package com.example.family_budget_flutter

import android.app.Notification
import android.content.Context
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import org.json.JSONObject

class BankingNotificationListenerService : NotificationListenerService() {
    
    companion object {
        private const val TAG = "BankingNotification"
        private const val CHANNEL = "com.example.family_budget_flutter/notifications"
        const val ACTION_NOTIFICATION_DATA = "com.example.family_budget_flutter.NOTIFICATION_DATA"

        // Supported banking apps (package names)
        private val BANKING_APPS = setOf(
            // Sberbank
            "ru.sberbankmobile",
            // Tinkoff
            "com.idamob.tinkoff.android",
            // Alfa Bank
            "ru.alfabank.mobile.android",
            // VTB
            "com.vtb.mobilebanking",
            // Gazprombank
            "com.gazprombank.android",
            // Raiffeisen
            "com.raiffeisenrbank.mobile",
            // Otkritie
            "com.openbank",
            // Add more banks as needed
        )
    }
    
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        super.onNotificationPosted(sbn)
        
        try {
            val packageName = sbn.packageName
            
            // Check if notification is from a banking app
            if (!isBankingApp(packageName)) {
                return
            }
            
            val notification = sbn.notification
            val extras = notification.extras
            
            // Extract notification text
            val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
            val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
            val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""
            
            // Use big text if available, otherwise use regular text
            val fullText = if (bigText.isNotEmpty()) bigText else text
            
            Log.d(TAG, "Banking notification received: $packageName - $title - $fullText")
            
            // Parse and send to Flutter
            val parsedData = parseBankingNotification(packageName, title, fullText)
            if (parsedData != null) {
                sendToFlutter(parsedData)
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error processing notification", e)
        }
    }
    
    private fun isBankingApp(packageName: String): Boolean {
        return BANKING_APPS.contains(packageName)
    }
    
    private fun parseBankingNotification(packageName: String, title: String, text: String): JSONObject? {
        val data = JSONObject()
        
        try {
            data.put("packageName", packageName)
            data.put("title", title)
            data.put("text", text)
            data.put("timestamp", System.currentTimeMillis())
            
            // Detect bank name
            data.put("bankName", getBankName(packageName))
            
            // Parse transaction details
            val transactionData = parseTransactionDetails(packageName, title, text)
            if (transactionData != null) {
                data.put("amount", transactionData["amount"])
                data.put("currency", transactionData["currency"])
                data.put("merchant", transactionData["merchant"])
                data.put("type", transactionData["type"]) // "expense" or "income"
                data.put("cardLastDigits", transactionData["cardLastDigits"])
            }
            
            return data
            
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing notification", e)
            return null
        }
    }
    
    private fun parseTransactionDetails(packageName: String, title: String, text: String): Map<String, String>? {
        // This is a basic parser - you'll need to customize for each bank
        val result = mutableMapOf<String, String>()
        
        try {
            when (packageName) {
                "ru.sberbankmobile" -> parseSberbank(title, text, result)
                "com.idamob.tinkoff.android" -> parseTinkoff(title, text, result)
                "ru.alfabank.mobile.android" -> parseAlfa(title, text, result)
                else -> parseGeneric(title, text, result)
            }
            
            if (result.containsKey("amount")) {
                return result
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing transaction details", e)
        }
        
        return null
    }
    
    private fun parseSberbank(title: String, text: String, result: MutableMap<String, String>) {
        // Sberbank patterns:
        // "Покупка 5000.00 руб. Магазин"
        // "Выполнено: списание 1500.00 руб"
        
        val amountPattern = """(\d+[\.,]\d{2})\s*(руб|RUB)""".toRegex(RegexOption.IGNORE_CASE)
        val match = amountPattern.find(text) ?: amountPattern.find(title)
        
        match?.let {
            result["amount"] = it.groupValues[1].replace(",", ".")
            result["currency"] = "RUB"
        }
        
        // Extract merchant
        val merchantPattern = """(?:Покупка|списание|оплата)\s*[\d.,]+\s*(?:руб|RUB)?\s*(.+)""".toRegex(RegexOption.IGNORE_CASE)
        val merchantMatch = merchantPattern.find(text) ?: merchantPattern.find(title)
        
        merchantMatch?.let {
            result["merchant"] = it.groupValues[1].trim()
        }
        
        // Determine type
        if (text.contains("зачисление", ignoreCase = true) || title.contains("зачисление", ignoreCase = true)) {
            result["type"] = "income"
        } else {
            result["type"] = "expense"
        }
        
        // Extract card last digits
        val cardPattern = """\*?(\d{4})""".toRegex()
        val cardMatch = cardPattern.find(text) ?: cardPattern.find(title)
        cardMatch?.let {
            result["cardLastDigits"] = it.groupValues[1]
        }
    }
    
    private fun parseTinkoff(title: String, text: String, result: MutableMap<String, String>) {
        // Tinkoff patterns:
        // "Вы потратили 1500₽ в Starbucks"
        // "Поступление 5000₽"
        
        val amountPattern = """(\d+[\.,]?\d*)\s*₽""".toRegex(RegexOption.IGNORE_CASE)
        val match = amountPattern.find(text) ?: amountPattern.find(title)
        
        match?.let {
            result["amount"] = it.groupValues[1].replace(",", ".")
            result["currency"] = "RUB"
        }
        
        // Extract merchant
        val merchantPattern = """(?:потратили|оплатили)\s*[\d.,]+₽\s*(?:в|на)\s*(.+)""".toRegex(RegexOption.IGNORE_CASE)
        val merchantMatch = merchantPattern.find(text) ?: merchantPattern.find(title)
        
        merchantMatch?.let {
            result["merchant"] = it.groupValues[1].trim()
        }
        
        // Determine type
        if (text.contains("поступление", ignoreCase = true) || title.contains("поступление", ignoreCase = true) ||
            text.contains("зачисление", ignoreCase = true)) {
            result["type"] = "income"
        } else {
            result["type"] = "expense"
        }
        
        // Extract card last digits
        val cardPattern = """\*?(\d{4})""".toRegex()
        val cardMatch = cardPattern.find(text) ?: cardPattern.find(title)
        cardMatch?.let {
            result["cardLastDigits"] = it.groupValues[1]
        }
    }
    
    private fun parseAlfa(title: String, text: String, result: MutableMap<String, String>) {
        // Alfa Bank patterns:
        // "Оплата картой *1234 на 2300 руб"
        // "Зачисление 10000 руб"
        
        val amountPattern = """(\d+[\.,]\d{2})\s*руб""".toRegex(RegexOption.IGNORE_CASE)
        val match = amountPattern.find(text) ?: amountPattern.find(title)
        
        match?.let {
            result["amount"] = it.groupValues[1].replace(",", ".")
            result["currency"] = "RUB"
        }
        
        // Extract merchant
        val merchantPattern = """(?:оплата)\s*(?:карт\s*\*\d{4}\s*на\s*[\d.,]+\s*руб\s*)?(.+)""".toRegex(RegexOption.IGNORE_CASE)
        val merchantMatch = merchantPattern.find(text) ?: merchantPattern.find(title)
        
        merchantMatch?.let {
            result["merchant"] = it.groupValues[1].trim()
        }
        
        // Determine type
        if (text.contains("зачисление", ignoreCase = true) || title.contains("зачисление", ignoreCase = true)) {
            result["type"] = "income"
        } else {
            result["type"] = "expense"
        }
        
        // Extract card last digits
        val cardPattern = """\*?(\d{4})""".toRegex()
        val cardMatch = cardPattern.find(text) ?: cardPattern.find(title)
        cardMatch?.let {
            result["cardLastDigits"] = it.groupValues[1]
        }
    }
    
    private fun parseGeneric(title: String, text: String, result: MutableMap<String, String>) {
        // Generic parser for other banks
        val amountPattern = """(\d+[\.,]\d{2})\s*(?:руб|RUB|₽)""".toRegex(RegexOption.IGNORE_CASE)
        val match = amountPattern.find(text) ?: amountPattern.find(title)
        
        match?.let {
            result["amount"] = it.groupValues[1].replace(",", ".")
            result["currency"] = "RUB"
        }
        
        // Determine type
        val fullText = "$title $text"
        if (fullText.contains("зачисление", ignoreCase = true) || 
            fullText.contains("поступление", ignoreCase = true) ||
            fullText.contains("доход", ignoreCase = true)) {
            result["type"] = "income"
        } else {
            result["type"] = "expense"
        }
    }
    
    private fun getBankName(packageName: String): String {
        return when (packageName) {
            "ru.sberbankmobile" -> "Sberbank"
            "com.idamob.tinkoff.android" -> "Tinkoff"
            "ru.alfabank.mobile.android" -> "Alfa Bank"
            "com.vtb.mobilebanking" -> "VTB"
            "com.gazprombank.android" -> "Gazprombank"
            "com.raiffeisenrbank.mobile" -> "Raiffeisen"
            "com.openbank" -> "Otkritie"
            else -> "Unknown Bank"
        }
    }
    
    private fun sendToFlutter(data: JSONObject) {
        // This will be implemented via MethodChannel
        // For now, we'll use a broadcast that Flutter can listen to
        val intent = android.content.Intent(ACTION_NOTIFICATION_DATA)
        intent.putExtra("notificationData", data.toString())
        sendBroadcast(intent)
    }
}
