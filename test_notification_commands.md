# Notification Listener Testing Commands

## Quick Test in Console

```dart
// Test parser directly
final testNotification = BankingNotificationData(
  packageName: 'ru.sberbankmobile',
  title: 'Покупка',
  text: 'Покупка 1500.00 руб. Магазин Пятерочка',
  timestamp: DateTime.now().millisecondsSinceEpoch,
  bankName: 'Sberbank',
);

final parsed = BankNotificationParser.parse(testNotification);
print('Amount: ${parsed?.amount}');
print('Category: ${parsed != null ? BankNotificationParser.suggestCategory(parsed) : 'N/A'}');
```

## Permission Status Check

```dart
Future<void> checkNotificationStatus() async {
  final hasPermission = await NotificationListenerService.isPermissionGranted();
  final isTrackingEnabled = await NotificationPermissionService.isNotificationTrackingEnabled();
  
  print('Permission: $hasPermission');
  print('Family Tracking: $isTrackingEnabled');
}
```

## Stream Testing

```dart
void testNotificationStream() {
  final stream = NotificationListenerService.startListening();
  
  stream.listen((notification) {
    print('New notification: ${notification.bankName} - ${notification.amount}');
    
    final parsed = BankNotificationParser.parse(notification);
    if (parsed != null) {
      print('Parsed transaction: ${parsed.amount} ${parsed.currency}');
    }
  });
}
```

## Test All Banks

```dart
void testAllBanks() {
  final banks = BankNotificationParser.getSupportedBanks();
  
  for (final bank in banks) {
    print('Testing $bank...');
    // Add bank-specific test cases
  }
}
```
