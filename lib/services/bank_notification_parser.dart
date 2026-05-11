import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import 'notification_listener_service.dart';

class ParsedTransaction {
  final double amount;
  final String currency;
  final String? merchant;
  final TransactionType type;
  final String? cardLastDigits;
  final String bankName;
  final DateTime date;
  final String rawTitle;
  final String rawText;

  ParsedTransaction({
    required this.amount,
    required this.currency,
    this.merchant,
    required this.type,
    this.cardLastDigits,
    required this.bankName,
    required this.date,
    required this.rawTitle,
    required this.rawText,
  });

  TransactionModel toTransactionModel(String categoryId) {
    return TransactionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: merchant ?? 'Transaction from $bankName',
      amount: amount,
      date: date,
      type: type,
      categoryId: categoryId,
      notes: 'Auto-imported from $bankName notification',
    );
  }
}

class BankNotificationParser {
  static final Map<String, List<String>> _categoryKeywords = {
    'food': ['кафе', 'ресторан', 'продукты', 'супермаркет', 'пекарня', 'макдоналдс', 'kfc', 'бургер кинг', 'starbucks', 'шоколадница', 'coffe', 'еда'],
    'transport': ['такси', 'uber', 'яндекс', 'метро', 'азс', 'бензин', 'транспорт', 'parking', 'парковка'],
    'shopping': ['магаз', 'одежда', 'обувь', 'shopping', 'молл', 'тц', 'wildberries', 'ozon', 'lamoda', 'aliexpress'],
    'entertainment': ['кино', 'фильм', 'концерт', 'театр', 'игра', 'netflix', 'spotify', 'youtube', 'развлечение'],
    'bills': ['жкх', 'свет', 'газ', 'вода', 'интернет', 'телефон', 'связь', 'мтс', 'билайн', 'мегафон', 'tele2'],
    'healthcare': ['аптека', 'врач', 'больница', 'клиника', 'медицина', 'лекарство', 'фарм', 'апт'],
    'education': ['курс', 'обучение', 'школа', 'университет', 'skillbox', 'udemy', 'coursera'],
    'travel': ['авиа', 'билет', 'отель', 'гостиница', 'тур', 'путешествие', 'аэрофлот', 's7'],
  };

  static ParsedTransaction? parse(BankingNotificationData notification) {
    if (notification.amount == null) {
      return null;
    }

    final type = _determineTransactionType(notification.type, notification.title, notification.text);
    
    return ParsedTransaction(
      amount: notification.amount!,
      currency: notification.currency ?? 'RUB',
      merchant: notification.merchant,
      type: type,
      cardLastDigits: notification.cardLastDigits,
      bankName: notification.bankName,
      date: DateTime.fromMillisecondsSinceEpoch(notification.timestamp),
      rawTitle: notification.title,
      rawText: notification.text,
    );
  }

  static String suggestCategory(ParsedTransaction transaction) {
    if (transaction.merchant == null) {
      return 'other';
    }

    final merchant = transaction.merchant!.toLowerCase();
    final text = (transaction.rawTitle + ' ' + transaction.rawText).toLowerCase();

    for (final entry in _categoryKeywords.entries) {
      final categoryId = entry.key;
      final keywords = entry.value;

      for (final keyword in keywords) {
        if (merchant.contains(keyword) || text.contains(keyword)) {
          return categoryId;
        }
      }
    }

    return 'other';
  }

  static TransactionType _determineTransactionType(
    String? parsedType,
    String title,
    String text,
  ) {
    // If the Android parser already determined the type, use it
    if (parsedType == 'income') {
      return TransactionType.income;
    } else if (parsedType == 'expense') {
      return TransactionType.expense;
    }

    // Otherwise, determine from text
    final fullText = '$title $text'.toLowerCase();
    
    final incomeKeywords = [
      'зачисление',
      'поступление',
      'доход',
      'возврат',
      'cashback',
      'кэшбэк',
      'бонус',
    ];

    for (final keyword in incomeKeywords) {
      if (fullText.contains(keyword)) {
        return TransactionType.income;
      }
    }

    return TransactionType.expense;
  }

  static List<String> getSupportedBanks() {
    return [
      'Sberbank',
      'Tinkoff',
      'Alfa Bank',
      'VTB',
      'Gazprombank',
      'Raiffeisen',
      'Otkritie',
    ];
  }

  static bool isBankSupported(String bankName) {
    return getSupportedBanks().contains(bankName);
  }

  static String getBankPackageName(String bankName) {
    switch (bankName) {
      case 'Sberbank':
        return 'ru.sberbankmobile';
      case 'Tinkoff':
        return 'com.idamob.tinkoff.android';
      case 'Alfa Bank':
        return 'ru.alfabank.mobile.android';
      case 'VTB':
        return 'com.vtb.mobilebanking';
      case 'Gazprombank':
        return 'com.gazprombank.android';
      case 'Raiffeisen':
        return 'com.raiffeisenrbank.mobile';
      case 'Otkritie':
        return 'com.openbank';
      default:
        return '';
    }
  }
}
