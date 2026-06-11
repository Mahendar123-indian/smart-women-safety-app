package com.example.smart_safety_app

import android.os.Bundle
import android.util.Log
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * MAIN ACTIVITY — 2026 INDUSTRIAL SENTINEL MASTER CONTROLLER
 * Orchestrates the bridge between Native Hardware Triggers and Flutter logic.
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "MainActivity"

        // Channel Definitions — Synchronized with lib/core/services/
        private const val VOICE_METHOD_CHANNEL  = "com.safeher/voice_sos"
        private const val VOICE_EVENT_CHANNEL   = "com.safeher/voice_sos_events"
        private const val HW_METHOD_CHANNEL     = "com.safeher/hardware_sos"
        private const val HW_EVENT_CHANNEL      = "com.safeher/hardware_sos_events"
        private const val SHAKE_METHOD_CHANNEL  = "com.safeher/shake_sos"
        private const val SHAKE_EVENT_CHANNEL   = "com.safeher/shake_sos_events"
    }

    // Native Sentinel Plugin Instances
    private lateinit var voicePlugin:    VoiceSosPlugin
    private lateinit var hardwarePlugin: HardwareSosPlugin
    private lateinit var shakePlugin:    ShakeSosPlugin

    // Channel References for Secure Cleanup
    private var voiceMethodChannel:    MethodChannel? = null
    private var voiceEventChannel:     EventChannel?  = null
    private var hardwareMethodChannel: MethodChannel? = null
    private var hardwareEventChannel:  EventChannel?  = null
    private var shakeMethodChannel:    MethodChannel? = null
    private var shakeEventChannel:     EventChannel?  = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        Log.d(TAG, "🛡️ Initializing Sentinel Native Bridge...")

        // 1. Initialize Native Industrial Kernels
        voicePlugin    = VoiceSosPlugin(applicationContext)
        hardwarePlugin = HardwareSosPlugin(applicationContext)
        shakePlugin    = ShakeSosPlugin(applicationContext)

        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // 2. Register ACOUSTIC SENTINEL (Voice)
        voiceMethodChannel = MethodChannel(messenger, VOICE_METHOD_CHANNEL).also {
            it.setMethodCallHandler(voicePlugin)
        }
        voiceEventChannel = EventChannel(messenger, VOICE_EVENT_CHANNEL).also {
            it.setStreamHandler(voicePlugin)
        }

        // 3. Register TACTICAL INTERRUPT (Hardware Buttons)
        hardwareMethodChannel = MethodChannel(messenger, HW_METHOD_CHANNEL).also {
            it.setMethodCallHandler(hardwarePlugin)
        }
        hardwareEventChannel = EventChannel(messenger, HW_EVENT_CHANNEL).also {
            it.setStreamHandler(hardwarePlugin)
        }

        // 4. Register KINETIC SENSOR (5-Layer Shake Detection)
        shakeMethodChannel = MethodChannel(messenger, SHAKE_METHOD_CHANNEL).also {
            it.setMethodCallHandler(shakePlugin)
        }
        shakeEventChannel = EventChannel(messenger, SHAKE_EVENT_CHANNEL).also {
            it.setStreamHandler(shakePlugin)
        }

        Log.d(TAG, "✅ All 6 Sentinel Channels Online")
    }

    /**
     * TACTICAL KEY INTERCEPTION
     * Routes Volume and Earphone pulses directly to the HardwarePlugin.
     * Consuming the event (returning true) hides the system volume UI during SOS hold.
     */
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (::hardwarePlugin.isInitialized) {
            // hardwarePlugin.handleKeyEvent returns true if it's a Volume Down or Media key
            // This prevents the Volume Slider from popping up on screen.
            if (hardwarePlugin.handleKeyEvent(event)) {
                return true
            }
        }
        return super.dispatchKeyEvent(event)
    }

    // --- LIFECYCLE MANAGEMENT ---

    override fun onPause() {
        super.onPause()
        Log.d(TAG, "Sentinel: Background Mode Engaged")
    }

    override fun onDestroy() {
        Log.d(TAG, "Sentinel: Secure Shutdown...")

        // 1. Detach Handlers to prevent memory leaks
        voiceMethodChannel?.setMethodCallHandler(null)
        voiceEventChannel?.setStreamHandler(null)

        hardwareMethodChannel?.setMethodCallHandler(null)
        hardwareEventChannel?.setStreamHandler(null)

        shakeMethodChannel?.setMethodCallHandler(null)
        shakeEventChannel?.setStreamHandler(null)

        // 2. Dispose Kernels safely using methods guaranteed to exist in your plugins
        if (::voicePlugin.isInitialized) {
            voicePlugin.stopVoiceRecognition()
        }

        if (::hardwarePlugin.isInitialized) {
            // HardwareSosPlugin has destroy() defined in your code
            hardwarePlugin.destroy()
        }

        if (::shakePlugin.isInitialized) {
            shakePlugin.stopShakeDetection()
        }

        super.onDestroy()
    }
}