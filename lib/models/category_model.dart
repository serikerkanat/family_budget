import 'package:flutter/material.dart';
import 'transaction_model.dart';

class Category {
  final String id;
  final String name;
  final IconData icon;
  final TransactionType type;
  final Color color;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.type,
    required this.color,
  });

  Category copyWith({
    String? id,
    String? name,
    IconData? icon,
    TransactionType? type,
    Color? color,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      type: type ?? this.type,
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon.codePoint,
      'type': type.toString(),
      'color': color.value,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'icon': icon.codePoint,
      'type': type.toString(),
      'color': color.value,
    };
  }

  factory Category.fromFirestore(Map<String, dynamic> data) {
    return Category(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      icon: IconData(data['icon'] ?? 0, fontFamily: 'MaterialIcons'),
      type: data['type']?.toString().contains('income') == true 
          ? TransactionType.income 
          : TransactionType.expense,
      color: Color(data['color'] ?? 0xFFE53935),
    );
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      icon: IconData(json['icon'] ?? 0, fontFamily: 'MaterialIcons'),
      type: json['type']?.toString().contains('income') == true 
          ? TransactionType.income 
          : TransactionType.expense,
      color: Color(json['color'] ?? 0xFFE53935),
    );
  }
}

// Default categories with colors
const List<Category> defaultCategories = [
  Category(
    id: 'groceries',
    name: 'Groceries',
    icon: Icons.shopping_cart,
    type: TransactionType.expense,
    color: Color(0xFFE53935),
  ),
  Category(
    id: 'transport',
    name: 'Transport',
    icon: Icons.directions_car,
    type: TransactionType.expense,
    color: Color(0xFF3B82F6),
  ),
  Category(
    id: 'utilities',
    name: 'Utilities',
    icon: Icons.lightbulb,
    type: TransactionType.expense,
    color: Color(0xFFF59E0B),
  ),
  Category(
    id: 'entertainment',
    name: 'Entertainment',
    icon: Icons.movie,
    type: TransactionType.expense,
    color: Color(0xFF9C27B0),
  ),
  Category(
    id: 'healthcare',
    name: 'Healthcare',
    icon: Icons.local_hospital,
    type: TransactionType.expense,
    color: Color(0xFFE91E63),
  ),
  Category(
    id: 'education',
    name: 'Education',
    icon: Icons.school,
    type: TransactionType.expense,
    color: Color(0xFF2196F3),
  ),
  Category(
    id: 'other',
    name: 'Other',
    icon: Icons.more_horiz,
    type: TransactionType.expense,
    color: Color(0xFF607D8B),
  ),
  Category(
    id: 'salary',
    name: 'Salary',
    icon: Icons.attach_money,
    type: TransactionType.income,
    color: Color(0xFF4CAF50),
  ),
  Category(
    id: 'freelance',
    name: 'Freelance',
    icon: Icons.work,
    type: TransactionType.income,
    color: Color(0xFF2196F3),
  ),
  Category(
    id: 'investment',
    name: 'Investments',
    icon: Icons.trending_up,
    type: TransactionType.income,
    color: Color(0xFF9C27B0),
  ),
  Category(
    id: 'gift',
    name: 'Gifts',
    icon: Icons.card_giftcard,
    type: TransactionType.income,
    color: Color(0xFFFF9800),
  ),
  Category(
    id: 'other_income',
    name: 'Other income',
    icon: Icons.add_circle,
    type: TransactionType.income,
    color: Color(0xFF795548),
  ),
];
