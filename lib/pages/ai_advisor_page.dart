import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../l10n/app_localizations.dart';
import '../models/budget_model.dart';
import '../models/category_model.dart';
import '../models/savings_goal_model.dart';
import '../models/transaction_model.dart';
import '../services/ai_advisor_service.dart';
import '../services/budget_service.dart';
import '../services/firestore_service.dart';
import '../services/savings_goal_service.dart';
import '../services/user_service.dart';

class AiAdvisorPage extends StatefulWidget {
  const AiAdvisorPage({super.key});

  @override
  State<AiAdvisorPage> createState() => _AiAdvisorPageState();
}

class _AiAdvisorPageState extends State<AiAdvisorPage> {
  static const _teal = Color(0xFF0F766E);

  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _sending = false;
  String? _error;

  // Cached financial context (refreshed on each send).
  List<TransactionModel> _transactions = const [];
  List<BudgetModel> _budgets = const [];
  List<SavingsGoalModel> _goals = const [];

  StreamSubscription<List<TransactionModel>>? _txSub;
  StreamSubscription<List<BudgetModel>>? _budgetSub;
  StreamSubscription<List<SavingsGoalModel>>? _goalSub;

  @override
  void initState() {
    super.initState();
    _txSub = FirestoreService.getTransactions().listen((v) {
      _transactions = v;
    });
    _budgetSub = BudgetService.getBudgets().listen((v) {
      _budgets = v;
    });
    _goalSub = SavingsGoalService.getSavingsGoals().listen((v) {
      _goals = v;
    });

    // Seed greeting.
    _messages.add(ChatMessage(
      role: 'assistant',
      text: _greeting(),
    ));
  }

  String _greeting() {
    // Localized greeting fetched lazily in build via context.t, but we need an
    // initial string before build runs. Provide neutral English; first rebuild
    // will keep it. For better i18n, you could move this to didChangeDependencies.
    return "Hi! I'm your Budget Coach. Ask me anything about your spending, or tell me to set up a budget / savings goal.";
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _txSub?.cancel();
    _budgetSub?.cancel();
    _goalSub?.cancel();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;

    // Capture context-dependent values up-front (before any awaits).
    final keyMissingMsg = context.t('aiKeyMissing');
    final familyCurrency = context.appCurrency.code;
    final lang = context.appLanguage.code;

    final available = await AiAdvisorService.isAvailable();
    if (!mounted) return;
    if (!available) {
      setState(() => _error = keyMissingMsg);
      return;
    }

    setState(() {
      _messages.add(ChatMessage(role: 'user', text: text));
      _input.clear();
      _sending = true;
      _error = null;
    });
    _scrollToBottom();

    try {

      // history excludes the just-added user message (we pass it separately).
      final history = _messages.sublist(0, _messages.length - 1);

      final resp = await AiAdvisorService.ask(
        userMessage: text,
        history: history,
        transactions: _transactions,
        budgets: _budgets,
        goals: _goals,
        familyCurrency: familyCurrency,
        language: lang,
      );

      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          text: resp.reply,
          action: resp.action,
        ));
        _sending = false;
      });
      _scrollToBottom();
    } on AiAdvisorException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = '$e';
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _confirmAction(ChatMessage msg) async {
    final action = msg.action;
    if (action == null) return;

    // Capture context-dependent values up-front (avoid use_build_context_synchronously).
    final fallbackCurrency = context.appCurrency.code;
    final budgetCreatedTemplate = context.t('budgetCreatedFor');
    final goalCreatedTemplate = context.t('goalCreatedFor');
    final txCreatedMsg = context.t('transactionCreated');
    final messenger = ScaffoldMessenger.of(context);

    try {
      final familyId = await UserService.getUserFamilyId();
      if (familyId == null) {
        throw Exception('User is not in a family');
      }
      final uid = UserService.currentUserId ?? '';

      String successMsg;
      switch (action.type) {
        case 'create_budget':
          final categoryId =
              (action.args['categoryId'] as String?) ?? 'other';
          final limit = (action.args['monthlyLimit'] as num?)?.toDouble() ?? 0;
          final currency =
              (action.args['currency'] as String?) ?? fallbackCurrency;
          if (limit <= 0) {
            throw Exception('Invalid monthly limit');
          }
          final category = defaultCategories.firstWhere(
            (c) => c.id == categoryId,
            orElse: () => defaultCategories.firstWhere((c) => c.id == 'other'),
          );
          await BudgetService.setBudget(BudgetModel(
            id: const Uuid().v4(),
            categoryId: category.id,
            categoryName: category.name,
            monthlyLimit: limit,
            currentSpent: 0,
            currency: currency,
            createdAt: DateTime.now(),
            createdBy: uid,
            familyId: familyId,
          ));
          successMsg =
              budgetCreatedTemplate.replaceAll('{category}', category.name);
          break;

        case 'create_goal':
          final title = (action.args['title'] as String?)?.trim() ?? 'Goal';
          final target =
              (action.args['targetAmount'] as num?)?.toDouble() ?? 0;
          final targetDateStr = action.args['targetDate'] as String?;
          final date =
              DateTime.tryParse(targetDateStr ?? '') ??
                  DateTime.now().add(const Duration(days: 180));
          final category = (action.args['category'] as String?) ?? 'other';
          if (target <= 0) {
            throw Exception('Invalid target amount');
          }
          await SavingsGoalService.createSavingsGoal(SavingsGoalModel(
            id: const Uuid().v4(),
            title: title,
            description: (action.args['reason'] as String?) ?? '',
            targetAmount: target,
            currentAmount: 0,
            targetDate: date,
            createdAt: DateTime.now(),
            createdBy: uid,
            familyId: familyId,
            category: category,
          ));
          successMsg = goalCreatedTemplate.replaceAll('{title}', title);
          break;

        case 'create_transaction':
          final title = (action.args['title'] as String?)?.trim() ?? 'AI Transaction';
          final amount = (action.args['amount'] as num?)?.toDouble() ?? 0;
          final typeStr = (action.args['type'] as String?)?.toLowerCase() ?? 'expense';
          final categoryId = (action.args['categoryId'] as String?) ?? 'other';
          final dateStr = action.args['date'] as String?;
          final date = DateTime.tryParse(dateStr ?? '') ?? DateTime.now();
          final notes = (action.args['notes'] as String?) ?? 'Created by AI Advisor';
          if (amount <= 0) throw Exception('Invalid amount');
          final category = defaultCategories.firstWhere(
            (c) => c.id == categoryId,
            orElse: () => defaultCategories.firstWhere((c) => c.id == 'other'),
          );
          await FirestoreService.addTransaction(TransactionModel(
            id: const Uuid().v4(),
            title: title,
            amount: amount,
            date: date,
            type: typeStr == 'income'
                ? TransactionType.income
                : TransactionType.expense,
            categoryId: category.id,
            notes: notes,
            currency: fallbackCurrency,
          ));
          successMsg = txCreatedMsg.replaceAll('{title}', title);
          break;

        default:
          throw Exception('Unknown action: ${action.type}');
      }

      if (!mounted) return;
      setState(() {
        msg.actionConsumed = true;
        _messages.add(ChatMessage(role: 'assistant', text: '✅ $successMsg'));
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _dismissAction(ChatMessage msg) {
    setState(() => msg.actionConsumed = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: Text(context.t('aiAdvisor')),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 16),
                itemCount: _messages.length + (_sending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _messages.length) {
                    return const _TypingIndicator();
                  }
                  return _MessageBubble(
                    message: _messages[index],
                    onConfirm: () => _confirmAction(_messages[index]),
                    onDismiss: () => _dismissAction(_messages[index]),
                  );
                },
              ),
            ),
            if (_error != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_error!,
                    style: const TextStyle(color: Color(0xFFB91C1C))),
              ),
            _buildSuggestions(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    if (_messages.length > 1) return const SizedBox.shrink();
    final suggestions = [
      context.t('suggestOverspend'),
      context.t('suggestAfford'),
      context.t('suggestSave'),
      context.t('suggestBudget'),
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final s = suggestions[i];
          return ActionChip(
            label: Text(s, overflow: TextOverflow.ellipsis),
            onPressed: () {
              _input.text = s;
              _send();
            },
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: context.t('askAnything'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: _teal,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send, color: Colors.white),
              onPressed: _sending ? null : _send,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  const _MessageBubble({
    required this.message,
    required this.onConfirm,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Column(
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82),
          decoration: BoxDecoration(
            color: isUser ? const Color(0xFF0F766E) : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
            border: isUser
                ? null
                : Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Text(
            message.text,
            style: TextStyle(
                color: isUser ? Colors.white : const Color(0xFF1F2937),
                height: 1.35),
          ),
        ),
        if (!isUser &&
            message.action != null &&
            !message.actionConsumed)
          _ActionCard(
            action: message.action!,
            onConfirm: onConfirm,
            onDismiss: onDismiss,
          ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final AdvisorAction action;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;
  const _ActionCard({
    required this.action,
    required this.onConfirm,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isBudget = action.type == 'create_budget';
    final title = isBudget
        ? context.t('proposedBudget')
        : context.t('proposedGoal');
    final icon = isBudget ? Icons.savings_outlined : Icons.flag_outlined;

    String formatMoney(num v, String currency) =>
        '${NumberFormat.decimalPattern().format(v)} $currency';

    final lines = <Widget>[];
    if (isBudget) {
      final categoryId = (action.args['categoryId'] as String?) ?? 'other';
      final limit = (action.args['monthlyLimit'] as num?) ?? 0;
      final currency = (action.args['currency'] as String?) ?? '';
      final reason = (action.args['reason'] as String?) ?? '';
      lines.add(_kvRow(context.t('category'), categoryId));
      lines.add(_kvRow(context.t('monthlyLimit'), formatMoney(limit, currency)));
      if (reason.isNotEmpty) lines.add(_kvRow(context.t('reason'), reason));
    } else {
      final goalTitle = (action.args['title'] as String?) ?? '';
      final target = (action.args['targetAmount'] as num?) ?? 0;
      final currency = (action.args['currency'] as String?) ?? '';
      final date = (action.args['targetDate'] as String?) ?? '';
      final reason = (action.args['reason'] as String?) ?? '';
      lines.add(_kvRow(context.t('title'), goalTitle));
      lines.add(_kvRow(context.t('targetAmount'), formatMoney(target, currency)));
      if (date.isNotEmpty) lines.add(_kvRow(context.t('targetDate'), date));
      if (reason.isNotEmpty) lines.add(_kvRow(context.t('reason'), reason));
    }

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 8),
      padding: const EdgeInsets.all(12),
      constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82),
      decoration: BoxDecoration(
        color: const Color(0xFFECFEFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF67E8F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: const Color(0xFF0E7490)),
            const SizedBox(width: 6),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: Color(0xFF0E7490))),
          ]),
          const SizedBox(height: 6),
          ...lines,
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onDismiss,
                child: Text(context.t('dismiss')),
              ),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.check, size: 18),
                label: Text(context.t('confirmCreate')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E7490),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _kvRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(k,
                style: const TextStyle(
                    color: Color(0xFF155E75), fontWeight: FontWeight.w600)),
          ),
          Expanded(
              child: Text(v,
                  style: const TextStyle(color: Color(0xFF134E4A)))),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF0F766E))),
            SizedBox(width: 8),
            Text('Thinking…',
                style: TextStyle(color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }
}
