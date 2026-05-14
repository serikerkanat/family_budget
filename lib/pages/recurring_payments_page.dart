import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/recurring_payment_model.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../services/recurring_payment_service.dart';
import '../services/user_service.dart';
import '../l10n/app_localizations.dart';

class RecurringPaymentsPage extends StatefulWidget {
  const RecurringPaymentsPage({super.key});

  @override
  State<RecurringPaymentsPage> createState() => _RecurringPaymentsPageState();
}

class _RecurringPaymentsPageState extends State<RecurringPaymentsPage> {
  bool _isLoading = false;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  RecurringPaymentType _selectedType = RecurringPaymentType.monthly;
  String _selectedCategoryId = 'other';
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  DateTime? _firstPaymentDate;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // Get expense categories only for recurring payments
  List<Category> get _expenseCategories => defaultCategories
      .where((cat) => cat.type == TransactionType.expense)
      .toList();

  Color _getPaymentTypeColor(RecurringPaymentType type) {
    switch (type) {
      case RecurringPaymentType.monthly:
        return Colors.blue;
      case RecurringPaymentType.weekly:
        return Colors.green;
      case RecurringPaymentType.yearly:
        return Colors.purple;
      case RecurringPaymentType.oneTime:
        return Colors.orange;
    }
  }

  String _getPaymentTypeIcon(RecurringPaymentType type) {
    switch (type) {
      case RecurringPaymentType.monthly:
        return 'M';
      case RecurringPaymentType.weekly:
        return 'W';
      case RecurringPaymentType.yearly:
        return 'Y';
      case RecurringPaymentType.oneTime:
        return '1';
    }
  }
  Future<void> _addRecurringPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final familyId = await UserService.getUserFamilyId();
      if (familyId == null) throw Exception('User not in family');

      final category = _expenseCategories.firstWhere(
        (cat) => cat.id == _selectedCategoryId,
        orElse: () => _expenseCategories.firstWhere(
          (cat) => cat.id == 'other',
        ),
      );

      final payment = RecurringPaymentModel(
        id: '', // Will be generated
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        amount: double.parse(_amountController.text.trim()),
        type: _selectedType,
        categoryId: _selectedCategoryId,
        categoryName: context.categoryName(category.id),
        startDate: _startDate,
        endDate: _endDate,
        nextPaymentDate: _firstPaymentDate ?? _calculateNextPaymentDate(_startDate),
        isActive: true,
        createdAt: DateTime.now(),
        createdBy: UserService.currentUserId ?? '',
        familyId: familyId,
      );

      await RecurringPaymentService.createRecurringPayment(payment);
      _clearForm();
      _showSuccessSnackBar(context.t('paymentCreated'));
    } catch (e) {
      _showErrorSnackBar(context.tx('errorCreatingPayment', {'error': e}));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processDuePayments() async {
    setState(() => _isLoading = true);
    try {
      await RecurringPaymentService.triggerPaymentProcessing();
      _showSuccessSnackBar('Payments processed successfully');
    } catch (e) {
      _showErrorSnackBar('Error processing payments: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  DateTime _calculateNextPaymentDate(DateTime fromDate) {
    switch (_selectedType) {
      case RecurringPaymentType.monthly:
        final nextMonth = fromDate.month == 12 ? 1 : fromDate.month + 1;
        final nextYear = fromDate.month == 12 ? fromDate.year + 1 : fromDate.year;
        return DateTime(nextYear, nextMonth, fromDate.day);
      case RecurringPaymentType.weekly:
        return fromDate.add(const Duration(days: 7));
      case RecurringPaymentType.yearly:
        return DateTime(fromDate.year + 1, fromDate.month, fromDate.day);
      case RecurringPaymentType.oneTime:
        return fromDate;
    }
  }

  void _clearForm() {
    _titleController.clear();
    _descriptionController.clear();
    _amountController.clear();
    _selectedType = RecurringPaymentType.monthly;
    _selectedCategoryId = 'other';
    _startDate = DateTime.now();
    _endDate = null;
    _firstPaymentDate = null;
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

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('recurringPayments')),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            tooltip: 'Process Due Payments',
            onPressed: _isLoading ? null : _processDuePayments,
          ),
        ],
      ),
      body: StreamBuilder<List<RecurringPaymentModel>>(
        stream: RecurringPaymentService.getRecurringPayments(),
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
                    context.t('errorLoadingPayments'),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final payments = snapshot.data ?? [];

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
                    Icon(Icons.repeat, color: Colors.white, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t('activePayments'),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${payments.length} ${context.t('active')}',
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

              // Add Payment Form
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('addNewPayment'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Title
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: context.t('paymentTitle'),
                          prefixIcon: const Icon(Icons.title),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return context.t('enterTitle');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Amount
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: context.t('amount'),
                          prefixIcon: const Icon(Icons.attach_money),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return context.t('enterAmount');
                          }
                          final amount = double.tryParse(value.trim());
                          if (amount == null || amount <= 0) {
                            return context.t('validAmount');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Payment Type
                      DropdownButtonFormField<RecurringPaymentType>(
                        value: _selectedType,
                        decoration: InputDecoration(
                          labelText: context.t('paymentType'),
                          prefixIcon: const Icon(Icons.schedule),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: RecurringPaymentType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Row(
                              children: [
                                Text(_getPaymentTypeIcon(type)),
                                const SizedBox(width: 8),
                                Text(context.recurringPaymentTypeName(type)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Category
                      DropdownButtonFormField<String>(
                        value: _selectedCategoryId,
                        decoration: InputDecoration(
                          labelText: context.t('category'),
                          prefixIcon: const Icon(Icons.category),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: _expenseCategories.map((category) {
                          return DropdownMenuItem(
                            value: category.id,
                            child: Row(
                              children: [
                                Icon(category.icon, color: category.color, size: 20),
                                const SizedBox(width: 8),
                                Text(context.categoryName(category.id)),
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
                      const SizedBox(height: 12),

                      // First Payment Date
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _firstPaymentDate ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setState(() {
                              _firstPaymentDate = picked;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: context.t('firstPaymentDate'),
                            prefixIcon: const Icon(Icons.calendar_today),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _firstPaymentDate != null
                                ? DateFormat('dd.MM.yyyy').format(_firstPaymentDate!)
                                : context.t('tapToSelectDate'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _addRecurringPayment,
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(context.t('addPayment')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Payments List
              Expanded(
                child: payments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.repeat, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              context.t('noRecurringPayments'),
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: payments.length,
                        itemBuilder: (context, index) {
                          final payment = payments[index];
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
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: _getPaymentTypeColor(payment.type).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _getPaymentTypeIcon(payment.type),
                                          style: const TextStyle(fontSize: 20),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              payment.title,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              context.categoryName(payment.categoryId),
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '\$${payment.amount.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red,
                                            ),
                                          ),
                                          Text(
                                            context.recurringPaymentTypeName(payment.type),
                                            style: TextStyle(
                                              color: _getPaymentTypeColor(payment.type),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today,
                                           color: Colors.grey[600], size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        context.tx('nextDate', {'date': DateFormat('MMM dd, yyyy').format(payment.nextPaymentDate)}),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (payment.isOverdue)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            context.t('overdue'),
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        onPressed: () async {
                                          final picked = await showDatePicker(
                                            context: context,
                                            initialDate: payment.nextPaymentDate,
                                            firstDate: DateTime.now(),
                                            lastDate: DateTime.now().add(const Duration(days: 365)),
                                          );
                                          if (picked != null) {
                                            await RecurringPaymentService.updateNextPaymentDate(payment.id, picked);
                                            _showSuccessSnackBar('Payment date updated');
                                          }
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () async {
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: Text(context.t('deletePayment')),
                                              content: Text(context.tx('deletePaymentConfirm', {'title': payment.title})),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, false),
                                                  child: Text(context.t('cancel')),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, true),
                                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                                  child: Text(context.t('delete')),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirmed == true) {
                                            await RecurringPaymentService.deactivateRecurringPayment(payment.id);
                                            _showSuccessSnackBar(context.t('paymentDeleted'));
                                          }
                                        },
                                      ),
                                    ],
                                  ),
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
