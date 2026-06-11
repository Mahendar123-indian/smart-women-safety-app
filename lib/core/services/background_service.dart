// lib/core/services/background_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// INDUSTRIAL SENTINEL — BACKGROUND MONITORING SERVICE v6.0 (2026 PRODUCTION)
// ─────────────────────────────────────────────────────────────────────────────
// ✅ [ADVANCED] Autonomous Trigger Matrix: Evaluates sustained threats and
//    fires Auto-SOS to the main UI isolate without user interaction.
// ✅ [FIXED] Kinetic Spike Detection: Shake sensor immediately triggers SOS.
// ✅ [FIXED] Isolate Communication: Sends GPS, Score, and Reason to Main thread.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

// ─── ML Backend Configuration ────────────────────────────────────────────────
const List<String> _kMlUrls = [
  'https://safeher-backend-1006130066125.asia-south1.run.app', // 🌟 ALPHA NODE
  'http://10.0.2.2:8001',
  'http://127.0.0.1:8001',
  'http://192.168.1.100:8001',
];
const String _kPrefMlUrl = 'ml_backend_url_v2';
const int _kMlTimeoutMs = 10000; // Increased timeout for background ML pings

double _mag(double x, double y, double z) => math.sqrt(x * x + y * y + z * z);

class BackgroundSafetyService {
  BackgroundSafetyService._();
  static final BackgroundSafetyService instance = BackgroundSafetyService._();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    final service = FlutterBackgroundService();
    final alreadyRunning = await service.isRunning();
    if (alreadyRunning) {
      debugPrint('✅ [BG SERVICE] Vanguard Service already alive.');
      _initialized = true;
      return;
    }

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onServiceStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: AppConstants.sosChannelId,
        initialNotificationTitle: 'SafeHer Sentinel',
        initialNotificationContent: 'AI Protection Active',
        foregroundServiceNotificationId: 1001,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: _onServiceStart,
        onBackground: _onIosBackground,
      ),
    );

    await service.startService();
    _initialized = true;
    debugPrint('🚀 [BG SERVICE] Vanguard Autonomous Isolate Spawned.');
  }

  Future<void> stop() async {
    _initialized = false;
    FlutterBackgroundService().invoke('stop');
  }

  Future<bool> isRunning() async => FlutterBackgroundService().isRunning();

  Stream<Map<String, dynamic>?> on(String event) =>
      FlutterBackgroundService().on(event);
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

// ═══════════════════════════════════════════════════════════════════════════
// BACKGROUND ISOLATE ENTRY POINT (Runs completely detached from UI)
// ═══════════════════════════════════════════════════════════════════════════
@pragma('vm:entry-point')
void _onServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('⚠️ Firebase already initialized in isolate.');
  }

  final db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://smart-women-safety-app-b1988-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  // Sensor Buffers
  final List<double> _magHistory = [];
  final List<Map<String, double>> _accelBuffer = [];
  final List<Map<String, double>> _gyroBuffer = [];

  // Service State
  double _smoothedDanger = 0.0;
  double _lastNotifUpdateScore = -1.0;
  bool _isSosActive = false;
  Position? _currentPosition;
  String? _mlUrl;
  int _consecutiveMlErrors = 0;

  // ── AUTONOMOUS TRIGGER MATRIX STATE ────────────────────────────────────────
  int _sustainedThreatCount = 0;
  DateTime _lastAutoSosTime = DateTime.fromMillisecondsSinceEpoch(0);
  const int _cooldownSeconds = 60; // 1 min cooldown to prevent spam

  // Hardware Subscriptions
  StreamSubscription? accelSub;
  StreamSubscription? gyroSub;
  StreamSubscription? gpsSub;
  Timer? heartbeatTimer;
  Timer? discoveryTimer;

  // ── Notification Manager ───────────────────────────────────────────────────
  void updateNotification(double score) {
    if ((score - _lastNotifUpdateScore).abs() < 0.05 && !_isSosActive) return;
    _lastNotifUpdateScore = score;

    if (service is AndroidServiceInstance) {
      final androidSvc = service as AndroidServiceInstance;
      if (_isSosActive) {
        androidSvc.setForegroundNotificationInfo(
          title: '🚨 SAFEHER SOS ACTIVE',
          content: 'Emergency Services and Contacts Notified.',
        );
      } else if (score > 0.75) {
        androidSvc.setForegroundNotificationInfo(
          title: '⚠️ SAFEHER: Danger Detected',
          content: 'Preparing to dispatch SOS... (${(score * 100).toInt()}% risk).',
        );
      } else if (score > 0.40) {
        androidSvc.setForegroundNotificationInfo(
          title: '⚠️ SAFEHER: Stay Alert',
          content: 'Unusual patterns detected.',
        );
      } else {
        androidSvc.setForegroundNotificationInfo(
          title: '✅ SAFEHER: Protected',
          content: 'Autonomous AI Sentinel is monitoring.',
        );
      }
    }
  }

  // ── AUTONOMOUS EVALUATOR (The Executioner) ─────────────────────────────────
  void _evaluateAutonomousTrigger(double score, bool backendFlag, String reason) {
    if (_isSosActive) return;

    // 1. Build Sustained Threat Counter
    if (backendFlag || score >= 0.85) {
      _sustainedThreatCount++;
    } else if (score < 0.60) {
      _sustainedThreatCount = 0;
    }

    // 2. Determine if trigger conditions are met
    bool isInstantTrigger = reason.contains('Kinetic');
    bool isSustainedTrigger = _sustainedThreatCount >= 3; // ~9 seconds of high danger

    if (isInstantTrigger || isSustainedTrigger) {
      if (DateTime.now().difference(_lastAutoSosTime).inSeconds > _cooldownSeconds) {
        _lastAutoSosTime = DateTime.now();
        _isSosActive = true;
        _sustainedThreatCount = 0;

        debugPrint('🚨 [BG SERVICE] AUTONOMOUS TRIGGER FIRED: $reason');

        // 🔥 FIRE EVENT TO MAIN UI ISOLATE TO START DISPATCH
        service.invoke('auto_sos_trigger', {
          'danger_score': score,
          'reason': reason,
          'lat': _currentPosition?.latitude ?? 0.0,
          'lng': _currentPosition?.longitude ?? 0.0,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });

        updateNotification(1.0);
      }
    }
  }

  // ── Inter-Isolate Listeners ────────────────────────────────────────────────
  service.on('stop').listen((_) {
    accelSub?.cancel();
    gyroSub?.cancel();
    gpsSub?.cancel();
    heartbeatTimer?.cancel();
    discoveryTimer?.cancel();
    service.stopSelf();
  });

  service.on('cancel_sos').listen((_) {
    _isSosActive = false;
    _sustainedThreatCount = 0;
    updateNotification(_smoothedDanger);
  });

  await Future.delayed(const Duration(milliseconds: 500));

  // ── Accelerometer Pipeline (Kinetic Spike Detection) ───────────────────────
  accelSub = accelerometerEventStream(samplingPeriod: const Duration(milliseconds: 20)).listen((e) {
    _accelBuffer.add({'x': e.x, 'y': e.y, 'z': e.z});
    if (_accelBuffer.length > 50) _accelBuffer.removeAt(0);

    final mag = _mag(e.x, e.y, e.z);
    _magHistory.add(mag);
    if (_magHistory.length > 30) _magHistory.removeAt(0);

    // INSTANT TRIGGER: Catastrophic kinetic impact or violent shake
    if (mag > 45.0 && !_isSosActive) {
      _evaluateAutonomousTrigger(0.99, true, 'Catastrophic Kinetic Spike');
    }
  });

  gyroSub = gyroscopeEventStream(samplingPeriod: const Duration(milliseconds: 20)).listen((e) {
    _gyroBuffer.add({'x': e.x, 'y': e.y, 'z': e.z});
    if (_gyroBuffer.length > 50) _gyroBuffer.removeAt(0);
  });

  // ── GPS Tracking ──────────────────────────────────────────────────────────
  try {
    gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((pos) async {
      _currentPosition = pos;
      service.invoke('location_update', {'lat': pos.latitude, 'lng': pos.longitude});

      try {
        final prefs = await SharedPreferences.getInstance();
        final uid = prefs.getString(AppConstants.userIdKey);
        if (uid != null && uid.isNotEmpty) {
          await db.ref('users/$uid/liveLocation').update({
            'lat': pos.latitude, 'lng': pos.longitude, 'speed': pos.speed * 3.6,
            'isSOSActive': _isSosActive, 'dangerScore': _smoothedDanger,
            'timestamp': ServerValue.timestamp,
          });
        }
      } catch (_) {}
    });
  } catch (_) {}

  // ── ML Discovery ──────────────────────────────────────────────────────────
  Future<void> discoverBackend() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_kPrefMlUrl);

    if (cached != null && cached.isNotEmpty) {
      try {
        final r = await http.get(Uri.parse('$cached/health')).timeout(const Duration(seconds: 4));
        if (r.statusCode == 200) { _mlUrl = cached; return; }
      } catch (_) {}
    }

    for (final url in _kMlUrls) {
      try {
        final r = await http.get(Uri.parse('$url/health')).timeout(const Duration(seconds: 4));
        if (r.statusCode == 200) {
          _mlUrl = url;
          await prefs.setString(_kPrefMlUrl, url);
          return;
        }
      } catch (_) {}
    }
  }

  // ── Python Cloud Inference ────────────────────────────────────────────────
  Future<Map<String, dynamic>?> callCloudMl() async {
    if (_mlUrl == null || _accelBuffer.length < 50) return null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString(AppConstants.userIdKey) ?? 'bg_sentinel';

      final cleanAccel = _accelBuffer.map((e) => {'x': e['x'], 'y': e['y'], 'z': e['z']}).toList();
      final cleanGyro  = _gyroBuffer.map((e) => {'x': e['x'], 'y': e['y'], 'z': e['z']}).toList();

      final body = {
        'user_id': uid,
        'accel_samples': cleanAccel,
        'gyro_samples':  cleanGyro,
        'audio_scream_probability': 0.0,
        'hour_of_day': DateTime.now().hour,
        'gps_lat': _currentPosition?.latitude ?? 0.0,
        'gps_lon': _currentPosition?.longitude ?? 0.0,
        'gps_speed_kmh': (_currentPosition?.speed ?? 0.0) * 3.6,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final res = await http.post(
        Uri.parse('$_mlUrl/analyze_danger'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(milliseconds: _kMlTimeoutMs));

      if (res.statusCode == 200) {
        _consecutiveMlErrors = 0;
        final data = jsonDecode(res.body);
        if (data != null && data['danger_score'] != null) {
          return data;
        }
      }
    } catch (e) {
      _consecutiveMlErrors++;
      if (_consecutiveMlErrors >= 3) {
        _mlUrl = null;
        _consecutiveMlErrors = 0;
      }
    }
    return null;
  }

  double calculateLocalRisk() {
    if (_magHistory.length < 10) return 0.0;
    final mean = _magHistory.reduce((a, b) => a + b) / _magHistory.length;
    final variance = _magHistory.map((m) => (m - mean) * (m - mean)).reduce((a, b) => a + b) / _magHistory.length;
    return (variance / 250.0).clamp(0.0, 1.0);
  }

  // ── Analysis Loop (3s Heartbeat) ──────────────────────────────────────────
  await discoverBackend();

  discoveryTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
    if (_mlUrl == null) await discoverBackend();
  });

  heartbeatTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
    final cloudData = await callCloudMl();

    double rawRisk = calculateLocalRisk();
    bool backendSosFlag = false;

    if (cloudData != null) {
      final rawScore = cloudData['danger_score'];
      rawRisk = rawScore is int ? (rawScore / 100.0) : (rawScore as double);
      backendSosFlag = cloudData['sos_triggered'] ?? false;

      service.invoke('ml_result', {
        'danger_score': rawRisk.clamp(0.0, 1.0),
        'danger_level': cloudData['danger_level'] ?? 'safe',
      });
    }

    _smoothedDanger = (_smoothedDanger * 0.60 + rawRisk * 0.40).clamp(0.0, 1.0);

    // ⚡ FEED INTO THE AUTONOMOUS MATRIX
    _evaluateAutonomousTrigger(_smoothedDanger, backendSosFlag, 'Sustained ML Danger Analysis');

    service.invoke('sensor_update', {
      'danger_score': _smoothedDanger,
      'is_cloud_active': cloudData != null,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    updateNotification(_smoothedDanger);
  });
}