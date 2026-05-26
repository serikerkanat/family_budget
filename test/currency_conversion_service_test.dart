import 'package:flutter_test/flutter_test.dart';

import '../lib/services/currency_conversion_service.dart';

void main() {
  group('CurrencyConversionService.convert', () {
    setUp(() {
      // Deterministic rates for the test (base USD = 1).
      CurrencyConversionService.debugSetRates(const {
        'USD': 1.0,
        'KZT': 500.0,
        'RUB': 100.0,
        'EUR': 0.8,
      });
    });

    test('USD -> USD is identity', () {
      expect(CurrencyConversionService.convert(123.45, 'USD', 'USD'),
          closeTo(123.45, 0.0001));
    });

    test('KZT -> USD divides by KZT rate', () {
      expect(CurrencyConversionService.convert(5000, 'KZT', 'USD'),
          closeTo(10.0, 0.0001));
    });

    test('USD -> EUR multiplies by EUR rate', () {
      expect(CurrencyConversionService.convert(100, 'USD', 'EUR'),
          closeTo(80.0, 0.0001));
    });

    test('KZT -> RUB cross conversion via USD', () {
      // 1000 KZT = 2 USD = 200 RUB
      expect(CurrencyConversionService.convert(1000, 'KZT', 'RUB'),
          closeTo(200.0, 0.0001));
    });

    test('case-insensitive currency codes', () {
      expect(CurrencyConversionService.convert(500, 'kzt', 'usd'),
          closeTo(1.0, 0.0001));
    });

    test('unknown currency falls back to bundled rate or 1.0 (no crash)', () {
      // Should not throw.
      final v = CurrencyConversionService.convert(100, 'XYZ', 'USD');
      expect(v, isA<double>());
    });
  });
}
