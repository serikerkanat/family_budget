import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_logger.dart';

/// Currency conversion with live rates fetched from exchangerate.host
/// (free, no API key). Rates are cached for 24h via SharedPreferences and
/// fall back to bundled defaults if the network is unavailable.
class CurrencyConversionService {
  static final _log = AppLogger.log('Currency');

  // Fallback rates (base: USD). Used only if network + cache both fail.
  static const Map<String, double> _fallbackRates = {
    'USD': 1.0,
    'KZT': 500.0,
    'RUB': 92.0,
    'EUR': 0.92,
    'GBP': 0.79,
    'CNY': 7.2,
  };

  static const _cacheKeyRates = 'currency_rates_cache_v1';
  static const _cacheKeyTimestamp = 'currency_rates_cache_ts_v1';
  static const Duration _cacheTtl = Duration(hours: 24);
  static const String _endpoint =
      'https://api.exchangerate.host/latest?base=USD';

  static Map<String, double> _rates = Map.from(_fallbackRates);
  static bool _loaded = false;
  static Future<void>? _inflight;

  /// Initialize rates from cache and trigger background refresh if stale.
  /// Safe to call multiple times.
  static Future<void> ensureLoaded() {
    return _inflight ??= _loadInternal();
  }

  static Future<void> _loadInternal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKeyRates);
      final cachedTs = prefs.getInt(_cacheKeyTimestamp) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - cachedTs;

      if (cachedJson != null) {
        try {
          final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
          _rates = decoded
              .map((k, v) => MapEntry(k, (v as num).toDouble()));
          _loaded = true;
        } catch (e) {
          _log.warning('Bad cached rates, ignoring', e);
        }
      }

      if (!_loaded || age > _cacheTtl.inMilliseconds) {
        await _fetchAndCache(prefs);
      }
    } catch (e) {
      _log.warning('Failed to load currency rates, using fallback', e);
    }
  }

  static Future<void> _fetchAndCache(SharedPreferences prefs) async {
    try {
      final res = await http
          .get(Uri.parse(_endpoint))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        _log.warning('Rates HTTP ${res.statusCode}');
        return;
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final ratesRaw = body['rates'] as Map<String, dynamic>?;
      if (ratesRaw == null) return;
      final parsed = <String, double>{'USD': 1.0};
      ratesRaw.forEach((k, v) {
        if (v is num) parsed[k.toUpperCase()] = v.toDouble();
      });
      if (parsed.length < 5) return; // sanity check
      _rates = parsed;
      _loaded = true;
      await prefs.setString(_cacheKeyRates, jsonEncode(parsed));
      await prefs.setInt(
          _cacheKeyTimestamp, DateTime.now().millisecondsSinceEpoch);
      _log.info('Refreshed ${parsed.length} currency rates');
    } catch (e) {
      _log.warning('Network rates fetch failed', e);
    }
  }

  /// Convert amount from source currency to target currency.
  /// Synchronous: uses whatever rates are currently loaded (cache/fallback).
  /// Call [ensureLoaded] at app start to get live rates.
  static double convert(double amount, String fromCurrency, String toCurrency) {
    final from = fromCurrency.toUpperCase();
    final to = toCurrency.toUpperCase();
    final fromRate = _rates[from] ?? _fallbackRates[from] ?? 1.0;
    final toRate = _rates[to] ?? _fallbackRates[to] ?? 1.0;
    final amountInUSD = amount / fromRate;
    return amountInUSD * toRate;
  }

  /// Async variant that ensures rates are loaded before converting.
  static Future<double> convertAsync(
      double amount, String fromCurrency, String toCurrency) async {
    await ensureLoaded();
    return convert(amount, fromCurrency, toCurrency);
  }

  static double? getExchangeRate(String currency) =>
      _rates[currency.toUpperCase()];

  static bool isSupported(String currency) =>
      _rates.containsKey(currency.toUpperCase()) ||
      _fallbackRates.containsKey(currency.toUpperCase());

  static List<String> getSupportedCurrencies() => _rates.keys.toList();

  /// For testing only.
  static void debugSetRates(Map<String, double> rates) {
    _rates = Map.from(rates);
    _loaded = true;
  }
}

