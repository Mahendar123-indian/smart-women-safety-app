// lib/features/auth/providers/auth_provider.dart
// ─────────────────────────────────────────────────────────────────────────────
// INDUSTRIAL SENTINEL — AUTH PROVIDER v5.0 (2026 PRODUCTION)
// ─────────────────────────────────────────────────────────────────────────────
// ✅ [FIXED] OTP Synchronization: Ensuring verificationId is set before notify.
// ✅ [FIXED] Auto-Verify Logic: Seamless transition for Android auto-verification.
// ✅ [FIXED] Conflict Resolution: Hidden Firebase AuthProvider to prevent crashes.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/services/notification_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository;
  final _notif = NotificationService.instance;

  AuthStatus _status       = AuthStatus.initial;
  UserModel? _user;
  String?    _errorMessage;
  bool       _isLoading    = false;

  // OTP state
  String? _verificationId;
  int?    _resendToken;
  bool    _otpSent = false;

  AuthProvider({AuthRepository? repository})
      : _repository = repository ?? AuthRepository() {
    _init();
  }

  // ─── Getters ──────────────────────────────────────────────────────────────
  AuthStatus get status       => _status;
  UserModel? get user         => _user;
  String?    get errorMessage => _errorMessage;
  bool get isLoading          => _isLoading;
  bool get isAuthenticated    => _status == AuthStatus.authenticated;
  bool get otpSent            => _otpSent;
  String? get verificationId  => _verificationId;

  // ─── Init ─────────────────────────────────────────────────────────────────
  Future<void> _init() async {
    _setStatus(AuthStatus.loading);
    try {
      final persistedUser = await _repository.getPersistedUser();
      if (persistedUser != null) {
        _user = persistedUser;
        _setStatus(AuthStatus.authenticated);
      } else {
        _setStatus(AuthStatus.unauthenticated);
      }
    } catch (_) {
      _setStatus(AuthStatus.unauthenticated);
    }

    _repository.authStateChanges.listen((firebaseUser) {
      if (firebaseUser == null && _status == AuthStatus.authenticated) {
        _user = null;
        _setStatus(AuthStatus.unauthenticated);
      }
    });
  }

  // ─── Email Login ──────────────────────────────────────────────────────────
  Future<bool> loginWithEmail({required String email, required String password}) async {
    _setLoading(true);
    _clearError();
    try {
      _user = await _repository.loginWithEmail(email: email, password: password);
      _setStatus(AuthStatus.authenticated);
      _unawaited(_notif.showLoginSuccess(name: _user?.name ?? email.split('@').first));
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ─── Register ─────────────────────────────────────────────────────────────
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      _user = await _repository.registerWithEmail(
        name: name,
        email: email,
        password: password,
        phone: phone,
      );
      _setStatus(AuthStatus.authenticated);
      _unawaited(_notif.showLoginSuccess(name: name));
      _unawaited(_notif.showAppProtectionActive());
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ─── Google Sign-In ───────────────────────────────────────────────────────
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _clearError();
    try {
      _user = await _repository.signInWithGoogle();
      _setStatus(AuthStatus.authenticated);
      _unawaited(_notif.showLoginSuccess(name: _user?.name ?? 'User'));
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ─── Phone OTP (Perfected Logic) ──────────────────────────────────────────
  Future<bool> sendOtp(String phoneNumber) async {
    _setLoading(true);
    _clearError();
    _otpSent = false;
    _verificationId = null; // Clear previous sessions

    try {
      await _repository.sendOtp(
        phoneNumber: phoneNumber,
        onCodeSent: (verId, resendToken) {
          _verificationId = verId;
          _resendToken    = resendToken;
          _otpSent        = true;
          _setLoading(false); // This triggers the navigation in PhoneAuthScreen
          debugPrint('✅ [AUTH] OTP Sent to $phoneNumber. VerID: $verId');
        },
        onError: (error) {
          _otpSent = false;
          _setError(error);
          _setLoading(false);
        },
        onAutoVerified: (credential) async {
          // Android Auto-Verification logic
          try {
            _user = await _repository.verifyOtp(
              verificationId: _verificationId ?? '',
              otp: credential.smsCode ?? '',
            );
            _setStatus(AuthStatus.authenticated);
            _unawaited(_notif.showLoginSuccess(name: _user?.name ?? 'User'));
          } catch (e) {
            _setError(e.toString());
          } finally {
            _setLoading(false);
          }
        },
      );
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> verifyOtp({required String otp, String? name}) async {
    if (_verificationId == null) {
      _setError('Session expired. Please request a new OTP.');
      return false;
    }

    _setLoading(true);
    _clearError();
    try {
      _user = await _repository.verifyOtp(
        verificationId: _verificationId!,
        otp: otp,
        name: name,
      );
      _setStatus(AuthStatus.authenticated);
      _unawaited(_notif.showLoginSuccess(name: _user?.name ?? name ?? 'User'));
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ─── Reset & SignOut ──────────────────────────────────────────────────────
  Future<bool> sendPasswordResetEmail(String email) async {
    _setLoading(true);
    _clearError();
    try {
      await _repository.sendPasswordResetEmail(email);
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    _unawaited(_notif.showLogoutSuccess());
    _unawaited(_notif.dismissAll());
    try {
      await _repository.signOut();
      _user = null;
      _setStatus(AuthStatus.unauthenticated);
    } finally {
      _setLoading(false);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  void _setStatus(AuthStatus status) {
    _status = status;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _status = AuthStatus.error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }

  void _unawaited(Future<void> future) =>
      future.catchError((e) => debugPrint('Notification error: $e'));
}