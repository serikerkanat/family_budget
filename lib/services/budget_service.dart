import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/budget_model.dart';
import '../models/transaction_model.dart';
import 'user_service.dart';

class BudgetService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Get current user ID
  static String? get currentUserId => _auth.currentUser?.uid;

  // Get all budgets for current family
  static Stream<List<BudgetModel>> getBudgets() {
    return UserService.currentUserStream.asyncMap(
      (userSnapshot) async {
        final userData = userSnapshot;
        final familyId = userData?['familyId'] as String?;
        
        if (familyId == null) {
          return <BudgetModel>[];
        }
        
        final budgetsSnapshot = await _db
            .collection('budgets')
            .where('familyId', isEqualTo: familyId)
            .get();
            
        return budgetsSnapshot.docs
            .map((doc) => BudgetModel.fromFirestore(doc))
            .toList();
      },
    );
  }

  // Create or update budget
  static Future<void> setBudget(BudgetModel budget) async {
    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) throw Exception('User not in family');
    
    await _db.collection('budgets').doc(budget.id).set(budget.toFirestore());
  }

  // Delete budget
  static Future<void> deleteBudget(String budgetId) async {
    await _db.collection('budgets').doc(budgetId).delete();
  }

  // Update budget spending (called when transaction is added)
  static Future<void> updateBudgetSpending(String categoryId, double amount) async {
    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) return;

    final budgetSnapshot = await _db
        .collection('budgets')
        .where('familyId', isEqualTo: familyId)
        .where('categoryId', isEqualTo: categoryId)
        .limit(1)
        .get();

    if (budgetSnapshot.docs.isNotEmpty) {
      final budgetDoc = budgetSnapshot.docs.first;
      final currentData = budgetDoc.data() as Map<String, dynamic>;
      final currentSpent = (currentData['currentSpent'] as num?)?.toDouble() ?? 0.0;
      
      await _db.collection('budgets').doc(budgetDoc.id).update({
        'currentSpent': currentSpent + amount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Reset monthly budgets (call this at the beginning of each month)
  static Future<void> resetMonthlyBudgets() async {
    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) return;

    final budgetsSnapshot = await _db
        .collection('budgets')
        .where('familyId', isEqualTo: familyId)
        .get();

    for (final doc in budgetsSnapshot.docs) {
      await _db.collection('budgets').doc(doc.id).update({
        'currentSpent': 0.0,
        'lastReset': FieldValue.serverTimestamp(),
      });
    }
  }

  // Calculate budget summary for analytics
  static Future<Map<String, dynamic>> getBudgetSummary() async {
    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) return {};

    final budgetsSnapshot = await _db
        .collection('budgets')
        .where('familyId', isEqualTo: familyId)
        .get();

    double totalLimit = 0;
    double totalSpent = 0;
    int exceededBudgets = 0;

    for (final doc in budgetsSnapshot.docs) {
      final budget = BudgetModel.fromFirestore(doc);
      totalLimit += budget.monthlyLimit;
      totalSpent += budget.currentSpent;
      if (budget.isExceeded) exceededBudgets++;
    }

    return {
      'totalLimit': totalLimit,
      'totalSpent': totalSpent,
      'totalRemaining': totalLimit - totalSpent,
      'exceededBudgets': exceededBudgets,
      'totalBudgets': budgetsSnapshot.docs.length,
    };
  }
}
