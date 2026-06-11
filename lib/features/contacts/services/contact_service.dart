// lib/features/contacts/services/contact_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// INDUSTRIAL SENTINEL — CONTACT SYNC & CRUD ENGINE v5.0 (2026 PRODUCTION)
// ─────────────────────────────────────────────────────────────────────────────
// ✅ [ARCHITECTURAL PURGE] Removed all duplicate alert dispatching logic.
//    Alerts are now strictly handled by ContactAlertService.
// ✅ [OPTIMIZATION] scanAndUpdateAppUsers now uses Firestore WriteBatch.
// ✅ [SECURITY] Perfected RTDB FCM token schema alignment.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/emergency_contact_model.dart';

class ContactService {
  ContactService._();
  static final ContactService instance = ContactService._();

  final _firestore = FirebaseFirestore.instance;

  final _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://smart-women-safety-app-b1988-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  final _auth = FirebaseAuth.instance;
  final _messaging = FirebaseMessaging.instance;

  String get _uid => _auth.currentUser?.uid ?? '';
  String get _userName => _auth.currentUser?.displayName ?? 'SafeHer User';

  CollectionReference get _ref =>
      _firestore.collection('users').doc(_uid).collection('contacts');

  // ═══════════════════════════════════════════════════════════════════════════
  // PERMISSIONS & DEVICE CONTACTS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> requestContactPermission() async {
    if (!await FlutterContacts.requestPermission()) return false;
    return true;
  }

  Future<bool> requestSmsPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  Future<bool> requestPhonePermission() async {
    final status = await Permission.phone.request();
    return status.isGranted;
  }

  Future<List<Contact>> fetchPhoneContacts() async {
    if (!await requestContactPermission()) return [];
    try {
      return await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
        withGroups: false,
        withAccounts: false,
      );
    } catch (e) {
      debugPrint('⚠️ [CONTACT SERVICE] Fetch device contacts failed: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FIRESTORE CRUD OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Stream<List<EmergencyContact>> streamContacts() => _ref
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs
      .map((d) => EmergencyContact.fromJson(d.data() as Map<String, dynamic>))
      .toList());

  Future<List<EmergencyContact>> getContacts() async {
    try {
      final s = await _ref.orderBy('createdAt').get();
      return s.docs
          .map((d) => EmergencyContact.fromJson(d.data() as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<EmergencyContact> addContact({
    required String name,
    required String phone,
    required String relation,
    bool isPrimary = false,
    String? photoUrl,
  }) async {
    if (isPrimary) await _clearPrimary();

    final appUid = await _findAppUser(phone);

    final doc = _ref.doc();
    final contact = EmergencyContact(
      id: doc.id,
      uid: _uid,
      name: name,
      phone: phone,
      relation: relation,
      isPrimary: isPrimary,
      photoUrl: photoUrl,
      appUid: appUid,
      isAppUser: appUid != null,
      createdAt: DateTime.now(),
    );

    await doc.set(contact.toJson());

    if (appUid == null) {
      await sendInviteSms(phone, name);
    } else {
      await _syncFcmToken(contact.id, appUid);
    }

    return contact;
  }

  Future<void> updateContact(EmergencyContact contact) async {
    if (contact.isPrimary) await _clearPrimary();
    await _ref.doc(contact.id).update(contact.toJson());
  }

  Future<void> deleteContact(String id) => _ref.doc(id).delete();

  Future<void> setPrimary(String id) async {
    await _clearPrimary();
    await _ref.doc(id).update({'isPrimary': true});
  }

  Future<void> toggleActive(String id, bool active) =>
      _ref.doc(id).update({'isActive': active});

  Future<void> updateFcmToken(String id, String token) =>
      _ref.doc(id).update({'fcmToken': token});

  Future<void> _clearPrimary() async {
    final snap = await _ref.where('isPrimary', isEqualTo: true).get();
    if (snap.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final d in snap.docs) {
      batch.update(d.reference, {'isPrimary': false});
    }
    await batch.commit();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SAFEHER NETWORK SYNCHRONIZATION
  // ═══════════════════════════════════════════════════════════════════════════

  Future<String?> _findAppUser(String phone) async {
    try {
      final normalized = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

      // Check normalized
      final snap = await _firestore.collection('users').where('phone', isEqualTo: normalized).limit(1).get();
      if (snap.docs.isNotEmpty) return snap.docs.first.id;

      // Check with +91 country code fallback
      final withPlus = normalized.startsWith('+') ? normalized : '+91$normalized';
      final snap2 = await _firestore.collection('users').where('phone', isEqualTo: withPlus).limit(1).get();

      return snap2.docs.isNotEmpty ? snap2.docs.first.id : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _syncFcmToken(String contactId, String appUid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(appUid).get();
      final token = userDoc.data()?['fcmToken'] as String?;
      if (token != null) {
        await _ref.doc(contactId).update({'fcmToken': token});
      }
    } catch (_) {}
  }

  /// Scans all saved contacts and updates their App User status if they recently joined.
  /// Uses a WriteBatch for optimized network efficiency.
  Future<int> scanAndUpdateAppUsers() async {
    final contacts = await getContacts();
    int updated = 0;
    final batch = _firestore.batch();

    for (final c in contacts) {
      if (!c.isAppUser) {
        final appUid = await _findAppUser(c.phone);
        if (appUid != null) {
          batch.update(_ref.doc(c.id), {
            'appUid':    appUid,
            'isAppUser': true,
          });

          // Still need to trigger token sync individually since we pull from other docs
          await _syncFcmToken(c.id, appUid);
          updated++;
        }
      }
    }

    if (updated > 0) await batch.commit();
    return updated;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FCM TOKEN MANAGEMENT (Device Owner)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> saveMyFcmToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null && _uid.isNotEmpty) {
        await _firestore.collection('users').doc(_uid).update({
          'fcmToken':      token,
          'fcmUpdatedAt':  FieldValue.serverTimestamp(),
        });

        // Exact match to RTDB Security Rules Schema
        await _db.ref('users/$_uid/fcmTokens').push().set({
          'token':     token,
          'updatedAt': ServerValue.timestamp,
        });
      }
    } catch (e) {
      debugPrint('⚠️ [CONTACT SERVICE] Save Token Error: $e');
    }
  }

  StreamSubscription listenFcmTokenRefresh() {
    return _messaging.onTokenRefresh.listen((token) async {
      try {
        await _firestore.collection('users').doc(_uid).update({
          'fcmToken':     token,
          'fcmUpdatedAt': FieldValue.serverTimestamp(),
        });
        await _db.ref('users/$_uid/fcmTokens').push().set({
          'token':     token,
          'updatedAt': ServerValue.timestamp,
        });
      } catch (_) {}
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> sendInviteSms(String phone, String name) async {
    final message =
        'Hi $name! $_userName has added you as an emergency contact on SafeHer '
        '(Women Safety App). Install at: https://safeher.app '
        'to stay connected and track their safety in real-time.';
    try {
      final encoded = Uri.encodeComponent(message);
      final uri = Uri.parse('sms:$phone?body=$encoded');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  Future<bool> callContact(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return true;
    }
    return false;
  }

  Future<List<String>> getActiveContactUids() async {
    final contacts = await getContacts();
    return contacts
        .where((c) => c.isActive && c.appUid != null)
        .map((c) => c.appUid!)
        .toList();
  }
}