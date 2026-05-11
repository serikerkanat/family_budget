# Notification Listener Feature

## Overview

This feature automatically imports banking transactions from push notifications on Android devices using the NotificationListenerService API.

## Features

- **Automatic Transaction Import**: Captures banking app notifications and parses transaction details
- **Multi-Bank Support**: Supports 7 major Russian banks (Sberbank, Tinkoff, Alfa Bank, VTB, Gazprombank, Raiffeisen, Otkritie)
- **Smart Categorization**: Automatically suggests categories based on merchant names and keywords
- **Family Role Control**: Only parents can enable/disable notification tracking
- **Duplicate Detection**: Prevents duplicate transactions with intelligent merging
- **Debug Tools**: Built-in parser testing and custom notification testing

## How It Works

1. **Permission Grant**: User grants notification listener permission in system settings
2. **Service Start**: AutoTransactionService starts when app launches
3. **Notification Capture**: BankingNotificationListenerService (Android) captures notifications
4. **Parsing**: BankNotificationParser extracts amount, merchant, type, and card details
5. **Categorization**: Suggests category based on keywords
6. **Deduplication**: Checks for existing transactions to prevent duplicates
7. **Storage**: Saves to Firestore with family context

## Architecture

### Android Native

- `BankingNotificationListenerService.kt` - Android service that intercepts notifications
- `NotificationListenerPlugin.kt` - Flutter plugin for MethodChannel/EventChannel communication
- `MainActivity.kt` - Registers the plugin

### Flutter Services

- `notification_listener_service.dart` - Flutter interface to Android service
- `bank_notification_parser.dart` - Parses notification text and suggests categories
- `notification_permission_service.dart` - Manages settings with family role checks
- `auto_transaction_service.dart` - Orchestrates automatic import
- `transaction_deduplication_service.dart` - Handles duplicate detection and merging

### UI Pages

- `notification_settings_page.dart` - Settings UI for users
- `notification_debug_page.dart` - Debug/testing page for developers

## Setup Instructions

### 1. Android Configuration

The Android configuration is already complete:
- Service registered in `AndroidManifest.xml`
- Plugin registered in `MainActivity.kt`
- Kotlin files created in `android/app/src/main/kotlin/`

### 2. User Setup

1. Open the app
2. Tap the notification icon (bell) in the app bar
3. Tap "Grant Permission" to open system settings
4. Enable "Family Budget" in notification listener settings
5. Return to app and enable "Automatic Tracking"
6. Select which banks to track

### 3. Family Role Requirements

- **Parents**: Can enable/disable tracking, select banks, edit category rules
- **Children**: Can view settings but cannot modify them

## Supported Banks

| Bank | Package Name |
|------|--------------|
| Sberbank | ru.sberbankmobile |
| Tinkoff | com.idamob.tinkoff.android |
| Alfa Bank | ru.alfabank.mobile.android |
| VTB | com.vtb.mobilebanking |
| Gazprombank | com.gazprombank.android |
| Raiffeisen | com.raiffeisenrbank.mobile |
| Otkritie | com.openbank |

## Notification Format Examples

### Sberbank
```
Title: Покупка
Text: Покупка 1500.00 руб. Магазин Пятерочка
```

### Tinkoff
```
Title: Трата
Text: Вы потратили 850₽ в Starbucks
```

### Alfa Bank
```
Title: Оплата
Text: Оплата картой *1234 на 2300 руб. Uber
```

## Category Keywords

The parser uses keyword matching to suggest categories:

- **Food**: кафе, ресторан, продукты, супермаркет, пекарня, etc.
- **Transport**: такси, uber, яндекс, метро, азс, бензин, etc.
- **Shopping**: магаз, одежда, обувь, wildberries, ozon, etc.
- **Entertainment**: кино, концерт, игра, netflix, spotify, etc.
- **Bills**: жкх, свет, газ, вода, интернет, телефон, etc.
- **Healthcare**: аптека, врач, больница, клиника, etc.
- **Education**: курс, обучение, школа, университет, etc.
- **Travel**: авиа, билет, отель, тур, путешествие, etc.

## Duplicate Detection

The system uses a 5-minute time window to detect duplicates:
- Transactions with same amount, type, and within 5 minutes are considered duplicates
- Manual transactions take priority over automatic ones
- Notification data is merged into existing manual transactions when possible

## Debug Mode

Access the debug page by:
1. Go to Notification Settings
2. Tap the bug icon in the app bar
3. Run preset tests or enter custom notification text

## Privacy & Security

- Only notification text is parsed, not full notification content
- No sensitive card data is stored (only last 4 digits)
- All data is stored in Firebase with family-level isolation
- Users must explicitly grant permission in system settings

## Limitations

- **Android Only**: NotificationListenerService is not available on iOS
- **System Settings**: Users must manually grant permission in Android settings
- **Notification Format**: Depends on bank's notification format (may break if banks change format)
- **Language**: Currently optimized for Russian language notifications

## Future Enhancements

- [ ] Add more banks
- [ ] Machine learning for better categorization
- [ ] iOS alternative (Screen Time API or manual import)
- [ ] Transaction editing from notification data
- [ ] Multi-language support
- [ ] Custom regex patterns per bank
- [ ] Notification history viewer

## Troubleshooting

### Permission Not Granted
- Ensure the app is enabled in Settings > Apps > Special Access > Notification Access
- Restart the app after granting permission

### Notifications Not Being Captured
- Check that the bank app is sending notifications
- Verify the bank is in the enabled banks list
- Check Android battery optimization settings (may kill the service)

### Incorrect Parsing
- Use the debug page to test notification format
- Check if bank has changed notification format
- Report the issue with the notification text

## Google Play Considerations

When publishing to Google Play:
- Clearly disclose that the app reads notifications
- Explain the purpose (automatic transaction import)
- Provide privacy policy
- Ensure user consent is obtained before accessing notifications
- The app should work without this feature (manual entry still available)
