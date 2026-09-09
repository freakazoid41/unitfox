import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';

import 'db_factory_io.dart' if (dart.library.js_interop) 'db_factory_web.dart';
import '../models/work_order.dart';

/// Local persistence: SQLite is the single source of truth. The app is fully
/// offline — every read and write goes through this database. No sync, no
/// server, no network dependency.
class LocalDB {
  static const _dbName = 'sitemanager.db';
  static const _dbVersion = 14;
  static Database? _db;
  static Future<Database>? _openFuture;

  static Future<Database> open({String? overridePath}) {
    if (_db != null) return Future.value(_db);
    _openFuture ??= _doOpen(overridePath);
    return _openFuture!;
  }

  static Future<Database> _doOpen(String? overridePath) async {
    final factory = resolveDatabaseFactory();
    if (factory != null) databaseFactory = factory;
    final isWeb = factory != null;
    final path = overridePath ??
        (isWeb ? _dbName : '${await getDatabasesPath()}/$_dbName');
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createTables(db, oldVersion: oldVersion);
      },
    );
    _openFuture = null;
    return _db!;
  }

  /// Canonical schemas keyed by table name. Every money column is declared
  /// INTEGER (exact minor-unit cents) — never REAL — so amounts are stored as
  /// exact integers and can never be silently corrupted as floats.
  static const Map<String, String> _tableDdl = {
    'properties': '''
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        address TEXT NOT NULL DEFAULT '',
        currency TEXT NOT NULL DEFAULT 'EUR',
        created_at INTEGER NOT NULL
      ''',
    'work_orders': '''
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        property_id INTEGER NOT NULL DEFAULT 0,
        unit TEXT NOT NULL,
        category TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        priority TEXT NOT NULL,
        status TEXT NOT NULL,
        assigned_to TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        completed_at INTEGER,
        photo_proof TEXT,
        proof_data BLOB,
        updated_at INTEGER NOT NULL DEFAULT 0
      ''',
    'units': '''
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        property_id INTEGER NOT NULL DEFAULT 0,
        number TEXT NOT NULL,
        floor TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'vacant',
        tenant_name TEXT NOT NULL DEFAULT '',
        base_rent INTEGER NOT NULL DEFAULT 0,
        extra_charge_name TEXT NOT NULL DEFAULT '',
        extra_charge INTEGER NOT NULL DEFAULT 0,
        owned_by_management INTEGER NOT NULL DEFAULT 0,
        occupiers TEXT NOT NULL DEFAULT '',
        is_rented INTEGER NOT NULL DEFAULT 1,
        move_in_date INTEGER,
        move_out_date INTEGER,
        lease_end INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL DEFAULT 0
      ''',
    'charges': '''
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        property_id INTEGER NOT NULL DEFAULT 0,
        unit_id INTEGER NOT NULL,
        month TEXT NOT NULL,
        amount INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL
      ''',
    'payments': '''
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        property_id INTEGER NOT NULL DEFAULT 0,
        unit_id INTEGER NOT NULL,
        month TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'Aidat',
        amount INTEGER NOT NULL,
        currency TEXT NOT NULL DEFAULT 'EUR',
        account_id INTEGER,
        note TEXT NOT NULL DEFAULT '',
        attachment BLOB,
        attachment_name TEXT NOT NULL DEFAULT '',
        paid_at INTEGER NOT NULL
      ''',
    'expenses': '''
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        property_id INTEGER NOT NULL DEFAULT 0,
        category TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        amount INTEGER NOT NULL,
        currency TEXT NOT NULL DEFAULT 'EUR',
        account_id INTEGER,
        attachment BLOB,
        attachment_name TEXT NOT NULL DEFAULT '',
        staff_id INTEGER,
        salary_month TEXT NOT NULL DEFAULT '',
        date INTEGER NOT NULL
      ''',
    'accounts': '''
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        property_id INTEGER NOT NULL DEFAULT 0,
        name TEXT NOT NULL,
        kind TEXT NOT NULL DEFAULT 'bank',
        bank_name TEXT NOT NULL DEFAULT '',
        iban TEXT NOT NULL DEFAULT '',
        currency TEXT NOT NULL DEFAULT 'EUR',
        opening_balance INTEGER NOT NULL DEFAULT 0
      ''',
    'staff': '''
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        property_id INTEGER NOT NULL DEFAULT 0,
        name TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT '',
        phone TEXT NOT NULL DEFAULT '',
        salary INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      ''',
    'settings': '''
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL DEFAULT ''
      ''',
  };

  static Future<void> _createTables(Database db, {int oldVersion = 0}) async {
    for (final entry in _tableDdl.entries) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS "${entry.key}"(${entry.value})');
    }
    await _migrate(db, oldVersion: oldVersion);
  }

  /// Brings schemas created before v3 (no accounts, no payment/expense
  /// type/currency/account columns) up to date.
  static Future<void> _migrate(Database db, {int oldVersion = 0}) async {
    final tableCols = <String, Set<String>>{};
    Future<Set<String>> colsOf(String table) async =>
        tableCols[table] ??= (await db.rawQuery('PRAGMA table_info($table)'))
            .map((r) => r['name'] as String)
            .toSet();

    Future<void> addIfMissing(
        String table, String column, String ddl) async {
      final existing = await colsOf(table);
      if (!existing.contains(column)) {
        await db.execute('ALTER TABLE $table ADD COLUMN $column $ddl');
        existing.add(column);
      }
    }

    await addIfMissing(
        'payments', 'type', "TEXT NOT NULL DEFAULT 'Aidat'");
    await addIfMissing(
        'payments', 'currency', "TEXT NOT NULL DEFAULT 'EUR'");
    await addIfMissing('payments', 'account_id', 'INTEGER');
    await addIfMissing(
        'expenses', 'currency', "TEXT NOT NULL DEFAULT 'EUR'");
    await addIfMissing('expenses', 'account_id', 'INTEGER');
    await addIfMissing('accounts', 'bank_name', "TEXT NOT NULL DEFAULT ''");
    await addIfMissing('accounts', 'iban', "TEXT NOT NULL DEFAULT ''");
    await addIfMissing('payments', 'attachment', 'BLOB');
    await addIfMissing(
        'payments', 'attachment_name', "TEXT NOT NULL DEFAULT ''");
    await addIfMissing('expenses', 'attachment', 'BLOB');
    await addIfMissing(
        'expenses', 'attachment_name', "TEXT NOT NULL DEFAULT ''");
    await addIfMissing('staff', 'salary', 'INTEGER NOT NULL DEFAULT 0');
    await addIfMissing('expenses', 'staff_id', 'INTEGER');
    await addIfMissing(
        'expenses', 'salary_month', "TEXT NOT NULL DEFAULT ''");

    // v10: unit occupiers and rental status.
    await addIfMissing(
        'units', 'occupiers', "TEXT NOT NULL DEFAULT ''");
    await addIfMissing(
        'units', 'is_rented', 'INTEGER NOT NULL DEFAULT 1');

    // v11: raw proof image bytes for work orders.
    await addIfMissing('work_orders', 'proof_data', 'BLOB');

    // v12: money is stored as exact minor units (cents). One-time conversion
    // of any pre-v12 floating amounts (e.g. 850.5 -> 85050). Runs ONLY when
    // upgrading from a pre-v12 schema (oldVersion > 0 && oldVersion < 12);
    // a fresh empty DB (oldVersion == 0) is unaffected (0 rows).
    if (oldVersion > 0 && oldVersion < 12) {
      for (final (table, column) in [
        ('units', 'base_rent'),
        ('units', 'extra_charge'),
        ('charges', 'amount'),
        ('payments', 'amount'),
        ('expenses', 'amount'),
        ('accounts', 'opening_balance'),
        ('staff', 'salary'),
      ]) {
        await db.execute(
            'UPDATE $table SET $column = CAST(ROUND($column * 100) AS INTEGER)');
      }
    }

    // v9: multi-property support. Add property_id everywhere and fold any
    // pre-existing single-site data into a first property.
    for (final table in [
      'work_orders',
      'units',
      'charges',
      'payments',
      'expenses',
      'accounts',
      'staff',
    ]) {
      await addIfMissing(
          table, 'property_id', 'INTEGER NOT NULL DEFAULT 0');
    }
    await _ensureMigratedProperty(db);

    // v13: rebuild the six tables that historically declared money columns as
    // REAL (float) so they become exact INTEGER cents. Runs only when upgrading
    // an existing database — a fresh DB (oldVersion == 0) already created its
    // tables with the canonical INTEGER schema above. Every row is copied
    // verbatim; the money columns hold whole cents after the v12 conversion.
    if (oldVersion > 0 && oldVersion < 13) {
      await _rebuildMoneyColumns(db);
      tableCols.clear(); // rebuild recreated tables — invalidate cache
    }

    // v14: lease tracking — move_in_date, move_out_date, lease_end on units.
    await addIfMissing('units', 'move_in_date', 'INTEGER');
    await addIfMissing('units', 'move_out_date', 'INTEGER');
    await addIfMissing('units', 'lease_end', 'INTEGER');
    // properties.address — added after initial schema.
    await addIfMissing('properties', 'address', "TEXT NOT NULL DEFAULT ''");
  }

  /// Recreates the money-holding tables with INTEGER (exact cent) columns and
  /// copies every row across, backfilling the canonical defaults so NULLs from
  /// looser legacy schemas never violate NOT NULL. Called once during the v13
  /// upgrade; a fresh DB never reaches this path. Atomic because sqflite wraps
  /// onUpgrade in a transaction.
  static Future<void> _rebuildMoneyColumns(Database db) async {
    // Column order + the canonical default to apply when a legacy row is NULL.
    const tables = {
      'units': {
        'id': null, 'property_id': 0, 'number': '', 'floor': '',
        'status': 'vacant', 'tenant_name': '', 'base_rent': 0,
        'extra_charge_name': '', 'extra_charge': 0, 'owned_by_management': 0,
        'occupiers': '', 'is_rented': 1,
        'move_in_date': null, 'move_out_date': null, 'lease_end': null,
        'created_at': 0, 'updated_at': 0,
      },
      'charges': {
        'id': null, 'property_id': 0, 'unit_id': 0, 'month': '',
        'amount': 0, 'note': '', 'created_at': 0,
      },
      'payments': {
        'id': null, 'property_id': 0, 'unit_id': 0, 'month': '',
        'type': 'Aidat', 'amount': 0, 'currency': 'EUR', 'account_id': null,
        'note': '', 'attachment': null, 'attachment_name': '', 'paid_at': 0,
      },
      'expenses': {
        'id': null, 'property_id': 0, 'category': '', 'description': '',
        'amount': 0, 'currency': 'EUR', 'account_id': null,
        'attachment': null, 'attachment_name': '', 'staff_id': null,
        'salary_month': '', 'date': 0,
      },
      'accounts': {
        'id': null, 'property_id': 0, 'name': '', 'kind': 'bank',
        'bank_name': '', 'iban': '', 'currency': 'EUR', 'opening_balance': 0,
      },
      'staff': {
        'id': null, 'property_id': 0, 'name': '', 'role': '', 'phone': '',
        'salary': 0, 'created_at': 0,
      },
    };
    for (final entry in tables.entries) {
      final table = entry.key;
      final allCols = entry.value.keys.toList();
      final backup = '${table}_v13_old';
      await db.execute('ALTER TABLE "$table" RENAME TO "$backup"');
      await db.execute('CREATE TABLE "$table"(${_tableDdl[table]})');
      // Discover which columns the backup actually has so we never SELECT
      // a column that doesn't exist (e.g. v14 columns in a v8 backup).
      final backupColsRaw = await db.rawQuery('PRAGMA table_info("$backup")');
      final backupCols = backupColsRaw.map((r) => r['name'] as String).toSet();
      final cols = allCols.where((c) => backupCols.contains(c)).toList();
      final select = cols
          .map((c) {
            final def = entry.value[c];
            if (def == null) return '"$c"';
            final lit = def is String ? "'$def'" : '$def';
            return 'COALESCE("$c", $lit)';
          })
          .join(', ');
      final list = cols.join(', ');
      await db.execute(
          'INSERT INTO "$table"($list) SELECT $select FROM "$backup"');
      await db.execute('DROP TABLE IF EXISTS "$backup"');
    }
  }

  /// Creates the initial property out of the legacy single-site settings and
  /// points every existing scoped row at it. Safe to run on every open —
  /// no-ops once properties exist.
  static Future<void> _ensureMigratedProperty(Database db) async {
    final countRows = await db.rawQuery('SELECT COUNT(*) AS c FROM properties');
    final count = (countRows.first['c'] as num?)?.toInt() ?? 0;
    if (count > 0) return;

    final nameRows =
        await db.query('settings', where: "key = 'site_name'", limit: 1);
    final name = nameRows.isEmpty
        ? ''
        : ((nameRows.first['value'] as String?) ?? '');
    if (name.isEmpty) return; // brand-new site, not yet onboarded.

    final currencyRows = await db
        .query('settings', where: "key = 'main_currency'", limit: 1);
    final currency = currencyRows.isEmpty
        ? ''
        : ((currencyRows.first['value'] as String?) ?? '');
    final created = await db.insert('properties', {
      'name': name,
      'currency': currency.isEmpty ? 'EUR' : currency,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    for (final table in [
      'work_orders',
      'units',
      'charges',
      'payments',
      'expenses',
      'accounts',
      'staff',
    ]) {
      await db.update(table, {'property_id': created});
    }
    await db.insert('settings', {
      'key': 'active_property',
      'value': '$created',
    });
  }

  static Database get db {
    final d = _db;
    if (d == null) {
      throw StateError('LocalDB not open. Call LocalDB.open() first.');
    }
    return d;
  }

  static Future<void> reset() async {
    await _db?.close();
    _db = null;
    _openFuture = null;
  }

  // ----------------------------------------------------------------- Properties

  static Future<int> insertProperty(Map<String, Object?> values) {
    return db.insert('properties', values);
  }

  static Future<List<Map<String, Object?>>> getProperties() async {
    return db.query('properties', orderBy: 'id ASC');
  }

  static Future<Map<String, Object?>?> getProperty(int id) async {
    final rows = await db.query('properties',
        where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  static Future<void> updateProperty(int id, Map<String, Object?> values) async {
    await db.update('properties', values, where: 'id = ?', whereArgs: [id]);
  }

  /// Removes a property and everything scoped to it (units, charges, payments,
  /// work orders, expenses, accounts and staff).
  static Future<void> deleteProperty(int id) async {
    final database = db;
    await database.transaction((txn) async {
      for (final table in [
        'units',
        'charges',
        'payments',
        'work_orders',
        'expenses',
        'accounts',
        'staff',
      ]) {
        await txn
            .delete(table, where: 'property_id = ?', whereArgs: [id]);
      }
      await txn.delete('properties', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ---------------------------------------------------------------- Work orders

  static Map<String, Object?> _workOrderRow(WorkOrder w) => {
        'id': w.id,
        'unit': w.unit,
        'category': w.category,
        'title': w.title,
        'description': w.description,
        'priority': w.priority,
        'status': w.status,
        'assigned_to': w.assignedTo,
        'property_id': 0,
        'created_at': w.createdAt.millisecondsSinceEpoch,
        'completed_at': w.completedAt?.millisecondsSinceEpoch,
        'photo_proof': w.photoProof,
        'proof_data': w.proofBytes,
        'updated_at': w.createdAt.millisecondsSinceEpoch,
      };

  static WorkOrder _workOrderFromRow(Map<String, Object?> row) => WorkOrder(
        id: row['id'] as int,
        unit: row['unit'] as String,
        category: row['category'] as String,
        title: row['title'] as String,
        description: row['description'] as String,
        priority: row['priority'] as String,
        status: row['status'] as String,
        assignedTo: (row['assigned_to'] as String?) ?? '',
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        completedAt: row['completed_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row['completed_at'] as int),
        photoProof: row['photo_proof'] as String?,
        proofBytes: row['proof_data'] as Uint8List?,
      );

  static Future<int> insertWorkOrder(WorkOrder w,
      {required int propertyId}) async {
    final map = _workOrderRow(w)
      ..remove('id')
      ..['property_id'] = propertyId;
    return db.insert('work_orders', map);
  }

  static Future<List<WorkOrder>> getWorkOrders(
      {int? propertyId, bool includeBlob = true}) async {
    final columns = includeBlob ? null : <String>[
      'id', 'property_id', 'unit', 'category', 'title', 'description',
      'priority', 'status', 'assigned_to', 'created_at', 'completed_at',
      'photo_proof', 'updated_at',
    ];
    if (propertyId == null) {
      final rows = await db.query('work_orders',
          columns: columns, orderBy: 'created_at DESC');
      return rows.map(_workOrderFromRow).toList();
    }
    final rows = await db.query('work_orders',
        columns: columns,
        where: 'property_id = ?',
        whereArgs: [propertyId],
        orderBy: 'created_at DESC');
    return rows.map(_workOrderFromRow).toList();
  }

  /// Fetches just a work order's proof image, avoiding loading every BLOB with
  /// the list query.
  static Future<Uint8List?> getWorkOrderProof(int id) async {
    final rows = await db.query('work_orders',
        columns: ['proof_data'], where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first['proof_data'] as Uint8List?;
  }

  static Future<void> updateWorkOrderStatus(int id, String status,
      {DateTime? completedAt, String? photoProof, String? assignedTo,
      Uint8List? proofBytes}) async {
    final values = <String, Object?>{
      'status': status,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    if (completedAt != null) {
      values['completed_at'] = completedAt.millisecondsSinceEpoch;
    }
    if (photoProof != null) {
      values['photo_proof'] = photoProof;
    }
    if (proofBytes != null) {
      values['proof_data'] = proofBytes;
    }
    if (assignedTo != null) {
      values['assigned_to'] = assignedTo;
    }
    await db.update('work_orders', values, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteWorkOrder(int id) async {
    await db.delete('work_orders', where: 'id = ?', whereArgs: [id]);
  }

  // --------------------------------------------------------------------- Units

  static Future<int> insertUnit(Map<String, Object?> values) async {
    return db.insert('units', values);
  }

  /// Inserts many units atomically in a single transaction.
  static Future<void> insertUnits(List<Map<String, Object?>> rows) async {
    final database = db;
    await database.transaction((txn) async {
      for (final row in rows) {
        await txn.insert('units', row);
      }
    });
  }

  static Future<List<Map<String, Object?>>> getUnits(int propertyId) async {
    return db.query('units',
        where: 'property_id = ?', whereArgs: [propertyId], orderBy: 'number ASC');
  }

  static Future<void> updateUnit(int id, Map<String, Object?> values) async {
    await db.update('units', {...values, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteUnit(int id) async {
    final database = db;
    await database.transaction((txn) async {
      // Cascade: orphaned charges/payments would otherwise leak forever and
      // could reappear in a unit ledger after a reload.
      await txn.delete('charges', where: 'unit_id = ?', whereArgs: [id]);
      await txn.delete('payments', where: 'unit_id = ?', whereArgs: [id]);
      await txn.delete('units', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ------------------------------------------------------------------- Charges

  static Future<int> insertCharge(Map<String, Object?> values) {
    return db.insert('charges', values);
  }

  static Future<void> deleteCharge(int id) {
    return db.delete('charges', where: 'id = ?', whereArgs: [id]);
  }

  /// Inserts many charges atomically in a single transaction.
  static Future<void> insertCharges(List<Map<String, Object?>> rows) async {
    final database = db;
    await database.transaction((txn) async {
      for (final row in rows) {
        await txn.insert('charges', row);
      }
    });
  }

  static Future<List<Map<String, Object?>>> getCharges(int propertyId) async {
    return db.query('charges',
        where: 'property_id = ?',
        whereArgs: [propertyId],
        orderBy: 'month ASC, id ASC');
  }

  static Future<List<Map<String, Object?>>> getChargesForUnit(int unitId) async {
    return db.query('charges',
        where: 'unit_id = ?', whereArgs: [unitId], orderBy: 'month ASC');
  }

  // ------------------------------------------------------------------ Payments

  static Future<int> insertPayment(Map<String, Object?> values) {
    return db.insert('payments', values);
  }

  static Future<List<Map<String, Object?>>> getPayments(int propertyId,
      {bool includeBlob = true}) async {
    final columns =
        includeBlob ? null : <String>['id', 'property_id', 'unit_id', 'month', 'type', 'amount', 'currency', 'account_id', 'note', 'attachment_name', 'paid_at'];
    return db.query('payments',
        columns: columns,
        where: 'property_id = ?',
        whereArgs: [propertyId],
        orderBy: 'paid_at ASC');
  }

  /// Fetches just a payment's attachment bytes on demand.
  static Future<Uint8List?> getPaymentAttachment(int id) async {
    final rows = await db.query('payments',
        columns: ['attachment'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1);
    return rows.isEmpty ? null : rows.first['attachment'] as Uint8List?;
  }

  static Future<List<Map<String, Object?>>> getPaymentsForUnit(int unitId) async {
    return db.query('payments',
        where: 'unit_id = ?', whereArgs: [unitId], orderBy: 'paid_at ASC');
  }

  // ------------------------------------------------------------------ Expenses

  static Future<int> insertExpense(Map<String, Object?> values) {
    return db.insert('expenses', values);
  }

  static Future<List<Map<String, Object?>>> getExpenses(int propertyId,
      {bool includeBlob = true}) async {
    final columns = includeBlob
        ? null
        : <String>[
            'id', 'property_id', 'category', 'description', 'amount',
            'currency', 'account_id', 'attachment_name', 'staff_id',
            'salary_month', 'date',
          ];
    return db.query('expenses',
        columns: columns,
        where: 'property_id = ?',
        whereArgs: [propertyId],
        orderBy: 'date DESC');
  }

  /// Fetches just an expense's attachment bytes on demand.
  static Future<Uint8List?> getExpenseAttachment(int id) async {
    final rows = await db.query('expenses',
        columns: ['attachment'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1);
    return rows.isEmpty ? null : rows.first['attachment'] as Uint8List?;
  }

  static Future<void> deleteExpense(int id) {
    return db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deletePayment(int id) {
    return db.delete('payments', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------------------- Accounts

  static Future<int> insertAccount(Map<String, Object?> values) {
    return db.insert('accounts', values);
  }

  /// Inserts many accounts atomically in a single transaction.
  static Future<void> insertAccounts(List<Map<String, Object?>> rows) async {
    final database = db;
    await database.transaction((txn) async {
      for (final row in rows) {
        await txn.insert('accounts', row);
      }
    });
  }

  /// Completes the first-run wizard atomically: creates the property,
  /// inserts all accounts and units, and sets the active property id — all
  /// in a single transaction so a partial failure never leaves a half-built
  /// orphan property.
  static Future<int> completeOnboardingAtomic(
    String name,
    String currency,
    String address,
    List<Map<String, Object?>> accountRows,
    List<Map<String, Object?>> unitRows,
  ) async {
    final database = db;
    return database.transaction((txn) async {
      final propertyId = await txn.insert('properties', {
        'name': name,
        'currency': currency,
        'address': address,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      for (final row in accountRows) {
        await txn.insert('accounts', {...row, 'property_id': propertyId});
      }
      for (final row in unitRows) {
        await txn.insert('units', {...row, 'property_id': propertyId});
      }
      await txn.insert('settings', {
        'key': 'active_property',
        'value': '$propertyId',
      });
      return propertyId;
    });
  }

  static Future<List<Map<String, Object?>>> getAccounts(int propertyId) async {
    return db.query('accounts',
        where: 'property_id = ?', whereArgs: [propertyId], orderBy: 'id ASC');
  }

  static Future<void> updateAccount(
      int id, Map<String, Object?> values) async {
    await db.update('accounts', values, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteAccount(int id) async {
    await db.transaction((txn) async {
      await txn.delete('accounts', where: 'id = ?', whereArgs: [id]);
      await txn
          .delete('payments', where: 'account_id = ?', whereArgs: [id]);
      await txn
          .delete('expenses', where: 'account_id = ?', whereArgs: [id]);
    });
  }

  // ---------------------------------------------------------------------- Staff

  static Future<int> insertStaffMember(Map<String, Object?> values) {
    return db.insert('staff', values);
  }

  static Future<List<Map<String, Object?>>> getStaffMembers(
      int propertyId) async {
    return db.query('staff',
        where: 'property_id = ?',
        whereArgs: [propertyId],
        orderBy: 'name COLLATE NOCASE ASC');
  }

  static Future<void> updateStaffMember(
      int id, Map<String, Object?> values) async {
    await db.update('staff', values, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteStaffMember(int id) async {
    await db.delete('staff', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------------------- Settings

  static Future<String> getSetting(String key) async {
    final rows =
        await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? '' : (rows.first['value'] as String?) ?? '';
  }

  static Future<void> setSetting(String key, String value) async {
    await db.rawInsert(
      'INSERT INTO settings (key, value) VALUES (?, ?) '
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      [key, value],
    );
  }

  /// True once the first-run wizard has been completed and at least one
  /// property exists. Stores use this to skip demo-data seeding.
  static Future<bool> isOnboarded() async {
    final name = await getSetting('site_name');
    if (name.isNotEmpty) return true;
    final count = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM properties')) ??
        0;
    return count > 0;
  }

  /// The id of the property currently being viewed, or null when unset.
  static Future<int?> getActivePropertyId() async {
    final v = await getSetting('active_property');
    if (v.isEmpty) return null;
    return int.tryParse(v);
  }

  static Future<void> setActivePropertyId(int id) =>
      setSetting('active_property', '$id');
}