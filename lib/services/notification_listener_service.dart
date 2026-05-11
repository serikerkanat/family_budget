import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';

class BankingNotificationData {
  final String packageName;
  final String title;
  final String text;
  final int timestamp;
  final String bankName;
  final double? amount;
  final String? currency;
  final String? merchant;
  final String? type; // "expense" or "income"
  final String? cardLastDigits;

  BankingNotificationData({
    required this.packageName,
    required this.title,
    required this.text,
    required this.timestamp,
    required this.bankName,
    this.amount,
    this.currency,
    this.merchant,
    this.type,
    this.cardLastDigits,
  });

  factory BankingNotificationData.fromJson(Map<String, dynamic> json) {
    return BankingNotificationData(
      packageName: json['packageName'] ?? '',
      title: json['title'] ?? '',
      text: json['text'] ?? '',
      timestamp: json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      bankName: json['bankName'] ?? 'Unknown',
      amount: json['amount'] != null ? (json['amount'] as num).toDouble() : null,
      currency: json['currency'],
      merchant: json['merchant'],
      type: json['type'],
      cardLastDigits: json['cardLastDigits'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'packageName': packageName,
      'title': title,
      'text': text,
      'timestamp': timestamp,
      'bankName': bankName,
      'amount': amount,
      'currency': currency,
      'merchant': merchant,
      'type': type,
      'cardLastDigits': cardLastDigits,
    };
  }

  @override
  String toString() {
    return 'BankingNotificationData{bankName: $bankName, amount: $amount $currency, merchant: $merchant, type: $type}';
  }
}

class NotificationListenerService {
  static const MethodChannel _channel = MethodChannel('com.example.family_budget_flutter/notifications');
  static const EventChannel _eventChannel = EventChannel('com.example.family_budget_flutter/notification_events');
  
  static Stream<BankingNotificationData>? _notificationStream;
  static bool _isListening = false;

  /// Check if notification listener permission is granted
  static Future<bool> isPermissionGranted() async {
    try {
      final bool result = await _channel.invokeMethod('isPermissionGranted');
      return result;
    } on PlatformException catch (e) {
      print('Error checking permission: ${e.message}');
      return false;
    }
  }

  /// Open notification listener settings for the user to grant permission
  static Future<void> openPermissionSettings() async {
    try {
      await _channel.invokeMethod('openPermissionSettings');
    } on PlatformException catch (e) {
      print('Error opening settings: ${e.message}');
      rethrow;
    }
  }

  /// Start listening for banking notifications
  static Stream<BankingNotificationData> startListening() {
    if (_isListening && _notificationStream != null) {
      return _notificationStream!;
    }

    _notificationStream = _eventChannel
        .receiveBroadcastStream()
        .map((dynamic event) {
      final String jsonString = event as String;
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      return BankingNotificationData.fromJson(jsonData);
    });

    _isListening = true;
    return _notificationStream!;
  }

  /// Stop listening for notifications
  static void stopListening() {
    _isListening = false;
    _notificationStream = null;
  }

  /// Check if currently listening
  static bool get isListening => _isListening;

  /// Get stream of banking notifications
  static Stream<BankingNotificationData>? get notificationStream => 
      _isListening ? _notificationStream : null;
}
