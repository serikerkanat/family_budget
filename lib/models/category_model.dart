import 'package:flutter/material.dart';
import 'transaction_model.dart';

class Category {
  final String id;
  final String name;
  final IconData icon;
  final TransactionType type;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.type,
  });

  Category copyWith({
    String? id,
    String? name,
    IconData? icon,
    TransactionType? type,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      type: type ?? this.type,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon.codePoint,
      'type': type.toString(),
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
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

// Default categories
final List<Category> defaultCategories = [
  // Income categories
  const Category(
    id: 'salary',
    name: 'Salary',
    icon: Icons.work,
    type: TransactionType.income,
  ),
  const Category(
    id: 'freelance',
    name: 'Freelance',
    icon: Icons.laptop_mac,
    type: TransactionType.income,
  ),
  const Category(
    id: 'investment',
    name: 'Investment',
    icon: Icons.trending_up,
    type: TransactionType.income,
  ),
  const Category(
    id: 'gift',
    name: 'Gift',
    icon: Icons.card_giftcard,
    type: TransactionType.income,
  ),
  const Category(
    id: 'other_income',
    name: 'Other Income',
    icon: Icons.add_circle,
    type: TransactionType.income,
  ),
  
  // Expense categories
  const Category(
    id: 'food',
    name: 'Food & Dining',
    icon: Icons.restaurant,
    type: TransactionType.expense,
  ),
  const Category(
    id: 'transport',
    name: 'Transportation',
    icon: Icons.directions_car,
    type: TransactionType.expense,
  ),
  const Category(
    id: 'shopping',
    name: 'Shopping',
    icon: Icons.shopping_bag,
    type: TransactionType.expense,
  ),
  const Category(
    id: 'entertainment',
    name: 'Entertainment',
    icon: Icons.movie,
    type: TransactionType.expense,
  ),
  const Category(
    id: 'bills',
    name: 'Bills & Utilities',
    icon: Icons.receipt,
    type: TransactionType.expense,
  ),
  const Category(
    id: 'healthcare',
    name: 'Healthcare',
    icon: Icons.local_hospital,
    type: TransactionType.expense,
  ),
  const Category(
    id: 'education',
    name: 'Education',
    icon: Icons.school,
    type: TransactionType.expense,
  ),
  const Category(
    id: 'travel',
    name: 'Travel',
    icon: Icons.flight,
    type: TransactionType.expense,
  ),
  const Category(
    id: 'other',
    name: 'Other',
    icon: Icons.more_horiz,
    type: TransactionType.expense,
  ),
];
