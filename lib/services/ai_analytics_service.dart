import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/budget_model.dart';
import '../models/category_model.dart';
import '../models/savings_goal_model.dart';
import '../models/transaction_model.dart';
import 'gemini_config_service.dart';

/// A single finding/observation produced by Gemini.
class AnalyticsFinding {
  final String title;
  final String detail;

  /// One of: positive, negative, neutral, warning.
  final String tone;

  /// Optional category id (one of [defaultCategories] ids) for highlighting.
  final String? categoryId;

  AnalyticsFinding({
    required this.title,
    required this.detail,
    this.tone = 'neutral',
    this.categoryId,
  });

  factory AnalyticsFinding.fromJson(Map<String, dynamic> j) => AnalyticsFinding(
        title: (j['title'] as String?)?.trim() ?? '',
        detail: (j['detail'] as String?)?.trim() ?? '',
        tone: (j['tone'] as String?)?.trim().toLowerCase() ?? 'neutral',
        categoryId: (j['categoryId'] as String?)?.trim(),
      );
}

class AnalyticsRecommendation {
  final String title;
  final String reason;

  /// One of: low, medium, high.
  final String impact;

  AnalyticsRecommendation({
    required this.title,
    required this.reason,
    this.impact = 'medium',
  });

  factory AnalyticsRecommendation.fromJson(Map<String, dynamic> j) =>
      AnalyticsRecommendation(
        title: (j['title'] as String?)?.trim() ?? '',
        reason: (j['reason'] as String?)?.trim() ?? '',
        impact: (j['impact'] as String?)?.trim().toLowerCase() ?? 'medium',
      );
}

class CategoryInsight {
  final String categoryId;

  /// E.g. "+23% vs prior month", "-5% vs prior month", "stable".
  final String trend;
  final String note;

  CategoryInsight({
    required this.categoryId,
    required this.trend,
    required this.note,
  });

  factory CategoryInsight.fromJson(Map<String, dynamic> j) => CategoryInsight(
        categoryId: (j['categoryId'] as String?)?.trim() ?? 'other',
        trend: (j['trend'] as String?)?.trim() ?? '',
        note: (j['note'] as String?)?.trim() ?? '',
      );
}

class AnalyticsReport {
  /// One-sentence summary of overall financial health.
  final String headline;

  /// A short "letter grade" or rating like A, B+, C, etc.
  final String healthGrade;

  /// 0..100 financial health score.
  final int healthScore;

  final List<AnalyticsFinding> findings;
  final List<AnalyticsRecommendation> recommendations;
  final List<CategoryInsight> categoryInsights;

  /// Narrative version of the next-30-days forecast.
  final String forecastNarrative;

  final DateTime generatedAt;

  AnalyticsReport({
    required this.headline,
    required this.healthGrade,
    required this.healthScore,
    required this.findings,
    required this.recommendations,
    required this.categoryInsights,
    required this.forecastNarrative,
    required this.generatedAt,
  });
}

class AiAnalyticsService {
  static const _modelName = 'gemini-2.5-flash-lite';

  static Future<bool> isAvailable() async {
    final key = await GeminiConfigService.getApiKey();
    return key != null && key.trim().isNotEmpty;
  }

  static Future<AnalyticsReport> generateReport({
    required List<TransactionModel> transactions,
    required List<BudgetModel> budgets,
    required List<SavingsGoalModel> goals,
    required String familyCurrency,
    String language = 'en',
  }) async {
    final apiKey = await GeminiConfigService.getApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const AiAnalyticsException(
          'Gemini API key is not configured. Set it in Settings → AI.');
    }

    final model = GenerativeModel(
      model: _modelName,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.3,
        responseMimeType: 'application/json',
      ),
    );

    final context = _buildContext(
      transactions: transactions,
      budgets: budgets,
      goals: goals,
      familyCurrency: familyCurrency,
    );

    final prompt = _systemPrompt(language, familyCurrency);

    final response = await model.generateContent([
      Content.text('$prompt\n\n$context'),
    ]).timeout(const Duration(seconds: 45));

    final text = response.text ?? '';
    if (text.trim().isEmpty) {
      throw const AiAnalyticsException('Gemini returned an empty response.');
    }

    return _parseReport(text);
  }

  // ---------- internals ----------

  static String _systemPrompt(String language, String familyCurrency) {
    final langName = switch (language) {
      'ru' => 'Russian',
      'kk' => 'Kazakh',
      _ => 'English',
    };

    return '''
You are a precise financial analyst inside a family budgeting app used in
Kazakhstan and Russia. The family currency is $familyCurrency.

Respond in $langName. Be specific, use concrete numbers from the data, and
NEVER invent transactions or amounts that aren't in the context block.

OUTPUT FORMAT: a single JSON object matching exactly this schema (no markdown
fences, no prose outside JSON):

{
  "headline": string,                  // one sentence summary of financial health
  "healthGrade": "A" | "A-" | "B+" | "B" | "B-" | "C+" | "C" | "C-" | "D" | "F",
  "healthScore": integer 0..100,
  "findings": [                        // 3 to 5 data-driven observations
    {
      "title": string,                 // short title (<= 8 words)
      "detail": string,                // 1-2 sentences citing concrete numbers
      "tone": "positive" | "negative" | "warning" | "neutral",
      "categoryId": string | null      // one of the validExpenseCategoryIds, optional
    }
  ],
  "recommendations": [                 // 3 to 5 actionable items
    {
      "title": string,                 // short imperative title
      "reason": string,                // why; 1-2 sentences
      "impact": "low" | "medium" | "high"
    }
  ],
  "categoryInsights": [                // up to 5 categories with biggest impact
    {
      "categoryId": string,            // must be from validExpenseCategoryIds
      "trend": string,                 // e.g. "+23% vs prior month", "stable"
      "note": string                   // 1 sentence note
    }
  ],
  "forecastNarrative": string          // 2-3 sentence forward-looking outlook
}

Rules:
- Health score reflects: savings rate, budget adherence, spending volatility,
  goal progress. 80+ = great; 60-79 = okay; <60 = needs attention.
- Findings must be specific. Avoid generic statements like "you spent money".
- Compare last 30 days vs prior 30 days when computing trends.
- Categories must use ONLY ids listed in validExpenseCategoryIds.
- If data is thin (<10 transactions), set healthScore <=50 and mention this in
  the headline.
- Never give legal/tax advice or external product recommendations.
''';
  }

  static String _buildContext({
    required List<TransactionModel> transactions,
    required List<BudgetModel> budgets,
    required List<SavingsGoalModel> goals,
    required String familyCurrency,
  }) {
    final now = DateTime.now();
    final last30 = now.subtract(const Duration(days: 30));
    final prev30 = now.subtract(const Duration(days: 60));
    final last90 = now.subtract(const Duration(days: 90));

    final all90 =
        transactions.where((t) => t.date.isAfter(last90)).toList();
    final last30Txs =
        all90.where((t) => t.date.isAfter(last30)).toList();
    final prev30Txs = all90
        .where((t) => t.date.isAfter(prev30) && !t.date.isAfter(last30))
        .toList();

    double sumExpense(Iterable<TransactionModel> xs) => xs
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (a, b) => a + b.amount);
    double sumIncome(Iterable<TransactionModel> xs) => xs
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (a, b) => a + b.amount);

    Map<String, double> byCategory(Iterable<TransactionModel> xs) {
      final m = <String, double>{};
      for (final t in xs.where((t) => t.type == TransactionType.expense)) {
        m[t.categoryId] = (m[t.categoryId] ?? 0) + t.amount;
      }
      return m;
    }

    final exp30 = sumExpense(last30Txs);
    final exp30Prev = sumExpense(prev30Txs);
    final inc30 = sumIncome(last30Txs);
    final inc30Prev = sumIncome(prev30Txs);

    final cat30 = byCategory(last30Txs);
    final cat30Prev = byCategory(prev30Txs);

    final allCategoryIds = {...cat30.keys, ...cat30Prev.keys};
    final categoryDeltas = <Map<String, dynamic>>[];
    for (final id in allCategoryIds) {
      final cur = cat30[id] ?? 0;
      final prev = cat30Prev[id] ?? 0;
      final delta = cur - prev;
      final pct =
          prev > 0 ? (delta / prev * 100) : (cur > 0 ? 100.0 : 0.0);
      categoryDeltas.add({
        'categoryId': id,
        'last30': _round(cur),
        'prev30': _round(prev),
        'deltaPct': pct.round(),
      });
    }
    categoryDeltas.sort((a, b) => (b['last30'] as num)
        .abs()
        .compareTo((a['last30'] as num).abs()));

    // Daily series (last 30 days) — helps Gemini spot volatility.
    final daily = <String, double>{};
    for (final t
        in last30Txs.where((t) => t.type == TransactionType.expense)) {
      final k =
          '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}';
      daily[k] = (daily[k] ?? 0) + t.amount;
    }
    final dailyEntries = daily.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    // Recurring weekday pattern.
    final byWeekday = <int, double>{};
    for (final t
        in last30Txs.where((t) => t.type == TransactionType.expense)) {
      byWeekday[t.date.weekday] =
          (byWeekday[t.date.weekday] ?? 0) + t.amount;
    }

    // Top single transactions.
    final bigTxs = last30Txs
        .where((t) => t.type == TransactionType.expense)
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final top5 = bigTxs.take(5).map((t) => {
          'date': t.date.toIso8601String().substring(0, 10),
          'title': t.title,
          'category': t.categoryId,
          'amount': _round(t.amount),
          'currency': t.currency,
        });

    final validIds = defaultCategories
        .where((c) => c.type == TransactionType.expense)
        .map((c) => c.id)
        .toList();

    final budgetsJson = budgets
        .map((b) => {
              'categoryId': b.categoryId,
              'monthlyLimit': _round(b.monthlyLimit),
              'currentSpent': _round(b.currentSpent),
              'percentUsed': _round(b.percentageUsed),
              'isExceeded': b.isExceeded,
            })
        .toList();

    final goalsJson = goals
        .map((g) => {
              'title': g.title,
              'targetAmount': _round(g.targetAmount),
              'currentAmount': _round(g.currentAmount),
              'percentSaved': _round(g.percentageSaved),
              'targetDate': g.targetDate.toIso8601String().substring(0, 10),
              'daysRemaining': g.daysRemaining,
              'monthlyNeeded': _round(g.monthlySavingsNeeded),
            })
        .toList();

    final savingsRate =
        inc30 > 0 ? ((inc30 - exp30) / inc30 * 100).round() : 0;
    final expenseChangePct = exp30Prev > 0
        ? ((exp30 - exp30Prev) / exp30Prev * 100).round()
        : (exp30 > 0 ? 100 : 0);
    final incomeChangePct = inc30Prev > 0
        ? ((inc30 - inc30Prev) / inc30Prev * 100).round()
        : (inc30 > 0 ? 100 : 0);

    final payload = {
      'today': now.toIso8601String().substring(0, 10),
      'familyCurrency': familyCurrency,
      'validExpenseCategoryIds': validIds,
      'totals': {
        'last30': {
          'income': _round(inc30),
          'expense': _round(exp30),
          'net': _round(inc30 - exp30),
          'savingsRatePct': savingsRate,
          'transactionCount': last30Txs.length,
        },
        'prev30': {
          'income': _round(inc30Prev),
          'expense': _round(exp30Prev),
          'transactionCount': prev30Txs.length,
        },
        'changes': {
          'expensePct': expenseChangePct,
          'incomePct': incomeChangePct,
        },
      },
      'categoryDeltas': categoryDeltas,
      'dailyExpenseSeries30d': [
        for (final e in dailyEntries) {'date': e.key, 'amount': _round(e.value)}
      ],
      'expenseByWeekday30d': {
        for (final e in byWeekday.entries)
          _weekdayName(e.key): _round(e.value),
      },
      'topTransactions30d': top5.toList(),
      'budgets': budgetsJson,
      'goals': goalsJson,
    };

    return '''
USER FINANCIAL CONTEXT (only use these numbers):
${const JsonEncoder.withIndent('  ').convert(payload)}
''';
  }

  static String _weekdayName(int w) => switch (w) {
        DateTime.monday => 'Mon',
        DateTime.tuesday => 'Tue',
        DateTime.wednesday => 'Wed',
        DateTime.thursday => 'Thu',
        DateTime.friday => 'Fri',
        DateTime.saturday => 'Sat',
        _ => 'Sun',
      };

  static double _round(double v) =>
      (v * 100).roundToDouble() / 100;

  static AnalyticsReport _parseReport(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      throw const AiAnalyticsException('Non-JSON response from Gemini.');
    }
    final jsonStr = text.substring(start, end + 1);
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      throw AiAnalyticsException('Invalid JSON from Gemini: $e');
    }

    List<T> parseList<T>(
            String key, T Function(Map<String, dynamic>) ctor) =>
        ((data[key] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => ctor(e.cast<String, dynamic>()))
            .toList();

    final report = AnalyticsReport(
      headline: (data['headline'] as String?)?.trim() ?? '',
      healthGrade: (data['healthGrade'] as String?)?.trim() ?? 'C',
      healthScore: (data['healthScore'] as num?)?.toInt().clamp(0, 100) ?? 50,
      findings: parseList('findings', AnalyticsFinding.fromJson),
      recommendations:
          parseList('recommendations', AnalyticsRecommendation.fromJson),
      categoryInsights:
          parseList('categoryInsights', CategoryInsight.fromJson),
      forecastNarrative:
          (data['forecastNarrative'] as String?)?.trim() ?? '',
      generatedAt: DateTime.now(),
    );

    if (kDebugMode) {
      debugPrint(
          '[AiAnalytics] grade=${report.healthGrade} score=${report.healthScore} findings=${report.findings.length} recs=${report.recommendations.length}');
    }

    return report;
  }
}

class AiAnalyticsException implements Exception {
  final String message;
  const AiAnalyticsException(this.message);
  @override
  String toString() => message;
}
