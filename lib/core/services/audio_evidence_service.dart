// lib/core/services/audio_evidence_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// SAFEHER — AUDIO EVIDENCE SERVICE v8.0
// ─────────────────────────────────────────────────────────────────────────────
// ✅ recordEvidenceClip() accepts folderName — uses EvidenceStoragePaths
// ✅ Storage path: evidence/{uid}/{folderName}/audio/audio_{ts}.m4a
// ✅ Writes BOTH audioEvidenceUrl + audioUrl to Firestore (set+merge)
// ✅ Two dedicated recorders — ML loop + forensic never conflict
// ✅ noiseSuppress/echoCancel OFF — preserves screams for court evidence
// ✅ Completer mutex for instant zero-latency stopEarly() cancellation
// ✅ ML loop stop uses timeout — never blocks forensic recording start
// ✅ Amplitude monitor for peak detection (scream probability proxy)
// ✅ Duration heartbeat drives EvidenceProgressWidget elapsed timer
// ✅ Zero-byte file check before upload
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'evidence/evidence_models.dart';
import 'ml_api_service.dart';

// ─── Status ───────────────────────────────────────────────────────────────────

enum AudioEvidenceStatus {
  idle,
  recording,
  processing,
  uploading,
  completed,
  failed,
}

// ─── Result ───────────────────────────────────────────────────────────────────

class AudioClipResult {
  final String   localPath;
  final String?  storageUrl;
  final DateTime startedAt;
  final DateTime endedAt;
  final Duration duration;
  final int      fileSizeBytes;
  final bool     uploaded;
  final double?  peakAmplitude;

  const AudioClipResult({
    required this.localPath,
    this.storageUrl,
    required this.startedAt,
    required this.endedAt,
    required this.duration,
    required this.fileSizeBytes,
    required this.uploaded,
    this.peakAmplitude,
  });

  Map<String, dynamic> toMap() => {
    'localPath':       localPath,
    'storageUrl':      storageUrl,
    'startedAt':       startedAt.toIso8601String(),
    'endedAt':         endedAt.toIso8601String(),
    'durationSeconds': duration.inSeconds,
    'fileSizeBytes':   fileSizeBytes,
    'uploaded':        uploaded,
    'peakAmplitude':   peakAmplitude,
    'type':            'audio_evidence',
  };
}

// ─── Service ──────────────────────────────────────────────────────────────────

class AudioEvidenceService {
  AudioEvidenceService._();
  static final AudioEvidenceService instance = AudioEvidenceService._();

  final _storage   = FirebaseStorage.instance;
  final _firestore = FirebaseFirestore.instance;

  // Two dedicated recorders — separate hardware channels, no conflict
  final _forensicRecorder = AudioRecorder();
  final _mlRecorder       = AudioRecorder();

  // Public notifiers for UI
  final ValueNotifier<AudioEvidenceStatus> statusNotifier =
  ValueNotifier(AudioEvidenceStatus.idle);
  final ValueNotifier<double> amplitudeNotifier      = ValueNotifier(0.0);
  final ValueNotifier<int>    elapsedSecondsNotifier = ValueNotifier(0);

  Timer?    _durationTimer;
  Timer?    _amplitudeTimer;
  DateTime? _startTime;
  double    _peakAmplitude = 0.0;

  // Completer mutex for instant cancellation via stopEarly()
  Completer<void>? _recordCompleter;
  bool _cancelled = false;

  // ML loop state
  bool _isMlLoopRunning = false;

  static const int _recordingDurationSeconds = 60;
  static const int _sampleRate               = 44100;
  static const int _bitRate                  = 128000;

  // ═══════════════════════════════════════════════════════════════════════════
  // BACKGROUND ML ACOUSTIC LOOP
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> startMlAudioLoop() async {
    if (_isMlLoopRunning ||
        statusNotifier.value == AudioEvidenceStatus.recording) {
      return;
    }

    final hasPermission = await _mlRecorder.hasPermission();
    if (!hasPermission) {
      debugPrint('[AudioEvidence] ML loop: mic permission denied');
      return;
    }

    _isMlLoopRunning = true;
    debugPrint('[AudioEvidence] ML acoustic loop started');

    final dir     = await getTemporaryDirectory();
    final mlPath  = '${dir.path}/ml_acoustic_buffer.m4a';
    _runMlCycle(mlPath);
  }

  Future<void> _runMlCycle(String filePath) async {
    if (!_isMlLoopRunning) return;

    try {
      await _mlRecorder.start(
        const RecordConfig(
          encoder:     AudioEncoder.aacLc,
          bitRate:     64000,
          numChannels: 1,
        ),
        path: filePath,
      );

      await Future.delayed(const Duration(seconds: 2));

      if (!_isMlLoopRunning) {
        if (await _mlRecorder.isRecording()) await _mlRecorder.stop();
        return;
      }

      final path = await _mlRecorder.stop();
      if (path != null) {
        await MLApiService.instance.analyzeAudioFile(path);
        try {
          final f = File(path);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }

      if (_isMlLoopRunning) _runMlCycle(filePath);
    } catch (e) {
      debugPrint('[AudioEvidence] ML loop error: $e');
      _isMlLoopRunning = false;
    }
  }

  /// Stop ML loop — uses short timeout so it never blocks forensic recording
  Future<void> stopMlAudioLoop() async {
    _isMlLoopRunning = false;
    try {
      if (await _mlRecorder.isRecording()) {
        await _mlRecorder.stop().timeout(const Duration(seconds: 2));
      }
    } catch (_) {}
    debugPrint('[AudioEvidence] ML loop stopped');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIMARY FORENSIC RECORDING
  // ═══════════════════════════════════════════════════════════════════════════

  Future<AudioClipResult?> recordEvidenceClip({
    required String uid,
    required String incidentId,
    required String folderName, // ✅ NEW: date-based folder from orchestrator
  }) async {
    // Stop ML loop with timeout — never blocks forensic capture
    await stopMlAudioLoop();

    _setStatus(AudioEvidenceStatus.recording);
    _startTime       = DateTime.now();
    _peakAmplitude   = 0.0;
    _cancelled       = false;
    _recordCompleter = Completer<void>();
    elapsedSecondsNotifier.value = 0;

    try {
      final hasPermission = await _forensicRecorder.hasPermission();
      if (!hasPermission) {
        debugPrint('[AudioEvidence] Mic permission denied');
        _setStatus(AudioEvidenceStatus.failed);
        return null;
      }

      // Create evidence directory on device
      final dir         = await getApplicationDocumentsDirectory();
      final evidenceDir = Directory(
        '${dir.path}/evidence/audio/$incidentId',
      );
      if (!await evidenceDir.exists()) {
        await evidenceDir.create(recursive: true);
      }

      final timestamp = _startTime!.millisecondsSinceEpoch;
      final filePath  = '${evidenceDir.path}/audio_$timestamp.m4a';

      // Start forensic recording with RAW config
      // noiseSuppress=false preserves screams and struggle sounds
      await _forensicRecorder.start(
        const RecordConfig(
          encoder:       AudioEncoder.aacLc,
          sampleRate:    _sampleRate,
          bitRate:       _bitRate,
          numChannels:   1,
          noiseSuppress: false, // CRITICAL: preserve forensic audio
          echoCancel:    false, // CRITICAL: preserve ambient sounds
          autoGain:      true,
        ),
        path: filePath,
      );

      debugPrint('[AudioEvidence] Forensic recording started: $filePath');

      // Duration heartbeat for UI progress
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        elapsedSecondsNotifier.value = t.tick;
        if (t.tick >= _recordingDurationSeconds) t.cancel();
      });

      // Amplitude monitor for peak detection
      _amplitudeTimer = Timer.periodic(
        const Duration(milliseconds: 200),
            (_) async {
          try {
            final amp        = await _forensicRecorder.getAmplitude();
            final normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
            amplitudeNotifier.value = normalized;
            if (normalized > _peakAmplitude) _peakAmplitude = normalized;
          } catch (_) {}
        },
      );

      // Wait 60 seconds OR early cancellation via stopEarly()
      try {
        await _recordCompleter!.future
            .timeout(Duration(seconds: _recordingDurationSeconds));
      } on TimeoutException {
        // Natural 60s expiry — proceed to save
      }

      return await _stopAndFinalize(
        uid:        uid,
        incidentId: incidentId,
        folderName: folderName,
        filePath:   filePath,
        timestamp:  timestamp,
      );
    } catch (e, st) {
      _durationTimer?.cancel();
      _amplitudeTimer?.cancel();
      debugPrint('[AudioEvidence] Recording failure: $e\n$st');
      _setStatus(AudioEvidenceStatus.failed);
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FINALIZE, UPLOAD, SYNC
  // ═══════════════════════════════════════════════════════════════════════════

  Future<AudioClipResult?> _stopAndFinalize({
    required String uid,
    required String incidentId,
    required String folderName,
    required String filePath,
    required int    timestamp,
  }) async {
    _durationTimer?.cancel();
    _amplitudeTimer?.cancel();

    // Stop hardware recorder
    try {
      if (await _forensicRecorder.isRecording()) {
        await _forensicRecorder.stop();
      }
    } catch (e) {
      debugPrint('[AudioEvidence] Stop warning: $e');
    }

    final endTime = DateTime.now();
    final file    = File(filePath);

    if (!await file.exists()) {
      debugPrint('[AudioEvidence] File missing after recording: $filePath');
      _setStatus(AudioEvidenceStatus.failed);
      return null;
    }

    final fileSize = await file.length();
    if (fileSize == 0) {
      debugPrint('[AudioEvidence] Zero-byte audio file — recording failed');
      _setStatus(AudioEvidenceStatus.failed);
      return null;
    }

    final duration = endTime.difference(_startTime!);
    debugPrint(
      '[AudioEvidence] Secured: '
          '${fileSize ~/ 1024}KB | ${duration.inSeconds}s | '
          'Peak: ${_peakAmplitude.toStringAsFixed(2)}',
    );

    _setStatus(AudioEvidenceStatus.uploading);

    // Upload using EvidenceStoragePaths for consistent path
    final storagePath = EvidenceStoragePaths.audio(
      uid,
      folderName,
      'audio_$timestamp.m4a',
    );

    final url = await _uploadToStorage(
      file:        file,
      storagePath: storagePath,
      uid:         uid,
      incidentId:  incidentId,
      timestamp:   timestamp,
    );

    final result = AudioClipResult(
      localPath:     filePath,
      storageUrl:    url,
      startedAt:     _startTime!,
      endedAt:       endTime,
      duration:      duration,
      fileSizeBytes: fileSize,
      uploaded:      url != null,
      peakAmplitude: _peakAmplitude,
    );

    await _saveMetadata(uid: uid, incidentId: incidentId, result: result);
    _setStatus(AudioEvidenceStatus.completed);
    return result;
  }

  Future<String?> _uploadToStorage({
    required File   file,
    required String storagePath,
    required String uid,
    required String incidentId,
    required int    timestamp,
  }) async {
    try {
      final ref = _storage.ref().child(storagePath);

      final metadata = SettableMetadata(
        contentType:    'audio/m4a',
        customMetadata: {
          'uid':          uid,
          'incidentId':   incidentId,
          'capturedAt':   DateTime.now().toIso8601String(),
          'evidenceType': 'audio',
          'sampleRate':   '$_sampleRate',
          'bitRate':      '$_bitRate',
        },
      );

      await ref.putFile(file, metadata);
      final url = await ref.getDownloadURL();

      // Write BOTH field names — PDF reads audioEvidenceUrl, legacy reads audioUrl
      // set+merge prevents crash on fresh incident doc
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('incidents')
          .doc(incidentId)
          .set({
        EvidenceFields.audioEvidenceUrl: url,
        EvidenceFields.audioUrl:         url,
      }, SetOptions(merge: true));

      debugPrint('[AudioEvidence] Uploaded: $url');
      return url;
    } catch (e) {
      debugPrint('[AudioEvidence] Upload failed: $e');
      return null;
    }
  }

  Future<void> _saveMetadata({
    required String          uid,
    required String          incidentId,
    required AudioClipResult result,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('incidents')
          .doc(incidentId)
          .collection('evidence')
          .doc('audio_primary')
          .set({
        ...result.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[AudioEvidence] Metadata sync failed: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONTROLS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> stopEarly() async {
    _cancelled = true;
    _durationTimer?.cancel();
    _amplitudeTimer?.cancel();
    if (_recordCompleter != null && !_recordCompleter!.isCompleted) {
      _recordCompleter!.complete();
    }
  }

  void reset() {
    _durationTimer?.cancel();
    _amplitudeTimer?.cancel();
    statusNotifier.value         = AudioEvidenceStatus.idle;
    amplitudeNotifier.value      = 0.0;
    elapsedSecondsNotifier.value = 0;
    _peakAmplitude               = 0.0;
    _cancelled                   = false;
  }

  void _setStatus(AudioEvidenceStatus s) => statusNotifier.value = s;

  void dispose() {
    stopMlAudioLoop();
    _durationTimer?.cancel();
    _amplitudeTimer?.cancel();
    _forensicRecorder.dispose();
    _mlRecorder.dispose();
    statusNotifier.dispose();
    amplitudeNotifier.dispose();
    elapsedSecondsNotifier.dispose();
  }
}