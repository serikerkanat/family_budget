import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import 'gemini_config_service.dart';

/// One line on a receipt extracted by Gemini Vision.
class ReceiptLineItem {
  final String name;
  final double amount;
  final int? quantity;

  /// One of: food, transport, shopping, entertainment, bills, healthcare,
  /// education, travel, other.
  final String suggestedCategory;

  ReceiptLineItem({
    required this.name,
    required this.amount,
    this.quantity,
    this.suggestedCategory = 'other',
  });

  ReceiptLineItem copyWith({
    String? name,
    double? amount,
    int? quantity,
    String? suggestedCategory,
  }) =>
      ReceiptLineItem(
        name: name ?? this.name,
        amount: amount ?? this.amount,
        quantity: quantity ?? this.quantity,
        suggestedCategory: suggestedCategory ?? this.suggestedCategory,
      );
}

/// The full structured result of a receipt scan.
class ReceiptScanResult {
  final String? merchant;
  final double total;
  final String currency;
  final DateTime? date;
  final List<ReceiptLineItem> items;
  final String confidence; // high | medium | low
  final String? rawJson;

  ReceiptScanResult({
    required this.merchant,
    required this.total,
    required this.currency,
    required this.date,
    required this.items,
    required this.confidence,
    this.rawJson,
  });
}

/// Sends a receipt image to Gemini Vision and returns structured data.
///
/// The Gemini API key must already be configured by the user via
/// [GeminiConfigService.saveApiKey] (Settings → AI). When no key is
/// available [ReceiptOcrService.isAvailable] is false and the UI should
/// prompt the user to set one.
class ReceiptOcrService {
  static const _modelName = 'gemini-2.5-flash-lite';

  static Future<bool> isAvailable() async {
    final key = await GeminiConfigService.getApiKey();
    return key != null && key.trim().isNotEmpty;
  }

  /// Analyze a receipt image and return structured data, or throw on error.
  ///
  /// [defaultCurrency] is used when Gemini cannot detect the currency in
  /// the receipt (e.g. the user's family currency).
  static Future<ReceiptScanResult> scan(
    File image, {
    String defaultCurrency = 'KZT',
  }) async {
    final apiKey = await GeminiConfigService.getApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const ReceiptOcrException(
        'Gemini API key is not configured. Set it in Settings → AI.',
      );
    }

    final model = GenerativeModel(
      model: _modelName,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.1,
        responseMimeType: 'application/json',
      ),
    );

    final bytes = await image.readAsBytes();
    final mime = _guessMime(image.path);

    final prompt = _buildPrompt(defaultCurrency);

    final response = await model.generateContent([
      Content.multi([
        TextPart(prompt),
        DataPart(mime, bytes),
      ]),
    ]).timeout(const Duration(seconds: 30));

    final text = response.text ?? '';
    if (text.trim().isEmpty) {
      throw const ReceiptOcrException(
          'Gemini returned an empty response. Try a clearer photo.');
    }

    return _parseResponse(text, defaultCurrency);
  }

  // ---------- internals ----------

  static String _buildPrompt(String defaultCurrency) {
    return '''
You are a precise receipt OCR assistant for a family budgeting app used in
Kazakhstan and Russia. The image attached is a paper or screenshot receipt
in Russian, Kazakh, or English.

Extract structured data and respond with ONLY valid JSON matching this schema:

{
  "merchant": string | null,                // store / vendor name
  "total": number,                          // grand total paid
  "currency": string,                       // ISO code: KZT, RUB, USD, EUR, GBP, CNY
  "date": string | null,                    // ISO 8601 date "YYYY-MM-DD" if visible
  "items": [
    {
      "name": string,
      "amount": number,                     // line subtotal (qty * price)
      "quantity": number | null,
      "suggestedCategory": string           // one of: food, transport, shopping,
                                            // entertainment, bills, healthcare,
                                            // education, travel, other
    }
  ],
  "confidence": "high" | "medium" | "low"
}

Rules:
- If the currency symbol is "₸" or text "тг" / "тенге" -> "KZT".
- If "₽" or "руб" -> "RUB".
- If you cannot detect a currency confidently, use "$defaultCurrency".
- "total" must be the final amount paid (after discounts), not subtotal.
- Skip non-purchase lines (subtotal, tax labels, "ИТОГО", change, card mask).
- For groceries, restaurants, cafes, fast food -> "food".
- For pharmacies, clinics -> "healthcare".
- For utilities, internet, mobile -> "bills".
- Be conservative on confidence: pick "low" if the image is blurry or partial.
- Return ONLY the JSON. No markdown fences, no comments.
''';
  }

  static ReceiptScanResult _parseResponse(
    String text,
    String defaultCurrency,
  ) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      throw const ReceiptOcrException('Gemini returned non-JSON output.');
    }
    final jsonStr = text.substring(start, end + 1);

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      throw ReceiptOcrException('Invalid JSON from Gemini: $e');
    }

    final merchant = (data['merchant'] as String?)?.trim();
    final totalRaw = data['total'];
    final total = totalRaw is num
        ? totalRaw.toDouble()
        : double.tryParse(totalRaw?.toString() ?? '') ?? 0.0;

    final currency = (data['currency'] as String?)?.trim().toUpperCase();
    final dateStr = (data['date'] as String?)?.trim();
    DateTime? date;
    if (dateStr != null && dateStr.isNotEmpty) {
      date = DateTime.tryParse(dateStr);
    }

    final rawItems = (data['items'] as List?) ?? const [];
    final items = <ReceiptLineItem>[];
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final name = (raw['name'] as String?)?.trim();
      final amountRaw = raw['amount'];
      if (name == null || name.isEmpty) continue;
      final amount = amountRaw is num
          ? amountRaw.toDouble()
          : double.tryParse(amountRaw?.toString() ?? '') ?? 0.0;
      if (amount <= 0) continue;
      final qtyRaw = raw['quantity'];
      final qty = qtyRaw is num ? qtyRaw.toInt() : null;
      final cat = (raw['suggestedCategory'] as String?)?.trim().toLowerCase();
      items.add(ReceiptLineItem(
        name: name,
        amount: amount,
        quantity: qty,
        suggestedCategory: (cat == null || cat.isEmpty) ? 'other' : cat,
      ));
    }

    final confidence =
        (data['confidence'] as String?)?.trim().toLowerCase() ?? 'medium';

    if (kDebugMode) {
      debugPrint(
          '[ReceiptOCR] merchant=$merchant total=$total $currency items=${items.length} conf=$confidence');
    }

    return ReceiptScanResult(
      merchant: (merchant == null || merchant.isEmpty) ? null : merchant,
      total: total,
      currency: (currency == null || currency.isEmpty)
          ? defaultCurrency.toUpperCase()
          : currency,
      date: date,
      items: items,
      confidence: confidence,
      rawJson: jsonStr,
    );
  }

  static String _guessMime(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }
}

class ReceiptOcrException implements Exception {
  final String message;
  const ReceiptOcrException(this.message);

  @override
  String toString() => message;
}
