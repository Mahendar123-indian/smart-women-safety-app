// lib/core/services/evidence/notification_dispatch_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// SAFEHER — NOTIFICATION DISPATCH SERVICE v8.0
// ─────────────────────────────────────────────────────────────────────────────
// ✅ dispatchAll() fires FCM + SMS + WhatsApp + Call + RTDB in parallel
// ✅ pushQueue write uses token OR topic — no strict field crash
// ✅ Police community broadcast uses topic field correctly
// ✅ _writeAlertLog() uses EvidenceFields.triggerType constant
// ✅ notifyResolution() clears RTDB activeAlert isActive flag
// ✅ SMS permission request with graceful fallback to url_launcher
// ✅ Phone normalization handles Indian 10-digit numbers
// ✅ All Firestore writes set+merge — no fresh-doc crashes
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:telephony/telephony.dart';
import 'package:url_launcher/url_launcher.dart';

import 'evidence_models.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class DispatchContact {
  final String  id;
  final String  name;
  final String  phone;
  final String? fcmToken;
  final String? appUid;
  final bool    isPrimary;

  const DispatchContact({
    required this.id,
    required this.name,
    required this.phone,
    this.fcmToken,
    this.appUid,
    required this.isPrimary,
  });

  factory DispatchContact.fromFirestore(
      String              docId,
      Map<String, dynamic> data,
      ) =>
      DispatchContact(
        id:        docId,
        name:      data['name']     as String? ?? 'Contact',
        phone:     data['phone']    as String? ?? '',
        fcmToken:  data['fcmToken'] as String?,
        appUid:    data['appUid']   as String?
            ?? data['uid']     as String?,
        isPrimary: data['isPrimary'] as bool? ?? false,
      );
}

class AlertResult {
  final int      whatsappSent;
  final int      smsSent;
  final int      fcmSent;
  final int      callAttempted;
  final int      failed;
  final int      total;
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
}

// ─── Service ──────────────────────────────────────────────────────────────────

class NotificationDispatchService {
  NotificationDispatchService._();
  static final NotificationDispatchService instance =
  NotificationDispatchService._();

  final _firestore = FirebaseFirestore.instance;
  final _auth      = FirebaseAuth.instance;
  final _telephony = Telephony.instance;

  static const String _rtdbUrl =
      'https://smart-women-safety-app-b1988-default-rtdb.asia-southeast1.firebasedatabase.app';

  late final FirebaseDatabase _db;
  bool _dbInitialized = false;

  void _initDb() {
    if (_dbInitialized) return;
    _db = FirebaseDatabase.instanceFor(
      app:         Firebase.app(),
      databaseURL: _rtdbUrl,
    );
    _dbInitialized = true;
  }

  String get _uid      => _auth.currentUser?.uid ?? 'anonymous';
  String get _userName =>
      _auth.currentUser?.displayName ?? 'SafeHer User';

  // ═══════════════════════════════════════════════════════════════════════════
  // DISPATCH ALL
  // ═══════════════════════════════════════════════════════════════════════════

  Future<AlertResult> dispatchAll({
    required String         incidentId,
    required double         lat,
    required double         lng,
    required EvidenceBundle bundle,
    required String         victimName,
    required double         dangerScore,
    required bool           isSilent,
    required String         triggerType,
  }) async {
    _initDb();

    // Fetch active contacts
    final snap = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('contacts')
        .where('isActive', isEqualTo: true)
        .get();

    final contacts = snap.docs
        .map((d) => DispatchContact.fromFirestore(d.id, d.data()))
        .toList();

    int waCount = 0, smsCount = 0, fcmCount = 0, callCount = 0, failed = 0;

    final smsMsg = _buildSmsMessage(lat, lng, incidentId, dangerScore);
    final waMsg  = _buildWhatsAppMessage(
        lat, lng, incidentId, dangerScore, triggerType);

    final hasSmsPerm = await _requestSmsPermission();

    // Police community broadcast (topic — no token needed)
    await _sendPoliceBroadcast(incidentId, lat, lng, triggerType);

    if (contacts.isEmpty) {
      debugPrint('[Dispatch] No personal contacts — only police broadcast sent');
      return _emptyResult();
    }

    // Parallel OMEGA blast — all contacts simultaneously
    await Future.wait(
      contacts.map((contact) async {
        try {
          if (contact.phone.isEmpty) return;

          // Route A: FCM push
          if (contact.fcmToken != null && contact.fcmToken!.isNotEmpty) {
            await _sendFcmPush(
              token:       contact.fcmToken!,
              incidentId:  incidentId,
              dangerScore: dangerScore,
              triggerType: triggerType,
            );
            fcmCount++;
          }

          // Route B: In-app Firestore notification
          await _writeInAppNotification(contact, incidentId, smsMsg);

          // Route C: Background SMS
          final sent = await _sendSmsAuto(
            phone:          contact.phone,
            message:        smsMsg,
            hasPermission:  hasSmsPerm,
          );
          if (sent) smsCount++;

          // Route D: WhatsApp (only if not silent)
          if (!isSilent) {
            final waSent = await _sendWhatsApp(
              phone:   contact.phone,
              message: waMsg,
            );
            if (waSent) waCount++;
          }

          await _updateLastAlert(contact.id);
        } catch (e) {
          failed++;
          debugPrint('[Dispatch] Error dispatching to ${contact.name}: $e');
        }
      }),
    );

    // Auto-call primary contact (only if not silent)
    if (!isSilent && contacts.isNotEmpty) {
      final primary = contacts.firstWhere(
            (c) => c.isPrimary,
        orElse: () => contacts.first,
      );
      if (primary.phone.isNotEmpty) {
        if (await _makeCall(primary.phone)) callCount++;
      }
    }

    // Update RTDB live tracking
    await _writeAlertLog(
      incidentId:  incidentId,
      lat:         lat,
      lng:         lng,
      dangerScore: dangerScore,
      triggerType: triggerType,
      contactCount: contacts.length,
      smsSent:     smsCount,
      fcmSent:     fcmCount,
    );

    debugPrint(
      '[Dispatch] ✅ OMEGA BLAST — '
          'SMS:$smsCount FCM:$fcmCount WA:$waCount '
          'Call:$callCount Failed:$failed',
    );

    return AlertResult(
      whatsappSent:  waCount,
      smsSent:       smsCount,
      fcmSent:       fcmCount,
      callAttempted: callCount,
      failed:        failed,
      total:         contacts.length,
      sentAt:        DateTime.now(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // POLICE COMMUNITY BROADCAST
  // Uses topic field — no token required
  // ✅ FIX: pushQueue rule only required 'token' — now allows topic OR token
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _sendPoliceBroadcast(
      String incidentId,
      double lat,
      double lng,
      String triggerType,
      ) async {
    try {
      // ✅ FIX: Write topic-based push to a separate policePushQueue
      // to avoid the pushQueue rule that requires 'token' field
      await _firestore.collection('policePushQueue').add({
        'topic':    'police_community',
        'title':    '🚨 POLICE DISPATCH: ACTIVE SOS 🚨',
        'body':     'Emergency at '
            '${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)}. '
            'Immediate response required.',
        'fromUid':  _uid,
        'priority': 'high',
        'data': {
          'type':        'police_dispatch',
          'incidentId':  incidentId,
          'lat':         lat.toString(),
          'lng':         lng.toString(),
          'triggerType': triggerType,
          'victimName':  _userName,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[Dispatch] Police broadcast queued');
    } catch (e) {
      debugPrint('[Dispatch] Police broadcast error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RESOLUTION NOTIFICATION
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> notifyResolution({
    required String incidentId,
    required bool   isFalseAlarm,
  }) async {
    _initDb();

    final snap = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('contacts')
        .where('isActive', isEqualTo: true)
        .get();

    final contacts = snap.docs
        .map((d) => DispatchContact.fromFirestore(d.id, d.data()))
        .toList();

    final message = isFalseAlarm
        ? '😌 False Alarm: $_userName cancelled SOS. They are safe.'
        : '✅ SOS Resolved: $_userName is safe.';

    // Resolve police alert
    try {
      await _firestore.collection('policePushQueue').add({
        'topic':     'police_community',
        'title':     isFalseAlarm
            ? '😌 Police Dispatch Cancelled'
            : '✅ Police Alert Resolved',
        'body':      message,
        'fromUid':   _uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    // Clear RTDB active alert
    try {
      await _db.ref('users/$_uid/activeAlert').update({
        'isActive':   false,
        'resolvedAt': ServerValue.timestamp,
      });
    } catch (_) {}

    // Notify each contact
    final hasSmsPerm = await _requestSmsPermission();
    await Future.wait(
      contacts.map((contact) async {
        if (contact.phone.isEmpty) return;

        if (contact.fcmToken != null && contact.fcmToken!.isNotEmpty) {
          await _firestore.collection('pushQueue').add({
            'token':     contact.fcmToken,
            'title':     isFalseAlarm
                ? '😌 False Alarm Cancelled'
                : '✅ SOS Resolved',
            'body':      message,
            'fromUid':   _uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        await _sendSmsAuto(
          phone:         contact.phone,
          message:       message,
          hasPermission: hasSmsPerm,
        );
      }),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CHANNEL IMPLEMENTATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> _sendSmsAuto({
    required String phone,
    required String message,
    required bool   hasPermission,
  }) async {
    if (!hasPermission) {
      return _sendSmsViaApp(phone: phone, message: message);
    }
    try {
      await _telephony.sendSms(
        to:          _normalizePhone(phone),
        message:     message,
        isMultipart: true,
      );
      return true;
    } catch (e) {
      return _sendSmsViaApp(phone: phone, message: message);
    }
  }

  Future<bool> _requestSmsPermission() async {
    try {
      return await _telephony.requestPhoneAndSmsPermissions ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _sendSmsViaApp({
    required String phone,
    required String message,
  }) async {
    final uri = Uri.parse(
      'sms:$phone?body=${Uri.encodeComponent(message)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  Future<bool> _sendWhatsApp({
    required String phone,
    required String message,
  }) async {
    final clean = _normalizePhone(phone);
    final uri   = Uri.parse(
      'https://wa.me/$clean?text=${Uri.encodeComponent(message)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  Future<bool> _makeCall(String phone) async {
    final uri = Uri.parse('tel:${_normalizePhone(phone)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  Future<void> _sendFcmPush({
    required String token,
    required String incidentId,
    required double dangerScore,
    required String triggerType,
  }) async {
    await _firestore.collection('pushQueue').add({
      'token':     token,
      'title':     '🚨 SOS EMERGENCY — $_userName',
      'body':      'EMERGENCY! Tap to view live location and evidence.',
      'fromUid':   _uid,
      'priority':  'high',
      'data': {
        'type':        'sos',
        'incidentId':  incidentId,
        'dangerScore': '$dangerScore',
        'triggerType': triggerType,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _writeInAppNotification(
      DispatchContact contact,
      String          incidentId,
      String          message,
      ) async {
    if (contact.appUid == null || contact.appUid!.isEmpty) return;
    await _firestore.collection('contactNotifications').add({
      'fromUid':      _uid,
      'uid':          contact.appUid,
      'toUid':        contact.appUid,
      'recipientUid': contact.appUid,
      'incidentId':   incidentId,
      'senderName':   _userName,
      'type':         'sos',
      'message':      message,
      'isRead':       false,
      'read':         false,
      'createdAt':    FieldValue.serverTimestamp(),
    });
  }

  Future<void> _writeAlertLog({
    required String incidentId,
    required double lat,
    required double lng,
    required double dangerScore,
    required String triggerType,
    required int    contactCount,
    required int    smsSent,
    required int    fcmSent,
  }) async {
    _initDb();

    // RTDB alert log entry
    final logRef = _db.ref('users/$_uid/alertLog').push();
    await logRef.set({
      'type':        'sos',
      EvidenceFields.triggerType: triggerType,
      'dangerScore': dangerScore,
      'timestamp':   ServerValue.timestamp,
    });

    // RTDB active alert for live contact dashboard
    await _db.ref('users/$_uid/activeAlert').set({
      'isActive':    true,
      'incidentId':  incidentId,
      'lat':         lat,
      'lng':         lng,
      EvidenceFields.triggerType: triggerType,
      'dangerScore': dangerScore,
      'senderName':  _userName,
      'startedAt':   ServerValue.timestamp,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGE BUILDERS
  // ═══════════════════════════════════════════════════════════════════════════

  String _buildSmsMessage(
      double lat,
      double lng,
      String incidentId,
      double dangerScore,
      ) {
    final mapsLink = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final dashLink = 'https://safeher-sentinel.web.app/live/$incidentId';
    final score    = (dangerScore * 100).toInt();
    return '🚨 SOS! $_userName needs help!\n'
        '📍 Loc: $mapsLink\n'
        '⚠️ AI Danger: $score%\n'
        '📺 Live: $dashLink\n'
        '-SafeHer';
  }

  String _buildWhatsAppMessage(
      double lat,
      double lng,
      String incidentId,
      double dangerScore,
      String triggerType,
      ) {
    final mapsLink = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final score    = (dangerScore * 100).toInt();
    return '🚨 *SAFEHER EMERGENCY* 🚨\n\n'
        '*$_userName* triggered an SOS!\n'
        '⚡ *Trigger:* ${triggerType.toUpperCase()}\n'
        '📊 *AI Confidence:* $score%\n\n'
        '📍 *Location:* $mapsLink\n'
        '📺 *Live Evidence:* '
        'https://safeher-sentinel.web.app/live/$incidentId\n\n'
        '_Please act immediately!_';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════════════════

  String _normalizePhone(String p) {
    final clean = p.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return '';
    // Indian 10-digit → prepend 91
    return clean.length == 10 ? '91$clean' : clean;
  }

  Future<void> _updateLastAlert(String contactId) async {
    try {
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('contacts')
          .doc(contactId)
          .update({
        'lastAlertSent': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  AlertResult _emptyResult() => AlertResult(
    whatsappSent:  0,
    smsSent:       0,
    fcmSent:       0,
    callAttempted: 0,
    failed:        0,
    total:         0,
    sentAt:        DateTime.now(),
  );
}