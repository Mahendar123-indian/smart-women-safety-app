// lib/core/services/shake_detector.dart
// ─────────────────────────────────────────────────────────────────────────────
// INDUSTRIAL SHAKE DETECTOR — v5.0 (2026 SENTINEL EDITION)
// ─────────────────────────────────────────────────────────────────────────────
// ⚠️ WARNING: Ensure you are NOT using `shake_sos_service.dart` at the same
// time, as they compete for the exact same Native Kotlin EventChannels.
// ─────────────────────────────────────────────────────────────────────────────
// ✅ [FIXED] StreamController Crash: Guarded stream additions against closed states.
// ✅ [FIXED] Singleton Leaks: Added _initCalled and _isDisposed lifecycle guards.
// ✅ [ADDED] setEnabled: Added missing toggle for the settings screen.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Data object representing a verified emergency shake event.
class ShakeTriggerEvent {
  final double confidence;
  final double magnitude;
  final int shakeCount;
  final DateTime timestamp;

  ShakeTriggerEvent({
    required this.confidence,
    required this.magnitude,
    required this.shakeCount,
    required this.timestamp,
  });
}

class ShakeDetector extends ChangeNotifier {
  ShakeDetector._();
  static final ShakeDetector instance = ShakeDetector._();

  // ── Channels (Must match MainActivity.kt) ──────────────────────────
  static const _methodChannel = MethodChannel('com.safeher/shake_sos');
  static const _eventChannel  = EventChannel('com.safeher/shake_sos_events');

  // ── State ───────────────────────────────────────────────────────────
  bool _isServiceRunning = false;
  bool _isEnabled = true;
  double _sensitivity = 0.5; // 0.0 (Hard) to 1.0 (Easy)

  // Lifecycle Guards
  bool _initCalled = false;
  bool _isDisposed = false;

  StreamSubscription? _nativeEventSub;

  // Broadcast stream for the UI/Provider to listen to
  final _shakeStreamCtrl = StreamController<ShakeTriggerEvent>.broadcast();
  Stream<ShakeTriggerEvent> get onShake => _shakeStreamCtrl.stream;

  // ── Getters ─────────────────────────────────────────────────────────
  bool get isRunning => _isServiceRunning;
  bool get isEnabled => _isEnabled;
  double get sensitivity => _sensitivity;

  /// Maps 0.0-1.0 slider to actual m/s² thresholds for the Native Kernel.
  double get _computedThreshold => 40.0 - (_sensitivity * 24.0);

  // ═══════════════════════════════════════════════════════════════
  // INITIALIZATION & LIFECYCLE
  // ═══════════════════════════════════════════════════════════════

  Future<void> init() async {
    if (_initCalled || _isDisposed) return;
    _initCalled = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool('shake_sos_enabled') ?? true;
      _sensitivity = prefs.getDouble('shake_sos_sensitivity') ?? 0.5;

      // Attach to the Native 5-Layer Physics Engine
      _nativeEventSub?.cancel();
      _nativeEventSub = _eventChannel.receiveBroadcastStream().listen(
        _handleNativeSignal,
        onError: (e) => debugPrint('⚠️ [SHAKE DETECTOR] Native Stream Error: $e'),
      );

      if (_isEnabled) {
        await start();
      }
      debugPrint('🛡️ [SHAKE DETECTOR] Sentinel Bridge Online');
    } catch (e) {
      debugPrint('❌ [SHAKE DETECTOR] Init Error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // CONTROL LOGIC
  // ═══════════════════════════════════════════════════════════════

  Future<void> start() async {
    if (_isServiceRunning || _isDisposed) return;
    try {
      await _methodChannel.invokeMethod('startListening', {
        'threshold': _computedThreshold,
        'minShakes': 3,
        'windowMs': 1800,
        'mlDangerScore': 0.0, // Initial state
      });
      _isServiceRunning = true;
      notifyListeners();
    } on PlatformException catch (e) {
      debugPrint('❌ [SHAKE DETECTOR] Native Start Error: ${e.message}');
    } catch (_) {}
  }

  Future<void> stop() async {
    if (!_isServiceRunning || _isDisposed) return;
    try {
      await _methodChannel.invokeMethod('stopListening');
      _isServiceRunning = false;
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ [SHAKE DETECTOR] Stop error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // EVENT HANDLING
  // ═══════════════════════════════════════════════════════════════

  void _handleNativeSignal(dynamic event) {
    if (event is! Map || _isDisposed) return;

    final type = event['type'] as String?;
    if (type == 'shake_detected') {
      final trigger = ShakeTriggerEvent(
        confidence: (event['confidence'] as num?)?.toDouble() ?? 0.8,
        magnitude: (event['magnitude'] as num?)?.toDouble() ?? 0.0,
        shakeCount: (event['shakeCount'] as num?)?.toInt() ?? 3,
        timestamp: DateTime.now(),
      );

      debugPrint('🚨 [SHAKE DETECTOR] High-Confidence Shake Detected: ${trigger.confidence.toStringAsFixed(2)}');

      // ✅ CRITICAL GUARD: Do not push to closed streams
      if (!_shakeStreamCtrl.isClosed) {
        _shakeStreamCtrl.add(trigger);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // LIVE CONFIGURATION
  // ═══════════════════════════════════════════════════════════════

  Future<void> setEnabled(bool value) async {
    _isEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('shake_sos_enabled', value);

    value ? await start() : await stop();

    if (!_isDisposed) notifyListeners();
  }

  Future<void> setSensitivity(double value) async {
    _sensitivity = value.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('shake_sos_sensitivity', _sensitivity);

    if (_isServiceRunning && !_isDisposed) {
      // Hot-swapping sensor thresholds in the Native Kernel
      await _methodChannel.invokeMethod('updateConfig', {
        'threshold': _computedThreshold,
        'minShakes': 3,
      }).catchError((_) {});
    }

    if (!_isDisposed) notifyListeners();
  }

  /// CRITICAL: Feeds the Danger Score from our AI loop into the Native sensor.
  Future<void> updateDangerScore(double score) async {
    if (_isServiceRunning && !_isDisposed) {
      await _methodChannel.invokeMethod('updateDangerScore', score.clamp(0.0, 1.0)).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    stop(); // Send command to halt Kotlin sensors
    _nativeEventSub?.cancel();
    _shakeStreamCtrl.close();
    super.dispose();
  }
}