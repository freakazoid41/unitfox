import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sitemanager/data/local_db.dart';
import 'package:sitemanager/data/site_store.dart';

// Proves a pre-v9 single-site DB gets folded into one Property on upgrade.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() => LocalDB.reset());

  test('legacy single-site data migrates into a property', () async {
    final file = File('${Directory.systemTemp.path}/_legacy_v8.db');
    if (file.existsSync()) file.deleteSync();

    // Build the OLD v8 schema by hand (no properties table, no property_id).
    final legacy = await databaseFactory.openDatabase(file.path, options: OpenDatabaseOptions(
      version: 8,
      onCreate: (db, version) async {
        await db.execute(
            'CREATE TABLE units(id INTEGER PRIMARY KEY AUTOINCREMENT, number TEXT, floor TEXT, status TEXT, tenant_name TEXT, base_rent REAL, extra_charge_name TEXT, extra_charge REAL, owned_by_management INTEGER, created_at INTEGER, updated_at INTEGER)');
        await db.execute(
            'CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)');
        await db.execute(
            'CREATE TABLE accounts(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, kind TEXT, bank_name TEXT, iban TEXT, currency TEXT, opening_balance REAL)');
        await db.execute(
            'CREATE TABLE work_orders(id INTEGER PRIMARY KEY AUTOINCREMENT, unit TEXT, category TEXT, title TEXT, description TEXT, priority TEXT, status TEXT, assigned_to TEXT, created_at INTEGER, completed_at INTEGER, photo_proof TEXT, updated_at INTEGER)');
        await db.execute(
            'CREATE TABLE charges(id INTEGER PRIMARY KEY AUTOINCREMENT, unit_id INTEGER, month TEXT, amount REAL, note TEXT, created_at INTEGER)');
        await db.execute(
            'CREATE TABLE payments(id INTEGER PRIMARY KEY AUTOINCREMENT, unit_id INTEGER, month TEXT, type TEXT, amount REAL, currency TEXT, account_id INTEGER, note TEXT, created_at INTEGER, attachment BLOB, attachment_name TEXT, paid_at INTEGER)');
        await db.execute(
            'CREATE TABLE expenses(id INTEGER PRIMARY KEY AUTOINCREMENT, category TEXT, description TEXT, amount REAL, currency TEXT, account_id INTEGER, attachment BLOB, attachment_name TEXT, staff_id INTEGER, salary_month TEXT, date INTEGER)');
        await db.execute(
            'CREATE TABLE staff(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, role TEXT, phone TEXT, salary REAL, created_at INTEGER)');
      },
    ));
    await legacy.insert('settings', {'key': 'site_name', 'value': 'Old Estate'});
    await legacy.insert('settings', {'key': 'main_currency', 'value': 'USD'});
    await legacy.insert('units', {
      'number': 'A-1',
      'status': 'occupied',
      'created_at': 0,
    });
    await legacy.close();

    // Reopen with current code -> should upgrade 8 -> 9 and fold data in.
    LocalDB.reset();
    await LocalDB.open(overridePath: file.path);

    final props = await LocalDB.getProperties();
    expect(props, hasLength(1), reason: 'one migrated property');
    expect(props.first['name'], 'Old Estate');
    expect(props.first['currency'], 'USD');

    final units = await LocalDB.getUnits(props.first['id'] as int);
    expect(units, hasLength(1), reason: 'legacy unit backfilled to property');
    expect(units.first['property_id'], props.first['id']);

    final site = SiteStore();
    await site.load();
    expect(site.onboarded, isTrue);
    expect(site.siteName, 'Old Estate');
    expect(site.mainCurrency, 'USD');

    // Money columns must have been rebuilt as exact INTEGERs, never floats.
    const moneyCols = {
      'units': ['base_rent', 'extra_charge'],
      'charges': ['amount'],
      'payments': ['amount'],
      'expenses': ['amount'],
      'accounts': ['opening_balance'],
      'staff': ['salary'],
    };
    for (final entry in moneyCols.entries) {
      final info =
          await LocalDB.db.rawQuery('PRAGMA table_info("${entry.key}")');
      for (final col in entry.value) {
        final row = info.firstWhere((r) => r['name'] == col);
        expect(row['type'], 'INTEGER',
            reason: '${entry.key}.$col must be INTEGER, got ${row['type']}');
      }
    }

    if (file.existsSync()) file.deleteSync();
  });
}