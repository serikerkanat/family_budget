import 'package:flutter_test/flutter_test.dart';

import '../lib/models/transaction_model.dart';
import '../lib/services/prediction_service.dart';

TransactionModel _expense(double amount, DateTime date) => TransactionModel(
      id: '${date.millisecondsSinceEpoch}-$amount',
      title: 'expense',
      amount: amount,
      date: date,
      type: TransactionType.expense,
      categoryId: 'groceries',
    );

void main() {
  group('PredictionService.generateForecast', () {
    test('returns insufficient-data message when no transactions', () async {
      final result = await PredictionService.generateForecast(
        transactions: const [],
        currentBalance: 1000,
        nextPayday: DateTime.now().add(const Duration(days: 30)),
      );

      expect(result.daysUntilBudgetDepleted, -1);
      expect(result.predictedDailySpend, 0.0);
      expect(result.recommendation, contains('Insufficient data'));
    });

    test('detects deficit when daily spend exceeds budget runway', () async {
      final now = DateTime.now();
      // Spend 500/day for the past 30 days.
      final transactions = List<TransactionModel>.generate(
        30,
        (i) => _expense(500, now.subtract(Duration(days: i + 1))),
      );

      final result = await PredictionService.generateForecast(
        transactions: transactions,
        currentBalance: 5000, // ~10 days at 500/day
        nextPayday: now.add(const Duration(days: 30)),
        analysisMonths: 2,
      );

      expect(result.predictedDailySpend, greaterThan(0));
      expect(result.daysUntilBudgetDepleted, lessThan(30));
      expect(
        result.recommendation.toLowerCase(),
        anyOf(contains('warning'), contains('reduce')),
      );
    });

    test('produces 30-day prediction list', () {
      final now = DateTime.now();
      final transactions = List<TransactionModel>.generate(
        20,
        (i) => _expense(100, now.subtract(Duration(days: i + 1))),
      );

      final preds = PredictionService.predictNext30Days(transactions);
      expect(preds.length, 30);
      for (final p in preds) {
        expect(p, isA<double>());
      }
    });
  });
}
