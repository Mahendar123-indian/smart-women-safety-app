// lib/features/sos/providers/sos_provider.dart
// ─────────────────────────────────────────────────────────────────────────────
// SAFEHER — SOS PROVIDER v8.0
// ─────────────────────────────────────────────────────────────────────────────
// ✅ All SosService methods wired correctly
// ✅ Camera controllers passed through to SosService
// ✅ EvidenceOrchestrator notifiers bound for UI progress
// ✅ countdown timer with configurable total (3/5/10s)
// ✅ dangerScore relay to ShakeSosService
// ✅ shakeEnabled / alarmEnabled toggles persisted
// ✅ setContactProvider() for contact-aware dispatch
// ✅ activeBundle from EvidenceOrchestrator.bundleNotifier
// ✅ evidenceTimeline from EvidenceOrchestrator.timelineNotifier
// ✅ audioRecording / photoCapturing / videoRecording states
// ✅ incidents list from SosService.incidentsNotifier
// ✅ activeDurationStr — human-readable elapsed time since SOS triggered
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/audio_evidence_service.dart';
import '../../../core/services/evidence/evidence_models.dart';
import '../../../core/services/evidence/evidence_orchestrator.dart';
import '../../../core/services/photo_evidence_service.dart';
import '../../../core/services/shake_sos_service.dart';
import '../../../core/services/video_evidence_service.dart';
import '../../../features/contacts/providers/contact_provider.dart';
import '../services/sos_service.dart';

class SosProvider extends ChangeNotifier {
  // ── Services ──────────────────────────────────────────────────────────────
  final SosService _sos = SosService.instance;

  // ── Contact provider (set from HomeScreen after init) ─────────────────────
  ContactProvider? _contactProvider;

  // ── Countdown state ───────────────────────────────────────────────────────
  Timer? _countdownTimer;
  int    _countdown      = 5;
  int    _countdownTotal = 5;
  bool   _isCountingDown = false;

  // ── Active duration tracking ───────────────────────────────────────────────
  // Ticks every second while SOS is active to drive activeDurationStr
  Timer?    _durationTimer;
  DateTime? _sosStartTime;
  int       _elapsedSeconds = 0;

  // ── Settings ──────────────────────────────────────────────────────────────
  bool   _shakeEnabled = true;
  bool   _alarmEnabled = true;
  double _dangerScore  = 0.0;

  // ── Evidence state from Orchestrator notifiers ────────────────────────────
  EvidenceBundle? _activeBundle;
  List<String>    _evidenceTimeline = [];

  // ── Sub-service state for UI chips ────────────────────────────────────────
  bool _audioRecording = false;
  bool _photoCapturing = false;
  bool _videoRecording = false;

  // ── Subscriptions ─────────────────────────────────────────────────────────
  List<VoidCallback> _listeners = [];

  // ═══════════════════════════════════════════════════════════════════════════
  // GETTERS
  // ═══════════════════════════════════════════════════════════════════════════

  SosStatus      get status         => _sos.status;
  SosEvent?      get activeEvent    => _sos.activeEvent;
  bool           get isSosActive    => _sos.isSosActive;
  bool           get isCountingDown => _isCountingDown;
  int            get countdown      => _countdown;
  int            get countdownTotal => _countdownTotal;
  bool           get shakeEnabled   => _shakeEnabled;
  bool           get alarmEnabled   => _alarmEnabled;
  double         get dangerScore    => _dangerScore;
  List<SosEvent> get incidents      => _sos.incidents;

  EvidenceBundle? get activeBundle     => _activeBundle;
  List<String>    get evidenceTimeline => _evidenceTimeline;

  bool get audioRecording => _audioRecording;
  bool get photoCapturing => _photoCapturing;
  bool get videoRecording => _videoRecording;

  /// Human-readable elapsed time since SOS was triggered.
  /// Format: "0:05", "1:23", "12:34"
  /// Returns "0:00" when no SOS is active.
  String get activeDurationStr {
    if (!_sos.isSosActive || _elapsedSeconds <= 0) return '0:00';
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> init() async {
    _sos.init();
    await _loadSettings();
    _bindServiceNotifiers();
  }

  void setContactProvider(ContactProvider cp) {
    _contactProvider = cp;
  }

  void _bindServiceNotifiers() {
    // SOS status changes — also drives the duration timer
    void onStatusChange() {
      _handleStatusChange(_sos.status);
      notifyListeners();
    }
    _sos.statusNotifier.addListener(onStatusChange);
    _listeners.add(() => _sos.statusNotifier.removeListener(onStatusChange));

    // Incident list updates
    void onIncidents() => notifyListeners();
    _sos.incidentsNotifier.addListener(onIncidents);
    _listeners.add(() => _sos.incidentsNotifier.removeListener(onIncidents));

    // Evidence bundle from Orchestrator
    void onBundle() {
      _activeBundle = EvidenceOrchestrator.instance.bundleNotifier.value;
      notifyListeners();
    }
    EvidenceOrchestrator.instance.bundleNotifier.addListener(onBundle);
    _listeners.add(
          () => EvidenceOrchestrator.instance.bundleNotifier.removeListener(onBundle),
    );

    // Evidence timeline for SOS screen log
    void onTimeline() {
      _evidenceTimeline = EvidenceOrchestrator.instance.timelineNotifier.value;
      notifyListeners();
    }
    EvidenceOrchestrator.instance.timelineNotifier.addListener(onTimeline);
    _listeners.add(
          () => EvidenceOrchestrator.instance.timelineNotifier.removeListener(onTimeline),
    );

    // Audio recording state
    void onAudio() {
      _audioRecording =
          AudioEvidenceService.instance.statusNotifier.value ==
              AudioEvidenceStatus.recording;
      notifyListeners();
    }
    AudioEvidenceService.instance.statusNotifier.addListener(onAudio);
    _listeners.add(
          () => AudioEvidenceService.instance.statusNotifier.removeListener(onAudio),
    );

    // Photo capturing state
    void onPhoto() {
      _photoCapturing =
          PhotoEvidenceService.instance.statusNotifier.value ==
              PhotoEvidenceStatus.capturing;
      notifyListeners();
    }
    PhotoEvidenceService.instance.statusNotifier.addListener(onPhoto);
    _listeners.add(
          () => PhotoEvidenceService.instance.statusNotifier.removeListener(onPhoto),
    );

    // Video recording state
    void onVideo() {
      _videoRecording =
          VideoEvidenceService.instance.statusNotifier.value ==
              VideoEvidenceStatus.recording;
      notifyListeners();
    }
    VideoEvidenceService.instance.statusNotifier.addListener(onVideo);
    _listeners.add(
          () => VideoEvidenceService.instance.statusNotifier.removeListener(onVideo),
    );
  }

  // ─── Duration timer lifecycle ─────────────────────────────────────────────

  /// Starts/stops the 1-second elapsed-time ticker based on SOS status.
  void _handleStatusChange(SosStatus newStatus) {
    if (newStatus == SosStatus.active) {
      _startDurationTimer();
    } else {
      _stopDurationTimer();
    }
  }

  void _startDurationTimer() {
    _stopDurationTimer(); // guard against double-start
    _sosStartTime    = DateTime.now();
    _elapsedSeconds  = 0;
    _durationTimer   = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_sosStartTime != null) {
        _elapsedSeconds =
            DateTime.now().difference(_sosStartTime!).inSeconds;
        notifyListeners();
      }
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer  = null;
    _sosStartTime   = null;
    _elapsedSeconds = 0;
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _shakeEnabled   = prefs.getBool('sos_shake_enabled')    ?? true;
    _alarmEnabled   = prefs.getBool('sos_alarm_enabled')    ?? true;
    _countdownTotal = prefs.getInt('sos_countdown_seconds') ?? 5;
    _countdown      = _countdownTotal;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SOS TRIGGERS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> triggerManualSOS({
    CameraController? backCamera,
    CameraController? frontCamera,
  }) async {
    _cancelCountdown();
    try {
      await _sos.triggerSOS(
        isSilent:    false,
        triggerType: 'manual',
        backCamera:  backCamera,
        frontCamera: frontCamera,
      );
    } catch (e) {
      debugPrint('[SosProvider] Manual SOS error: $e');
    }
    notifyListeners();
  }

  Future<void> triggerSilentSOS({
    CameraController? backCamera,
    CameraController? frontCamera,
    String            triggerType = 'silent',
  }) async {
    _cancelCountdown();
    try {
      await _sos.triggerSilentSOS(
        backCamera:  backCamera,
        frontCamera: frontCamera,
        triggerType: triggerType,
      );
    } catch (e) {
      debugPrint('[SosProvider] Silent SOS error: $e');
    }
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COUNTDOWN
  // ═══════════════════════════════════════════════════════════════════════════

  void startCountdown({
    CameraController? backCamera,
    CameraController? frontCamera,
  }) {
    if (_isCountingDown || _sos.isSosActive) return;

    _isCountingDown = true;
    _countdown      = _countdownTotal;
    notifyListeners();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      _countdown--;
      notifyListeners();

      if (_countdown <= 0) {
        t.cancel();
        _isCountingDown = false;
        await triggerManualSOS(
          backCamera:  backCamera,
          frontCamera: frontCamera,
        );
      }
    });
  }

  void cancelCountdown() {
    _cancelCountdown();
    notifyListeners();
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _isCountingDown = false;
    _countdown      = _countdownTotal;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RESOLVE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> resolveSosWithPin({
    required String pin,
    bool            isFalseAlarm = false,
  }) async {
    final ok = await _sos.resolveSosWithPin(pin, isFalseAlarm: isFalseAlarm);
    notifyListeners();
    return ok;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DANGER SCORE RELAY
  // ═══════════════════════════════════════════════════════════════════════════

  void updateDangerScore(double score) {
    _dangerScore = score.clamp(0.0, 1.0);
    _sos.updateDangerScore(_dangerScore);
    ShakeSosService.instance.updateMlDangerScore(_dangerScore);
    // Don't notify — called every 3s from ML stream, would cause rebuild spam
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SETTINGS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> toggleShake(bool value) async {
    _shakeEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sos_shake_enabled', value);
    await ShakeSosService.instance.setEnabled(value);
    notifyListeners();
  }

  Future<void> toggleAlarm(bool value) async {
    _alarmEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sos_alarm_enabled', value);
    notifyListeners();
  }

  Future<void> setCountdownSeconds(int seconds) async {
    _countdownTotal = seconds;
    _countdown      = seconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sos_countdown_seconds', seconds);
    notifyListeners();
  }

  Future<bool> changePin(String oldPin, String newPin) async {
    return _sos.changePin(oldPin, newPin);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DISPOSAL
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void dispose() {
    _cancelCountdown();
    _stopDurationTimer();
    for (final remove in _listeners) {
      remove();
    }
    _listeners.clear();
    super.dispose();
  }
}