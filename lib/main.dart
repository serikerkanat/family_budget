// main.dart - Firebase РІРµСЂСЃРёСЏ
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'models/transaction_model.dart';
import 'models/category_model.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/permission_service.dart';
import 'services/auto_transaction_service.dart';
import 'services/recurring_payment_service.dart';
import 'widgets/category_selector.dart';
import 'pages/transaction_details_page.dart';
import 'pages/settings_page.dart';
import 'pages/analytics_page.dart';
import 'pages/auth_page.dart';
import 'pages/family_management_page.dart';
import 'pages/budget_management_page.dart';
import 'pages/notification_settings_page.dart';
import 'pages/recurring_payments_page.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const BudgetApp());
}

class BudgetApp extends StatefulWidget {
  const BudgetApp({super.key});

  @override
  State<BudgetApp> createState() => _BudgetAppState();
}

class _BudgetAppState extends State<BudgetApp> {
  final AppLanguageController _languageController = AppLanguageController();

  @override
  void initState() {
    super.initState();
    _languageController.load();
    // Process due payments on app start
    _processDuePayments();
  }

  Future<void> _processDuePayments() async {
    try {
      await RecurringPaymentService.triggerPaymentProcessing();
    } catch (e) {
      print('Error processing due payments on app start: $e');
    }
  }

  @override
  void dispose() {
    _languageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppLanguageScope(
      controller: _languageController,
      child: AnimatedBuilder(
        animation: _languageController,
        builder: (context, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: context.t('appName'),
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0F766E),
                brightness: Brightness.light,
              ),
              scaffoldBackgroundColor: const Color(0xFFF4F7F6),
              appBarTheme: const AppBarTheme(
                elevation: 0,
                centerTitle: false,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                titleTextStyle: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0B1F1D),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFD7E2DF)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFD7E2DF)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF0F766E), width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                labelStyle: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              cardTheme: CardThemeData(
                elevation: 0,
                color: Colors.white,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: Color(0xFFE4ECE9)),
                ),
              ),
            ),
            home: StreamBuilder<User?>(
              stream: AuthService.authStateChanges,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasData) {
                  return const HomePage();
                } else {
                  return const AuthPage();
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<TransactionModel> _transactions = [];
  double _totalIncome = 0;
  double _totalExpense = 0;
  int _currentTabIndex = 0;

  static const _ink = Color(0xFF0B1F1D);
  static const _muted = Color(0xFF667875);
  static const _teal = Color(0xFF0F766E);
  static const _mint = Color(0xFFE4F5EF);
  static const _amber = Color(0xFFF59E0B);
  static const _rose = Color(0xFFDC2626);

  @override
  void initState() {
    super.initState();
    AutoTransactionService.start();
  }

  @override
  void dispose() {
    AutoTransactionService.stop();
    super.dispose();
  }

  void _calculateTotals() {
    _totalIncome = _transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0, (sum, t) => sum + t.amount);

    _totalExpense = _transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0, (sum, t) => sum + t.amount);
  }

  Future<void> _addTransaction(TransactionModel transaction) async {
    await FirestoreService.addTransaction(transaction);
  }

  Future<void> _deleteTransaction(String id) async {
    await FirestoreService.deleteTransaction(id);
  }

  Future<void> _openAddTransaction() async {
    final result = await Navigator.push<TransactionModel>(
      context,
      MaterialPageRoute(builder: (_) => const AddTransactionPage()),
    );
    if (result != null) {
      await _addTransaction(result);
    }
  }

  List<TransactionModel> get _filteredTransactions {
    final transactions = List<TransactionModel>.from(_transactions)
      ..sort((a, b) => b.date.compareTo(a.date));

    if (_currentTabIndex == 1) {
      return transactions.where((t) => t.type == TransactionType.income).toList();
    }
    if (_currentTabIndex == 2) {
      return transactions.where((t) => t.type == TransactionType.expense).toList();
    }
    return transactions;
  }

  double get _balance => _totalIncome - _totalExpense;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddTransaction,
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBankNavigation(),
      body: StreamBuilder<List<TransactionModel>>(
        stream: FirestoreService.getTransactions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildErrorState();
          }

          _transactions = snapshot.data ?? [];
          _calculateTotals();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildAccountCard()),
              SliverToBoxAdapter(child: _buildQuickActions()),
              SliverToBoxAdapter(child: _buildInsights()),
              SliverToBoxAdapter(child: _buildTransactionHeader()),
              if (_transactions.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(),
                )
              else
                _buildTransactionSliver(),
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.email?.split('@').first ?? 'family';

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _ink,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.account_balance, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Good day',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    name,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            _HeaderButton(
              icon: Icons.notifications_active_outlined,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationSettingsPage()),
              ),
              tooltip: context.t('notifications'),
            ),
            const SizedBox(width: 8),
            _HeaderButton(
              icon: Icons.logout,
              onTap: () async => AuthService.signOut(),
              tooltip: 'Sign out',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard() {
    final availableRatio = _totalIncome <= 0
        ? 0.0
        : (_balance / _totalIncome).clamp(0.0, 1.0).toDouble();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _ink.withOpacity(0.18),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.16)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user_outlined, color: Color(0xFF9DE7D1), size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Protected account',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Icon(Icons.contactless_outlined, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 26),
          Text(
            context.t('totalBalance'),
            style: const TextStyle(
              color: Color(0xFFB5C8C4),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '\$${_balance.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 44,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: availableRatio,
              backgroundColor: Colors.white.withOpacity(0.12),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF9DE7D1)),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _AccountMetric(
                  label: context.t('income'),
                  value: '+\$${_totalIncome.toStringAsFixed(2)}',
                  icon: Icons.south_west_rounded,
                  color: const Color(0xFF9DE7D1),
                ),
              ),
              Container(width: 1, height: 42, color: Colors.white.withOpacity(0.14)),
              Expanded(
                child: _AccountMetric(
                  label: context.t('expense'),
                  value: '-\$${_totalExpense.toStringAsFixed(2)}',
                  icon: Icons.north_east_rounded,
                  color: const Color(0xFFFDBA74),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return SizedBox(
      height: 102,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        children: [
          _QuickAction(
            icon: Icons.add_card,
            label: context.t('add'),
            color: _teal,
            onTap: _openAddTransaction,
          ),
          _QuickAction(
            icon: Icons.pie_chart_outline,
            label: context.t('analytics'),
            color: const Color(0xFF2563EB),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AnalyticsPage()),
            ),
          ),
          _QuickAction(
            icon: Icons.account_balance_wallet_outlined,
            label: context.t('budgetManagement'),
            color: _amber,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BudgetManagementPage()),
            ),
          ),
          _QuickAction(
            icon: Icons.repeat,
            label: context.t('recurringPayments'),
            color: const Color(0xFF7C3AED),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecurringPaymentsPage()),
            ),
          ),
          _QuickAction(
            icon: Icons.family_restroom,
            label: context.t('familyManagement'),
            color: const Color(0xFF0891B2),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FamilyManagementPage()),
            ),
          ),
          _QuickAction(
            icon: Icons.settings_outlined,
            label: context.t('settings'),
            color: const Color(0xFF475569),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsights() {
    final spendRatio = _totalIncome <= 0
        ? 0.0
        : (_totalExpense / _totalIncome).clamp(0.0, 1.0).toDouble();
    final categories = <String, double>{};
    for (final tx in _transactions.where((t) => t.type == TransactionType.expense)) {
      categories[tx.categoryId] = (categories[tx.categoryId] ?? 0) + tx.amount;
    }
    final topCategory = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCategoryName = topCategory.isEmpty
        ? context.t('expenseCategories')
        : context.categoryName(topCategory.first.key);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
      child: Row(
        children: [
          Expanded(
            child: _InsightCard(
              title: 'Spending pulse',
              value: '${(spendRatio * 100).toStringAsFixed(0)}%',
              caption: 'of income used',
              icon: Icons.speed_outlined,
              color: _rose,
              progress: spendRatio,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _InsightCard(
              title: 'Top category',
              value: topCategoryName,
              caption: topCategory.isEmpty
                  ? 'No spend yet'
                  : '\$${topCategory.first.value.toStringAsFixed(0)} this period',
              icon: Icons.category_outlined,
              color: _teal,
              progress: topCategory.isEmpty ? 0 : 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionHeader() {
    final labels = [context.t('all'), context.t('income'), context.t('expense')];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.t('recentTransactions'),
                style: const TextStyle(
                  color: _ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${_filteredTransactions.length}',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(labels.length, (index) {
              final selected = _currentTabIndex == index;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index == labels.length - 1 ? 0 : 8),
                  child: ChoiceChip(
                    selected: selected,
                    showCheckmark: false,
                    label: Center(child: Text(labels[index])),
                    selectedColor: _ink,
                    backgroundColor: Colors.white,
                    side: BorderSide(color: selected ? _ink : const Color(0xFFDDE7E4)),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : _muted,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onSelected: (_) => setState(() => _currentTabIndex = index),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionSliver() {
    return FutureBuilder<bool>(
      future: PermissionService.canDeleteTransactions(),
      builder: (context, snapshot) {
        final canDelete = snapshot.data ?? false;
        final transactions = _filteredTransactions;

        if (transactions.isEmpty) {
          return SliverToBoxAdapter(child: _buildEmptyState());
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, rawIndex) {
            if (rawIndex.isOdd) {
              return const SizedBox(height: 10);
            }
            final index = rawIndex ~/ 2;
            final tx = transactions[index];
            final category = defaultCategories.firstWhere(
              (cat) => cat.id == tx.categoryId,
              orElse: () => defaultCategories.last,
            );

            final card = _TransactionCard(
              transaction: tx,
              category: category,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TransactionDetailsPage(
                      transaction: tx,
                      category: category,
                      onDelete: canDelete ? () => _deleteTransaction(tx.id) : () {},
                    ),
                  ),
                );
              },
            );

            if (!canDelete) return card;

            return Dismissible(
              key: Key(tx.id),
              direction: DismissDirection.endToStart,
              background: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: _rose,
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.centerRight,
                child: const Icon(Icons.delete_outline, color: Colors.white),
              ),
              confirmDismiss: (_) async {
                return await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(context.t('deleteTransaction')),
                    content: Text(context.t('deleteTransactionConfirm')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(context.t('cancel')),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(foregroundColor: _rose),
                        child: Text(context.t('delete')),
                      ),
                    ],
                  ),
                );
              },
              onDismissed: (_) => _deleteTransaction(tx.id),
              child: card,
            );
          }, childCount: transactions.length * 2 - 1),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: _mint,
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Icon(Icons.receipt_long_outlined, size: 40, color: _teal),
          ),
          const SizedBox(height: 18),
          Text(
            context.t('noTransactionsYet'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              color: _ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.t('tapToAddFirstTransaction'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            context.t('errorLoadingTransactions'),
            style: const TextStyle(color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _buildBankNavigation() {
    return BottomAppBar(
      height: 78,
      color: Colors.white,
      elevation: 14,
      shadowColor: Colors.black.withOpacity(0.16),
      surfaceTintColor: Colors.white,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Row(
        children: [
          _NavItem(icon: Icons.home_filled, label: 'Home', selected: true, onTap: () {}),
          _NavItem(
            icon: Icons.pie_chart_outline,
            label: context.t('analytics'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AnalyticsPage()),
            ),
          ),
          const SizedBox(width: 64),
          _NavItem(
            icon: Icons.account_balance_wallet_outlined,
            label: context.t('budgetManagement'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BudgetManagementPage()),
            ),
          ),
          _NavItem(
            icon: Icons.settings_outlined,
            label: context.t('settings'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _HeaderButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFFE1EAE7)),
          ),
          child: Icon(icon, color: const Color(0xFF0B1F1D), size: 21),
        ),
      ),
    );
  }
}

class _AccountMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _AccountMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFB5C8C4),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 82,
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.16)),
                ),
                child: Icon(icon, color: color, size: 25),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF344744),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;
  final double progress;

  const _InsightCard({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: 154),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE1EAE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0).toDouble(),
                  strokeWidth: 5,
                  backgroundColor: const Color(0xFFEAF1EF),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF667875),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF0B1F1D),
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF667875),
              fontSize: 12,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF0F766E) : const Color(0xFF7B8D8A);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final TransactionModel transaction;
  final Category category;
  final VoidCallback onTap;

  const _TransactionCard({
    required this.transaction,
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final date = DateFormat('MMM dd').format(transaction.date);
    final color = isIncome ? const Color(0xFF0F766E) : const Color(0xFFDC2626);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE1EAE7)),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: category.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(category.icon, color: category.color, size: 23),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Color(0xFF0B1F1D),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            context.categoryName(category.id),
                            style: const TextStyle(
                              color: Color(0xFF667875),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('-', style: TextStyle(color: Color(0xFF9AACAA))),
                        const SizedBox(width: 6),
                        Text(
                          date,
                          style: const TextStyle(
                            color: Color(0xFF667875),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (transaction.bankName?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 5),
                      Text(
                        transaction.bankName!,
                        style: const TextStyle(
                          color: Color(0xFF0F766E),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isIncome ? '+' : '-'}\$${transaction.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Icon(
                    transaction.receiptImagePath != null
                        ? Icons.receipt_long_outlined
                        : Icons.chevron_right,
                    color: const Color(0xFF9AACAA),
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddTransactionPage extends StatefulWidget {
  const AddTransactionPage({super.key});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  String _selectedCategoryId = 'salary';
  String? _receiptImagePath;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize with income categories first to show all categories
    _updateSelectedCategory();
  }

  void _updateSelectedCategory() {
    final categoriesForType = defaultCategories
        .where((cat) => cat.type == _type)
        .toList();
    if (categoriesForType.isNotEmpty) {
      _selectedCategoryId = categoriesForType.first.id;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 800,
      );

      if (image != null) {
        setState(() {
          _receiptImagePath = image.path;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('pickImageFailed')),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;

    final transaction = TransactionModel(
      id: const Uuid().v4(),
      title: _titleController.text.trim(),
      amount: double.parse(_amountController.text.trim()),
      type: _type,
      date: DateTime.now(),
      categoryId: _selectedCategoryId,
      receiptImagePath: _receiptImagePath,
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    );

    Navigator.pop(context, transaction);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: Text(context.t('addTransaction')),
        backgroundColor: Colors.transparent,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: ElevatedButton(
              onPressed: _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                context.t('save'),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Amount Input
              Container(
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
                child: TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    labelText: context.t('amount'),
                    prefixText: '\$ ',
                    hintText: '0.00',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(20),
                  ),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                  textAlign: TextAlign.center,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.t('enterAmount');
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return context.t('validAmount');
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Type Toggle
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: _type == TransactionType.expense
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [const Color(0xFFF97316), const Color(0xFFDC2626)],
                                )
                              : null,
                          color: _type == TransactionType.expense ? null : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _type = TransactionType.expense;
                              _updateSelectedCategory();
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Text(
                            context.t('expense'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _type == TransactionType.expense
                                  ? Colors.white
                                  : Colors.grey[700],
                              fontWeight: _type == TransactionType.expense
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: _type == TransactionType.income
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [const Color(0xFF14B8A6), const Color(0xFF0F766E)],
                                )
                              : null,
                          color: _type == TransactionType.income ? null : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _type = TransactionType.income;
                              _updateSelectedCategory();
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Text(
                            context.t('income'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _type == TransactionType.income
                                  ? Colors.white
                                  : Colors.grey[700],
                              fontWeight: _type == TransactionType.income
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Title Input
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: context.t('title'),
                  hintText: context.t('titleHint'),
                  prefixIcon: const Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return context.t('enterTitle');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category Selector
              CategorySelector(
                selectedCategoryId: _selectedCategoryId,
                type: _type,
                onCategorySelected: (category) {
                  setState(() {
                    _selectedCategoryId = category.id;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Receipt Image
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('receiptOptional'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _receiptImagePath == null
                          ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt,
                            size: 40,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.t('tapToAddReceipt'),
                            style: TextStyle(
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      )
                          : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_receiptImagePath!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: context.t('notesOptional'),
                  hintText: context.t('notesHint'),
                  prefixIcon: const Icon(Icons.notes),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Save Button
              ElevatedButton(
                onPressed: _submitForm,
                child: Text(context.t('saveTransaction')),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
