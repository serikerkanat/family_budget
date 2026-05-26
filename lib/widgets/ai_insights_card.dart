import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/budget_model.dart';
import '../models/category_model.dart';
import '../models/savings_goal_model.dart';
import '../models/transaction_model.dart';
import '../services/ai_analytics_service.dart';
import '../services/budget_service.dart';
import '../services/savings_goal_service.dart';

/// A self-contained card that streams budgets+goals, lets the user tap
/// "Generate AI insights" to call Gemini, and displays a rich structured
/// analytics report.
class AiInsightsCard extends StatefulWidget {
  final List<TransactionModel> transactions;
  const AiInsightsCard({super.key, required this.transactions});

  @override
  State<AiInsightsCard> createState() => _AiInsightsCardState();
}

class _AiInsightsCardState extends State<AiInsightsCard> {
  AnalyticsReport? _report;
  bool _loading = false;
  String? _error;

  List<BudgetModel> _budgets = const [];
  List<SavingsGoalModel> _goals = const [];

  @override
  void initState() {
    super.initState();
    BudgetService.getBudgets().listen((b) {
      if (mounted) setState(() => _budgets = b);
    });
    SavingsGoalService.getSavingsGoals().listen((g) {
      if (mounted) setState(() => _goals = g);
    });
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // Capture context-dependent values up front.
    final familyCurrency = context.appCurrency.code;
    final language = context.appLanguage.code;
    final missingMsg = context.t('aiKeyMissing');

    try {
      final available = await AiAnalyticsService.isAvailable();
      if (!mounted) return;
      if (!available) {
        setState(() {
          _loading = false;
          _error = missingMsg;
        });
        return;
      }

      final report = await AiAnalyticsService.generateReport(
        transactions: widget.transactions,
        budgets: _budgets,
        goals: _goals,
        familyCurrency: familyCurrency,
        language: language,
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });
    } on AiAnalyticsException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          if (_loading)
            const _SkeletonBody()
          else if (_error != null)
            _buildError()
          else if (_report == null)
            _buildEmpty()
          else
            _buildReport(_report!),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.auto_awesome,
              color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t('aiDeepInsights'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF312E81),
                ),
              ),
              if (_report != null)
                Text(
                  context.tx('generatedAt', {
                    'time':
                        DateFormat.yMMMd().add_jm().format(_report!.generatedAt)
                  }),
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF4F46E5)),
                ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(_report == null ? Icons.bolt : Icons.refresh,
              color: const Color(0xFF4F46E5)),
          tooltip: context.t('regenerate'),
          onPressed: _loading ? null : _generate,
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.t('aiInsightsExplainer'),
          style: const TextStyle(color: Color(0xFF4338CA), height: 1.4),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _generate,
          icon: const Icon(Icons.auto_awesome),
          label: Text(context.t('generateInsights')),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFB91C1C)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_error!,
                style: const TextStyle(color: Color(0xFFB91C1C))),
          ),
          TextButton(
            onPressed: _generate,
            child: Text(context.t('retry')),
          ),
        ],
      ),
    );
  }

  Widget _buildReport(AnalyticsReport r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScoreRow(grade: r.healthGrade, score: r.healthScore),
        const SizedBox(height: 12),
        _Section(
          title: context.t('summary'),
          child: Text(
            r.headline,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
              height: 1.45,
            ),
          ),
        ),
        if (r.findings.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section(
            title: context.t('keyFindings'),
            child: Column(
              children: r.findings.map(_FindingTile.new).toList(),
            ),
          ),
        ],
        if (r.categoryInsights.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section(
            title: context.t('categoryInsights'),
            child: Column(
              children: r.categoryInsights
                  .map((c) => _CategoryInsightTile(insight: c))
                  .toList(),
            ),
          ),
        ],
        if (r.recommendations.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section(
            title: context.t('recommendations'),
            child: Column(
              children:
                  r.recommendations.map(_RecommendationTile.new).toList(),
            ),
          ),
        ],
        if (r.forecastNarrative.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section(
            title: context.t('forecast30d'),
            child: Text(
              r.forecastNarrative,
              style: const TextStyle(
                  color: Color(0xFF1F2937), height: 1.45, fontSize: 13.5),
            ),
          ),
        ],
      ],
    );
  }
}

class _SkeletonBody extends StatelessWidget {
  const _SkeletonBody();

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, [double h = 14]) => Container(
          height: h,
          width: w,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(6),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFF6366F1)),
          ),
          const SizedBox(width: 8),
          Text(
            context.t('analyzingWithGemini'),
            style: const TextStyle(color: Color(0xFF4338CA)),
          ),
        ]),
        const SizedBox(height: 16),
        bar(220, 18),
        bar(double.infinity),
        bar(280),
        const SizedBox(height: 8),
        bar(180, 18),
        bar(double.infinity),
        bar(220),
      ],
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String grade;
  final int score;
  const _ScoreRow({required this.grade, required this.score});

  Color _scoreColor() {
    if (score >= 80) return const Color(0xFF059669);
    if (score >= 60) return const Color(0xFF2563EB);
    if (score >= 40) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    final c = _scoreColor();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: c, width: 2),
            ),
            child: Text(
              grade,
              style: TextStyle(
                color: c,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('financialHealth'),
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$score',
                      style: TextStyle(
                          color: c,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          height: 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4, left: 4),
                      child: Text('/100',
                          style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: score / 100,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: AlwaysStoppedAnimation(c),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF4338CA),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _FindingTile extends StatelessWidget {
  final AnalyticsFinding finding;
  const _FindingTile(this.finding);

  ({Color bg, Color fg, IconData icon}) _toneStyle() {
    switch (finding.tone) {
      case 'positive':
        return (
          bg: const Color(0xFFDCFCE7),
          fg: const Color(0xFF166534),
          icon: Icons.trending_up,
        );
      case 'negative':
      case 'warning':
        return (
          bg: const Color(0xFFFEE2E2),
          fg: const Color(0xFFB91C1C),
          icon: finding.tone == 'warning'
              ? Icons.warning_amber_rounded
              : Icons.trending_down,
        );
      default:
        return (
          bg: const Color(0xFFE0E7FF),
          fg: const Color(0xFF3730A3),
          icon: Icons.info_outline,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _toneStyle();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: s.bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(s.icon, color: s.fg, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    finding.title,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: s.fg,
                        fontSize: 13.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    finding.detail,
                    style: TextStyle(
                        color: s.fg.withValues(alpha: 0.9),
                        fontSize: 12.5,
                        height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  final AnalyticsRecommendation rec;
  const _RecommendationTile(this.rec);

  ({Color bg, Color fg, String label}) _impactStyle() {
    switch (rec.impact) {
      case 'high':
        return (
          bg: const Color(0xFFDC2626),
          fg: Colors.white,
          label: 'HIGH'
        );
      case 'low':
        return (
          bg: const Color(0xFFE5E7EB),
          fg: const Color(0xFF374151),
          label: 'LOW'
        );
      default:
        return (
          bg: const Color(0xFFFBBF24),
          fg: const Color(0xFF78350F),
          label: 'MED'
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _impactStyle();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.check_circle_outline,
                  color: Color(0xFF4338CA), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          rec.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: s.bg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          s.label,
                          style: TextStyle(
                            color: s.fg,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rec.reason,
                    style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 12.5,
                        height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryInsightTile extends StatelessWidget {
  final CategoryInsight insight;
  const _CategoryInsightTile({required this.insight});

  @override
  Widget build(BuildContext context) {
    final cat = defaultCategories.firstWhere(
      (c) => c.id == insight.categoryId,
      orElse: () =>
          defaultCategories.firstWhere((c) => c.id == 'other'),
    );
    final isIncrease = insight.trend.contains('+');
    final isDecrease = insight.trend.contains('-') &&
        !insight.trend.toLowerCase().contains('stable');
    final trendColor = isIncrease
        ? const Color(0xFFB91C1C)
        : isDecrease
            ? const Color(0xFF166534)
            : const Color(0xFF6B7280);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: cat.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(cat.icon, size: 16, color: cat.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      context.categoryName(cat.id),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: trendColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        insight.trend,
                        style: TextStyle(
                            color: trendColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  insight.note,
                  style: const TextStyle(
                      color: Color(0xFF4B5563), fontSize: 12.5, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
