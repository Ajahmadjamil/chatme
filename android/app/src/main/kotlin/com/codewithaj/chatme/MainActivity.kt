package com.codewithaj.chatme

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.os.PowerManager
import android.util.Log
import android.view.WindowManager
import androidx.core.content.ContextCompat
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "chat_shortcut"
    private var channel: MethodChannel? = null

    // Chat data received when the app is opened from a shortcut
    private var pendingChat: Map<String, Any?>? = null

    // Turns the screen off when the phone is held to the ear (audio calls)
    private var proximityLock: PowerManager.WakeLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Things a call needs from Android itself (see CallDeviceService.dart)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "chatme/call_device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startCallService" -> result.success(
                        startCallService(
                            call.argument<String>("title"),
                            call.argument<String>("text"),
                            call.argument<Boolean>("video") ?: false,
                        )
                    )
                    "stopCallService" -> {
                        stopService(Intent(this, CallForegroundService::class.java))
                        result.success(null)
                    }
                    "keepScreenOn" -> {
                        if (call.argument<Boolean>("on") == true) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        result.success(null)
                    }
                    "proximityScreenOff" -> {
                        setProximityScreenOff(call.argument<Boolean>("on") == true)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        pendingChat = readChatFromIntent(intent)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                // Dart asks: create a shortcut on the home screen
                "pinShortcut" -> {
                    val chatId = call.argument<String>("chatId")!!
                    val name = call.argument<String>("name")!!
                    val isGroup = call.argument<Boolean>("isGroup") ?: false
                    result.success(pinShortcut(chatId, name, isGroup))
                }
                // Dart asks: was the app opened from a shortcut?
                "getInitialChat" -> {
                    result.success(pendingChat)
                    pendingChat = null
                }
                else -> result.notImplemented()
            }
        }
    }

    // App is already running and the user taps a shortcut
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val chat = readChatFromIntent(intent)
        if (chat != null) channel?.invokeMethod("onShortcutTapped", chat)
    }

    // Reads chat info stored inside the shortcut intent
    private fun readChatFromIntent(intent: Intent?): Map<String, Any?>? {
        val chatId = intent?.getStringExtra("chat_id") ?: return null
        return mapOf(
            "chatId" to chatId,
            "name" to (intent.getStringExtra("chat_name") ?: ""),
            "isGroup" to intent.getBooleanExtra("is_group", false)
        )
    }

    private fun pinShortcut(chatId: String, name: String, isGroup: Boolean): Boolean {
        if (!ShortcutManagerCompat.isRequestPinShortcutSupported(this)) return false

        // This intent runs when the shortcut is tapped
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW // action is required for shortcuts
            putExtra("chat_id", chatId)
            putExtra("chat_name", name)
            putExtra("is_group", isGroup)
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }

        val shortcut = ShortcutInfoCompat.Builder(this, "chat_$chatId")
            .setShortLabel(name)
            .setLongLabel(name)
            .setIcon(IconCompat.createWithBitmap(buildAvatar(name)))
            .setIntent(launchIntent)
            .build()

        return ShortcutManagerCompat.requestPinShortcut(this, shortcut, null)
    }

    // Round green icon with the first letter of the name
    private fun buildAvatar(name: String): Bitmap {
        val size = 192
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val circle = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#075E54") }
        canvas.drawCircle(size / 2f, size / 2f, size / 2f, circle)

        val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = 96f
            textAlign = Paint.Align.CENTER
        }
        val y = size / 2f - (text.descent() + text.ascent()) / 2
        canvas.drawText(name.take(1).uppercase(), size / 2f, y, text)
        return bitmap
    }

    // ---- Calls ----

    private fun startCallService(title: String?, text: String?, video: Boolean): Boolean {
        val intent = Intent(this, CallForegroundService::class.java).apply {
            putExtra(CallForegroundService.EXTRA_TITLE, title)
            putExtra(CallForegroundService.EXTRA_TEXT, text)
            putExtra(CallForegroundService.EXTRA_VIDEO, video)
        }
        return try {
            ContextCompat.startForegroundService(this, intent)
            true
        } catch (e: Exception) {
            Log.w("MainActivity", "Call service not started: $e")
            false
        }
    }

    private fun setProximityScreenOff(on: Boolean) {
        if (!on) {
            proximityLock?.let { if (it.isHeld) it.release() }
            return
        }
        if (proximityLock?.isHeld == true) return

        val power = getSystemService(Context.POWER_SERVICE) as PowerManager
        if (!power.isWakeLockLevelSupported(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK)) return
        proximityLock = power.newWakeLock(
            PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK,
            "chatme:call_proximity"
        ).apply {
            setReferenceCounted(false)
            acquire(4 * 60 * 60 * 1000L) // safety limit; released when the call ends
        }
    }

    override fun onDestroy() {
        setProximityScreenOff(false)
        super.onDestroy()
    }
}