import 'dart:async' show unawaited;
import 'dart:ui' show Locale, PlatformDispatcher;
import 'package:flutter/foundation.dart';

import 'local_db.dart';

/// Persisted region language preference. On first run it follows the device
/// locale; if the phone speaks none of the supported languages it falls back
/// to English. Afterwards the manual choice survives restarts.
class LanguageStore extends ChangeNotifier {
  static const _key = 'app_lang';
  static const List<Locale> supported = [
    Locale('en'), Locale('tr'), Locale('ru'),
    Locale('fr'), Locale('de'), Locale('hi'),
  ];
  static const _supportedCodes = ['en', 'tr', 'ru', 'fr', 'de', 'hi'];

  final bool _usePersistence;
  String _lang = 'en';

  LanguageStore({bool usePersistence = true}) : _usePersistence = usePersistence;

  String get lang => _lang;
  Locale get locale => Locale(_lang);

  Future<void> load() async {
    var persisted = '';
    if (_usePersistence) {
      persisted = await LocalDB.getSetting(_key);
    }
    if (_supportedCodes.contains(persisted)) {
      _lang = persisted;
    } else {
      // First run — mirror the phone's language, or fall back to English.
      final sys = PlatformDispatcher.instance.locale.languageCode;
      _lang = _supportedCodes.contains(sys) ? sys : 'en';
      if (_usePersistence) await LocalDB.setSetting(_key, _lang);
    }
    notifyListeners();
  }

  void setLocale(String lang) {
    if (!_supportedCodes.contains(lang)) return;
    _lang = lang;
    if (_usePersistence) unawaited(LocalDB.setSetting(_key, _lang));
    notifyListeners();
  }
}