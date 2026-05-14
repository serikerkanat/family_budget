import 'dart:io';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import '../models/transaction_model.dart';
import '../models/budget_model.dart';
import '../models/savings_goal_model.dart';

class ExportService {
  // Export monthly report to PDF
  static Future<void> exportToPDF({
    required List<TransactionModel> transactions,
    required List<BudgetModel> budgets,
    required List<SavingsGoalModel> savingsGoals,
    required String month,
    required String year,
  }) async {
    final pdf = pw.Document();
    
    // Add title page
    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Family Budget Report',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue,
                    ),
                  ),
                  pw.Text(
                    '$month $year',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              
              // Summary Section
              pw.Container(
                padding: pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Summary',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    _buildSummaryRow('Total Transactions', '${transactions.length}'),
                    _buildSummaryRow('Total Income', 
                        '\$${_calculateTotalIncome(transactions).toStringAsFixed(2)}'),
                    _buildSummaryRow('Total Expenses', 
                        '\$${_calculateTotalExpenses(transactions).toStringAsFixed(2)}'),
                    _buildSummaryRow('Net Balance', 
                        '\$${(_calculateTotalIncome(transactions) - _calculateTotalExpenses(transactions)).toStringAsFixed(2)}'),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              
              // Budgets Section
              if (budgets.isNotEmpty) ...[
                pw.Text(
                  'Budget Analysis',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue,
                  ),
                ),
                pw.SizedBox(height: 10),
                ...budgets.map((budget) => pw.Container(
                  margin: pw.EdgeInsets.only(bottom: 10),
                  padding: pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        budget.categoryName,
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      _buildSummaryRow('Budget Limit', 
                          '\$${budget.monthlyLimit.toStringAsFixed(2)}'),
                      _buildSummaryRow('Spent', 
                          '\$${budget.currentSpent.toStringAsFixed(2)}'),
                      _buildSummaryRow('Remaining', 
                          '\$${budget.remaining.toStringAsFixed(2)}'),
                      _buildSummaryRow('Usage', 
                          '${budget.percentageUsed.toStringAsFixed(1)}%'),
                    ],
                  ),
                )),
                pw.SizedBox(height: 20),
              ],
              
              // Savings Goals Section
              if (savingsGoals.isNotEmpty) ...[
                pw.Text(
                  'Savings Goals',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue,
                  ),
                ),
                pw.SizedBox(height: 10),
                ...savingsGoals.map((goal) => pw.Container(
                  margin: pw.EdgeInsets.only(bottom: 10),
                  padding: pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        goal.title,
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      _buildSummaryRow('Target', 
                          '\$${goal.targetAmount.toStringAsFixed(2)}'),
                      _buildSummaryRow('Saved', 
                          '\$${goal.currentAmount.toStringAsFixed(2)}'),
                      _buildSummaryRow('Remaining', 
                          '\$${goal.remainingAmount.toStringAsFixed(2)}'),
                      _buildSummaryRow('Progress', 
                          '${goal.percentageSaved.toStringAsFixed(1)}%'),
                    ],
                  ),
                )),
                pw.SizedBox(height: 20),
              ],
              
              // Transactions Section
              pw.Text(
                'Transactions',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                context: context,
                data: List<List<String>>.from([
                  ['Date', 'Title', 'Category', 'Type', 'Amount'],
                  ...transactions.map((t) => [
                    DateFormat('MMM dd, yyyy').format(t.date),
                    t.title,
                    t.categoryId,
                    t.type.toString(),
                    '\$${t.amount.toStringAsFixed(2)}',
                  ]),
                ]),
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: pw.BoxDecoration(
                  color: PdfColors.blue,
                ),
                cellStyle: pw.TextStyle(fontSize: 10),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.center,
                  4: pw.Alignment.centerRight,
                },
              ),
            ],
          );
        },
      ),
    );

    // Save and print PDF
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/family_budget_report_$month$year.pdf');
    await file.writeAsBytes(await pdf.save());
    
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'family_budget_report_$month$year.pdf',
    );
  }

  // Export to Excel
  static Future<void> exportToExcel({
    required List<TransactionModel> transactions,
    required List<BudgetModel> budgets,
    required List<SavingsGoalModel> savingsGoals,
    required String month,
    required String year,
  }) async {
    final excel = Excel.createExcel();
    
    // Transactions Sheet
    final transactionsSheet = excel['Transactions'];
    
    // Headers
    transactionsSheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Title'),
      TextCellValue('Category'),
      TextCellValue('Type'),
      TextCellValue('Amount'),
    ]);
    
    // Data
    for (final transaction in transactions) {
      transactionsSheet.appendRow([
        TextCellValue(DateFormat('yyyy-MM-dd').format(transaction.date)),
        TextCellValue(transaction.title),
        TextCellValue(transaction.categoryId),
        TextCellValue(transaction.type.toString()),
        TextCellValue(transaction.amount.toString()),
      ]);
    }

    // Budgets Sheet
    final budgetsSheet = excel['Budgets'];
    
    // Headers
    budgetsSheet.appendRow([
      TextCellValue('Category'),
      TextCellValue('Monthly Limit'),
      TextCellValue('Current Spent'),
      TextCellValue('Remaining'),
      TextCellValue('Usage %'),
    ]);
    
    // Data
    for (final budget in budgets) {
      budgetsSheet.appendRow([
        TextCellValue(budget.categoryName),
        TextCellValue(budget.monthlyLimit.toString()),
        TextCellValue(budget.currentSpent.toString()),
        TextCellValue(budget.remaining.toString()),
        TextCellValue(budget.percentageUsed.toString()),
      ]);
    }

    // Savings Goals Sheet
    final savingsSheet = excel['Savings Goals'];
    
    // Headers
    savingsSheet.appendRow([
      TextCellValue('Title'),
      TextCellValue('Target Amount'),
      TextCellValue('Current Saved'),
      TextCellValue('Remaining'),
      TextCellValue('Progress %'),
      TextCellValue('Target Date'),
      TextCellValue('Status'),
    ]);
    
    // Data
    for (final goal in savingsGoals) {
      savingsSheet.appendRow([
        TextCellValue(goal.title),
        TextCellValue(goal.targetAmount.toString()),
        TextCellValue(goal.currentAmount.toString()),
        TextCellValue(goal.remainingAmount.toString()),
        TextCellValue(goal.percentageSaved.toString()),
        TextCellValue(DateFormat('yyyy-MM-dd').format(goal.targetDate)),
        TextCellValue(goal.isAchieved ? 'Achieved' : 
                   goal.isOverdue ? 'Overdue' : 'In Progress'),
      ]);
    }

    // Save file
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/family_budget_report_$month$year.xlsx');
    
    final excelBytes = excel.save();
    await file.writeAsBytes(excelBytes!);
    
    // Share file (if possible)
    // Note: For mobile, you might want to use share_plus package
  }

  // Helper methods
  static pw.Widget _buildSummaryRow(String label, String value) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 12),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static double _calculateTotalIncome(List<TransactionModel> transactions) {
    return transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  static double _calculateTotalExpenses(List<TransactionModel> transactions) {
    return transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }
}
