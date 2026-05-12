import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/savings_goal_model.dart';
import 'user_service.dart';

class SavingsGoalService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Get current user ID
  static String? get currentUserId => _auth.currentUser?.uid;

  // Get all savings goals for current family
  static Stream<List<SavingsGoalModel>> getSavingsGoals() {
    return UserService.currentUserStream.asyncMap(
      (userSnapshot) async {
        final userData = userSnapshot;
        final familyId = userData?['familyId'] as String?;
        
        if (familyId == null) {
          return <SavingsGoalModel>[];
        }
        
        final goalsSnapshot = await _db
            .collection('savings_goals')
            .where('familyId', isEqualTo: familyId)
            .orderBy('targetDate', descending: false)
            .get();
            
        return goalsSnapshot.docs
            .map((doc) => SavingsGoalModel.fromFirestore(doc))
            .toList();
      },
    );
  }

  // Create new savings goal
  static Future<void> createSavingsGoal(SavingsGoalModel goal) async {
    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) throw Exception('User not in family');
    
    await _db.collection('savings_goals').add(goal.toFirestore());
  }

  // Update savings goal
  static Future<void> updateSavingsGoal(SavingsGoalModel goal) async {
    await _db.collection('savings_goals').doc(goal.id).update({
      'currentAmount': goal.currentAmount,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Add money to savings goal
  static Future<void> addToSavingsGoal(String goalId, double amount) async {
    final goalDoc = await _db.collection('savings_goals').doc(goalId).get();
    if (!goalDoc.exists) throw Exception('Goal not found');
    
    final currentData = goalDoc.data() as Map<String, dynamic>;
    final currentAmount = (currentData['currentAmount'] as num?)?.toDouble() ?? 0.0;
    
    await _db.collection('savings_goals').doc(goalId).update({
      'currentAmount': currentAmount + amount,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete savings goal
  static Future<void> deleteSavingsGoal(String goalId) async {
    await _db.collection('savings_goals').doc(goalId).delete();
  }

  // Get savings summary for analytics
  static Future<Map<String, dynamic>> getSavingsSummary() async {
    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) return {};

    final goalsSnapshot = await _db
        .collection('savings_goals')
        .where('familyId', isEqualTo: familyId)
        .get();

    double totalTarget = 0;
    double totalSaved = 0;
    int achievedGoals = 0;
    int overdueGoals = 0;

    for (final doc in goalsSnapshot.docs) {
      final goal = SavingsGoalModel.fromFirestore(doc);
      totalTarget += goal.targetAmount;
      totalSaved += goal.currentAmount;
      if (goal.isAchieved) achievedGoals++;
      if (goal.isOverdue) overdueGoals++;
    }

    return {
      'totalTarget': totalTarget,
      'totalSaved': totalSaved,
      'totalRemaining': totalTarget - totalSaved,
      'achievedGoals': achievedGoals,
      'overdueGoals': overdueGoals,
      'totalGoals': goalsSnapshot.docs.length,
      'overallProgress': totalTarget > 0 ? (totalSaved / totalTarget) * 100 : 0,
    };
  }

  // Get goals by category
  static Future<List<SavingsGoalModel>> getGoalsByCategory(String category) async {
    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) return [];

    final goalsSnapshot = await _db
        .collection('savings_goals')
        .where('familyId', isEqualTo: familyId)
        .where('category', isEqualTo: category)
        .get();

    return goalsSnapshot.docs
        .map((doc) => SavingsGoalModel.fromFirestore(doc))
        .toList();
  }
}
