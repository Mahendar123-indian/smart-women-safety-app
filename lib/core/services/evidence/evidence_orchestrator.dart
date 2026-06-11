// lib/core/services/evidence/evidence_orchestrator.dart
// ─────────────────────────────────────────────────────────────────────────────
// SAFEHER — EVIDENCE ORCHESTRATOR v8.0 (COMPLETE REWRITE)
// ─────────────────────────────────────────────────────────────────────────────
// ✅ Uses EvidenceStoragePaths for consistent path building across all services
// ✅ Writes evidenceFolderName to Firestore so Repository can find evidence
// ✅ null-safe bundle updates via copyWith() with list spreads
// ✅ Audio runs parallel, Photos→Video run sequential (camera hardware safe)
// ✅ GPS trail timer with proper cancellation and null guards
// ✅ Sensor flush with batch write — no individual Firestore calls per snapshot
// ✅ stopCollection() properly awaits all pipelines before returning bundle
// ✅ All Firestore writes use set+merge — no crash on fresh incident docs
// ✅ Timeline notifier for real-time UI evidence progress display
// ✅ StatusNotifier drives EvidenceProgressWidget in sos_screen
// ✅ Complete error isolation — one pipeline failure never kills others
// ✅ Singleton with _isCollecting mutex — zero double-trigger risk
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../audio_evidence_service.dart';
import '../camera_manager.dart';
import '../photo_evidence_service.dart';
import '../video_evidence_service.dart';
import 'evidence_models.dart';
import 'evidence_upload_queue.dart';

class EvidenceOrchestrator {
  EvidenceOrchestrator._();
  static final EvidenceOrchestrator instance = EvidenceOrchestrator._();

  // ── Firebase ────────────────────────────────────────────────────────────
  final _firestore = FirebaseFirestore.instance;
  final _auth      = FirebaseAuth.instance;
  String get _uid  => _auth.currentUser?.uid ?? '';

  // ── Public notifiers consumed by UI ─────────────────────────────────────
  final ValueNotifier<EvidenceSessionStatus> statusNotifier =
  ValueNotifier(EvidenceSessionStatus.idle);
  final ValueNotifier<EvidenceBundle?> bundleNotifier =
  ValueNotifier(null);
  final ValueNotifier<List<String>> timelineNotifier =
  ValueNotifier(const []);

  // ── Internal state ───────────────────────────────────────────────────────
  bool            _isCollecting     = false;
  EvidenceBundle? _activeBundle;
  String?         _activeIncidentId;
  DateTime?       _sessionStart;
  String?         _folderName;       // date-based storage folder

  // ── GPS trail ────────────────────────────────────────────────────────────
  Timer?              _gpsTimer;
  final List<GpsPoint> _gpsPoints = [];

  // ── Sensor logging ───────────────────────────────────────────────────────
  StreamSubscription? _accelSub;
  StreamSubscription? _gyroSub;
  double _lastGX = 0, _lastGY = 0, _lastGZ = 0;
  bool   _phoneFallen = false;
  final List<SensorSnapshot> _sensorSnapshots = [];

  // ── Pipeline completion tracking ─────────────────────────────────────────
  Completer<void>? _audioCompleter;
  Completer<void>? _visualCompleter;

  bool get isCollecting => _isCollecting;

  // ═══════════════════════════════════════════════════════════════════════════
  // START COLLECTION
  // ═══════════════════════════════════════════════════════════════════════════

  Future<EvidenceBundle> startCollection({
    required String incidentId,
    required double lat,
    required double lng,
    required double dangerScore,
    required String victimName,
    required bool   isSilent,
    String?         triggerType,
    CameraController? backCamera,
    CameraController? frontCamera,
  }) async {
    // ── Mutex guard — never double-start ──────────────────────────────────
    if (_isCollecting) {
      _addTimeline('⚠️ Collection already active — returning existing bundle');
      return _activeBundle!;
    }

    _isCollecting      = true;
    _activeIncidentId  = incidentId;
    _sessionStart      = DateTime.now();
    _phoneFallen       = false;
    _gpsPoints.clear();
    _sensorSnapshots.clear();

    // ── Build storage folder name ─────────────────────────────────────────
    _folderName = EvidenceStoragePaths.buildFolderName(_sessionStart!, incidentId);

    // ── Inject cameras into CameraManager ────────────────────────────────
    if (backCamera != null && frontCamera != null) {
      await CameraManager.instance.injectBothControllers(
        back:  backCamera,
        front: frontCamera,
      );
    } else if (backCamera != null) {
      await CameraManager.instance.injectBackController(backCamera);
    }

    _setStatus(EvidenceSessionStatus.starting);
    _addTimeline(
      '🚨 Evidence collection started | '
          '${(triggerType ?? 'manual').toUpperCase()} | '
          'Folder: $_folderName',
    );

    // ── Create initial bundle ─────────────────────────────────────────────
    final now = _sessionStart!;
    _activeBundle = EvidenceBundle(
      incidentId:         incidentId,
      uid:                _uid,
      collectedAt:        now,
      dangerScore:        dangerScore,
      triggerType:        triggerType ?? 'manual',
      address:            '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
      isNightTime:        now.hour >= 20 || now.hour < 6,
      evidenceFolderName: _folderName,
    );
    bundleNotifier.value = _activeBundle;

    // ── Write folder name to Firestore immediately so Repository can find it
    await _mergeToIncident(incidentId, {
      EvidenceFields.evidenceFolderName: _folderName,
      EvidenceFields.evidenceStatus:     EvidenceStatus.securing,
      EvidenceFields.isNightTime:        _activeBundle!.isNightTime,
    });

    // ── Start upload queue engine ─────────────────────────────────────────
    await EvidenceUploadQueue.instance.start();

    // ── Start background pipelines ────────────────────────────────────────
    _startGpsTrail(incidentId, lat, lng, dangerScore);
    _startSensorLogging(incidentId);
    _setStatus(EvidenceSessionStatus.collecting);

    // ── PIPELINE A: Audio — independent recorder, runs in parallel ────────
    _audioCompleter = Completer<void>();
    _runAudioPipeline(incidentId).then((_) {
      if (!_audioCompleter!.isCompleted) _audioCompleter!.complete();
    });

    // ── PIPELINE B: Photos → Video — sequential (share CameraManager) ─────
    _visualCompleter = Completer<void>();
    _runVisualPipeline(incidentId, lat, lng).then((_) {
      if (!_visualCompleter!.isCompleted) _visualCompleter!.complete();
    });

    _addTimeline('✅ All evidence pipelines launched');
    return _activeBundle!;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AUDIO PIPELINE
  // Runs on dedicated AudioRecorder — completely independent of camera.
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _runAudioPipeline(String incidentId) async {
    try {
      _addTimeline('🎙️ Audio: stopping ML loop, starting forensic recording');

      // Stop background ML audio loop so hardware channel is free
      await AudioEvidenceService.instance.stopMlAudioLoop();

      final clip = await AudioEvidenceService.instance.recordEvidenceClip(
        uid:        _uid,
        incidentId: incidentId,
        folderName: _folderName!,
      );

      if (clip == null) {
        _addTimeline('⚠️ Audio: capture returned null — mic permission denied?');
        return;
      }

      _updateBundle(
        _activeBundle?.copyWith(
          audioUrl:           clip.storageUrl,
          audioDuration:      clip.duration,
          audioPeakAmplitude: clip.peakAmplitude,
        ),
      );

      if (clip.storageUrl != null) {
        await _mergeToIncident(incidentId, {
          EvidenceFields.audioEvidenceUrl:   clip.storageUrl,
          EvidenceFields.audioUrl:           clip.storageUrl,
          EvidenceFields.audioDurationSec:   clip.duration.inSeconds,
          EvidenceFields.audioPeakAmplitude: clip.peakAmplitude,
        });
        _addTimeline(
          '✅ Audio: ${clip.duration.inSeconds}s | '
              '${clip.fileSizeBytes ~/ 1024}KB | '
              'Peak: ${clip.peakAmplitude?.toStringAsFixed(2) ?? '?'}',
        );
      } else {
        _addTimeline('⚠️ Audio: recorded but upload failed — queued for retry');
      }
    } catch (e, st) {
      _addTimeline('❌ Audio pipeline error: $e');
      debugPrint('[EvidenceOrchestrator] Audio error: $e\n$st');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VISUAL PIPELINE: Photos THEN Video
  // Sequential — both share CameraManager's single active controller.
  // Running parallel would cause camera hardware conflict on Android.
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _runVisualPipeline(
      String incidentId,
      double lat,
      double lng,
      ) async {
    await _runPhotoPipeline(incidentId, lat, lng);
    if (_isCollecting) {
      await _runVideoPipeline(incidentId, lat, lng);
    }
  }

  Future<void> _runPhotoPipeline(
      String incidentId,
      double lat,
      double lng,
      ) async {
    try {
      _addTimeline('📷 Photo: starting burst (3 back + 3 front)');

      final photos = await PhotoEvidenceService.instance.captureEvidenceSet(
        uid:        _uid,
        incidentId: incidentId,
        folderName: _folderName!,
        gpsCoords:  '$lat,$lng',
      );

      if (photos.isEmpty) {
        _addTimeline('⚠️ Photo: no photos captured');
        return;
      }

      final uploadedUrls = photos
          .where((p) => p.storageUrl != null && p.storageUrl!.isNotEmpty)
          .map((p) => p.storageUrl!)
          .toList();

      final localPaths = photos.map((p) => p.localPath).toList();
      final frontCount = photos.where((p) => p.facing == CameraFacing.front).length;
      final backCount  = photos.where((p) => p.facing == CameraFacing.back).length;

      _updateBundle(
        _activeBundle?.copyWith(
          photoUrls:       [
            ...(_activeBundle?.photoUrls ?? []),
            ...uploadedUrls,
          ],
          photoLocalPaths: [
            ...(_activeBundle?.photoLocalPaths ?? []),
            ...localPaths,
          ],
          frontPhotoCount: frontCount,
          backPhotoCount:  backCount,
        ),
      );

      if (uploadedUrls.isNotEmpty) {
        await _mergeToIncident(incidentId, {
          EvidenceFields.photoUrls:       FieldValue.arrayUnion(uploadedUrls),
          EvidenceFields.photoBurstUrls:  FieldValue.arrayUnion(uploadedUrls),
          EvidenceFields.frontPhotoCount: frontCount,
          EvidenceFields.backPhotoCount:  backCount,
        });
      }

      _addTimeline(
        '📷 Photo: ${photos.length} captured '
            '($frontCount front · $backCount back) | '
            '${uploadedUrls.length} uploaded',
      );
    } catch (e, st) {
      _addTimeline('❌ Photo pipeline error: $e');
      debugPrint('[EvidenceOrchestrator] Photo error: $e\n$st');
    }
  }

  Future<void> _runVideoPipeline(
      String incidentId,
      double lat,
      double lng,
      ) async {
    try {
      _addTimeline('🎥 Video: starting (30s back + 30s front)');

      final clips = await VideoEvidenceService.instance.captureEvidenceSet(
        uid:        _uid,
        incidentId: incidentId,
        folderName: _folderName!,
        gpsCoords:  '$lat,$lng',
      );

      if (clips.isEmpty) {
        _addTimeline('⚠️ Video: no clips captured');
        return;
      }

      final uploadedUrls = clips
          .where((c) => c.storageUrl != null && c.storageUrl!.isNotEmpty)
          .map((c) => c.storageUrl!)
          .toList();

      final localPaths   = clips.map((c) => c.localPath).toList();
      final totalSeconds = clips.fold(0, (s, c) => s + c.duration.inSeconds);

      _updateBundle(
        _activeBundle?.copyWith(
          videoUrls:          [
            ...(_activeBundle?.videoUrls ?? []),
            ...uploadedUrls,
          ],
          videoLocalPaths:    [
            ...(_activeBundle?.videoLocalPaths ?? []),
            ...localPaths,
          ],
          videoClipCount:     clips.length,
          totalVideoDuration: Duration(seconds: totalSeconds),
        ),
      );

      if (uploadedUrls.isNotEmpty) {
        await _mergeToIncident(incidentId, {
          EvidenceFields.videoUrls:             FieldValue.arrayUnion(uploadedUrls),
          EvidenceFields.videoClipCount:        clips.length,
          EvidenceFields.totalVideoDurationSec: totalSeconds,
        });
      }

      _addTimeline(
        '🎥 Video: ${clips.length} clips | '
            '${totalSeconds}s total | '
            '${uploadedUrls.length} uploaded',
      );
    } catch (e, st) {
      _addTimeline('❌ Video pipeline error: $e');
      debugPrint('[EvidenceOrchestrator] Video error: $e\n$st');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GPS TRAIL
  // Fires every 5 seconds while SOS is active.
  // Writes to Firestore breadcrumbs sub-collection for real-time contact map.
  // ═══════════════════════════════════════════════════════════════════════════

  void _startGpsTrail(
      String incidentId,
      double initialLat,
      double initialLng,
      double dangerScore,
      ) {
    // Add the trigger-point immediately
    final first = GpsPoint(
      lat:         initialLat,
      lng:         initialLng,
      accuracy:    0,
      speed:       0,
      heading:     0,
      altitude:    0,
      timestamp:   DateTime.now(),
      dangerScore: dangerScore,
    );
    _gpsPoints.add(first);
    _writeBreadcrumb(incidentId, first);

    _gpsTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!_isCollecting) return;
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy:  LocationAccuracy.high,
            timeLimit: Duration(seconds: 4),
          ),
        ).timeout(const Duration(seconds: 4));

        final point = GpsPoint(
          lat:         pos.latitude,
          lng:         pos.longitude,
          accuracy:    pos.accuracy,
          speed:       pos.speed * 3.6, // m/s → km/h
          heading:     pos.heading,
          altitude:    pos.altitude,
          timestamp:   DateTime.now(),
          dangerScore: dangerScore,
        );

        _gpsPoints.add(point);
        _writeBreadcrumb(incidentId, point);
      } catch (e) {
        // GPS timeout is expected — don't log spam
        debugPrint('[GPS Trail] Position timeout: $e');
      }
    });

    _addTimeline('📍 GPS trail started (every 5s)');
  }

  void _writeBreadcrumb(String incidentId, GpsPoint point) {
    _firestore
        .collection('users')
        .doc(_uid)
        .collection('incidents')
        .doc(incidentId)
        .collection('breadcrumbs')
        .add({
      ...point.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    })
        .catchError((e) => debugPrint('[GPS Trail] Breadcrumb write error: $e'));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SENSOR LOGGING
  // Accelerometer at 200ms — detects falls (magnitude > 35 m/s²).
  // Gyroscope at 200ms — detects struggle patterns.
  // Batch-flushes to JSON every 50 snapshots to minimize write operations.
  // ═══════════════════════════════════════════════════════════════════════════

  void _startSensorLogging(String incidentId) {
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 200),
    ).listen(
          (e) {
        if (!_isCollecting) return;

        final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);

        // Fall detection — 35 m/s² threshold
        if (mag > 35 && !_phoneFallen) {
          _phoneFallen = true;
          _updateBundle(_activeBundle?.copyWith(phoneFallen: true));
          _addTimeline('🚨 Fall detected! Acceleration: ${mag.toStringAsFixed(1)} m/s²');
          // Write immediately — don't wait for batch flush
          _mergeToIncident(incidentId, {EvidenceFields.phoneFallen: true});
        }

        _sensorSnapshots.add(SensorSnapshot(
          accelX: e.x,
          accelY: e.y,
          accelZ: e.z,
          gyroX:  _lastGX,
          gyroY:  _lastGY,
          gyroZ:  _lastGZ,
          magnitude: mag,
          isSignificantMovement: mag > 15,
          timestamp: DateTime.now(),
        ));

        // Batch flush every 50 snapshots (~10 seconds of data)
        if (_sensorSnapshots.length >= 50) {
          _flushSensorBatch(incidentId);
        }
      },
      onError: (e) => debugPrint('[Sensor] Accelerometer error: $e'),
    );

    _gyroSub = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 200),
    ).listen(
          (e) {
        _lastGX = e.x;
        _lastGY = e.y;
        _lastGZ = e.z;
      },
      onError: (e) => debugPrint('[Sensor] Gyroscope error: $e'),
    );

    _addTimeline('📡 Sensor logging started (accel + gyro at 200ms)');
  }

  Future<void> _flushSensorBatch(String incidentId) async {
    if (_sensorSnapshots.isEmpty || _folderName == null) return;

    final batch = List<SensorSnapshot>.from(_sensorSnapshots);
    _sensorSnapshots.clear();

    try {
      final json    = jsonEncode(batch.map((s) => s.toMap()).toList());
      final dir     = await getTemporaryDirectory();
      final ts      = DateTime.now().millisecondsSinceEpoch;
      final file    = File('${dir.path}/sensors_${incidentId}_$ts.json');
      await file.writeAsString(json);

      final storagePath = EvidenceStoragePaths.log(
        _uid,
        _folderName!,
        'sensors_$ts.json',
      );

      EvidenceUploadQueue.instance.enqueue(
        localPath:   file.path,
        storagePath: storagePath,
        contentType: 'application/json',
        metadata: {
          'incidentId': incidentId,
          'type':       'sensor_log',
          'batchTs':    '$ts',
        },
        incidentId: incidentId,
        uid:        _uid,
        type:       EvidenceType.sensorLog,
      );
    } catch (e) {
      debugPrint('[Sensor] Flush error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STOP COLLECTION
  // Awaits both audio and visual pipelines before returning final bundle.
  // ═══════════════════════════════════════════════════════════════════════════

  Future<EvidenceBundle?> stopCollection() async {
    if (!_isCollecting) return _activeBundle;

    _isCollecting = false;
    _setStatus(EvidenceSessionStatus.uploading);
    _addTimeline('🛑 Stopping collection — awaiting pipeline completion');

    // ── Cancel continuous streams ─────────────────────────────────────────
    _gpsTimer?.cancel();
    _gpsTimer = null;
    _accelSub?.cancel();
    _accelSub = null;
    _gyroSub?.cancel();
    _gyroSub = null;

    // ── Stop active recording early if still running ───────────────────────
    await VideoEvidenceService.instance.stopRecording();
    await AudioEvidenceService.instance.stopEarly();

    // ── Wait for both pipelines to finish (max 90s) ────────────────────────
    try {
      await Future.wait([
        if (_audioCompleter != null)
          _audioCompleter!.future.timeout(const Duration(seconds: 90)),
        if (_visualCompleter != null)
          _visualCompleter!.future.timeout(const Duration(seconds: 90)),
      ]);
    } catch (e) {
      _addTimeline('⚠️ Pipeline timeout on stop — saving partial evidence');
    }

    // ── Flush remaining sensor data ───────────────────────────────────────
    if (_activeIncidentId != null) {
      await _flushSensorBatch(_activeIncidentId!);
    }

    // ── Final Firestore update ────────────────────────────────────────────
    if (_activeIncidentId != null && _activeBundle != null) {
      await _mergeToIncident(_activeIncidentId!, {
        EvidenceFields.evidenceStatus: EvidenceStatus.collected,
        EvidenceFields.totalEvidence:  _activeBundle!.totalPieces,
        EvidenceFields.gpsPointCount:  _gpsPoints.length,
        EvidenceFields.phoneFallen:    _activeBundle!.phoneFallen,
        EvidenceFields.phoneInPocket:  _activeBundle!.phoneInPocket,
        EvidenceFields.updatedAt:      FieldValue.serverTimestamp(),
      });
    }

    _setStatus(EvidenceSessionStatus.complete);
    _addTimeline(
      '✅ Collection complete — '
          '${_activeBundle?.totalPieces ?? 0} evidence items secured | '
          '${_gpsPoints.length} GPS points',
    );

    // ── Log summary ───────────────────────────────────────────────────────
    debugPrint(
      '[EvidenceOrchestrator] COMPLETE — '
          'Photos: ${_activeBundle?.photoUrls.length ?? 0} | '
          'Videos: ${_activeBundle?.videoUrls.length ?? 0} | '
          'Audio: ${_activeBundle?.audioUrl != null ? "yes" : "no"} | '
          'GPS: ${_gpsPoints.length} pts | '
          'Folder: $_folderName',
    );

    final finalBundle  = _activeBundle;

    // ── Reset state ───────────────────────────────────────────────────────
    _activeBundle      = null;
    _activeIncidentId  = null;
    _sessionStart      = null;
    _folderName        = null;
    _audioCompleter    = null;
    _visualCompleter   = null;
    bundleNotifier.value = null;

    return finalBundle;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CAMERA INJECTION HELPER
  // Called from SOS screen when cameras are already initialized
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> updateActiveCameras({
    CameraController? back,
    CameraController? front,
  }) async {
    if (back != null && front != null) {
      await CameraManager.instance.injectBothControllers(
        back:  back,
        front: front,
      );
    } else if (back != null) {
      await CameraManager.instance.injectBackController(back);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Merge data into incident doc — always set+merge, never update
  Future<void> _mergeToIncident(
      String incidentId,
      Map<String, dynamic> data,
      ) async {
    try {
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('incidents')
          .doc(incidentId)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[EvidenceOrchestrator] Firestore merge error: $e');
    }
  }

  /// Thread-safe bundle update — always null-checks before assigning
  void _updateBundle(EvidenceBundle? updated) {
    if (updated == null) return;
    _activeBundle        = updated;
    bundleNotifier.value = updated;
  }

  void _addTimeline(String event) {
    final ts   = DateTime.now();
    final time =
        '${ts.hour.toString().padLeft(2, '0')}:'
        '${ts.minute.toString().padLeft(2, '0')}:'
        '${ts.second.toString().padLeft(2, '0')}';
    final entry = '[$time] $event';
    timelineNotifier.value = [...timelineNotifier.value, entry];
    debugPrint('[Evidence] $entry');
  }

  void _setStatus(EvidenceSessionStatus s) {
    statusNotifier.value = s;
  }
}