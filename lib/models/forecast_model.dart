class ForecastModel {
  final int daysUntilBudgetDepleted;
  final double probability;
  final double predictedDailySpend;
  final double confidenceInterval;
  final DateTime predictedDepletionDate;
  final String recommendation;
  final DateTime createdAt;

  ForecastModel({
    required this.daysUntilBudgetDepleted,
    required this.probability,
    required this.predictedDailySpend,
    required this.confidenceInterval,
    required this.predictedDepletionDate,
    required this.recommendation,
  }) : createdAt = DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'daysUntilBudgetDepleted': daysUntilBudgetDepleted,
      'probability': probability,
      'predictedDailySpend': predictedDailySpend,
      'confidenceInterval': confidenceInterval,
      'predictedDepletionDate': predictedDepletionDate.toIso8601String(),
      'recommendation': recommendation,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ForecastModel.fromJson(Map<String, dynamic> json) {
    return ForecastModel(
      daysUntilBudgetDepleted: json['daysUntilBudgetDepleted'] ?? 0,
      probability: (json['probability'] as num?)?.toDouble() ?? 0.0,
      predictedDailySpend: (json['predictedDailySpend'] as num?)?.toDouble() ?? 0.0,
      confidenceInterval: (json['confidenceInterval'] as num?)?.toDouble() ?? 0.0,
      predictedDepletionDate: DateTime.parse(json['predictedDepletionDate'] ?? DateTime.now().toIso8601String()),
      recommendation: json['recommendation'] ?? '',
    );
  }

  String get riskLevel {
    if (probability >= 80) return 'High';
    if (probability >= 60) return 'Medium';
    return 'Low';
  }

  bool get isUrgent {
    return daysUntilBudgetDepleted >= 0 && daysUntilBudgetDepleted < 7;
  }
}
