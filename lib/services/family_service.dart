import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'user_service.dart';
import '../models/role_model.dart';

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
    if (userId == null) throw Exception('User not logged in');

    try {
      print('Creating family for user: $userId');

      // Ensure user document exists and get user data
      await UserService.createUserDocument();
      final userData = await UserService.getCurrentUserData();
      print('User data: $userData');

      final familyDoc = await _db.collection('families').add({
        'name': familyName,
        'code': _generateFamilyCode(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': userId,
        'members': [userId],
      });

      print('Family created with ID: ${familyDoc.id}');

      // Update user to be the family creator (parent role)
      await _db.collection('users').doc(userId).update({
        'familyId': familyDoc.id,
        'role': 'parent', // Creator is always parent
        'joinedAt': FieldValue.serverTimestamp(),
      });

      print('User updated with familyId and parent role');

      return familyDoc.id;
    } catch (e) {
      print('Error creating family: $e');
      rethrow;
    }
  }

  // Join existing family by code with role selection
  static Future<bool> joinFamily(String familyCode, {UserRole role = UserRole.child}) async {
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
    await UserService.updateUserFamily(familyId, role.value);

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
    final familyData = familyDoc.data();
    
    // Добавляем ID в данные семьи
    if (familyData != null) {
      familyData['id'] = familyId;
    }
    
    return familyData;
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
        final familyData = familySnapshot.data();
        // Добавляем ID в данные семьи
        if (familyData != null) {
          familyData['id'] = familyId;
        }
        yield familyData;
      }
    }
  }

  // Get family members
  static Future<List<Map<String, dynamic>>> getFamilyMembers(String familyId) async {
    try {
      print('=== Getting family members for familyId: $familyId ===');
      
      // Get current user ID first
      final FirebaseAuth auth = FirebaseAuth.instance;
      final currentUserId = auth.currentUser?.uid;
      if (currentUserId == null) {
        print('No current user found');
        return [];
      }
      
      print('Current user ID: $currentUserId');
      
      // First verify user exists and has familyId
      final currentUserDoc = await _db.collection('users').doc(currentUserId).get();
      if (!currentUserDoc.exists) {
        print('Current user document does not exist');
        return [];
      }
      
      final currentUserData = currentUserDoc.data();
      final userFamilyId = currentUserData?['familyId'] as String?;
      print('User familyId from user doc: $userFamilyId');
      print('Requested familyId: $familyId');
      
      if (userFamilyId != familyId) {
        print('User does not belong to this family!');
        print('User belongs to family: $userFamilyId');
        return [];
      }
      
      final familyDoc = await _familiesRef.doc(familyId).get();
      if (!familyDoc.exists) {
        print('Family document does not exist');
        return [];
      }
      
      final familyData = familyDoc.data();
      final memberIds = List<String>.from(familyData?['members'] ?? []);
      print('Member IDs from family doc: $memberIds');
      print('Current user in family members: ${memberIds.contains(currentUserId)}');

      if (memberIds.isEmpty) {
        print('No member IDs found');
        return [];
      }

      print('Starting to fetch individual user documents...');
      List<Map<String, dynamic>> members = [];
      
      // Get each user individually to avoid whereIn issues
      for (final memberId in memberIds) {
        try {
          print('Fetching user: $memberId');
          final userDoc = await _db.collection('users').doc(memberId).get();
          
          if (userDoc.exists) {
            final data = userDoc.data() ?? {};
            print('Raw user data for $memberId: $data');
            
            final member = {
              'id': userDoc.id,
              'email': data['email'] ?? 'No Email',
              'displayName': data['displayName'] ?? data['name'] ?? 'Unknown User',
              'role': data['role'] ?? 'child',
              'joinedAt': data['joinedAt'],
              ...data,
            };
            members.add(member);
            print('Successfully added member: ${member['id']} - ${member['email']} - Role: ${member['role']}');
          } else {
            print('User document does not exist for ID: $memberId');
          }
        } catch (e) {
          print('Error getting user $memberId: $e');
        }
      }

      print('Final members list: $members');
      print('Total members count: ${members.length}');
      
      // Debug: check if current user is in the list
      final currentUserInList = members.any((member) => member['id'] == currentUserId);
      print('Current user found in members list: $currentUserInList');
      
      return members;
    } catch (e) {
      print('Error getting family members: $e');
      return [];
    }
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

  // Update member role (only for parents)
  static Future<void> updateMemberRole(String userId, UserRole newRole) async {
    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) throw Exception('User not in family');

    // Check if current user is a parent
    final currentUserRole = await UserService.getCurrentUserData();
    final currentRole = currentUserRole?['role'] as String?;
    if (currentRole != 'parent' && currentRole != 'owner') {
      throw Exception('Only parents can change member roles');
    }

    // Update the member's role
    await _db.collection('users').doc(userId).update({
      'role': newRole.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Remove member from family (only for parents)
  static Future<void> removeMember(String userId) async {
    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) throw Exception('User not in family');

    // Check if current user is a parent
    final currentUserRole = await UserService.getCurrentUserData();
    final currentRole = currentUserRole?['role'] as String?;
    if (currentRole != 'parent' && currentRole != 'owner') {
      throw Exception('Only parents can remove members');
    }

    // Remove user from family members
    await _familiesRef.doc(familyId).update({
      'members': FieldValue.arrayRemove([userId]),
    });

    // Remove familyId from user
    await _db.collection('users').doc(userId).update({
      'familyId': FieldValue.delete(),
      'role': FieldValue.delete(),
      'joinedAt': FieldValue.delete(),
    });
  }
}
