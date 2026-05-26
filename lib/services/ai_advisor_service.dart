import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/budget_model.dart';
import '../models/category_model.dart';
import '../models/savings_goal_model.dart';
import '../models/transaction_model.dart';
import 'gemini_config_service.dart';

/// One message in the chat history.
class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String text;
  final AdvisorAction? action; // optional confirmable action attached to assistant
  final DateTime timestamp;
  bool actionConsumed; // true once the user has confirmed/dismissed the action

  ChatMessage({
    required this.role,
    required this.text,
    this.action,
    DateTime? timestamp,
    this.actionConsumed = false,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// A structured action proposed by the AI that the user can confirm.
class AdvisorAction {
  /// One of: create_budget, create_goal, none
  final String type;
  final Map<String, dynamic> args;

  AdvisorAction({required this.type, required this.args});

  factory AdvisorAction.fromJson(Map<String, dynamic> json) {
    return AdvisorAction(
      type: (json['type'] as String?)?.toLowerCase() ?? 'none',
      args: (json['args'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}

/// Structured response we ask Gemini to produce.
class AdvisorResponse {
  final String reply;
  final AdvisorAction? action;
  AdvisorResponse({required this.reply, this.action});
}

/// Sends financial context + chat history to Gemini and returns a structured
/// reply with an optional confirmable action.
class AiAdvisorService {
  static const _modelName = 'gemini-2.5-flash-lite';

  static Future<bool> isAvailable() async {
    final key = await GeminiConfigService.getApiKey();
    return key != null && key.trim().isNotEmpty;
  }

  static Future<AdvisorResponse> ask({
    required String userMessage,
    required List<ChatMessage> history,
    required List<TransactionModel> transactions,
    required List<BudgetModel> budgets,
    required List<SavingsGoalModel> goals,
    required String familyCurrency,
    String language = 'en',
  }) async {
    final apiKey = await GeminiConfigService.getApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const AiAdvisorException(
          'Gemini API key is not configured. Set it in Settings → AI.');
    }

    final model = GenerativeModel(
      model: _modelName,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.4,
        responseMimeType: 'application/json',
      ),
    );

    final contextBlock = _buildContextBlock(
      transactions: transactions,
      budgets: budgets,
      goals: goals,
      familyCurrency: familyCurrency,
    );

    final systemInstruction = _systemPrompt(language, familyCurrency);

    // Build conversation: prepend a synthetic system turn (Gemini doesn't have
    // a dedicated system role in v1 stable, so we embed it in the first user
    // turn), then the running history, then the new user message + context.
    final contents = <Content>[];
    contents.add(Content.text('$systemInstruction\n\n$contextBlock'));
    contents.add(Content.model([TextPart(
        jsonEncode({'reply': 'OK. I have your financial context. Ask me anything.', 'action': null}))]));

    for (final m in history) {
      if (m.role == 'user') {
        contents.add(Content.text(m.text));
      } else {
        // Re-encode prior assistant turns as JSON so the model sees its own format.
        contents.add(Content.model([
          TextPart(jsonEncode({
            'reply': m.text,
            'action': m.action == null
                ? null
                : {'type': m.action!.type, 'args': m.action!.args},
          }))
        ]));
      }
    }

    contents.add(Content.text(userMessage));

    final response = await model
        .generateContent(contents)
        .timeout(const Duration(seconds: 30));

    final text = response.text ?? '';
    if (text.trim().isEmpty) {
      throw const AiAdvisorException('Gemini returned an empty response.');
    }

    return _parseResponse(text);
  }

  // ---------- internals ----------

  static String _systemPrompt(String language, String familyCurrency) {
    final langName = switch (language) {
      'ru' => 'Russian',
      'kk' => 'Kazakh',
      _ => 'English',
    };
    return '''
You are "Budget Coach", an AI financial advisor inside a family budgeting app
used in Kazakhstan and Russia. The default family currency is $familyCurrency.

Respond in $langName. Be concise, practical, and friendly. Use concrete numbers
from the user's data. Never invent transactions. If data is insufficient, say so.

OUTPUT FORMAT: Always respond with ONLY a single JSON object matching:

{
  "reply": string,                  // your natural-language answer (markdown OK)
  "action": null | {
    "type": "create_budget" | "create_goal",
    "args": {
      // for create_budget:
      "categoryId": string,         // one of: groceries, transport, shopping,
                                    //   utilities, entertainment, healthcare,
                                    //   education, other
      "monthlyLimit": number,
      "currency": string,           // ISO code; default $familyCurrency
      "reason": string              // why you suggest this

      // for create_goal:
      // "title": string,
      // "targetAmount": number,
      // "currency": string,
      // "targetDate": "YYYY-MM-DD",
      // "category": "vacation" | "car" | "emergency" | "education" | "home" | "other",
      // "reason": string
    }
  }
}

Only propose an action when the user clearly asked you to create or set
something up (e.g. "set a food budget", "save for a vacation"). Otherwise
"action" must be null.

Never wrap the JSON in markdown fences. Never add prose before/after the JSON.
''';
  }

  static String _buildContextBlock({
    required List<TransactionModel> transactions,
    required List<BudgetModel> budgets,
    required List<SavingsGoalModel> goals,
    required String familyCurrency,
  }) {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 90));
    final recent = transactions.where((t) => t.date.isAfter(cutoff)).toList();

    // --- Monthly totals (last 3 months) ---
    final monthly = <String, _MonthBucket>{};
    for (final t in recent) {
      final key = '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}';
      final b = monthly.putIfAbsent(key, () => _MonthBucket());
      if (t.type == TransactionType.income) {
        b.income += t.amount;
      } else {
        b.expense += t.amount;
        b.byCategory[t.categoryId] =
            (b.byCategory[t.categoryId] ?? 0) + t.amount;
      }
    }
    final sortedMonths = monthly.keys.toList()..sort();

    final monthlyJson = [
      for (final k in sortedMonths)
        {
          'month': k,
          'income': _round(monthly[k]!.income),
          'expense': _round(monthly[k]!.expense),
          'net': _round(monthly[k]!.income - monthly[k]!.expense),
          'byCategory': {
            for (final e in monthly[k]!.byCategory.entries)
              e.key: _round(e.value),
          }
        }
    ];

    // --- Top 5 spending titles over 90 days ---
    final byTitle = <String, double>{};
    for (final t in recent.where((t) => t.type == TransactionType.expense)) {
      final name = t.title.trim().isEmpty ? '(untitled)' : t.title.trim();
      byTitle[name] = (byTitle[name] ?? 0) + t.amount;
    }
    final topTitles = byTitle.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = topTitles.take(5).toList();

    // --- Recent 10 transactions for grounding ---
    final last10 = (recent.toList()
          ..sort((a, b) => b.date.compareTo(a.date)))
        .take(10)
        .map((t) => {
              'date': t.date.toIso8601String().substring(0, 10),
              'title': t.title,
              'amount': _round(t.amount),
              'currency': t.currency,
              'type': t.type == TransactionType.income ? 'income' : 'expense',
              'category': t.categoryId,
              if (t.bankName != null && t.bankName!.isNotEmpty)
                'bank': t.bankName,
            })
        .toList();

    // --- Budgets ---
    final budgetsJson = budgets
        .map((b) => {
              'categoryId': b.categoryId,
              'monthlyLimit': _round(b.monthlyLimit),
              'currentSpent': _round(b.currentSpent),
              'remaining': _round(b.remaining),
              'currency': b.currency,
              'percentUsed': _round(b.percentageUsed),
            })
        .toList();

    // --- Goals ---
    final goalsJson = goals
        .map((g) => {
              'title': g.title,
              'category': g.category,
              'targetAmount': _round(g.targetAmount),
              'currentAmount': _round(g.currentAmount),
              'remaining': _round(g.remainingAmount),
              'targetDate': g.targetDate.toIso8601String().substring(0, 10),
              'daysRemaining': g.daysRemaining,
              'monthlySavingsNeeded': _round(g.monthlySavingsNeeded),
            })
        .toList();

    final validCategoryIds = defaultCategories
        .where((c) => c.type == TransactionType.expense)
        .map((c) => c.id)
        .toList();

    final payload = {
      'today': now.toIso8601String().substring(0, 10),
      'familyCurrency': familyCurrency,
      'validExpenseCategoryIds': validCategoryIds,
      'monthlyTotals': monthlyJson,
      'topSpending90d': [
        for (final e in top5)
          {'title': e.key, 'amount': _round(e.value)}
      ],
      'recentTransactions': last10,
      'budgets': budgetsJson,
      'goals': goalsJson,
    };

    return '''
USER FINANCIAL CONTEXT (use these numbers, do not invent others):
${const JsonEncoder.withIndent('  ').convert(payload)}
''';
  }

  static double _round(double v) =>
      (v * 100).roundToDouble() / 100;

  static AdvisorResponse _parseResponse(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      // Treat as plain text fallback.
      return AdvisorResponse(reply: text.trim());
    }
    final jsonStr = text.substring(start, end + 1);
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final reply = (data['reply'] as String?)?.trim() ?? '';
      final rawAction = data['action'];
      AdvisorAction? action;
      if (rawAction is Map) {
        final m = rawAction.cast<String, dynamic>();
        final type = (m['type'] as String?)?.toLowerCase();
        if (type != null && type != 'none' && type.isNotEmpty) {
          action = AdvisorAction.fromJson(m);
        }
      }
      if (kDebugMode) {
        debugPrint('[AiAdvisor] reply.len=${reply.length} action=${action?.type}');
      }
      return AdvisorResponse(
        reply: reply.isEmpty ? text.trim() : reply,
        action: action,
      );
    } catch (e) {
      return AdvisorResponse(reply: text.trim());
    }
  }
}

class _MonthBucket {
  double income = 0;
  double expense = 0;
  final Map<String, double> byCategory = {};
}

class AiAdvisorException implements Exception {
  final String message;
  const AiAdvisorException(this.message);

  @override
  String toString() => message;
}
