package com.example.family_budget_flutter

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class NotificationListenerPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var context: Context? = null
    private var broadcastReceiver: NotificationBroadcastReceiver? = null

    companion object {
        private const val TAG = "NotificationPlugin"
        private const val METHOD_CHANNEL = "com.example.family_budget_flutter/notifications"
        private const val EVENT_CHANNEL = "com.example.family_budget_flutter/notification_events"
        const val ACTION_NOTIFICATION_DATA = "com.example.family_budget_flutter.NOTIFICATION_DATA"
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                registerBroadcastReceiver()
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
                unregisterBroadcastReceiver()
            }
        })
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "isPermissionGranted" -> {
                result.success(isNotificationListenerPermissionGranted())
            }
            "openPermissionSettings" -> {
                openNotificationListenerSettings()
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        unregisterBroadcastReceiver()
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        context = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        // No-op
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        context = binding.activity
    }

    override fun onDetachedFromActivity() {
        context = null
    }

    private fun isNotificationListenerPermissionGranted(): Boolean {
        val context = context ?: return false

        return try {
            val enabledListeners = Settings.Secure.getString(
                context.contentResolver,
                "enabled_notification_listeners"
            )
            enabledListeners?.contains(context.packageName) == true
        } catch (e: Exception) {
            Log.e(TAG, "Error checking permission", e)
            false
        }
    }

    private fun openNotificationListenerSettings() {
        val context = context ?: return
        
        try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
            } else {
                Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Error opening settings", e)
        }
    }

    private fun registerBroadcastReceiver() {
        if (broadcastReceiver != null) return

        broadcastReceiver = NotificationBroadcastReceiver { data ->
            eventSink?.success(data)
        }

        val context = context ?: return
        val intentFilter = android.content.IntentFilter(ACTION_NOTIFICATION_DATA)
        context.registerReceiver(broadcastReceiver, intentFilter)
    }

    private fun unregisterBroadcastReceiver() {
        if (broadcastReceiver != null) {
            try {
                context?.unregisterReceiver(broadcastReceiver)
            } catch (e: Exception) {
                Log.e(TAG, "Error unregistering receiver", e)
            }
            broadcastReceiver = null
        }
    }
}

class NotificationBroadcastReceiver(private val onDataReceived: (String) -> Unit) : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == NotificationListenerPlugin.ACTION_NOTIFICATION_DATA) {
            val data = intent.getStringExtra("notificationData")
            if (data != null) {
                onDataReceived(data)
            }
        }
    }
}
