import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../models/category_model.dart';
import '../services/user_service.dart';
import '../services/budget_service.dart';
import '../services/bank_notification_parser.dart';
import '../services/gemini_notification_parser.dart';
import '../services/notification_listener_service.dart';
import '../services/notification_permission_service.dart';
import '../services/transaction_deduplication_service.dart';
import '../services/currency_conversion_service.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Get current user ID
  static String? get currentUserId => _auth.currentUser?.uid;
  
  // Get transactions filtered by family
  static Stream<List<TransactionModel>> getTransactions() {
    return UserService.currentUserStream.asyncMap(
      (userSnapshot) async {
        final userData = userSnapshot;
        final familyId = userData?['familyId'] as String?;
        
        if (familyId == null) {
          return <TransactionModel>[];
        }
        
        final transactionsSnapshot = await _db
            .collection('transactions')
            .where('familyId', isEqualTo: familyId)
            .orderBy('date', descending: true)
            .get();
            
        return transactionsSnapshot.docs
            .map((doc) => _transactionFromDocument(doc))
            .toList();
      },
    );
  }
  
  // Add transaction
  static Future<void> addTransaction(TransactionModel transaction) async {
    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) throw Exception('User not in family');

    await _db.collection('transactions').add({
      'id': transaction.id,
      'title': transaction.title,
      'amount': transaction.amount,
      'date': transaction.date.toIso8601String(),
      'type': transaction.type.toString(),
      'categoryId': transaction.categoryId,
      'receiptImagePath': transaction.receiptImagePath,
      'notes': transaction.notes,
      'familyId': familyId,
      'createdBy': currentUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // Update budget spending if this is an expense transaction
    if (transaction.type == TransactionType.expense) {
      await BudgetService.updateBudgetSpending(
        transaction.categoryId, 
        transaction.amount,
      );
    }
  }
  
  // Update transaction
  static Future<void> updateTransaction(TransactionModel transaction) async {
    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) throw Exception('User not in family');
    
    await _db.collection('transactions').doc(transaction.id).update({
      'title': transaction.title,
      'amount': transaction.amount,
      'date': transaction.date.toIso8601String(),
      'type': transaction.type.toString(),
      'categoryId': transaction.categoryId,
      'receiptImagePath': transaction.receiptImagePath,
      'notes': transaction.notes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  
  // Delete transaction
  static Future<void> deleteTransaction(String id) async {
    final familyId = await UserService.getUserFamilyId();
    if (familyId == null) throw Exception('User not in family');
    
    await _db.collection('transactions').doc(id).delete();
  }

  // Add transaction from notification
  static Future<void> addTransactionFromNotification(
    BankingNotificationData notificationData,
  ) async {
    try {
      final familyId = await UserService.getUserFamilyId();
      if (familyId == null) {
        print('User not in family');
        return;
      }

      // Check if notification tracking is enabled
      final isTrackingEnabled = await NotificationPermissionService.isNotificationTrackingEnabled();
      if (!isTrackingEnabled) return;

      // Get settings to check if bank is enabled
      final settings = await NotificationPermissionService.getNotificationSettings();
      if (settings != null && !settings.enabledBanks.contains(notificationData.bankName)) {
        return;
      }

      // Try Gemini AI parser first (if initialized) - with timeout
      GeminiParsedTransaction? geminiParsed;
      ParsedTransaction? parsedTransaction;
      
      if (GeminiNotificationParser.isAvailable) {
        try {
          // Add timeout to prevent hanging
          geminiParsed = await GeminiNotificationParser.parseWithAI(notificationData)
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  print('Gemini parsing timeout, using rule-based parser');
                  return null;
                },
              );
          
          if (geminiParsed != null) {
            // Convert GeminiParsedTransaction to ParsedTransaction
            parsedTransaction = ParsedTransaction(
              amount: geminiParsed.amount,
              currency: geminiParsed.currency,
              merchant: geminiParsed.merchant,
              type: geminiParsed.type,
              cardLastDigits: geminiParsed.cardLastDigits,
              bankName: geminiParsed.bankName,
              date: geminiParsed.date,
              rawTitle: geminiParsed.rawTitle,
              rawText: geminiParsed.rawText,
            );
          }
        } catch (e) {
          print('Gemini parsing failed, falling back to rule-based parser: $e');
          // Continue to rule-based parser
        }
      }

      // Fallback to rule-based parser
      if (parsedTransaction == null) {
        try {
          parsedTransaction = BankNotificationParser.parse(notificationData);
        } catch (e) {
          print('Rule-based parsing also failed: $e');
          return;
        }
      }

      if (parsedTransaction == null) {
        print('Failed to parse notification with both AI and rule-based parser');
        return;
      }

      // Suggest category (use AI suggestion if available and confidence is high, otherwise rule-based)
      String categoryId;
      try {
        if (geminiParsed != null && geminiParsed.confidence == 'high') {
          // Use AI-suggested category if confidence is high
          categoryId = _mapAICategoryToCategoryId(geminiParsed.suggestedCategory);
        } else {
          categoryId = BankNotificationParser.suggestCategory(parsedTransaction);
        }
      } catch (e) {
        print('Error suggesting category: $e');
        categoryId = 'other'; // Fallback to 'other' category
      }

      // Create transaction
      // Convert currency if needed (e.g., KZT to USD)
      double convertedAmount = parsedTransaction.amount;
      String displayCurrency = parsedTransaction.currency;
      
      // If notification currency is not USD, convert to USD
      if (parsedTransaction.currency.toUpperCase() != 'USD') {
        try {
          convertedAmount = CurrencyConversionService.convert(
            parsedTransaction.amount,
            parsedTransaction.currency,
            'USD',
          );
          displayCurrency = 'USD';
          print('Converted ${parsedTransaction.amount} ${parsedTransaction.currency} to $convertedAmount USD');
        } catch (e) {
          print('Currency conversion failed: $e');
          // Keep original amount if conversion fails
          convertedAmount = parsedTransaction.amount;
          displayCurrency = parsedTransaction.currency;
        }
      }
      
      final transaction = parsedTransaction.toTransactionModel(categoryId).copyWith(
        amount: convertedAmount,
        currency: displayCurrency,
        source: TransactionSource.notification,
        bankName: parsedTransaction.bankName,
        rawNotificationText: '${parsedTransaction.rawTitle}\n${parsedTransaction.rawText}',
      );

      // Try to merge with existing manual transaction
      try {
        final merged = await TransactionDeduplicationService.mergeWithNotification(transaction);
        if (merged) {
          // Successfully merged with existing transaction
          await NotificationPermissionService.updateLastSync();
          return;
        }
      } catch (e) {
        print('Error merging with existing transaction: $e');
        // Continue to create new transaction
      }

      // Check for exact duplicates
      try {
        final existingTransaction = await TransactionDeduplicationService.findDuplicate(transaction);
        if (existingTransaction != null) {
          // Update existing transaction instead of creating duplicate
          await _db.collection('transactions').doc(existingTransaction.id).update({
            'bankName': transaction.bankName,
            'rawNotificationText': transaction.rawNotificationText,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Add new transaction
          await _db.collection('transactions').add({
            'id': transaction.id,
            'title': transaction.title,
            'amount': transaction.amount,
            'date': transaction.date.toIso8601String(),
            'type': transaction.type.toString(),
            'categoryId': transaction.categoryId,
            'receiptImagePath': transaction.receiptImagePath,
            'notes': transaction.notes,
            'source': transaction.source.toString(),
            'bankName': transaction.bankName,
            'rawNotificationText': transaction.rawNotificationText,
            'currency': transaction.currency,
            'familyId': familyId,
            'createdBy': currentUserId,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        print('Error saving transaction to Firestore: $e');
        return;
      }

      // Update last sync timestamp
      try {
        await NotificationPermissionService.updateLastSync();
      } catch (e) {
        print('Error updating last sync: $e');
      }
    } catch (e) {
      print('Unexpected error in addTransactionFromNotification: $e');
      // Don't rethrow - we don't want to crash the app
    }
  }

  // Map AI category suggestions to our category IDs
  static String _mapAICategoryToCategoryId(String aiCategory) {
    final categoryMap = {
      'food': 'groceries',
      'transport': 'transport',
      'shopping': 'shopping',
      'entertainment': 'entertainment',
      'bills': 'utilities',
      'healthcare': 'healthcare',
      'education': 'education',
      'travel': 'travel',
      'other': 'other',
    };
    return categoryMap[aiCategory.toLowerCase()] ?? 'other';
  }

  // Get default categories
  static List<Category> getDefaultCategories() => defaultCategories;
  
  // === HELPER METHODS ===
  
  // Convert transaction from Firestore document
  static TransactionModel _transactionFromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return TransactionModel(
      id: data['id'] ?? doc.id,
      title: data['title'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.parse(data['date'] ?? DateTime.now().toIso8601String()),
      type: data['type']?.toString().contains('income') == true 
          ? TransactionType.income 
          : TransactionType.expense,
      categoryId: data['categoryId'] ?? 'other',
      receiptImagePath: data['receiptImagePath'],
      notes: data['notes'],
      currency: data['currency'] ?? 'USD',
    );
  }
  
  // Convert category from Firestore document
  static Category _categoryFromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Category(
      id: data['id'] ?? doc.id,
      name: data['name'] ?? '',
      icon: IconData(data['icon'] ?? 0, fontFamily: 'MaterialIcons'),
      type: data['type']?.toString().contains('income') == true 
          ? TransactionType.income 
          : TransactionType.expense,
      color: Color(data['color'] ?? 0xFFE53935),
    );
  }
}
