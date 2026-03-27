import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../models/transaction_model.dart';
import 'package:flutter/material.dart';

class LocalStorageService {
  static const String _transactionsKey = 'transactions';
  static const String _categoriesKey = 'categories';
  
  static final LocalStorageService _instance = LocalStorageService._internal();
  late SharedPreferences _prefs;
  
  factory LocalStorageService() => _instance;
  
  LocalStorageService._internal();
  
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _initializeDefaultCategories();
  }
  
  Future<void> _initializeDefaultCategories() async {
    final categories = getCategories();
    if (categories.isEmpty) {
      // Save default categories if none exist
      await _prefs.setStringList(
        _categoriesKey,
        defaultCategories.map((cat) => _categoryToJson(cat)).toList(),
      );
    }
  }
  
  // Transaction methods
  Future<void> saveTransaction(TransactionModel transaction) async {
    final transactions = getTransactions();
    transactions.add(transaction);
    await _saveTransactions(transactions);
  }
  
  Future<void> updateTransaction(TransactionModel updatedTransaction) async {
    final transactions = getTransactions();
    final index = transactions.indexWhere((t) => t.id == updatedTransaction.id);
    if (index != -1) {
      transactions[index] = updatedTransaction;
      await _saveTransactions(transactions);
    }
  }
  
  Future<void> deleteTransaction(String id) async {
    final transactions = getTransactions();
    transactions.removeWhere((t) => t.id == id);
    await _saveTransactions(transactions);
  }
  
  List<TransactionModel> getTransactions() {
    final transactionsJson = _prefs.getStringList(_transactionsKey) ?? [];
    return transactionsJson.map((json) => _transactionFromJson(json)).toList();
  }
  
  // Category methods
  List<Category> getCategories() {
    final categoriesJson = _prefs.getStringList(_categoriesKey) ?? [];
    return categoriesJson.map((json) => _categoryFromJson(json)).toList();
  }
  
  Category? getCategoryById(String id) {
    final categories = getCategories();
    return categories.firstWhere((cat) => cat.id == id);
  }
  
  List<Category> getCategoriesByType(TransactionType type) {
    final categories = getCategories();
    return categories.where((cat) => cat.type == type).toList();
  }
  
  // Helper methods
  Future<void> _saveTransactions(List<TransactionModel> transactions) async {
    final transactionsJson = transactions.map((t) => _transactionToJson(t)).toList();
    await _prefs.setStringList(_transactionsKey, transactionsJson);
  }
  
  // JSON serialization/deserialization
  String _transactionToJson(TransactionModel transaction) {
    return jsonEncode({
      'id': transaction.id,
      'title': transaction.title,
      'amount': transaction.amount,
      'date': transaction.date.toIso8601String(),
      'type': transaction.type.toString(),
      'categoryId': transaction.categoryId,
      'receiptImagePath': transaction.receiptImagePath,
      'notes': transaction.notes,
    });
  }
  
  TransactionModel _transactionFromJson(String jsonStr) {
    final Map<String, dynamic> json = jsonDecode(jsonStr);
    return TransactionModel(
      id: json['id'] ?? const Uuid().v4(),
      title: json['title'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      type: json['type']?.toString().contains('income') == true 
          ? TransactionType.income 
          : TransactionType.expense,
      categoryId: json['categoryId'] ?? 'other',
      receiptImagePath: json['receiptImagePath'],
      notes: json['notes'],
    );
  }
  
  String _categoryToJson(Category category) {
    return jsonEncode({
      'id': category.id,
      'name': category.name,
      'icon': category.icon.codePoint,
      'type': category.type.toString(),
    });
  }
  
  Category _categoryFromJson(String jsonStr) {
    final Map<String, dynamic> json = jsonDecode(jsonStr);
    return Category(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      icon: IconData(json['icon'] ?? 0, fontFamily: 'MaterialIcons'),
      type: json['type']?.toString().contains('income') == true 
          ? TransactionType.income 
          : TransactionType.expense,
    );
  }
}
