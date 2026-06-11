// lib/core/services/location/location_intelligence_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// LOCATION INTELLIGENCE SERVICE
// Risk scoring, historical heatmap, time-of-day safety, crowd density
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../location_service.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

class RiskScore {
  final double score;         // 0.0 = safe, 1.0 = very dangerous
  final String label;         // 'Safe', 'Low Risk', 'Moderate', 'High', 'Danger'
  final String reason;
  final List<String> factors;
  final bool requiresAlert;

  const RiskScore({
    required this.score,
    required this.label,
    required this.reason,
    required this.factors,
    this.requiresAlert = false,
  });

  static RiskScore fromScore(double s) {
    if (s < 0.2)  return RiskScore(score: s, label: 'Safe',     reason: 'Low historical incidents', factors: [], requiresAlert: false);
    if (s < 0.4)  return RiskScore(score: s, label: 'Low Risk', reason: 'Minor incidents reported',  factors: [], requiresAlert: false);
    if (s < 0.6)  return RiskScore(score: s, label: 'Moderate', reason: 'Some incidents reported',   factors: [], requiresAlert: false);
    if (s < 0.8)  return RiskScore(score: s, label: 'High',     reason: 'Frequent incidents',        factors: [], requiresAlert: true);
    return          RiskScore(score: s, label: 'Danger',   reason: 'Danger zone',               factors: [], requiresAlert: true);
  }
}

class HeatmapPoint {
  final double lat;
  final double lng;
  final double intensity; // 0.0–1.0
  final int    incidentCount;
  final String lastReported;

  const HeatmapPoint({
    required this.lat,
    required this.lng,
    required this.intensity,
    required this.incidentCount,
    required this.lastReported,
  });
}

class SafetyReport {
  final double lat;
  final double lng;
  final RiskScore riskScore;
  final List<HeatmapPoint> nearbyHotspots;
  final List<SafePlace> nearbyPlaces;
  final String timeContext; // 'Daytime', 'Evening', 'Night', 'Late Night'
  final List<String> recommendations;

  const SafetyReport({
    required this.lat,
    required this.lng,
    required this.riskScore,
    required this.nearbyHotspots,
    required this.nearbyPlaces,
    required this.timeContext,
    required this.recommendations,
  });
}

// ─── Service ─────────────────────────────────────────────────────────────────

class LocationIntelligenceService {
  LocationIntelligenceService._();
  static final LocationIntelligenceService instance =
  LocationIntelligenceService._();

  final _firestore = FirebaseFirestore.instance;
  final _auth      = FirebaseAuth.instance;

  // Cache
  List<HeatmapPoint> _heatmapCache = [];
  DateTime?          _cacheTime;
  static const Duration _cacheTtl = Duration(minutes: 10);

  String get _uid => _auth.currentUser?.uid ?? '';

  // ─── GENERATE SAFETY REPORT ─────────────────────────────────
  Future<SafetyReport> generateReport({
    required double lat,
    required double lng,
    List<SafePlace> nearbyPlaces = const [],
  }) async {
    final hour       = DateTime.now().hour;
    final timeCtx    = _timeContext(hour);
    final hotspots   = await getHeatmapPoints(lat: lat, lng: lng, radiusKm: 1.0);
    final riskScore  = await _calculateRisk(
      lat:       lat,
      lng:       lng,
      hour:      hour,
      hotspots:  hotspots,
      places:    nearbyPlaces,
    );

    return SafetyReport(
      lat:             lat,
      lng:             lng,
      riskScore:       riskScore,
      nearbyHotspots:  hotspots,
      nearbyPlaces:    nearbyPlaces,
      timeContext:     timeCtx,
      recommendations: _buildRecommendations(riskScore, timeCtx, nearbyPlaces),
    );
  }

  // ─── CALCULATE RISK SCORE ───────────────────────────────────
  Future<RiskScore> _calculateRisk({
    required double lat,
    required double lng,
    required int hour,
    required List<HeatmapPoint> hotspots,
    required List<SafePlace> places,
  }) async {
    double score = 0.0;
    final factors = <String>[];

    // 1. Incident density (0–0.4)
    if (hotspots.isNotEmpty) {
      final closest = hotspots
          .map((h) => h.intensity * (1 - (_distKm(lat, lng, h.lat, h.lng) / 1.0).clamp(0, 1)))
          .reduce(max);
      score += closest * 0.4;
      if (closest > 0.3) factors.add('${hotspots.length} incident(s) reported nearby');
    }

    // 2. Time of day multiplier (0–0.25)
    double timeMult = 0;
    if (hour >= 23 || hour < 4)      { timeMult = 0.25; factors.add('Late night (high risk hours)'); }
    else if (hour >= 20 || hour < 6) { timeMult = 0.15; factors.add('Night time'); }
    else if (hour >= 18)             { timeMult = 0.05; factors.add('Evening'); }
    score += timeMult;

    // 3. Isolation — no safe places nearby (0–0.2)
    final hasSafePlace = places.any((p) => p.distanceKm < 0.3);
    if (!hasSafePlace) {
      score += 0.15;
      factors.add('No police/hospital within 300m');
    }

    // 4. Historical SOS from this user at location (0–0.15)
    try {
      final snap = await _firestore
          .collection('users').doc(_uid)
          .collection('incidents')
          .where('status', isEqualTo: 'confirmed')
          .limit(50)
          .get();

      final nearbyUserIncidents = snap.docs.where((d) {
        final data = d.data();
        final iLat = (data['lat'] as num?)?.toDouble() ?? 0;
        final iLng = (data['lng'] as num?)?.toDouble() ?? 0;
        return _distKm(lat, lng, iLat, iLng) < 0.5;
      }).length;

      if (nearbyUserIncidents > 0) {
        score += (nearbyUserIncidents / 10).clamp(0, 0.15);
        factors.add('$nearbyUserIncidents past incident(s) at this location');
      }
    } catch (_) {}

    final clamped = score.clamp(0.0, 1.0);
    return RiskScore(
      score:         clamped,
      label:         RiskScore.fromScore(clamped).label,
      reason:        factors.isEmpty ? 'No significant risk factors' : factors.first,
      factors:       factors,
      requiresAlert: clamped >= 0.6,
    );
  }

  // ─── GET HEATMAP POINTS ─────────────────────────────────────
  Future<List<HeatmapPoint>> getHeatmapPoints({
    required double lat,
    required double lng,
    double radiusKm = 2.0,
  }) async {
    // Use cache if fresh
    if (_heatmapCache.isNotEmpty &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheTtl) {
      return _filterByRadius(_heatmapCache, lat, lng, radiusKm);
    }

    try {
      final snap = await _firestore
          .collection('dangerZones')
          .limit(500)
          .get();

      _heatmapCache = snap.docs.map((doc) {
        final d = doc.data();
        final sosCount = (d['sosCount'] as int?) ?? 1;
        return HeatmapPoint(
          lat:           (d['lat'] as num).toDouble(),
          lng:           (d['lng'] as num).toDouble(),
          intensity:     (sosCount / 20.0).clamp(0.0, 1.0),
          incidentCount: sosCount,
          lastReported:  d['lastIncident'] != null
              ? _formatDate((d['lastIncident'] as Timestamp).toDate())
              : 'Unknown',
        );
      }).toList();

      _cacheTime = DateTime.now();
      return _filterByRadius(_heatmapCache, lat, lng, radiusKm);
    } catch (e) {
      debugPrint('❌ LocationIntelligence heatmap: $e');
      return [];
    }
  }

  // ─── ROUTE RISK ANALYSIS ────────────────────────────────────
  Future<Map<String, dynamic>> analyzeRoute({
    required List<LatLngPoint> route,
  }) async {
    if (route.isEmpty) return {'score': 0.0, 'hotspots': 0, 'dangerSegments': []};

    final allHotspots = await getHeatmapPoints(
      lat: route[route.length ~/ 2].lat,
      lng: route[route.length ~/ 2].lng,
      radiusKm: 5.0,
    );

    double maxRisk = 0;
    int hotspotCount = 0;
    final dangerSegments = <int>[];

    for (int i = 0; i < route.length; i++) {
      final p = route[i];
      for (final h in allHotspots) {
        final d = _distKm(p.lat, p.lng, h.lat, h.lng);
        if (d < 0.2) {
          hotspotCount++;
          final risk = h.intensity * (1 - d / 0.2);
          if (risk > maxRisk) maxRisk = risk;
          if (risk > 0.4 && !dangerSegments.contains(i)) {
            dangerSegments.add(i);
          }
          break;
        }
      }
    }

    return {
      'score':          maxRisk.clamp(0.0, 1.0),
      'hotspots':       hotspotCount,
      'dangerSegments': dangerSegments,
      'label':          RiskScore.fromScore(maxRisk).label,
    };
  }

  // ─── RECORD INCIDENT AT CURRENT LOCATION ────────────────────
  Future<void> recordIncident({
    required double lat,
    required double lng,
    required String type,
  }) async {
    if (_uid.isEmpty) return;
    try {
      // Check if zone already exists nearby
      final existing = _heatmapCache
          .where((h) => _distKm(lat, lng, h.lat, h.lng) < 0.3)
          .toList();

      if (existing.isNotEmpty) {
        await _firestore.collection('dangerZones')
            .where('lat', isEqualTo: existing.first.lat)
            .limit(1)
            .get()
            .then((s) {
          if (s.docs.isNotEmpty) {
            s.docs.first.reference.update({
              'sosCount':     FieldValue.increment(1),
              'lastIncident': FieldValue.serverTimestamp(),
            });
          }
        });
      } else {
        await _firestore.collection('dangerZones').add({
          'lat':          lat,
          'lng':          lng,
          'radiusMeters': 200.0,
          'sosCount':     1,
          'lastIncident': FieldValue.serverTimestamp(),
          'reportedBy':   _uid,
          'type':         type,
        });
      }
      _heatmapCache = []; // invalidate cache
    } catch (e) {
      debugPrint('❌ recordIncident: $e');
    }
  }

  // ─── HELPERS ────────────────────────────────────────────────
  List<HeatmapPoint> _filterByRadius(
      List<HeatmapPoint> points, double lat, double lng, double radiusKm,
      ) => points.where((p) => _distKm(lat, lng, p.lat, p.lng) <= radiusKm).toList();

  double _distKm(double lat1, double lng1, double lat2, double lng2) {
    const R   = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lng2 - lng1) * pi / 180;
    final a   = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
            sin(dLon / 2) * sin(dLon / 2);
    return 2 * R * asin(sqrt(a));
  }

  String _timeContext(int hour) {
    if (hour >= 6  && hour < 12) return 'Morning';
    if (hour >= 12 && hour < 17) return 'Afternoon';
    if (hour >= 17 && hour < 20) return 'Evening';
    if (hour >= 20 && hour < 23) return 'Night';
    return 'Late Night';
  }

  String _formatDate(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7)  return '${diff.inDays} days ago';
    return '${d.day}/${d.month}/${d.year}';
  }

  List<String> _buildRecommendations(
      RiskScore risk, String time, List<SafePlace> places,
      ) {
    final recs = <String>[];
    if (risk.score > 0.6) {
      recs.add('⚠️ Share your live location with a trusted contact now');
      recs.add('🏃 Move toward a safe place — police or hospital nearby');
    }
    if (time == 'Late Night' || time == 'Night') {
      recs.add('🌙 Stay on well-lit, populated streets');
      recs.add('📱 Keep your phone charged and in a safe pocket');
    }
    if (places.isNotEmpty) {
      final nearest = places.first;
      recs.add('🏥 Nearest safe place: ${nearest.name} (${(nearest.distanceKm * 1000).toStringAsFixed(0)}m)');
    }
    if (recs.isEmpty) recs.add('✅ Area looks safe. Stay aware of your surroundings.');
    return recs;
  }
}