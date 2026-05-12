import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../models/category_model.dart';
import '../services/family_service.dart';
import '../services/user_service.dart';
import '../services/budget_service.dart';
import '../services/bank_notification_parser.dart';
import '../services/notification_permission_service.dart';
import '../services/transaction_deduplication_service.dart';

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
  
  // Add transaction
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
    
    // Update budget spending if this is an expense transaction
    if (transaction.type == TransactionType.expense) {
      await BudgetService.updateBudgetSpending(
        transaction.categoryId, 
        transaction.amount,
      );
    }
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

  // Add transaction from notification
  static Future<void> addTransactionFromNotification(
    ParsedTransaction parsedTransaction,
  ) async {
    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) throw Exception('User not in family');

    // Check if notification tracking is enabled
    final isTrackingEnabled = await NotificationPermissionService.isNotificationTrackingEnabled();
    if (!isTrackingEnabled) return;

    // Get settings to check if bank is enabled
    final settings = await NotificationPermissionService.getNotificationSettings();
    if (settings != null && !settings.enabledBanks.contains(parsedTransaction.bankName)) {
      return;
    }

    // Suggest category
    final categoryId = BankNotificationParser.suggestCategory(parsedTransaction);

    // Create transaction
    final transaction = parsedTransaction.toTransactionModel(categoryId).copyWith(
      source: TransactionSource.notification,
      bankName: parsedTransaction.bankName,
      rawNotificationText: '${parsedTransaction.rawTitle}\n${parsedTransaction.rawText}',
    );

    // Try to merge with existing manual transaction
    final merged = await TransactionDeduplicationService.mergeWithNotification(transaction);
    if (merged) {
      // Successfully merged with existing transaction
      await NotificationPermissionService.updateLastSync();
      return;
    }

    // Check for exact duplicates
    final existingTransaction = await TransactionDeduplicationService.findDuplicate(transaction);
    if (existingTransaction != null) {
      // Update existing transaction instead of creating duplicate
      await _db.collection('transactions').doc(existingTransaction.id).update({
        'bankName': transaction.bankName,
        'rawNotificationText': transaction.rawNotificationText,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Add new transaction
      await _db.collection('transactions').add({
        'id': transaction.id,
        'title': transaction.title,
        'amount': transaction.amount,
        'date': transaction.date.toIso8601String(),
        'type': transaction.type.toString(),
        'categoryId': transaction.categoryId,
        'receiptImagePath': transaction.receiptImagePath,
        'notes': transaction.notes,
        'source': transaction.source.toString(),
        'bankName': transaction.bankName,
        'rawNotificationText': transaction.rawNotificationText,
        'familyId': familyId,
        'createdBy': currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // Update last sync timestamp
    await NotificationPermissionService.updateLastSync();
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
      color: Color(data['color'] ?? 0xFFE53935),
    );
  }
}
