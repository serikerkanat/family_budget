import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/category_model.dart';
import '../services/firestore_service.dart';
import '../services/prediction_service.dart';
import '../l10n/app_localizations.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;
  ForecastResult? _forecast;
  DateTime? _nextPayday;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final transactionsStream = FirestoreService.getTransactions();
    transactionsStream.listen((transactions) {
      if (mounted) {
        setState(() {
          _transactions = transactions;
          _isLoading = false;
        });
        _generateForecast();
      }
    });
  }

  Future<void> _generateForecast() async {
    final totalIncome = _transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);

    final totalExpense = _transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);

    final balance = totalIncome - totalExpense;

    // Set next payday to 30 days from now (this could be user-configurable)
    _nextPayday = DateTime.now().add(const Duration(days: 30));

    final forecast = await PredictionService.generateForecast(
      transactions: _transactions,
      currentBalance: balance,
      nextPayday: _nextPayday!,
      analysisMonths: 6,
    );

    if (mounted) {
      setState(() {
        _forecast = forecast;
      });
    }
  }

  Map<String, double> _getCategoryData(TransactionType type) {
    final categoryTotals = <String, double>{};

    for (final transaction in _transactions) {
      if (transaction.type == type) {
        final category = defaultCategories.firstWhere(
          (cat) => cat.id == transaction.categoryId,
          orElse: () => defaultCategories.last,
        );
        final categoryName = context.categoryName(category.id);
        categoryTotals[categoryName] = (categoryTotals[categoryName] ?? 0) + transaction.amount;
      }
    }

    return categoryTotals;
  }

  List<Map<String, dynamic>> _getMonthlyData() {
    final monthlyData = <String, Map<String, double>>{};

    for (final transaction in _transactions) {
      final monthKey = DateFormat('MMM yyyy').format(transaction.date);
      if (!monthlyData.containsKey(monthKey)) {
        monthlyData[monthKey] = {'income': 0.0, 'expense': 0.0};
      }

      if (transaction.type == TransactionType.income) {
        monthlyData[monthKey]!['income'] =
            (monthlyData[monthKey]!['income'] ?? 0) + transaction.amount;
      } else {
        monthlyData[monthKey]!['expense'] =
            (monthlyData[monthKey]!['expense'] ?? 0) + transaction.amount;
      }
    }

    return monthlyData.entries
        .map((entry) => {
              'month': entry.key,
              'income': entry.value['income']!,
              'expense': entry.value['expense']!,
              'balance': entry.value['income']! - entry.value['expense']!,
            })
        .toList()
      ..sort((a, b) => (a['month'] as String).compareTo(b['month'] as String));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final totalIncome = _transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);

    final totalExpense = _transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);

    final balance = totalIncome - totalExpense;
    final expenseCategories = _getCategoryData(TransactionType.expense);
    final incomeCategories = _getCategoryData(TransactionType.income);
    final monthlyData = _getMonthlyData();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(context.t('analytics')),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    context.t('totalIncome'),
                    '+\$${totalIncome.toStringAsFixed(2)}',
                    const Color(0xFF10B981),
                    Icons.trending_up,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    context.t('totalExpense'),
                    '-\$${totalExpense.toStringAsFixed(2)}',
                    const Color(0xFFEF4444),
                    Icons.trending_down,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSummaryCard(
              context.t('netBalance'),
              '\$${balance.toStringAsFixed(2)}',
              balance >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              Icons.account_balance_wallet,
              isBalance: true,
            ),
            const SizedBox(height: 24),

            // AI Forecast
            if (_forecast != null) ...[
              _buildForecastCard(),
              const SizedBox(height: 24),
            ],

            // Category Breakdown
            if (expenseCategories.isNotEmpty) ...[
              _buildSectionTitle(context.t('expenseCategories')),
              const SizedBox(height: 12),
              _buildCategoryChart(expenseCategories, TransactionType.expense),
              const SizedBox(height: 24),
            ],

            if (incomeCategories.isNotEmpty) ...[
              _buildSectionTitle(context.t('incomeSources')),
              const SizedBox(height: 12),
              _buildCategoryChart(incomeCategories, TransactionType.income),
              const SizedBox(height: 24),
            ],

            // Monthly Trends
            if (monthlyData.isNotEmpty) ...[
              _buildSectionTitle(context.t('monthlyTrends')),
              const SizedBox(height: 12),
              _buildMonthlyChart(monthlyData),
              const SizedBox(height: 24),
            ],

            // Recent Transactions
            _buildSectionTitle(context.t('recentTransactions')),
            const SizedBox(height: 12),
            _buildRecentTransactions(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String amount, Color color, IconData icon, {bool isBalance = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const Spacer(),
              if (isBalance && amount.startsWith('-'))
                Icon(
                  Icons.arrow_downward,
                  color: const Color(0xFFEF4444),
                  size: 16,
                )
              else if (isBalance)
                Icon(
                  Icons.arrow_upward,
                  color: const Color(0xFF10B981),
                  size: 16,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isBalance ? color : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastCard() {
    if (_forecast == null) return const SizedBox.shrink();

    final isWarning = _forecast!.daysUntilBudgetDepleted >= 0 &&
                      _forecast!.daysUntilBudgetDepleted < 7;
    final isGood = _forecast!.daysUntilBudgetDepleted >
                   (_nextPayday?.difference(DateTime.now()).inDays ?? 30);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isWarning
              ? [const Color(0xFFFEE2E2), const Color(0xFFFECACA)]
              : isGood
                  ? [const Color(0xFFD1FAE5), const Color(0xFFA7F3D0)]
                  : [const Color(0xFFDBEAFE), const Color(0xFFBFDBFE)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isWarning ? const Color(0xFFEF4444) :
                   isGood ? const Color(0xFF10B981) :
                   const Color(0xFF3B82F6)).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  isWarning ? Icons.warning_amber_rounded :
                  isGood ? Icons.check_circle_rounded :
                  Icons.info_rounded,
                  color: isWarning ? const Color(0xFFEF4444) :
                         isGood ? const Color(0xFF10B981) :
                         const Color(0xFF3B82F6),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('aiForecast'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isWarning ? context.t('budgetAlert') :
                      isGood ? context.t('lookingGood') :
                      context.t('onTrack'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isWarning ? const Color(0xFFDC2626) :
                               isGood ? const Color(0xFF059669) :
                               const Color(0xFF1D4ED8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_forecast!.probability.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isWarning ? const Color(0xFFDC2626) :
                           isGood ? const Color(0xFF059669) :
                           const Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _forecast!.recommendation,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildForecastStat(
                      context.t('dailySpend'),
                      '\$${_forecast!.predictedDailySpend.toStringAsFixed(2)}',
                      Icons.attach_money,
                    ),
                    const SizedBox(width: 16),
                    _buildForecastStat(
                      context.t('daysLeft'),
                      _forecast!.daysUntilBudgetDepleted >= 0
                          ? '${_forecast!.daysUntilBudgetDepleted}'
                          : 'в€ћ',
                      Icons.calendar_today,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastStat(String label, String value, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A1A),
      ),
    );
  }

  Widget _buildCategoryChart(Map<String, double> categories, TransactionType type) {
    final total = categories.values.fold(0.0, (sum, amount) => sum + amount);
    final sortedCategories = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ...sortedCategories.take(5).map((entry) {
            final percentage = total > 0 ? (entry.value / total * 100) : 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '\$${entry.value.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: percentage / 100,
                      child: Container(
                        decoration: BoxDecoration(
                          color: type == TransactionType.income
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMonthlyChart(List<Map<String, dynamic>> monthlyData) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ...monthlyData.take(6).map((data) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['month'],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMonthlyBar(
                          context.t('income'),
                          data['income'],
                          const Color(0xFF10B981),
                          monthlyData,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMonthlyBar(
                          context.t('expense'),
                          data['expense'],
                          const Color(0xFFEF4444),
                          monthlyData,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tx('balanceLabel', {
                          'amount': "\$${data['balance'].toStringAsFixed(2)}",
                        }),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: data['balance'] >= 0
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMonthlyBar(String label, double amount, Color color, List<Map<String, dynamic>> monthlyData) {
    final maxValue = monthlyData.isNotEmpty
        ? monthlyData.map((d) => d[label.toLowerCase()]).reduce((a, b) => (a as double) > (b as double) ? a : b)
        : amount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '\$${amount.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 20,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: maxValue > 0 ? amount / maxValue : 0,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTransactions() {
    final recentTransactions = _transactions
      ..sort((a, b) => b.date.compareTo(a.date));

    final recent = recentTransactions.take(5).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: recent.map((transaction) {
          final category = defaultCategories.firstWhere(
            (cat) => cat.id == transaction.categoryId,
            orElse: () => defaultCategories.last,
          );
          final isIncome = transaction.type == TransactionType.income;

          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isIncome
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                category.icon,
                color: isIncome ? Colors.green : Colors.red,
                size: 20,
              ),
            ),
            title: Text(
              transaction.title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              '${context.categoryName(category.id)} • ${DateFormat('MMM dd').format(transaction.date)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            trailing: Text(
              '${isIncome ? '+' : '-'}\$${transaction.amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: isIncome ? Colors.green : Colors.red,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
