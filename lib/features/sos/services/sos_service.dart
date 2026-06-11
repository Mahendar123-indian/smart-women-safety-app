// lib/features/sos/services/sos_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// SAFEHER — HEADLESS SOS ENGINE v8.1
// ─────────────────────────────────────────────────────────────────────────────
// ✅ triggerSOS() — atomic mutex, zero double-trigger risk
// ✅ EvidenceOrchestrator.startCollection() awaited before dispatch
// ✅ Parallel dispatch: FCM + SMS + RTDB + Police simultaneously
// ✅ _resolveInternal() uses EvidenceFields constants — no typos
// ✅ screamProbability + audioAnalyzedForScream written on resolve
// ✅ evidenceFolderName preserved from bundle to Firestore
// ✅ Multi-format date parser — handles Timestamp, int, String
// ✅ SosEvent.fromFirestore() with full null safety
// ✅ PDF auto-generated 3s after resolve (evidence settled)
// ✅ Resolution notification fires after Firestore sealed
// ✅ Incident stream: real-time listener with error recovery
// ✅ FIX: digit-separator literals replaced (dart language compat)
// ✅ FIX: onError handlers return correct types
// ✅ FIX: dispatchToPolice() — only valid params passed (no isNightTime)
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/evidence/evidence_models.dart';
import '../../../core/services/evidence/evidence_orchestrator.dart';
import '../../../core/services/evidence/notification_dispatch_service.dart';
import '../../../core/services/evidence/police_dispatch_service.dart';
import '../../../core/services/evidence_pdf_service.dart';

// ─── SOS Status ───────────────────────────────────────────────────────────────

enum SosStatus { idle, countdown, active, resolved }

// ─── SOS Event Model ──────────────────────────────────────────────────────────

class SosEvent {
  final String   id;
  final DateTime triggeredAt;
  final double   lat;
  final double   lng;
  final double   dangerScore;
  final String   triggerType;
  final bool     isSilent;
  final String   status;

  const SosEvent({
    required this.id,
    required this.triggeredAt,
    required this.lat,
    required this.lng,
    required this.dangerScore,
    required this.triggerType,
    required this.isSilent,
    required this.status,
  });

  SosEvent copyWith({String? status}) => SosEvent(
    id:          id,
    triggeredAt: triggeredAt,
    lat:         lat,
    lng:         lng,
    dangerScore: dangerScore,
    triggerType: triggerType,
    isSilent:    isSilent,
    status:      status ?? this.status,
  );

  factory SosEvent.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return SosEvent(
      id:          doc.id,
      triggeredAt: _parseDate(d['triggeredAt'] ?? d['createdAt']),
      lat:         (d['lat']         as num?)?.toDouble() ?? 0.0,
      lng:         (d['lng']         as num?)?.toDouble() ?? 0.0,
      dangerScore: (d['dangerScore'] as num?)?.toDouble() ?? 0.0,
      triggerType:  d['triggerType'] as String? ?? 'manual',
      isSilent:     d['isSilent']    as bool?   ?? false,
      status:       d['status']      as String? ?? 'active',
    );
  }

  /// Handles Firestore Timestamp, epoch int (ms + s), and ISO String
  /// FIX: Replaced 1_000_000_000_000 with 1000000000000 (no digit separators)
  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is Timestamp) return v.toDate();
    if (v is int) {
      return v > 1000000000000
          ? DateTime.fromMillisecondsSinceEpoch(v)
          : DateTime.fromMillisecondsSinceEpoch(v * 1000);
    }
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  Map<String, dynamic> toMap() => {
    'id':          id,
    'triggeredAt': triggeredAt.toIso8601String(),
    'lat':         lat,
    'lng':         lng,
    'dangerScore': dangerScore,
    'triggerType': triggerType,
    'isSilent':    isSilent,
    'status':      status,
  };
}

// ─── SOS Service ──────────────────────────────────────────────────────────────

class SosService {
  SosService._();
  static final SosService instance = SosService._();

  final _firestore = FirebaseFirestore.instance;
  final _auth      = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  // ── Internal state ────────────────────────────────────────────────────────
  SosStatus            _status            = SosStatus.idle;
  SosEvent?            _activeEvent;
  double               _latestDangerScore = 0.0;
  final List<SosEvent> _incidents         = [];
  StreamSubscription?  _incidentsSub;

  // Mutex — prevents double-trigger from simultaneous callbacks
  bool _isSosStarting = false;

  // ── Public notifiers ──────────────────────────────────────────────────────
  final ValueNotifier<SosStatus>      statusNotifier    = ValueNotifier(SosStatus.idle);
  final ValueNotifier<SosEvent?>      activeNotifier    = ValueNotifier(null);
  final ValueNotifier<List<SosEvent>> incidentsNotifier = ValueNotifier([]);

  // ── Getters ───────────────────────────────────────────────────────────────
  SosStatus      get status         => _status;
  SosEvent?      get activeEvent    => _activeEvent;
  bool           get isSosActive    => _status == SosStatus.active;
  bool           get isCountingDown => _status == SosStatus.countdown;
  List<SosEvent> get incidents      => List.unmodifiable(_incidents);

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════

  void init() {
    _listenToIncidents();
  }

  void _listenToIncidents() {
    if (_uid.isEmpty) return;
    _incidentsSub?.cancel();
    _incidentsSub = _firestore
        .collection('users')
        .doc(_uid)
        .collection('incidents')
        .orderBy('triggeredAt', descending: true)
        .limit(25)
        .snapshots()
        .listen(
          (snap) {
        _incidents
          ..clear()
          ..addAll(snap.docs.map(SosEvent.fromFirestore));
        incidentsNotifier.value = List<SosEvent>.from(_incidents);
      },
      onError: (Object e) {
        debugPrint('[SosService] Incident stream error: $e');
        incidentsNotifier.value = <SosEvent>[];
      },
    );
  }

  void updateDangerScore(double score) {
    _latestDangerScore = score.clamp(0.0, 1.0);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MASTER TRIGGER
  // ═══════════════════════════════════════════════════════════════════════════

  Future<SosEvent?> triggerSOS({
    bool              isSilent    = false,
    String            triggerType = 'manual',
    CameraController? backCamera,
    CameraController? frontCamera,
  }) async {
    // Atomic mutex — prevents ghost/double triggers
    if (_isSosStarting || _status == SosStatus.active) {
      debugPrint('[SosService] Trigger blocked — already active');
      return _activeEvent;
    }
    if (_uid.isEmpty) {
      debugPrint('[SosService] Trigger blocked — no authenticated user');
      return null;
    }

    _isSosStarting = true;

    try {
      debugPrint(
        '[SosService] 🚨 TRIGGER: $triggerType | '
            'Silent: $isSilent | '
            'DangerScore: ${(_latestDangerScore * 100).toInt()}%',
      );

      _status = SosStatus.active;
      statusNotifier.value = SosStatus.active;

      // 1. Acquire GPS (4s timeout — never blocks SOS)
      final pos = await _getLocation();
      final lat = pos?.latitude  ?? 0.0;
      final lng = pos?.longitude ?? 0.0;

      final victimName = await _getVictimName();

      // 2. Create Firestore incident document immediately
      final docRef = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('incidents')
          .add({
        EvidenceFields.uid:            _uid,
        EvidenceFields.lat:            lat,
        EvidenceFields.lng:            lng,
        EvidenceFields.dangerScore:    _latestDangerScore,
        EvidenceFields.triggerType:    triggerType,
        EvidenceFields.isSilent:       isSilent,
        EvidenceFields.status:         IncidentStatus.active,
        EvidenceFields.evidenceStatus: EvidenceStatus.securing,
        'triggeredAt':                 FieldValue.serverTimestamp(),
        EvidenceFields.createdAt:      FieldValue.serverTimestamp(),
      });

      final event = SosEvent(
        id:          docRef.id,
        triggeredAt: DateTime.now(),
        lat:         lat,
        lng:         lng,
        dangerScore: _latestDangerScore,
        triggerType: triggerType,
        isSilent:    isSilent,
        status:      IncidentStatus.active,
      );

      _activeEvent         = event;
      activeNotifier.value = event;

      // 3. Start forensic evidence collection — AWAIT so bundle is ready
      final bundle = await EvidenceOrchestrator.instance.startCollection(
        incidentId:  docRef.id,
        lat:         lat,
        lng:         lng,
        dangerScore: _latestDangerScore,
        victimName:  victimName,
        isSilent:    isSilent,
        triggerType: triggerType,
        backCamera:  backCamera,
        frontCamera: frontCamera,
      );

      // 4. Parallel omega dispatch — all channels fire simultaneously
      _dispatchAll(
        event:      event,
        bundle:     bundle,
        victimName: victimName,
      );

      debugPrint(
        '[SosService] ✅ SOS pipeline complete — '
            'IncidentID: ${docRef.id}',
      );

      return event;
    } catch (e, st) {
      debugPrint('[SosService] ❌ CRITICAL FAILURE: $e\n$st');
      _status = SosStatus.idle;
      statusNotifier.value = SosStatus.idle;
      rethrow;
    } finally {
      _isSosStarting = false;
    }
  }

  /// Fire all dispatch channels in parallel — never awaited (fire-and-forget)
  void _dispatchAll({
    required SosEvent       event,
    required EvidenceBundle bundle,
    required String         victimName,
  }) {
    Future.wait([
      NotificationDispatchService.instance.dispatchAll(
        incidentId:  event.id,
        lat:         event.lat,
        lng:         event.lng,
        bundle:      bundle,
        victimName:  victimName,
        dangerScore: event.dangerScore,
        isSilent:    event.isSilent,
        triggerType: event.triggerType,
      ),
      // ✅ Only params that exist in dispatchToPolice() signature are passed.
      //    dispatchToPolice() signature:
      //      required incidentId, lat, lng, bundle, victimName, dangerScore
      //      optional triggerType  ← String?  (no isNightTime — never existed)
      PoliceDispatchService.instance.dispatchToPolice(
        incidentId:  event.id,
        lat:         event.lat,
        lng:         event.lng,
        bundle:      bundle,
        victimName:  victimName,
        dangerScore: event.dangerScore,
        triggerType: event.triggerType, // ✅ optional — passed correctly
      ),
    ]).catchError((Object e) {
      debugPrint('[SosService] Dispatch error: $e');
      // FIX: Future.wait returns Future<List<dynamic>>, catchError must
      //      return List<dynamic>
      return <dynamic>[];
    });
  }

  /// Silent SOS — used by Shake / Voice / Hardware triggers
  Future<SosEvent?> triggerSilentSOS({
    CameraController? backCamera,
    CameraController? frontCamera,
    String            triggerType = 'silent',
  }) =>
      triggerSOS(
        isSilent:    true,
        triggerType: triggerType,
        backCamera:  backCamera,
        frontCamera: frontCamera,
      );

  // ═══════════════════════════════════════════════════════════════════════════
  // RESOLVE SOS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> resolveSosWithPin(
      String pin, {
        bool isFalseAlarm = false,
      }) async {
    final prefs    = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('sos_safe_pin') ?? '1234';

    if (pin != savedPin) {
      debugPrint('[SosService] Resolve blocked — wrong PIN');
      return false;
    }

    await _resolveInternal(isFalseAlarm: isFalseAlarm);
    return true;
  }

  Future<void> _resolveInternal({bool isFalseAlarm = false}) async {
    if (_status != SosStatus.active) return;

    _status = SosStatus.resolved;
    statusNotifier.value = SosStatus.resolved;

    final event = _activeEvent;

    // Step 1: Stop all evidence pipelines — get final bundle
    final bundle = await EvidenceOrchestrator.instance.stopCollection();

    if (event != null) {
      debugPrint(
        '[SosService] Sealing forensic manifest — '
            '${bundle?.totalPieces ?? 0} evidence items',
      );

      // Step 2: Seal incident in Firestore
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('incidents')
          .doc(event.id)
          .set({
        EvidenceFields.status: isFalseAlarm
            ? IncidentStatus.falseAlarm
            : IncidentStatus.resolved,
        EvidenceFields.resolvedAt:   FieldValue.serverTimestamp(),
        EvidenceFields.updatedAt:    FieldValue.serverTimestamp(),
        'isFalseAlarm':              isFalseAlarm,
        EvidenceFields.evidenceStatus:     EvidenceStatus.sealed,
        EvidenceFields.totalEvidence:      bundle?.totalPieces ?? 0,
        EvidenceFields.evidenceFolderName: bundle?.evidenceFolderName,

        // Audio
        EvidenceFields.audioEvidenceUrl:   bundle?.audioUrl,
        EvidenceFields.audioUrl:           bundle?.audioUrl,
        EvidenceFields.audioDurationSec:   bundle?.audioDuration?.inSeconds,
        EvidenceFields.audioPeakAmplitude: bundle?.audioPeakAmplitude,
        EvidenceFields.screamProbability:      bundle?.screamProbability,
        EvidenceFields.audioAnalyzedForScream: bundle?.audioAnalyzedForScream ?? false,

        // Photos
        EvidenceFields.photoUrls:       bundle?.photoUrls      ?? [],
        EvidenceFields.photoBurstUrls:  bundle?.photoUrls      ?? [],
        EvidenceFields.frontPhotoCount: bundle?.frontPhotoCount ?? 0,
        EvidenceFields.backPhotoCount:  bundle?.backPhotoCount  ?? 0,

        // Videos
        EvidenceFields.videoUrls:             bundle?.videoUrls          ?? [],
        EvidenceFields.videoClipCount:        bundle?.videoUrls.length   ?? 0,
        EvidenceFields.totalVideoDurationSec: bundle?.totalVideoDuration?.inSeconds,

        // Sensors
        EvidenceFields.phoneFallen:   bundle?.phoneFallen   ?? false,
        EvidenceFields.phoneInPocket: bundle?.phoneInPocket ?? false,
        EvidenceFields.sensorLogUrl:  bundle?.sensorLogUrl,

        // GPS
        EvidenceFields.gpsTrailFirestorePath: bundle?.gpsTrailFirestorePath,
      }, SetOptions(merge: true));

      // Step 3: Notify resolution to all contacts + police
      NotificationDispatchService.instance
          .notifyResolution(
        incidentId:   event.id,
        isFalseAlarm: isFalseAlarm,
      )
          .catchError((Object e) {
        debugPrint('[SosService] Resolution notify error: $e');
      });

      // Step 4: Auto-generate court-ready PDF (3s delay for Firestore settle)
      Future.delayed(const Duration(seconds: 3), () {
        EvidencePdfService.instance
            .autoGenerateOnResolve(event.id)
            .catchError((Object e) {
          debugPrint('[SosService] PDF generation error: $e');
        });
      });

      debugPrint('[SosService] ✅ Incident sealed: ${event.id}');
    }

    // Step 5: Clear active state
    _activeEvent         = null;
    activeNotifier.value = null;

    // Hold resolved state 3s for UI propagation, then reset to idle
    await Future.delayed(const Duration(seconds: 3));
    _status              = SosStatus.idle;
    statusNotifier.value = SosStatus.idle;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PIN MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> changePin(String oldPin, String newPin) async {
    final prefs    = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('sos_safe_pin') ?? '1234';
    if (oldPin != savedPin) return false;
    if (newPin.length < 4) return false;
    await prefs.setString('sos_safe_pin', newPin);
    debugPrint('[SosService] Safe PIN updated');
    return true;
  }

  Future<String> getSafePin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('sos_safe_pin') ?? '1234';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Position?> _getLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy:  LocationAccuracy.high,
          timeLimit: Duration(seconds: 4),
        ),
      ).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('[SosService] GPS acquisition timeout: $e');
      return null;
    }
  }

  Future<String> _getVictimName() async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(_uid)
          .get();
      return doc.data()?['name'] as String?
          ?? _auth.currentUser?.displayName
          ?? 'SafeHer User';
    } catch (_) {
      return _auth.currentUser?.displayName ?? 'SafeHer User';
    }
  }

  void dispose() {
    _incidentsSub?.cancel();
    statusNotifier.dispose();
    activeNotifier.dispose();
    incidentsNotifier.dispose();
  }
}