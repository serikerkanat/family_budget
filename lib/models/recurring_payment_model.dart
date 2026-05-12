import 'package:cloud_firestore/cloud_firestore.dart';

enum RecurringPaymentType {
  monthly,
  weekly,
  yearly,
  oneTime,
}

class RecurringPaymentModel {
  final String id;
  final String title;
  final String description;
  final double amount;
  final RecurringPaymentType type;
  final String categoryId;
  final String categoryName;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime nextPaymentDate;
  final bool isActive;
  final DateTime createdAt;
  final String createdBy;
  final String familyId;

  RecurringPaymentModel({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.categoryName,
    required this.startDate,
    this.endDate,
    required this.nextPaymentDate,
    required this.isActive,
    required this.createdAt,
    required this.createdBy,
    required this.familyId,
  });

  // Check if payment is due today
  bool get isDueToday {
    final now = DateTime.now();
    return now.year == nextPaymentDate.year &&
           now.month == nextPaymentDate.month &&
           now.day == nextPaymentDate.day;
  }

  // Check if payment is overdue
  bool get isOverdue {
    return DateTime.now().isAfter(nextPaymentDate);
  }

  // Get days until next payment
  int get daysUntilPayment {
    final now = DateTime.now();
    if (now.isAfter(nextPaymentDate)) return 0;
    return nextPaymentDate.difference(now).inDays;
  }

  // Calculate next payment date
  DateTime calculateNextPaymentDate(DateTime fromDate) {
    switch (type) {
      case RecurringPaymentType.monthly:
        final nextMonth = fromDate.month == 12 ? 1 : fromDate.month + 1;
        final nextYear = fromDate.month == 12 ? fromDate.year + 1 : fromDate.year;
        return DateTime(nextYear, nextMonth, fromDate.day);
      
      case RecurringPaymentType.weekly:
        return fromDate.add(const Duration(days: 7));
      
      case RecurringPaymentType.yearly:
        return DateTime(fromDate.year + 1, fromDate.month, fromDate.day);
      
      case RecurringPaymentType.oneTime:
        return fromDate; // One-time payments don't recur
    }
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'amount': amount,
      'type': type.toString(),
      'categoryId': categoryId,
      'categoryName': categoryName,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'nextPaymentDate': Timestamp.fromDate(nextPaymentDate),
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'familyId': familyId,
    };
  }

  // Create from Firestore document
  factory RecurringPaymentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    RecurringPaymentType paymentType = RecurringPaymentType.monthly;
    if (data['type'] != null) {
      final typeString = data['type'] as String;
      paymentType = RecurringPaymentType.values.firstWhere(
        (e) => e.toString() == typeString,
        orElse: () => RecurringPaymentType.monthly,
      );
    }

    return RecurringPaymentModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      type: paymentType,
      categoryId: data['categoryId'] ?? '',
      categoryName: data['categoryName'] ?? '',
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: data['endDate'] != null 
          ? (data['endDate'] as Timestamp).toDate() 
          : null,
      nextPaymentDate: (data['nextPaymentDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
      familyId: data['familyId'] ?? '',
    );
  }
}
