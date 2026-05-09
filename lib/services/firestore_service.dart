import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../models/category_model.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Get current user ID
  static String? get currentUserId => _auth.currentUser?.uid;
  
  // Reference to user's transactions
  static CollectionReference<Map<String, dynamic>> get _transactionsRef =>
      _db.collection('transactions');
      
  // Reference to user's categories
  static CollectionReference<Map<String, dynamic>> get _categoriesRef =>
      _db.collection('categories');
  
  // Get default categories
  static List<Category> getDefaultCategories() => defaultCategories;
  
  // === TRANSACTIONS ===
  
  // Get all transactions for current user
  static Stream<List<TransactionModel>> getTransactions() {
    if (currentUserId == null) return Stream.value([]);
    
    return _transactionsRef
        .where('userId', isEqualTo: currentUserId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _transactionFromDocument(doc))
            .toList());
  }
  
  // Add new transaction
  static Future<void> addTransaction(TransactionModel transaction) async {
    if (currentUserId == null) throw 'User not authenticated';
    
    final transactionWithUser = TransactionModel(
      id: transaction.id,
      title: transaction.title,
      amount: transaction.amount,
      type: transaction.type,
      date: transaction.date,
      categoryId: transaction.categoryId,
      receiptImagePath: transaction.receiptImagePath,
      notes: transaction.notes,
    );
    
    await _transactionsRef.doc(transaction.id).set({
      'userId': currentUserId,
      'id': transactionWithUser.id,
      'title': transactionWithUser.title,
      'amount': transactionWithUser.amount,
      'type': transactionWithUser.type.toString(),
      'date': transactionWithUser.date.toIso8601String(),
      'categoryId': transactionWithUser.categoryId,
      'receiptImagePath': transactionWithUser.receiptImagePath,
      'notes': transactionWithUser.notes,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  
  // Update transaction
  static Future<void> updateTransaction(TransactionModel transaction) async {
    if (currentUserId == null) throw 'User not authenticated';
    
    await _transactionsRef.doc(transaction.id).update({
      'title': transaction.title,
      'amount': transaction.amount,
      'type': transaction.type.toString(),
      'date': transaction.date.toIso8601String(),
      'categoryId': transaction.categoryId,
      'receiptImagePath': transaction.receiptImagePath,
      'notes': transaction.notes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  
  // Delete transaction
  static Future<void> deleteTransaction(String transactionId) async {
    if (currentUserId == null) throw 'User not authenticated';
    
    await _transactionsRef.doc(transactionId).delete();
  }
  
  // === CATEGORIES ===
  
  // Get all categories for current user
  static Stream<List<Category>> getCategories() {
    if (currentUserId == null) return Stream.value([]);
    
    return _categoriesRef
        .where('userId', isEqualTo: currentUserId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _categoryFromDocument(doc))
            .toList());
  }
  
  // Add default categories for new user
  static Future<void> addDefaultCategories() async {
    if (currentUserId == null) throw 'User not authenticated';
    
    final defaultCategories = getDefaultCategories();
    
    for (final category in defaultCategories) {
      await _categoriesRef.doc(category.id).set({
        'userId': currentUserId,
        'id': category.id,
        'name': category.name,
        'icon': category.icon.codePoint,
        'type': category.type.toString(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
  
  // Add custom category
  static Future<void> addCategory(Category category) async {
    if (currentUserId == null) throw 'User not authenticated';
    
    await _categoriesRef.doc(category.id).set({
      'userId': currentUserId,
      'id': category.id,
      'name': category.name,
      'icon': category.icon.codePoint,
      'type': category.type.toString(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  
  // Update category
  static Future<void> updateCategory(Category category) async {
    if (currentUserId == null) throw 'User not authenticated';
    
    await _categoriesRef.doc(category.id).update({
      'name': category.name,
      'icon': category.icon.codePoint,
      'type': category.type.toString(),
    });
  }
  
  // Delete category
  static Future<void> deleteCategory(String categoryId) async {
    if (currentUserId == null) throw 'User not authenticated';
    
    await _categoriesRef.doc(categoryId).delete();
  }
  
  // === HELPER METHODS ===
  
  static TransactionModel _transactionFromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return TransactionModel(
      id: data['id'] ?? doc.id,
      title: data['title'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      type: data['type']?.toString().contains('income') == true 
          ? TransactionType.income 
          : TransactionType.expense,
      date: DateTime.parse(data['date'] ?? DateTime.now().toIso8601String()),
      categoryId: data['categoryId'] ?? 'other',
      receiptImagePath: data['receiptImagePath'],
      notes: data['notes'],
    );
  }
  
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
