// lib/core/services/voice_sos_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// INDUSTRIAL VOICE SOS SERVICE — v5.0 (2026 SENTINEL EDITION)
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum VoiceSosState { inactive, listening, detected, triggered, cooldown }

class VoiceDetectionEvent {
  final String keyword;
  final double confidence;
  final DateTime detectedAt;
  final String rawTranscript;
  final bool isFuzzyMatch;
  final String language;

  const VoiceDetectionEvent({
    required this.keyword,
    required this.confidence,
    required this.detectedAt,
    required this.rawTranscript,
    this.isFuzzyMatch = false,
    this.language = 'en',
  });
}

class _KeywordEntry {
  final String keyword;
  final double baseThreshold;
  final String language;
  const _KeywordEntry(this.keyword, this.baseThreshold, this.language);
}

class VoiceSosService extends ChangeNotifier {
  VoiceSosService._();
  static final VoiceSosService instance = VoiceSosService._();

  static const _method = MethodChannel('com.safeher/voice_sos');
  static const _events = EventChannel('com.safeher/voice_sos_events');

  static const _kEnabled     = 'voice_sos_enabled';
  static const _kSensitivity = 'voice_sos_sensitivity';
  static const int _cooldownSec  = 30;

  final _firestore = FirebaseFirestore.instance;
  final _auth      = FirebaseAuth.instance;

  VoiceSosState _state         = VoiceSosState.inactive;
  bool _isEnabled              = false;
  bool _isInitialized          = false;
  bool _isDisposed             = false;

  double _sensitivity          = 0.6;
  VoiceDetectionEvent? _lastEvent;

  StreamSubscription? _eventSub;
  Timer? _cooldownTimer;

  void Function(String keyword)? onSosTriggered;
  void Function(VoiceDetectionEvent event)? onKeywordDetected;

  VoiceSosState get state => _state;
  bool get isEnabled      => _isEnabled;
  VoiceDetectionEvent? get lastEvent => _lastEvent;
  double get sensitivity  => _sensitivity;

  static const List<_KeywordEntry> _keywordDb = [
    _KeywordEntry('help', 0.55, 'en'),
    _KeywordEntry('emergency', 0.60, 'en'),
    _KeywordEntry('danger', 0.60, 'en'),
    _KeywordEntry('stop it', 0.60, 'en'),
    _KeywordEntry('bachao', 0.50, 'hi'),
    _KeywordEntry('chhodo', 0.55, 'hi'),
    _KeywordEntry('madad karo', 0.55, 'hi'),
    _KeywordEntry('help cheyyi', 0.55, 'te'),
    _KeywordEntry('vaddu', 0.50, 'te'),
    _KeywordEntry('utavi', 0.55, 'ta'),
  ];

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    _isDisposed = false;

    try {
      final prefs  = await SharedPreferences.getInstance();
      _isEnabled   = prefs.getBool(_kEnabled) ?? false;
      _sensitivity = prefs.getDouble(_kSensitivity) ?? 0.6;

      _eventSub = _events.receiveBroadcastStream().listen(
        _onNativeEvent,
        onError: (e) => debugPrint('⚠️ [VOICE SOS] Stream Error: $e'),
      );

      _isInitialized = true;
      debugPrint('🛡️ [VOICE SOS] Acoustic Sentinel Online and Ready');

      if (_isEnabled) await start();
      return true;
    } catch (e) {
      debugPrint('❌ [VOICE SOS] Init Failure: $e');
      return false;
    }
  }

  Future<void> start() async {
    if (!_isInitialized) await initialize();
    if (!_isEnabled || _isDisposed) return;
    if (_state == VoiceSosState.listening || _state == VoiceSosState.detected) return;

    try {
      await _method.invokeMethod('startListening', {
        'sensitivity': _effectiveThreshold(),
        'keywords': _keywordDb.map((k) => k.keyword).toList(),
      });
      _safeSetState(VoiceSosState.listening);
      debugPrint('🎙️ [VOICE SOS] Native Microphone Engaged');
    } catch (e) {
      debugPrint('⚠️ [VOICE SOS] Start Error: $e');
    }
  }

  Future<void> stop() async {
    _cooldownTimer?.cancel();
    try {
      if (!_isDisposed) await _method.invokeMethod('stopListening');
    } catch (_) {}
    _safeSetState(VoiceSosState.inactive);
    debugPrint('🛑 [VOICE SOS] Native Microphone Disengaged');
  }

  double _effectiveThreshold() {
    final hour = DateTime.now().hour;
    final isNight = hour >= 21 || hour < 6;
    return isNight ? (_sensitivity - 0.1).clamp(0.3, 0.9) : _sensitivity;
  }

  void _onNativeEvent(dynamic event) {
    if (event is! Map || _isDisposed || !_isEnabled) return;
    final type = event['type'] as String?;

    switch (type) {
      case 'keyword_detected':
        final kw = event['keyword'] as String? ?? '';
        final entry = _keywordDb.firstWhere(
                (e) => e.keyword == kw,
            orElse: () => const _KeywordEntry('unknown', 0.6, 'en')
        );

        _processDetection(
          keyword: kw,
          confidence: (event['confidence'] as num?)?.toDouble() ?? 0.7,
          transcript: event['transcript'] as String? ?? '',
          language: entry.language,
          isFuzzy: false,
        );
        break;
      case 'status':
        final status = event['status'] as String?;
        if (status == 'stopped' && _isEnabled && _state == VoiceSosState.listening) {
          debugPrint('⚠️ [VOICE SOS] Native stream dropped unexpectedly.');
        }
        break;
    }
  }

  void _processDetection({
    required String keyword,
    required double confidence,
    required String transcript,
    required String language,
    required bool isFuzzy,
  }) {
    if (_state != VoiceSosState.listening || _isDisposed) return;

    final threshold = _effectiveThreshold();
    if (confidence < threshold) return;

    // 🚨 CRITICAL HARDWARE MUTEX
    _method.invokeMethod('stopListening').catchError((_) {});

    _lastEvent = VoiceDetectionEvent(
      keyword: keyword,
      confidence: confidence,
      detectedAt: DateTime.now(),
      rawTranscript: transcript,
      isFuzzyMatch: isFuzzy,
      language: language,
    );

    debugPrint('🚨 [VOICE SOS] Acoustic Trigger: "$keyword" (Conf: ${confidence.toStringAsFixed(2)})');

    _logToFirestore(_lastEvent!);
    if (!_isDisposed) onKeywordDetected?.call(_lastEvent!);

    // ✅ FIXED: Instantly command the Provider to start the UI Countdown!
    _safeSetState(VoiceSosState.detected);
    _fireSos();
  }

  void cancelDetection() {
    if (_isEnabled && !_isDisposed) {
      start();
    } else {
      _safeSetState(VoiceSosState.inactive);
    }
  }

  void _fireSos() {
    if (_isDisposed) return;
    _safeSetState(VoiceSosState.triggered);
    onSosTriggered?.call(_lastEvent?.keyword ?? 'voice_panic');
    _startCooldown();
  }

  void _startCooldown() {
    _safeSetState(VoiceSosState.cooldown);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(const Duration(seconds: _cooldownSec), () {
      if (_isDisposed) return;
      if (_isEnabled) {
        start();
      } else {
        _safeSetState(VoiceSosState.inactive);
      }
    });
  }

  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, enabled);

    if (enabled) {
      await start();
    } else {
      await stop();
    }
    if (!_isDisposed) notifyListeners();
  }

  Future<void> setSensitivity(double value) async {
    _sensitivity = value.clamp(0.3, 0.95);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kSensitivity, _sensitivity);

    if (_isEnabled && _state == VoiceSosState.listening && !_isDisposed) {
      await stop();
      await start();
    }
    if (!_isDisposed) notifyListeners();
  }

  Future<void> _logToFirestore(VoiceDetectionEvent event) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore.collection('users').doc(uid).collection('voice_logs').add({
        'keyword': event.keyword,
        'confidence': event.confidence,
        'transcript': event.rawTranscript,
        'isFuzzy': event.isFuzzyMatch,
        'language': event.language,
        'detectedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {}
  }

  void _safeSetState(VoiceSosState s) {
    if (_isDisposed) return;
    _state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _eventSub?.cancel();
    _cooldownTimer?.cancel();
    stop();
    super.dispose();
  }
}