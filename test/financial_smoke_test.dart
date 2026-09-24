import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sitemanager/data/account_store.dart';
import 'package:sitemanager/data/expense_store.dart';
import 'package:sitemanager/data/fx_store.dart';
import 'package:sitemanager/data/local_db.dart';
import 'package:sitemanager/data/staff_store.dart';
import 'package:sitemanager/data/unit_store.dart';
import 'package:sitemanager/models/payment.dart';
import 'package:sitemanager/models/staff_member.dart';
import 'package:sitemanager/models/unit.dart';
import 'package:sitemanager/utils/metrics.dart';

/// Pre-release smoke test for the FINANCIAL mechanics. Uses the REAL SQLite
/// database (in-memory, sqflite_common_ffi) and the REAL stores — no mocks —
/// so every number below is what a manager would actually see. The purpose is
/// to prove the money math end-to-end: charges, payments, carry-forward,
/// per-currency arrears, account balances, salaries, monthly rollups and the
/// cross-store delete sync.
class Harness {
  int pid = 0;
  late UnitStore units;
  late AccountStore accounts;
  late ExpenseStore expenses;
  late StaffStore staff;
  final FxStore fx = FxStore();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await LocalDB.reset();
  });

  String ym(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
  String currentMonth() => ym(DateTime.now());
  String nextMonth() {
    final now = DateTime.now();
    return ym(DateTime(now.year, now.month + 1));
  }

  Future<int> seedSite() async {
    await LocalDB.open(overridePath: inMemoryDatabasePath);
    return LocalDB.completeOnboardingAtomic(
      'Smoke Site',
      'EUR',
      '',
      [
        {
          'name': 'Cash (main)',
          'kind': 'cash',
          'bank_name': '',
          'iban': '',
          'currency': 'EUR',
          'opening_balance': 100000,
        },
        {
          'name': 'Bank TRY',
          'kind': 'bank',
          'bank_name': '',
          'iban': '',
          'currency': 'TRY',
          'opening_balance': 0,
        },
      ],
      const [],
    );
  }

  Future<Harness> harness() async {
    final h = Harness();
    h.pid = await seedSite();
    h.units = UnitStore();
    await h.units.load(propertyId: h.pid);
    h.accounts = AccountStore();
    await h.accounts.load(propertyId: h.pid);
    h.expenses = ExpenseStore();
    await h.expenses.load(propertyId: h.pid);
    h.staff = StaffStore();
    await h.staff.load(propertyId: h.pid, seedIfEmpty: false);
    return h;
  }

  Future<Unit> addOccupied(Harness h,
          {int baseRent = 90000, String number = 'A-101'}) =>
      h.units.addUnit(Unit(
        id: 0,
        number: number,
        floor: '1',
        status: 'occupied',
        tenantName: 'Tenant',
        baseRent: baseRent,
      ));

  group('account balances', () {
    test('opening balances land on the right accounts, nothing else', () async {
      final h = await harness();
      expect(h.accounts.cashAccount!.currency, 'EUR');
      expect(h.accounts.balanceFor(h.accounts.cashAccount!.id)!.balance, 100000);
      final tryBank = h.accounts.accounts.firstWhere((a) => a.currency == 'TRY');
      expect(h.accounts.balanceFor(tryBank.id)!.balance, 0);
    });

    test('income into cash raises its balance and clears the unit', () async {
      final h = await harness();
      final unit = await addOccupied(h);
      expect(h.units.ledgerFor(unit.id)!.outstanding, 90000,
          reason: 'addUnit auto-bills the current month');

      final cash = h.accounts.cashAccount!;
      await h.units.recordPayment(unit.id, currentMonth(), 90000,
          type: PaymentType.aidat, currency: 'EUR', accountId: cash.id);
      await h.accounts.refreshTransactions();

      expect(h.units.ledgerFor(unit.id)!.outstanding, 0);
      expect(h.units.totalIncome, 90000);
      expect(h.units.totalOutstanding, 0);
      expect(h.accounts.balanceFor(cash.id)!.balance, 100000 + 90000);
    });

    test('a mismatched account currency never lands on any balance', () async {
      final h = await harness();
      final cash = h.accounts.cashAccount!;
      final tryBank = h.accounts.accounts.firstWhere((a) => a.currency == 'TRY');

      // Expense in TRY but pointed at the EUR cash account -> unattributable.
      await h.expenses.add('Mismatch', 5000, currency: 'TRY', accountId: cash.id);
      // Payment in EUR but pointed at the TRY bank -> unattributable.
      final unit = await addOccupied(h);
      await h.units.recordPayment(unit.id, '2099-03', 70000,
          type: PaymentType.aidat, currency: 'EUR', accountId: tryBank.id);
      await h.accounts.refreshTransactions();

      expect(h.accounts.balanceFor(cash.id)!.balance, 100000,
          reason: 'mismatched expense must not debit cash');
      expect(h.accounts.balanceFor(tryBank.id)!.balance, 0,
          reason: 'mismatched payment must not credit TRY');
      final txns = h.accounts.transactions();
      expect(txns.where((t) => t.kind == 'expense'), hasLength(1));
      expect(txns.where((t) => t.kind == 'income'), hasLength(1),
          reason: 'unattributable rows stay visible in the log');
    });
  });

  group('unit ledger', () {
    test('foreign payment is a credit — never clears base-currency arrears',
        () async {
      final h = await harness();
      final unit = await addOccupied(h);
      final tryBank = h.accounts.accounts.firstWhere((a) => a.currency == 'TRY');

      await h.units.recordPayment(unit.id, currentMonth(), 200000,
          type: PaymentType.aidat, currency: 'TRY', accountId: tryBank.id);
      await h.accounts.refreshTransactions();

      expect(h.units.ledgerFor(unit.id)!.outstanding, 90000,
          reason: 'TRY payment must not wipe the EUR charge');
      expect(h.units.ledgerFor(unit.id)!.paidBase, 0);
      expect(h.accounts.balanceFor(tryBank.id)!.balance, 200000);
      expect(h.accounts.balanceFor(h.accounts.cashAccount!.id)!.balance, 100000);
      // The awaiting-card caption figure: foreign credits converted 1:1.
      expect(nonBaseCredits(h.units, 'EUR', h.fx), 200000);
      // Monthly income sums it, and flags it approximate (no FX rates loaded).
      final (received, guessed) = monthlyIncomeGuessed(h.units, 'EUR', h.fx);
      expect(received, 200000);
      expect(guessed, isTrue);
    });

    test('non-aidat payment never auto-bills a missing month', () async {
      final h = await harness();
      final unit = await addOccupied(h);

      await h.units.recordPayment(unit.id, '2099-01', 5000,
          type: PaymentType.other, currency: 'EUR',
          accountId: h.accounts.cashAccount!.id);

      final charges2099 =
          h.units.chargesFor(unit.id).where((c) => c.month == '2099-01');
      expect(charges2099, isEmpty,
          reason: 'a fuel/other payment must not post a rent charge');
      expect(h.units.ledgerFor(unit.id)!.totalCharged, 90000);
      expect(h.units.totalOutstanding, 90000,
          reason: 'the 5000 Diğer is income, but the rent is still owed');
    });

    test('aidat auto-bills the missing month, then payment settles it',
        () async {
      final h = await harness();
      final unit = await addOccupied(h);

      await h.units.recordPayment(unit.id, '2099-02', 90000,
          type: PaymentType.aidat, currency: 'EUR',
          accountId: h.accounts.cashAccount!.id);

      final charge2099 =
          h.units.chargesFor(unit.id).firstWhere((c) => c.month == '2099-02');
      expect(charge2099.amount, 90000);
      expect(h.units.ledgerFor(unit.id)!.totalCharged, 180000);
      expect(h.units.ledgerFor(unit.id)!.outstanding, 90000,
          reason: 'only the still-unpaid current month remains');
    });

    test('overpayment carries forward into the next month', () async {
      final h = await harness();
      final unit = await addOccupied(h);

      await h.units.recordPayment(unit.id, currentMonth(), 100000,
          type: PaymentType.aidat, currency: 'EUR',
          accountId: h.accounts.cashAccount!.id);
      await h.units.postAllMonthlyCharges(nextMonth());

      final rows = h.units.monthBalancesAll(unit.id);
      expect(rows.first.remaining, 0,
          reason: 'overpaid current month is fully covered');
      expect(rows.last.charged, 90000);
      expect(rows.last.remaining, 80000,
          reason: '10000 credit carries into the next month');
      expect(h.units.totalOutstanding, 80000);
    });

    test('removeCharge drops the charge, the DB row, and the arrears',
        () async {
      final h = await harness();
      final unit = await addOccupied(h);
      expect(h.units.totalOutstanding, 90000);

      await h.units.removeCharge(unit.id, currentMonth());

      expect(h.units.ledgerFor(unit.id)!.totalCharged, 0);
      expect(h.units.totalOutstanding, 0);
      final rows = await LocalDB.getCharges(h.pid);
      expect(rows, isEmpty);
    });
  });

  group('salaries', () {
    test('partial pays, cap at salary, and overpayments are blocked',
        () async {
      final h = await harness();
      final cash = h.accounts.cashAccount!;
      final m = StaffMember(
          id: 0, name: 'Sara', role: 'Plumbing', salary: 80000, createdAt: DateTime.now());
      await h.staff.add(m);
      // add() persists and the store owns the real id — use that one.
      final id = h.staff.members.single.id;
      final month = currentMonth();

      final ok1 = await h.expenses.paySalary(id,
          amount: 50000, salary: 80000, currency: 'EUR',
          accountId: cash.id, salaryMonth: month);
      expect(ok1, isTrue);
      expect(awaitingCrewSalaries(h.staff, h.expenses), 30000);

      final ok2 = await h.expenses.paySalary(id,
          amount: 40000, salary: 80000, currency: 'EUR',
          accountId: cash.id, salaryMonth: month);
      expect(ok2, isTrue);
      expect(awaitingCrewSalaries(h.staff, h.expenses), 0,
          reason: 'topped up to exactly the salary');

      final ok3 = await h.expenses.paySalary(id,
          amount: 10000, salary: 80000, currency: 'EUR',
          accountId: cash.id, salaryMonth: month);
      expect(ok3, isFalse, reason: 'overpayment must be refused');
      final salaryPaid = h.expenses.expenses
          .where((e) => e.staffId == id && e.salaryMonth == month)
          .fold<int>(0, (s, e) => s + e.amount);
      expect(salaryPaid, 80000);

      await h.accounts.refreshTransactions();
      expect(h.accounts.balanceFor(cash.id)!.balance, 100000 - 80000);
    });
  });

  group('cross-store delete sync', () {
    test('deleting a unit removes its payments from account balances',
        () async {
      final h = await harness();
      final unit = await addOccupied(h);
      final cash = h.accounts.cashAccount!;
      await h.units.recordPayment(unit.id, currentMonth(), 90000,
          type: PaymentType.aidat, currency: 'EUR', accountId: cash.id);
      await h.accounts.refreshTransactions();
      expect(h.accounts.balanceFor(cash.id)!.balance, 190000);

      final removed = await h.units.removeUnit(unit.id);
      h.accounts.removePayments(removed);

      expect(h.accounts.balanceFor(cash.id)!.balance, 100000,
          reason: 'the deleted unit\'s payment must stop counting');
      expect(h.accounts.transactions().where((t) => t.kind == 'income'),
          isEmpty);
      expect(await LocalDB.getPayments(h.pid), isEmpty);
    });

    test('deleting an account drops its expenses from the expense store',
        () async {
      final h = await harness();
      final cash = h.accounts.cashAccount!;
      await h.expenses.add('Utilities', 12050,
          currency: 'EUR', accountId: cash.id);
      expect(h.expenses.expenses, hasLength(1));

      final removedPayments = await h.accounts.deleteAccount(cash.id);
      h.units.removePayments(removedPayments);
      h.expenses.removeForAccount(cash.id);

      expect(h.expenses.expenses, isEmpty,
          reason: 'monthly expenses must not count the deleted account\'s rows');
      expect(await LocalDB.getExpenses(h.pid, includeBlob: false), isEmpty);
      expect(h.accounts.accounts.any((a) => a.id == cash.id), isFalse);
    });
  });

  group('monthly rollups + transaction log', () {
    test('income/expense land in the combined log, newest first', () async {
      final h = await harness();
      final unit = await addOccupied(h);
      final cash = h.accounts.cashAccount!;
      await h.units.recordPayment(unit.id, currentMonth(), 90000,
          type: PaymentType.aidat, currency: 'EUR', accountId: cash.id);
      await h.expenses.add('Maintenance', 5000,
          currency: 'EUR', accountId: cash.id);
      await h.accounts.refreshTransactions();

      final txns = h.accounts.transactions();
      final income = txns.firstWhere((t) => t.kind == 'income');
      final expense = txns.firstWhere((t) => t.kind == 'expense');
      expect(income.label, 'A-101 · Aidat');
      expect(income.amount, 90000);
      expect(expense.amount, 5000);
      // Log itself is newest-first (non-increasing dates). DB round-trips
      // truncate to milliseconds, so ties are legal — assert the invariant,
      // not a strict order.
      for (var i = 0; i + 1 < txns.length; i++) {
        expect(
          txns[i].date.isAfter(txns[i + 1].date) ||
              txns[i].date.isAtSameMomentAs(txns[i + 1].date),
          isTrue,
          reason: 'txns sorted newest first',
        );
      }

      final (spent, guessedExpense) =
          monthlyExpensesGuessed(h.expenses, 'EUR', h.fx);
      expect(spent, 5000);
      expect(guessedExpense, isFalse, reason: 'EUR->EUR needs no rate');
      expect(monthlyTransactionCount(h.units, h.expenses), 2);
    });

    test('fx identity and 1:1 fallback never crash offline', () async {
      final h = await harness();
      expect(h.fx.hasKnownRate('EUR', 'EUR'), isTrue);
      expect(h.fx.convert(12345, 'EUR', 'EUR'), 12345);
      // Unknown pair -> identity fallback (approximate, but no crash).
      expect(h.fx.convert(12345, 'TRY', 'EUR'), 12345);
      expect(h.fx.hasKnownRate('TRY', 'EUR'), isFalse);
    });
  });

  group('persistence (DB is the source of truth)', () {
    test('data survives a store restart with identical numbers', () async {
      final h = await harness();
      final unit = await addOccupied(h);
      final cash = h.accounts.cashAccount!;
      await h.units.recordPayment(unit.id, currentMonth(), 90000,
          type: PaymentType.aidat, currency: 'EUR', accountId: cash.id);
      await h.expenses.add('Maintenance', 5000,
          currency: 'EUR', accountId: cash.id);

      final units2 = UnitStore();
      await units2.load(propertyId: h.pid);
      final accounts2 = AccountStore();
      await accounts2.load(propertyId: h.pid);
      final expenses2 = ExpenseStore();
      await expenses2.load(propertyId: h.pid);

      expect(units2.ledgerFor(unit.id)!.outstanding, 0);
      expect(units2.totalIncome, 90000);
      expect(accounts2.balanceFor(cash.id)!.balance, 100000 + 90000 - 5000);
      expect(expenses2.expenses, hasLength(1));
    });
  });
}
