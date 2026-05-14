import 'package:flutter/material.dart';
import '../services/bank_notification_parser.dart';
import '../services/notification_listener_service.dart';
import '../l10n/app_localizations.dart';

class NotificationDebugPage extends StatefulWidget {
  const NotificationDebugPage({Key? key}) : super(key: key);

  @override
  State<NotificationDebugPage> createState() => _NotificationDebugPageState();
}

class _NotificationDebugPageState extends State<NotificationDebugPage> {
  final _titleController = TextEditingController();
  final _textController = TextEditingController();
  final _bankController = TextEditingController();
  final List<TestNotification> _testNotifications = [
    TestNotification(
      bankName: 'Sberbank',
      title: 'Покупка',
      text: 'Покупка 1500.00 руб. Магазин Пятерочка',
    ),
    TestNotification(
      bankName: 'Sberbank',
      title: 'Зачисление',
      text: 'Зачисление 50000.00 руб. Зарплата',
    ),
    TestNotification(
      bankName: 'Tinkoff',
      title: 'Трата',
      text: 'Вы потратили 850₽ в Starbucks',
    ),
    TestNotification(
      bankName: 'Tinkoff',
      title: 'Поступление',
      text: 'Поступление 10000₽',
    ),
    TestNotification(
      bankName: 'Alfa Bank',
      title: 'Оплата',
      text: 'Оплата картой *1234 на 2300 руб. Uber',
    ),
    TestNotification(
      bankName: 'Alfa Bank',
      title: 'Зачисление',
      text: 'Зачисление 15000 руб на счет *5678',
    ),
    TestNotification(
      bankName: 'VTB',
      title: 'Операция',
      text: 'Списание 3200.00 руб. Яндекс Такси',
    ),
    TestNotification(
      bankName: 'VTB',
      title: 'Доход',
      text: 'Зачисление 25000 руб',
    ),
  ];

  final List<ParsedTransaction?> _parsedResults = [];

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    _bankController.dispose();
    super.dispose();
  }

  void _testCustomNotification() {
    if (_titleController.text.isEmpty || _textController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('enterTitleAndText'))),
      );
      return;
    }

    final bankName = _bankController.text.isNotEmpty
        ? _bankController.text
        : context.t('unknown');

    final notification = BankingNotificationData(
      packageName: 'com.test.bank',
      title: _titleController.text,
      text: _textController.text,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      bankName: bankName,
    );

    final parsed = BankNotificationParser.parse(notification);
    
    setState(() {
      _parsedResults.insert(0, parsed);
    });

    if (parsed != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tx('parsedNotification', {'amount': parsed.amount, 'currency': parsed.currency})),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('failedParseNotification')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _testParser() {
    setState(() {
      _parsedResults.clear();
      for (final test in _testNotifications) {
        final notification = BankingNotificationData(
          packageName: BankNotificationParser.getBankPackageName(test.bankName),
          title: test.title,
          text: test.text,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          bankName: test.bankName,
        );
        final parsed = BankNotificationParser.parse(notification);
        _parsedResults.add(parsed);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('notificationParserDebug')),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              setState(() {
                _parsedResults.clear();
              });
            },
            tooltip: context.t('clearResults'),
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: _testParser,
            tooltip: context.t('runTests'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text(
                        context.t('debugPage'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.t('debugPageDesc'),
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('customTest'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bankController,
                    decoration: InputDecoration(
                      labelText: context.t('bankNameOptional'),
                      hintText: 'e.g., Sberbank',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: context.t('notificationTitle'),
                      hintText: 'e.g., Покупка',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      labelText: context.t('notificationText'),
                      hintText: 'e.g., Покупка 1500.00 руб. Магазин',
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _testCustomNotification,
                    icon: const Icon(Icons.science),
                    label: Text(context.t('testCustomNotification')),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_parsedResults.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.touch_app, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(context.t('clickPlayTests')),
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tx('testResults', {'count': _parsedResults.length}),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(_testNotifications.length, (index) {
                  final test = _testNotifications[index];
                  final parsed = _parsedResults[index];
                  return _buildTestResult(test, parsed);
                }),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTestResult(TestNotification test, ParsedTransaction? parsed) {
    final isSuccess = parsed != null;
    final category = parsed != null ? BankNotificationParser.suggestCategory(parsed) : 'other';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                    color: isSuccess ? Colors.green[100] : Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isSuccess ? Icons.check_circle : Icons.error,
                    color: isSuccess ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        test.bankName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${test.title}: ${test.text}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (parsed != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              _buildResultRow(context.t('amount'), '${parsed.amount} ${parsed.currency}'),
              _buildResultRow(context.t('paymentType'), parsed.type.toString()),
              _buildResultRow(context.t('merchant'), parsed.merchant ?? 'N/A'),
              _buildResultRow(context.t('card'), parsed.cardLastDigits ?? 'N/A'),
              _buildResultRow(context.t('suggestedCategory'), context.categoryName(category)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class TestNotification {
  final String bankName;
  final String title;
  final String text;

  TestNotification({
    required this.bankName,
    required this.title,
    required this.text,
  });
}
