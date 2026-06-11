// lib/core/services/evidence/evidence_repository.dart
// ─────────────────────────────────────────────────────────────────────────────
// SAFEHER — EVIDENCE REPOSITORY v8.0
// ─────────────────────────────────────────────────────────────────────────────
// ✅ _resolveFolder() reads evidenceFolderName (now written by orchestrator)
// ✅ getBundleForIncident() uses EvidenceBundle.fromFirestoreMap()
// ✅ Reads both photoBurstUrls + photoUrls — whichever has data
// ✅ Reads both audioEvidenceUrl + audioUrl
// ✅ streamGpsBreadcrumbs() for real-time contact map
// ✅ getEvidenceSummary() concurrent metadata fetch
// ✅ deleteEvidenceForIncident() GDPR wipe — storage + Firestore
// ✅ listIncidentsWithEvidence() paginated with startAfter
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'evidence_models.dart';

class EvidenceRepository {
  EvidenceRepository._();
  static final EvidenceRepository instance = EvidenceRepository._();

  final _firestore = FirebaseFirestore.instance;
  final _storage   = FirebaseStorage.instance;
  final _auth      = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  // ═══════════════════════════════════════════════════════════════════════════
  // FETCH BUNDLE FOR INCIDENT
  // ═══════════════════════════════════════════════════════════════════════════

  Future<EvidenceBundle?> getBundleForIncident(String incidentId) async {
    if (_uid.isEmpty) return null;
    try {
      final doc = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('incidents')
          .doc(incidentId)
          .get();

      if (!doc.exists) return null;
      final data = doc.data()!;

      // Pull extra URLs from evidence sub-collection
      final evidenceSnap = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('incidents')
          .doc(incidentId)
          .collection('evidence')
          .get();

      final extraPhotoUrls = <String>[];
      final extraVideoUrls = <String>[];
      final extraAudioUrls = <String>[];

      for (final d in evidenceSnap.docs) {
        final ev   = d.data();
        final type = ev['type'] as String? ?? '';
        final url  = ev['storageUrl'] as String? ?? '';
        if (url.isEmpty) continue;
        if (type == 'photo_evidence') extraPhotoUrls.add(url);
        if (type == 'video_evidence') extraVideoUrls.add(url);
        if (type == 'audio_evidence') extraAudioUrls.add(url);
      }

      // Merge sub-collection URLs into main data for fromFirestoreMap
      final photoUrls = <String>{
        ...List<String>.from(data[EvidenceFields.photoBurstUrls] as List? ?? []),
        ...List<String>.from(data[EvidenceFields.photoUrls]      as List? ?? []),
        ...extraPhotoUrls,
      }.toList();

      final videoUrls = <String>{
        ...List<String>.from(data[EvidenceFields.videoUrls] as List? ?? []),
        ...extraVideoUrls,
      }.toList();

      final audioUrl = data[EvidenceFields.audioEvidenceUrl] as String?
          ?? data[EvidenceFields.audioUrl] as String?
          ?? (extraAudioUrls.isNotEmpty ? extraAudioUrls.first : null);

      // Inject merged URLs back into data map for clean fromFirestoreMap
      final mergedData = Map<String, dynamic>.from(data);
      mergedData[EvidenceFields.photoUrls]      = photoUrls;
      mergedData[EvidenceFields.photoBurstUrls] = photoUrls;
      mergedData[EvidenceFields.videoUrls]      = videoUrls;
      mergedData[EvidenceFields.audioEvidenceUrl] = audioUrl;
      mergedData[EvidenceFields.audioUrl]         = audioUrl;

      return EvidenceBundle.fromFirestoreMap(incidentId, _uid, mergedData);
    } catch (e) {
      debugPrint('[EvidenceRepository] getBundleForIncident error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LIST INCIDENTS WITH EVIDENCE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> listIncidentsWithEvidence({
    int               limit      = 20,
    DocumentSnapshot? startAfter,
  }) async {
    if (_uid.isEmpty) return [];
    try {
      Query query = _firestore
          .collection('users')
          .doc(_uid)
          .collection('incidents')
          .where(
        EvidenceFields.evidenceStatus,
        whereIn: [
          EvidenceStatus.securing,
          EvidenceStatus.collected,
          EvidenceStatus.sealed,
        ],
      )
          .orderBy('triggeredAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snap = await query.get();
      return snap.docs
          .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      debugPrint('[EvidenceRepository] listIncidentsWithEvidence error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REAL-TIME GPS BREADCRUMB STREAM
  // ═══════════════════════════════════════════════════════════════════════════

  Stream<List<GpsPoint>> streamGpsBreadcrumbs(String incidentId) {
    return _firestore
        .collection('users')
        .doc(_uid)
        .collection('incidents')
        .doc(incidentId)
        .collection('breadcrumbs')
        .orderBy('timestamp')
        .snapshots()
        .map((snap) => snap.docs.map((d) {
      final data = d.data();
      return GpsPoint(
        lat:         (data['lat']      as num).toDouble(),
        lng:         (data['lng']      as num).toDouble(),
        accuracy:    (data['accuracy'] as num?)?.toDouble() ?? 0,
        speed:       (data['speed']    as num?)?.toDouble() ?? 0,
        heading:     (data['heading']  as num?)?.toDouble() ?? 0,
        altitude:    (data['altitude'] as num?)?.toDouble() ?? 0,
        timestamp:   _parseTs(data['timestamp']),
        dangerScore: (data['dangerScore'] as num?)?.toDouble(),
      );
    }).toList());
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STORAGE FOLDER RESOLUTION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Resolves the storage folder name from Firestore.
  /// Now that orchestrator writes evidenceFolderName immediately,
  /// this will always return the correct date-based folder.
  Future<String> _resolveFolder(String incidentId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('incidents')
          .doc(incidentId)
          .get();

      final folder =
      doc.data()?[EvidenceFields.evidenceFolderName] as String?;
      if (folder != null && folder.isNotEmpty) return folder;
    } catch (_) {}

    // Fallback for legacy incidents without evidenceFolderName
    return incidentId;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STORAGE ITEM LISTS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<Reference>> listPhotos(String incidentId) =>
      _listStorageItems(incidentId, 'photos');

  Future<List<Reference>> listAudioChunks(String incidentId) =>
      _listStorageItems(incidentId, 'audio');

  Future<List<Reference>> listVideos(String incidentId) =>
      _listStorageItems(incidentId, 'video');

  Future<List<Reference>> listLogs(String incidentId) =>
      _listStorageItems(incidentId, 'logs');

  Future<List<Reference>> _listStorageItems(
      String incidentId,
      String type,
      ) async {
    try {
      final folder = await _resolveFolder(incidentId);
      final ref    = _storage.ref('evidence/$_uid/$folder/$type');
      final result = await ref.listAll();
      result.items.sort((a, b) => a.name.compareTo(b.name));
      return result.items;
    } catch (e) {
      debugPrint('[EvidenceRepository] listStorageItems ($type) error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EVIDENCE SUMMARY
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getEvidenceSummary(String incidentId) async {
    try {
      final photos = await listPhotos(incidentId);
      final audio  = await listAudioChunks(incidentId);
      final videos = await listVideos(incidentId);
      final logs   = await listLogs(incidentId);

      int totalBytes = 0;
      final allRefs  = [...photos, ...audio, ...videos, ...logs];

      // Concurrent metadata fetch for speed
      await Future.wait(
        allRefs.map((ref) async {
          try {
            final meta = await ref.getMetadata();
            totalBytes += meta.size ?? 0;
          } catch (_) {}
        }),
      );

      return {
        'photoCount':  photos.length,
        'audioCount':  audio.length,
        'videoCount':  videos.length,
        'logCount':    logs.length,
        'totalPieces': allRefs.length,
        'totalSizeMB': (totalBytes / (1024 * 1024)).toStringAsFixed(1),
      };
    } catch (e) {
      return {'error': '$e'};
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GDPR / FORENSIC WIPE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> deleteEvidenceForIncident(String incidentId) async {
    if (_uid.isEmpty) return;
    try {
      final folder     = await _resolveFolder(incidentId);
      final storageRef = _storage.ref('evidence/$_uid/$folder');

      // 1. Wipe Storage recursively
      await _deleteStorageFolder(storageRef);

      // 2. Wipe PDF reports
      try {
        await _deleteStorageFolder(
          _storage.ref('reports/$_uid/$incidentId'),
        );
      } catch (_) {}

      // 3. Wipe Firestore breadcrumbs
      await _deleteSubCollection(_firestore
          .collection('users')
          .doc(_uid)
          .collection('incidents')
          .doc(incidentId)
          .collection('breadcrumbs'));

      // 4. Wipe Firestore evidence manifest
      await _deleteSubCollection(_firestore
          .collection('users')
          .doc(_uid)
          .collection('incidents')
          .doc(incidentId)
          .collection('evidence'));

      // 5. Nullify main document evidence references
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('incidents')
          .doc(incidentId)
          .set({
        EvidenceFields.audioEvidenceUrl:  FieldValue.delete(),
        EvidenceFields.audioUrl:          FieldValue.delete(),
        EvidenceFields.photoUrls:         [],
        EvidenceFields.photoBurstUrls:    [],
        EvidenceFields.videoUrls:         [],
        EvidenceFields.sensorLogUrl:      FieldValue.delete(),
        EvidenceFields.evidenceFolderName: FieldValue.delete(),
        EvidenceFields.pdfReportUrl:      FieldValue.delete(),
        'evidenceDeleted':   true,
        'evidenceDeletedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint(
        '[EvidenceRepository] Forensic wipe complete: $incidentId',
      );
    } catch (e) {
      debugPrint('[EvidenceRepository] Deletion error: $e');
    }
  }

  Future<void> _deleteStorageFolder(Reference ref) async {
    try {
      final result = await ref.listAll();
      await Future.wait([
        for (final item in result.items)   item.delete(),
        for (final prefix in result.prefixes) _deleteStorageFolder(prefix),
      ]);
    } catch (_) {}
  }

  Future<void> _deleteSubCollection(CollectionReference ref) async {
    try {
      const batchSize = 400;
      QuerySnapshot snap;
      do {
        snap = await ref.limit(batchSize).get();
        if (snap.docs.isEmpty) break;
        final batch = _firestore.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      } while (snap.docs.length == batchSize);
    } catch (e) {
      debugPrint('[EvidenceRepository] Sub-collection delete error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  DateTime _parseTs(dynamic v) {
    if (v is int) {
      return v > 1000000000000
          ? DateTime.fromMillisecondsSinceEpoch(v)
          : DateTime.fromMillisecondsSinceEpoch(v * 1000);
    }
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }
}