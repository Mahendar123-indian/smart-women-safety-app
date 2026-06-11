// lib/core/services/decoy_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// DECOY SERVICE — PIN management + fake app logic
// Real PIN → opens SafeHer normally
// Decoy PIN → opens fake calculator (hides SafeHer)
// Panic PIN → triggers silent SOS then opens decoy
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PinType { real, decoy, panic, invalid }

enum DecoyMode { calculator, notepad, weather }

class DecoyService extends ChangeNotifier {
  DecoyService._();
  static final DecoyService instance = DecoyService._();

  static const String _prefEnabled    = 'decoy_enabled';
  static const String _prefRealPin    = 'decoy_real_pin_hash';
  static const String _prefDecoyPin   = 'decoy_decoy_pin_hash';
  static const String _prefPanicPin   = 'decoy_panic_pin_hash';
  static const String _prefMode       = 'decoy_mode';
  static const String _prefSetup      = 'decoy_setup_done';

  bool       _isEnabled  = false;
  bool       _isSetup    = false;
  DecoyMode  _mode       = DecoyMode.calculator;
  int        _failedAttempts = 0;
  DateTime?  _lockoutUntil;

  // Callbacks
  void Function()? onPanicPinEntered;  // triggers silent SOS

  // ── Getters ─────────────────────────────────────────────────────
  bool      get isEnabled  => _isEnabled;
  bool      get isSetup    => _isSetup;
  DecoyMode get mode       => _mode;
  bool      get isLockedOut =>
      _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);
  Duration  get lockoutRemaining =>
      _lockoutUntil != null
          ? _lockoutUntil!.difference(DateTime.now())
          : Duration.zero;

  // ─── INIT ────────────────────────────────────────────────────────
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled  = prefs.getBool(_prefEnabled) ?? false;
    _isSetup    = prefs.getBool(_prefSetup)   ?? false;
    _mode       = DecoyMode.values[prefs.getInt(_prefMode) ?? 0];
    notifyListeners();
  }

  // ─── SETUP PINS ──────────────────────────────────────────────────
  Future<bool> setupPins({
    required String realPin,
    required String decoyPin,
    String? panicPin,
  }) async {
    if (realPin.length < 4 || decoyPin.length < 4) return false;
    if (realPin == decoyPin) return false;
    if (panicPin != null && panicPin == realPin) return false;
    if (panicPin != null && panicPin == decoyPin) return false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefRealPin,  _hash(realPin));
    await prefs.setString(_prefDecoyPin, _hash(decoyPin));
    if (panicPin != null && panicPin.length >= 4) {
      await prefs.setString(_prefPanicPin, _hash(panicPin));
    }
    await prefs.setBool(_prefSetup,   true);
    await prefs.setBool(_prefEnabled, true);

    _isSetup  = true;
    _isEnabled = true;
    notifyListeners();
    return true;
  }

  // ─── CHECK PIN ───────────────────────────────────────────────────
  Future<PinType> checkPin(String pin) async {
    if (isLockedOut) return PinType.invalid;
    if (pin.isEmpty) return PinType.invalid;

    final prefs     = await SharedPreferences.getInstance();
    final realHash  = prefs.getString(_prefRealPin)  ?? '';
    final decoyHash = prefs.getString(_prefDecoyPin) ?? '';
    final panicHash = prefs.getString(_prefPanicPin) ?? '';
    final entered   = _hash(pin);

    if (entered == realHash) {
      _failedAttempts = 0;
      return PinType.real;
    }
    if (entered == decoyHash) {
      _failedAttempts = 0;
      return PinType.decoy;
    }
    if (panicHash.isNotEmpty && entered == panicHash) {
      _failedAttempts = 0;
      onPanicPinEntered?.call(); // triggers silent SOS
      return PinType.panic; // shows decoy after SOS
    }

    // Wrong PIN
    _failedAttempts++;
    if (_failedAttempts >= 5) {
      // Lockout 5 minutes after 5 wrong attempts
      _lockoutUntil = DateTime.now().add(const Duration(minutes: 5));
      _failedAttempts = 0;
    }
    return PinType.invalid;
  }

  // ─── SETTINGS ────────────────────────────────────────────────────
  Future<void> setEnabled(bool v) async {
    _isEnabled = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, v);
    notifyListeners();
  }

  Future<void> setMode(DecoyMode m) async {
    _mode = m;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefMode, m.index);
    notifyListeners();
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefRealPin);
    await prefs.remove(_prefDecoyPin);
    await prefs.remove(_prefPanicPin);
    await prefs.setBool(_prefSetup, false);
    await prefs.setBool(_prefEnabled, false);
    _isSetup   = false;
    _isEnabled = false;
    notifyListeners();
  }

  // ─── HASH ────────────────────────────────────────────────────────
  String _hash(String pin) {
    final bytes  = utf8.encode('safeher_salt_$pin');
    return sha256.convert(bytes).toString();
  }
}