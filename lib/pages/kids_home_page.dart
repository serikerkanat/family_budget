import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/achievement_model.dart';
import '../models/savings_goal_model.dart';
import '../models/transaction_model.dart';
import '../models/withdrawal_request_model.dart';
import '../services/firestore_service.dart';
import '../services/kids_service.dart';
import '../services/savings_goal_service.dart';
import '../services/user_service.dart';
import '../widgets/growing_tree.dart';

class KidsHomePage extends StatefulWidget {
  const KidsHomePage({super.key});

  @override
  State<KidsHomePage> createState() => _KidsHomePageState();
}

class _KidsHomePageState extends State<KidsHomePage> {
  String? _uid;
  String _userName = '';
  String _currency = 'KZT';

  List<AllowanceEntry> _allowances = const [];
  List<WithdrawalRequest> _requests = const [];
  List<TransactionModel> _myTransactions = const [];
  SavingsGoalModel? _primaryGoal;

  StreamSubscription? _allowSub;
  StreamSubscription? _reqSub;
  StreamSubscription? _txSub;
  StreamSubscription? _goalsSub;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _uid = KidsService.currentUid;
    final data = await UserService.getCurrentUserData();
    if (mounted) {
      setState(() {
        _userName =
            (data?['name'] as String?) ?? (data?['email'] as String?) ?? '';
        _loading = false;
      });
    }
    if (_uid == null) return;

    _allowSub = KidsService.allowancesFor(_uid!).listen((v) {
      if (mounted) setState(() => _allowances = v);
    });
    _reqSub = KidsService.requestsByChild(_uid!).listen((v) {
      if (mounted) setState(() => _requests = v);
    });
    _txSub = FirestoreService.getTransactions().listen((all) {
      // "My transactions" = ones I created.
      final mine = all.where((t) => true).toList(); // family-wide for now
      if (mounted) setState(() => _myTransactions = mine);
    });
    _goalsSub = SavingsGoalService.getSavingsGoals().listen((goals) {
      if (goals.isEmpty) {
        if (mounted) setState(() => _primaryGoal = null);
        return;
      }
      // Pick the goal closest to (but not over) its target.
      final active = goals.where((g) => !g.isAchieved).toList();
      final picked = (active.isEmpty ? goals : active)
        ..sort((a, b) => b.percentageSaved.compareTo(a.percentageSaved));
      if (mounted) setState(() => _primaryGoal = picked.first);
    });
  }

  @override
  void dispose() {
    _allowSub?.cancel();
    _reqSub?.cancel();
    _txSub?.cancel();
    _goalsSub?.cancel();
    super.dispose();
  }

  double get _balance => KidsService.computeBalance(
        allowances: _allowances,
        requests: _requests,
      );

  List<Achievement> get _achievements => AchievementService.compute(
        allowances: _allowances,
        requests: _requests,
        myTransactions: _myTransactions,
      );

  double get _treeProgress {
    if (_primaryGoal == null) return (_balance / 5000).clamp(0, 1);
    return (_primaryGoal!.percentageSaved / 100).clamp(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    _currency = context.appCurrency.code;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFDF4FF),
      appBar: AppBar(
        title: Text(context.t('kidsMode')),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildGreetingAndBalance(),
              _buildTreeCard(),
              _buildActions(),
              _buildBadges(),
              _buildRecentRequests(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ----- Sections -----

  Widget _buildGreetingAndBalance() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _userName.isEmpty
                ? '👋 ${context.t('hello')}'
                : '👋 ${context.t('hello')}, $_userName',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Text(
            context.t('yourBalance'),
            style:
                const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                NumberFormat.decimalPattern().format(_balance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_currency,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTreeCard() {
    final goal = _primaryGoal;
    final pct = (_treeProgress * 100).round();
    final goalLabel = goal == null
        ? context.tx('savedTowardsTarget',
            {'pct': pct.toString(), 'target': '5 000'})
        : context.tx('goalProgress',
            {'title': goal.title, 'pct': pct.toString()});

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            context.t('yourSavingsTree'),
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF065F46)),
          ),
          const SizedBox(height: 8),
          GrowingTree(progress: _treeProgress, size: 200),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              goalLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF065F46)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _openRequestSheet,
              icon: const Icon(Icons.shopping_bag_outlined),
              label: Text(context.t('requestMoney')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEC4899),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadges() {
    final ach = _achievements;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              Text(
                context.t('myBadges'),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${ach.where((a) => a.earned).length} / ${ach.length}',
                style: const TextStyle(
                    color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.55,
            ),
            itemCount: ach.length,
            itemBuilder: (context, i) => _BadgeTile(achievement: ach[i]),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRequests() {
    if (_requests.isEmpty) return const SizedBox.shrink();
    final recent = _requests.take(5).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('myRequests'),
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...recent.map((r) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Icon(_statusIcon(r.status), color: _statusColor(r.status)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.reason,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat.yMMMd().format(r.createdAt),
                            style: const TextStyle(
                                color: Color(0xFF6B7280), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${NumberFormat.decimalPattern().format(r.amount)} ${r.currency}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          context.t('status_${r.status.value}'),
                          style: TextStyle(
                              color: _statusColor(r.status),
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  IconData _statusIcon(WithdrawalStatus s) => switch (s) {
        WithdrawalStatus.pending => Icons.hourglass_top,
        WithdrawalStatus.approved => Icons.check_circle,
        WithdrawalStatus.rejected => Icons.cancel,
      };

  Color _statusColor(WithdrawalStatus s) => switch (s) {
        WithdrawalStatus.pending => const Color(0xFFD97706),
        WithdrawalStatus.approved => const Color(0xFF059669),
        WithdrawalStatus.rejected => const Color(0xFFB91C1C),
      };

  void _openRequestSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RequestSheet(currency: _currency),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final Achievement achievement;
  const _BadgeTile({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final earned = achievement.earned;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: earned ? achievement.color.withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: earned
              ? achievement.color.withValues(alpha: 0.4)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: earned
                      ? achievement.color
                      : const Color(0xFFE5E7EB),
                  shape: BoxShape.circle,
                ),
                child: Icon(achievement.icon,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.t(achievement.titleKey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: earned
                        ? achievement.color
                        : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
          Text(
            context.t(achievement.descriptionKey),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 11, color: Color(0xFF6B7280), height: 1.2),
          ),
          if (!earned)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: achievement.progress,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: AlwaysStoppedAnimation(achievement.color),
                    ),
                  ),
                  if (achievement.progressLabel != null)
                    Text(
                      achievement.progressLabel!,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF6B7280)),
                    ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      color: achievement.color, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    context.t('earned'),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: achievement.color),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RequestSheet extends StatefulWidget {
  final String currency;
  const _RequestSheet({required this.currency});

  @override
  State<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<_RequestSheet> {
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount =
        double.tryParse(_amountCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    final reason = _reasonCtrl.text.trim();
    if (amount <= 0 || reason.isEmpty) {
      setState(() => _error = context.t('fillAllFields'));
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final successMsg = context.t('requestSent');
    try {
      await KidsService.createRequest(
        amount: amount,
        currency: widget.currency,
        reason: reason,
      );
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(successMsg)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              context.t('requestMoney'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: context.t('amount'),
                prefixIcon: const Icon(Icons.attach_money),
                border: const OutlineInputBorder(),
                suffixText: widget.currency,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: context.t('reason'),
                prefixIcon: const Icon(Icons.edit_note),
                border: const OutlineInputBorder(),
                hintText: context.t('reasonHint'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send),
              label: Text(context.t('send')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEC4899),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
