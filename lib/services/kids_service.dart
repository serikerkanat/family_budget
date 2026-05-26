import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/achievement_model.dart';
import '../models/transaction_model.dart';
import '../models/withdrawal_request_model.dart';
import 'firestore_service.dart';
import 'user_service.dart';

/// One allowance "deposit" given by a parent to a child.
///
/// Stored in `/allowances`. We keep it separate from family transactions so
/// the family ledger isn't polluted with internal money transfers — but we do
/// also create a regular `expense` transaction for the family pool when a
/// withdrawal is approved (so the family budget reflects real outflow).
class AllowanceEntry {
  final String id;
  final String familyId;
  final String childUid;
  final double amount;
  final String currency;
  final String? note;
  final String givenBy;
  final DateTime createdAt;

  AllowanceEntry({
    required this.id,
    required this.familyId,
    required this.childUid,
    required this.amount,
    required this.currency,
    required this.givenBy,
    required this.createdAt,
    this.note,
  });

  Map<String, dynamic> toFirestore() => {
        'familyId': familyId,
        'childUid': childUid,
        'amount': amount,
        'currency': currency,
        if (note != null) 'note': note,
        'givenBy': givenBy,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory AllowanceEntry.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AllowanceEntry(
      id: doc.id,
      familyId: d['familyId'] ?? '',
      childUid: d['childUid'] ?? '',
      amount: (d['amount'] as num?)?.toDouble() ?? 0,
      currency: d['currency'] ?? 'USD',
      note: d['note'] as String?,
      givenBy: d['givenBy'] ?? '',
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class KidsService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? get currentUid => _auth.currentUser?.uid;

  // ---------- Allowances ----------

  /// Allowances received by [childUid].
  static Stream<List<AllowanceEntry>> allowancesFor(String childUid) {
    return _db
        .collection('allowances')
        .where('childUid', isEqualTo: childUid)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(AllowanceEntry.fromFirestore).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Parent grants [amount] of allowance to [childUid].
  static Future<void> giveAllowance({
    required String childUid,
    required double amount,
    required String currency,
    String? note,
  }) async {
    if (amount <= 0) throw Exception('Amount must be positive');
    final familyId = await UserService.getUserFamilyId();
    final givenBy = currentUid;
    if (familyId == null || givenBy == null) {
      throw Exception('User not authenticated or not in a family');
    }
    await _db.collection('allowances').add(AllowanceEntry(
          id: '',
          familyId: familyId,
          childUid: childUid,
          amount: amount,
          currency: currency,
          note: note,
          givenBy: givenBy,
          createdAt: DateTime.now(),
        ).toFirestore());
  }

  // ---------- Withdrawal requests ----------

  /// Pending requests in current family (parents poll this).
  static Stream<List<WithdrawalRequest>> pendingRequests() {
    return UserService.currentUserStream.asyncExpand((u) {
      final famId = u?['familyId'] as String?;
      if (famId == null) return Stream.value(<WithdrawalRequest>[]);
      return _db
          .collection('withdrawal_requests')
          .where('familyId', isEqualTo: famId)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .map((s) {
        final list =
            s.docs.map(WithdrawalRequest.fromFirestore).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
    });
  }

  /// All requests by [childUid] (most recent first).
  static Stream<List<WithdrawalRequest>> requestsByChild(String childUid) {
    return _db
        .collection('withdrawal_requests')
        .where('childUid', isEqualTo: childUid)
        .snapshots()
        .map((s) {
      final list = s.docs.map(WithdrawalRequest.fromFirestore).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Child files a new withdrawal request.
  static Future<void> createRequest({
    required double amount,
    required String currency,
    required String reason,
  }) async {
    if (amount <= 0) throw Exception('Amount must be positive');
    final familyId = await UserService.getUserFamilyId();
    final uid = currentUid;
    final userData = await UserService.getCurrentUserData();
    if (familyId == null || uid == null) {
      throw Exception('User not authenticated or not in a family');
    }
    final name = (userData?['name'] as String?) ??
        (userData?['email'] as String?) ??
        'Child';

    await _db.collection('withdrawal_requests').add(WithdrawalRequest(
          id: '',
          familyId: familyId,
          childUid: uid,
          childName: name,
          amount: amount,
          currency: currency,
          reason: reason,
          status: WithdrawalStatus.pending,
          createdAt: DateTime.now(),
        ).toFirestore());
  }

  /// Parent approves a withdrawal. Creates a family expense transaction so
  /// the household budget reflects the real outflow.
  static Future<void> approveRequest(WithdrawalRequest req,
      {String? note}) async {
    final decider = currentUid;
    if (decider == null) throw Exception('Not authenticated');

    await _db.collection('withdrawal_requests').doc(req.id).update({
      'status': WithdrawalStatus.approved.value,
      'decidedAt': FieldValue.serverTimestamp(),
      'decidedBy': decider,
      if (note != null) 'decisionNote': note,
    });

    // Mirror to family ledger as expense.
    try {
      final tx = TransactionModel(
        id: '',
        title: '${req.childName} • ${req.reason}',
        amount: req.amount,
        date: DateTime.now(),
        type: TransactionType.expense,
        categoryId: 'other',
        notes: 'Approved withdrawal for ${req.childName}',
        currency: req.currency,
      );
      await FirestoreService.addTransaction(tx);
    } catch (e) {
      // Non-fatal: the withdrawal is still approved.
      debugPrint('Failed to mirror approved withdrawal as transaction: $e');
    }
  }

  static Future<void> rejectRequest(WithdrawalRequest req,
      {String? note}) async {
    final decider = currentUid;
    if (decider == null) throw Exception('Not authenticated');
    await _db.collection('withdrawal_requests').doc(req.id).update({
      'status': WithdrawalStatus.rejected.value,
      'decidedAt': FieldValue.serverTimestamp(),
      'decidedBy': decider,
      if (note != null) 'decisionNote': note,
    });
  }

  // ---------- Balance & savings progress ----------

  /// Computes a child's spendable balance from allowances and approved
  /// withdrawals. Pure synchronous given the inputs.
  static double computeBalance({
    required List<AllowanceEntry> allowances,
    required List<WithdrawalRequest> requests,
  }) {
    double bal = 0;
    for (final a in allowances) {
      bal += a.amount;
    }
    for (final r in requests) {
      if (r.status == WithdrawalStatus.approved) {
        bal -= r.amount;
      }
    }
    return bal;
  }
}

// ---------- Achievement computation ----------

class AchievementService {
  /// Computes the full badge set with `earned` / `progress` for a child.
  /// Inputs are intentionally pure data so this is easy to unit test.
  static List<Achievement> compute({
    required List<AllowanceEntry> allowances,
    required List<WithdrawalRequest> requests,
    required List<TransactionModel> myTransactions,
  }) {
    final balance = KidsService.computeBalance(
      allowances: allowances,
      requests: requests,
    );
    final approvedCount = requests
        .where((r) => r.status == WithdrawalStatus.approved)
        .length;

    // 1. "First Allowance"
    final firstAllowance = Achievement(
      id: 'first_allowance',
      titleKey: 'ach_firstAllowance_title',
      descriptionKey: 'ach_firstAllowance_desc',
      icon: Icons.savings,
      color: const Color(0xFF10B981),
      earned: allowances.isNotEmpty,
    );

    // 2. "Saved 7 days in a row" — 7+ consecutive days with no expenses by me
    final daysWithoutSpending = _maxNoSpendStreak(myTransactions);
    final saved7 = Achievement(
      id: 'saved_7_days',
      titleKey: 'ach_saved7_title',
      descriptionKey: 'ach_saved7_desc',
      icon: Icons.local_fire_department,
      color: const Color(0xFFF59E0B),
      earned: daysWithoutSpending >= 7,
      progress: (daysWithoutSpending / 7).clamp(0, 1),
      progressLabel: '$daysWithoutSpending / 7',
    );

    // 3. "Big Saver" — current balance >= 5000 (currency-agnostic threshold)
    const bigSaverGoal = 5000.0;
    final bigSaver = Achievement(
      id: 'big_saver',
      titleKey: 'ach_bigSaver_title',
      descriptionKey: 'ach_bigSaver_desc',
      icon: Icons.account_balance,
      color: const Color(0xFF6366F1),
      earned: balance >= bigSaverGoal,
      progress: (balance / bigSaverGoal).clamp(0, 1),
      progressLabel: '${balance.toStringAsFixed(0)} / ${bigSaverGoal.toStringAsFixed(0)}',
    );

    // 4. "Smart Spender" — at least 5 approved withdrawals (i.e. responsible spending decisions)
    const smartGoal = 5;
    final smartSpender = Achievement(
      id: 'smart_spender',
      titleKey: 'ach_smartSpender_title',
      descriptionKey: 'ach_smartSpender_desc',
      icon: Icons.psychology,
      color: const Color(0xFF8B5CF6),
      earned: approvedCount >= smartGoal,
      progress: (approvedCount / smartGoal).clamp(0, 1),
      progressLabel: '$approvedCount / $smartGoal',
    );

    // 5. "Allowance Streak" — received allowance in 4+ different weeks
    final weeks = <String>{};
    for (final a in allowances) {
      final week = _isoWeek(a.createdAt);
      weeks.add(week);
    }
    const weekGoal = 4;
    final streak = Achievement(
      id: 'allowance_streak',
      titleKey: 'ach_allowanceStreak_title',
      descriptionKey: 'ach_allowanceStreak_desc',
      icon: Icons.calendar_month,
      color: const Color(0xFFEC4899),
      earned: weeks.length >= weekGoal,
      progress: (weeks.length / weekGoal).clamp(0, 1),
      progressLabel: '${weeks.length} / $weekGoal',
    );

    return [firstAllowance, saved7, bigSaver, smartSpender, streak];
  }

  /// Maximum number of consecutive days (ending today) with no expense
  /// recorded by the current user.
  static int _maxNoSpendStreak(List<TransactionModel> myTxs) {
    final today = DateTime.now();
    final spendDays = <String>{};
    for (final t in myTxs.where((t) => t.type == TransactionType.expense)) {
      spendDays.add(_dayKey(t.date));
    }
    var streak = 0;
    for (var i = 0; i < 60; i++) {
      final d = today.subtract(Duration(days: i));
      if (spendDays.contains(_dayKey(d))) break;
      streak++;
    }
    return streak;
  }

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Returns YYYY-Www. Good enough for streak counting (not strict ISO).
  static String _isoWeek(DateTime d) {
    final dayOfYear = d.difference(DateTime(d.year, 1, 1)).inDays + 1;
    final week = ((dayOfYear - d.weekday + 10) / 7).floor();
    return '${d.year}-W${week.toString().padLeft(2, '0')}';
  }
}
