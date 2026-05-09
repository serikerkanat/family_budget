import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../models/category_model.dart';
import '../services/family_service.dart';
import '../services/user_service.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Get current user ID
  static String? get currentUserId => _auth.currentUser?.uid;
  
  // Get transactions filtered by family
  static Stream<List<TransactionModel>> getTransactions() {
    return UserService.currentUserStream.asyncMap(
      (userSnapshot) async {
        final userData = userSnapshot;
        final familyId = userData?['familyId'] as String?;
        
        if (familyId == null) {
          return <TransactionModel>[];
        }
        
        final transactionsSnapshot = await _db
            .collection('transactions')
            .where('familyId', isEqualTo: familyId)
            .orderBy('date', descending: true)
            .get();
            
        return transactionsSnapshot.docs
            .map((doc) => _transactionFromDocument(doc))
            .toList();
      },
    );
  }
  
  // Add transaction with familyId
  static Future<void> addTransaction(TransactionModel transaction) async {
    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) throw Exception('User not in family');
    
    await _db.collection('transactions').add({
      'id': transaction.id,
      'title': transaction.title,
      'amount': transaction.amount,
      'date': transaction.date.toIso8601String(),
      'type': transaction.type.toString(),
      'categoryId': transaction.categoryId,
      'receiptImagePath': transaction.receiptImagePath,
      'notes': transaction.notes,
      'familyId': familyId,
      'createdBy': currentUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  
  // Update transaction
  static Future<void> updateTransaction(TransactionModel transaction) async {
    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) throw Exception('User not in family');
    
    await _db.collection('transactions').doc(transaction.id).update({
      'title': transaction.title,
      'amount': transaction.amount,
      'date': transaction.date.toIso8601String(),
      'type': transaction.type.toString(),
      'categoryId': transaction.categoryId,
      'receiptImagePath': transaction.receiptImagePath,
      'notes': transaction.notes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  
  // Delete transaction
  static Future<void> deleteTransaction(String id) async {
    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) throw Exception('User not in family');
    
    await _db.collection('transactions').doc(id).delete();
  }
  
  // Get default categories
  static List<Category> getDefaultCategories() => defaultCategories;
  
  // === HELPER METHODS ===
  
  // Convert transaction from Firestore document
  static TransactionModel _transactionFromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return TransactionModel(
      id: data['id'] ?? doc.id,
      title: data['title'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.parse(data['date'] ?? DateTime.now().toIso8601String()),
      type: data['type']?.toString().contains('income') == true 
          ? TransactionType.income 
          : TransactionType.expense,
      categoryId: data['categoryId'] ?? 'other',
      receiptImagePath: data['receiptImagePath'],
      notes: data['notes'],
    );
  }
  
  // Convert category from Firestore document
  static Category _categoryFromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Category(
      id: data['id'] ?? doc.id,
      name: data['name'] ?? '',
      icon: IconData(data['icon'] ?? 0, fontFamily: 'MaterialIcons'),
      type: data['type']?.toString().contains('income') == true 
          ? TransactionType.income 
          : TransactionType.expense,
    );
  }
}
