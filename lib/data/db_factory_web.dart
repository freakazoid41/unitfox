import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Web: SQLite compiled to WASM, persisted in IndexedDB through a shared worker.
/// Keeps the app fully offline in the browser.
DatabaseFactory? resolveDatabaseFactory() => databaseFactoryFfiWeb;
