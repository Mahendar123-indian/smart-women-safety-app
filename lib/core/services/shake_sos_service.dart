// lib/core/services/shake_sos_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// INDUSTRIAL SHAKE SOS SERVICE — v5.0 (2026 SENTINEL EDITION)
// ─────────────────────────────────────────────────────────────────────────────
// ✅ [FIXED] False Positives: Recalibrated computed G-Force threshold.
// ✅ [FIXED] Background Math Mismatch: Aligned magnitude check with new sqrt() logic.
// ✅ [FIXED] High-Pass Context Filter: Requires ML danger > 65% for bg fallback.
// ✅ [DUAL-SOURCE MUTEX] Prevents double-triggers from Native & BG sources.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ShakeSosState { idle, detecting, candidate, triggered, cooldown }

/// Data manifest for a verified shake event
class ShakeDetectionResult {
  final double confidence;
  final double magnitude;
  final int shakeCount;
  final double patternConf;
  final double physicsConf;
  final double contextConf;
  final double mlDangerScore;
  final bool isNight;
  final String source; // 'native' or 'background'
  final DateTime detectedAt;

  const ShakeDetectionResult({
    required this.confidence,
    required this.magnitude,
    required this.shakeCount,
    required this.patternConf,
    required this.physicsConf,
    required this.contextConf,
    required this.mlDangerScore,
    required this.isNight,
    required this.source,
    required this.detectedAt,
  });
}

class ShakeSosService extends ChangeNotifier {
  ShakeSosService._();
  static final ShakeSosService instance = ShakeSosService._();

  // ── Channels ────────────────────────────────────────────────────────
  static const _channel = MethodChannel('com.safeher/shake_sos');
  static const _eventChannel = EventChannel('com.safeher/shake_sos_events');

  // ── Pref Keys ───────────────────────────────────────────────────────
  static const String _prefEnabled = 'shake_sos_enabled';
  static const String _prefSensitivity = 'shake_sos_sensitivity';
  static const String _prefMinShakes = 'shake_sos_min_shakes';

  // ── State ───────────────────────────────────────────────────────────
  ShakeSosState _state = ShakeSosState.idle;
  bool _isEnabled = true;
  bool _initialized = false;
  bool _isDisposed = false; // Lifecycle guard

  double _sensitivity = 0.5;
  int _minShakes = 3;
  double _mlDangerScore = 0.0;

  bool _triggerInProgress = false; // The Master Mutex
  ShakeDetectionResult? _lastResult;

  StreamSubscription? _eventSub;
  StreamSubscription? _bgServiceSub;
  Timer? _cooldownTimer;

  // ── Callbacks (Interlinked with UI and SosProvider) ─────────────────
  void Function(ShakeDetectionResult result)? onSosTriggered;
  void Function(double confidence, int shakeCount)? onCandidate;

  // ── Getters ─────────────────────────────────────────────────────────
  ShakeSosState get state => _state;
  bool get isEnabled => _isEnabled;
  double get sensitivity => _sensitivity;
  ShakeDetectionResult? get lastResult => _lastResult;

  /// Translates UI sensitivity (0.0 - 1.0) to hardware m/s²
  /// ✅ RECALIBRATED:
  /// Min Sensitivity (0.0) = 45.0 m/s² (Requires violent shaking)
  /// Max Sensitivity (1.0) = 25.0 m/s² (Still requires definitive shaking, prevents jogging false alarms)
  double get _computedThreshold => 45.0 - (_sensitivity * 20.0);

  // ═══════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════

  Future<void> initialize() async {
    if (_initialized) return;
    _isDisposed = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool(_prefEnabled) ?? true;
      _sensitivity = prefs.getDouble(_prefSensitivity) ?? 0.5;
      _minShakes = prefs.getInt(_prefMinShakes) ?? 3;

      // Listen to High-Speed Native Kernel (Source A)
      _eventSub = _eventChannel.receiveBroadcastStream().listen(
        _onNativeEvent,
        onError: (e) => debugPrint('⚠️ [SHAKE SOS] Native Event Error: $e'),
      );

      // Listen to Background Service (Source B - Fallback)
      _listenBackgroundService();

      _initialized = true;
      if (_isEnabled) await _startNativeDetection();

      debugPrint('🛡️ [SHAKE SOS] Kinetic Sentinel Online');
    } catch (e) {
      debugPrint('❌ [SHAKE SOS] Init Failure: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // DUAL-SOURCE SIGNAL PROCESSORS
  // ═══════════════════════════════════════════════════════════════

  void _listenBackgroundService() {
    _bgServiceSub?.cancel();

    _bgServiceSub = FlutterBackgroundService().on('shake_detected').listen((data) {
      if (data == null || !_isEnabled || _triggerInProgress || _isDisposed) return;

      // ✅ FIXED: Background service now sends magnitude using sqrt() math, so values are typically 30.0 - 60.0
      final mag = (data['magnitude'] as num?)?.toDouble() ?? 0.0;

      // ✅ SECONDARY LOGIC: Background source acts as a fallback.
      // It requires a high magnitude (> 35.0 m/s²) AND context confirmation from the ML layer.
      // If ML Danger Score is low (< 0.65), we assume you just dropped your phone on the bed.
      if (mag > 35.0 && _mlDangerScore >= 0.65) {

        final confidence = (mag / 50.0 + _mlDangerScore) / 2.0;

        if (confidence >= 0.70) {
          _onShakeConfirmed(ShakeDetectionResult(
            confidence: confidence.clamp(0.0, 1.0),
            magnitude: mag,
            shakeCount: _minShakes,
            patternConf: 0.6,
            physicsConf: 0.7,
            contextConf: _mlDangerScore,
            mlDangerScore: _mlDangerScore,
            isNight: _isNightTime(),
            source: 'background',
            detectedAt: DateTime.now(),
          ));
        }
      }
    });
  }

  void _onNativeEvent(dynamic event) {
    if (event is! Map || _isDisposed) return;
    final type = event['type'] as String? ?? '';

    switch (type) {
      case 'shake_detected':
      // Kotlin 5-Layer AI confirmed the event
        _onShakeConfirmed(ShakeDetectionResult(
          confidence: (event['confidence'] as num?)?.toDouble() ?? 0.0,
          magnitude: (event['magnitude'] as num?)?.toDouble() ?? 0.0,
          shakeCount: (event['shakeCount'] as num?)?.toInt() ?? 0,
          patternConf: (event['patternConf'] as num?)?.toDouble() ?? 0.0,
          physicsConf: (event['physicsConf'] as num?)?.toDouble() ?? 0.0,
          contextConf: (event['contextConf'] as num?)?.toDouble() ?? 0.0,
          mlDangerScore: _mlDangerScore,
          isNight: _isNightTime(),
          source: 'native',
          detectedAt: DateTime.now(),
        ));
        break;

      case 'shake_candidate':
      // Visual feedback for "Potential Shake"
        _safeSetState(ShakeSosState.candidate);
        onCandidate?.call(
            (event['confidence'] as num?)?.toDouble() ?? 0.0,
            (event['shakeCount'] as num?)?.toInt() ?? 0
        );
        break;

      case 'status':
        final s = event['status'] as String? ?? '';
        _safeSetState((s == 'listening') ? ShakeSosState.detecting : ShakeSosState.idle);
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // MUTEX GUARDED DISPATCH
  // ═══════════════════════════════════════════════════════════════

  void _onShakeConfirmed(ShakeDetectionResult result) {
    if (_triggerInProgress || !_isEnabled || _isDisposed) return;

    _triggerInProgress = true;
    _lastResult = result;
    _safeSetState(ShakeSosState.triggered);

    debugPrint('🚨 [SHAKE SOS] Verified Strike [Source: ${result.source}] Conf: ${result.confidence.toStringAsFixed(2)}');

    // Signal SosProvider to execute the forensic sequence
    onSosTriggered?.call(result);

    // Enter Cooldown to prevent multiple SOS events from one struggle
    _safeSetState(ShakeSosState.cooldown);

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(const Duration(seconds: 25), () {
      if (_isDisposed) return;

      _triggerInProgress = false;
      _safeSetState(ShakeSosState.detecting);

      // Resync Kotlin state to clear any lingering hardware buffers
      if (_isEnabled) _startNativeDetection();
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // NATIVE CONTROL
  // ═══════════════════════════════════════════════════════════════

  Future<void> _startNativeDetection() async {
    try {
      await _channel.invokeMethod('startListening', {
        'threshold': _computedThreshold,
        'minShakes': _minShakes,
        'mlDangerScore': _mlDangerScore,
        'isNightTime': _isNightTime(),
      });
    } on PlatformException catch (e) {
      debugPrint('⚠️ [SHAKE SOS] Native Start Error: ${e.message}');
    } catch (_) {}
  }

  Future<void> _stopNativeDetection() async {
    try {
      await _channel.invokeMethod('stopListening');
    } catch (_) {}
  }

  /// CRITICAL: Injects live ML score into Kotlin for contextual awareness
  void updateMlDangerScore(double score) {
    _mlDangerScore = score.clamp(0.0, 1.0);
    if (_isEnabled && !_isDisposed) {
      _channel.invokeMethod('updateDangerScore', _mlDangerScore).catchError((_) {});
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // PUBLIC CONFIGURATION
  // ═══════════════════════════════════════════════════════════════

  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, enabled);

    enabled ? await _startNativeDetection() : await _stopNativeDetection();

    if (!_isDisposed) notifyListeners();
  }

  Future<void> setSensitivity(double value) async {
    _sensitivity = value.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefSensitivity, _sensitivity);

    if (_isEnabled && !_isDisposed) {
      await _channel.invokeMethod('updateConfig', {
        'threshold': _computedThreshold,
        'minShakes': _minShakes,
      }).catchError((_) {});
    }

    if (!_isDisposed) notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════
  // UTILITIES & CLEANUP
  // ═══════════════════════════════════════════════════════════════

  void _safeSetState(ShakeSosState newState) {
    if (_isDisposed) return;
    _state = newState;
    notifyListeners();
  }

  bool _isNightTime() {
    final h = DateTime.now().hour;
    return h >= 21 || h < 6;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stopNativeDetection();
    _eventSub?.cancel();
    _bgServiceSub?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }
}