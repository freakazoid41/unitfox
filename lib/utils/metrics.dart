import '../data/expense_store.dart';
import '../data/fx_store.dart';
import '../data/staff_store.dart';
import '../data/unit_store.dart';

/// Single source of truth for the monthly roll-up metrics shared by the
/// dashboard and finance screens — they previously re-implemented the same
/// loops and could drift apart.

/// Payments received during the current calendar month, converted to [main].
/// Returns the sum AND whether any conversion fell back to a 1:1 guess because
/// the rate is unknown (offline / never fetched), so callers can flag the
/// figure as approximate.
(int, bool) monthlyIncomeGuessed(UnitStore units, String main, FxStore fx) {
  final now = DateTime.now();
  var sum = 0;
  var guessed = false;
  for (final p in units.allPayments) {
    if (p.paidAt.year != now.year || p.paidAt.month != now.month) continue;
    if (!fx.hasKnownRate(p.currency, main)) guessed = true;
    sum += fx.convert(p.amount, p.currency, main);
  }
  return (sum, guessed);
}

/// Expenses booked during the current calendar month, converted to [main].
/// Same (sum, guessed) contract as [monthlyIncomeGuessed].
(int, bool) monthlyExpensesGuessed(
    ExpenseStore expenses, String main, FxStore fx) {
  final now = DateTime.now();
  var sum = 0;
  var guessed = false;
  for (final e in expenses.expenses) {
    if (e.date.year != now.year || e.date.month != now.month) continue;
    if (!fx.hasKnownRate(e.currency, main)) guessed = true;
    sum += fx.convert(e.amount, e.currency, main);
  }
  return (sum, guessed);
}

/// Payments received in currencies OTHER THAN [main], converted to [main].
/// These sit in the ledger as credits that base-currency arrears never see, so
/// the "received this month" and "awaiting income" KPIs could tell
/// contradictory stories — this is what the awaiting card's caption surfaces.
int nonBaseCredits(UnitStore units, String main, FxStore fx) {
  var sum = 0;
  for (final p in units.allPayments) {
    final cur = p.currency.isEmpty ? main : p.currency;
    if (cur == main) continue;
    sum += fx.convert(p.amount, cur, main);
  }
  return sum;
}

/// Total crew salary still unpaid for the current month (in the cash/base
/// currency — salaries are denominated in the cash account's currency).
int awaitingCrewSalaries(StaffStore staff, ExpenseStore expenses) {
  final now = DateTime.now();
  final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  var sum = 0;
  for (final m in staff.members) {
    if (m.salary <= 0) continue;
    final paid = expenses.expenses
        .where((e) => e.staffId == m.id && e.salaryMonth == month)
        .fold<int>(0, (s, e) => s + e.amount);
    if (paid < m.salary) sum += m.salary - paid;
  }
  return sum;
}

/// Combined income + expense entries recorded during the current calendar
/// month (count, not value).
int monthlyTransactionCount(UnitStore units, ExpenseStore expenses) {
  final now = DateTime.now();
  final income = units.allPayments
      .where((p) => p.paidAt.year == now.year && p.paidAt.month == now.month)
      .length;
  final exp = expenses.expenses
      .where((e) => e.date.year == now.year && e.date.month == now.month)
      .length;
  return income + exp;
}