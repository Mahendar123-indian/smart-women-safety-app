// lib/core/services/ml_api_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// INDUSTRIAL SENTINEL — ML API SERVICE v5.1 (2026 PRODUCTION)
// ─────────────────────────────────────────────────────────────────────────────
// ✅ [FIXED] Cold Start Timeout: Increased ping duration to 15s for Cloud Run.
// ✅ [FIXED] Fatal GPS Crash: Added onError traps to Geolocator streams.
// ✅ [FIXED] Hardware Glitches: Sensor streams now gracefully ignore faults.
// ✅ [RESILIENCE] Multi-Node Discovery & Intelligent Fallbacks.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────

enum DangerLevel { safe, low, medium, high, critical }

class MLDangerResult {
  final DangerLevel level;
  final double score;
  final double scoreRaw;
  final double movementProb;
  final double audioProb;
  final double behavioralDeviation;
  final double confidence;
  final bool   sosTriggered;
  final String triggerRecommendation;
  final String dangerLevelString;
  final List<String> insights;
  final Map<String, dynamic> scoreBreakdown;
  final int processingMs;
  final DateTime timestamp;

  const MLDangerResult({
    required this.level,
    required this.score,
    required this.scoreRaw,
    required this.movementProb,
    required this.audioProb,
    required this.behavioralDeviation,
    required this.confidence,
    required this.sosTriggered,
    required this.triggerRecommendation,
    required this.dangerLevelString,
    required this.insights,
    required this.scoreBreakdown,
    required this.processingMs,
    required this.timestamp,
  });

  factory MLDangerResult.fromJson(Map<String, dynamic> json) {
    final double scoreRaw = (json['danger_score'] as num?)?.toDouble() ?? 0.0;
    final String levelStr = json['danger_level'] as String? ?? 'SAFE';

    final breakdown = Map<String, dynamic>.from(json['score_breakdown'] as Map? ?? {});

    return MLDangerResult(
      scoreRaw:              scoreRaw,
      score:                 (scoreRaw / 100.0).clamp(0.0, 1.0),
      level:                 _levelFromString(levelStr),
      dangerLevelString:     levelStr,
      movementProb:          (json['individual_scores']?['movement_probability'] as num?)?.toDouble() ?? 0.0,
      audioProb:             (json['individual_scores']?['audio_probability'] as num?)?.toDouble() ?? 0.0,
      behavioralDeviation:   (json['individual_scores']?['behavioral_deviation'] as num?)?.toDouble() ?? 0.0,
      confidence:            (json['confidence'] as num?)?.toDouble() ?? 0.0,
      sosTriggered:          json['sos_triggered'] as bool? ?? false,
      triggerRecommendation: json['trigger_recommendation'] as String? ?? 'none',
      insights:              List<String>.from(json['insights'] as List? ?? []),
      scoreBreakdown:        breakdown,
      processingMs:          json['processing_ms'] as int? ?? 0,
      timestamp:             DateTime.now(),
    );
  }

  static DangerLevel _levelFromString(String level) {
    switch (level.toUpperCase()) {
      case 'SOS':      return DangerLevel.critical;
      case 'DANGER':   return DangerLevel.high;
      case 'WARNING':  return DangerLevel.medium;
      case 'ALERT':    return DangerLevel.low;
      default:         return DangerLevel.safe;
    }
  }

  factory MLDangerResult.safe() => MLDangerResult(
    level: DangerLevel.safe, score: 0.0, scoreRaw: 0.0, movementProb: 0.0, audioProb: 0.0,
    behavioralDeviation: 0.0, confidence: 1.0, sosTriggered: false, triggerRecommendation: 'none',
    dangerLevelString: 'SAFE', insights: [], scoreBreakdown: {}, processingMs: 0, timestamp: DateTime.now(),
  );
}

class _SensorBuffer {
  static const int windowSize = 50;
  final List<Map<String, double>> _accel = [];
  final List<Map<String, double>> _gyro  = [];

  void addAccel(double x, double y, double z) {
    _accel.add({'x': x, 'y': y, 'z': z});
    if (_accel.length > windowSize) _accel.removeAt(0);
  }

  void addGyro(double x, double y, double z) {
    _gyro.add({'x': x, 'y': y, 'z': z});
    if (_gyro.length > windowSize) _gyro.removeAt(0);
  }

  bool get hasEnoughData => _accel.length >= windowSize && _gyro.length >= windowSize;
  List<Map<String, double>> get accelSamples => List.from(_accel);
  List<Map<String, double>> get gyroSamples  => List.from(_gyro);
}

// ─────────────────────────────────────────────
// ML API SERVICE (SINGLETON)
// ─────────────────────────────────────────────

class MLApiService extends ChangeNotifier {
  MLApiService._();
  static final MLApiService instance = MLApiService._();

  static const List<String> _kMlUrls = [
    'https://safeher-backend-1006130066125.asia-south1.run.app', // 🌟 ALPHA NODE
    'http://10.0.2.2:8001',                                 // Local Android Emulator
    'http://127.0.0.1:8001',                                // Localhost
    'http://192.168.1.100:8001',                            // Local Network IP
  ];
  static const String _prefKey = 'ml_backend_url_v2';

  // ✅ FIXED: Increased timeouts to handle Cloud Run cold starts
  static const Duration _pingTimeout = Duration(seconds: 15);
  static const Duration _requestTimeout = Duration(seconds: 20);
  static const Duration _analyzeInterval = Duration(seconds: 3);

  String? _activeUrl;
  int _consecutiveErrors = 0;
  bool _isDiscovering = false;

  String? get activeUrl => _activeUrl;
  bool get isConnected => _activeUrl != null;

  bool _isMonitoring = false;
  final _sensorBuffer = _SensorBuffer();
  Position? _lastPosition;
  double _latestAudioProb = 0.0;

  final _resultController = StreamController<MLDangerResult>.broadcast();
  final _autoSosController = StreamController<MLDangerResult>.broadcast();

  Stream<MLDangerResult> get resultStream => _resultController.stream;
  Stream<MLDangerResult> get autoSosStream => _autoSosController.stream;

  StreamSubscription? _accelSub;
  StreamSubscription? _gyroSub;
  StreamSubscription? _gpsSub;
  Timer? _analyzeTimer;

  // ═══════════════════════════════════════════════════════════════
  // INITIALIZATION & DISCOVERY
  // ═══════════════════════════════════════════════════════════════

  Future<void> initialize() async {
    debugPrint('🚀 [ML SERVICE] Initializing Industrial Bridge...');
    _startSensors();
    await _discoverBackend();
  }

  Future<void> _discoverBackend() async {
    if (_isDiscovering) return;
    _isDiscovering = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_prefKey);

      if (cached != null && cached.isNotEmpty) {
        if (await _checkHealth(cached)) {
          _activeUrl = cached;
          notifyListeners();
          _isDiscovering = false;
          return;
        }
      }

      for (final url in _kMlUrls) {
        if (await _checkHealth(url)) {
          _activeUrl = url;
          await prefs.setString(_prefKey, url);
          notifyListeners();
          debugPrint('✅ [ML SERVICE] Connected to Backend: $url');
          _isDiscovering = false;
          return;
        }
      }

      _activeUrl = null;
      notifyListeners();
      debugPrint('⚠️ [ML SERVICE] No active backend found.');
    } finally {
      _isDiscovering = false;
    }
  }

  Future<bool> _checkHealth(String url) async {
    try {
      final res = await http.get(Uri.parse('$url/health')).timeout(_pingTimeout);
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // SENSORS & PROBABILITY
  // ═══════════════════════════════════════════════════════════════

  void _startSensors() {
    _accelSub = accelerometerEventStream(samplingPeriod: const Duration(milliseconds: 20))
        .listen(
          (e) => _sensorBuffer.addAccel(e.x, e.y, e.z),
      onError: (e) => debugPrint('⚠️ [ML SERVICE] Accel sensor error: $e'),
    );

    _gyroSub = gyroscopeEventStream(samplingPeriod: const Duration(milliseconds: 20))
        .listen(
          (e) => _sensorBuffer.addGyro(e.x, e.y, e.z),
      onError: (e) => debugPrint('⚠️ [ML SERVICE] Gyro sensor error: $e'),
    );

    _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10)
    ).listen(
          (p) => _lastPosition = p,
      onError: (e) => debugPrint('⚠️ [ML SERVICE] GPS stream error (Permissions denied?): $e'),
    );
  }

  void updateAudioScreamProbability(double prob) => _latestAudioProb = prob;

  // ═══════════════════════════════════════════════════════════════
  // INFERENCE ENGINE
  // ═══════════════════════════════════════════════════════════════

  Future<void> startMonitoring() async {
    if (_isMonitoring) return;
    _isMonitoring = true;
    _analyzeTimer = Timer.periodic(_analyzeInterval, (_) => _runInference());
    debugPrint('✅ [ML SERVICE] Real-time Analysis Started.');
  }

  Future<void> _runInference() async {
    if (_activeUrl == null) {
      await _discoverBackend();
      return;
    }

    if (!_sensorBuffer.hasEnoughData) return;

    try {
      final result = await _sendPayload(_buildPayload());
      _consecutiveErrors = 0;

      _resultController.add(result);
      if (result.sosTriggered) _autoSosController.add(result);

    } catch (e) {
      _consecutiveErrors++;
      debugPrint('⚠️ [ML SERVICE] inference cycle error: $e');

      if (_consecutiveErrors >= 3) {
        debugPrint('🚨 [ML SERVICE] Backend unresponsive. Dropping connection.');
        _activeUrl = null;
        _consecutiveErrors = 0;
        notifyListeners();
      }
    }
  }

  Future<MLDangerResult?> analyzeNow() async {
    if (_activeUrl == null || !_sensorBuffer.hasEnoughData) return null;
    try {
      final result = await _sendPayload(_buildPayload());
      _resultController.add(result);
      return result;
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> _buildPayload() {
    final user = FirebaseAuth.instance.currentUser;

    final cleanAccel = _sensorBuffer.accelSamples.map((e) => {'x': e['x'], 'y': e['y'], 'z': e['z']}).toList();
    final cleanGyro  = _sensorBuffer.gyroSamples.map((e) => {'x': e['x'], 'y': e['y'], 'z': e['z']}).toList();

    return {
      'user_id': user?.uid ?? 'anonymous_sentinel',
      'accel_samples': cleanAccel,
      'gyro_samples':  cleanGyro,
      'audio_scream_probability': _latestAudioProb,
      'gps_lat': _lastPosition?.latitude ?? 0.0,
      'gps_lon': _lastPosition?.longitude ?? 0.0,
      'gps_speed_kmh': (_lastPosition?.speed ?? 0.0) * 3.6,
      'hour_of_day': DateTime.now().hour,
      'is_isolated_area': false,
      'is_known_danger_zone': false,
      'location_risk': 0.0,
      'phone_face_down': false,
      'phone_shake': 0.0,
      'impact_force': 0.0,
      'route_deviation': 0.0,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  Future<MLDangerResult> _sendPayload(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('$_activeUrl/analyze_danger'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(_requestTimeout);

    if (response.statusCode == 200) {
      return MLDangerResult.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Backend Error: ${response.statusCode}');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════

  Future<double?> analyzeAudioFile(String filePath) async {
    if (_activeUrl == null) return null;
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$_activeUrl/predict/audio_file'));
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      final streamedRes = await request.send().timeout(_requestTimeout);
      final res = await http.Response.fromStream(streamedRes);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final prob = (data['danger_probability'] as num?)?.toDouble() ?? 0.0;
        updateAudioScreamProbability(prob);
        return prob;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getBackendHealth() async {
    if (_activeUrl == null) return null;
    try {
      final res = await http.get(Uri.parse('$_activeUrl/health')).timeout(_pingTimeout);
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  void stopMonitoring() {
    _isMonitoring = false;
    _analyzeTimer?.cancel();
  }

  @override
  void dispose() {
    stopMonitoring();
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _gpsSub?.cancel();
    _resultController.close();
    _autoSosController.close();
    super.dispose();
  }
}