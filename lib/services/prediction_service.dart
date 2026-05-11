import 'dart:math';
import '../models/transaction_model.dart';

class ForecastResult {
  final int daysUntilBudgetDepleted;
  final double probability;
  final double predictedDailySpend;
  final double confidenceInterval;
  final DateTime predictedDepletionDate;
  final String recommendation;

  ForecastResult({
    required this.daysUntilBudgetDepleted,
    required this.probability,
    required this.predictedDailySpend,
    required this.confidenceInterval,
    required this.predictedDepletionDate,
    required this.recommendation,
  });

  @override
  String toString() {
    return 'ForecastResult(daysUntilBudgetDepleted: $daysUntilBudgetDepleted, probability: $probability, predictedDailySpend: $predictedDailySpend)';
  }
}

class PredictionService {
  // Simple linear regression implementation
  static Map<String, double> _linearRegression(List<double> x, List<double> y) {
    if (x.length != y.length || x.length < 2) {
      return {'slope': 0.0, 'intercept': 0.0};
    }

    final n = x.length;
    double sumX = 0;
    double sumY = 0;
    double sumXY = 0;
    double sumX2 = 0;

    for (int i = 0; i < n; i++) {
      sumX += x[i];
      sumY += y[i];
      sumXY += x[i] * y[i];
      sumX2 += x[i] * x[i];
    }

    final denominator = n * sumX2 - sumX * sumX;
    if (denominator == 0) {
      return {'slope': 0.0, 'intercept': y.reduce((a, b) => a + b) / n};
    }

    final slope = (n * sumXY - sumX * sumY) / denominator;
    final intercept = (sumY - slope * sumX) / n;

    return {'slope': slope, 'intercept': intercept};
  }

  // Analyze spending patterns over the last N months
  static List<double> _getDailySpendingPattern(List<TransactionModel> transactions, int months) {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month - months, now.day);
    
    // Group expenses by day
    final Map<int, double> dailySpending = {};
    
    for (final tx in transactions) {
      if (tx.type == TransactionType.expense && tx.date.isAfter(startDate)) {
        final dayKey = tx.date.difference(startDate).inDays;
        dailySpending[dayKey] = (dailySpending[dayKey] ?? 0) + tx.amount;
      }
    }

    // Fill in missing days with 0
    final totalDays = now.difference(startDate).inDays;
    final List<double> pattern = [];
    for (int i = 0; i <= totalDays; i++) {
      pattern.add(dailySpending[i] ?? 0.0);
    }

    return pattern;
  }

  // Calculate average daily spending with trend
  static Map<String, double> _analyzeSpendingTrend(List<double> dailySpending) {
    if (dailySpending.isEmpty) {
      return {'average': 0.0, 'trend': 0.0, 'volatility': 0.0};
    }

    // Calculate moving average (7-day window)
    final List<double> movingAverages = [];
    final windowSize = min(7, dailySpending.length);
    
    for (int i = windowSize - 1; i < dailySpending.length; i++) {
      double sum = 0;
      for (int j = 0; j < windowSize; j++) {
        sum += dailySpending[i - j];
      }
      movingAverages.add(sum / windowSize);
    }

    if (movingAverages.isEmpty) {
      final avg = dailySpending.reduce((a, b) => a + b) / dailySpending.length;
      return {'average': avg, 'trend': 0.0, 'volatility': 0.0};
    }

    // Calculate trend using linear regression on moving averages
    final x = List.generate(movingAverages.length, (i) => i.toDouble());
    final regression = _linearRegression(x, movingAverages);
    
    // Calculate volatility (standard deviation)
    final avg = movingAverages.reduce((a, b) => a + b) / movingAverages.length;
    final variance = movingAverages.map((v) => pow(v - avg, 2)).reduce((a, b) => a + b) / movingAverages.length;
    final volatility = sqrt(variance);

    return {
      'average': avg,
      'trend': regression['slope']!,
      'volatility': volatility,
    };
  }

  // Generate forecast
  static Future<ForecastResult> generateForecast({
    required List<TransactionModel> transactions,
    required double currentBalance,
    required DateTime nextPayday,
    int analysisMonths = 6,
  }) async {
    // Get spending pattern
    final dailySpending = _getDailySpendingPattern(transactions, analysisMonths);
    
    if (dailySpending.isEmpty) {
      return ForecastResult(
        daysUntilBudgetDepleted: -1,
        probability: 0.0,
        predictedDailySpend: 0.0,
        confidenceInterval: 0.0,
        predictedDepletionDate: nextPayday,
        recommendation: 'Insufficient data for prediction. Add more transactions.',
      );
    }

    // Analyze trend
    final trendAnalysis = _analyzeSpendingTrend(dailySpending);
    final avgDailySpend = trendAnalysis['average']!;
    final dailyTrend = trendAnalysis['trend']!;
    final volatility = trendAnalysis['volatility']!;

    // Calculate predicted daily spending (with trend)
    final predictedDailySpend = avgDailySpend + dailyTrend;

    // Calculate days until budget depletion
    int daysUntilDepleted;
    if (predictedDailySpend > 0) {
      daysUntilDepleted = (currentBalance / predictedDailySpend).floor();
    } else {
      daysUntilDepleted = 999; // Budget won't deplete
    }

    // Calculate confidence based on data quality and volatility
    final dataQuality = min(1.0, dailySpending.length / 180.0); // 180 days = 6 months
    final stabilityScore = max(0.0, 1.0 - (volatility / (avgDailySpend + 1)));
    final confidence = (dataQuality * 0.6 + stabilityScore * 0.4);
    final probability = (confidence * 100).clamp(50.0, 95.0);

    // Calculate confidence interval
    final confidenceInterval = volatility * 1.96; // 95% confidence interval

    // Predict depletion date
    final predictedDepletionDate = DateTime.now().add(Duration(days: daysUntilDepleted));

    // Generate recommendation
    String recommendation;
    final daysUntilPayday = nextPayday.difference(DateTime.now()).inDays;
    
    if (daysUntilDepleted < 0) {
      recommendation = 'Budget already depleted!';
    } else if (daysUntilDepleted > daysUntilPayday) {
      final surplusDays = daysUntilDepleted - daysUntilPayday;
      recommendation = 'Great! Your budget will last $surplusDays days past payday. Consider saving the surplus.';
    } else if (daysUntilDepleted < daysUntilPayday) {
      final deficitDays = daysUntilPayday - daysUntilDepleted;
      recommendation = 'Warning: Budget will run out $deficitDays days before payday. Reduce daily spending by \$${((avgDailySpend * daysUntilPayday - currentBalance) / daysUntilPayday).toStringAsFixed(2)}.';
    } else {
      recommendation = 'Budget will last exactly until payday. Monitor spending closely.';
    }

    return ForecastResult(
      daysUntilBudgetDepleted: daysUntilDepleted,
      probability: probability,
      predictedDailySpend: predictedDailySpend.clamp(0, double.infinity),
      confidenceInterval: confidenceInterval,
      predictedDepletionDate: predictedDepletionDate,
      recommendation: recommendation,
    );
  }

  // Get spending predictions for next 30 days
  static List<double> predictNext30Days(List<TransactionModel> transactions) {
    final dailySpending = _getDailySpendingPattern(transactions, 3);
    final trendAnalysis = _analyzeSpendingTrend(dailySpending);
    final avgDailySpend = trendAnalysis['average']!;
    final dailyTrend = trendAnalysis['trend']!;

    final predictions = <double>[];
    for (int i = 0; i < 30; i++) {
      predictions.add(avgDailySpend + dailyTrend * i);
    }

    return predictions;
  }
}
