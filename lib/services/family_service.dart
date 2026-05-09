import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'user_service.dart';

class FamilyService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Get current user ID
  static String? get currentUserId => _auth.currentUser?.uid;
  
  // Reference to families collection
  static CollectionReference<Map<String, dynamic>> get _familiesRef =>
      _db.collection('families');

  // Generate unique family code
  static String _generateFamilyCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    final codeParts = <String>[];
    
    for (int i = 0; i < 3; i++) {
      String part = '';
      for (int j = 0; j < 3; j++) {
        part += chars[random.nextInt(chars.length)];
      }
      codeParts.add(part);
    }
    
    return codeParts.join('-'); // ABC-123-XYZ
  }

  // Create new family
  static Future<String> createFamily(String familyName) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    // Ensure user document exists
    await UserService.createUserDocument();

    final familyCode = _generateFamilyCode();
    final familyId = 'FAM-$familyCode';

    // Create family document
    await _familiesRef.doc(familyId).set({
      'id': familyId,
      'code': familyCode,
      'name': familyName,
      'members': [userId],
      'createdBy': userId,
      'createdAt': FieldValue.serverTimestamp(),
      'settings': {
        'currency': 'USD',
        'timezone': 'UTC',
      }
    });

    // Update user with familyId using UserService
    await UserService.updateUserFamily(familyId, 'owner');

    return familyCode;
  }

  // Join existing family by code
  static Future<bool> joinFamily(String familyCode) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    // Ensure user document exists
    await UserService.createUserDocument();

    // Clean the code (remove FAM- prefix if present)
    final cleanCode = familyCode.startsWith('FAM-') 
        ? familyCode.substring(4) 
        : familyCode;

    // Find family by code
    final familySnapshot = await _familiesRef
        .where('code', isEqualTo: cleanCode)
        .limit(1)
        .get();

    if (familySnapshot.docs.isEmpty) {
      return false; // Family not found
    }

    final familyDoc = familySnapshot.docs.first;
    final familyId = familyDoc.id;
    final familyData = familyDoc.data();

    // Check if user is already a member
    final currentMembers = List<String>.from(familyData['members'] ?? []);
    if (currentMembers.contains(userId)) {
      return true; // Already a member
    }

    // Add user to family members
    await _familiesRef.doc(familyId).update({
      'members': FieldValue.arrayUnion([userId]),
    });

    // Update user with familyId using UserService
    await UserService.updateUserFamily(familyId, 'member');

    return true;
  }

  // Leave family
  static Future<void> leaveFamily() async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    // Get current user familyId
    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) return; // User not in family

    // Remove user from family members
    await _familiesRef.doc(familyId).update({
      'members': FieldValue.arrayRemove([userId]),
    });

    // Remove familyId from user using UserService
    await UserService.removeUserFromFamily();
  }

  // Get current family data
  static Future<Map<String, dynamic>?> getCurrentFamily() async {
    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) return null;

    final familyDoc = await _familiesRef.doc(familyId).get();
    return familyDoc.data();
  }

  // Stream for current family data
  static Stream<Map<String, dynamic>?> get currentFamilyStream async* {
    // Listen to user document for familyId changes
    await for (final userSnapshot in UserService.currentUserStream) {
      final userData = userSnapshot;
      final familyId = userData?['familyId'] as String?;

      if (familyId == null) {
        yield null;
        continue;
      }

      // Listen to family document
      await for (final familySnapshot in _familiesRef.doc(familyId).snapshots()) {
        yield familySnapshot.data();
      }
    }
  }

  // Get family members
  static Future<List<Map<String, dynamic>>> getFamilyMembers(String familyId) async {
    final familyDoc = await _familiesRef.doc(familyId).get();
    final familyData = familyDoc.data();
    final memberIds = List<String>.from(familyData?['members'] ?? []);

    if (memberIds.isEmpty) return [];

    // Get user details for all members
    final usersSnapshot = await _db
        .collection('users')
        .where(FieldPath.documentId, whereIn: memberIds)
        .get();

    return usersSnapshot.docs.map((doc) => {
      'id': doc.id,
      ...doc.data(),
    }).toList();
  }

  // Update family settings
  static Future<void> updateFamilySettings(Map<String, dynamic> settings) async {
    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) return;

    await _familiesRef.doc(familyId).update({
      'settings': settings,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Check if user is in family
  static Future<bool> isUserInFamily() async {
    return await UserService.isUserInFamily();
  }
}
