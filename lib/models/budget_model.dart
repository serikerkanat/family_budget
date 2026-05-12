import 'package:cloud_firestore/cloud_firestore.dart';

class BudgetModel {
  final String id;
  final String categoryId;
  final String categoryName;
  final double monthlyLimit;
  final double currentSpent;
  final String currency;
  final DateTime createdAt;
  final String createdBy;
  final String familyId;

  BudgetModel({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.monthlyLimit,
    required this.currentSpent,
    required this.currency,
    required this.createdAt,
    required this.createdBy,
    required this.familyId,
  });

  // Calculate percentage of budget used
  double get percentageUsed {
    if (monthlyLimit == 0) return 0;
    return (currentSpent / monthlyLimit) * 100;
  }

  // Get remaining amount
  double get remaining => monthlyLimit - currentSpent;

  // Check if budget is exceeded
  bool get isExceeded => currentSpent > monthlyLimit;

  // Get color based on percentage
  String get progressColor {
    if (percentageUsed >= 90) return 'red';
    if (percentageUsed >= 75) return 'orange';
    if (percentageUsed >= 50) return 'yellow';
    return 'green';
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'monthlyLimit': monthlyLimit,
      'currentSpent': currentSpent,
      'currency': currency,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'familyId': familyId,
    };
  }

  // Create from Firestore document
  factory BudgetModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BudgetModel(
      id: doc.id,
      categoryId: data['categoryId'] ?? '',
      categoryName: data['categoryName'] ?? '',
      monthlyLimit: (data['monthlyLimit'] as num?)?.toDouble() ?? 0.0,
      currentSpent: (data['currentSpent'] as num?)?.toDouble() ?? 0.0,
      currency: data['currency'] ?? 'USD',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
      familyId: data['familyId'] ?? '',
    );
  }
}
