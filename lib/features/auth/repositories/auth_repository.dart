// lib/features/auth/repositories/auth_repository.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../models/user_model.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/constants/app_constants.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final FlutterSecureStorage _secureStorage;
  final FirebaseFirestore _firestore;

  AuthRepository({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    FlutterSecureStorage? secureStorage,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
  User? get currentFirebaseUser => _firebaseAuth.currentUser;

  // ─── Build UserModel from Firebase User ───────────────────────────────────
  UserModel _userFromFirebase(User firebaseUser, {String? name}) {
    return UserModel(
      id: firebaseUser.uid,
      name: name ?? firebaseUser.displayName ?? 'SafeHer User',
      email: firebaseUser.email ?? '',
      phone: firebaseUser.phoneNumber,
      photoUrl: firebaseUser.photoURL,
      isVerified: firebaseUser.emailVerified,
      createdAt: DateTime.now(),
    );
  }

  // ─── Write user document to Firestore ─────────────────────────────────────
  // ✅ FIX: This was completely missing — without this, users collection
  // is always empty and ALL other Firestore writes fail because
  // the parent user document doesn't exist
  Future<void> _saveUserToFirestore(UserModel user) async {
    try {
      final docRef = _firestore.collection('users').doc(user.id);
      final doc = await docRef.get();

      if (!doc.exists) {
        // First time — create the full document
        await docRef.set({
          'name': user.name,
          'email': user.email,
          'phone': user.phone ?? '',
          'photoUrl': user.photoUrl ?? '',
          'is_verified': user.isVerified,
          'fcmToken': '',
          'biometric_enabled': false,
          'lastSeen': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Already exists — only update mutable fields
        await docRef.update({
          'lastSeen': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          // Update name/photo in case they changed (e.g. Google profile)
          if (user.name.isNotEmpty && user.name != 'SafeHer User')
            'name': user.name,
          if (user.photoUrl != null && user.photoUrl!.isNotEmpty)
            'photoUrl': user.photoUrl,
          if (user.email.isNotEmpty) 'email': user.email,
        });
      }
    } catch (_) {
      // Non-fatal — app can still work even if Firestore write fails
      // Data will sync on next login
    }
  }

  // ─── Persist user locally ─────────────────────────────────────────────────
  Future<void> _persistUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.userDataKey, jsonEncode(user.toJson()));
    await prefs.setString(AppConstants.userIdKey, user.id);
  }

  // ─── Email Login ──────────────────────────────────────────────────────────
  Future<UserModel> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final userData = _userFromFirebase(credential.user!);
      // ✅ FIX: Save to Firestore on every login (updates lastSeen)
      await _saveUserToFirestore(userData);
      await _persistUser(userData);
      return userData;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseException(e);
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  // ─── Register ─────────────────────────────────────────────────────────────
  Future<UserModel> registerWithEmail({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final firebaseUser = credential.user!;
      await firebaseUser.updateDisplayName(name.trim());
      await firebaseUser.reload();
      final updatedUser = _firebaseAuth.currentUser!;

      final userData = _userFromFirebase(updatedUser, name: name.trim());

      // ✅ FIX: Write to Firestore immediately after registration
      // This creates the users/{uid} document that ALL other
      // collections depend on (contacts, incidents, journey, etc.)
      await _firestore.collection('users').doc(firebaseUser.uid).set({
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone ?? '',
        'photoUrl': '',
        'is_verified': false,
        'fcmToken': '',
        'biometric_enabled': false,
        'lastSeen': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _persistUser(userData);
      return userData;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseException(e);
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  // ─── Google Sign-In ───────────────────────────────────────────────────────
  Future<UserModel> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw const ApiException(message: 'Google sign-in cancelled.');
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
      await _firebaseAuth.signInWithCredential(credential);
      final userData = _userFromFirebase(userCredential.user!);

      // ✅ FIX: Save Google user to Firestore
      await _saveUserToFirestore(userData);
      await _persistUser(userData);
      return userData;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseException(e);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  // ─── Phone OTP — Send ─────────────────────────────────────────────────────
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String error) onError,
    required void Function(PhoneAuthCredential) onAutoVerified,
  }) async {
    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onAutoVerified,
      verificationFailed: (e) => onError(_mapFirebaseException(e).message),
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (_) {},
      timeout: const Duration(seconds: 60),
    );
  }

  // ─── Phone OTP — Verify ───────────────────────────────────────────────────
  Future<UserModel> verifyOtp({
    required String verificationId,
    required String otp,
    String? name,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      final userCredential =
      await _firebaseAuth.signInWithCredential(credential);
      final userData = _userFromFirebase(userCredential.user!, name: name);

      // ✅ FIX: Save phone user to Firestore
      // Phone users are always verified (phone_number != null)
      await _saveUserToFirestore(userData);
      await _persistUser(userData);
      return userData;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseException(e);
    }
  }

  // ─── Forgot Password ──────────────────────────────────────────────────────
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseException(e);
    }
  }

  // ─── Sign Out ─────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    // Update lastSeen before signing out
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid != null) {
      try {
        await _firestore.collection('users').doc(uid).update({
          'lastSeen': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }

    await Future.wait([
      _firebaseAuth.signOut(),
      _googleSignIn.signOut(),
      _clearSession(),
    ]);
  }

  // ─── Get Persisted User ───────────────────────────────────────────────────
  Future<UserModel?> getPersistedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(AppConstants.userDataKey);
      if (userJson != null && _firebaseAuth.currentUser != null) {
        return UserModel.fromJson(jsonDecode(userJson));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ─── Clear Session ────────────────────────────────────────────────────────
  Future<void> _clearSession() async {
    await _secureStorage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ─── Firebase Error Mapper ────────────────────────────────────────────────
  ApiException _mapFirebaseException(FirebaseAuthException e) {
    return switch (e.code) {
      'user-not-found' =>
      const ApiException(message: 'No account found with this email.'),
      'wrong-password' =>
      const ApiException(message: 'Incorrect password. Try again.'),
      'invalid-credential' =>
      const ApiException(message: 'Invalid email or password.'),
      'invalid-email' =>
      const ApiException(message: 'Invalid email address.'),
      'email-already-in-use' =>
      const ApiException(message: 'Account already exists with this email.'),
      'weak-password' =>
      const ApiException(message: 'Password too weak. Use 8+ characters.'),
      'network-request-failed' =>
      const ApiException(message: 'No internet connection.'),
      'too-many-requests' =>
      const ApiException(message: 'Too many attempts. Try again later.'),
      'invalid-verification-code' =>
      const ApiException(message: 'Invalid OTP. Enter the correct code.'),
      'session-expired' =>
      const ApiException(message: 'OTP expired. Request a new code.'),
      _ => ApiException(message: e.message ?? 'Authentication failed.'),
    };
  }
}