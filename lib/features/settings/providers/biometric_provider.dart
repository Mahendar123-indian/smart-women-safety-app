// lib/features/settings/providers/biometric_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';

enum BiometricState { unknown, locked, unlocked, unsupported }
enum BiometricAuthResult { success, failed, cancelled, unavailable, notEnrolled }

class BiometricProvider extends ChangeNotifier {
  BiometricProvider() { _init(); }

  final LocalAuthentication _auth = LocalAuthentication();

  BiometricState _state = BiometricState.unknown;
  bool _isEnabled = false;
  bool _isSupportedOnDevice = false;
  bool _isLoading = false;
  List<BiometricType> _availableTypes = [];
  String? _error;
  DateTime? _lastUnlockedAt;
  int _failedAttempts = 0;
  static const int _maxAttempts = 3;
  static const Duration _lockoutDuration = Duration(minutes: 1);
  Timer? _lockoutTimer;
  bool _isLockedOut = false;
  int _lockoutSecondsRemaining = 0;

  // ── Getters ──────────────────────────────────────────────
  BiometricState get state => _state;
  bool get isEnabled => _isEnabled;
  bool get isSupported => _isSupportedOnDevice;
  bool get isLoading => _isLoading;
  bool get isLocked => _state == BiometricState.locked;
  bool get isUnlocked => _state == BiometricState.unlocked;
  bool get isLockedOut => _isLockedOut;
  int get lockoutSecondsRemaining => _lockoutSecondsRemaining;
  List<BiometricType> get availableTypes => _availableTypes;
  String? get error => _error;
  int get failedAttempts => _failedAttempts;
  int get maxAttempts => _maxAttempts;

  bool get hasFingerprint => _availableTypes.contains(BiometricType.fingerprint);
  bool get hasFaceID => _availableTypes.contains(BiometricType.face);

  String get biometricLabel {
    if (hasFaceID && hasFingerprint) return 'Face ID / Fingerprint';
    if (hasFaceID) return 'Face ID';
    if (hasFingerprint) return 'Fingerprint';
    return 'Biometric';
  }

  // ── Init ─────────────────────────────────────────────────
  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    try {
      _isSupportedOnDevice = await _auth.isDeviceSupported();
      if (_isSupportedOnDevice) {
        _availableTypes = await _auth.getAvailableBiometrics();
      }
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool(AppConstants.biometricEnabledKey) ?? false;

      // If enabled, start in locked state
      _state = _isEnabled
          ? BiometricState.locked
          : BiometricState.unlocked;
    } catch (_) {
      _isSupportedOnDevice = false;
      _state = BiometricState.unlocked;
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Authenticate ─────────────────────────────────────────
  Future<BiometricAuthResult> authenticate({
    String reason = 'Verify your identity to access SafeHer',
  }) async {
    if (_isLockedOut) return BiometricAuthResult.failed;
    if (!_isSupportedOnDevice) return BiometricAuthResult.unavailable;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final enrolled = await _auth.canCheckBiometrics;
      if (!enrolled) {
        _isLoading = false;
        notifyListeners();
        return BiometricAuthResult.notEnrolled;
      }

      final result = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // allow PIN fallback
          stickyAuth: true,
          sensitiveTransaction: true,
          useErrorDialogs: true,
        ),
      );

      if (result) {
        _state = BiometricState.unlocked;
        _lastUnlockedAt = DateTime.now();
        _failedAttempts = 0;
        _isLoading = false;
        notifyListeners();
        return BiometricAuthResult.success;
      } else {
        _handleFailedAttempt();
        _isLoading = false;
        notifyListeners();
        return BiometricAuthResult.failed;
      }
    } on PlatformException catch (e) {
      _error = e.message;
      if (e.code == 'NotAvailable' || e.code == 'NotEnrolled') {
        _isLoading = false;
        notifyListeners();
        return BiometricAuthResult.unavailable;
      }
      _handleFailedAttempt();
      _isLoading = false;
      notifyListeners();
      return BiometricAuthResult.failed;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return BiometricAuthResult.failed;
    }
  }

  void _handleFailedAttempt() {
    _failedAttempts++;
    if (_failedAttempts >= _maxAttempts) {
      _startLockout();
    }
  }

  void _startLockout() {
    _isLockedOut = true;
    _lockoutSecondsRemaining = _lockoutDuration.inSeconds;
    notifyListeners();

    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      _lockoutSecondsRemaining--;
      if (_lockoutSecondsRemaining <= 0) {
        t.cancel();
        _isLockedOut = false;
        _failedAttempts = 0;
        _lockoutSecondsRemaining = 0;
      }
      notifyListeners();
    });
  }

  // ── Enable / Disable ─────────────────────────────────────
  Future<bool> enableBiometric() async {
    if (!_isSupportedOnDevice) return false;

    final result = await authenticate(
      reason: 'Verify your identity to enable App Lock',
    );

    if (result == BiometricAuthResult.success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.biometricEnabledKey, true);
      _isEnabled = true;
      _state = BiometricState.unlocked;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> disableBiometric() async {
    final result = await authenticate(
      reason: 'Verify your identity to disable App Lock',
    );

    if (result == BiometricAuthResult.success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.biometricEnabledKey, false);
      _isEnabled = false;
      _state = BiometricState.unlocked;
      notifyListeners();
      return true;
    }
    return false;
  }

  // ── Lock app manually ────────────────────────────────────
  void lockApp() {
    if (_isEnabled) {
      _state = BiometricState.locked;
      notifyListeners();
    }
  }

  // ── Skip (for unsupported devices) ──────────────────────
  void unlockWithoutBiometric() {
    _state = BiometricState.unlocked;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }
}