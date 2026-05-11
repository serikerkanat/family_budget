import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/role_model.dart';
import 'user_service.dart';
import 'family_service.dart';
import 'notification_listener_service.dart';
import 'bank_notification_parser.dart';

class NotificationTrackingSettings {
  final bool enabled;
  final List<String> enabledBanks;
  final Map<String, String> categoryRules;
  final DateTime? lastSync;

  NotificationTrackingSettings({
    required this.enabled,
    required this.enabledBanks,
    required this.categoryRules,
    this.lastSync,
  });

  factory NotificationTrackingSettings.fromJson(Map<String, dynamic> json) {
    return NotificationTrackingSettings(
      enabled: json['enabled'] ?? false,
      enabledBanks: List<String>.from(json['enabledBanks'] ?? []),
      categoryRules: Map<String, String>.from(json['categoryRules'] ?? {}),
      lastSync: json['lastSync'] != null 
          ? (json['lastSync'] as Timestamp).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'enabledBanks': enabledBanks,
      'categoryRules': categoryRules,
      'lastSync': lastSync != null ? Timestamp.fromDate(lastSync!) : null,
    };
  }
}

class NotificationPermissionService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Check if current user can manage notification settings (parent only)
  static Future<bool> canManageNotificationSettings() async {
    final userData = await UserService.getCurrentUserData();
    if (userData == null) return false;

    final role = userData['role'] as String?;
    return role == 'parent' || role == 'owner';
  }

  /// Enable notification tracking (parent only)
  static Future<void> enableNotificationTracking() async {
    if (!await canManageNotificationSettings()) {
      throw Exception('Only parents can enable notification tracking');
    }

    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) throw Exception('User not in family');

    await _db
        .collection('families')
        .doc(familyId)
        .collection('settings')
        .doc('notificationTracking')
        .set({
          'enabled': true,
          'enabledBanks': BankNotificationParser.getSupportedBanks(),
          'categoryRules': {},
          'lastSync': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  /// Disable notification tracking (parent only)
  static Future<void> disableNotificationTracking() async {
    if (!await canManageNotificationSettings()) {
      throw Exception('Only parents can disable notification tracking');
    }

    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) throw Exception('User not in family');

    await _db
        .collection('families')
        .doc(familyId)
        .collection('settings')
        .doc('notificationTracking')
        .update({
          'enabled': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  /// Check if notification tracking is enabled for the family
  static Future<bool> isNotificationTrackingEnabled() async {
    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) return false;

    final doc = await _db
        .collection('families')
        .doc(familyId)
        .collection('settings')
        .doc('notificationTracking')
        .get();

    if (!doc.exists) return false;

    final data = doc.data();
    return data?['enabled'] ?? false;
  }

  /// Get notification tracking settings
  static Future<NotificationTrackingSettings?> getNotificationSettings() async {
    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) return null;

    final doc = await _db
        .collection('families')
        .doc(familyId)
        .collection('settings')
        .doc('notificationTracking')
        .get();

    if (!doc.exists) return null;

    return NotificationTrackingSettings.fromJson(doc.data()!);
  }

  /// Update enabled banks (parent only)
  static Future<void> updateEnabledBanks(List<String> banks) async {
    if (!await canManageNotificationSettings()) {
      throw Exception('Only parents can update enabled banks');
    }

    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) throw Exception('User not in family');

    await _db
        .collection('families')
        .doc(familyId)
        .collection('settings')
        .doc('notificationTracking')
        .update({
          'enabledBanks': banks,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  /// Update category rules (parent only)
  static Future<void> updateCategoryRules(Map<String, String> rules) async {
    if (!await canManageNotificationSettings()) {
      throw Exception('Only parents can update category rules');
    }

    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) throw Exception('User not in family');

    await _db
        .collection('families')
        .doc(familyId)
        .collection('settings')
        .doc('notificationTracking')
        .update({
          'categoryRules': rules,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  /// Stream for notification tracking settings
  static Stream<NotificationTrackingSettings?> get notificationSettingsStream async* {
    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) {
      yield null;
      return;
    }

    yield* _db
        .collection('families')
        .doc(familyId)
        .collection('settings')
        .doc('notificationTracking')
        .snapshots()
        .map((doc) => doc.exists ? NotificationTrackingSettings.fromJson(doc.data()!) : null);
  }

  /// Update last sync timestamp
  static Future<void> updateLastSync() async {
    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) return;

    await _db
        .collection('families')
        .doc(familyId)
        .collection('settings')
        .doc('notificationTracking')
        .update({
          'lastSync': FieldValue.serverTimestamp(),
        });
  }

  /// Check if user has granted notification listener permission
  static Future<bool> hasNotificationPermission() async {
    return await NotificationListenerService.isPermissionGranted();
  }

  /// Request notification listener permission (opens settings)
  static Future<void> requestNotificationPermission() async {
    await NotificationListenerService.openPermissionSettings();
  }
}
