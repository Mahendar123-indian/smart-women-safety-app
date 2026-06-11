// lib/core/services/video_evidence_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// SAFEHER — VIDEO EVIDENCE SERVICE v8.0
// ─────────────────────────────────────────────────────────────────────────────
// ✅ captureEvidenceSet() accepts folderName — uses EvidenceStoragePaths
// ✅ Storage path: evidence/{uid}/{folderName}/video/{fileName}
// ✅ set+merge on Firestore — no crash on fresh doc
// ✅ Injected camera controllers — instant switch, zero hardware remount
// ✅ Completer-based cancellation — stopRecording() exits loop cleanly
// ✅ 0-byte file check before upload — skips corrupt recordings
// ✅ Unique filename: {facing}_{timestamp}.mp4 — no Storage overwrite
// ✅ 800ms buffer flush pause between back and front clips
// ✅ progressNotifier tracks upload progress for EvidenceProgressWidget
// ✅ elapsedSecondsNotifier drives recording timer in UI
// ✅ Sub-collection evidence record per clip for vault screen
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';

import 'camera_manager.dart';
import 'evidence/evidence_models.dart';

// ─── Status ───────────────────────────────────────────────────────────────────

enum VideoEvidenceStatus {
  idle,
  initializing,
  recording,
  processing,
  uploading,
  completed,
  failed,
}

// ─── Result ───────────────────────────────────────────────────────────────────

class VideoClipResult {
  final String       localPath;
  final String?      storageUrl;
  final CameraFacing facing;
  final DateTime     startedAt;
  final DateTime     endedAt;
  final Duration     duration;
  final String?      gpsCoords;
  final int          fileSizeBytes;
  final bool         uploaded;

  const VideoClipResult({
    required this.localPath,
    this.storageUrl,
    required this.facing,
    required this.startedAt,
    required this.endedAt,
    required this.duration,
    this.gpsCoords,
    required this.fileSizeBytes,
    required this.uploaded,
  });

  Map<String, dynamic> toMap() => {
    'localPath':       localPath,
    'storageUrl':      storageUrl,
    'facing':          facing.name,
    'startedAt':       startedAt.toIso8601String(),
    'endedAt':         endedAt.toIso8601String(),
    'durationSeconds': duration.inSeconds,
    'gpsCoords':       gpsCoords,
    'fileSizeBytes':   fileSizeBytes,
    'uploaded':        uploaded,
    'type':            'video_evidence',
  };
}

// ─── Service ──────────────────────────────────────────────────────────────────

class VideoEvidenceService {
  VideoEvidenceService._();
  static final VideoEvidenceService instance = VideoEvidenceService._();

  final _storage   = FirebaseStorage.instance;
  final _firestore = FirebaseFirestore.instance;

  final ValueNotifier<VideoEvidenceStatus> statusNotifier =
  ValueNotifier(VideoEvidenceStatus.idle);
  final ValueNotifier<double> progressNotifier       = ValueNotifier(0.0);
  final ValueNotifier<int>    elapsedSecondsNotifier = ValueNotifier(0);

  final List<VideoClipResult> _clips = [];
  List<VideoClipResult> get clips => List.unmodifiable(_clips);

  Timer?           _elapsedTimer;
  Completer<void>? _cancelCompleter;
  bool             _cancelled = false;

  static const int _clipDurationSeconds = 30; // 30s back + 30s front

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIMARY CAPTURE SEQUENCE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<VideoClipResult>> captureEvidenceSet({
    required String uid,
    required String incidentId,
    required String folderName,  // ✅ date-based folder from orchestrator
    String?         gpsCoords,
  }) async {
    _clips.clear();
    _cancelled       = false;
    _cancelCompleter = Completer<void>();
    _setStatus(VideoEvidenceStatus.initializing);

    try {
      // Phase 1: Back camera clip (30s)
      final backClip = await _recordClip(
        uid:        uid,
        incidentId: incidentId,
        folderName: folderName,
        facing:     CameraFacing.back,
        clipIndex:  0,
        gpsCoords:  gpsCoords,
      );
      if (backClip != null) _clips.add(backClip);

      if (_cancelled) {
        _setStatus(VideoEvidenceStatus.completed);
        return _clips;
      }

      // 800ms buffer flush pause between clips
      try {
        await _cancelCompleter!.future
            .timeout(const Duration(milliseconds: 800));
        // Completer fired = cancelled
        _setStatus(VideoEvidenceStatus.completed);
        return _clips;
      } on TimeoutException {
        // Normal — 800ms elapsed, proceed to front clip
      }

      // Phase 2: Front camera clip (30s)
      final frontClip = await _recordClip(
        uid:        uid,
        incidentId: incidentId,
        folderName: folderName,
        facing:     CameraFacing.front,
        clipIndex:  1,
        gpsCoords:  gpsCoords,
      );
      if (frontClip != null) _clips.add(frontClip);

      _setStatus(VideoEvidenceStatus.completed);
      debugPrint('[VideoEvidence] Complete: ${_clips.length} clips');
      return _clips;
    } catch (e, st) {
      _setStatus(VideoEvidenceStatus.failed);
      debugPrint('[VideoEvidence] Sequence failed: $e\n$st');
      return _clips;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RECORDING ENGINE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<VideoClipResult?> _recordClip({
    required String       uid,
    required String       incidentId,
    required String       folderName,
    required CameraFacing facing,
    required int          clipIndex,
    String?               gpsCoords,
  }) async {
    final mgr = CameraManager.instance;

    // Switch using injected controllers — instant, no hardware crash
    final switched = facing == CameraFacing.back
        ? await mgr.switchToBack()
        : await mgr.switchToFront();

    if (!switched || !mgr.hasController) {
      debugPrint(
        '[VideoEvidence] Camera unavailable for ${facing.name} — skipping',
      );
      return null;
    }

    if (_cancelled) return null;

    final controller = mgr.controller!;
    final startTime  = DateTime.now();

    // Create local evidence directory
    final dir         = await getApplicationDocumentsDirectory();
    final evidenceDir = Directory(
      '${dir.path}/evidence/video/$incidentId',
    );
    if (!await evidenceDir.exists()) {
      await evidenceDir.create(recursive: true);
    }

    final timestamp = startTime.millisecondsSinceEpoch;
    // Unique filename — prevents Storage overwrite
    final filePath  = '${evidenceDir.path}/${facing.name}_$timestamp.mp4';

    // UI progress timer
    _elapsedTimer?.cancel();
    elapsedSecondsNotifier.value = 0;
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      elapsedSecondsNotifier.value = t.tick;
      progressNotifier.value =
          (t.tick / _clipDurationSeconds).clamp(0.0, 1.0);
    });

    _setStatus(VideoEvidenceStatus.recording);

    try {
      await controller.startVideoRecording();
      debugPrint(
        '[VideoEvidence] Recording ${facing.name.toUpperCase()} camera...',
      );

      // Wait for clip duration OR early cancellation
      try {
        await _cancelCompleter!.future
            .timeout(Duration(seconds: _clipDurationSeconds));
        // Completer fired = cancelled early
      } on TimeoutException {
        // Normal — 30s elapsed, proceed to save
      }

      _elapsedTimer?.cancel();

      if (_cancelled) {
        if (controller.value.isRecordingVideo) {
          await controller.stopVideoRecording();
        }
        return null;
      }

      if (!controller.value.isRecordingVideo) {
        debugPrint('[VideoEvidence] Controller stopped recording unexpectedly');
        return null;
      }

      final xFile   = await controller.stopVideoRecording();
      final rawFile = File(xFile.path);

      // Integrity check — skip corrupt/empty files
      if (!await rawFile.exists() || await rawFile.length() == 0) {
        debugPrint(
          '[VideoEvidence] Corrupt/empty file: ${xFile.path}',
        );
        return null;
      }

      // Copy to evidence locker (persists across temp dir cleanup)
      final saved    = await rawFile.copy(filePath);
      final fileSize = await saved.length();
      final endTime  = DateTime.now();

      debugPrint(
        '[VideoEvidence] Clip secured: ${facing.name} | '
            '${fileSize ~/ 1024}KB | '
            '${endTime.difference(startTime).inSeconds}s',
      );

      _setStatus(VideoEvidenceStatus.uploading);

      final url = await _uploadToStorage(
        file:       saved,
        uid:        uid,
        incidentId: incidentId,
        folderName: folderName,
        facing:     facing,
        timestamp:  timestamp,
      );

      final clip = VideoClipResult(
        localPath:     saved.path,
        storageUrl:    url,
        facing:        facing,
        startedAt:     startTime,
        endedAt:       endTime,
        duration:      endTime.difference(startTime),
        gpsCoords:     gpsCoords,
        fileSizeBytes: fileSize,
        uploaded:      url != null,
      );

      await _saveClipMetadata(
        uid:        uid,
        incidentId: incidentId,
        clip:       clip,
        clipIndex:  clipIndex,
      );

      return clip;
    } catch (e, st) {
      _elapsedTimer?.cancel();
      try {
        if (controller.value.isRecordingVideo) {
          await controller.stopVideoRecording();
        }
      } catch (_) {}
      debugPrint(
        '[VideoEvidence] Recording failed (${facing.name}): $e\n$st',
      );
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UPLOAD AND FIRESTORE SYNC
  // ═══════════════════════════════════════════════════════════════════════════

  Future<String?> _uploadToStorage({
    required File         file,
    required String       uid,
    required String       incidentId,
    required String       folderName,
    required CameraFacing facing,
    required int          timestamp,
  }) async {
    try {
      final fileName    = '${facing.name}_$timestamp.mp4';
      final storagePath = EvidenceStoragePaths.video(uid, folderName, fileName);
      final ref         = _storage.ref().child(storagePath);

      final metadata = SettableMetadata(
        contentType:    'video/mp4',
        customMetadata: {
          'uid':          uid,
          'incidentId':   incidentId,
          'facing':       facing.name,
          'capturedAt':   DateTime.now().toIso8601String(),
          'evidenceType': 'video',
        },
      );

      final task = ref.putFile(file, metadata);

      // Track upload progress for UI
      task.snapshotEvents.listen((snap) {
        if (snap.totalBytes > 0) {
          progressNotifier.value =
              snap.bytesTransferred / snap.totalBytes;
        }
      });

      await task;
      final url = await ref.getDownloadURL();

      // set+merge — no crash if videoUrls field doesn't exist yet
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('incidents')
          .doc(incidentId)
          .set({
        EvidenceFields.videoUrls: FieldValue.arrayUnion([url]),
      }, SetOptions(merge: true));

      debugPrint('[VideoEvidence] Uploaded: ${facing.name} → $url');
      return url;
    } catch (e) {
      debugPrint('[VideoEvidence] Upload failed: $e');
      return null;
    }
  }

  Future<void> _saveClipMetadata({
    required String          uid,
    required String          incidentId,
    required VideoClipResult clip,
    required int             clipIndex,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('incidents')
          .doc(incidentId)
          .collection('evidence')
          .doc('video_${clip.facing.name}_$clipIndex')
          .set({
        ...clip.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[VideoEvidence] Metadata sync failed: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONTROLS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<VideoClipResult?> recordAdditionalClip({
    required String uid,
    required String incidentId,
    required String folderName,
    CameraFacing    facing = CameraFacing.back,
  }) async {
    _cancelled       = false;
    _cancelCompleter = Completer<void>();

    String? gpsCoords;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      gpsCoords = '${pos.latitude},${pos.longitude}';
    } catch (_) {}

    return _recordClip(
      uid:        uid,
      incidentId: incidentId,
      folderName: folderName,
      facing:     facing,
      clipIndex:  _clips.length,
      gpsCoords:  gpsCoords,
    );
  }

  Future<void> stopRecording() async {
    _cancelled = true;
    _elapsedTimer?.cancel();

    // Resolve completer immediately — exits timeout mutex
    if (_cancelCompleter != null && !_cancelCompleter!.isCompleted) {
      _cancelCompleter!.complete();
    }

    // Also stop hardware directly in case completer was already done
    try {
      final ctrl = CameraManager.instance.controller;
      if (ctrl != null && ctrl.value.isRecordingVideo) {
        await ctrl.stopVideoRecording();
      }
    } catch (_) {}

    _setStatus(VideoEvidenceStatus.idle);
    debugPrint('[VideoEvidence] Recording stopped');
  }

  void reset() {
    _clips.clear();
    _cancelled = false;
    _elapsedTimer?.cancel();
    statusNotifier.value         = VideoEvidenceStatus.idle;
    progressNotifier.value       = 0.0;
    elapsedSecondsNotifier.value = 0;
  }

  void _setStatus(VideoEvidenceStatus s) => statusNotifier.value = s;
}