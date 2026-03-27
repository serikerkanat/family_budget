import 'package:flutter/material.dart';
import 'transaction_model.dart';

class BudgetModel {
  final String id;
  final String categoryId;
  final double amount;
  final String period; // 'monthly', 'weekly', 'yearly'
  final DateTime createdAt;
  final DateTime? startDate;
  final DateTime? endDate;

  BudgetModel({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.period,
    required this.createdAt,
    this.startDate,
    this.endDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'categoryId': categoryId,
      'amount': amount,
      'period': period,
      'createdAt': createdAt.toIso8601String(),
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
    };
  }

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      id: map['id'],
      categoryId: map['categoryId'],
      amount: map['amount'].toDouble(),
      period: map['period'],
      createdAt: DateTime.parse(map['createdAt']),
      startDate: map['startDate'] != null ? DateTime.parse(map['startDate']) : null,
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
    );
  }
}

class BudgetStatus {
  final String categoryId;
  final double budgetAmount;
  final double spentAmount;
  final double remainingAmount;
  final double percentageUsed;
  final bool isOverBudget;
  final Category category;

  BudgetStatus({
    required this.categoryId,
    required this.budgetAmount,
    required this.spentAmount,
    required this.remainingAmount,
    required this.percentageUsed,
    required this.isOverBudget,
    required this.category,
  });
}
