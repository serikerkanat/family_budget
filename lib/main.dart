// main.dart - Firebase версия
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
import 'widgets/category_selector.dart';
import 'pages/transaction_details_page.dart';
import 'pages/settings_page.dart';
import 'pages/analytics_page.dart';
import 'pages/auth_page.dart';
import 'pages/family_management_page.dart';
import 'pages/notification_settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const BudgetApp());
}

class BudgetApp extends StatelessWidget {
  const BudgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FamilyBank',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Color(0xFF1E3A8A),
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelStyle: const TextStyle(
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          hintStyle: const TextStyle(
            color: Color(0xFF9CA3AF),
            fontSize: 14,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
            backgroundColor: const Color(0xFF1E3A8A),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shadowColor: Colors.black.withOpacity(0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFF374151),
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF6B7280),
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
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late List<TransactionModel> _transactions = [];
  double _totalIncome = 0;
  double _totalExpense = 0;
  late TabController _tabController;
  final List<String> _tabs = ['All', 'Income', 'Expense'];
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    // Start auto transaction service
    AutoTransactionService.start();
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  List<TransactionModel> get _filteredTransactions {
    if (_currentTabIndex == 1) {
      return _transactions.where((t) => t.type == TransactionType.income).toList();
    } else if (_currentTabIndex == 2) {
      return _transactions.where((t) => t.type == TransactionType.expense).toList();
    }
    return _transactions;
  }

  @override
  Widget build(BuildContext context) {
    final balance = _totalIncome - _totalExpense;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FamilyBank'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FamilyManagementPage()),
              );
            },
            tooltip: 'Family',
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationSettingsPage()),
              );
            },
            tooltip: 'Notifications',
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AnalyticsPage()),
              );
            },
            tooltip: 'Analytics',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
            tooltip: 'Settings',
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 22),
            onPressed: () async {
              await AuthService.signOut();
            },
            tooltip: 'Sign Out',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            color: const Color(0xFF1E3A8A),
            child: TabBar(
              controller: _tabController,
              tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
              onTap: (index) {
                setState(() {
                  _currentTabIndex = index;
                });
              },
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicator: UnderlineTabIndicator(
                borderSide: const BorderSide(
                  color: Colors.white,
                  width: 3,
                ),
                insets: const EdgeInsets.symmetric(horizontal: 24),
              ),
              dividerColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
              overlayColor: MaterialStateProperty.all(Colors.transparent),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<TransactionModel>(
            context,
            MaterialPageRoute(builder: (_) => const AddTransactionPage()),
          );
          if (result != null) {
            await _addTransaction(result);
          }
        },
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('New Transaction'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      body: StreamBuilder<List<TransactionModel>>(
        stream: FirestoreService.getTransactions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading transactions',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }
          
          _transactions = snapshot.data ?? [];
          _calculateTotals();
          final balance = _totalIncome - _totalExpense;
          
          return Column(
            children: [
              _buildSummary(balance),
              const SizedBox(height: 8),
              Expanded(
                child: _transactions.isEmpty
                    ? _buildEmptyState()
                    : _buildTransactionList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummary(double balance) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E3A8A),
            const Color(0xFF1E40AF),
            const Color(0xFF2563EB),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Balance',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'FamilyBank',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '\$${balance.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem('Income', _totalIncome, true),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryItem('Expense', _totalExpense, false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, bool isIncome) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${isIncome ? '+' : '-'}\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: isIncome ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No transactions yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first transaction',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    return FutureBuilder<bool>(
      future: PermissionService.canDeleteTransactions(),
      builder: (context, snapshot) {
        final canDelete = snapshot.data ?? false;
        
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 100),
          itemCount: _filteredTransactions.length,
          itemBuilder: (context, index) {
            final tx = _filteredTransactions[index];
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

            if (!canDelete) {
              return card;
            }

            return Dismissible(
              key: Key(tx.id),
              direction: DismissDirection.endToStart,
              background: Container(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.centerRight,
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (direction) async {
                return await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Transaction'),
                    content: const Text('Are you sure you want to delete this transaction?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
              onDismissed: (direction) => _deleteTransaction(tx.id),
              child: card,
            );
          },
        );
      },
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
    final date = DateFormat('MMM dd, yyyy').format(transaction.date);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isIncome 
                      ? const Color(0xFF1E3A8A).withOpacity(0.1)
                      : const Color(0xFFDC2626).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  category.icon,
                  color: isIncome ? const Color(0xFF1E3A8A) : const Color(0xFFDC2626),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Color(0xFF111827),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          category.name,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: Color(0xFF9CA3AF),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          date,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (transaction.notes?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 6),
                      Text(
                        transaction.notes!,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isIncome ? '+' : '-'}\$${transaction.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: isIncome ? const Color(0xFF1E3A8A) : const Color(0xFFDC2626),
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  if (transaction.receiptImagePath != null) ...[
                    const SizedBox(height: 4),
                    const Icon(
                      Icons.receipt_long,
                      size: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                  ],
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
        const SnackBar(
          content: Text('Failed to pick image. Please try again.'),
          backgroundColor: Colors.red,
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
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('New Transaction'),
        backgroundColor: const Color(0xFF1E3A8A),
        actions: [
          TextButton(
            onPressed: _submitForm,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            child: const Text('Save'),
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
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '\$ ',
                    hintText: '0.00',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                  textAlign: TextAlign.center,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an amount';
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return 'Please enter a valid amount';
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
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _type == TransactionType.expense
                              ? const Color(0xFFDC2626)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _type = TransactionType.expense;
                              _updateSelectedCategory();
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Text(
                            'Expense',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _type == TransactionType.expense
                                  ? Colors.white
                                  : const Color(0xFF6B7280),
                              fontWeight: _type == TransactionType.expense
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              fontSize: 15,
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
                          color: _type == TransactionType.income
                              ? const Color(0xFF1E3A8A)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _type = TransactionType.income;
                              _updateSelectedCategory();
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Text(
                            'Income',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _type == TransactionType.income
                                  ? Colors.white
                                  : const Color(0xFF6B7280),
                              fontWeight: _type == TransactionType.income
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              fontSize: 15,
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
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Groceries, Salary, etc.',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
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
                  const Text(
                    'Receipt (Optional)',
                    style: TextStyle(
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
                            'Tap to add receipt',
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
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  hintText: 'Add any additional notes...',
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}