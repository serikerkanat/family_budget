import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/budget_model.dart';
import '../models/category_model.dart';
import '../services/budget_service.dart';
import '../services/user_service.dart';

class BudgetManagementPage extends StatefulWidget {
  const BudgetManagementPage({super.key});

  @override
  State<BudgetManagementPage> createState() => _BudgetManagementPageState();
}

class _BudgetManagementPageState extends State<BudgetManagementPage> {
  bool _isLoading = false;
  List<BudgetModel> _budgets = [];
  final Map<String, TextEditingController> _limitControllers = {};

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    for (final category in defaultCategories) {
      _limitControllers[category.id] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in _limitControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Color _getProgressColor(String colorString) {
    switch (colorString) {
      case 'red':
        return Colors.red;
      case 'orange':
        return Colors.orange;
      case 'yellow':
        return Colors.amber;
      case 'green':
      default:
        return Colors.green;
    }
  }

  Future<void> _setBudget(String categoryId, String categoryName, double limit) async {
    setState(() => _isLoading = true);
    
    try {
      final familyId = await UserService.getUserFamilyId();
      if (familyId == null) throw Exception('User not in family');

      final budget = BudgetModel(
        id: '${familyId}_$categoryId',
        categoryId: categoryId,
        categoryName: categoryName,
        monthlyLimit: limit,
        currentSpent: 0.0,
        currency: 'USD',
        createdAt: DateTime.now(),
        createdBy: UserService.currentUserId ?? '',
        familyId: familyId,
      );

      await BudgetService.setBudget(budget);
      _showSuccessSnackBar('Budget set successfully for $categoryName');
    } catch (e) {
      _showErrorSnackBar('Error setting budget: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteBudget(String budgetId, String categoryName) async {
    final confirmed = await _showConfirmDialog(
      'Delete Budget',
      'Are you sure you want to delete the budget for $categoryName?',
    );
    
    if (!confirmed) return;

    setState(() => _isLoading = true);
    
    try {
      await BudgetService.deleteBudget(budgetId);
      _showSuccessSnackBar('Budget deleted successfully');
    } catch (e) {
      _showErrorSnackBar('Error deleting budget: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Management'),
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder<List<BudgetModel>>(
        stream: BudgetService.getBudgets(),
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
                    'Error loading budgets',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }
          
          _budgets = snapshot.data ?? [];
          
          return Column(
            children: [
              // Summary Card
              Container(
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
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: Colors.white, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Monthly Budgets',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${_budgets.length} Active',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Budgets List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: defaultCategories.length,
                  itemBuilder: (context, index) {
                    final category = defaultCategories[index];
                    final existingBudget = _budgets.firstWhere(
                      (b) => b.categoryId == category.id,
                      orElse: () => BudgetModel(
                        id: '',
                        categoryId: category.id,
                        categoryName: category.name,
                        monthlyLimit: 0,
                        currentSpent: 0,
                        currency: 'USD',
                        createdAt: DateTime.now(),
                        createdBy: '',
                        familyId: '',
                      ),
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Category Header
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: category.color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    category.icon,
                                    color: category.color,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    category.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (existingBudget.monthlyLimit > 0)
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteBudget(
                                      existingBudget.id,
                                      existingBudget.categoryName,
                                    ),
                                  ),
                              ],
                            ),
                            
                            if (existingBudget.monthlyLimit > 0) ...[
                              const SizedBox(height: 16),
                              
                              // Progress Bar
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '\$${existingBudget.currentSpent.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: _getProgressColor(existingBudget.progressColor),
                                        ),
                                      ),
                                      Text(
                                        'of \$${existingBudget.monthlyLimit.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: existingBudget.percentageUsed / 100,
                                    backgroundColor: Colors.grey[300],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _getProgressColor(existingBudget.progressColor),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${existingBudget.percentageUsed.toStringAsFixed(1)}% used',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: _getProgressColor(existingBudget.progressColor),
                                        ),
                                      ),
                                      Text(
                                        '\$${existingBudget.remaining.toStringAsFixed(2)} remaining',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: existingBudget.isExceeded 
                                              ? Colors.red 
                                              : Colors.green[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ] else ...[
                              const SizedBox(height: 16),
                              // Set Budget Input
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _limitControllers[category.id],
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'Monthly Limit (\$)',
                                        prefixIcon: const Icon(Icons.attach_money),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[50],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton(
                                    onPressed: _isLoading ? null : () {
                                      final limit = double.tryParse(
                                        _limitControllers[category.id]!.text
                                      );
                                      if (limit != null && limit! > 0) {
                                        _setBudget(
                                          category.id,
                                          category.name,
                                          limit!,
                                        );
                                        _limitControllers[category.id]!.clear();
                                      }
                                    },
                                    child: _isLoading
                                        ? const CircularProgressIndicator(color: Colors.white)
                                        : const Text('Set'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
