import 'package:flutter/material.dart';
import '../services/bank_notification_parser.dart';
import '../services/notification_listener_service.dart';

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
        const SnackBar(content: Text('Please enter title and text')),
      );
      return;
    }

    final bankName = _bankController.text.isNotEmpty 
        ? _bankController.text 
        : 'Unknown';

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
          content: Text('Parsed: ${parsed.amount} ${parsed.currency}'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to parse notification'),
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
        title: const Text('Notification Parser Debug'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              setState(() {
                _parsedResults.clear();
              });
            },
            tooltip: 'Clear Results',
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: _testParser,
            tooltip: 'Run Tests',
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
                      const Text(
                        'Debug Page',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This page is for testing the notification parser without actual bank notifications. Click the play button to run tests.',
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
                  const Text(
                    'Custom Test',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bankController,
                    decoration: const InputDecoration(
                      labelText: 'Bank Name (optional)',
                      hintText: 'e.g., Sberbank',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Notification Title',
                      hintText: 'e.g., Покупка',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      labelText: 'Notification Text',
                      hintText: 'e.g., Покупка 1500.00 руб. Магазин',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _testCustomNotification,
                    icon: const Icon(Icons.science),
                    label: const Text('Test Custom Notification'),
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
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Click play to run parser tests'),
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Test Results (${_parsedResults.length})',
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
              _buildResultRow('Amount', '${parsed.amount} ${parsed.currency}'),
              _buildResultRow('Type', parsed.type.toString()),
              _buildResultRow('Merchant', parsed.merchant ?? 'N/A'),
              _buildResultRow('Card', parsed.cardLastDigits ?? 'N/A'),
              _buildResultRow('Suggested Category', category),
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
