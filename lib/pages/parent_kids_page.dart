import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/withdrawal_request_model.dart';
import '../services/family_service.dart';
import '../services/kids_service.dart';
import '../services/user_service.dart';

/// Parent screen with two tabs:
///   • Approvals — pending withdrawal requests from kids
///   • Allowance — give a one-off allowance to a child
class ParentKidsPage extends StatefulWidget {
  const ParentKidsPage({super.key});

  @override
  State<ParentKidsPage> createState() => _ParentKidsPageState();
}

class _ParentKidsPageState extends State<ParentKidsPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7F6),
        appBar: AppBar(
          title: Text(context.t('kidsManagement')),
          bottom: TabBar(
            tabs: [
              Tab(text: context.t('approvals')),
              Tab(text: context.t('giveAllowance')),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ApprovalsTab(),
            _AllowanceTab(),
          ],
        ),
      ),
    );
  }
}

class _ApprovalsTab extends StatelessWidget {
  const _ApprovalsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WithdrawalRequest>>(
      stream: KidsService.pendingRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snapshot.data ?? const [];
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 72, color: Color(0xFF10B981)),
                  const SizedBox(height: 12),
                  Text(
                    context.t('noPendingRequests'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.t('allCaughtUp'),
                    style: const TextStyle(color: Color(0xFF6B7280)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (context, i) => _RequestCard(request: list[i]),
        );
      },
    );
  }
}

class _RequestCard extends StatefulWidget {
  final WithdrawalRequest request;
  const _RequestCard({required this.request});

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _busy = false;

  Future<void> _decide(bool approve) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final okMsg = context
        .t(approve ? 'requestApproved' : 'requestRejected');
    try {
      if (approve) {
        await KidsService.approveRequest(widget.request);
      } else {
        await KidsService.rejectRequest(widget.request);
      }
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(okMsg)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFEC4899),
                child: Text(
                  r.childName.isNotEmpty
                      ? r.childName.characters.first.toUpperCase()
                      : '?',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.childName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(
                      DateFormat.yMMMd().add_jm().format(r.createdAt),
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                '${NumberFormat.decimalPattern().format(r.amount)} ${r.currency}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(r.reason),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _decide(false),
                  icon: const Icon(Icons.close, color: Color(0xFFB91C1C)),
                  label: Text(context.t('reject'),
                      style: const TextStyle(color: Color(0xFFB91C1C))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFB91C1C)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : () => _decide(true),
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check),
                  label: Text(context.t('approve')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class _AllowanceTab extends StatefulWidget {
  const _AllowanceTab();

  @override
  State<_AllowanceTab> createState() => _AllowanceTabState();
}

class _AllowanceTabState extends State<_AllowanceTab> {
  List<Map<String, dynamic>> _children = const [];
  String? _selectedUid;
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadChildren() async {
    try {
      final familyId = await UserService.getUserFamilyId();
      if (familyId == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final members = await FamilyService.getFamilyMembers(familyId);
      if (!mounted) return;
      setState(() {
        _children = members
            .where((m) =>
                (m['role'] as String?) == 'child' ||
                (m['role'] as String?) == 'member')
            .toList();
        if (_children.isNotEmpty) {
          _selectedUid = _children.first['id'] as String?;
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _giveAllowance() async {
    final amount = double.tryParse(
            _amountCtrl.text.trim().replaceAll(',', '.')) ??
        0;
    if (_selectedUid == null || amount <= 0) return;
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final currency = context.appCurrency.code;
    final successMsg = context.t('allowanceGiven');
    try {
      await KidsService.giveAllowance(
        childUid: _selectedUid!,
        amount: amount,
        currency: currency,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      _amountCtrl.clear();
      _noteCtrl.clear();
      messenger.showSnackBar(SnackBar(content: Text(successMsg)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_children.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.t('noChildrenInFamily'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF6B7280)),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.t('chooseChild'),
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedUid,
                items: _children
                    .map((c) => DropdownMenuItem<String>(
                          value: c['id'] as String?,
                          child: Text(
                              (c['name'] as String?) ??
                                  (c['email'] as String?) ??
                                  '—'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedUid = v),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: context.t('amount'),
              border: const OutlineInputBorder(),
              suffixText: context.appCurrency.code,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: InputDecoration(
              labelText: context.t('noteOptional'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _submitting ? null : _giveAllowance,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.payments),
            label: Text(context.t('giveAllowance')),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
