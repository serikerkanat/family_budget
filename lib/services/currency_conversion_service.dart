import 'dart:async';

class CurrencyConversionService {
  // Exchange rates (base: USD)
  // TODO: In production, fetch from an API
  static const Map<String, double> _exchangeRates = {
    'USD': 1.0,
    'KZT': 450.0,  // Kazakhstani Tenge
    'RUB': 92.0,   // Russian Ruble
    'EUR': 0.92,   // Euro
    'GBP': 0.79,   // British Pound
    'CNY': 7.2,    // Chinese Yuan
  };

  /// Convert amount from source currency to target currency
  static double convert(double amount, String fromCurrency, String toCurrency) {
    final fromRate = _exchangeRates[fromCurrency.toUpperCase()] ?? 1.0;
    final toRate = _exchangeRates[toCurrency.toUpperCase()] ?? 1.0;
    
    // Convert to USD first, then to target currency
    final amountInUSD = amount / fromRate;
    final convertedAmount = amountInUSD * toRate;
    
    return convertedAmount;
  }

  /// Get exchange rate for a currency (relative to USD)
  static double? getExchangeRate(String currency) {
    return _exchangeRates[currency.toUpperCase()];
  }

  /// Check if currency is supported
  static bool isSupported(String currency) {
    return _exchangeRates.containsKey(currency.toUpperCase());
  }

  /// Get list of supported currencies
  static List<String> getSupportedCurrencies() {
    return _exchangeRates.keys.toList();
  }
}
