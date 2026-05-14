import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/transaction_model.dart';
import 'notification_listener_service.dart';

class GeminiParsedTransaction {
  final double amount;
  final String currency;
  final String? merchant;
  final TransactionType type;
  final String? cardLastDigits;
  final String bankName;
  final DateTime date;
  final String rawTitle;
  final String rawText;
  final String suggestedCategory;
  final String confidence;

  GeminiParsedTransaction({
    required this.amount,
    required this.currency,
    this.merchant,
    required this.type,
    this.cardLastDigits,
    required this.bankName,
    required this.date,
    required this.rawTitle,
    required this.rawText,
    required this.suggestedCategory,
    required this.confidence,
  });

  TransactionModel toTransactionModel(String categoryId) {
    return TransactionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: merchant ?? 'Transaction from $bankName',
      amount: amount,
      date: date,
      type: type,
      categoryId: categoryId,
      notes: 'AI-parsed from $bankName notification (Confidence: $confidence)',
      currency: currency,
    );
  }
}

class GeminiNotificationParser {
  static GenerativeModel? _model;
  static bool _isInitialized = false;

  // Initialize Gemini with API key
  // User needs to set their API key in Firebase Remote Config or environment
  static Future<void> initialize(String apiKey) async {
    if (_isInitialized) return;
    
    try {
      _model = GenerativeModel(
        model: 'gemini-pro',
        apiKey: apiKey,
      );
      _isInitialized = true;
    } catch (e) {
      print('Failed to initialize Gemini: $e');
      _isInitialized = false;
    }
  }

  // Parse notification using Gemini AI
  static Future<GeminiParsedTransaction?> parseWithAI(
    BankingNotificationData notification,
  ) async {
    if (!_isInitialized || _model == null) {
      print('Gemini not initialized, falling back to rule-based parser');
      return null;
    }

    if (notification.amount == null) {
      return null;
    }

    try {
      // Construct the prompt for Gemini
      final prompt = _buildParsingPrompt(notification);

      // Generate response from Gemini
      final response = await _model!.generateContent([
        Content.text(prompt),
      ]);

      final responseText = response.text ?? '';
      
      // Parse the JSON response from Gemini
      return _parseGeminiResponse(responseText, notification);
    } catch (e) {
      print('Error parsing with Gemini: $e');
      return null;
    }
  }

  static String _buildParsingPrompt(BankingNotificationData notification) {
    return '''
You are a financial transaction parser. Extract transaction details from the following bank notification.

Bank Notification:
Title: "${notification.title}"
Text: "${notification.text}"
Bank: "${notification.bankName}"
Amount: ${notification.amount}
Currency: ${notification.currency ?? 'KZT'}
Timestamp: ${notification.timestamp}

Extract the following information and return ONLY valid JSON:
{
  "amount": number (the transaction amount),
  "currency": string (currency code like KZT, USD, RUB),
  "merchant": string or null (merchant name, e.g., "Kaspi Store", "Starbucks"),
  "type": "income" or "expense" (determine if this is money coming in or going out),
  "cardLastDigits": string or null (last 4 digits of card if mentioned),
  "suggestedCategory": string (one of: food, transport, shopping, entertainment, bills, healthcare, education, travel, other),
  "confidence": string (high, medium, or low based on how confident you are in this parsing)
}

Rules:
- If the notification mentions "зачисление", "поступление", "income", "cashback", "кэшбэк" - it's income
- If the notification mentions "покупка", "списание", "payment", "purchase" - it's expense
- For Kazakhstani banks (Kaspi, Halyk, etc.), understand both Russian and Kazakh text
- Be conservative with confidence - if unsure, mark as "low"
- Return ONLY the JSON, no additional text
''';
  }

  static GeminiParsedTransaction _parseGeminiResponse(
    String responseText,
    BankingNotificationData notification,
  ) {
    try {
      // Extract JSON from response (in case there's extra text)
      final jsonStart = responseText.indexOf('{');
      final jsonEnd = responseText.lastIndexOf('}');
      
      if (jsonStart == -1 || jsonEnd == -1) {
        throw Exception('No JSON found in response');
      }

      final jsonString = responseText.substring(jsonStart, jsonEnd + 1);
      
      // Parse JSON (simple implementation - in production use dart:convert)
      final amount = _extractDouble(jsonString, '"amount"');
      final currency = _extractString(jsonString, '"currency"') ?? 'KZT';
      final merchant = _extractString(jsonString, '"merchant"');
      final typeStr = _extractString(jsonString, '"type"') ?? 'expense';
      final cardLastDigits = _extractString(jsonString, '"cardLastDigits"');
      final suggestedCategory = _extractString(jsonString, '"suggestedCategory"') ?? 'other';
      final confidence = _extractString(jsonString, '"confidence"') ?? 'medium';

      final type = typeStr.toLowerCase() == 'income' 
          ? TransactionType.income 
          : TransactionType.expense;

      return GeminiParsedTransaction(
        amount: amount,
        currency: currency,
        merchant: merchant,
        type: type,
        cardLastDigits: cardLastDigits,
        bankName: notification.bankName,
        date: DateTime.fromMillisecondsSinceEpoch(notification.timestamp),
        rawTitle: notification.title,
        rawText: notification.text,
        suggestedCategory: suggestedCategory,
        confidence: confidence,
      );
    } catch (e) {
      print('Error parsing Gemini response: $e');
      rethrow;
    }
  }

  // Helper to extract string value from JSON
  static String? _extractString(String json, String key) {
    final pattern = '$key:"([^"]*)"';
    final regex = RegExp(pattern);
    final match = regex.firstMatch(json);
    return match?.group(1);
  }

  // Helper to extract double value from JSON
  static double _extractDouble(String json, String key) {
    final pattern = '$key:([0-9.]+)';
    final regex = RegExp(pattern);
    final match = regex.firstMatch(json);
    return match != null ? double.tryParse(match.group(1)!) ?? 0.0 : 0.0;
  }

  // Check if Gemini is available and initialized
  static bool get isAvailable => _isInitialized && _model != null;

  // Get supported banks (same as rule-based parser)
  static List<String> getSupportedBanks() {
    return [
      'Kaspi',
      'Halyk Bank',
      'Eurasian Bank',
      'ForteBank',
      'Jysan Bank',
      'Altyn Bank',
      'CenterCredit Bank',
      'Bank RBK',
      'ATF Bank',
      'Tengri Bank',
      'Sberbank',
      'Tinkoff',
      'Alfa Bank',
      'VTB',
      'Gazprombank',
      'Raiffeisen',
      'Otkritie',
    ];
  }
}
