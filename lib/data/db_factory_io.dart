import 'package:sqflite_common/sqlite_api.dart';

/// Native platforms keep sqflite's default file-based SQLite factory.
DatabaseFactory? resolveDatabaseFactory() => null;
