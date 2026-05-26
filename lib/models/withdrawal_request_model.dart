import 'package:cloud_firestore/cloud_firestore.dart';

enum WithdrawalStatus { pending, approved, rejected }

extension WithdrawalStatusX on WithdrawalStatus {
  String get value => switch (this) {
        WithdrawalStatus.pending => 'pending',
        WithdrawalStatus.approved => 'approved',
        WithdrawalStatus.rejected => 'rejected',
      };

  static WithdrawalStatus fromString(String? v) => switch (v) {
        'approved' => WithdrawalStatus.approved,
        'rejected' => WithdrawalStatus.rejected,
        _ => WithdrawalStatus.pending,
      };
}

class WithdrawalRequest {
  final String id;
  final String familyId;
  final String childUid;
  final String childName;
  final double amount;
  final String currency;
  final String reason;
  final WithdrawalStatus status;
  final DateTime createdAt;
  final DateTime? decidedAt;
  final String? decidedBy;
  final String? decisionNote;

  WithdrawalRequest({
    required this.id,
    required this.familyId,
    required this.childUid,
    required this.childName,
    required this.amount,
    required this.currency,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.decidedAt,
    this.decidedBy,
    this.decisionNote,
  });

  Map<String, dynamic> toFirestore() => {
        'familyId': familyId,
        'childUid': childUid,
        'childName': childName,
        'amount': amount,
        'currency': currency,
        'reason': reason,
        'status': status.value,
        'createdAt': Timestamp.fromDate(createdAt),
        if (decidedAt != null) 'decidedAt': Timestamp.fromDate(decidedAt!),
        if (decidedBy != null) 'decidedBy': decidedBy,
        if (decisionNote != null) 'decisionNote': decisionNote,
      };

  factory WithdrawalRequest.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return WithdrawalRequest(
      id: doc.id,
      familyId: d['familyId'] ?? '',
      childUid: d['childUid'] ?? '',
      childName: d['childName'] ?? '',
      amount: (d['amount'] as num?)?.toDouble() ?? 0,
      currency: d['currency'] ?? 'USD',
      reason: d['reason'] ?? '',
      status: WithdrawalStatusX.fromString(d['status'] as String?),
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      decidedAt: (d['decidedAt'] as Timestamp?)?.toDate(),
      decidedBy: d['decidedBy'] as String?,
      decisionNote: d['decisionNote'] as String?,
    );
  }
}
