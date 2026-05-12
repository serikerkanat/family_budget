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
    name: 'Продукты',
    icon: Icons.shopping_cart,
    type: TransactionType.expense,
    color: Color(0xFFE53935),
  ),
  Category(
    id: 'transport',
    name: 'Транспорт',
    icon: Icons.directions_car,
    type: TransactionType.expense,
    color: Color(0xFF3B82F6),
  ),
  Category(
    id: 'utilities',
    name: 'Коммунальные услуги',
    icon: Icons.lightbulb,
    type: TransactionType.expense,
    color: Color(0xFFF59E0B),
  ),
  Category(
    id: 'entertainment',
    name: 'Развлечения',
    icon: Icons.movie,
    type: TransactionType.expense,
    color: Color(0xFF9C27B0),
  ),
  Category(
    id: 'healthcare',
    name: 'Здоровье',
    icon: Icons.local_hospital,
    type: TransactionType.expense,
    color: Color(0xFFE91E63),
  ),
  Category(
    id: 'education',
    name: 'Образование',
    icon: Icons.school,
    type: TransactionType.expense,
    color: Color(0xFF2196F3),
  ),
  Category(
    id: 'other',
    name: 'Другое',
    icon: Icons.more_horiz,
    type: TransactionType.expense,
    color: Color(0xFF607D8B),
  ),
  // Income categories
  Category(
    id: 'salary',
    name: 'Зарплата',
    icon: Icons.attach_money,
    type: TransactionType.income,
    color: Color(0xFF4CAF50),
  ),
  Category(
    id: 'freelance',
    name: 'Фриланс',
    icon: Icons.work,
    type: TransactionType.income,
    color: Color(0xFF2196F3),
  ),
  Category(
    id: 'investment',
    name: 'Инвестиции',
    icon: Icons.trending_up,
    type: TransactionType.income,
    color: Color(0xFF9C27B0),
  ),
  Category(
    id: 'gift',
    name: 'Подарки',
    icon: Icons.card_giftcard,
    type: TransactionType.income,
    color: Color(0xFFFF9800),
  ),
  Category(
    id: 'other_income',
    name: 'Другой доход',
    icon: Icons.add_circle,
    type: TransactionType.income,
    color: Color(0xFF795548),
  ),
];
