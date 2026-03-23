import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
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
    return '''
    {
      "id": "${transaction.id}",
      "title": "${transaction.title}",
      "amount": ${transaction.amount},
      "date": "${transaction.date.toIso8601String()}",
      "type": "${transaction.type}",
      "categoryId": "${transaction.categoryId}",
      "receiptImagePath": ${transaction.receiptImagePath != null ? '"${transaction.receiptImagePath}"' : 'null'},
      "notes": ${transaction.notes != null ? '"${transaction.notes}"' : 'null'}
    }
    ''';
  }
  
  TransactionModel _transactionFromJson(String jsonStr) {
    // Simple JSON parsing (for demo purposes, in production use json_serializable)
    final id = _extractJsonValue(jsonStr, 'id') ?? const Uuid().v4();
    final title = _extractJsonValue(jsonStr, 'title') ?? '';
    final amount = double.tryParse(_extractJsonValue(jsonStr, 'amount') ?? '0') ?? 0;
    final dateStr = _extractJsonValue(jsonStr, 'date') ?? DateTime.now().toIso8601String();
    final typeStr = _extractJsonValue(jsonStr, 'type') ?? 'expense';
    final categoryId = _extractJsonValue(jsonStr, 'categoryId') ?? 'other';
    final receiptImagePath = _extractJsonValue(jsonStr, 'receiptImagePath');
    final notes = _extractJsonValue(jsonStr, 'notes');
    
    return TransactionModel(
      id: id,
      title: title,
      amount: amount,
      date: DateTime.parse(dateStr),
      type: typeStr.contains('income') ? TransactionType.income : TransactionType.expense,
      categoryId: categoryId,
      receiptImagePath: receiptImagePath,
      notes: notes,
    );
  }
  
  String _categoryToJson(Category category) {
    return '''
    {
      "id": "${category.id}",
      "name": "${category.name}",
      "icon": ${category.icon.codePoint},
      "type": "${category.type}"
    }
    ''';
  }
  
  Category _categoryFromJson(String jsonStr) {
    final id = _extractJsonValue(jsonStr, 'id') ?? '';
    final name = _extractJsonValue(jsonStr, 'name') ?? '';
    final iconCodePoint = int.tryParse(_extractJsonValue(jsonStr, 'icon') ?? '0') ?? 0;
    final typeStr = _extractJsonValue(jsonStr, 'type') ?? 'expense';
    
    return Category(
      id: id,
      name: name,
      icon: IconData(iconCodePoint, fontFamily: 'MaterialIcons'),
      type: typeStr.contains('income') ? TransactionType.income : TransactionType.expense,
    );
  }
  
  String? _extractJsonValue(String json, String key) {
    final pattern = '"$key"\s*:\s*"?([^,"\n}]+)"?[,\n}]';
    final regExp = RegExp(pattern);
    final match = regExp.firstMatch(json);
    if (match != null && match.groupCount >= 1) {
      // Remove any trailing quotes or commas
      return match.group(1)?.replaceAll('"', '').trim();
    }
    return null;
  }
}
