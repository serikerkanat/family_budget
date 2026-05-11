import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';
import 'user_service.dart';

class TransactionDeduplicationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Check if a transaction is a duplicate
  /// Returns the existing transaction if found, null otherwise
  static Future<TransactionModel?> findDuplicate(
    TransactionModel transaction,
  ) async {
    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) return null;

    // Check for duplicates within a time window (5 minutes before and after)
    final timeWindow = const Duration(minutes: 5);
    final startTime = transaction.date.subtract(timeWindow);
    final endTime = transaction.date.add(timeWindow);

    final snapshot = await _db
        .collection('transactions')
        .where('familyId', isEqualTo: familyId)
        .where('amount', isEqualTo: transaction.amount)
        .where('type', isEqualTo: transaction.type.toString())
        .where('date', isGreaterThanOrEqualTo: startTime.toIso8601String())
        .where('date', isLessThanOrEqualTo: endTime.toIso8601String())
        .limit(5)
        .get();

    if (snapshot.docs.isEmpty) return null;

    // Find the closest match
    TransactionModel? closestMatch;
    Duration? smallestDifference;

    for (final doc in snapshot.docs) {
      final existing = _transactionFromDocument(doc);
      final difference = transaction.date.difference(existing.date).abs();

      if (smallestDifference == null || difference < smallestDifference) {
        smallestDifference = difference;
        closestMatch = existing;
      }
    }

    // Only consider it a duplicate if within 2 minutes
    if (smallestDifference != null && smallestDifference.inMinutes <= 2) {
      return closestMatch;
    }

    return null;
  }

  /// Check for duplicate by bank notification data
  static Future<TransactionModel?> findDuplicateByNotification(
    String bankName,
    double amount,
    DateTime date,
  ) async {
    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) return null;

    final timeWindow = const Duration(minutes: 5);
    final startTime = date.subtract(timeWindow);
    final endTime = date.add(timeWindow);

    final snapshot = await _db
        .collection('transactions')
        .where('familyId', isEqualTo: familyId)
        .where('amount', isEqualTo: amount)
        .where('bankName', isEqualTo: bankName)
        .where('date', isGreaterThanOrEqualTo: startTime.toIso8601String())
        .where('date', isLessThanOrEqualTo: endTime.toIso8601String())
        .limit(3)
        .get();

    if (snapshot.docs.isEmpty) return null;

    return _transactionFromDocument(snapshot.docs.first);
  }

  /// Merge manual transaction with notification data
  /// If a manual transaction exists nearby, update it with notification info
  static Future<bool> mergeWithNotification(
    TransactionModel notificationTransaction,
  ) async {
    final duplicate = await findDuplicate(notificationTransaction);

    if (duplicate != null && duplicate.source == TransactionSource.manual) {
      // Update the manual transaction with notification data
      await _db.collection('transactions').doc(duplicate.id).update({
        'bankName': notificationTransaction.bankName,
        'rawNotificationText': notificationTransaction.rawNotificationText,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    }

    return false;
  }

  /// Get statistics about duplicate transactions
  static Future<Map<String, dynamic>> getDuplicateStats() async {
    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) return {};

    // Get all transactions from the last 30 days
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    final snapshot = await _db
        .collection('transactions')
        .where('familyId', isEqualTo: familyId)
        .where('date', isGreaterThanOrEqualTo: thirtyDaysAgo.toIso8601String())
        .get();

    final transactions = snapshot.docs.map(_transactionFromDocument).toList();

    // Count duplicates
    int duplicateCount = 0;
    int notificationCount = 0;
    int manualCount = 0;

    for (final tx in transactions) {
      if (tx.source == TransactionSource.notification) {
        notificationCount++;
      } else if (tx.source == TransactionSource.manual) {
        manualCount++;
      }
    }

    return {
      'totalTransactions': transactions.length,
      'notificationTransactions': notificationCount,
      'manualTransactions': manualCount,
      'duplicateCount': duplicateCount,
    };
  }

  static TransactionModel _transactionFromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return TransactionModel(
      id: data['id'] ?? doc.id,
      title: data['title'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.parse(data['date'] ?? DateTime.now().toIso8601String()),
      type: data['type']?.toString().contains('income') == true 
          ? TransactionType.income 
          : TransactionType.expense,
      categoryId: data['categoryId'] ?? 'other',
      receiptImagePath: data['receiptImagePath'],
      notes: data['notes'],
      source: data['source']?.toString().contains('notification') == true
          ? TransactionSource.notification
          : data['source']?.toString().contains('import') == true
              ? TransactionSource.import
              : TransactionSource.manual,
      bankName: data['bankName'],
      rawNotificationText: data['rawNotificationText'],
    );
  }
}
