import 'package:flutter/material.dart';

enum TransactionType { income, expense }

class Category {
  final String id;
  final String name;
  final IconData icon;
  final TransactionType type;

  Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.type,
  });
}

class TransactionModel {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final TransactionType type;
  final String categoryId;
  final String? receiptImagePath;
  final String? notes;

  TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.type,
    required this.categoryId,
    this.receiptImagePath,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'type': type.toString(),
      'categoryId': categoryId,
      'receiptImagePath': receiptImagePath,
      'notes': notes,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      title: map['title'],
      amount: map['amount'].toDouble(),
      date: DateTime.parse(map['date']),
      type: map['type'] == 'TransactionType.income' 
          ? TransactionType.income 
          : TransactionType.expense,
      categoryId: map['categoryId'],
      receiptImagePath: map['receiptImagePath'],
      notes: map['notes'],
    );
  }
}

// Predefined categories
final List<Category> defaultCategories = [
  // Income Categories
  Category(id: 'salary', name: 'Salary', icon: Icons.work, type: TransactionType.income),
  Category(id: 'freelance', name: 'Freelance', icon: Icons.computer, type: TransactionType.income),
  Category(id: 'gift', name: 'Gift', icon: Icons.card_giftcard, type: TransactionType.income),
  Category(id: 'investment', name: 'Investment', icon: Icons.trending_up, type: TransactionType.income),
  
  // Expense Categories
  Category(id: 'food', name: 'Food', icon: Icons.restaurant, type: TransactionType.expense),
  Category(id: 'transport', name: 'Transport', icon: Icons.directions_car, type: TransactionType.expense),
  Category(id: 'shopping', name: 'Shopping', icon: Icons.shopping_cart, type: TransactionType.expense),
  Category(id: 'bills', name: 'Bills', icon: Icons.receipt, type: TransactionType.expense),
  Category(id: 'entertainment', name: 'Entertainment', icon: Icons.movie, type: TransactionType.expense),
  Category(id: 'health', name: 'Health', icon: Icons.local_hospital, type: TransactionType.expense),
  Category(id: 'education', name: 'Education', icon: Icons.school, type: TransactionType.expense),
  Category(id: 'other', name: 'Other', icon: Icons.category, type: TransactionType.expense),
];
