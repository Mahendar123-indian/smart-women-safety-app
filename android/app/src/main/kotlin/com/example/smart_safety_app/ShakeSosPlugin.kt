package com.example.smart_safety_app

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.*

/**
 * SHAKE SOS PLUGIN — 2026 INDUSTRIAL SENTINEL EDITION
 * 5-Layer intelligence system for high-accuracy background detection.
 */
class ShakeSosPlugin(private val context: Context) :
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    SensorEventListener {

    companion object {
        private const val TAG = "ShakeSosPlugin"
        private const val DEFAULT_PEAK_THRESHOLD = 28.0f   // m/s²
        private const val MIN_PEAK_THRESHOLD = 18.0f       // Safety floor
        private const val DEFAULT_MIN_SHAKES = 3           // Sequential peaks
        private const val DEFAULT_WINDOW_MS = 1800L        // Cluster window
        private const val COOLDOWN_MS = 25_000L            // Post-trigger silence
        private const val WAKELOCK_TAG = "SafeHer:ShakeSentinel"
        private const val JERK_THRESHOLD = 18.0f           // High jerk = intentional

        // Confidence Weights
        private const val WEIGHT_PATTERN = 0.40f
        private const val WEIGHT_PHYSICS = 0.30f
        private const val WEIGHT_CONTEXT = 0.30f

        // Final Thresholds
        private const val CONF_TRIGGER_ML = 0.72f
        private const val CONF_TRIGGER_OFFLINE = 0.85f
    }

    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var sensorMgr: SensorManager? = null
    private var accelSensor: Sensor? = null
    private var wakeLock: PowerManager.WakeLock? = null

    private var isListening = false
    private var isInCooldown = false

    // Configurable Parameters
    private var peakThreshold = DEFAULT_PEAK_THRESHOLD
    private var minShakes = DEFAULT_MIN_SHAKES
    private var windowMs = DEFAULT_WINDOW_MS
    private var mlDangerScore = 0.0f
    private var isNightTime = false

    // High-pass filter state
    private var gravX = 0f; private var gravY = 0f; private var gravZ = 0f
    private val ALPHA = 0.8f

    // History Buffers
    data class AccelSample(val filteredMag: Float, val jerk: Float, val timestamp: Long)
    private val sampleHistory = ArrayDeque<AccelSample>()
    private var lastMagnitude = 0f
    private var lastTimestamp = 0L

    data class ShakePeak(val magnitude: Float, val timestamp: Long, val jerk: Float, val direction: Int)
    private val peakHistory = ArrayDeque<ShakePeak>()

    // Baseline Tracking
    private val baselineWindow = ArrayDeque<Float>()
    private var baselineMean = 9.81f
    private var baselineVar = 0.5f

    // Reversal Tracking
    private var lastDirX = 0f; private var lastDirY = 0f; private var lastDirZ = 0f
    private var reversalCount = 0

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startListening" -> {
                val args = call.arguments as? Map<*, *>
                peakThreshold = (args?.get("threshold") as? Double)?.toFloat() ?: DEFAULT_PEAK_THRESHOLD
                minShakes = (args?.get("minShakes") as? Int) ?: DEFAULT_MIN_SHAKES
                windowMs = (args?.get("windowMs") as? Int)?.toLong() ?: DEFAULT_WINDOW_MS
                mlDangerScore = (args?.get("mlDangerScore") as? Double)?.toFloat() ?: 0.0f
                isNightTime = (args?.get("isNightTime") as? Boolean) ?: false
                startShakeDetection()
                result.success(true)
            }
            "stopListening" -> {
                stopShakeDetection()
                result.success(true)
            }
            "updateDangerScore" -> {
                mlDangerScore = (call.arguments as? Double)?.toFloat() ?: 0.0f
                result.success(true)
            }
            "isAvailable" -> {
                val sm = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
                result.success(sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null)
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

    fun startShakeDetection() {
        if (isListening) return
        sensorMgr = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelSensor = sensorMgr?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

        if (accelSensor != null) {
            sensorMgr?.registerListener(this, accelSensor, SensorManager.SENSOR_DELAY_GAME)
            isListening = true
            acquireWakeLock()
            sendStatus("listening", "Hardware Sentinel Active")
        }
    }

    fun stopShakeDetection() {
        isListening = false
        sensorMgr?.unregisterListener(this)
        releaseWakeLock()
        sampleHistory.clear()
        peakHistory.clear()
        sendStatus("stopped", "Hardware Sentinel Offline")
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (!isListening || isInCooldown) return
        val now = System.currentTimeMillis()

        // 1. High-Pass Filter (Gravity Removal)
        gravX = ALPHA * gravX + (1f - ALPHA) * event.values[0]
        gravY = ALPHA * gravY + (1f - ALPHA) * event.values[1]
        gravZ = ALPHA * gravZ + (1f - ALPHA) * event.values[2]

        val hpX = event.values[0] - gravX
        val hpY = event.values[1] - gravY
        val hpZ = event.values[2] - gravZ

        val filteredMag = sqrt((hpX * hpX + hpY * hpY + hpZ * hpZ).toDouble()).toFloat()

        // 2. Jerk Computation
        val dt = if (lastTimestamp > 0) (now - lastTimestamp) / 1000f else 0.02f
        val jerk = if (dt > 0) abs(filteredMag - lastMagnitude) / dt else 0f
        lastMagnitude = filteredMag
        lastTimestamp = now

        // 3. Reversal Detection
        val dirX = if (hpX > 0.5f) 1f else if (hpX < -0.5f) -1f else 0f
        if (lastDirX != 0f && dirX != 0f && dirX != lastDirX) reversalCount++
        lastDirX = if (dirX != 0f) dirX else lastDirX

        // 4. Peak Validation
        val dynamicThreshold = (baselineMean * 0.1f + peakThreshold).coerceAtLeast(MIN_PEAK_THRESHOLD)
        if (filteredMag >= dynamicThreshold && jerk >= JERK_THRESHOLD) {
            val lastPeakTime = peakHistory.lastOrNull()?.timestamp ?: 0L
            if (now - lastPeakTime > 180) { // Debounce peaks
                peakHistory.addLast(ShakePeak(filteredMag, now, jerk, 1))
            }
        }

        // Window Maintenance
        while (peakHistory.isNotEmpty() && now - peakHistory.first().timestamp > windowMs) {
            peakHistory.removeFirst()
        }

        // 5. Intelligence Handshake
        if (peakHistory.size >= minShakes) {
            analyzeSignature(now)
        }
    }

    private fun analyzeSignature(now: Long) {
        val patternConf = computePatternConfidence()
        val physicsConf = computePhysicsConfidence()
        val contextConf = computeContextConfidence()

        val totalConf = (patternConf * WEIGHT_PATTERN + physicsConf * WEIGHT_PHYSICS + contextConf * WEIGHT_CONTEXT)

        // Dynamic Thresholding
        val baseThreshold = if (mlDangerScore > 0.1) CONF_TRIGGER_ML else CONF_TRIGGER_OFFLINE
        val adjustedThreshold = if (isNightTime) baseThreshold - 0.08f else baseThreshold

        if (totalConf >= adjustedThreshold) {
            executeTrigger(totalConf, now)
        } else {
            sendEvent(mapOf("type" to "shake_candidate", "confidence" to totalConf))
        }
    }

    private fun computePatternConfidence(): Float {
        if (peakHistory.size < 2) return 0f
        val span = peakHistory.last().timestamp - peakHistory.first().timestamp
        val density = peakHistory.size.toFloat() / (span.coerceAtLeast(1).toFloat() / 1000f)
        val reversalScore = (reversalCount / 10f).coerceIn(0f, 1f)
        return ((density / 5f) + reversalScore) / 2f
    }

    private fun computePhysicsConfidence(): Float {
        val avgPeak = peakHistory.map { it.magnitude }.average().toFloat()
        return (avgPeak / 50f).coerceIn(0f, 1f)
    }

    private fun computeContextConfidence(): Float {
        var score = 0.5f
        if (mlDangerScore > 0.05f) score += (mlDangerScore * 0.4f)
        if (isNightTime) score += 0.1f
        return score.coerceIn(0f, 1f)
    }

    private fun executeTrigger(conf: Float, now: Long) {
        isInCooldown = true
        sendEvent(mapOf(
            "type" to "shake_detected",
            "confidence" to conf,
            "shakeCount" to peakHistory.size,
            "timestamp" to now
        ))
        peakHistory.clear()
        mainHandler.postDelayed({ isInCooldown = false }, COOLDOWN_MS)
    }

    private fun acquireWakeLock() {
        if (wakeLock == null) {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, WAKELOCK_TAG)
        }
        wakeLock?.acquire(10 * 60 * 1000L)
    }

    private fun releaseWakeLock() {
        if (wakeLock?.isHeld == true) wakeLock?.release()
    }

    private fun sendEvent(data: Map<String, Any>) {
        mainHandler.post { eventSink?.success(data) }
    }

    private fun sendStatus(status: String, msg: String) {
        sendEvent(mapOf("type" to "status", "status" to status, "message" to msg))
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
}