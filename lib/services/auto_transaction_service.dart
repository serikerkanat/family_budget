import 'dart:async';
import 'package:flutter/foundation.dart';
import 'notification_listener_service.dart';
import 'firestore_service.dart';
import 'notification_permission_service.dart';

class AutoTransactionService {
  static StreamSubscription<BankingNotificationData>? _subscription;
  static bool _isRunning = false;

  /// Start automatic transaction import from notifications
  static Future<void> start() async {
    if (_isRunning) {
      debugPrint('Auto transaction service is already running');
      return;
    }

    // Check if notification tracking is enabled
    final isEnabled = await NotificationPermissionService.isNotificationTrackingEnabled();
    if (!isEnabled) {
      debugPrint('Notification tracking is disabled');
      return;
    }

    // Check permission
    final hasPermission = await NotificationPermissionService.hasNotificationPermission();
    if (!hasPermission) {
      debugPrint('Notification permission not granted');
      return;
    }

    debugPrint('Starting auto transaction service');

    // Start listening for notifications
    final stream = NotificationListenerService.startListening();
    
    _subscription = stream.listen(
      _handleNotification,
      onError: (error) {
        debugPrint('Error in notification stream: $error');
      },
      onDone: () {
        debugPrint('Notification stream closed');
        _isRunning = false;
      },
    );

    _isRunning = true;
    debugPrint('Auto transaction service started');
  }

  /// Stop automatic transaction import
  static void stop() {
    if (_subscription != null) {
      _subscription!.cancel();
      _subscription = null;
    }
    NotificationListenerService.stopListening();
    _isRunning = false;
    debugPrint('Auto transaction service stopped');
  }

  /// Check if service is running
  static bool get isRunning => _isRunning;

  /// Handle incoming notification
  static Future<void> _handleNotification(BankingNotificationData notification) async {
    debugPrint('Received notification: ${notification.bankName} - ${notification.amount} ${notification.currency}');

    try {
      // Add to Firestore (FirestoreService will handle both AI and rule-based parsing)
      await FirestoreService.addTransactionFromNotification(notification);
      debugPrint('Transaction added successfully');
    } catch (e) {
      debugPrint('Error adding transaction: $e');
    }
  }

  /// Restart the service (useful when settings change)
  static Future<void> restart() async {
    stop();
    await Future.delayed(const Duration(milliseconds: 500));
    await start();
  }
}
