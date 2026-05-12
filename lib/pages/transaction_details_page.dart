import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/category_model.dart';

class TransactionDetailsPage extends StatelessWidget {
  final TransactionModel transaction;
  final Category category;
  final VoidCallback onDelete;

  const TransactionDetailsPage({
    super.key,
    required this.transaction,
    required this.category,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final formattedDate = DateFormat('EEEE, MMMM dd, yyyy').format(transaction.date);
    final formattedTime = DateFormat('hh:mm a').format(transaction.date);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Transaction Details'),
        backgroundColor: const Color(0xFF1E3A8A),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.delete,
                color: Color(0xFFDC2626),
                size: 20,
              ),
            ),
            onPressed: () async {
              final confirm = await showDialog<bool>(
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
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                onDelete();
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Amount Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isIncome
                      ? [const Color(0xFF1E3A8A), const Color(0xFF1E40AF), const Color(0xFF2563EB)]
                      : [const Color(0xFFDC2626), const Color(0xFFB91C1C)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (isIncome ? const Color(0xFF1E3A8A) : const Color(0xFFDC2626))
                        .withOpacity(0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${isIncome ? 'Income' : 'Expense'}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${isIncome ? '+' : '-'}\$${transaction.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Details Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                      'Title',
                      transaction.title,
                      Icons.title,
                    ),
                    const Divider(height: 24),
                    _buildDetailRow(
                      'Category',
                      category.name,
                      category.icon,
                      iconColor: isIncome ? const Color(0xFF1E3A8A) : const Color(0xFFDC2626),
                    ),
                    const Divider(height: 24),
                    _buildDetailRow(
                      'Date',
                      formattedDate,
                      Icons.calendar_today,
                    ),
                    const Divider(height: 24),
                    _buildDetailRow(
                      'Time',
                      formattedTime,
                      Icons.access_time,
                    ),
                    if (transaction.notes?.isNotEmpty ?? false) ...[
                      const Divider(height: 24),
                      _buildDetailRow(
                        'Notes',
                        transaction.notes!,
                        Icons.note,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Receipt Image (if available)
            if (transaction.receiptImagePath != null) ...[
              const Text(
                'Receipt',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(transaction.receiptImagePath!),
                    width: double.infinity,
                    height: 300,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 300,
                        width: double.infinity,
                        color: const Color(0xFFF3F4F6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              size: 64,
                              color: const Color(0xFF9CA3AF),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Unable to load receipt',
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon, {
    Color? iconColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (iconColor ?? Colors.grey[600])?.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: iconColor ?? Colors.grey[600],
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
