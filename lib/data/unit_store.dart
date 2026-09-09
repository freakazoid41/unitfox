import 'package:flutter/foundation.dart';

import '../models/payment.dart';
import '../models/unit.dart';
import 'local_db.dart';

/// A single calendar month's balance for a unit. `remaining` already includes
/// credit carried forward from earlier months, so the rent grid and the
/// arrears summary read the same number and can never disagree. All amounts
/// are exact minor units in the base currency.
class UnitMonthBalance {
  final int year;
  final int monthNum; // 1-12
  final String ym; // 'YYYY-MM'
  final int charged; // charges posted for this month
  final int paidBase; // payments received this month, in the base currency
  final int remaining; // still owed after carry-forward (0 when covered)
  const UnitMonthBalance({
    required this.year,
    required this.monthNum,
    required this.ym,
    required this.charged,
    required this.paidBase,
    required this.remaining,
  });
}

/// A unit's ledger. Charges are posted in a single base currency (the site's
/// main currency — the cash account's currency). Payments can arrive in other
/// currencies, so arrears are always computed per-currency — a payment in one
/// currency never wipes a charge in another. All amounts are exact minor units.
class UnitLedger {
  final Unit unit;
  final int totalCharged; // posted charges, in the base/rent currency
  final int paidBase; // payments received in the base (charged) currency
  final int outstanding; // arrears after month-ordered credit carry-forward
  final String baseCurrency;

  const UnitLedger({
    required this.unit,
    required this.totalCharged,
    required this.paidBase,
    required this.outstanding,
    required this.baseCurrency,
  });

  /// Income received in the charged (base) currency — comparable against
  /// [totalCharged]. Payments in other currencies are credits, not income here.
  int get totalIncome => paidBase;
}

class UnitStore extends ChangeNotifier {
  final bool _usePersistence;
  int _propertyId = 0;
  int _loadGen = 0;
  List<Unit> _units = [];
  Map<int, List<UnitCharge>> _charges = {};
  Map<int, List<Payment>> _payments = {};
  String _baseCurrency = 'EUR'; // the cash (main) account currency
  bool _loaded = false;

  UnitStore({bool usePersistence = true}) : _usePersistence = usePersistence;

  bool get isLoaded => _loaded;
  int get propertyId => _propertyId;
  List<Unit> get units => List.unmodifiable(_units);

  /// The currency charges are posted in (the cash/main account currency).
  String get baseCurrency => _baseCurrency;

  void setBaseCurrency(String currency) {
    if (_baseCurrency == currency) return;
    _baseCurrency = currency;
    _ledgerCache = null;
    
    
    notifyListeners();
  }

  /// Units that are billed each month. Must match [postAllMonthlyCharges]'s
  /// definition (status-driven), otherwise the occupancy % and awaiting-income
  /// metrics would disagree with what actually gets charged.
  int get occupiedCount =>
      _units.where((u) => u.status == 'occupied').length;

  /// True when any unit has posted charges or recorded payments — used to warn
  /// before operations that would re-denominate an existing ledger (e.g. a
  /// cash-account currency change).
  bool get hasLedgerData => _units
      .any((u) => (_charges[u.id]?.isNotEmpty ?? false) || (_payments[u.id]?.isNotEmpty ?? false));
  int get maintenanceCount =>
      _units.where((u) => u.status == 'maintenance').length;
  int get arrearsCount => _ledgers.values.where((l) => l.outstanding > 0).length;

  Map<int, UnitLedger>? _ledgerCache;

  Map<int, UnitLedger> get _ledgers =>
      _ledgerCache ??= _computeLedgers();

  Map<int, UnitLedger> _computeLedgers() {
    final map = <int, UnitLedger>{};
    for (final u in _units) {
      final rows = _monthBalancesFor(u.id);
      map[u.id] = UnitLedger(
        unit: u,
        totalCharged: rows.fold<int>(0, (s, r) => s + r.charged),
        paidBase: rows.fold<int>(0, (s, r) => s + r.paidBase),
        outstanding: rows.fold<int>(0, (s, r) => s + r.remaining),
        baseCurrency: _baseCurrency,
      );
    }
    return map;
  }

  /// Per-month balances for a unit, oldest to newest. Surplus credit rolls
  /// forward into the next month, so `remaining` reflects how much is genuinely
  /// outstanding this month even after an earlier overpayment.
  List<UnitMonthBalance> monthBalancesAll(int unitId) =>
      _monthBalancesFor(unitId);

  List<UnitMonthBalance> _monthBalancesFor(int unitId) {
    final chargedByMonth = <String, int>{};
    for (final c in _charges[unitId] ?? const <UnitCharge>[]) {
      chargedByMonth[c.month] = (chargedByMonth[c.month] ?? 0) + c.amount;
    }
    final paidByMonth = <String, int>{};
    for (final p in _payments[unitId] ?? const <Payment>[]) {
      final cur = p.currency.isEmpty ? _baseCurrency : p.currency;
      if (cur != _baseCurrency) continue;
      paidByMonth[p.month] = (paidByMonth[p.month] ?? 0) + p.amount;
    }
    final months =
        <String>{...chargedByMonth.keys, ...paidByMonth.keys}.toList()..sort();
    final rows = <UnitMonthBalance>[];
    var carrying = 0;
    for (final ym in months) {
      final parts = ym.split('-');
      final charge = chargedByMonth[ym] ?? 0;
      final pay = paidByMonth[ym] ?? 0;
      final fellShort = charge - (carrying + pay);
      rows.add(UnitMonthBalance(
        year: parts.isEmpty ? 0 : int.tryParse(parts[0]) ?? 0,
        monthNum: parts.length < 2 ? 0 : int.tryParse(parts[1]) ?? 0,
        ym: ym,
        charged: charge,
        paidBase: pay,
        remaining: fellShort < 0 ? 0 : fellShort,
      ));
      carrying += pay - charge;
      if (carrying < 0) carrying = 0;
    }
    return rows;
  }

  /// Total still owed (base/rent currency only) across all billed units.
  int get totalOutstanding =>
      _ledgers.values.fold<int>(0, (s, l) => s + l.outstanding);

  /// Income received in the charged (base) currency — comparable against
  /// [totalCharged]. Payments in other currencies are tracked per-currency.
  int get totalIncome =>
      _ledgers.values.fold<int>(0, (s, l) => s + l.paidBase);

  /// Sum of monthly charges posted (expected income for the ledger).
  int get totalCharged =>
      _ledgers.values.fold<int>(0, (s, l) => s + l.totalCharged);

  String get _currentMonth {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  UnitLedger? ledgerFor(int unitId) => _ledgers[unitId];

  List<UnitCharge> chargesFor(int unitId) =>
      List.unmodifiable(_charges[unitId] ?? const []);

  List<Payment> paymentsFor(int unitId) =>
      List.unmodifiable(_payments[unitId] ?? const []);

  /// Every recorded payment across all units, newest first. Cached and rebuilt
  /// only when payments/units change.
  List<Payment> get allPayments =>
      _allPaymentsCache ??= _computeAllPayments();

  List<Payment>? _allPaymentsCache;

  List<Payment> _computeAllPayments() {
    final all = <Payment>[];
    for (final u in _units) {
      all.addAll(_payments[u.id] ?? const []);
    }
    all.sort((a, b) => b.paidAt.compareTo(a.paidAt));
    return all;
  }

  Future<void> load({int? propertyId, bool seedIfEmpty = true}) async {
    final gen = ++_loadGen;
    _propertyId = propertyId ?? _propertyId;
    if (!_usePersistence) {
      _units = _seedUnits();
      _charges = {};
      _payments = {};
      _ledgerCache = null;
      _allPaymentsCache = null;
      
      
      _loaded = true;
      notifyListeners();
      return;
    }
    final rows = await LocalDB.getUnits(_propertyId);
    if (gen != _loadGen) return;
    _units = rows.map(Unit.fromRow).toList();
    if (_units.isEmpty && seedIfEmpty && !await LocalDB.isOnboarded()) {
      await _seed();
      _units = (await LocalDB.getUnits(_propertyId)).map(Unit.fromRow).toList();
    }
    if (gen != _loadGen) return;
    await _loadLedger();
    if (gen != _loadGen) return;
    // Bill the current month automatically so awaiting income (total
    // outstanding) is visible without a manual "post" step.
    await postAllMonthlyCharges(_currentMonth);
    if (gen != _loadGen) return;
    
    
    _loaded = true;
    notifyListeners();
  }

  Future<void> _loadLedger() async {
    _charges = {};
    _payments = {};
    _ledgerCache = null;
    _allPaymentsCache = null;
    for (final charge in await LocalDB.getCharges(_propertyId)) {
      final c = UnitCharge.fromRow(charge);
      _charges.putIfAbsent(c.unitId, () => []).add(c);
    }
    for (final payment in await LocalDB.getPayments(_propertyId, includeBlob: false)) {
      final p = Payment.fromRow(payment);
      _payments.putIfAbsent(p.unitId, () => []).add(p);
    }
  }

  /// Loads a single payment's attachment bytes on demand (kept out of memory
  /// during list loads).
  Future<Uint8List?> paymentAttachment(int paymentId) =>
      LocalDB.getPaymentAttachment(paymentId);

  /// Posts a month's charges (rent + extra charge) for one unit.
  Future<void> postMonthlyCharge(int unitId, String month) async {
    final idx = _units.indexWhere((u) => u.id == unitId);
    if (idx == -1) return;
    final unit = _units[idx];
    if (unit.monthlyCharge <= 0) return;
    final already = _charges[unitId]?.any(
            (c) => c.month == month && c.note == 'Monthly charge') ??
        false;
    if (already) return;

    final id = await LocalDB.insertCharge({
      'property_id': _propertyId,
      'unit_id': unitId,
      'month': month,
      'amount': unit.monthlyCharge,
      'note': 'Monthly charge',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    _charges.putIfAbsent(unitId, () => []).add(UnitCharge(
          id: id,
          unitId: unitId,
          month: month,
          amount: unit.monthlyCharge,
          note: 'Monthly charge',
        ));
    _ledgerCache = null;
    
    notifyListeners();
  }

  /// Posts the monthly charge for every rented (occupied) unit at once, in a
  /// single transaction.
  Future<int> postAllMonthlyCharges(String month) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = <Map<String, Object?>>[];
    final inserted = <UnitCharge>[];
    for (final u in _units) {
      if (u.status != 'occupied' || u.monthlyCharge <= 0) continue;
      final already = _charges[u.id]?.any(
              (c) => c.month == month && c.note == 'Monthly charge') ??
          false;
      if (already) continue;
      rows.add({
        'property_id': _propertyId,
        'unit_id': u.id,
        'month': month,
        'amount': u.monthlyCharge,
        'note': 'Monthly charge',
        'created_at': now,
      });
      inserted.add(UnitCharge(
        id: 0,
        unitId: u.id,
        month: month,
        amount: u.monthlyCharge,
        note: 'Monthly charge',
      ));
    }
    if (rows.isEmpty) return 0;
    await LocalDB.insertCharges(rows);
    // Resolve the fresh row ids. Scope the query to the inserted unit ids so
    // pre-existing 'Monthly charge' rows for the same property+month (older
    // ids) can never be matched to the wrong new charge — ORDER BY id ASC is
    // only safe within this exact set because every row here is brand new.
    final unitIds = inserted.map((c) => c.unitId).toList();
    final placeholders = List.filled(unitIds.length, '?').join(',');
    final ids = await LocalDB.db.rawQuery(
      'SELECT id FROM charges WHERE property_id = ? AND month = ? '
      'AND note = ? AND unit_id IN ($placeholders) ORDER BY id ASC',
      [_propertyId, month, 'Monthly charge', ...unitIds],
    );
    for (var i = 0; i < inserted.length; i++) {
      final dbId = (ids[i]['id'] as num?)?.toInt() ?? 0;
      final c = inserted[i];
      _charges
          .putIfAbsent(c.unitId, () => [])
          .add(UnitCharge(id: dbId, unitId: c.unitId, month: c.month, amount: c.amount, note: c.note));
    }
    _ledgerCache = null;
    
    notifyListeners();
    return inserted.length;
  }

  /// Records a payment received for a unit against a month.
  Future<void> recordPayment(
    int unitId,
    String month,
    int amount, {
    String type = PaymentType.aidat,
    String currency = 'EUR',
    int? accountId,
    String note = '',
    Uint8List? attachment,
    String attachmentName = '',
  }) async {
    final paidAt = DateTime.now();
    // Only a rent (Aidat) payment auto-bills a missing month. Posting the full
    // charge for a fuel/other payment would silently inflate the unit's
    // outstanding by (charge − payment) — the charge belongs to a separate
    // billing intent the manager must trigger deliberately.
    if (type == PaymentType.aidat &&
        !(_charges[unitId]?.any(
                (c) => c.month == month && c.note == 'Monthly charge') ??
            false)) {
      final unitIdx = _units.indexWhere((u) => u.id == unitId);
      if (unitIdx != -1 && _units[unitIdx].monthlyCharge > 0) {
        await postMonthlyCharge(unitId, month);
      }
    }
    final id = await LocalDB.insertPayment({
      'property_id': _propertyId,
      'unit_id': unitId,
      'month': month,
      'type': type,
      'amount': amount,
      'currency': currency,
      'account_id': accountId,
      'note': note,
      'attachment': attachment,
      'attachment_name': attachmentName,
      'paid_at': paidAt.millisecondsSinceEpoch,
    });
    _payments.putIfAbsent(unitId, () => []).add(Payment(
          id: id,
          unitId: unitId,
          month: month,
          type: type,
          amount: amount,
          currency: currency,
          accountId: accountId,
          note: note,
          attachment: attachment,
          attachmentName: attachmentName,
          paidAt: paidAt,
        ));
    _ledgerCache = null;
    _allPaymentsCache = null;
    
    notifyListeners();
  }

  /// Removes every charge posted for a unit/month (the rent-grid "remove
  /// charge" action). Deletes from the DB and memory so arrears and the rent
  /// grid re-agree immediately.
  Future<void> removeCharge(int unitId, String month) async {
    final list = _charges[unitId];
    if (list == null || list.isEmpty) return;
    final toRemove = list.where((c) => c.month == month).toList();
    if (toRemove.isEmpty) return;
    for (final c in toRemove) {
      await LocalDB.deleteCharge(c.id);
    }
    list.removeWhere((c) => c.month == month);
    _ledgerCache = null;
    notifyListeners();
  }

  /// Updates a unit's editable fields.
  Future<void> updateUnit(Unit unit) async {
    await LocalDB.updateUnit(unit.id,
        unit.toRow(propertyId: _propertyId));
    final i = _units.indexWhere((u) => u.id == unit.id);
    if (i != -1) _units[i] = unit.copyWith(propertyId: _propertyId);
    _units.sort((a, b) => a.number.compareTo(b.number));
    _ledgerCache = null;
    _allPaymentsCache = null;
    
    notifyListeners();
  }

  /// Removes a unit by id. Its charges and payments are cascade-deleted from
  /// the DB alongside it (see LocalDB.deleteUnit). Returns the ids of the
  /// wiped payments so callers can keep other stores (e.g. the transaction log
  /// and account balances) in sync.
  Future<List<int>> removeUnit(int id) async {
    final removedPayments = [
      for (final p in _payments[id] ?? const <Payment>[]) p.id,
    ];
    await LocalDB.deleteUnit(id);
    _units.removeWhere((u) => u.id == id);
    _charges.remove(id);
    _payments.remove(id);
    _ledgerCache = null;
    _allPaymentsCache = null;
    notifyListeners();
    return removedPayments;
  }

  /// Drops a single payment from the in-memory ledgers. Used when a payment
  /// is deleted elsewhere (transactions screen) so unit balances, income and
  /// arrears stay in sync with the DB without a full reload.
  void removePayment(int paymentId) {
    for (final entry in _payments.entries) {
      final before = entry.value.length;
      entry.value.removeWhere((p) => p.id == paymentId);
      if (entry.value.length != before) break;
    }
    _ledgerCache = null;
    _allPaymentsCache = null;
    
    notifyListeners();
  }

  /// Drops every payment whose id is in [paymentIds] (batch variant for
  /// cascade deletions, e.g. removing an account wipes its payments).
  void removePayments(Iterable<int> paymentIds) {
    final ids = Set<int>.from(paymentIds);
    if (ids.isEmpty) return;
    for (final entry in _payments.entries) {
      entry.value.removeWhere((p) => ids.contains(p.id));
    }
    _ledgerCache = null;
    _allPaymentsCache = null;
    
    notifyListeners();
  }

  /// Adds a new unit and keeps the list sorted by unit number.
  Future<Unit> addUnit(Unit unit) async {
    final values = unit.toRow(propertyId: _propertyId)
      ..addAll({'created_at': DateTime.now().millisecondsSinceEpoch});
    final id = await LocalDB.insertUnit(values);
    final created = Unit(
      id: id,
      propertyId: _propertyId,
      number: unit.number,
      floor: unit.floor,
      status: unit.status,
      tenantName: unit.tenantName,
      baseRent: unit.baseRent,
      extraChargeName: unit.extraChargeName,
      extraCharge: unit.extraCharge,
      ownedByManagement: unit.ownedByManagement,
      occupiers: unit.occupiers,
      isRented: unit.isRented,
      moveInDate: unit.moveInDate,
      moveOutDate: unit.moveOutDate,
      leaseEnd: unit.leaseEnd,
    );
    _units.add(created);
    _units.sort((a, b) => a.number.compareTo(b.number));
    _ledgerCache = null;
    _allPaymentsCache = null;
    notifyListeners();
    // A newly added rented unit is billed for the current month right away so
    // it shows up in awaiting income immediately.
    if (created.status == 'occupied' && created.monthlyCharge > 0) {
      await postMonthlyCharge(created.id, _currentMonth);
    }
    return created;
  }

  Future<void> _seed() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = _seedUnits()
        .map((u) => u.toRow(propertyId: _propertyId)
          ..addAll({'created_at': now}))
        .toList();
    await LocalDB.insertUnits(rows);
  }

  List<Unit> _seedUnits() => [
        Unit(
            id: 0,
            number: 'A-101',
            floor: '1',
            status: 'occupied',
            tenantName: 'Alice Tan',
            baseRent: 85000,
            extraChargeName: 'Heating',
            extraCharge: 5000),
        Unit(
            id: 0,
            number: 'A-102',
            floor: '1',
            status: 'occupied',
            tenantName: 'Bob Lee',
            baseRent: 85000,
            extraChargeName: 'Heating',
            extraCharge: 5000),
        Unit(
            id: 0,
            number: 'A-103',
            floor: '1',
            status: 'vacant',
            tenantName: '',
            baseRent: 80000),
        Unit(
            id: 0,
            number: 'B-201',
            floor: '2',
            status: 'occupied',
            tenantName: 'Carol Ng',
            baseRent: 100000,
            extraChargeName: 'Heating',
            extraCharge: 6000),
        Unit(
            id: 0,
            number: 'B-202',
            floor: '2',
            status: 'maintenance',
            tenantName: 'Dan Yap',
            baseRent: 100000),
        Unit(
            id: 0,
            number: 'C-301',
            floor: '3',
            status: 'occupied',
            tenantName: 'Frank Ho',
            baseRent: 120000,
            extraChargeName: 'Heating',
            extraCharge: 7000),
        Unit(
            id: 0,
            number: 'M-401',
            floor: '4',
            status: 'occupied',
            tenantName: 'Management unit (rented)',
            baseRent: 60000,
            ownedByManagement: true),
        Unit(
            id: 0,
            number: 'M-402',
            floor: '4',
            status: 'occupied',
            tenantName: 'Management unit (rented)',
            baseRent: 60000,
            ownedByManagement: true),
      ];
}