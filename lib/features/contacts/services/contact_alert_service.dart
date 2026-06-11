// lib/features/contacts/services/contact_alert_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// INDUSTRIAL SENTINEL — MULTIPATH CONTACT ALERT SERVICE v5.0 (2026 PRODUCTION)
// ─────────────────────────────────────────────────────────────────────────────
// ✅ [FIXED] Firestore Schema Alignment: Added recipientUid for strict Security Rules.
// ✅ [FIXED] RTDB Schema Alignment: Matched dangerScore & triggerType keys exactly.
// ✅ [FIXED] URL Interpolation: Repaired Google Maps link generation.
// ✅ [FIXED] Math Precedence: Corrected Danger Score percentage calculations.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:telephony/telephony.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/emergency_contact_model.dart';

// ─── Alert Configuration ─────────────────────────────────────────────────────

enum AlertType {
  sos, journeyStart, journeyOverdue, safeArrival, locationShare,
  batteryLow, signalLost, dangerZone, deadManSwitch, nightDeparture,
  geofenceExit, geofenceEnter, speedAnomaly,
}

class AlertPayload {
  final AlertType type;
  final double?   lat;
  final double?   lng;
  final String?   address;
  final String?   destination;
  final int?      estimatedMinutes;
  final int?      batteryLevel;
  final String?   customMessage;
  final String?   incidentId;
  final double?   dangerScore;
  final String?   triggerType; // 'manual', 'silent', 'shake', 'voice', 'auto_ml'

  const AlertPayload({
    required this.type,
    this.lat, this.lng, this.address, this.destination,
    this.estimatedMinutes, this.batteryLevel, this.customMessage,
    this.incidentId, this.dangerScore, this.triggerType,
  });
}

class AlertResult {
  final int whatsappSent;
  final int smsSent;
  final int fcmSent;
  final int callAttempted;
  final int failed;
  final int total;
  final DateTime sentAt;

  const AlertResult({
    required this.whatsappSent,
    required this.smsSent,
    required this.fcmSent,
    required this.callAttempted,
    required this.failed,
    required this.total,
    required this.sentAt,
  });

  String get summary => '🚨 Alert: $total contacts | SMS:$smsSent Push:$fcmSent | Success Rate: ${total > 0 ? ((total-failed)/total*100).toInt() : 0}%';
}

// ─── Alert Dispatcher ────────────────────────────────────────────────────────

class ContactAlertService {
  ContactAlertService._();
  static final ContactAlertService instance = ContactAlertService._();

  final _firestore = FirebaseFirestore.instance;
  final _auth      = FirebaseAuth.instance;
  final _telephony = Telephony.instance;

  static const String _rtdbUrl = 'https://smart-women-safety-app-b1988-default-rtdb.asia-southeast1.firebasedatabase.app';
  late final FirebaseDatabase _db;
  bool _dbInitialized = false;

  void _initDb() {
    if (_dbInitialized) return;
    _db = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: _rtdbUrl);
    _dbInitialized = true;
  }

  String get _uid      => _auth.currentUser?.uid ?? 'anonymous_sentinel';
  String get _userName => _auth.currentUser?.displayName ?? 'SafeHer User';

  // ═══════════════════════════════════════════════════════════════
  // MASTER MULTIPATH DISPATCH
  // ═══════════════════════════════════════════════════════════════

  Future<AlertResult> dispatch({
    required AlertPayload payload,
    required List<EmergencyContact> contacts,
    bool callPrimary = false,
  }) async {
    _initDb();
    final active = contacts.where((c) => c.isActive).toList();
    if (active.isEmpty) return _emptyResult();

    int waCount = 0, smsCount = 0, fcmCount = 0, callCount = 0, failed = 0;

    final smsMessage = _buildSmsMessage(payload);
    final waMessage  = _buildWhatsAppMessage(payload);
    final hasSmsPermission = await _requestSmsPermission();

    // Fire all contacts in PARALLEL for maximum execution speed
    await Future.wait(active.map((contact) async {
      try {
        // 1. FCM Push (Industrial standard for smart-notification)
        if (contact.fcmToken != null && contact.fcmToken!.isNotEmpty) {
          await _sendFcmPush(token: contact.fcmToken!, payload: payload);
          fcmCount++;
        }

        // 2. Persistent Firestore Notification (Forensic Log)
        await _writeInAppNotification(contact, payload);

        // 3. Background SMS (Telephony - No User Action Required)
        final smsSent = await _sendSmsAuto(
          phone: contact.phone,
          message: smsMessage,
          hasPermission: hasSmsPermission,
        );
        if (smsSent) smsCount++;

        // 4. WhatsApp (Manual User Intent Fallback)
        if (payload.type == AlertType.sos) {
          final waSent = await _sendWhatsApp(phone: contact.phone, message: waMessage);
          if (waSent) waCount++;
        }

        await _updateLastAlert(contact.id);
      } catch (e) {
        failed++;
        debugPrint('❌ Dispatch Error to ${contact.name}: $e');
      }
    }));

    // 5. Automated Emergency Call
    if (callPrimary && active.isNotEmpty) {
      final primary = active.firstWhere((c) => c.isPrimary, orElse: () => active.first);
      if (await _makeCall(primary.phone)) callCount++;
    }

    // 6. RTDB Sentinel Sync
    await _writeAlertLog(payload, active.length, smsCount, fcmCount);

    return AlertResult(
      whatsappSent: waCount, smsSent: smsCount, fcmSent: fcmCount,
      callAttempted: callCount, failed: failed, total: active.length, sentAt: DateTime.now(),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // MANUAL SHARING METHODS
  // ═══════════════════════════════════════════════════════════════

  /// Opens WhatsApp for manual live location sharing
  Future<void> shareLiveLocationLink({required double lat, required double lng, String? address}) async {
    final mapsLink = 'https://maps.google.com/?q=$lat,$lng';
    final text = '📍 *Live location shared by $_userName*\n'
        '${address ?? ""}\n'
        '🗺️ View: $mapsLink\n\n'
        '_Sent via SafeHer App_';
    await _sendWhatsApp(phone: '', message: text, isGeneric: true);
  }

  /// Opens system share sheet/SMS for manual location sharing
  Future<void> shareViaAnyApp({required double lat, required double lng, String? address}) async {
    final mapsLink = 'https://maps.google.com/?q=$lat,$lng';
    final text = '📍 SafeHer Alert: $_userName\'s location: $mapsLink';
    final uri = Uri.parse('sms:?body=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // SMS AUTO-SEND ENGINE (Telephony)
  // ═══════════════════════════════════════════════════════════════

  Future<bool> _sendSmsAuto({required String phone, required String message, required bool hasPermission}) async {
    if (!hasPermission) return _sendSmsViaApp(phone: phone, message: message);
    try {
      await _telephony.sendSms(to: _normalizePhone(phone), message: message, isMultipart: true);
      return true;
    } catch (e) {
      return _sendSmsViaApp(phone: phone, message: message);
    }
  }

  Future<bool> _requestSmsPermission() async {
    try {
      return await _telephony.requestPhoneAndSmsPermissions ?? false;
    } catch (_) { return false; }
  }

  Future<bool> _sendSmsViaApp({required String phone, required String message}) async {
    final uri = Uri.parse('sms:$phone?body=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  // ═══════════════════════════════════════════════════════════════
  // WHATSAPP & CALLING
  // ═══════════════════════════════════════════════════════════════

  Future<bool> _sendWhatsApp({required String phone, required String message, bool isGeneric = false}) async {
    final cleanPhone = isGeneric ? "" : _normalizePhone(phone);
    final waUri = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(waUri)) {
      await launchUrl(waUri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  Future<bool> _makeCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  // ═══════════════════════════════════════════════════════════════
  // BACKEND SYNCHRONIZATION (FCM / Firestore / RTDB)
  // ═══════════════════════════════════════════════════════════════

  Future<void> _sendFcmPush({required String token, required AlertPayload payload}) async {
    await _firestore.collection('pushQueue').add({
      'token': token,
      'title': _pushTitle(payload.type),
      'body': _pushBody(payload),
      'fromUid': _uid,
      'priority': 'high',
      'data': {
        'type': payload.type.name,
        'incidentId': payload.incidentId ?? '',
        'dangerScore': '${payload.dangerScore ?? 0.0}',
        'triggerType': payload.triggerType ?? 'manual',
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _writeInAppNotification(EmergencyContact contact, AlertPayload payload) async {
    if (contact.appUid == null) return;

    await _firestore.collection('contactNotifications').add({
      'fromUid': _uid,
      'toUid': contact.appUid,
      'uid': contact.appUid,               // ✅ FIX 2: Added to ensure rules match seamlessly
      'recipientUid': contact.appUid,      // ✅ FIX 2: Required by Firestore query rules
      'incidentId': payload.incidentId ?? '',
      'senderName': _userName,
      'type': payload.type.name,
      'message': _buildSmsMessage(payload),
      'isRead': false,
      'read': false,                       // Legacy support for backwards compatibility
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _writeAlertLog(AlertPayload p, int contacts, int sms, int fcm) async {
    _initDb();

    // 1. Write to the historical log
    final logRef = _db.ref('users/$_uid/alertLog').push();
    await logRef.set({
      'type': p.type.name,
      'triggerType': p.triggerType ?? 'manual', // ✅ FIX 1: Matched to RTDB rules
      'dangerScore': p.dangerScore ?? 0.0,      // ✅ FIX 1: Matched to RTDB rules
      'timestamp': ServerValue.timestamp,
    });

    // 2. Broadcast active status
    if (p.type == AlertType.sos) {
      await _db.ref('users/$_uid/activeAlert').set({
        'isActive': true,
        'incidentId': p.incidentId ?? '',
        'lat': p.lat ?? 0.0,
        'lng': p.lng ?? 0.0,
        'triggerType': p.triggerType ?? 'manual', // ✅ FIX 1: Matched to RTDB rules
        'dangerScore': p.dangerScore ?? 0.0,      // ✅ FIX 1: Matched to RTDB rules
        'senderName': _userName,
        'startedAt': ServerValue.timestamp,
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // MESSAGE BUILDERS (SENTINEL STANDARDS)
  // ═══════════════════════════════════════════════════════════════

  String _buildSmsMessage(AlertPayload p) {
    // ✅ FIX 3: Fixed malformed URL interpolation
    final maps = p.lat != null ? 'https://maps.google.com/?q=${p.lat},${p.lng}' : '';
    final dash = p.incidentId != null ? 'Live: https://safeher-sentinel.web.app/live/${p.incidentId}' : '';

    // ✅ FIX 4: Corrected math precedence
    final score = p.dangerScore != null ? 'AI Danger: ${((p.dangerScore ?? 0.0) * 100).toInt()}%' : '';

    switch (p.type) {
      case AlertType.sos:
        return '🚨 SOS! $_userName needs help!\n📍 $maps\n$score\n$dash\n-SafeHer';
      case AlertType.speedAnomaly:
        return '🚨 SPEED ALERT: $_userName may be in a forced vehicle!\n📍 $maps\n-SafeHer';
      default:
        return '📍 Alert from $_userName: ${p.type.name}\n$maps';
    }
  }

  String _buildWhatsAppMessage(AlertPayload p) {
    // ✅ FIX 3: Fixed malformed URL interpolation
    final maps = 'https://maps.google.com/?q=${p.lat},${p.lng}';

    return '🚨 *SAFEHER EMERGENCY* 🚨\n\n'
        '*$_userName* triggered an SOS!\n'
        '⚡ *Trigger:* ${p.triggerType?.toUpperCase() ?? "MANUAL"}\n'
        '📊 *AI Confidence:* ${((p.dangerScore ?? 0.0) * 100).toInt()}%\n\n' // ✅ FIX 4
        '📍 *Location:* $maps\n'
        '📺 *Live Evidence:* https://safeher-sentinel.web.app/live/${p.incidentId}\n\n'
        '_Please act immediately!_';
  }

  String _pushTitle(AlertType t) => '🚨 ${t.name.toUpperCase()} — $_userName';
  String _pushBody(AlertPayload p) => 'EMERGENCY! Tap for live forensic audio & location.';

  String _normalizePhone(String p) {
    final clean = p.replaceAll(RegExp(r'[^\d]'), '');
    return clean.length == 10 ? '91$clean' : clean;
  }

  Future<void> _updateLastAlert(String cid) async {
    await _firestore.collection('users').doc(_uid).collection('contacts').doc(cid).update({
      'lastAlertSent': DateTime.now().millisecondsSinceEpoch,
    });
  }

  AlertResult _emptyResult() => AlertResult(whatsappSent: 0, smsSent: 0, fcmSent: 0, callAttempted: 0, failed: 0, total: 0, sentAt: DateTime.now());
}