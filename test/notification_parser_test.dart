import 'package:flutter_test/flutter_test.dart';
import '../lib/services/bank_notification_parser.dart';
import '../lib/services/notification_listener_service.dart';
import '../lib/models/transaction_model.dart';

void main() {
  group('BankNotificationParser Tests', () {
    test('Parse Sberbank expense notification', () {
      final notification = BankingNotificationData(
        packageName: 'ru.sberbankmobile',
        title: 'Покупка',
        text: 'Покупка 1500.00 руб. Магазин Пятерочка',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        bankName: 'Sberbank',
        amount: 1500.00,
        currency: 'RUB',
        merchant: 'Пятерочка',
        type: 'expense',
      );

      final parsed = BankNotificationParser.parse(notification);
      
      expect(parsed, isNotNull);
      expect(parsed!.amount, 1500.00);
      expect(parsed.currency, 'RUB');
      expect(parsed.merchant, 'Пятерочка');
      expect(parsed.type, TransactionType.expense);
    });

    test('Parse Tinkoff income notification', () {
      final notification = BankingNotificationData(
        packageName: 'com.idamob.tinkoff.android',
        title: 'Поступление',
        text: 'Поступление 10000₽',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        bankName: 'Tinkoff',
        amount: 10000.00,
        currency: 'RUB',
        type: 'income',
      );

      final parsed = BankNotificationParser.parse(notification);
      
      expect(parsed, isNotNull);
      expect(parsed!.amount, 10000.00);
      expect(parsed.type, TransactionType.income);
    });

    test('Suggest correct categories', () {
      final foodTransaction = ParsedTransaction(
        amount: 500.0,
        currency: 'RUB',
        merchant: 'Starbucks',
        type: TransactionType.expense,
        bankName: 'Test Bank',
        date: DateTime.now(),
        rawTitle: 'Покупка',
        rawText: 'Покупка 500 руб Starbucks',
      );

      final category = BankNotificationParser.suggestCategory(foodTransaction);
      expect(category, 'food');
    });

    test('Handle unsupported bank', () {
      final isSupported = BankNotificationParser.isBankSupported('Unknown Bank');
      expect(isSupported, false);
    });
  });
}
