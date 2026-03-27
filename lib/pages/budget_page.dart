import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../models/budget_model.dart';
import '../services/local_storage_service.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  final LocalStorageService _storage = LocalStorageService();
  List<BudgetModel> _budgets = [];
  List<TransactionModel> _transactions = [];
  List<BudgetStatus> _budgetStatuses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    _budgets = _storage.getBudgets();
    _transactions = _storage.getTransactions();
    _budgetStatuses = _calculateBudgetStatuses();
    
    setState(() => _isLoading = false);
  }

  List<BudgetStatus> _calculateBudgetStatuses() {
    final List<BudgetStatus> statuses = [];
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final currentMonthEnd = DateTime(now.year, now.month + 1, 0);

    for (final budget in _budgets) {
      // Filter transactions for the current month and category
      final categoryTransactions = _transactions.where((transaction) {
        if (transaction.categoryId != budget.categoryId) return false;
        if (transaction.type != TransactionType.expense) return false;
        
        // Check if transaction is within the budget period
        final transactionDate = transaction.date;
        if (budget.period == 'monthly') {
          return transactionDate.isAfter(currentMonthStart.subtract(const Duration(days: 1))) &&
                 transactionDate.isBefore(currentMonthEnd.add(const Duration(days: 1)));
        } else if (budget.period == 'weekly') {
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          final weekEnd = weekStart.add(const Duration(days: 6));
          return transactionDate.isAfter(weekStart.subtract(const Duration(days: 1))) &&
                 transactionDate.isAfter(weekEnd.add(const Duration(days: 1)));
        }
        return true; // yearly or custom period
      }).toList();

      final spentAmount = categoryTransactions.fold<double>(
        0.0, (sum, transaction) => sum + transaction.amount,
      );

      final remainingAmount = budget.amount - spentAmount;
      final percentageUsed = budget.amount > 0 ? (spentAmount / budget.amount) * 100.0 : 0.0;
      final isOverBudget = spentAmount > budget.amount;

      final category = defaultCategories.firstWhere(
        (cat) => cat.id == budget.categoryId,
        orElse: () => defaultCategories.last,
      );

      statuses.add(BudgetStatus(
        categoryId: budget.categoryId,
        budgetAmount: budget.amount,
        spentAmount: spentAmount,
        remainingAmount: remainingAmount,
        percentageUsed: percentageUsed,
        isOverBudget: isOverBudget,
        category: category,
      ));
    }

    // Sort by percentage used (highest first) to show overspent categories at top
    statuses.sort((a, b) => b.percentageUsed.compareTo(a.percentageUsed));
    
    return statuses;
  }

  double _getTotalBudget() {
    return _budgetStatuses.fold<double>(0.0, (sum, status) => sum + status.budgetAmount);
  }

  double _getTotalSpent() {
    return _budgetStatuses.fold<double>(0.0, (sum, status) => sum + status.spentAmount);
  }

  double _getTotalRemaining() {
    return _budgetStatuses.fold<double>(0.0, (sum, status) => sum + status.remainingAmount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(
              Icons.add,
              color: Colors.grey[700],
            ),
            onPressed: _showAddBudgetDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _budgetStatuses.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildSummaryCard(),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount: _budgetStatuses.length,
                        itemBuilder: (context, index) {
                          final status = _budgetStatuses[index];
                          return _BudgetCard(
                            status: status,
                            onEdit: () => _showEditBudgetDialog(status),
                            onDelete: () => _showDeleteBudgetDialog(status),
                          );
                        },
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
            Icons.account_balance_wallet_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No budgets set yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to create your first budget',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddBudgetDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create Budget'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final totalBudget = _getTotalBudget();
    final totalSpent = _getTotalSpent();
    final totalRemaining = totalBudget - totalSpent;
    final percentageUsed = totalBudget > 0 ? (totalSpent / totalBudget) * 100 : 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6366F1),
            const Color(0xFF8B5CF6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
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
                'Total Budget',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${percentageUsed.toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '\$${totalBudget.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem('Spent', totalSpent, false),
              _buildSummaryItem('Remaining', totalRemaining, true),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentageUsed / 100,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(
                percentageUsed >= 100 ? Colors.red : Colors.white,
              ),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, bool isPositive) {
    return Column(
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
          '\$${amount.abs().toStringAsFixed(2)}',
          style: TextStyle(
            color: isPositive ? const Color(0xFF86EFAC) : Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  void _showAddBudgetDialog() {
    showDialog(
      context: context,
      builder: (context) => AddBudgetDialog(
        onSave: (budget) async {
          await _storage.saveBudget(budget);
          await _loadData();
        },
      ),
    );
  }

  void _showEditBudgetDialog(BudgetStatus status) {
    showDialog(
      context: context,
      builder: (context) => AddBudgetDialog(
        budgetStatus: status,
        onSave: (budget) async {
          await _storage.updateBudget(budget);
          await _loadData();
        },
      ),
    );
  }

  void _showDeleteBudgetDialog(BudgetStatus status) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Budget'),
        content: Text('Are you sure you want to delete the budget for ${status.category.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _storage.deleteBudget(status.categoryId);
              Navigator.of(context).pop();
              await _loadData();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final BudgetStatus status;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BudgetCard({
    required this.status,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isOverBudget = status.isOverBudget;
    final progressColor = isOverBudget 
        ? Colors.red 
        : status.percentageUsed >= 80 
            ? Colors.orange 
            : const Color(0xFF10B981);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        border: isOverBudget 
            ? Border.all(color: Colors.red.withOpacity(0.3), width: 2)
            : null,
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        progressColor.withOpacity(0.2),
                        progressColor.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    status.category.icon,
                    color: progressColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.category.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${status.spentAmount.toStringAsFixed(2)} of \$${status.budgetAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  child: Icon(
                    Icons.more_vert,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Progress Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${status.percentageUsed.toStringAsFixed(1)}% used',
                      style: TextStyle(
                        color: isOverBudget ? Colors.red : progressColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      isOverBudget 
                          ? 'Over by \$${status.remainingAmount.abs().toStringAsFixed(2)}'
                          : '\$${status.remainingAmount.toStringAsFixed(2)} remaining',
                      style: TextStyle(
                        color: isOverBudget ? Colors.red : Colors.grey[600],
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (status.percentageUsed / 100).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),

          // Overspend Warning
          if (isOverBudget)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Budget exceeded! You\'ve overspent by \$${status.remainingAmount.abs().toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class AddBudgetDialog extends StatefulWidget {
  final BudgetStatus? budgetStatus;
  final Function(BudgetModel) onSave;

  const AddBudgetDialog({
    super.key,
    this.budgetStatus,
    required this.onSave,
  });

  @override
  State<AddBudgetDialog> createState() => _AddBudgetDialogState();
}

class _AddBudgetDialogState extends State<AddBudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String _selectedCategoryId = 'food';
  String _selectedPeriod = 'monthly';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.budgetStatus != null) {
      _selectedCategoryId = widget.budgetStatus!.categoryId;
      _amountController.text = widget.budgetStatus!.budgetAmount.toString();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expenseCategories = defaultCategories
        .where((cat) => cat.type == TransactionType.expense)
        .toList();

    return AlertDialog(
      title: Text(widget.budgetStatus == null ? 'Create Budget' : 'Edit Budget'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedCategoryId,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category),
              ),
              items: expenseCategories.map((category) {
                return DropdownMenuItem(
                  value: category.id,
                  child: Row(
                    children: [
                      Icon(category.icon, size: 20),
                      const SizedBox(width: 8),
                      Text(category.name),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategoryId = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Budget Amount',
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                if (double.tryParse(value) == null || double.parse(value) <= 0) {
                  return 'Please enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedPeriod,
              decoration: const InputDecoration(
                labelText: 'Period',
                prefixIcon: Icon(Icons.date_range),
              ),
              items: const [
                DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedPeriod = value!;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveBudget,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final budget = BudgetModel(
        id: widget.budgetStatus?.categoryId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        categoryId: _selectedCategoryId,
        amount: double.parse(_amountController.text).toDouble(),
        period: _selectedPeriod,
        createdAt: DateTime.now(),
      );

      await widget.onSave(budget);
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
