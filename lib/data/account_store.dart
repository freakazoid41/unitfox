import 'package:flutter/foundation.dart';

import '../models/account.dart';
import '../models/expense.dart';
import '../models/payment.dart';
import 'local_db.dart';

class AccountBalance {
  final Account account;
  final int income; // received payments, in the account's currency
  final int expenses;
  final int balance; // opening + income - expenses

  const AccountBalance({
    required this.account,
    required this.income,
    required this.expenses,
    required this.balance,
  });
}

/// One line in the combined transaction log (income or expense).
class Txn {
  final DateTime date;
  final String kind; // 'income' | 'expense'
  final int amount; // minor units of [currency]
  final String currency;
  final String label; // e.g. 'A-101 · Aidat' or 'Maintenance'
  final int? accountId;
  final int? unitId;
  final String? paymentType; // 'Aidat' | 'Yakıt' | 'Diğer' for income
  final int? ownerId; // payment id (income) or expense id — for lazy blobs
  final Uint8List? attachment;
  final String attachmentName;

  const Txn({
    required this.date,
    required this.kind,
    required this.amount,
    required this.currency,
    required this.label,
    this.accountId,
    this.unitId,
    this.paymentType,
    this.ownerId,
    this.attachment,
    this.attachmentName = '',
  });
}

class AccountStore extends ChangeNotifier {
  final bool _usePersistence;
  int _propertyId = 0;
  int _loadGen = 0;
  List<Account> _accounts = [];
  List<Payment> _payments = [];
  List<Expense> _expenses = [];
  final Map<int, String> _unitNumbers = {};
  Map<int, AccountBalance>? _balanceCache;
  Map<int, String>? _accountNames;
  bool _loaded = false;

  AccountStore({bool usePersistence = true}) : _usePersistence = usePersistence;

  bool get isLoaded => _loaded;
  int get propertyId => _propertyId;
  List<Account> get accounts => List.unmodifiable(_accounts);

  /// The local cash account — the site's main money box. Its currency is the
  /// currency salaries are owed in. Returns null when no cash account exists
  /// (do NOT silently fall back to a bank account).
  Account? get cashAccount {
    for (final a in _accounts) {
      if (a.kind == 'cash') return a;
    }
    return null;
  }

  /// The usual account to post income/expenses against: the cash (main)
  /// account when present, otherwise the first account, or null when empty.
  Account? get defaultTransactionAccount =>
      _accounts.isEmpty ? null : (cashAccount ?? _accounts.first);

  String unitNumber(int unitId) => _unitNumbers[unitId] ?? 'U$unitId';

  /// Returns the account a transaction truly lands in. A transaction recorded
  /// without an explicit account (e.g. before any accounts existed) falls back
  /// to an account of the same currency, then to the default account ONLY when
  /// that account is denominated in the same currency. It must never be summed
  /// into a differently-denominated account's balance — mixing TRY cents into a
  /// EUR cash balance would corrupt the figure. Unattributable transactions
  /// stay visible in the transaction log but count on no balance.
  int? _resolveAccount(String currency, int? accountId) {
    if (accountId != null) {
      // An explicit account id is only honored when it exists AND is
      // denominated in the transaction's currency — summing a payment into a
      // differently-denominated account would corrupt its balance (e.g. 100 TRY
      // added to a EUR account). Unattributable transactions stay in the log
      // but count on no balance.
      for (final a in _accounts) {
        if (a.id == accountId) return a.currency == currency ? a.id : null;
      }
      return null;
    }
    for (final a in _accounts) {
      if (a.currency == currency) return a.id;
    }
    final def = defaultTransactionAccount;
    if (def != null && def.currency == currency) return def.id;
    return null;
  }

  static const _defaultAccounts = [
    Account(id: 0, name: 'Cash (local)', kind: 'cash', currency: 'EUR'),
    Account(id: 0, name: 'Bank · EUR', kind: 'bank', currency: 'EUR'),
    Account(id: 0, name: 'Bank · USD', kind: 'bank', currency: 'USD'),
    Account(id: 0, name: 'Bank · TRY', kind: 'bank', currency: 'TRY'),
  ];

  Future<void> load({int? propertyId}) async {
    final gen = ++_loadGen;
    _propertyId = propertyId ?? _propertyId;
    final pid = _propertyId;
    if (!_usePersistence) {
      _accounts = _defaultAccounts;
      _invalidate();
      _loaded = true;
      notifyListeners();
      return;
    }
    _accounts = (await LocalDB.getAccounts(pid)).map(Account.fromRow).toList();
    if (gen != _loadGen) return;
    if (_accounts.isEmpty && !await LocalDB.isOnboarded()) {
      for (final a in _defaultAccounts) {
        await LocalDB.insertAccount(a.toRow(propertyId: pid));
      }
      _accounts =
          (await LocalDB.getAccounts(pid)).map(Account.fromRow).toList();
    }
    if (gen != _loadGen) return;
    await _loadScoped(pid);
    if (gen != _loadGen) return;
    _invalidate();
    _loaded = true;
    notifyListeners();
  }

  /// Reloads payments/expenses/unit-numbers only (skips accounts). Each DB read
  /// is gen-guarded so a property switch mid-load can never surface a stale
  /// mix of old and new transactions.
  Future<void> _loadScoped(int pid) async {
    final gen = _loadGen;
    final payments = (await LocalDB.getPayments(pid, includeBlob: false))
        .map(Payment.fromRow)
        .toList();
    if (gen != _loadGen) return;
    _payments = payments;
    final expenses =
        (await LocalDB.getExpenses(pid, includeBlob: false)).map(Expense.fromRow).toList();
    if (gen != _loadGen) return;
    _expenses = expenses;
    _unitNumbers.clear();
    for (final row in await LocalDB.getUnits(pid)) {
      _unitNumbers[row['id'] as int] = (row['number'] as String?) ?? 'U?';
    }
  }

  void _invalidate() {
    _balanceCache = null;
    _accountNames = null;
    _allTxns = null;
  }

  /// Lightweight reload of just the transactions (payments/expenses) after an
  /// income/expense write elsewhere, without re-reading accounts.
  Future<void> refreshTransactions() async {
    if (_usePersistence) {
      final gen = _loadGen;
      await _loadScoped(_propertyId);
      if (gen != _loadGen) return;
    }
    _invalidate();
    notifyListeners();
  }

  Future<void> addAccount(Account account) async {
    if (!_usePersistence) {
      _accounts = [
        ..._accounts,
        Account(
          id: account.id == 0 ? 0 : account.id,
          propertyId: account.propertyId,
          name: account.name,
          kind: account.kind,
          bankName: account.bankName,
          iban: account.iban,
          currency: account.currency,
          openingBalance: account.openingBalance,
        ),
      ];
      _invalidate();
      notifyListeners();
      return;
    }
    final id = await LocalDB.insertAccount(account.toRow(propertyId: _propertyId));
    _accounts = [
      ..._accounts,
      Account(
        id: id,
        propertyId: _propertyId,
        name: account.name,
        kind: account.kind,
        bankName: account.bankName,
        iban: account.iban,
        currency: account.currency,
        openingBalance: account.openingBalance,
      ),
    ];
    _invalidate();
    notifyListeners();
  }

  Future<void> updateAccount(int id, Account account) async {
    if (_usePersistence) {
      await LocalDB.updateAccount(id, account.toRow(propertyId: _propertyId));
    }
    _accounts = [
      for (final a in _accounts)
        if (a.id == id)
          account.copyWith(id: id, propertyId: _propertyId)
        else
          a,
    ];
    _invalidate();
    notifyListeners();
  }

  /// Deletes an account and cascade-removes its payments/expenses. Returns the
  /// ids of the payments that were wiped, so callers can keep other stores
  /// (e.g. the unit ledger) in sync.
  Future<List<int>> deleteAccount(int id) async {
    final removedPayments = _payments
        .where((p) => p.accountId == id)
        .map((p) => p.id)
        .toList();
    if (_usePersistence) {
      await LocalDB.deleteAccount(id);
    }
    _accounts = _accounts.where((a) => a.id != id).toList();
    _payments = _payments.where((p) => p.accountId != id).toList();
    _expenses = _expenses.where((e) => e.accountId != id).toList();
    _invalidate();
    notifyListeners();
    return removedPayments;
  }

  Future<void> removePayment(int id) async {
    if (_usePersistence) await LocalDB.deletePayment(id);
    _payments = _payments.where((p) => p.id != id).toList();
    _invalidate();
    notifyListeners();
  }

  /// Drops payments by id from memory without touching the DB. Used when the
  /// rows were already cascade-deleted elsewhere (e.g. deleting a unit wipes
  /// its payments), so account balances and the transaction log stop counting
  /// them immediately instead of waiting for a full reload.
  void removePayments(Iterable<int> paymentIds) {
    final ids = Set<int>.from(paymentIds);
    if (ids.isEmpty) return;
    _payments = _payments.where((p) => !ids.contains(p.id)).toList();
    _invalidate();
    notifyListeners();
  }

  /// Balance per account: opening + payments - expenses. Cached and rebuilt
  /// only when the underlying data changes.
  Map<int, AccountBalance> get balances {
    if (_balanceCache != null) return _balanceCache!;
    final map = <int, AccountBalance>{};
    for (final a in _accounts) {
      var income = 0;
      var expenses = 0;
      for (final p in _payments) {
        final aid = _resolveAccount(p.currency, p.accountId);
        if (aid == a.id) income += p.amount;
      }
      for (final e in _expenses) {
        final aid = _resolveAccount(e.currency, e.accountId);
        if (aid == a.id) expenses += e.amount;
      }
      map[a.id] = AccountBalance(
        account: a,
        income: income,
        expenses: expenses,
        balance: a.openingBalance + income - expenses,
      );
    }
    _balanceCache = map;
    return map;
  }

  AccountBalance? balanceFor(int accountId) => balances[accountId];

  /// Fetches a single transaction's attachment bytes on demand.
  Future<Uint8List?> paymentAttachment(int paymentId) =>
      LocalDB.getPaymentAttachment(paymentId);

  Future<Uint8List?> expenseAttachment(int expenseId) =>
      LocalDB.getExpenseAttachment(expenseId);

  /// Combined income + expense log, newest first, with optional date-range
  /// filter (inclusive). The unfiltered list is cached and rebuilt only when
  /// the underlying data changes.
  List<Txn> transactions({DateTime? from, DateTime? to}) {
    final all = _allTxns ??= _computeTxns();
    if (from == null && to == null) return all;
    final start = from ?? DateTime(0);
    final end = to ?? DateTime(9999);
    return all
        .where((t) =>
            !t.date.isBefore(start) &&
            !t.date.isAfter(end.add(const Duration(days: 1))))
        .toList();
  }

  List<Txn>? _allTxns;

  List<Txn> _computeTxns() {
    final txns = <Txn>[];
    for (final p in _payments) {
      txns.add(Txn(
        date: p.paidAt,
        kind: 'income',
        amount: p.amount,
        currency: p.currency,
        label: '${unitNumber(p.unitId)} · ${p.type}',
        accountId: p.accountId,
        unitId: p.unitId,
        paymentType: p.type,
        ownerId: p.id,
        attachmentName: p.attachmentName,
      ));
    }
    for (final e in _expenses) {
      txns.add(Txn(
        date: e.date,
        kind: 'expense',
        amount: e.amount,
        currency: e.currency,
        label: e.category,
        accountId: e.accountId,
        ownerId: e.id,
        attachmentName: e.attachmentName,
      ));
    }
    txns.sort((a, b) => b.date.compareTo(a.date));
    return txns;
  }

  /// Display name of an account, or null when unknown.
  String? accountName(int? id) {
    if (id == null) return null;
    _accountNames ??= {for (final a in _accounts) a.id: a.name};
    return _accountNames![id];
  }
}