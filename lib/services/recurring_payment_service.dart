import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recurring_payment_model.dart';
import '../models/transaction_model.dart';
import '../services/firestore_service.dart';
import 'user_service.dart';

class RecurringPaymentService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Get current user ID
  static String? get currentUserId => _auth.currentUser?.uid;

  // Get all recurring payments for family
  static Stream<List<RecurringPaymentModel>> getRecurringPayments() {
    return UserService.currentUserStream.asyncMap(
      (userSnapshot) async {
        try {
          final userData = userSnapshot;
          final familyId = userData?['familyId'] as String?;
          
          if (familyId == null) {
            print('No familyId found for user');
            return <RecurringPaymentModel>[];
          }
          
          print('Getting recurring payments for familyId: $familyId');

          // Get all payments first, then filter in memory to avoid index issues
          final paymentsSnapshot = await _db
              .collection('recurring_payments')
              .where('familyId', isEqualTo: familyId)
              .get();
          
          // Filter active payments and sort in memory
          final activePayments = paymentsSnapshot.docs
              .where((doc) => (doc.data()['isActive'] as bool? ?? false) == true)
              .toList();
          
          // Sort by nextPaymentDate in memory
          activePayments.sort((a, b) {
            final aDate = (a.data()['nextPaymentDate'] as Timestamp?)?.toDate() ?? DateTime.now();
            final bDate = (b.data()['nextPaymentDate'] as Timestamp?)?.toDate() ?? DateTime.now();
            return aDate.compareTo(bDate);
          });
            
          final payments = activePayments
              .map((doc) => RecurringPaymentModel.fromFirestore(doc))
              .toList();
              
          print('Found ${payments.length} active recurring payments');
          return payments;
        } catch (e) {
          print('Error getting recurring payments: $e');
          return <RecurringPaymentModel>[];
        }
      },
    );
  }

  // Create new recurring payment
  static Future<void> createRecurringPayment(RecurringPaymentModel payment) async {
    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) throw Exception('User not in family');
    
    await _db.collection('recurring_payments').add(payment.toFirestore());
  }

  // Update recurring payment
  static Future<void> updateRecurringPayment(RecurringPaymentModel payment) async {
    await _db.collection('recurring_payments').doc(payment.id).update({
      'nextPaymentDate': Timestamp.fromDate(payment.nextPaymentDate),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Update next payment date only
  static Future<void> updateNextPaymentDate(String paymentId, DateTime newDate) async {
    await _db.collection('recurring_payments').doc(paymentId).update({
      'nextPaymentDate': Timestamp.fromDate(newDate),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Deactivate recurring payment
  static Future<void> deactivateRecurringPayment(String paymentId) async {
    await _db.collection('recurring_payments').doc(paymentId).update({
      'isActive': false,
      'deactivatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Process due recurring payments (call this daily/weekly)
  static Future<void> processDuePayments() async {
    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final duePaymentsSnapshot = await _db
        .collection('recurring_payments')
        .where('familyId', isEqualTo: familyId)
        .where('isActive', isEqualTo: true)
        .where('nextPaymentDate', isLessThanOrEqualTo: Timestamp.fromDate(today))
        .get();

    for (final doc in duePaymentsSnapshot.docs) {
      final payment = RecurringPaymentModel.fromFirestore(doc);
      
      // Create transaction for the payment
      final transaction = TransactionModel(
        id: '', // Will be generated
        title: payment.title,
        amount: payment.amount,
        type: TransactionType.expense,
        date: payment.nextPaymentDate,
        categoryId: payment.categoryId,
        receiptImagePath: null,
        notes: 'Recurring payment: ${payment.description}',
      );
      
      await FirestoreService.addTransaction(transaction);
      
      // Update next payment date
      DateTime nextDate = payment.calculateNextPaymentDate(payment.nextPaymentDate);
      
      // Check if payment should be deactivated (reached end date)
      bool shouldDeactivate = false;
      if (payment.endDate != null && nextDate.isAfter(payment.endDate!)) {
        shouldDeactivate = true;
      }
      
      if (shouldDeactivate) {
        await _db.collection('recurring_payments').doc(payment.id).update({
          'isActive': false,
          'deactivatedAt': FieldValue.serverTimestamp(),
          'lastProcessedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await _db.collection('recurring_payments').doc(payment.id).update({
          'nextPaymentDate': Timestamp.fromDate(nextDate),
          'lastProcessedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  // Get upcoming payments (next 30 days)
  static Future<List<RecurringPaymentModel>> getUpcomingPayments() async {
    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) return [];

    final now = DateTime.now();
    final thirtyDaysLater = now.add(const Duration(days: 30));
    
    // Get all payments and filter in memory to avoid index issues
    final paymentsSnapshot = await _db
        .collection('recurring_payments')
        .where('familyId', isEqualTo: familyId)
        .get();

    // Filter active and upcoming payments, then sort in memory
    final upcomingPayments = paymentsSnapshot.docs
        .where((doc) {
          final data = doc.data();
          final isActive = data['isActive'] as bool? ?? false;
          final nextDate = (data['nextPaymentDate'] as Timestamp?)?.toDate();
          return isActive && nextDate != null && nextDate.isBefore(thirtyDaysLater);
        })
        .toList()
        ..sort((a, b) {
          final aDate = (a.data()['nextPaymentDate'] as Timestamp?)?.toDate() ?? DateTime.now();
          final bDate = (b.data()['nextPaymentDate'] as Timestamp?)?.toDate() ?? DateTime.now();
          return aDate.compareTo(bDate);
        });

    return upcomingPayments
        .map((doc) => RecurringPaymentModel.fromFirestore(doc))
        .toList();
  }

  // Get payment summary for analytics
  static Future<Map<String, dynamic>> getPaymentSummary() async {
    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) return {};

    final paymentsSnapshot = await _db
        .collection('recurring_payments')
        .where('familyId', isEqualTo: familyId)
        .where('isActive', isEqualTo: true)
        .get();

    double monthlyTotal = 0;
    int activePayments = 0;
    int overduePayments = 0;

    for (final doc in paymentsSnapshot.docs) {
      final payment = RecurringPaymentModel.fromFirestore(doc);
      activePayments++;
      
      // Calculate monthly equivalent
      switch (payment.type) {
        case RecurringPaymentType.monthly:
          monthlyTotal += payment.amount;
          break;
        case RecurringPaymentType.weekly:
          monthlyTotal += payment.amount * 4.33; // Average weeks per month
          break;
        case RecurringPaymentType.yearly:
          monthlyTotal += payment.amount / 12;
          break;
        case RecurringPaymentType.oneTime:
          // One-time payments don't contribute to monthly total
          break;
      }
      
      if (payment.isOverdue) overduePayments++;
    }

    return {
      'monthlyTotal': monthlyTotal,
      'activePayments': activePayments,
      'overduePayments': overduePayments,
      'yearlyProjection': monthlyTotal * 12,
    };
  }

  // Manually trigger payment processing
  static Future<void> triggerPaymentProcessing() async {
    await processDuePayments();
  }
}
