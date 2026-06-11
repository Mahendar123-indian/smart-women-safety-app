// lib/core/services/notification_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// INDUSTRIAL SENTINEL — MASTER NOTIFICATION ENGINE v5.0
// ─────────────────────────────────────────────────────────────────────────────
// ✅ [FIXED] Replaced default '@mipmap/ic_launcher' with '@drawable/ic_notification'
//    to ensure compliance with Android's monochromatic icon guidelines.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SafeHerNotifType {
  loginSuccess, logoutSuccess, sosCountdown, sosActive, sosShakeDetected,
  sosAiDetected, sosSilentActive, sosResolved, sosFalseAlarm, contactAdded,
  contactDeleted, contactSetPrimary, contactDeactivated, contactReactivated,
  contactSosAlertSent, contactOnApp, locationSharingOn, locationSharingOff,
  journeyStarted, journeyArrived, journeyOverdue, journeyCancelled,
  geofenceEntered, geofenceExited, dangerZoneNearby, dangerZoneReported,
  profileSaved, pinChanged, biometricEnabled, biometricDisabled,
  thresholdChanged, appProtectionOn, offlineSosSynced, backgroundTrackingOn,
  backgroundTrackingOff,
}

class _Channels {
  static const sos      = 'safeher_sos';
  static const journey  = 'safeher_journey';
  static const contact  = 'safeher_contact';
  static const location = 'safeher_location';
  static const system   = 'safeher_system';
}

class NotifPayload {
  final String title;
  final String body;
  final String channel;
  final Importance importance;
  final Priority priority;
  final bool ongoing;
  final bool fullScreen;
  final int id;
  final Color color;
  final String? bigText;
  final bool vibrate;
  final bool sound;
  final String firestoreType;

  const NotifPayload({
    required this.title,
    required this.body,
    required this.channel,
    required this.importance,
    required this.priority,
    required this.firestoreType,
    this.ongoing = false,
    this.fullScreen = false,
    this.id = 0,
    this.color = const Color(0xFF6C3EE8),
    this.bigText,
    this.vibrate = true,
    this.sound = true,
  });
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin   = FlutterLocalNotificationsPlugin();
  final _firestore = FirebaseFirestore.instance;
  String get _uid  => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _name => FirebaseAuth.instance.currentUser?.displayName ?? 'User';

  bool _initialized = false;

  static const int _idSosOngoing     = 1000;
  static const int _idSosCountdown   = 1001;
  static const int _idJourneyOngoing = 1002;
  static const int _idJourneyOverdue = 1003;
  static const int _idDangerZone     = 1004;
  static const int _idLocationShare  = 1005;
  static int _autoId = 2000;
  static int get _nextId => ++_autoId;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // ✅ CRITICAL FIX: Forces Android to use the transparent icon asset instead of the Flutter logo
    const android = AndroidInitializationSettings('@drawable/ic_notification');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onTapped,
    );
    await _createAllChannels();
  }

  Future<void> _createAllChannels() async {
    final plugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (plugin == null) return;

    final channels = [
      const AndroidNotificationChannel(_Channels.sos, 'SOS Alerts', description: 'Critical emergency SOS notifications', importance: Importance.max, enableVibration: true, playSound: true, showBadge: true),
      const AndroidNotificationChannel(_Channels.journey, 'Journey Alerts', description: 'Journey tracking and arrival alerts', importance: Importance.high, enableVibration: true, playSound: true, showBadge: true),
      const AndroidNotificationChannel(_Channels.contact, 'Guardian Alerts', description: 'Emergency contact activity', importance: Importance.defaultImportance, enableVibration: true, playSound: true),
      const AndroidNotificationChannel(_Channels.location, 'Location Tracking', description: 'Live location and geofence alerts', importance: Importance.low, enableVibration: false, playSound: false),
      const AndroidNotificationChannel(_Channels.system, 'SafeHer System', description: 'App status and general updates', importance: Importance.low, enableVibration: false, playSound: false),
    ];

    for (final ch in channels) {
      await plugin.createNotificationChannel(ch);
    }
  }

  void _onTapped(NotificationResponse response) {}

  Future<void> _show(NotifPayload p) async {
    await init();
    try {
      final androidDetails = AndroidNotificationDetails(
        p.channel,
        _channelName(p.channel),
        channelDescription: _channelDesc(p.channel),
        importance: p.importance,
        priority: p.priority,
        ongoing: p.ongoing,
        autoCancel: !p.ongoing,
        fullScreenIntent: p.fullScreen,
        color: p.color,
        enableVibration: p.vibrate,
        playSound: p.sound,
        // ✅ CRITICAL FIX: Ensure the icon is hardcoded here as well
        icon: '@drawable/ic_notification',
        styleInformation: p.bigText != null ? BigTextStyleInformation(p.bigText!) : null,
        category: p.fullScreen ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.message,
        visibility: p.fullScreen ? NotificationVisibility.public : NotificationVisibility.private,
        showWhen: true,
      );
      final iosDetails = DarwinNotificationDetails(
        presentAlert: true, presentBadge: true, presentSound: p.sound,
        interruptionLevel: p.fullScreen ? InterruptionLevel.critical : InterruptionLevel.active,
      );
      await _plugin.show(
        p.id > 0 ? p.id : _nextId,
        p.title, p.body,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
      );
    } catch (_) {}
  }

  Future<void> _cancel(int id) async => _plugin.cancel(id);

  Future<void> _saveToFirestore({required String title, required String body, required String type, Map<String, dynamic> extra = const {}}) async {
    if (_uid.isEmpty) return;
    try {
      await _firestore.collection('contactNotifications').add({
        'recipientUid': _uid, 'fromUid': _uid, 'senderName': _name,
        'title': title, 'body': body, 'message': body,
        'type': type, 'category': type, 'isRead': false, 'read': false,
        'createdAt': FieldValue.serverTimestamp(), ...extra,
      });
    } catch (_) {}
  }

  String _channelName(String id) => switch (id) {
    _Channels.sos => 'SOS Alerts', _Channels.journey => 'Journey Alerts',
    _Channels.contact => 'Guardian Alerts', _Channels.location => 'Location Tracking',
    _ => 'SafeHer System',
  };

  String _channelDesc(String id) => switch (id) {
    _Channels.sos => 'Critical emergency SOS notifications', _Channels.journey => 'Journey tracking and arrival alerts',
    _Channels.contact => 'Emergency contact activity', _Channels.location => 'Live location and geofence alerts',
    _ => 'App status and general updates',
  };

  // ═══════════════════════════════════════════════════════════
  // ─── AUTH NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════
  Future<void> showLoginSuccess({required String name}) async {
    await _show(NotifPayload(id: _nextId, title: '🛡️ Welcome back, $name!', body: 'SafeHer AI is now protecting you. Stay safe today! 💜', bigText: 'SafeHer is actively monitoring your safety. AI danger detection, shake SOS, and live tracking are all active.', channel: _Channels.system, importance: Importance.defaultImportance, priority: Priority.defaultPriority, firestoreType: 'system_login', color: const Color(0xFF6C3EE8), vibrate: false, sound: false));
    await _saveToFirestore(title: '🛡️ Welcome back, $name!', body: 'SafeHer AI is now protecting you. Stay safe today! 💜', type: 'system_login');
  }

  Future<void> showLogoutSuccess() async {
    await _show(NotifPayload(id: _nextId, title: '👋 Signed out of SafeHer', body: 'Your data is encrypted and secure. Stay safe!', channel: _Channels.system, importance: Importance.low, priority: Priority.low, firestoreType: 'system_logout', vibrate: false, sound: false));
  }

  // ═══════════════════════════════════════════════════════════
  // ─── SOS NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════
  Future<void> showSosCountdown({required int seconds, required String triggerType}) async {
    final trigger = switch (triggerType) { 'shake' => '📳 Shake detected', 'auto_ml' => '🤖 AI danger detected', 'silent' => '🤫 Silent SOS', _ => '👆 Manual trigger' };
    await _show(NotifPayload(id: _idSosCountdown, title: '⚡ SOS activating in ${seconds}s — TAP TO CANCEL', body: '$trigger · Hold volume-down to cancel', bigText: '$trigger · SafeHer SOS will alert all your guardians via SMS and push notification in $seconds seconds. Open the app immediately to cancel if this is a mistake.', channel: _Channels.sos, importance: Importance.max, priority: Priority.max, fullScreen: true, color: const Color(0xFFFF1744), firestoreType: 'sos'));
  }

  Future<void> dismissSosCountdown() async => _cancel(_idSosCountdown);

  Future<void> showSosActive({required int contactsCount, required String address, required String triggerType}) async {
    final triggerLabel = switch (triggerType) { 'shake' => 'Shake SOS', 'auto_ml' => 'AI Auto-SOS', 'silent' => 'Silent SOS', _ => 'Manual SOS' };
    await _cancel(_idSosCountdown);
    await _show(NotifPayload(id: _idSosOngoing, title: '🚨 SOS ACTIVE — EMERGENCY ALERT', body: '$contactsCount guardian${contactsCount == 1 ? '' : 's'} alerted · $address', bigText: '🚨 $triggerLabel is ACTIVE!\n\n📍 Location: $address\n👥 $contactsCount contact${contactsCount == 1 ? '' : 's'} notified via SMS & push\n📹 Evidence recording in progress\n\nOpen SafeHer to resolve when safe.', channel: _Channels.sos, importance: Importance.max, priority: Priority.max, ongoing: true, fullScreen: true, color: const Color(0xFFFF1744), firestoreType: 'sos'));
    await _saveToFirestore(title: '🚨 SOS ACTIVE — $triggerLabel', body: '$contactsCount guardian${contactsCount == 1 ? '' : 's'} alerted · $address', type: 'sos', extra: {'address': address, 'triggerType': triggerType, 'contactCount': contactsCount});
  }

  Future<void> showSosResolved({required String address, required bool isFalseAlarm, required int durationSeconds}) async {
    await _cancel(_idSosOngoing);
    final mins = durationSeconds ~/ 60; final secs = durationSeconds % 60;
    final duration = mins > 0 ? '${mins}m ${secs}s' : '${secs}s';
    if (isFalseAlarm) {
      await _show(NotifPayload(id: _nextId, title: '😌 False Alarm — SOS Cancelled', body: 'All guardians notified you\'re safe. Duration: $duration', bigText: '😌 False alarm cancelled safely.\n\n📍 Location: $address\n⏱️ Active for: $duration\n✅ All guardians notified — You\'re safe!\n\nSafeHer AI is still monitoring for your safety.', channel: _Channels.sos, importance: Importance.high, priority: Priority.high, color: const Color(0xFFFF9800), firestoreType: 'sos'));
      await _saveToFirestore(title: '😌 False Alarm — SOS Cancelled', body: 'All guardians notified you\'re safe. Duration: $duration', type: 'sos', extra: {'isFalseAlarm': true, 'duration': durationSeconds});
    } else {
      await _show(NotifPayload(id: _nextId, title: '✅ You\'re safe now — SOS Resolved', body: 'Emergency over. Guardians notified. Duration: $duration', bigText: '✅ SafeHer SOS resolved successfully.\n\n📍 Location: $address\n⏱️ Emergency duration: $duration\n📨 All guardians notified — You\'re okay!\n📁 Evidence saved securely to your account.\n\nThank you for using SafeHer. Stay safe! 💜', channel: _Channels.sos, importance: Importance.high, priority: Priority.high, color: const Color(0xFF00C853), firestoreType: 'sos'));
      await _saveToFirestore(title: '✅ You\'re safe now — SOS Resolved', body: 'Emergency over. All guardians notified. Duration: $duration', type: 'sos', extra: {'isFalseAlarm': false, 'duration': durationSeconds});
    }
  }

  Future<void> showShakeDetected() async {
    await _show(NotifPayload(id: _nextId, title: '📳 Shake Detected — SOS Activating!', body: 'Shake your phone again to trigger immediately, or open app to cancel', channel: _Channels.sos, importance: Importance.max, priority: Priority.max, fullScreen: true, color: const Color(0xFFFF1744), firestoreType: 'sos'));
  }

  Future<void> showAiDangerDetected({required int scorePercent}) async {
    await _show(NotifPayload(id: _nextId, title: '🤖 AI Danger Detected — $scorePercent% Risk', body: 'Suspicious motion pattern detected. SOS activating in 5 seconds', bigText: '🤖 SafeHer AI detected a suspicious activity pattern.\n\n⚠️ Danger score: $scorePercent%\n📱 Open app immediately to cancel if you\'re safe\n🚨 SOS will activate automatically in 5 seconds', channel: _Channels.sos, importance: Importance.max, priority: Priority.max, fullScreen: true, color: const Color(0xFFFF1744), firestoreType: 'sos'));
    await _saveToFirestore(title: '🤖 AI Danger Detected — $scorePercent% Risk', body: 'Suspicious motion pattern. SOS activating automatically.', type: 'sos', extra: {'dangerScore': scorePercent, 'triggerType': 'auto_ml'});
  }

  Future<void> showEvidenceSaved({required String evidenceType}) async {
    final label = switch (evidenceType) { 'audio' => '🎤 Audio recording (60s) saved', 'photo' => '📸 Photo burst (3 photos) saved', 'video' => '🎥 Video evidence (30s) saved', _ => '📎 Evidence saved' };
    await _show(NotifPayload(id: _nextId, title: '$label securely', body: 'Uploaded to your encrypted cloud storage', channel: _Channels.system, importance: Importance.low, priority: Priority.low, firestoreType: 'system', vibrate: false, sound: false));
  }

  // ═══════════════════════════════════════════════════════════
  // ─── CONTACT NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════
  Future<void> showContactAdded({required String name, required String relation, required bool isAppUser, required bool isPrimary}) async {
    final appStatus = isAppUser ? '📱 On SafeHer — real-time location tracking enabled' : '📩 Invite SMS sent to join SafeHer';
    final primaryNote = isPrimary ? ' · ⭐ Set as primary guardian' : '';
    await _show(NotifPayload(id: _nextId, title: '👥 $name added as guardian!', body: '$relation · $appStatus$primaryNote', bigText: '👥 $name ($relation) is now your emergency guardian.\n\n$appStatus\n${isPrimary ? '⭐ Set as primary contact — first to be alerted\n' : ''}🚨 Will receive SMS + push notification during SOS\n📍 Can track your live location when sharing', channel: _Channels.contact, importance: Importance.high, priority: Priority.high, color: const Color(0xFF6C3EE8), firestoreType: 'contact'));
    await _saveToFirestore(title: '👥 $name added as guardian!', body: '$relation · $appStatus$primaryNote', type: 'contact_added', extra: {'contactName': name, 'relation': relation, 'isAppUser': isAppUser, 'isPrimary': isPrimary});
  }

  Future<void> showContactDeleted({required String name}) async {
    await _show(NotifPayload(id: _nextId, title: '🗑️ $name removed from guardians', body: 'This contact will no longer receive SOS alerts', channel: _Channels.contact, importance: Importance.defaultImportance, priority: Priority.defaultPriority, color: const Color(0xFFFF9800), firestoreType: 'contact', vibrate: false));
    await _saveToFirestore(title: '🗑️ $name removed from guardians', body: 'This contact will no longer receive your SOS alerts', type: 'contact_deleted', extra: {'contactName': name});
  }

  Future<void> showContactSetPrimary({required String name}) async {
    await _show(NotifPayload(id: _nextId, title: '⭐ $name is your primary guardian!', body: 'First contact alerted in every SOS emergency', channel: _Channels.contact, importance: Importance.defaultImportance, priority: Priority.defaultPriority, color: const Color(0xFF6C3EE8), firestoreType: 'contact'));
    await _saveToFirestore(title: '⭐ $name is now primary guardian', body: 'First contact alerted in every SOS emergency', type: 'contact', extra: {'contactName': name, 'action': 'set_primary'});
  }

  Future<void> showContactToggled({required String name, required bool isNowActive}) async {
    final title = isNowActive ? '✅ $name reactivated' : '⚪ $name deactivated';
    final body = isNowActive ? 'Will now receive SOS alerts and location updates' : 'Paused — won\'t receive alerts until reactivated';
    await _show(NotifPayload(id: _nextId, title: title, body: body, channel: _Channels.contact, importance: Importance.defaultImportance, priority: Priority.defaultPriority, color: isNowActive ? const Color(0xFF00C853) : const Color(0xFF9E9E9E), firestoreType: 'contact', vibrate: false));
    await _saveToFirestore(title: title, body: body, type: 'contact', extra: {'contactName': name, 'isActive': isNowActive});
  }

  Future<void> showSosSentToContacts({required int contactsReached, required int totalContacts, required String address}) async {
    await _show(NotifPayload(id: _nextId, title: '📨 SOS sent to $contactsReached/$totalContacts guardians!', body: '📍 $address · SMS + Push sent', bigText: '📨 Emergency alert delivered!\n\n✅ $contactsReached of $totalContacts guardians notified\n📍 Location shared: $address\n📱 SMS + Push notification delivered\n🔄 Location updates every 8 seconds', channel: _Channels.sos, importance: Importance.high, priority: Priority.high, color: const Color(0xFFFF1744), firestoreType: 'sos'));
  }

  Future<void> showNewAppUsersFound({required int count}) async {
    await _show(NotifPayload(id: _nextId, title: '🎉 $count contact${count == 1 ? '' : 's'} joined SafeHer!', body: 'Real-time location tracking now enabled for ${count == 1 ? 'them' : 'all of them'}', channel: _Channels.contact, importance: Importance.defaultImportance, priority: Priority.defaultPriority, color: const Color(0xFF6C3EE8), firestoreType: 'contact'));
    await _saveToFirestore(title: '🎉 $count contact${count == 1 ? '' : 's'} joined SafeHer!', body: 'Real-time location tracking now enabled', type: 'contact', extra: {'newAppUsers': count});
  }

  // ═══════════════════════════════════════════════════════════
  // ─── LOCATION & JOURNEY NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════
  Future<void> showLocationSharingOn({required int contactsCount}) async {
    await _show(NotifPayload(id: _idLocationShare, title: '📡 Live location sharing ON', body: '$contactsCount guardian${contactsCount == 1 ? '' : 's'} can see your real-time location', channel: _Channels.location, importance: Importance.low, priority: Priority.low, ongoing: true, color: const Color(0xFF00C853), firestoreType: 'location', vibrate: false, sound: false));
    await _saveToFirestore(title: '📡 Live location sharing started', body: '$contactsCount guardian${contactsCount == 1 ? '' : 's'} can now see your real-time location', type: 'location_sharing', extra: {'contactsCount': contactsCount, 'action': 'started'});
  }

  Future<void> showLocationSharingOff() async {
    await _cancel(_idLocationShare);
    await _show(NotifPayload(id: _nextId, title: '📴 Location sharing stopped', body: 'Your guardians can no longer see your live location', channel: _Channels.location, importance: Importance.low, priority: Priority.low, firestoreType: 'location', vibrate: false, sound: false));
    await _saveToFirestore(title: '📴 Location sharing stopped', body: 'Your guardians can no longer see your live location', type: 'location_sharing', extra: {'action': 'stopped'});
  }

  Future<void> showJourneyStarted({required String destination, required int estimatedMinutes, required int contactsCount}) async {
    await _show(NotifPayload(id: _idJourneyOngoing, title: '🗺️ Journey to $destination started', body: '⏱️ ETA: $estimatedMinutes mins · $contactsCount guardian${contactsCount == 1 ? '' : 's'} tracking you', bigText: '🗺️ Journey started — SafeHer is watching!\n\n📍 Destination: $destination\n⏱️ Estimated time: $estimatedMinutes minutes\n👥 $contactsCount guardian${contactsCount == 1 ? '' : 's'} notified\n📡 Live location sharing active\n\n⚠️ If you don\'t arrive in time, your guardians will be auto-alerted.', channel: _Channels.journey, importance: Importance.high, priority: Priority.high, ongoing: true, color: const Color(0xFF00C853), firestoreType: 'location_journey'));
    await _saveToFirestore(title: '🗺️ Journey to $destination started', body: '⏱️ ETA: $estimatedMinutes mins · $contactsCount guardian${contactsCount == 1 ? '' : 's'} notified', type: 'journey', extra: {'destination': destination, 'estimatedMinutes': estimatedMinutes, 'contactsCount': contactsCount, 'action': 'started'});
  }

  Future<void> showJourneyArrived({required String destination}) async {
    await _cancel(_idJourneyOngoing); await _cancel(_idJourneyOverdue);
    await _show(NotifPayload(id: _nextId, title: '🏁 Arrived safely at $destination!', body: 'All guardians notified. Journey complete. Stay safe! 💜', bigText: '🏁 Safe arrival confirmed!\n\n✅ Destination: $destination\n📨 All guardians notified\n📡 Location sharing ended\n\nSafeHer is proud to have kept you safe on this journey.', channel: _Channels.journey, importance: Importance.high, priority: Priority.high, color: const Color(0xFF00C853), firestoreType: 'location_journey'));
    await _saveToFirestore(title: '🏁 Arrived safely at $destination!', body: 'Journey complete. All guardians notified.', type: 'journey', extra: {'destination': destination, 'action': 'arrived'});
  }

  Future<void> showJourneyOverdue({required String destination, required int overdueMinutes}) async {
    await _show(NotifPayload(id: _idJourneyOverdue, title: '⚠️ OVERDUE — Tap to check in now!', body: '${overdueMinutes}m overdue to $destination · Guardians being alerted', bigText: '⚠️ You haven\'t arrived at $destination!\n\n🕐 Overdue by: $overdueMinutes minute${overdueMinutes == 1 ? '' : 's'}\n📨 Guardians are being notified automatically\n\n🟢 Open SafeHer and tap "I\'ve Arrived" if you\'re safe\n🔴 Or your guardians will assume you need help', channel: _Channels.journey, importance: Importance.max, priority: Priority.max, fullScreen: true, color: const Color(0xFFFF6D00), firestoreType: 'location_journey'));
    await _saveToFirestore(title: '⚠️ Journey OVERDUE — $destination', body: '${overdueMinutes}m overdue. Guardians auto-alerted.', type: 'journey', extra: {'destination': destination, 'overdueMinutes': overdueMinutes, 'action': 'overdue'});
  }

  Future<void> showJourneyCancelled({required String destination}) async {
    await _cancel(_idJourneyOngoing); await _cancel(_idJourneyOverdue);
    await _show(NotifPayload(id: _nextId, title: '🛑 Journey to $destination cancelled', body: 'Safe tracking ended. Guardians notified.', channel: _Channels.journey, importance: Importance.defaultImportance, priority: Priority.defaultPriority, color: const Color(0xFF9E9E9E), firestoreType: 'location_journey', vibrate: false));
    await _saveToFirestore(title: '🛑 Journey to $destination cancelled', body: 'Safe tracking ended. Guardians notified.', type: 'journey', extra: {'destination': destination, 'action': 'cancelled'});
  }

  Future<void> showGeofenceExited({required String zoneName}) async {
    await _show(NotifPayload(id: _nextId, title: '🏠 You\'ve left $zoneName', body: 'Auto-sharing your live location to guardians', channel: _Channels.location, importance: Importance.defaultImportance, priority: Priority.defaultPriority, color: const Color(0xFF6C3EE8), firestoreType: 'geofence'));
    await _saveToFirestore(title: '🏠 You\'ve left $zoneName', body: 'Auto-sharing your live location to guardians', type: 'geofence', extra: {'zone': zoneName, 'event': 'exited'});
  }

  Future<void> showGeofenceEntered({required String zoneName}) async {
    await _show(NotifPayload(id: _nextId, title: '🏡 Arrived at $zoneName — You\'re safe!', body: 'Location sharing paused. Guardians notified of safe arrival.', channel: _Channels.location, importance: Importance.defaultImportance, priority: Priority.defaultPriority, color: const Color(0xFF00C853), firestoreType: 'geofence'));
    await _saveToFirestore(title: '🏡 Arrived at $zoneName — You\'re safe!', body: 'Location sharing paused. Guardians notified.', type: 'geofence', extra: {'zone': zoneName, 'event': 'entered'});
  }

  Future<void> showDangerZoneNearby({required int sosReportCount, required double distanceMeters}) async {
    final distStr = distanceMeters < 1000 ? '${distanceMeters.toInt()}m' : '${(distanceMeters / 1000).toStringAsFixed(1)}km';
    await _show(NotifPayload(id: _idDangerZone, title: '⚠️ DANGER ZONE — $distStr from you!', body: '$sosReportCount SOS report${sosReportCount == 1 ? '' : 's'} nearby · Stay alert & be cautious', bigText: '⚠️ SafeHer AI detected a danger zone nearby!\n\n📍 Distance: $distStr from your current location\n🚨 $sosReportCount SOS incident${sosReportCount == 1 ? '' : 's'} reported in this area\n\n🔴 Avoid this area if possible\n📱 Open SafeHer to see the danger zone on map\n🆘 Tap SOS button immediately if you feel unsafe', channel: _Channels.sos, importance: Importance.max, priority: Priority.max, color: const Color(0xFFFF6D00), firestoreType: 'danger'));
    await _saveToFirestore(title: '⚠️ DANGER ZONE $distStr from you!', body: '$sosReportCount SOS report${sosReportCount == 1 ? '' : 's'} nearby. Stay alert!', type: 'danger_zone', extra: {'sosCount': sosReportCount, 'distance': distanceMeters});
  }

  Future<void> showDangerZoneReported() async {
    await _show(NotifPayload(id: _nextId, title: '🗺️ Danger zone reported — Thank you!', body: 'Your report helps keep other women safe in this area', channel: _Channels.system, importance: Importance.low, priority: Priority.low, color: const Color(0xFFFF6D00), firestoreType: 'system', vibrate: false, sound: false));
    await _saveToFirestore(title: '🗺️ Danger zone reported', body: 'Your report helps keep other women safe in this area', type: 'system_danger_report');
  }

  // ═══════════════════════════════════════════════════════════
  // ─── SETTINGS & SYSTEM NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════
  Future<void> showProfileSaved() async {
    await _show(NotifPayload(id: _nextId, title: '✏️ Profile updated successfully!', body: 'Your info and medical data are saved securely in the cloud', channel: _Channels.system, importance: Importance.low, priority: Priority.low, firestoreType: 'system_profile', vibrate: false, sound: false));
    await _saveToFirestore(title: '✏️ Profile updated successfully!', body: 'Your info and medical data are saved securely', type: 'system');
  }

  Future<void> showPinChanged() async {
    await _show(NotifPayload(id: _nextId, title: '🔐 SOS Safe PIN updated', body: 'Your new 4-digit PIN is active. Remember it to resolve future SOS!', channel: _Channels.system, importance: Importance.defaultImportance, priority: Priority.defaultPriority, color: const Color(0xFFFF1744), firestoreType: 'system'));
    await _saveToFirestore(title: '🔐 SOS Safe PIN updated', body: 'Your new 4-digit PIN is active. Remember it to resolve future SOS!', type: 'system');
  }

  Future<void> showBiometricChanged({required bool enabled}) async {
    final title = enabled ? '🔒 App Lock enabled' : '🔓 App Lock disabled';
    final body = enabled ? 'Fingerprint/Face ID required to open SafeHer. You\'re protected!' : 'Anyone can now open SafeHer without authentication';
    await _show(NotifPayload(id: _nextId, title: title, body: body, channel: _Channels.system, importance: Importance.defaultImportance, priority: Priority.defaultPriority, color: enabled ? const Color(0xFFFF9800) : const Color(0xFF9E9E9E), firestoreType: 'system'));
    await _saveToFirestore(title: title, body: body, type: 'system', extra: {'biometricEnabled': enabled});
  }

  Future<void> showShakeToggled({required bool enabled}) async {
    await _show(NotifPayload(id: _nextId, title: enabled ? '📳 Shake-to-SOS enabled' : '📳 Shake-to-SOS disabled', body: enabled ? 'Shake your phone 3× to trigger SOS instantly' : 'Shake detection is now off. Use manual SOS button instead', channel: _Channels.system, importance: Importance.low, priority: Priority.low, firestoreType: 'system', vibrate: false, sound: false));
  }

  Future<void> showBackgroundTrackingToggled({required bool enabled}) async {
    if (enabled) await _show(NotifPayload(id: _nextId, title: '📡 Background tracking ON', body: 'SafeHer is tracking your location 24/7 in the background', channel: _Channels.system, importance: Importance.low, priority: Priority.low, firestoreType: 'system', vibrate: false, sound: false));
    await _saveToFirestore(title: enabled ? '📡 Background tracking ON' : '📡 Background tracking OFF', body: enabled ? 'SafeHer is tracking your location 24/7 in the background' : 'Background location tracking stopped', type: 'system');
  }

  Future<void> showOfflineSosSynced({required int count}) async {
    await _show(NotifPayload(id: _nextId, title: '☁️ Offline SOS synced — $count record${count == 1 ? '' : 's'}', body: 'Back online! Pending SOS records uploaded to your account', channel: _Channels.system, importance: Importance.defaultImportance, priority: Priority.defaultPriority, color: const Color(0xFF6C3EE8), firestoreType: 'system'));
    await _saveToFirestore(title: '☁️ Offline SOS synced — $count record${count == 1 ? '' : 's'}', body: 'Back online! Pending SOS records uploaded to your account', type: 'system');
  }

  Future<void> showAppProtectionActive() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('_app_protection_shown') == true) return;
    await prefs.setBool('_app_protection_shown', true);

    await _show(NotifPayload(id: _nextId, title: '🛡️ SafeHer AI Protection Active', body: 'AI monitoring · Shake SOS · Live tracking — all systems go!', bigText: '🛡️ SafeHer is fully active and protecting you!\n\n🤖 AI danger detection: ON\n📳 Shake-to-SOS: ON\n📡 Background tracking: ready\n👥 Emergency contacts: configured\n\nYou\'re protected by SafeHer 24/7. Stay safe! 💜', channel: _Channels.system, importance: Importance.defaultImportance, priority: Priority.defaultPriority, color: const Color(0xFF6C3EE8), firestoreType: 'system', vibrate: false, sound: false));
    await _saveToFirestore(title: '🛡️ SafeHer AI Protection Active', body: 'AI monitoring · Shake SOS · Live tracking — all systems go!', type: 'system_protection');
  }

  Future<void> dismissAll() async => _plugin.cancelAll();
  Future<void> dismissSosAll() async { await _cancel(_idSosOngoing); await _cancel(_idSosCountdown); }
  Future<void> dismissJourneyAll() async { await _cancel(_idJourneyOngoing); await _cancel(_idJourneyOverdue); }
}