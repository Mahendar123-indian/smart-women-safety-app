// lib/core/services/photo_evidence_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// SAFEHER — PHOTO EVIDENCE SERVICE v8.0
// ─────────────────────────────────────────────────────────────────────────────
// ✅ captureEvidenceSet() accepts folderName — uses EvidenceStoragePaths
// ✅ Storage path: evidence/{uid}/{folderName}/photos/{fileName}
// ✅ Writes BOTH photoUrls + photoBurstUrls (set+merge)
// ✅ Unique filename per frame: {facing}_{timestamp}_{burstIndex}.jpg
// ✅ storageUrl set on PhotoResult BEFORE returning — orchestrator gets URLs
// ✅ Camera switching uses injected controllers — instant, no hardware remount
// ✅ 400ms stabilization pause after each camera switch (AF + AE settle)
// ✅ 300ms burst interval between shots
// ✅ GPS embedded in metadata for each photo
// ✅ Sub-collection evidence record written per photo for vault screen
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

enum PhotoEvidenceStatus { idle, capturing, uploading, completed, failed }

// ─── Result ───────────────────────────────────────────────────────────────────

class PhotoResult {
  final String     localPath;
  String?          storageUrl;    // set after upload completes
  final CameraFacing facing;
  final DateTime   capturedAt;
  final int        fileSizeBytes;
  final String?    gpsCoords;
  bool             uploaded;
  final int        burstIndex;

  PhotoResult({
    required this.localPath,
    this.storageUrl,
    required this.facing,
    required this.capturedAt,
    required this.fileSizeBytes,
    this.gpsCoords,
    required this.uploaded,
    required this.burstIndex,
  });

  Map<String, dynamic> toMap() => {
    'localPath':     localPath,
    'storageUrl':    storageUrl,
    'facing':        facing.name,
    'capturedAt':    capturedAt.toIso8601String(),
    'fileSizeBytes': fileSizeBytes,
    'gpsCoords':     gpsCoords,
    'uploaded':      uploaded,
    'burstIndex':    burstIndex,
    'type':          'photo_evidence',
  };
}

// ─── Service ──────────────────────────────────────────────────────────────────

class PhotoEvidenceService {
  PhotoEvidenceService._();
  static final PhotoEvidenceService instance = PhotoEvidenceService._();

  final _storage   = FirebaseStorage.instance;
  final _firestore = FirebaseFirestore.instance;

  final ValueNotifier<PhotoEvidenceStatus> statusNotifier =
  ValueNotifier(PhotoEvidenceStatus.idle);
  final ValueNotifier<int> capturedCountNotifier = ValueNotifier(0);

  final List<PhotoResult> _photos = [];
  List<PhotoResult> get photos => List.unmodifiable(_photos);

  static const int _burstCount      = 3;    // 3 back + 3 front = 6 total
  static const int _burstIntervalMs = 300;  // 300ms between shots

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIMARY CAPTURE SEQUENCE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<PhotoResult>> captureEvidenceSet({
    required String uid,
    required String incidentId,
    required String folderName,  // ✅ date-based folder from orchestrator
    String?         gpsCoords,
  }) async {
    _photos.clear();
    capturedCountNotifier.value = 0;
    _setStatus(PhotoEvidenceStatus.capturing);

    // Try to get GPS for metadata embedding
    gpsCoords ??= await _getGps();

    try {
      // Phase 1: Back camera burst (3 shots)
      final backPhotos = await _burstCapture(
        uid:        uid,
        incidentId: incidentId,
        folderName: folderName,
        facing:     CameraFacing.back,
        gpsCoords:  gpsCoords,
      );
      _photos.addAll(backPhotos);
      capturedCountNotifier.value = _photos.length;

      // Phase 2: Front camera burst (3 shots)
      final frontPhotos = await _burstCapture(
        uid:        uid,
        incidentId: incidentId,
        folderName: folderName,
        facing:     CameraFacing.front,
        gpsCoords:  gpsCoords,
      );
      _photos.addAll(frontPhotos);
      capturedCountNotifier.value = _photos.length;

      _setStatus(PhotoEvidenceStatus.completed);
      debugPrint(
        '[PhotoEvidence] Complete: ${_photos.length} photos '
            '(${backPhotos.length} back + ${frontPhotos.length} front)',
      );
      return _photos;
    } catch (e, st) {
      _setStatus(PhotoEvidenceStatus.failed);
      debugPrint('[PhotoEvidence] Sequence failed: $e\n$st');
      return _photos; // return partial if any captured
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BURST ENGINE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<PhotoResult>> _burstCapture({
    required String       uid,
    required String       incidentId,
    required String       folderName,
    required CameraFacing facing,
    String?               gpsCoords,
  }) async {
    final mgr = CameraManager.instance;

    // Switch camera — uses injected controller (instant, no hardware remount)
    final switched = facing == CameraFacing.back
        ? await mgr.switchToBack()
        : await mgr.switchToFront();

    if (!switched || mgr.controller == null) {
      debugPrint(
        '[PhotoEvidence] Camera unavailable for ${facing.name} — skipping',
      );
      return [];
    }

    final controller = mgr.controller!;
    if (!controller.value.isInitialized) {
      debugPrint(
        '[PhotoEvidence] Controller not initialized for ${facing.name}',
      );
      return [];
    }

    // Stabilization pause — allows AF and AE to settle after switch
    await Future.delayed(const Duration(milliseconds: 400));

    // Create local evidence directory
    final dir         = await getApplicationDocumentsDirectory();
    final evidenceDir = Directory(
      '${dir.path}/evidence/photos/$incidentId/${facing.name}',
    );
    if (!await evidenceDir.exists()) {
      await evidenceDir.create(recursive: true);
    }

    final results    = <PhotoResult>[];
    final baseOffset = facing == CameraFacing.back ? 0 : _burstCount;

    for (int i = 0; i < _burstCount; i++) {
      try {
        final xFile     = await controller.takePicture();
        final timestamp = DateTime.now().millisecondsSinceEpoch;

        // Unique filename — prevents Storage overwrite of earlier frames
        final fileName = '${facing.name}_${timestamp}_$i.jpg';
        final destPath = '${evidenceDir.path}/$fileName';

        final saved    = await File(xFile.path).copy(destPath);
        final fileSize = await saved.length();

        debugPrint(
          '[PhotoEvidence] Frame $i ${facing.name.toUpperCase()}: '
              '${fileSize ~/ 1024}KB',
        );

        final photo = PhotoResult(
          localPath:     saved.path,
          facing:        facing,
          capturedAt:    DateTime.now(),
          fileSizeBytes: fileSize,
          gpsCoords:     gpsCoords,
          uploaded:      false,
          burstIndex:    baseOffset + i,
        );

        results.add(photo);

        // Upload synchronously during burst so URL is available immediately
        // This blocks next shot by ~1-2s but guarantees URLs are populated
        // before orchestrator reads them for Firestore
        await _uploadAndSaveMetadata(
          file:       saved,
          uid:        uid,
          incidentId: incidentId,
          folderName: folderName,
          photo:      photo,
        );

        if (i < _burstCount - 1) {
          await Future.delayed(
            const Duration(milliseconds: _burstIntervalMs),
          );
        }
      } catch (e) {
        debugPrint(
          '[PhotoEvidence] Frame $i failed (${facing.name}): $e',
        );
      }
    }

    return results;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UPLOAD AND FIRESTORE SYNC
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _uploadAndSaveMetadata({
    required File        file,
    required String      uid,
    required String      incidentId,
    required String      folderName,
    required PhotoResult photo,
  }) async {
    try {
      _setStatus(PhotoEvidenceStatus.uploading);

      // Use EvidenceStoragePaths for consistent path building
      final fileName = '${photo.facing.name}_${photo.burstIndex}_'
          '${photo.capturedAt.millisecondsSinceEpoch}.jpg';
      final storagePath = EvidenceStoragePaths.photo(uid, folderName, fileName);

      final ref = _storage.ref().child(storagePath);

      final metadata = SettableMetadata(
        contentType:    'image/jpeg',
        customMetadata: {
          'uid':          uid,
          'incidentId':   incidentId,
          'facing':       photo.facing.name,
          'capturedAt':   photo.capturedAt.toIso8601String(),
          'gpsCoords':    photo.gpsCoords ?? '',
          'burstIndex':   '${photo.burstIndex}',
          'evidenceType': 'photo',
        },
      );

      await ref.putFile(file, metadata);
      final url = await ref.getDownloadURL();

      // Update result object — orchestrator reads this URL
      photo.storageUrl = url;
      photo.uploaded   = true;

      // Write to BOTH field names (set+merge — no crash on fresh doc)
      // PDF reads photoBurstUrls, incident screen reads photoUrls
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('incidents')
          .doc(incidentId)
          .set({
        EvidenceFields.photoUrls:      FieldValue.arrayUnion([url]),
        EvidenceFields.photoBurstUrls: FieldValue.arrayUnion([url]),
      }, SetOptions(merge: true));

      // Sub-collection evidence record for vault screen
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('incidents')
          .doc(incidentId)
          .collection('evidence')
          .doc('photo_${photo.facing.name}_${photo.burstIndex}')
          .set({
        ...photo.toMap(),
        'storageUrl': url,
        'uploaded':   true,
        'createdAt':  FieldValue.serverTimestamp(),
      });

      debugPrint(
        '[PhotoEvidence] Uploaded: '
            '${photo.facing.name} #${photo.burstIndex} → $url',
      );
    } catch (e) {
      debugPrint(
        '[PhotoEvidence] Upload failed for '
            '${photo.facing.name} #${photo.burstIndex}: $e',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════════════════

  Future<String?> _getGps() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy:  LocationAccuracy.high,
          timeLimit: Duration(seconds: 3),
        ),
      );
      return '${pos.latitude},${pos.longitude}';
    } catch (_) {
      return null;
    }
  }

  void reset() {
    _photos.clear();
    statusNotifier.value        = PhotoEvidenceStatus.idle;
    capturedCountNotifier.value = 0;
  }

  void _setStatus(PhotoEvidenceStatus s) => statusNotifier.value = s;
}