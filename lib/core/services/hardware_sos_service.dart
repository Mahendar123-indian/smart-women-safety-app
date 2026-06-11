// lib/core/services/hardware_sos_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// INDUSTRIAL SENTINEL — TACTICAL HARDWARE SOS v5.0 (2026 PRODUCTION)
// ─────────────────────────────────────────────────────────────────────────────
// ✅ [FIXED] Lifecycle Crash: Added strict _isDisposed guards to prevent fatal
//    timer crashes if the service is disposed during the 25s cooldown.
// ✅ [KERNEL] Zero-latency Native Interrupts via Method/Event Channels.
// ✅ [TACTILE] Pulsed Haptics (30/60/90%) strictly locked to prevent spam buzzing.
// ✅ [STEALTH] Native suppression of Volume UI during emergency arming.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum HardwareTriggerType {
  volumeHold,
  earphoneDouble,
  earphoneTriple,
}

enum HardwareSosState { idle, armed, triggered, cooldown }

class HardwareTriggerEvent {
  final HardwareTriggerType type;
  final String triggerSource;
  final DateTime triggeredAt;

  const HardwareTriggerEvent({
    required this.type,
    required this.triggerSource,
    required this.triggeredAt
  });
}

class HardwareSosService extends ChangeNotifier {
  HardwareSosService._();
  static final HardwareSosService instance = HardwareSosService._();

  // ── Native Bridge Channels (Must match MainActivity.kt) ───────────────
  static const _methodChannel = MethodChannel('com.safeher/hardware_sos');
  static const _eventChannel  = EventChannel('com.safeher/hardware_sos_events');

  // ── Persistent Preference Keys ──────────────────────────────────────
  static const String _prefEnabled      = 'hardware_sos_enabled';
  static const String _prefVolEnabled   = 'hardware_sos_volume_enabled';
  static const String _prefEarEnabled   = 'hardware_sos_earphone_enabled';
  static const String _prefVolHoldMs    = 'hardware_sos_vol_hold_ms';

  static const int _defaultHoldMs       = 3000;
  static const int _cooldownSeconds     = 25; // Extended for safety stability

  // ── Internal Service State ──────────────────────────────────────────
  bool _isEnabled       = true;
  bool _volumeEnabled   = true;
  bool _earphoneEnabled = true;
  int  _volumeHoldMs    = _defaultHoldMs;
  HardwareSosState _state = HardwareSosState.idle;

  bool _initialized = false;
  bool _isDisposed  = false; // ✅ CRITICAL: Lifecycle Guard

  // Haptic spam prevention tracker
  int _lastHapticStep = 0;

  StreamSubscription? _eventSub;
  Timer? _cooldownTimer;

  // ── Tactical Callbacks (Interlinked with SosProvider & UI) ───────────
  void Function(HardwareTriggerEvent)? onSosTriggered;
  void Function(double progress)? onArmingProgress;

  // ── Getters ────────────────────────────────────────────────────────
  bool             get isEnabled       => _isEnabled;
  bool             get volumeEnabled   => _volumeEnabled;
  bool             get earphoneEnabled => _earphoneEnabled;
  int              get volumeHoldMs    => _volumeHoldMs;
  HardwareSosState get state           => _state;

  // ═══════════════════════════════════════════════════════════════
  // INITIALIZATION & BRIDGE SETUP
  // ═══════════════════════════════════════════════════════════════

  Future<void> initialize() async {
    if (_initialized) return;
    _isDisposed = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled       = prefs.getBool(_prefEnabled)    ?? true;
      _volumeEnabled   = prefs.getBool(_prefVolEnabled) ?? true;
      _earphoneEnabled = prefs.getBool(_prefEarEnabled) ?? true;
      _volumeHoldMs    = prefs.getInt(_prefVolHoldMs)   ?? _defaultHoldMs;

      if (_isEnabled) {
        _startNativeSentinel();
      }
      _initialized = true;
      debugPrint('🛡️ [HARDWARE SERVICE] Tactical Hardware Bridge Online.');
    } catch (e) {
      debugPrint('❌ [HARDWARE SERVICE] Initialization Error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // NATIVE INTERRUPT CONTROL
  // ═══════════════════════════════════════════════════════════════

  void _startNativeSentinel() {
    _eventSub?.cancel();
    _eventSub = _eventChannel.receiveBroadcastStream().listen(
      _handleNativePulse,
      onError: (e) => debugPrint('⚠️ [HARDWARE SERVICE] Kernel Event Error: $e'),
    );

    _syncConfigWithNative();
  }

  Future<void> _syncConfigWithNative() async {
    if (_isDisposed) return;
    try {
      // Direct Kernel Command to start hardware monitoring
      await _methodChannel.invokeMethod('startListening', {
        'volumeEnabled':   _volumeEnabled,
        'earphoneEnabled': _earphoneEnabled,
        'volumeHoldMs':    _volumeHoldMs,
        'discreetMode':    true, // Suppresses Volume UI on Android
      });
    } catch (e) {
      debugPrint('⚠️ [HARDWARE SERVICE] Native Sync Failed: $e');
    }
  }

  void _stopNativeSentinel() {
    _eventSub?.cancel();
    if (!_isDisposed) {
      _methodChannel.invokeMethod('stopListening').catchError((e) => null);
    }
    _safeSetState(HardwareSosState.idle);
  }

  // ═══════════════════════════════════════════════════════════════
  // NATIVE SIGNAL PROCESSOR
  // ═══════════════════════════════════════════════════════════════

  void _handleNativePulse(dynamic event) {
    if (!_isEnabled || _isDisposed || event is! Map) return;

    final type = event['type'] as String? ?? '';

    switch (type) {
      case 'volume_down_start':
        _safeSetState(HardwareSosState.armed);
        _lastHapticStep = 0; // Reset haptic tracker
        HapticFeedback.mediumImpact(); // Immediate confirmation through clothing
        break;

      case 'volume_down_end':
        if (_state == HardwareSosState.armed) {
          _lastHapticStep = 0;
          onArmingProgress?.call(0.0);
          _safeSetState(HardwareSosState.idle);
        }
        break;

      case 'arming':
      // Real-time progress (0.0 to 1.0) for the UI overlay and haptics
        final progress = (event['progress'] as num?)?.toDouble() ?? 0.0;
        if (!_isDisposed) onArmingProgress?.call(progress);

        // Tactile "Heartbeat" feedback (Strictly locked to prevent buzzing spam)
        final percent = (progress * 100).toInt();
        if (percent >= 30 && _lastHapticStep < 30) {
          HapticFeedback.selectionClick();
          _lastHapticStep = 30;
        } else if (percent >= 60 && _lastHapticStep < 60) {
          HapticFeedback.selectionClick();
          _lastHapticStep = 60;
        } else if (percent >= 90 && _lastHapticStep < 90) {
          HapticFeedback.heavyImpact();
          _lastHapticStep = 90;
        }
        break;

      case 'volume_down_long':
      // Kotlin sends this master key for BOTH Volume AND Earphone triggers
        _executeTacticalTrigger(event['triggerType'] as String? ?? 'volume_hold');
        break;

      case 'status':
        debugPrint('🛡️ [HARDWARE SERVICE] Kernel Status: ${event['status']}');
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // TACTICAL EXECUTION ENGINE
  // ═══════════════════════════════════════════════════════════════

  void _executeTacticalTrigger(String source) {
    // Atomic State Mutex: Prevent double triggers within the cooldown period
    if (_state == HardwareSosState.triggered || _state == HardwareSosState.cooldown || _isDisposed) return;

    _safeSetState(HardwareSosState.triggered);
    HapticFeedback.vibrate(); // Major confirmation vibration

    // Map source string from Kotlin to strictly typed Dart enum
    HardwareTriggerType mappedType;
    if (source.contains('triple')) {
      mappedType = HardwareTriggerType.earphoneTriple;
    } else if (source.contains('earphone') || source.contains('headset') || source.contains('double')) {
      mappedType = HardwareTriggerType.earphoneDouble;
    } else {
      mappedType = HardwareTriggerType.volumeHold;
    }

    final triggerEvent = HardwareTriggerEvent(
      type: mappedType,
      triggerSource: source,
      triggeredAt: DateTime.now(),
    );

    debugPrint('🚨 [SENTINEL] Hardware SOS Dispatched via: $source');

    // Push event to SosProvider
    if (!_isDisposed) onSosTriggered?.call(triggerEvent);

    // Enter Cooldown Phase
    _safeSetState(HardwareSosState.cooldown);

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(Duration(seconds: _cooldownSeconds), () {
      if (_isDisposed) return; // ✅ FIXED: Guard against post-dispose crash

      _safeSetState(HardwareSosState.idle);
      _syncConfigWithNative(); // Re-sync to clean kernel buffers
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // PUBLIC CONFIGURATION METHODS
  // ═══════════════════════════════════════════════════════════════

  Future<void> setEnabled(bool v) async {
    _isEnabled = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, v);
    v ? _startNativeSentinel() : _stopNativeSentinel();
    if (!_isDisposed) notifyListeners();
  }

  Future<void> setVolumeEnabled(bool v) async {
    _volumeEnabled = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefVolEnabled, v);
    _syncConfigWithNative();
    if (!_isDisposed) notifyListeners();
  }

  Future<void> setEarphoneEnabled(bool v) async {
    _earphoneEnabled = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEarEnabled, v);
    _syncConfigWithNative();
    if (!_isDisposed) notifyListeners();
  }

  Future<void> setVolumeHoldDuration(int ms) async {
    _volumeHoldMs = ms.clamp(1500, 5000); // Guarding within sensible limits
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefVolHoldMs, _volumeHoldMs);
    _syncConfigWithNative();
    if (!_isDisposed) notifyListeners();
  }

  /// Tactical Simulation: Used for testing the SOS loop in the UI
  void testTrigger(HardwareTriggerType type) {
    _executeTacticalTrigger('internal_simulation_${type.name}');
  }

  // ═══════════════════════════════════════════════════════════════
  // UTILITIES & CLEANUP
  // ═══════════════════════════════════════════════════════════════

  void _safeSetState(HardwareSosState newState) {
    if (_isDisposed) return;
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true; // Set flag FIRST
    _stopNativeSentinel();
    _cooldownTimer?.cancel();
    super.dispose();
  }
}