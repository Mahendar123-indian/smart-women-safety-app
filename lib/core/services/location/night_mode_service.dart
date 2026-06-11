// lib/core/services/location/night_mode_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// NIGHT MODE SERVICE
// Automatic high-alert mode 9pm–6am
// Higher GPS frequency, lower thresholds, silent SOS, auto-sharing
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NightAlert {
  nightModeActivated,
  nightModeDeactivated,
  autoSharingStarted,
  batteryLow,
  lateNightCheckIn,  // "Are you safe?" prompt at midnight
}

class NightModeEvent {
  final NightAlert type;
  final String message;
  final DateTime timestamp;
  const NightModeEvent({
    required this.type,
    required this.message,
    required this.timestamp,
  });
}

class NightModeService {
  NightModeService._();
  static final NightModeService instance = NightModeService._();

  static const int _nightStartHour = 21; // 9 PM
  static const int _nightEndHour   = 6;  // 6 AM
  static const int _lateNightHour  = 0;  // midnight check-in

  bool _isNightMode        = false;
  bool _autoSharingEnabled = true;
  bool _checkInEnabled     = true;
  int  _batteryLevel       = 100;

  Timer? _nightCheckTimer;
  Timer? _checkInTimer;
  Timer? _batteryWatcher;

  final _eventCtrl = StreamController<NightModeEvent>.broadcast();
  Stream<NightModeEvent> get eventStream => _eventCtrl.stream;
  bool get isNightMode        => _isNightMode;
  bool get autoSharingEnabled => _autoSharingEnabled;

  // ─── INIT ────────────────────────────────────────────────────
  Future<void> init() async {
    await _loadPrefs();
    _evaluateNightMode();

    // Check every minute if night mode should toggle
    _nightCheckTimer?.cancel();
    _nightCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _evaluateNightMode();
    });

    debugPrint('🌙 NightModeService: Init complete. Night mode = $_isNightMode');
  }

  // ─── EVALUATE NIGHT MODE ────────────────────────────────────
  void _evaluateNightMode() {
    final hour   = DateTime.now().hour;
    final isNight = hour >= _nightStartHour || hour < _nightEndHour;

    if (isNight && !_isNightMode) {
      _activateNightMode();
    } else if (!isNight && _isNightMode) {
      _deactivateNightMode();
    }

    // Midnight check-in
    if (hour == _lateNightHour && _checkInEnabled && _isNightMode) {
      _scheduleCheckIn();
    }
  }

  // ─── ACTIVATE ────────────────────────────────────────────────
  void _activateNightMode() {
    _isNightMode = true;
    debugPrint('🌙 NIGHT MODE ACTIVATED');
    _eventCtrl.add(NightModeEvent(
      type:      NightAlert.nightModeActivated,
      message:   '🌙 Night mode activated. Enhanced protection on. GPS frequency doubled.',
      timestamp: DateTime.now(),
    ));

    if (_autoSharingEnabled) {
      _eventCtrl.add(NightModeEvent(
        type:      NightAlert.autoSharingStarted,
        message:   '📡 Location auto-sharing started for night safety.',
        timestamp: DateTime.now(),
      ));
    }
  }

  // ─── DEACTIVATE ──────────────────────────────────────────────
  void _deactivateNightMode() {
    _isNightMode = false;
    debugPrint('☀️ NIGHT MODE DEACTIVATED');
    _eventCtrl.add(NightModeEvent(
      type:      NightAlert.nightModeDeactivated,
      message:   '☀️ Good morning! Night safety mode has ended.',
      timestamp: DateTime.now(),
    ));
  }

  // ─── MIDNIGHT CHECK-IN ───────────────────────────────────────
  void _scheduleCheckIn() {
    _checkInTimer?.cancel();
    // Debounce — only fire once per night
    _checkInTimer = Timer(const Duration(minutes: 1), () {
      if (!_isNightMode) return;
      _eventCtrl.add(NightModeEvent(
        type:      NightAlert.lateNightCheckIn,
        message:   '🌙 It\'s midnight. Are you safe? Tap to confirm or SOS will be triggered in 2 minutes.',
        timestamp: DateTime.now(),
      ));
    });
  }

  // ─── BATTERY ALERT ──────────────────────────────────────────
  void updateBatteryLevel(int percent) {
    _batteryLevel = percent;
    if (percent <= 15 && _isNightMode) {
      _eventCtrl.add(NightModeEvent(
        type:      NightAlert.batteryLow,
        message:   '🔋 Battery at $percent% at night. Last location being shared with your contacts.',
        timestamp: DateTime.now(),
      ));
    }
  }

  // ─── GPS INTERVAL for current mode ──────────────────────────
  /// Returns GPS update interval based on night mode + battery
  Duration get gpsInterval {
    if (_batteryLevel < 20) return const Duration(seconds: 30);
    if (_isNightMode)       return const Duration(seconds: 5);
    return const Duration(seconds: 10);
  }

  /// Distance filter in meters
  double get distanceFilter {
    if (_isNightMode) return 3.0;
    return 8.0;
  }

  /// Stationary threshold for dead man's switch
  Duration get stationaryThreshold {
    if (_isNightMode) return const Duration(minutes: 3);
    return const Duration(minutes: 5);
  }

  /// Auto-SOS delay after stationary warning
  Duration get autoSosDelay {
    if (_isNightMode) return const Duration(minutes: 1);
    return const Duration(minutes: 2);
  }

  /// Route deviation threshold in meters
  double get deviationThreshold {
    if (_isNightMode) return 150.0;
    return 300.0;
  }

  // ─── SETTINGS ────────────────────────────────────────────────
  Future<void> setAutoSharing(bool enabled) async {
    _autoSharingEnabled = enabled;
    await _savePrefs();
  }

  Future<void> setCheckIn(bool enabled) async {
    _checkInEnabled = enabled;
    await _savePrefs();
  }

  Future<void> forceNightMode(bool active) async {
    if (active) {
      _activateNightMode();
    } else {
      _deactivateNightMode();
    }
  }

  // ─── PREFS ──────────────────────────────────────────────────
  Future<void> _loadPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      _autoSharingEnabled = p.getBool('night_auto_share') ?? true;
      _checkInEnabled     = p.getBool('night_check_in')   ?? true;
    } catch (_) {}
  }

  Future<void> _savePrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('night_auto_share', _autoSharingEnabled);
      await p.setBool('night_check_in',   _checkInEnabled);
    } catch (_) {}
  }

  void dispose() {
    _nightCheckTimer?.cancel();
    _checkInTimer?.cancel();
    _batteryWatcher?.cancel();
    _eventCtrl.close();
  }
}