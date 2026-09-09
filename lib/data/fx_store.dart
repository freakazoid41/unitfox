import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'local_db.dart';

/// Foreign-exchange conversion for multi-currency reports. Rates are fetched
/// from the free open.er-api.com feed, cached in memory AND persisted to the
/// database with a 1-hour TTL. When the network is unavailable it falls back
/// to the last known rates, and finally to a 1:1 (no conversion) as a last
/// resort so the dashboard never crashes offline.
class FxStore extends ChangeNotifier {
  static const _ttl = Duration(hours: 1);
  static const _baseUrl = 'https://open.er-api.com/v6/latest/';

  /// base currency -> {currency: rate-to-1-base}
  final Map<String, Map<String, double>> _rates = {};
  final Map<String, DateTime> _fetchedAt = {};
  final Map<String, Future<void>> _refreshing = {};

  /// True once we have usable rates for [base].
  bool hasRates(String base) => _rates[base] != null;

  /// True when converting away from [base] would fall back to a 1:1 guess
  /// because no rates are known — the displayed figure is then approximate.
  /// Tries both lookup directions so a known base either side can resolve the
  /// pair (`_rates[to]` = to-based, `_rates[from]` = from-based).
  bool hasKnownRate(String from, String to) {
    if (from == to) return true;
    final rates = _rates[to];
    if (rates != null && (rates[from] ?? 0) > 0) return true;
    final inverse = _rates[from];
    return inverse != null && (inverse[to] ?? 0) > 0;
  }

  /// Fetches fresh rates for [base] (once per hour), persisting them offline.
  Future<void> refresh(String base) async {
    final last = _fetchedAt[base];
    if (last != null && DateTime.now().difference(last) < _ttl) return;
    if (_refreshing.containsKey(base)) {
      await _refreshing[base];
      return;
    }
    final f = _doRefresh(base);
    _refreshing[base] = f;
    try {
      await f;
    } finally {
      _refreshing.remove(base);
    }
  }

  Future<void> _doRefresh(String base) async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl${Uri.encodeComponent(base)}'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        try {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          if (body['result'] == 'success') {
            final ratesJson = body['rates'] as Map<String, dynamic>;
            _rates[base] = {
              for (final e in ratesJson.entries)
                if (e.value is num) e.key: (e.value as num).toDouble()
            };
            _fetchedAt[base] = DateTime.now();
            await _persist(base);
          }
        } catch (_) {
          // 200 but not the expected JSON shape — fall back to persisted rates.
        }
      }
    } catch (_) {
      // Network unavailable — fall back to persisted rates below.
    }
    if (_rates[base] == null) {
      await _loadPersisted(base);
    }
    notifyListeners();
  }

  /// Converts an exact minor-unit [amount] from [from] currency into [to],
  /// rounded to the nearest minor unit. Falls back to the identity (returns
  /// [amount]) when no rates are known, so reports never crash offline.
  ///
  /// Rates are stored base-to-currency (`_rates[base][other]` = units of
  /// `other` per 1 `base`), so the direct look-up converts into [to]; when that
  /// side is unknown but [from] is a known base, the reciprocal is used instead.
  int convert(int amount, String from, String to) {
    if (from == to) return amount;
    // Always prefer the multiplication path (_rates[from]) for consistency:
    // it uses the rate set fetched for `from` as base, so two conversions
    // that share the same base currency produce identical results.
    final fromRates = _rates[from];
    if (fromRates != null) {
      final rate = fromRates[to];
      if (rate != null && rate > 0) return (amount * rate).round();
    }
    // Fall back to the division path only when `from` isn't a known base
    // but `to` is (so we can derive from/to = 1 / (to/from)).
    final toRates = _rates[to];
    if (toRates != null) {
      final rate = toRates[from];
      if (rate != null && rate > 0) return (amount / rate).round();
    }
    return amount;
  }

  Future<void> _persist(String base) async {
    final cache = _rates[base];
    if (cache == null) return;
    await LocalDB.setSetting('fx_$base', jsonEncode({
          'ts': _fetchedAt[base]!.millisecondsSinceEpoch,
          'rates': cache,
        }));
  }

  Future<void> _loadPersisted(String base) async {
    try {
      final raw = await LocalDB.getSetting('fx_$base');
      if (raw.isEmpty) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final rates = (data['rates'] as Map<String, dynamic>);
      _rates[base] = {
        for (final e in rates.entries)
          if (e.value is num) e.key: (e.value as num).toDouble()
      };
      final ts = data['ts'];
      if (ts is num) {
        _fetchedAt[base] =
            DateTime.fromMillisecondsSinceEpoch(ts.toInt());
      }
    } catch (_) {
      // Corrupt persisted payload — leave rates unknown (1:1 fallback).
    }
  }
}