package com.example.smart_safety_app

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/**
 * VOICE SOS PLUGIN — 2026 INDUSTRIAL SENTINEL EDITION
 * Silent background listening with multi-language keyword support.
 */
class VoiceSosPlugin(private val context: Context) :
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    companion object {
        private const val TAG = "VoiceSosPlugin"
        private const val WAKELOCK_TAG = "SafeHer:VoiceSentinel"
        private const val MUTE_DURATION_MS = 350L // Covers mic chime window
        private const val RESTART_DELAY_MS = 1000L
        private const val MAX_RESTART_ATTEMPTS = 15

        private val DEFAULT_KEYWORDS = listOf(
            "help", "help me", "save me", "danger", "emergency", "stop it",
            "bachao", "madad karo", "chhodo", "chhod do", "police bulao",
            "help cheyyi", "vaddu", "utavi", "kaapaatru"
        )
    }

    private var speechRecognizer: SpeechRecognizer? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var wakeLock: PowerManager.WakeLock? = null

    private var isListening = false
    private var shouldRestart = false
    private var restartAttempts = 0
    private var sensitivity = 0.6
    private var activeKeywords = DEFAULT_KEYWORDS.toMutableList()

    private var savedSystemVolume = -1
    private var isMuted = false

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startListening" -> {
                val args = call.arguments as? Map<*, *>
                sensitivity = (args?.get("sensitivity") as? Double) ?: 0.6
                val kwList = args?.get("keywords") as? List<String>
                if (!kwList.isNullOrEmpty()) activeKeywords = kwList.toMutableList()
                startVoiceRecognition()
                result.success(true)
            }
            "stopListening" -> {
                stopVoiceRecognition()
                result.success(true)
            }
            "isAvailable" -> {
                result.success(SpeechRecognizer.isRecognitionAvailable(context))
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

    fun startVoiceRecognition() {
        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            sendStatus("error", "Speech recognition unavailable")
            return
        }
        shouldRestart = true
        restartAttempts = 0
        acquireWakeLock()
        silentStartSequence()
    }

    /**
     * Stealth Start Sequence:
     * Mutes STREAM_SYSTEM to prevent the "Tidm" mic-access sound.
     */
    private fun silentStartSequence() {
        mainHandler.post {
            muteSystemSounds()

            try {
                speechRecognizer?.destroy()
                speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context).apply {
                    setRecognitionListener(recognitionListener)
                }

                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    // Increase silence thresholds for industrial stability
                    putExtra("android.speech.extra.SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS", 8000L)
                    putExtra("android.speech.extra.SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS", 5000L)
                }

                speechRecognizer?.startListening(intent)
                isListening = true
                Log.d(TAG, "🎙️ Sentinel Listening...")
            } catch (e: Exception) {
                Log.e(TAG, "Start Error: ${e.message}")
                restoreSystemSounds()
                scheduleRestart()
            }

            // Restore volume after the chime window has passed
            mainHandler.postDelayed({ restoreSystemSounds() }, MUTE_DURATION_MS)
        }
    }

    private fun muteSystemSounds() {
        if (isMuted) return
        try {
            savedSystemVolume = audioManager.getStreamVolume(AudioManager.STREAM_SYSTEM)
            audioManager.setStreamVolume(AudioManager.STREAM_SYSTEM, 0, 0)
            isMuted = true
        } catch (e: Exception) { Log.w(TAG, "Mute failed: $e") }
    }

    private fun restoreSystemSounds() {
        if (!isMuted) return
        try {
            if (savedSystemVolume >= 0) {
                audioManager.setStreamVolume(AudioManager.STREAM_SYSTEM, savedSystemVolume, 0)
            }
        } catch (e: Exception) { Log.w(TAG, "Restore failed: $e") }
        finally { isMuted = false; savedSystemVolume = -1 }
    }

    fun stopVoiceRecognition() {
        shouldRestart = false
        isListening = false
        mainHandler.removeCallbacksAndMessages(null)
        restoreSystemSounds()

        mainHandler.post {
            speechRecognizer?.cancel()
            speechRecognizer?.destroy()
            speechRecognizer = null
        }
        releaseWakeLock()
        sendStatus("stopped", "Sentinel Offline")
    }

    private val recognitionListener = object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) { restartAttempts = 0 }
        override fun onBeginningOfSpeech() {}
        override fun onRmsChanged(rmsdB: Float) {}
        override fun onBufferReceived(buffer: ByteArray?) {}
        override fun onEndOfSpeech() {}

        override fun onError(error: Int) {
            isListening = false
            val isTimeout = error == SpeechRecognizer.ERROR_NO_MATCH || error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT

            if (!isTimeout) restartAttempts++

            if (shouldRestart && restartAttempts < MAX_RESTART_ATTEMPTS) {
                val delay = if (isTimeout) 200L else RESTART_DELAY_MS
                scheduleRestart(delay)
            }
        }

        override fun onResults(results: Bundle?) {
            isListening = false
            val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION) ?: return
            val scores = results.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)

            processText(matches, scores)
            if (shouldRestart) scheduleRestart(200L)
        }

        override fun onPartialResults(partialResults: Bundle?) {
            val partial = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION) ?: return
            processText(partial, null, isPartial = true)
        }

        override fun onEvent(eventType: Int, params: Bundle?) {}
        override fun onSegmentResults(segmentResults: Bundle) {}
        override fun onEndOfSegmentedSession() {}
    }

    private fun processText(transcripts: List<String>, confidences: FloatArray?, isPartial: Boolean = false) {
        for ((i, text) in transcripts.withIndex()) {
            val normalized = text.lowercase().trim()
            val conf = confidences?.getOrNull(i)?.toDouble() ?: 0.75

            for (keyword in activeKeywords) {
                if (normalized.contains(keyword.lowercase())) {
                    if (conf >= sensitivity || isPartial) {
                        Log.w(TAG, "🚨 KEYWORD DETECTED: $keyword")
                        triggerSignal(keyword, conf, text)
                        return
                    }
                }
            }
        }
    }

    private fun scheduleRestart(delay: Long = RESTART_DELAY_MS) {
        if (!shouldRestart) return
        mainHandler.postDelayed({
            if (shouldRestart && !isListening) silentStartSequence()
        }, delay)
    }

    private fun triggerSignal(kw: String, conf: Double, fullText: String) {
        mainHandler.post {
            eventSink?.success(mapOf(
                "type" to "keyword_detected",
                "keyword" to kw,
                "confidence" to conf,
                "transcript" to fullText,
                "timestamp" to System.currentTimeMillis()
            ))
        }
    }

    private fun sendStatus(status: String, msg: String) {
        mainHandler.post {
            eventSink?.success(mapOf("type" to "status", "status" to status, "message" to msg))
        }
    }

    private fun acquireWakeLock() {
        if (wakeLock == null) {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, WAKELOCK_TAG)
        }
        if (wakeLock?.isHeld == false) wakeLock?.acquire(2 * 60 * 60 * 1000L)
    }

    private fun releaseWakeLock() {
        if (wakeLock?.isHeld == true) wakeLock?.release()
    }

    fun destroy() {
        stopVoiceRecognition()
        mainHandler.removeCallbacksAndMessages(null)
    }
}