// lib/core/services/evidence_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// SAFEHER — CENTRAL EVIDENCE SERVICE v8.0
// ─────────────────────────────────────────────────────────────────────────────
// ✅ Thin coordinator — delegates everything to EvidenceOrchestrator
// ✅ attachCamera() / detachCamera() with correct plural clearInjectedControllers()
// ✅ isCollectingNotifier for SosProvider UI binding
// ✅ collectAll() returns EvidenceSessionResult with final bundle
// ✅ stopAll() gracefully stops audio + video + orchestrator
// ✅ camera attachment uses injectBothControllers() when both available
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import 'audio_evidence_service.dart';
import 'photo_evidence_service.dart';
import 'video_evidence_service.dart';
import 'camera_manager.dart';
import 'evidence/evidence_models.dart';
import 'evidence/evidence_orchestrator.dart';

class EvidenceService {
  EvidenceService._();
  static final EvidenceService instance = EvidenceService._();

  // ── Notifiers consumed by SosProvider ────────────────────────────────────
  final ValueNotifier<bool> isCollectingNotifier = ValueNotifier(false);

  EvidenceSessionResult? lastSession;

  // ── Injected camera state ─────────────────────────────────────────────────
  CameraController? _injectedBackCtrl;
  CameraController? _injectedFrontCtrl;

  // ─── Called by SOS screen after both cameras are initialized ──────────────
  void attachCamera({
    required CameraController back,
    CameraController?         front,
  }) {
    _injectedBackCtrl  = back;
    _injectedFrontCtrl = front;

    if (front != null) {
      CameraManager.instance.injectBothControllers(
        back:  back,
        front: front,
      );
    } else {
      CameraManager.instance.injectBackController(back);
    }
    debugPrint('[EvidenceService] Cameras attached');
  }

  void detachCamera() {
    _injectedBackCtrl  = null;
    _injectedFrontCtrl = null;
    // ✅ FIX: Use plural clearInjectedControllers() — was clearInjectedController()
    CameraManager.instance.clearInjectedControllers();
    debugPrint('[EvidenceService] Cameras detached');
  }

  // ─── Main entry — called by SOS service ───────────────────────────────────
  Future<EvidenceSessionResult> collectAll({
    required String incidentId,
    required String uid,
    required double lat,
    required double lng,
    required double dangerScore,
    required String triggerType,
    required bool   isSilent,
    String?         victimName,
    CameraController? backCamera,
    CameraController? frontCamera,
  }) async {
    isCollectingNotifier.value = true;

    // Reset all sub-services for a fresh session
    AudioEvidenceService.instance.reset();
    PhotoEvidenceService.instance.reset();
    VideoEvidenceService.instance.reset();

    try {
      final bundle = await EvidenceOrchestrator.instance.startCollection(
        incidentId:  incidentId,
        lat:         lat,
        lng:         lng,
        dangerScore: dangerScore,
        victimName:  victimName ?? 'SafeHer User',
        isSilent:    isSilent,
        triggerType: triggerType,
        backCamera:  backCamera ?? _injectedBackCtrl,
        frontCamera: frontCamera ?? _injectedFrontCtrl,
      );

      final session = EvidenceSessionResult(
        incidentId:  incidentId,
        collectedAt: DateTime.now(),
        bundle:      bundle,
        success:     true,
      );

      lastSession = session;
      debugPrint(
        '[EvidenceService] Session complete — '
            '${bundle.totalPieces} items',
      );
      return session;
    } catch (e) {
      debugPrint('[EvidenceService] collectAll error: $e');
      return EvidenceSessionResult.failure(
        incidentId: incidentId,
        error:      e.toString(),
      );
    } finally {
      isCollectingNotifier.value = false;
    }
  }

  // ─── Stop all evidence (called on SOS resolve) ────────────────────────────
  Future<EvidenceBundle?> stopAll() async {
    isCollectingNotifier.value = false;
    await AudioEvidenceService.instance.stopEarly();
    await VideoEvidenceService.instance.stopRecording();
    final bundle = await EvidenceOrchestrator.instance.stopCollection();
    debugPrint('[EvidenceService] All pipelines stopped');
    return bundle;
  }

  void dispose() {
    isCollectingNotifier.dispose();
  }
}