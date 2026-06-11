// lib/core/services/community_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// COMMUNITY SERVICE — Crowdsourced danger zone reporting
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

enum DangerType {
  theft, assault, harassment, stalking, poorLighting, unsafeRoad, suspiciousActivity, other, sosEmergency // ✅ Added SOS Emergency Type
}

class DangerReport {
  final String    id;
  final double    lat;
  final double    lng;
  final DangerType type;
  final String    description;
  final String    reportedBy;
  final DateTime  reportedAt;
  final int       voteCount;
  final bool      verified;
  final DateTime  expiresAt;
  final String?   address;
  final double    distanceKm;

  const DangerReport({
    required this.id, required this.lat, required this.lng, required this.type,
    required this.description, required this.reportedBy, required this.reportedAt,
    required this.voteCount, required this.verified, required this.expiresAt,
    this.address, this.distanceKm = 0,
  });

  bool get isActive => DateTime.now().isBefore(expiresAt);
  bool get isHighRisk => voteCount >= 5 || verified || type == DangerType.sosEmergency;
  String get typeLabel => typeLabels[type] ?? 'Danger';
  String get typeEmoji => typeEmojis[type] ?? '⚠️';

  static const typeLabels = {
    DangerType.theft:               'Theft/Robbery',
    DangerType.assault:             'Assault',
    DangerType.harassment:          'Harassment',
    DangerType.stalking:            'Stalking',
    DangerType.poorLighting:        'Poor Lighting',
    DangerType.unsafeRoad:          'Unsafe Road',
    DangerType.suspiciousActivity:  'Suspicious Activity',
    DangerType.sosEmergency:        'ACTIVE SOS', // ✅ Map Label
    DangerType.other:               'Other Danger',
  };

  static const typeEmojis = {
    DangerType.theft:               '🔪',
    DangerType.assault:             '👊',
    DangerType.harassment:          '😡',
    DangerType.stalking:            '👁️',
    DangerType.poorLighting:        '🌑',
    DangerType.unsafeRoad:          '🚧',
    DangerType.suspiciousActivity:  '🕵️',
    DangerType.sosEmergency:        '🚨', // ✅ Map Emoji
    DangerType.other:               '⚠️',
  };

  factory DangerReport.fromFirestore(DocumentSnapshot doc, double distKm) {
    final d = doc.data() as Map<String, dynamic>;
    // Safely parse the type, mapping SOS correctly if it comes from the Police Dispatch
    DangerType parsedType = DangerType.other;
    if (d['typeLabel'] == 'ACTIVE SOS ALERT' || d['sosCount'] != null && d['sosCount'] > 0) {
      parsedType = DangerType.sosEmergency;
    } else {
      parsedType = DangerType.values[d['typeIndex'] ?? 0];
    }

    return DangerReport(
      id:          doc.id,
      lat:         (d['lat']  as num).toDouble(),
      lng:         (d['lng']  as num).toDouble(),
      type:        parsedType,
      description: d['description'] ?? '',
      reportedBy:  d['reportedBy']  ?? '',
      reportedAt:  (d['reportedAt'] as Timestamp).toDate(),
      voteCount:   d['reportCount'] as int? ?? 1,
      verified:    d['verified']    as bool? ?? false,
      expiresAt:   (d['expiresAt']  as Timestamp).toDate(),
      address:     d['address'],
      distanceKm:  distKm,
    );
  }
}

class CommunityStats {
  final int    totalReports;
  final int    activeReports;
  final int    verifiedZones;
  final int    myReports;
  final double safetysScore;

  const CommunityStats({
    required this.totalReports, required this.activeReports, required this.verifiedZones,
    required this.myReports, required this.safetysScore,
  });
}

class CommunityService extends ChangeNotifier {
  CommunityService._();
  static final CommunityService instance = CommunityService._();

  final _firestore = FirebaseFirestore.instance;
  final _auth      = FirebaseAuth.instance;
  final _rtdb      = FirebaseDatabase.instanceFor(
    app:         FirebaseDatabase.instance.app,
    databaseURL: 'https://smart-women-safety-app-b1988-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  List<DangerReport> _reports   = [];
  CommunityStats?    _stats;
  bool               _isLoading = false;
  String?            _error;
  StreamSubscription? _sub;

  List<DangerReport> get reports   => _reports;
  CommunityStats?    get stats     => _stats;
  bool               get isLoading => _isLoading;
  String?            get error     => _error;
  List<DangerReport> get highRisk  => _reports.where((r) => r.isHighRisk).toList();

  Future<void> loadNearbyReports({required double lat, required double lng, double radiusKm = 10}) async {
    _isLoading = true;
    _error     = null;
    notifyListeners();

    try {
      final delta = radiusKm / 111.0;
      final snap = await _firestore.collection('dangerZones')
          .where('lat', isGreaterThan: lat - delta)
          .where('lat', isLessThan:    lat + delta)
          .where('isActive', isEqualTo: true)
          .orderBy('lat')
          .orderBy('reportCount', descending: true)
          .limit(100)
          .get();

      _reports = snap.docs.map((doc) {
        final d    = doc.data();
        final sLat = (d['lat'] as num).toDouble();
        final sLng = (d['lng'] as num).toDouble();
        final dist = _distKm(lat, lng, sLat, sLng);
        return DangerReport.fromFirestore(doc, dist);
      }).where((r) => r.distanceKm <= radiusKm && r.isActive).toList()
        ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

      _computeStats(lat, lng);
    } catch (e) {
      _error = 'Could not load community reports';
    }

    _isLoading = false;
    notifyListeners();
  }

  void startLiveStream(double lat, double lng) {
    _sub?.cancel();
    final delta = 0.1;

    _sub = _firestore.collection('dangerZones')
        .where('lat', isGreaterThan: lat - delta)
        .where('lat', isLessThan:    lat + delta)
        .where('isActive', isEqualTo: true)
        .orderBy('lat')
        .snapshots()
        .listen((snap) {
      _reports = snap.docs.map((doc) {
        final d    = doc.data();
        final sLat = (d['lat'] as num).toDouble();
        final sLng = (d['lng'] as num).toDouble();
        final dist = _distKm(lat, lng, sLat, sLng);
        return DangerReport.fromFirestore(doc, dist);
      }).where((r) => r.isActive).toList()
        ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      _computeStats(lat, lng);
      notifyListeners();
    });
  }

  void stopLiveStream() => _sub?.cancel();

  Future<bool> submitReport({required double lat, required double lng, required DangerType type, required String description, String? address}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    if (description.trim().length < 10) return false;

    try {
      final expiry = DateTime.now().add(const Duration(hours: 24));
      final existing = await _findExistingReport(lat, lng, type);

      if (existing != null) {
        await _firestore.collection('dangerZones').doc(existing).update({
          'reportCount': FieldValue.increment(1),
          'lastIncident': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await _firestore.collection('dangerZones').add({
          'lat':          lat,
          'lng':          lng,
          'typeIndex':    type.index,
          'typeLabel':    DangerReport.typeLabels[type],
          'description':  description.trim(),
          'reportedBy':   uid,
          'reportCount':  1,
          'sosCount':     0,
          'verified':     false,
          'isActive':     true,
          'address':      address ?? '',
          'expiresAt':    Timestamp.fromDate(expiry),
          'lastIncident': FieldValue.serverTimestamp(),
          'reportedAt':   FieldValue.serverTimestamp(),
          'createdAt':    FieldValue.serverTimestamp(),
        });
      }

      await _firestore.collection('users').doc(uid).collection('myReports').add({
        'lat': lat, 'lng': lng, 'type': type.index, 'createdAt': FieldValue.serverTimestamp(),
      });

      await _rtdb.ref('communityAlerts/${DateTime.now().millisecondsSinceEpoch}').set({
        'lat': lat, 'lng': lng, 'type': type.index, 'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> upvoteReport(String reportId) async {
    try {
      await _firestore.collection('dangerZones').doc(reportId).update({
        'reportCount': FieldValue.increment(1), 'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> markSafe(String reportId) async {
    try {
      await _firestore.collection('dangerZones').doc(reportId).update({
        'safeVotes': FieldValue.increment(1), 'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<String?> _findExistingReport(double lat, double lng, DangerType type) async {
    try {
      final delta = 0.0005;
      final snap  = await _firestore.collection('dangerZones')
          .where('lat', isGreaterThan: lat - delta).where('lat', isLessThan: lat + delta)
          .where('typeIndex', isEqualTo: type.index).where('isActive', isEqualTo: true).limit(1).get();
      return snap.docs.isEmpty ? null : snap.docs.first.id;
    } catch (_) { return null; }
  }

  void _computeStats(double lat, double lng) {
    final active   = _reports.where((r) => r.isActive).length;
    final verified = _reports.where((r) => r.verified || r.type == DangerType.sosEmergency).length;

    double score = 100;
    for (final r in _reports) {
      final weight = r.distanceKm < 0.5 ? 15 : r.distanceKm < 1 ? 8 : r.distanceKm < 2 ? 4 : 1;
      score -= weight * (r.isHighRisk ? 2 : 1);
    }
    score = score.clamp(0, 100);

    _stats = CommunityStats(totalReports: _reports.length, activeReports: active, verifiedZones: verified, myReports: 0, safetysScore: score);
  }

  double _distKm(double lat1, double lng1, double lat2, double lng2) {
    const r   = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a    = sin(dLat / 2) * sin(dLat / 2) + cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _rad(double d) => d * pi / 180;

  @override
  void dispose() { _sub?.cancel(); super.dispose(); }
}