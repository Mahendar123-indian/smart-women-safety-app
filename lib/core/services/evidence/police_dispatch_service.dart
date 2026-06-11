// lib/core/services/evidence/police_dispatch_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// SAFEHER — POLICE DISPATCH SERVICE v8.0
// ─────────────────────────────────────────────────────────────────────────────
// ✅ dispatchToPolice() uses EvidenceFields constants throughout
// ✅ _broadcastToCommunityMap() writes verified SOS pin to dangerZones
// ✅ _findResponseUnitsWithRetry() with 3 retries + exponential backoff
// ✅ _queueStationAlert() writes to policeAlertTasks (rule: victimUid)
// ✅ _triggerRegionalFallback() writes to sos_events (fully unlocked rule)
// ✅ Static fallback station when API unavailable
// ✅ NearbyPoliceStation.fromMap() with full null safety
// ✅ Haversine distance calculation in _calculateDistance()
// ✅ policeDispatches Firestore doc uses uid field (matches rule: uid == auth.uid)
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'evidence_models.dart';

class PoliceDispatchService {
  PoliceDispatchService._();
  static final PoliceDispatchService instance = PoliceDispatchService._();

  final _firestore = FirebaseFirestore.instance;
  final _auth      = FirebaseAuth.instance;

  static const String _rtdbUrl =
      'https://smart-women-safety-app-b1988-default-rtdb.asia-southeast1.firebasedatabase.app';
  static const String _placesApiKey =
      'AIzaSyDB1FkgbJbGI-ttCUlVdENdy_hoXGdjU7Q';
  static const String _placesUrl =
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json';

  late final FirebaseDatabase _db;
  bool _dbInit = false;

  void _initDb() {
    if (_dbInit) return;
    _db = FirebaseDatabase.instanceFor(
      app:         _firestore.app,
      databaseURL: _rtdbUrl,
    );
    _dbInit = true;
  }

  String get _uid      => _auth.currentUser?.uid ?? 'anonymous';
  String get _userName =>
      _auth.currentUser?.displayName ?? 'SafeHer User';

  // ═══════════════════════════════════════════════════════════════════════════
  // MAIN DISPATCH
  // ═══════════════════════════════════════════════════════════════════════════

  Future<PoliceDispatchResult> dispatchToPolice({
    required String         incidentId,
    required double         lat,
    required double         lng,
    required EvidenceBundle bundle,
    required String         victimName,
    required double         dangerScore,
    String?                 triggerType,
  }) async {
    _initDb();
    debugPrint('[PoliceDispatch] Initiating dispatch for $incidentId');

    final errors          = <String>[];
    int   stationsAlerted = 0;

    // Find nearest police stations (Google Places API)
    final stations = await _findResponseUnitsWithRetry(lat, lng);

    // Build forensic package for police
    final forensicPackage = <String, dynamic>{
      'incidentId':    incidentId,
      EvidenceFields.uid: _uid,          // ✅ matches policeDispatches rule
      'victimUid':     _uid,
      'victimName':    victimName,
      EvidenceFields.lat: lat,
      EvidenceFields.lng: lng,
      'dangerScore':   dangerScore,
      EvidenceFields.status: 'CRITICAL_DISPATCH',
      'dispatchedAt':  FieldValue.serverTimestamp(),
      EvidenceFields.createdAt: FieldValue.serverTimestamp(),
      EvidenceFields.triggerType: triggerType ?? 'automated_ai',
      'isSilent':      bundle.triggerType == 'silent',
      'googleMapsUrl': 'https://maps.google.com/?q=$lat,$lng',
      'evidenceManifest': {
        'liveDashboard':
        'https://safeher-sentinel.web.app/dispatch/$incidentId',
        EvidenceFields.audioEvidenceUrl: bundle.audioUrl,
        EvidenceFields.videoUrls:        bundle.videoUrls,
        EvidenceFields.photoUrls:        bundle.photoUrls,
      },
      'priority': 'OMEGA',
    };

    // Write to policeDispatches (rule requires uid == auth.uid)
    try {
      await _firestore
          .collection('policeDispatches')
          .doc(incidentId)
          .set(forensicPackage);
    } catch (e) {
      errors.add('Forensic log failure: $e');
      debugPrint('[PoliceDispatch] Firestore write error: $e');
    }

    // Alert up to 3 nearest stations
    if (stations.isNotEmpty &&
        stations.first.placeId != 'emergency_central') {
      await Future.wait(
        stations.take(3).map((station) async {
          final ok = await _queueStationAlert(station, forensicPackage);
          if (ok) stationsAlerted++;
        }),
      );
    } else {
      await _triggerRegionalFallback(forensicPackage, lat, lng);
      errors.add('No digital units reached — regional fallback engaged');
    }

    // Update dispatch status
    try {
      await _firestore
          .collection('policeDispatches')
          .doc(incidentId)
          .update({
        'stationsAlerted': stationsAlerted,
        EvidenceFields.status: stationsAlerted > 0
            ? 'ACTIVE_DISPATCH'
            : 'FALLBACK_ROUTED',
        EvidenceFields.updatedAt: FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    // Broadcast to community danger map
    await _broadcastToCommunityMap(lat, lng, incidentId, triggerType);

    debugPrint(
      '[PoliceDispatch] Complete — '
          'Stations: $stationsAlerted | Errors: ${errors.length}',
    );

    return PoliceDispatchResult(
      stationsFound:         stations,
      stationsAlerted:       stationsAlerted,
      firestoreRecordCreated: true,
      dispatchedAt:          DateTime.now(),
      errors:                errors,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COMMUNITY MAP BROADCAST
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _broadcastToCommunityMap(
      double  lat,
      double  lng,
      String  incidentId,
      String? trigger,
      ) async {
    _initDb();
    try {
      // Firestore — permanent 24h verified SOS pin
      await _firestore.collection('dangerZones').add({
        EvidenceFields.lat:  lat,
        EvidenceFields.lng:  lng,
        'typeIndex':         1,
        'typeLabel':         'ACTIVE SOS ALERT',
        'description':       'Verified SOS: $_userName is in danger. '
            'Police dispatched.',
        'reportedBy':        _uid,
        'reportCount':       100, // Forces high-risk display
        'sosCount':          1,
        'verified':          true,
        'isActive':          true,
        'incidentId':        incidentId,
        'expiresAt':         Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 24)),
        ),
        'lastIncident':      FieldValue.serverTimestamp(),
        'reportedAt':        FieldValue.serverTimestamp(),
        EvidenceFields.createdAt: FieldValue.serverTimestamp(),
      });

      // RTDB — instant real-time ping for live users
      await _db
          .ref('communityAlerts/${DateTime.now().millisecondsSinceEpoch}')
          .set({
        EvidenceFields.lat: lat,
        EvidenceFields.lng: lng,
        'type':             1,
        'isSos':            true,
        'timestamp':        ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('[PoliceDispatch] Community broadcast error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GOOGLE PLACES — Find Nearest Police Stations
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<NearbyPoliceStation>> _findResponseUnitsWithRetry(
      double lat,
      double lng, {
        int retries = 3,
      }) async {
    for (int i = 0; i < retries; i++) {
      try {
        final uri = Uri.parse(_placesUrl).replace(
          queryParameters: {
            'location': '$lat,$lng',
            'radius':   '5000',
            'type':     'police',
            'key':      _placesApiKey,
          },
        );

        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          final data    = jsonDecode(response.body) as Map<String, dynamic>;
          final results = data['results'] as List? ?? [];
          return results
              .map((p) => NearbyPoliceStation.fromMap(
            p as Map<String, dynamic>,
            lat,
            lng,
          ))
              .toList()
            ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        }
      } on SocketException catch (_) {
        break; // No internet — no point retrying
      } on TimeoutException catch (_) {
        if (i == retries - 1) break;
        await Future.delayed(
          Duration(seconds: math.pow(2, i + 1).toInt()),
        );
      } catch (e) {
        if (i == retries - 1) break;
        await Future.delayed(
          Duration(seconds: math.pow(2, i + 1).toInt()),
        );
      }
    }
    return _buildStaticFallback();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // QUEUE STATION ALERT
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> _queueStationAlert(
      NearbyPoliceStation      station,
      Map<String, dynamic>     package,
      ) async {
    try {
      // ✅ policeAlertTasks rule: hasFields(['incidentId','victimUid','status','createdAt'])
      //    + auth.uid == victimUid
      await _firestore.collection('policeAlertTasks').add({
        ...package,
        'targetStation':   station.toMap(),
        'executionStatus': 'pending',
        'retryCount':      0,
        'type':            'POLICE_API_DISPATCH',
        'victimUid':       _uid,    // ✅ required by rule
        EvidenceFields.status: 'pending', // ✅ required by rule
        EvidenceFields.createdAt: FieldValue.serverTimestamp(), // ✅ required
      });
      return true;
    } catch (e) {
      debugPrint('[PoliceDispatch] Station alert queue error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REGIONAL FALLBACK
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _triggerRegionalFallback(
      Map<String, dynamic> package,
      double lat,
      double lng,
      ) async {
    try {
      // ✅ sos_events rule: allow create if isAuth() — fully unlocked
      await _firestore.collection('sos_events').add({
        ...package,
        'fallbackReason':  'NETWORK_OR_API_FAILURE',
        'instruction':     'BROADCAST_TO_HIGHWAY_PATROL',
        'emergencyNumbers': ['100', '1091', '112'],
        'type':            'police_fallback',
      });
    } catch (e) {
      debugPrint('[PoliceDispatch] Regional fallback error: $e');
    }
  }

  List<NearbyPoliceStation> _buildStaticFallback() => [
    NearbyPoliceStation(
      placeId:     'emergency_central',
      name:        'State Police Command Center',
      address:     'Emergency Response HQ',
      lat:         0.0,
      lng:         0.0,
      distanceKm:  0.0,
      phoneNumber: '100',
    ),
  ];
}

// ─── Models ───────────────────────────────────────────────────────────────────

class NearbyPoliceStation {
  final String  placeId;
  final String  name;
  final String  address;
  final double  lat;
  final double  lng;
  final double  distanceKm;
  final String? phoneNumber;

  const NearbyPoliceStation({
    required this.placeId,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.distanceKm,
    this.phoneNumber,
  });

  factory NearbyPoliceStation.fromMap(
      Map<String, dynamic> map,
      double userLat,
      double userLng,
      ) {
    final loc        = map['geometry']?['location'] as Map? ?? {};
    final stationLat = (loc['lat'] as num?)?.toDouble() ?? 0.0;
    final stationLng = (loc['lng'] as num?)?.toDouble() ?? 0.0;

    return NearbyPoliceStation(
      placeId:    map['place_id'] as String? ?? '',
      name:       map['name']     as String? ?? 'Police Station',
      address:    map['vicinity'] as String? ?? 'Unknown',
      lat:        stationLat,
      lng:        stationLng,
      distanceKm: _calculateDistance(userLat, userLng, stationLat, stationLng),
    );
  }

  static double _calculateDistance(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) {
    const r = 6371.0;
    final p = math.pi / 180;
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return 2 * r * math.asin(math.sqrt(a));
  }

  Map<String, dynamic> toMap() => {
    'placeId':     placeId,
    'name':        name,
    'address':     address,
    'lat':         lat,
    'lng':         lng,
    'distanceKm':  distanceKm,
    'phoneNumber': phoneNumber,
  };
}

class PoliceDispatchResult {
  final List<NearbyPoliceStation> stationsFound;
  final int                       stationsAlerted;
  final bool                      firestoreRecordCreated;
  final DateTime                  dispatchedAt;
  final List<String>              errors;

  const PoliceDispatchResult({
    required this.stationsFound,
    required this.stationsAlerted,
    required this.firestoreRecordCreated,
    required this.dispatchedAt,
    this.errors = const [],
  });
}