import 'package:shared_preferences/shared_preferences.dart';
import 'gemini_notification_parser.dart';

class GeminiConfigService {
  static const String _apiKeyKey = 'gemini_api_key';
  static const String _aiEnabledKey = 'ai_parsing_enabled';

  // Save Gemini API key
  static Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, apiKey);
    
    // Initialize Gemini with the new key
    if (apiKey.isNotEmpty) {
      await GeminiNotificationParser.initialize(apiKey);
    }
  }

  // Get saved API key
  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyKey);
  }

  // Check if AI parsing is enabled
  static Future<bool> isAIEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_aiEnabledKey) ?? false;
  }

  // Enable/disable AI parsing
  static Future<void> setAIEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_aiEnabledKey, enabled);
    
    // Initialize Gemini if enabled and API key exists
    if (enabled) {
      final apiKey = await getApiKey();
      if (apiKey != null && apiKey.isNotEmpty) {
        await GeminiNotificationParser.initialize(apiKey);
      }
    }
  }

  // Initialize Gemini with saved API key
  static Future<void> initializeIfNeeded() async {
    final enabled = await isAIEnabled();
    if (enabled) {
      final apiKey = await getApiKey();
      if (apiKey != null && apiKey.isNotEmpty) {
        await GeminiNotificationParser.initialize(apiKey);
      }
    }
  }

  // Clear API key
  static Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiKeyKey);
    await setAIEnabled(false);
  }
}
