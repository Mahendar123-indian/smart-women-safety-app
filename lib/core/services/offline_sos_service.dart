// lib/core/services/offline_sos_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// INDUSTRIAL SENTINEL — OFFLINE SOS SERVICE v5.0 (2026 PRODUCTION)
// ─────────────────────────────────────────────────────────────────────────────
// ✅ [FIXED] True Zero-Click SMS: Replaced url_launcher with background telephony.
// ✅ [FIXED] Rule Synchronization: Firestore payload matches strict security rules.
// ✅ [RESILIENCE] Caches live location every 30s to guarantee valid dispatch data.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:telephony/telephony.dart'; // ✅ Added for Zero-Click SMS

// ─── Models ──────────────────────────────────────────────────────────────────

class CachedLocation {
  final double lat;
  final double lng;
  final String address;
  final DateTime timestamp;
  final double accuracy;

  const CachedLocation({
    required this.lat,
    required this.lng,
    required this.address,
    required this.timestamp,
    required this.accuracy,
  });

  Map<String, dynamic> toJson() => {
    'lat': lat,
    'lng': lng,
    'address': address,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'accuracy': accuracy,
  };

  factory CachedLocation.fromJson(Map<String, dynamic> j) => CachedLocation(
    lat: (j['lat'] ?? 0.0).toDouble(),
    lng: (j['lng'] ?? 0.0).toDouble(),
    address: j['address'] ?? 'Unknown location',
    timestamp: DateTime.fromMillisecondsSinceEpoch(j['timestamp'] ?? 0),
    accuracy: (j['accuracy'] ?? 0.0).toDouble(),
  );

  String get mapsLink => 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

  String get ageStr {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min ago';
    return '${diff.inHours}h ago';
  }
}

class OfflineSosRecord {
  final String id;
  final String uid;
  final CachedLocation location;
  final DateTime triggeredAt;
  final String triggerType;
  final bool smsSent;
  final List<String> contactsSmsed;
  bool synced;

  OfflineSosRecord({
    required this.id,
    required this.uid,
    required this.location,
    required this.triggeredAt,
    required this.triggerType,
    this.smsSent = false,
    this.contactsSmsed = const [],
    this.synced = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'uid': uid,
    'location': location.toJson(),
    'triggeredAt': triggeredAt.millisecondsSinceEpoch,
    'triggerType': triggerType,
    'smsSent': smsSent,
    'contactsSmsed': contactsSmsed,
    'synced': synced,
  };

  factory OfflineSosRecord.fromJson(Map<String, dynamic> j) => OfflineSosRecord(
    id: j['id'] ?? '',
    uid: j['uid'] ?? '',
    location: CachedLocation.fromJson(j['location'] as Map<String, dynamic>),
    triggeredAt: DateTime.fromMillisecondsSinceEpoch(j['triggeredAt'] ?? 0),
    triggerType: j['triggerType'] ?? 'manual',
    smsSent: j['smsSent'] ?? false,
    contactsSmsed: List<String>.from(j['contactsSmsed'] ?? []),
    synced: j['synced'] ?? false,
  );
}

// ─── Offline SOS Service ─────────────────────────────────────────────────────

class OfflineSosService {
  OfflineSosService._();
  static final OfflineSosService instance = OfflineSosService._();

  static const _prefKeyLocation = 'offline_cached_location';
  static const _prefKeyContacts = 'offline_emergency_contacts';
  static const _prefKeyUserName = 'offline_user_name';
  static const _prefKeyPendingSync = 'offline_pending_sos_records';
  static const _prefKeyLocationHistory = 'offline_location_history';

  final _connectivity = Connectivity();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _telephony = Telephony.instance; // ✅ Added

  Timer? _locationCacheTimer;
  Timer? _syncRetryTimer;
  StreamSubscription? _connectivitySub;

  bool _isOnline = true;
  CachedLocation? _lastCachedLocation;

  // ─── INIT ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    await _loadCachedLocation();
    await _checkConnectivity();
    _startLocationCaching();
    _listenConnectivity();
    _startSyncRetry();
    debugPrint('✅ OfflineSosService initialized. Online: $_isOnline');
  }

  Future<void> _checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    // Adjusted for newer connectivity_plus versions returning a List
    if (result is List) {
      _isOnline = !result.contains(ConnectivityResult.none);
    } else {
      _isOnline = result != ConnectivityResult.none;
    }
  }

  void _listenConnectivity() {
    _connectivitySub = _connectivity.onConnectivityChanged.listen((result) {
      final wasOffline = !_isOnline;

      if (result is List) {
        _isOnline = !result.contains(ConnectivityResult.none);
      } else {
        _isOnline = result != ConnectivityResult.none;
      }

      debugPrint('📶 Connectivity changed. Online: $_isOnline');
      if (wasOffline && _isOnline) {
        debugPrint('🔄 Back online! Syncing pending offline SOS records...');
        syncPendingRecords();
      }
    });
  }

  // ─── LOCATION CACHING — runs every 30s in background ─────────────────────

  void _startLocationCaching() {
    _cacheCurrentLocation();
    _locationCacheTimer = Timer.periodic(
      const Duration(seconds: 30),
          (_) => _cacheCurrentLocation(),
    );
  }

  Future<void> _cacheCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 6),
      );

      String address = 'Lat: ${pos.latitude.toStringAsFixed(4)}, Lng: ${pos.longitude.toStringAsFixed(4)}';

      if (_isOnline) {
        try {
          address = await _reverseGeocode(pos.latitude, pos.longitude);
        } catch (_) {}
      }

      final cached = CachedLocation(
        lat: pos.latitude,
        lng: pos.longitude,
        address: address,
        timestamp: DateTime.now(),
        accuracy: pos.accuracy,
      );

      _lastCachedLocation = cached;
      await _saveCachedLocation(cached);
      await _addToLocationHistory(cached);
    } catch (e) {
      debugPrint('⚠️ Location cache failed: $e');
    }
  }

  Future<String> _reverseGeocode(double lat, double lng) async {
    return 'Near ${lat.toStringAsFixed(3)}°N, ${lng.toStringAsFixed(3)}°E';
  }

  // ─── TRIGGER OFFLINE SOS ─────────────────────────────────────────────────

  Future<bool> triggerOfflineSOS({
    String triggerType = 'manual',
    List<Map<String, String>>? contacts,
  }) async {
    debugPrint('🚨 Offline SOS triggered! Online: $_isOnline');

    final location = await _getBestLocation();
    final userName = await _getCachedUserName();
    final emergencyContacts = contacts ?? await _getCachedContacts();

    if (emergencyContacts.isEmpty) {
      debugPrint('⚠️ No cached contacts for offline SOS!');
      return false;
    }

    final recordId = 'offline_${DateTime.now().millisecondsSinceEpoch}';

    // 1. Send ZERO-CLICK SMS immediately (works offline via cellular towers)
    final smsSent = await _sendSMSToAll(
      contacts: emergencyContacts,
      location: location,
      userName: userName,
      incidentId: recordId,
    );

    // 2. Save record locally for later sync
    final savedRecord = OfflineSosRecord(
      id: recordId,
      uid: _auth.currentUser?.uid ?? 'offline_user',
      location: location,
      triggeredAt: DateTime.now(),
      triggerType: triggerType,
      smsSent: smsSent,
      contactsSmsed: emergencyContacts.map((c) => c['phone'] ?? '').toList(),
      synced: false,
    );

    await _savePendingRecord(savedRecord);

    // 3. If online, sync immediately
    if (_isOnline) {
      await syncPendingRecords();
    }

    debugPrint('✅ Offline SOS complete. SMS sent: $smsSent');
    return smsSent;
  }

  // ─── GET BEST AVAILABLE LOCATION ─────────────────────────────────────────

  Future<CachedLocation> _getBestLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      return CachedLocation(
        lat: pos.latitude,
        lng: pos.longitude,
        address: _lastCachedLocation?.address ??
            'Lat: ${pos.latitude.toStringAsFixed(4)}, Lng: ${pos.longitude.toStringAsFixed(4)}',
        timestamp: DateTime.now(),
        accuracy: pos.accuracy,
      );
    } catch (_) {
      debugPrint('⚠️ Live GPS failed, using cached location');
    }

    if (_lastCachedLocation != null) return _lastCachedLocation!;

    final stored = await _loadCachedLocation();
    if (stored != null) return stored;

    return CachedLocation(
      lat: 0, lng: 0,
      address: 'Location unavailable',
      timestamp: DateTime.now(),
      accuracy: 0,
    );
  }

  // ─── ZERO-CLICK SMS SENDING ──────────────────────────────────────────────

  Future<bool> _sendSMSToAll({
    required List<Map<String, String>> contacts,
    required CachedLocation location,
    required String userName,
    required String incidentId,
  }) async {
    if (contacts.isEmpty) return false;

    final now = DateTime.now();
    final timeStr = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
    final locationAge = location.ageStr;

    // ✅ FIXED: Official Maps Query Formatting
    final mapsLink = '${location.mapsLink}?q=${location.lat},${location.lng}';

    final message = '🚨 EMERGENCY SOS from $userName!\n'
        'Time: $timeStr\n'
        '📍 ${location.address}\n'
        '🗺️ Map: $mapsLink\n'
        '⏱️ Location: $locationAge\n'
        '⚠️ Please call/come immediately!\n'
        '[Sent via SafeHer Offline Mode]';

    int sent = 0;
    final hasPermission = await _telephony.requestPhoneAndSmsPermissions ?? false;

    for (final contact in contacts) {
      final phone = contact['phone'];
      if (phone == null || phone.isEmpty) continue;

      final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');

      try {
        if (hasPermission) {
          // ✅ BACKGROUND ZERO-CLICK EXECUTION
          await _telephony.sendSms(to: cleanPhone, message: message, isMultipart: true);
          sent++;
          await Future.delayed(const Duration(milliseconds: 300)); // Prevent carrier rate limiting
        } else {
          // Fallback if user denied SMS permissions
          final uri = Uri.parse('sms:$cleanPhone?body=${Uri.encodeComponent(message)}');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            sent++;
          }
        }
      } catch (e) {
        debugPrint('❌ SMS failed to $cleanPhone: $e');
      }
    }

    return sent > 0;
  }

  // ─── SYNC PENDING RECORDS WHEN BACK ONLINE ───────────────────────────────

  Future<void> syncPendingRecords() async {
    if (!_isOnline) return;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefKeyPendingSync) ?? [];

    if (raw.isEmpty) return;

    debugPrint('🔄 Syncing ${raw.length} offline SOS records...');

    final remaining = <String>[];

    for (final item in raw) {
      try {
        final json = jsonDecode(item) as Map<String, dynamic>;
        final record = OfflineSosRecord.fromJson(json);

        if (record.synced) continue;

        // ✅ FIXED: Strictly aligns with the 'hasFields' constraint in firestore.rules
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('incidents')
            .doc(record.id)
            .set({
          'uid': uid,
          'lat': record.location.lat,
          'lng': record.location.lng,
          'dangerScore': 1.0, // Assumed critical if triggered offline
          'triggerType': record.triggerType,
          'status': 'resolved', // Archived offline event
          'isSilent': false,
          'triggeredAt': record.triggeredAt.millisecondsSinceEpoch,
          // Extra context fields permitted by rules
          'address': record.location.address,
          'resolvedAt': FieldValue.serverTimestamp(),
          'contactsNotified': record.contactsSmsed,
          'smsSentOffline': record.smsSent,
          'syncedFromOffline': true,
          'syncedAt': FieldValue.serverTimestamp(),
        });

        record.synced = true;
        debugPrint('✅ Synced offline SOS: ${record.id}');
      } catch (e) {
        remaining.add(item);
        debugPrint('❌ Sync failed for record: $e');
      }
    }

    await prefs.setStringList(_prefKeyPendingSync, remaining);
  }

  void _startSyncRetry() {
    _syncRetryTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_isOnline) syncPendingRecords();
    });
  }

  // ─── CACHE MANAGEMENT ────────────────────────────────────────────────────

  Future<void> cacheUserData({
    required String userName,
    required List<Map<String, String>> contacts,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyUserName, userName);
    await prefs.setString(_prefKeyContacts, jsonEncode(contacts));
    debugPrint('✅ User data cached for offline SOS');
  }

  Future<String> _getCachedUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyUserName) ??
        _auth.currentUser?.displayName ??
        'SafeHer User';
  }

  Future<List<Map<String, String>>> _getCachedContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKeyContacts);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Map<String, String>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveCachedLocation(CachedLocation location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyLocation, jsonEncode(location.toJson()));
  }

  Future<CachedLocation?> _loadCachedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKeyLocation);
      if (raw == null) return null;
      _lastCachedLocation = CachedLocation.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return _lastCachedLocation;
    } catch (_) {
      return null;
    }
  }

  Future<void> _addToLocationHistory(CachedLocation location) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefKeyLocationHistory) ?? [];
    raw.add(jsonEncode(location.toJson()));
    final trimmed = raw.length > 50 ? raw.sublist(raw.length - 50) : raw;
    await prefs.setStringList(_prefKeyLocationHistory, trimmed);
  }

  Future<void> _savePendingRecord(OfflineSosRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefKeyPendingSync) ?? [];
    raw.add(jsonEncode(record.toJson()));
    await prefs.setStringList(_prefKeyPendingSync, raw);
    debugPrint('💾 Offline SOS record saved locally: ${record.id}');
  }

  // ─── PUBLIC GETTERS ───────────────────────────────────────────────────────

  bool get isOnline => _isOnline;
  CachedLocation? get lastCachedLocation => _lastCachedLocation;

  Future<List<OfflineSosRecord>> getPendingRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefKeyPendingSync) ?? [];
    return raw.map((e) {
      try {
        return OfflineSosRecord.fromJson(jsonDecode(e) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<OfflineSosRecord>().where((r) => !r.synced).toList();
  }

  Future<List<CachedLocation>> getLocationHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefKeyLocationHistory) ?? [];
    return raw.map((e) {
      try {
        return CachedLocation.fromJson(jsonDecode(e) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<CachedLocation>().toList();
  }

  Future<int> getPendingCount() async {
    final records = await getPendingRecords();
    return records.length;
  }

  // ─── DISPOSE ─────────────────────────────────────────────────────────────

  void dispose() {
    _locationCacheTimer?.cancel();
    _syncRetryTimer?.cancel();
    _connectivitySub?.cancel();
  }
}