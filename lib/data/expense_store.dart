import 'package:flutter/foundation.dart';

import '../models/expense.dart';
import 'local_db.dart';

class ExpenseStore extends ChangeNotifier {
  final bool _usePersistence;
  int _propertyId = 0;
  int _loadGen = 0;
  List<Expense> _expenses = [];
  bool _loaded = false;

  ExpenseStore({bool usePersistence = true}) : _usePersistence = usePersistence;

  bool get isLoaded => _loaded;
  int get propertyId => _propertyId;
  List<Expense> get expenses => List.unmodifiable(_expenses);

  /// Raw sum of ALL expenses in their native currencies — no conversion. Only
  /// tests consume this; UI totals go through the FX-aware monthly rollups.
  int get totalAll => _expenses.fold<int>(0, (s, e) => s + e.amount);

  Future<void> load({int? propertyId}) async {
    final gen = ++_loadGen;
    _propertyId = propertyId ?? _propertyId;
    if (!_usePersistence) {
      _loaded = true;
      notifyListeners();
      return;
    }
    final rows =
        await LocalDB.getExpenses(_propertyId, includeBlob: false);
    if (gen != _loadGen) return;
    _expenses = rows.map(Expense.fromRow).toList();
    _loaded = true;
    notifyListeners();
  }

  Future<void> add(
    String category,
    int amount, {
    String description = '',
    String currency = 'EUR',
    int? accountId,
    DateTime? date,
    Uint8List? attachment,
    String attachmentName = '',
    int? staffId,
    String salaryMonth = '',
  }) async {
    final createdAt = date ?? DateTime.now();
    final id = _usePersistence
        ? await LocalDB.insertExpense({
            'property_id': _propertyId,
            'category': category,
            'description': description,
            'amount': amount,
            'currency': currency,
            'account_id': accountId,
            'attachment': attachment,
            'attachment_name': attachmentName,
            'staff_id': staffId,
            'salary_month': salaryMonth,
            'date': createdAt.millisecondsSinceEpoch,
          })
        : 0;
    _expenses = [
      Expense(
        id: id,
        category: category,
        description: description,
        amount: amount,
        currency: currency,
        accountId: accountId,
        attachment: attachment,
        attachmentName: attachmentName,
        staffId: staffId,
        salaryMonth: salaryMonth,
        date: createdAt,
      ),
      ..._expenses,
    ];
    notifyListeners();
  }

  /// Records a monthly salary payment for a crew member. Booked as an expense
  /// so it flows through account balances and the monthly expense summary.
  /// Allows partial payments: the total paid for the month is capped at
  /// [salary], so topping up works but overpayment is blocked. Returns true
  /// when money was booked, false when the salary is already fully settled.
  Future<bool> paySalary(
    int staffId, {
    required int amount,
    required int salary,
    required String currency,
    required int? accountId,
    required String salaryMonth,
    String staffName = '',
  }) async {
    final paid = _expenses
        .where((e) => e.staffId == staffId && e.salaryMonth == salaryMonth)
        .fold<int>(0, (s, e) => s + e.amount);
    if (paid >= salary) return false;
    var toPay = amount;
    final remaining = salary - paid;
    if (toPay > remaining) toPay = remaining;
    if (toPay <= 0) return false;
    await add(
      'Salary',
      toPay,
      description: salaryMonth.isEmpty
          ? 'Salary'
          : 'Salary $staffName — $salaryMonth',
      currency: currency,
      accountId: accountId,
      staffId: staffId,
      salaryMonth: salaryMonth,
      date: DateTime.now(),
    );
    return true;
  }

  Future<void> remove(int id) async {
    if (_usePersistence) {
      await LocalDB.deleteExpense(id);
    }
    _expenses = _expenses.where((e) => e.id != id).toList();
    notifyListeners();
  }

  /// Drops every expense booked against an account, memory only. Called after
  /// LocalDB.deleteAccount has cascade-removed the rows, so monthly expenses
  /// stop counting them immediately instead of waiting for a full reload.
  void removeForAccount(int accountId) {
    _expenses = _expenses.where((e) => e.accountId != accountId).toList();
    notifyListeners();
  }

  /// Fetches a single expense attachment's bytes on demand.
  Future<Uint8List?> expenseAttachment(int expenseId) =>
      LocalDB.getExpenseAttachment(expenseId);
}