import 'package:cloud_firestore/cloud_firestore.dart';

class SavingsGoalModel {
  final String id;
  final String title;
  final String description;
  final double targetAmount;
  final double currentAmount;
  final DateTime targetDate;
  final DateTime createdAt;
  final String createdBy;
  final String familyId;
  final String category; // 'vacation', 'car', 'emergency', etc.

  SavingsGoalModel({
    required this.id,
    required this.title,
    required this.description,
    required this.targetAmount,
    required this.currentAmount,
    required this.targetDate,
    required this.createdAt,
    required this.createdBy,
    required this.familyId,
    required this.category,
  });

  // Calculate percentage saved
  double get percentageSaved {
    if (targetAmount == 0) return 0;
    return (currentAmount / targetAmount) * 100;
  }

  // Get remaining amount
  double get remainingAmount => targetAmount - currentAmount;

  // Check if goal is achieved
  bool get isAchieved => currentAmount >= targetAmount;

  // Check if goal is overdue
  bool get isOverdue => DateTime.now().isAfter(targetDate) && !isAchieved;

  // Get days remaining
  int get daysRemaining {
    final now = DateTime.now();
    if (now.isAfter(targetDate)) return 0;
    return targetDate.difference(now).inDays;
  }

  // Get monthly savings needed
  double get monthlySavingsNeeded {
    final now = DateTime.now();
    final monthsRemaining = (targetDate.year - now.year) * 12 + 
                       (targetDate.month - now.month) + 
                       (targetDate.day >= now.day ? 1 : 0);
    
    if (monthsRemaining <= 0) return remainingAmount;
    return remainingAmount / monthsRemaining;
  }

  // Get progress color based on percentage
  String get progressColor {
    if (isAchieved) return 'green';
    if (isOverdue) return 'red';
    if (percentageSaved >= 75) return 'blue';
    if (percentageSaved >= 50) return 'purple';
    if (percentageSaved >= 25) return 'orange';
    return 'grey';
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'targetDate': Timestamp.fromDate(targetDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'familyId': familyId,
      'category': category,
    };
  }

  // Create from Firestore document
  factory SavingsGoalModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SavingsGoalModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      targetAmount: (data['targetAmount'] as num?)?.toDouble() ?? 0.0,
      currentAmount: (data['currentAmount'] as num?)?.toDouble() ?? 0.0,
      targetDate: (data['targetDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
      familyId: data['familyId'] ?? '',
      category: data['category'] ?? 'other',
    );
  }
}
