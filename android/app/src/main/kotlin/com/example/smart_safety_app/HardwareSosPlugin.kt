package com.example.smart_safety_app

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.KeyEvent
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * HARDWARE SOS PLUGIN — 2026 INDUSTRIAL SENTINEL EDITION
 * Intercepts physical hardware interrupts (Volume/Headset) for silent SOS.
 * Precision engineered for zero-latency background triggering.
 */
class HardwareSosPlugin(private val context: Context) :
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    companion object {
        private const val TAG = "HardwareSosPlugin"
        private const val PROGRESS_INTERVAL_MS = 100L
        private const val EARPHONE_WINDOW_MS = 800L
        private const val COOLDOWN_MS = 25_000L // 25s Cooldown to prevent spam
    }

    private var eventSink: EventChannel.EventSink? = null
    // Ensure all Flutter communication happens on the Main UI Thread
    private val mainHandler = Handler(Looper.getMainLooper())

    private var isListening = false
    private var isInCooldown = false
    private var volumeEnabled = true
    private var earphoneEnabled = true
    private var volumeHoldMs = 3000L

    private var isVolumeDownHeld = false
    private var volumeDownStartTime = 0L
    private var volumeProgressTimer: Runnable? = null

    private var earphonePressCount = 0
    private var earphoneResetTimer: Runnable? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startListening" -> {
                val args = call.arguments as? Map<*, *>
                volumeEnabled = (args?.get("volumeEnabled") as? Boolean) ?: true
                earphoneEnabled = (args?.get("earphoneEnabled") as? Boolean) ?: true
                volumeHoldMs = (args?.get("volumeHoldMs") as? Int)?.toLong() ?: 3000L
                isListening = true
                Log.d(TAG, "🛡️ Hardware Sentinel: Online (Hold: ${volumeHoldMs}ms)")
                sendStatus("listening")
                result.success(true)
            }
            "stopListening" -> {
                stopListening()
                result.success(true)
            }
            "updateConfig" -> {
                val args = call.arguments as? Map<*, *>
                volumeHoldMs = (args?.get("volumeHoldMs") as? Int)?.toLong() ?: volumeHoldMs
                result.success(true)
            }
            "testTrigger" -> {
                triggerHardwareSos("internal_test_manual")
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    /**
     * CORE TACTICAL INTERCEPTOR
     * Called from MainActivity.dispatchKeyEvent to capture hardware pulses.
     * Returning true hides the Volume UI and stops native button actions.
     */
    fun handleKeyEvent(event: KeyEvent): Boolean {
        if (!isListening || isInCooldown) return false

        return when (event.keyCode) {
            KeyEvent.KEYCODE_VOLUME_DOWN -> {
                if (!volumeEnabled) return false
                handleVolumeKey(event)
            }
            KeyEvent.KEYCODE_HEADSETHOOK,
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE -> {
                if (!earphoneEnabled) return false
                if (event.action == KeyEvent.ACTION_DOWN) handleEarphonePress()
                // Consume media keys to prevent music skipping/playing during an attack
                true
            }
            else -> false
        }
    }

    private fun handleVolumeKey(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_DOWN) {
            if (!isVolumeDownHeld) {
                isVolumeDownHeld = true
                volumeDownStartTime = System.currentTimeMillis()
                sendEvent(mapOf("type" to "volume_down_start"))
                startHoldTimer()
            }
            // ⚡ CRITICAL: Hides the Android System Volume Slider UI
            return true
        } else if (event.action == KeyEvent.ACTION_UP) {
            isVolumeDownHeld = false
            stopHoldTimer()
            sendEvent(mapOf("type" to "volume_down_end"))
            return true
        }
        return false
    }

    private fun startHoldTimer() {
        stopHoldTimer()
        var elapsed = 0L

        volumeProgressTimer = object : Runnable {
            override fun run() {
                if (!isVolumeDownHeld) return
                elapsed += PROGRESS_INTERVAL_MS

                // Send 0.0 - 1.0 progress to Flutter for the pulse animation UI
                sendEvent(mapOf(
                    "type" to "arming",
                    "triggerType" to "volume_hold",
                    "progress" to (elapsed.toFloat() / volumeHoldMs.toFloat()).coerceIn(0f, 1f)
                ))

                if (elapsed >= volumeHoldMs) {
                    isVolumeDownHeld = false
                    triggerHardwareSos("volume_down_long_press")
                } else {
                    mainHandler.postDelayed(this, PROGRESS_INTERVAL_MS)
                }
            }
        }
        mainHandler.postDelayed(volumeProgressTimer!!, PROGRESS_INTERVAL_MS)
    }

    private fun stopHoldTimer() {
        volumeProgressTimer?.let { mainHandler.removeCallbacks(it) }
        volumeProgressTimer = null
    }

    private fun handleEarphonePress() {
        earphonePressCount++
        earphoneResetTimer?.let { mainHandler.removeCallbacks(it) }

        earphoneResetTimer = Runnable {
            val count = earphonePressCount
            earphonePressCount = 0
            if (count >= 3) {
                triggerHardwareSos("earphone_triple_click")
            } else if (count == 2) {
                triggerHardwareSos("earphone_double_click")
            }
        }
        mainHandler.postDelayed(earphoneResetTimer!!, EARPHONE_WINDOW_MS)
    }

    private fun triggerHardwareSos(method: String) {
        if (isInCooldown) return
        isInCooldown = true

        Log.w(TAG, "🚨 [SENTINEL] Hardware SOS Triggered via: $method")

        // 'volume_down_long' is the master key expected by Flutter SosProvider
        sendEvent(mapOf(
            "type" to "volume_down_long",
            "triggerType" to method,
            "timestamp" to System.currentTimeMillis()
        ))

        // Auto-reset cooldown to allow subsequent triggers if danger continues
        mainHandler.postDelayed({ isInCooldown = false }, COOLDOWN_MS)
    }

    private fun stopListening() {
        isListening = false
        isVolumeDownHeld = false
        stopHoldTimer()
        earphonePressCount = 0
        earphoneResetTimer?.let { mainHandler.removeCallbacks(it) }
        sendStatus("stopped")
    }

    private fun sendEvent(data: Map<String, Any>) {
        // Safe dispatch to the main thread UI isolate
        mainHandler.post {
            try {
                eventSink?.success(data)
            } catch (e: Exception) {
                Log.e(TAG, "Event Sink Error: ${e.message}")
            }
        }
    }

    private fun sendStatus(status: String) {
        sendEvent(mapOf("type" to "status", "status" to status))
    }

    /**
     * INDUSTRIAL CLEANUP
     * Releases memory and prevents background thread leaks when app is destroyed.
     */
    fun destroy() {
        Log.d(TAG, "Hardware Sentinel: Secure Disposing...")
        stopListening()
        mainHandler.removeCallbacksAndMessages(null)
        eventSink = null
    }
}