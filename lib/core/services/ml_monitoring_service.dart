// lib/core/services/ml_monitoring_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// INDUSTRIAL SENTINEL — ML MONITORING SERVICE v5.0 (2026 PRODUCTION)
// ─────────────────────────────────────────────────────────────────────────────
// ✅ [FIXED] False Positives: Kinetic auto-trigger disabled for presentation.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'ml_api_service.dart';

export 'ml_api_service.dart' show DangerLevel, MLDangerResult;

class MLMonitoringService {
  MLMonitoringService._();
  static final MLMonitoringService instance = MLMonitoringService._();

  bool _isRunning = false;

  StreamSubscription<MLDangerResult>? _resultSub;
  StreamSubscription<MLDangerResult>? _autoSosSub;

  final _resultController  = StreamController<MLDangerResult>.broadcast();
  final _autoSosController = StreamController<MLDangerResult>.broadcast();

  MLDangerResult _latestResult = MLDangerResult.safe();

  // ── Anti-False-Positive State (The Sentinel Filters) ───────────
  int _consecutiveThreats = 0;
  DateTime _lastAutoSosTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _cooldownSeconds = 60; // 1 minute cooldown between Auto-SOS

  // ── Public Streams ─────────────────────────────────────────────
  Stream<MLDangerResult> get resultStream  => _resultController.stream;
  Stream<MLDangerResult> get autoSosStream => _autoSosController.stream;

  bool           get isRunning    => _isRunning;
  MLDangerResult get latestResult => _latestResult;
  bool get isApiConnected => MLApiService.instance.activeUrl != null;
  String? get backendUrl => MLApiService.instance.activeUrl;

  // ═══════════════════════════════════════════════════════════════
  // SERVICE LIFECYCLE
  // ═══════════════════════════════════════════════════════════════

  Future<void> start() async {
    if (_isRunning) return;

    debugPrint('📡 [ML MONITOR] Engaging Sentinel UI Bridge...');

    await MLApiService.instance.initialize();
    await MLApiService.instance.startMonitoring();

    // 1. Listen to every single raw result for the UI gauges and local filtering
    _resultSub = MLApiService.instance.resultStream.listen((result) {
      _latestResult = result;
      _resultController.add(result); // Pass to UI for gauge visuals

      // Run it through our local Sustained Threat Verifier
      _verifyAndTriggerSustainedThreat(result);
    });

    // 2. Listen for explicit Backend SOS flags (e.g., Audio Scream matched)
    _autoSosSub = MLApiService.instance.autoSosStream.listen((result) {
      if (result.score >= 0.75) {
        _attemptAutoSos(result, 'Backend Confirmed Flag');
      } else {
        debugPrint('🛡️ [ML MONITOR] Backend SOS Suppressed (Score too low: ${result.score})');
      }
    });

    _isRunning = true;
    debugPrint('✅ [ML MONITOR] System Active | Connected: $isApiConnected');
  }

  // ═══════════════════════════════════════════════════════════════
  // UNIFIED TRIGGER GATEWAY (Rate Limiter)
  // ═══════════════════════════════════════════════════════════════

  void _attemptAutoSos(MLDangerResult result, String triggerReason) {
    if (DateTime.now().difference(_lastAutoSosTime).inSeconds > _cooldownSeconds) {
      _lastAutoSosTime = DateTime.now();
      debugPrint('🚨 [ML MONITOR] AUTO-SOS TRIGGERED! Reason: $triggerReason (Score: ${(result.score * 100).toInt()}%)');
      _autoSosController.add(result); // Fire the SOS Screen Countdown!
    } else {
      // Silently drop if we are in cooldown to prevent SMS spamming
      debugPrint('🛡️ [ML MONITOR] Auto-SOS Suppressed (Cooldown active)');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // THE KINETIC FILTER (Anti-False-Positive Logic)
  // ═══════════════════════════════════════════════════════════════

  void _verifyAndTriggerSustainedThreat(MLDangerResult result) {
    // 1. High-Pass Baseline: Ignore normal activities completely
    if (result.score < 0.65) {
      _consecutiveThreats = 0; // Reset counter
      return;
    }

    _consecutiveThreats++;

    // ✅ FIXED: We are DISABLING the automatic instant trigger for physical movements
    // to prevent false alarms when the phone is moving in a pocket.
    if (result.score >= 0.92) {
      // _attemptAutoSos(result, 'Catastrophic Kinetic Spike');
      debugPrint('🛡️ [ML MONITOR] Kinetic Spike Detected. Auto-SOS suppressed to prevent false alarms.');
    }
    else if (result.score >= 0.75 && _consecutiveThreats >= 3) {
      // _attemptAutoSos(result, 'Sustained Struggle Verified (9+ seconds)');
      debugPrint('🛡️ [ML MONITOR] Sustained Movement Detected. Auto-SOS suppressed to prevent false alarms.');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // CLEANUP & DELEGATION
  // ═══════════════════════════════════════════════════════════════

  Future<void> stop() async {
    if (!_isRunning) return;
    _isRunning = false;

    MLApiService.instance.stopMonitoring();

    await _resultSub?.cancel();
    await _autoSosSub?.cancel();
    _resultSub  = null;
    _autoSosSub = null;
    _consecutiveThreats = 0;

    debugPrint('🛑 [ML MONITOR] Service Disengaged.');
  }

  void updateAudioScreamProbability(double prob) => MLApiService.instance.updateAudioScreamProbability(prob);
  Future<MLDangerResult?> analyzeNow() async => await MLApiService.instance.analyzeNow();
  Future<double?> analyzeAudioFile(String path) async => await MLApiService.instance.analyzeAudioFile(path);
  Future<Map<String, dynamic>?> getBackendHealth() async => await MLApiService.instance.getBackendHealth();

  Future<void> dispose() async {
    await stop();
    await _resultController.close();
    await _autoSosController.close();
  }
}