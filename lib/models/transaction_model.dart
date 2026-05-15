import 'package:flutter/material.dart';

enum TransactionType { income, expense }

enum TransactionSource { manual, notification, import }

class TransactionModel {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final TransactionType type;
  final String categoryId;
  final String? receiptImagePath;
  final String? notes;
  final TransactionSource source;
  final String? bankName;
  final String? rawNotificationText;
  final String currency; // Added currency field

  TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.type,
    required this.categoryId,
    this.receiptImagePath,
    this.notes,
    this.source = TransactionSource.manual,
    this.bankName,
    this.rawNotificationText,
    this.currency = 'USD', // Default to USD
  });

  TransactionModel copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? date,
    TransactionType? type,
    String? categoryId,
    String? receiptImagePath,
    String? notes,
    TransactionSource? source,
    String? bankName,
    String? rawNotificationText,
    String? currency,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      receiptImagePath: receiptImagePath ?? this.receiptImagePath,
      notes: notes ?? this.notes,
      source: source ?? this.source,
      bankName: bankName ?? this.bankName,
      rawNotificationText: rawNotificationText ?? this.rawNotificationText,
      currency: currency ?? this.currency,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'type': type.toString(),
      'categoryId': categoryId,
      'receiptImagePath': receiptImagePath,
      'notes': notes,
      'source': source.toString(),
      'bankName': bankName,
      'rawNotificationText': rawNotificationText,
      'currency': currency,
    };
  }

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      type: json['type']?.toString().contains('income') == true 
          ? TransactionType.income 
          : TransactionType.expense,
      categoryId: json['categoryId'] ?? 'other',
      receiptImagePath: json['receiptImagePath'],
      notes: json['notes'],
      source: json['source']?.toString().contains('notification') == true
          ? TransactionSource.notification
          : json['source']?.toString().contains('import') == true
              ? TransactionSource.import
              : TransactionSource.manual,
      bankName: json['bankName'],
      rawNotificationText: json['rawNotificationText'],
      currency: json['currency'] ?? 'USD',
    );
  }
}
