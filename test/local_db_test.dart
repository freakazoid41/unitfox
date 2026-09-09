import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sitemanager/data/expense_store.dart';
import 'package:sitemanager/data/local_db.dart';
import 'package:sitemanager/data/unit_store.dart';
import 'package:sitemanager/data/work_order_store.dart';
import 'package:sitemanager/models/work_order.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await LocalDB.reset();
  });

  group('work orders', () {
    test('completely offline: data persists locally and survives restarts',
        () async {
      await LocalDB.open(overridePath: inMemoryDatabasePath);
      final store = WorkOrderStore();
      await store.load();

      expect(store.orders, isNotEmpty, reason: 'seeds on first run');

      final first = store.orders.first;
      await store.complete(first.id, photoProof: 'camera/file.jpg');

      final fromDisk = await LocalDB.getWorkOrders(propertyId: 0);
      expect(fromDisk.first.status, 'completed');
      expect(fromDisk.first.photoProof, 'camera/file.jpg');
    });

    test('offline-added work orders survive a restart', () async {
      await LocalDB.open(overridePath: inMemoryDatabasePath);

      final s1 = WorkOrderStore();
      await s1.load();
      await s1.add(WorkOrder(
        id: 0,
        unit: 'Z-999',
        category: 'Other',
        title: 'Offline job',
        description: 'Created with no signal.',
        priority: 'low',
        status: 'open',
        assignedTo: '',
        createdAt: DateTime.now(),
      ));

      final s2 = WorkOrderStore();
      await s2.load(seedIfEmpty: false);
      expect(s2.orders.any((o) => o.title == 'Offline job'), isTrue);
    });
  });

  group('finance', () {
    test('units seed with rents and monthly charge math works', () async {
      await LocalDB.open(overridePath: inMemoryDatabasePath);
      final store = UnitStore();
      await store.load();

      expect(store.units, isNotEmpty);
      // Management-owned units are flagged and contribute to income.
      expect(store.units.any((u) => u.ownedByManagement), isTrue);

      final u = store.units.first;
      expect(u.monthlyCharge, u.baseRent + u.extraCharge);
      // The current month is auto-billed on load, so awaiting income shows up.
      expect(store.ledgerFor(u.id)!.totalCharged, u.monthlyCharge);
    });

    test('post monthly charges + record payment updates ledger', () async {
      await LocalDB.open(overridePath: inMemoryDatabasePath);
      final store = UnitStore();
      await store.load();

      final now = DateTime.now();
      final prev = DateTime(now.year, now.month - 1);
      final month = '${prev.year}-${prev.month.toString().padLeft(2, '0')}';
      final posted = await store.postAllMonthlyCharges(month);
      expect(posted, greaterThan(0));
      expect(store.totalCharged, greaterThan(0));
      expect(store.totalOutstanding, store.totalCharged);

      // Record a payment for the first occupied unit.
      final target = store.units.firstWhere((u) => u.status == 'occupied');
      final charge = store.ledgerFor(target.id)!.totalCharged;
      await store.recordPayment(target.id, month, charge, note: 'Cash');

      expect(store.ledgerFor(target.id)!.outstanding, 0);
      expect(store.totalOutstanding, lessThan(store.totalCharged));
      expect(store.totalIncome, charge);

      // Persisted to disk.
      final fromDisk = await LocalDB.getPaymentsForUnit(target.id);
      expect(fromDisk, isNotEmpty);
    });

    test('expenses are recorded and deleted', () async {
      await LocalDB.open(overridePath: inMemoryDatabasePath);
      final expenseStore = ExpenseStore();
      await expenseStore.add('Utilities', 12050, description: 'Water bill');

      expect(expenseStore.expenses, hasLength(1));
      expect(expenseStore.totalAll, 12050);

      await expenseStore.remove(expenseStore.expenses.first.id);
      expect(expenseStore.expenses, isEmpty);
    });
  });
}