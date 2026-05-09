import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Get current user ID
  static String? get currentUserId => _auth.currentUser?.uid;
  
  // Reference to users collection
  static CollectionReference<Map<String, dynamic>> get _usersRef =>
      _db.collection('users');

  // Create user document after registration
  static Future<void> createUserDocument() async {
    final userId = currentUserId;
    final currentUser = _auth.currentUser;
    
    if (userId == null || currentUser == null) {
      throw Exception('User not authenticated');
    }

    // Check if user document already exists
    final userDoc = await _usersRef.doc(userId).get();
    
    if (!userDoc.exists) {
      // Create new user document
      await _usersRef.doc(userId).set({
        'id': userId,
        'email': currentUser.email,
        'displayName': currentUser.displayName ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'familyId': null, // Will be set when joining/creating family
        'role': null,
        'joinedAt': null,
        'settings': {
          'currency': 'USD',
          'timezone': 'UTC',
          'notifications': true,
        }
      });
    } else {
      // Update last login
      await _usersRef.doc(userId).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Update user with family information
  static Future<void> updateUserFamily(String familyId, String role) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    await _usersRef.doc(userId).update({
      'familyId': familyId,
      'role': role,
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }

  // Remove user from family
  static Future<void> removeUserFromFamily() async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    await _usersRef.doc(userId).update({
      'familyId': FieldValue.delete(),
      'role': FieldValue.delete(),
      'joinedAt': FieldValue.delete(),
    });
  }

  // Get current user data
  static Future<Map<String, dynamic>?> getCurrentUserData() async {
    final userId = currentUserId;
    if (userId == null) return null;

    final userDoc = await _usersRef.doc(userId).get();
    return userDoc.data();
  }

  // Stream for current user data
  static Stream<Map<String, dynamic>?> get currentUserStream {
    final userId = currentUserId;
    if (userId == null) return Stream.value(null);

    return _usersRef.doc(userId).snapshots().map((doc) => doc.data());
  }

  // Check if user is in family
  static Future<bool> isUserInFamily() async {
    final userData = await getCurrentUserData();
    return userData?['familyId'] != null;
  }

  // Get user's family ID
  static Future<String?> getUserFamilyId() async {
    final userData = await getCurrentUserData();
    return userData?['familyId'] as String?;
  }

  // Update user settings
  static Future<void> updateUserSettings(Map<String, dynamic> settings) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    await _usersRef.doc(userId).update({
      'settings': settings,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
