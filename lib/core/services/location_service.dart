// lib/core/services/location_service.dart — Complete Advanced Location Service (FIXED)

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'places_service.dart';

// ─────────────────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────────────────

enum TravelMode { walking, driving, transit }
enum SpeedAlert { none, suddenStop, vehicleSpeed, runningFast }
enum GeofenceEvent { entered, exited, none }

// ─────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────

class LocationData {
  final double lat;
  final double lng;
  final double accuracy;
  final double speed;
  final double heading;
  final double altitude;
  final String address;
  final DateTime timestamp;

  const LocationData({
    required this.lat,
    required this.lng,
    required this.accuracy,
    required this.speed,
    required this.heading,
    required this.altitude,
    required this.address,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'lat': lat,
    'lng': lng,
    'accuracy': accuracy,
    'speed': speed,
    'heading': heading,
    'altitude': altitude,
    'address': address,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'isSharing': true,
  };

  factory LocationData.fromJson(Map<String, dynamic> json) => LocationData(
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
    speed: (json['speed'] as num?)?.toDouble() ?? 0,
    heading: (json['heading'] as num?)?.toDouble() ?? 0,
    altitude: (json['altitude'] as num?)?.toDouble() ?? 0,
    address: json['address'] as String? ?? '',
    timestamp: json['timestamp'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
        : DateTime.now(),
  );
}

class SafePlace {
  final String id;
  final String name;
  final String type;
  final double lat;
  final double lng;
  final double distanceKm;
  final String address;
  final String? phone;

  const SafePlace({
    required this.id,
    required this.name,
    required this.type,
    required this.lat,
    required this.lng,
    required this.distanceKm,
    required this.address,
    this.phone,
  });
}

class DangerZone {
  final String id;
  final double lat;
  final double lng;
  final double radiusMeters;
  final int sosCount;
  final DateTime lastIncident;

  const DangerZone({
    required this.id,
    required this.lat,
    required this.lng,
    required this.radiusMeters,
    required this.sosCount,
    required this.lastIncident,
  });
}

class JourneyData {
  final String id;
  final String destinationName;
  final double destLat;
  final double destLng;
  final DateTime startTime;
  final DateTime expectedArrival;
  final bool isActive;
  final bool isOverdue;
  final List<LocationData> breadcrumbs;
  final TravelMode travelMode;

  const JourneyData({
    required this.id,
    required this.destinationName,
    required this.destLat,
    required this.destLng,
    required this.startTime,
    required this.expectedArrival,
    required this.isActive,
    this.isOverdue = false,
    required this.breadcrumbs,
    this.travelMode = TravelMode.walking,
  });

  JourneyData copyWith({
    bool? isActive,
    bool? isOverdue,
    List<LocationData>? breadcrumbs,
  }) =>
      JourneyData(
        id: id,
        destinationName: destinationName,
        destLat: destLat,
        destLng: destLng,
        startTime: startTime,
        expectedArrival: expectedArrival,
        isActive: isActive ?? this.isActive,
        isOverdue: isOverdue ?? this.isOverdue,
        breadcrumbs: breadcrumbs ?? this.breadcrumbs,
        travelMode: travelMode,
      );
}

class RouteInfo {
  final List<LatLngPoint> polylinePoints;
  final double distanceKm;
  final int durationMinutes;
  final List<SafePlace> safePlacesAlongRoute;
  final List<DangerZone> dangerZonesOnRoute;
  final String distanceText;
  final String durationText;
  final TravelMode travelMode;

  const RouteInfo({
    required this.polylinePoints,
    required this.distanceKm,
    required this.durationMinutes,
    required this.safePlacesAlongRoute,
    required this.dangerZonesOnRoute,
    required this.distanceText,
    required this.durationText,
    required this.travelMode,
  });
}

class LatLngPoint {
  final double lat;
  final double lng;
  const LatLngPoint(this.lat, this.lng);
}

class GeofenceZone {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double radiusMeters;
  final bool isHome;
  final TimeOfDay? autoSharingStart;
  final TimeOfDay? autoSharingEnd;

  GeofenceZone({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusMeters,
    this.isHome = false,
    this.autoSharingStart,
    this.autoSharingEnd,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'lat': lat,
    'lng': lng,
    'radiusMeters': radiusMeters,
    'isHome': isHome,
    'autoSharingStart': autoSharingStart != null
        ? '${autoSharingStart!.hour}:${autoSharingStart!.minute}'
        : null,
    'autoSharingEnd': autoSharingEnd != null
        ? '${autoSharingEnd!.hour}:${autoSharingEnd!.minute}'
        : null,
  };

  factory GeofenceZone.fromJson(Map<String, dynamic> j) {
    TimeOfDay? parseTime(String? s) {
      if (s == null) return null;
      final parts = s.split(':');
      return TimeOfDay(
          hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    return GeofenceZone(
      id: j['id'] as String,
      name: j['name'] as String,
      lat: (j['lat'] as num).toDouble(),
      lng: (j['lng'] as num).toDouble(),
      radiusMeters: (j['radiusMeters'] as num).toDouble(),
      isHome: j['isHome'] as bool? ?? false,
      autoSharingStart: parseTime(j['autoSharingStart'] as String?),
      autoSharingEnd: parseTime(j['autoSharingEnd'] as String?),
    );
  }
}

class SpeedAlertData {
  final SpeedAlert type;
  final double speedKmh;
  final double prevSpeedKmh;
  final DateTime timestamp;
  final String message;

  const SpeedAlertData({
    required this.type,
    required this.speedKmh,
    required this.prevSpeedKmh,
    required this.timestamp,
    required this.message,
  });
}

class ContactLocation {
  final String uid;
  final String name;
  final String? photoUrl;
  final LocationData location;
  final bool isSharing;

  const ContactLocation({
    required this.uid,
    required this.name,
    this.photoUrl,
    required this.location,
    required this.isSharing,
  });
}

// ─────────────────────────────────────────────────────────────
// DIRECTIONS SERVICE — real Google Directions API
// ─────────────────────────────────────────────────────────────

class _DirectionsService {
  static const String _apiKey = 'AIzaSyDB1FkgbJbGI-ttCUlVdENdy_hoXGdjU7Q';
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  Future<RouteInfo?> getRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    required TravelMode mode,
    required List<SafePlace> nearbyPlaces,
    required List<DangerZone> dangerZones,
  }) async {
    final modeStr = mode == TravelMode.driving
        ? 'driving'
        : mode == TravelMode.transit
        ? 'transit'
        : 'walking';
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'origin': '$fromLat,$fromLng',
        'destination': '$toLat,$toLng',
        'mode': modeStr,
        'key': _apiKey,
        'alternatives': 'false',
        'language': 'en',
      });

      final res =
      await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return null;

      final routes = data['routes'] as List;
      if (routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final leg =
      (route['legs'] as List).first as Map<String, dynamic>;

      final encoded =
      route['overview_polyline']['points'] as String;
      final points = _decodePolyline(encoded);

      final distText = leg['distance']['text'] as String;
      final durText = leg['duration']['text'] as String;
      final distValue = (leg['distance']['value'] as int) / 1000.0;
      final durValue =
      ((leg['duration']['value'] as int) / 60).round();

      final routePlaces = _placesAlongRoute(points, nearbyPlaces);
      final routeDangers = _dangersAlongRoute(points, dangerZones);

      return RouteInfo(
        polylinePoints: points,
        distanceKm: distValue,
        durationMinutes: durValue,
        safePlacesAlongRoute: routePlaces,
        dangerZonesOnRoute: routeDangers,
        distanceText: distText,
        durationText: durText,
        travelMode: mode,
      );
    } catch (e) {
      return null;
    }
  }

  List<LatLngPoint> _decodePolyline(String encoded) {
    final points = <LatLngPoint>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int result = 0;
      int shift = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      result = 0;
      shift = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLngPoint(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  List<SafePlace> _placesAlongRoute(
      List<LatLngPoint> route, List<SafePlace> places) {
    return places.where((p) {
      return route.any(
              (pt) => _dist(pt.lat, pt.lng, p.lat, p.lng) < 0.5);
    }).toList();
  }

  List<DangerZone> _dangersAlongRoute(
      List<LatLngPoint> route, List<DangerZone> zones) {
    return zones.where((z) {
      return route.any((pt) =>
      _dist(pt.lat, pt.lng, z.lat, z.lng) * 1000 <
          z.radiusMeters + 200);
    }).toList();
  }

  double _dist(
      double lat1, double lng1, double lat2, double lng2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return 2 * R * asin(sqrt(a));
  }
}

// ─────────────────────────────────────────────────────────────
// BACKGROUND LOCATION SERVICE
// ─────────────────────────────────────────────────────────────

class BackgroundLocationService {
  BackgroundLocationService._();
  static final BackgroundLocationService instance =
  BackgroundLocationService._();

  StreamSubscription<Position>? _bgSub;
  Timer? _bgFirebaseTimer;
  bool _isRunning = false;

  // ✅ FIX: Use instanceFor with explicit databaseURL so the service
  // connects to the correct Realtime Database in asia-southeast1.
  // Previously FirebaseDatabase.instance had no databaseURL in
  // firebase_options.dart so it connected to nothing → data was never stored.
  final _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
    'https://smart-women-safety-app-b1988-default-rtdb.asia-southeast1.firebasedatabase.app',
  );
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';
  bool get isRunning => _isRunning;

  Future<void> startBackgroundTracking() async {
    if (_isRunning) return;
    _isRunning = true;

    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.whileInUse) {
      await Geolocator.requestPermission();
    }

    await _bgSub?.cancel();
    _bgSub = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 10),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText:
          'SafeHer is tracking your location for safety',
          notificationTitle: '🛡️ SafeHer Active',
          enableWakeLock: true,
        ),
      ),
    ).listen(
          (pos) async {
        if (_uid.isEmpty) return;
        try {
          await _db.ref('users/$_uid/liveLocation').update({
            'lat': pos.latitude,
            'lng': pos.longitude,
            'speed': (pos.speed * 3.6).clamp(0, 300),
            'heading': pos.heading,
            'accuracy': pos.accuracy,
            'timestamp': pos.timestamp.millisecondsSinceEpoch,
            'isSharing': true,
            'source': 'background',
          });

          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble('bg_last_lat', pos.latitude);
          await prefs.setDouble('bg_last_lng', pos.longitude);
          await prefs.setInt(
              'bg_last_ts', pos.timestamp.millisecondsSinceEpoch);
        } catch (_) {}
      },
      onError: (_) {},
    );
  }

  Future<void> stopBackgroundTracking() async {
    await _bgSub?.cancel();
    _bgFirebaseTimer?.cancel();
    _isRunning = false;
  }

  Future<LocationData?> getLastBackgroundLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble('bg_last_lat');
      final lng = prefs.getDouble('bg_last_lng');
      final ts = prefs.getInt('bg_last_ts');
      if (lat == null || lng == null) return null;
      return LocationData(
        lat: lat,
        lng: lng,
        accuracy: 0,
        speed: 0,
        heading: 0,
        altitude: 0,
        address: '',
        timestamp: ts != null
            ? DateTime.fromMillisecondsSinceEpoch(ts)
            : DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// GEOFENCE SERVICE
// ─────────────────────────────────────────────────────────────

class GeofenceService {
  GeofenceService._();
  static final GeofenceService instance = GeofenceService._();

  static const String _prefsKey = 'geofence_zones';

  List<GeofenceZone> _zones = [];
  final Map<String, bool> _insideStatus = {};
  final _eventCtrl =
  StreamController<Map<String, dynamic>>.broadcast();

  List<GeofenceZone> get zones => _zones;
  Stream<Map<String, dynamic>> get eventStream => _eventCtrl.stream;

  Future<void> loadZones() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        _zones = list
            .map((e) =>
            GeofenceZone.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
  }

  Future<void> saveZone(GeofenceZone zone) async {
    _zones.removeWhere((z) => z.id == zone.id);
    _zones.add(zone);
    await _persist();
  }

  Future<void> deleteZone(String id) async {
    _zones.removeWhere((z) => z.id == id);
    _insideStatus.remove(id);
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(_zones.map((z) => z.toJson()).toList()),
    );
  }

  void checkGeofences(LocationData loc) {
    final now = DateTime.now();
    final nowHour = now.hour;

    for (final zone in _zones) {
      final distM =
      _distM(loc.lat, loc.lng, zone.lat, zone.lng);
      final isInside = distM <= zone.radiusMeters;
      final wasInside = _insideStatus[zone.id] ?? true;

      if (!wasInside && isInside) {
        _insideStatus[zone.id] = true;
        _eventCtrl.add({
          'event': GeofenceEvent.entered.name,
          'zone': zone,
          'loc': loc,
        });
        if (zone.isHome) {
          _eventCtrl
              .add({'action': 'stop_sharing', 'reason': 'arrived_home'});
        }
      } else if (wasInside && !isInside) {
        _insideStatus[zone.id] = false;
        _eventCtrl.add({
          'event': GeofenceEvent.exited.name,
          'zone': zone,
          'loc': loc,
        });
        if (zone.isHome && zone.autoSharingStart != null) {
          final startHour = zone.autoSharingStart!.hour;
          final isNight = nowHour >= startHour || nowHour < 6;
          if (isNight) {
            _eventCtrl.add({
              'action': 'start_sharing',
              'reason': 'left_home_at_night',
            });
          }
        }
      }
    }
  }

  double _distM(
      double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return 2 * R * asin(sqrt(a));
  }

  void dispose() => _eventCtrl.close();
}

// ─────────────────────────────────────────────────────────────
// SPEED MONITOR
// ─────────────────────────────────────────────────────────────

class SpeedMonitor {
  SpeedMonitor._();
  static final SpeedMonitor instance = SpeedMonitor._();

  final _alertCtrl = StreamController<SpeedAlertData>.broadcast();
  Stream<SpeedAlertData> get alertStream => _alertCtrl.stream;

  double _prevSpeed = 0;
  DateTime? _prevTime;
  final List<double> _speedHistory = [];
  static const int _historySize = 10;

  TravelMode _detectedMode = TravelMode.walking;
  TravelMode get detectedMode => _detectedMode;

  void processLocation(LocationData loc) {
    final speed = loc.speed;
    _speedHistory.add(speed);
    if (_speedHistory.length > _historySize) _speedHistory.removeAt(0);

    final avgSpeed = _speedHistory.isEmpty
        ? 0.0
        : _speedHistory.reduce((a, b) => a + b) / _speedHistory.length;

    if (avgSpeed > 30) {
      _detectedMode = TravelMode.driving;
    } else if (avgSpeed > 8) {
      _detectedMode = TravelMode.transit;
    } else {
      _detectedMode = TravelMode.walking;
    }

    final now = DateTime.now();
    if (_prevTime != null) {
      final timeDiff = now.difference(_prevTime!).inSeconds;

      if (_prevSpeed > 5 && speed < 1 && timeDiff < 30) {
        final hour = now.hour;
        if (hour >= 20 || hour < 6) {
          _alertCtrl.add(SpeedAlertData(
            type: SpeedAlert.suddenStop,
            speedKmh: speed,
            prevSpeedKmh: _prevSpeed,
            timestamp: now,
            message: 'Sudden stop detected at night. Are you safe?',
          ));
        }
      }

      if (_prevSpeed < 5 && speed > 40) {
        _alertCtrl.add(SpeedAlertData(
          type: SpeedAlert.vehicleSpeed,
          speedKmh: speed,
          prevSpeedKmh: _prevSpeed,
          timestamp: now,
          message:
          'You appear to be in a vehicle. Location sharing auto-started.',
        ));
      }
    }

    _prevSpeed = speed;
    _prevTime = now;
  }

  void dispose() => _alertCtrl.close();
}

// ─────────────────────────────────────────────────────────────
// MAIN LOCATION SERVICE
// ─────────────────────────────────────────────────────────────

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  // ✅ FIX: Use instanceFor with explicit databaseURL so the service
  // connects to the correct Realtime Database in asia-southeast1.
  // Previously FirebaseDatabase.instance had no databaseURL in
  // firebase_options.dart so it connected to nothing → data was never stored.
  final _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
    'https://smart-women-safety-app-b1988-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _directions = _DirectionsService();

  final _locationCtrl = StreamController<LocationData>.broadcast();
  final _dangerCtrl = StreamController<DangerZone?>.broadcast();
  final _journeyCtrl = StreamController<JourneyData?>.broadcast();
  final _contactCtrl =
  StreamController<Map<String, ContactLocation>>.broadcast();
  final _speedAlertCtrl =
  StreamController<SpeedAlertData>.broadcast();
  final _geofenceCtrl =
  StreamController<Map<String, dynamic>>.broadcast();

  StreamSubscription<Position>? _positionSub;
  StreamSubscription? _geofenceEventSub;
  Timer? _firebaseTimer;
  Timer? _journeyTimer;
  Timer? _dangerZoneTimer;

  LocationData? _lastLocation;
  bool _isSharingLive = false;
  JourneyData? _activeJourney;
  final List<LocationData> _breadcrumbs = [];
  List<DangerZone> _cachedDangerZones = [];
  final Map<String, ContactLocation> _contactLocations = {};
  final Map<String, StreamSubscription> _contactSubs = {};

  String get _uid => _auth.currentUser?.uid ?? '';
  Stream<LocationData> get locationStream => _locationCtrl.stream;
  Stream<DangerZone?> get dangerZoneStream => _dangerCtrl.stream;
  Stream<JourneyData?> get journeyStream => _journeyCtrl.stream;
  Stream<Map<String, ContactLocation>> get contactLocationStream =>
      _contactCtrl.stream;
  Stream<SpeedAlertData> get speedAlertStream =>
      SpeedMonitor.instance.alertStream;
  Stream<Map<String, dynamic>> get geofenceStream =>
      GeofenceService.instance.eventStream;
  LocationData? get lastLocation => _lastLocation;
  bool get isSharingLive => _isSharingLive;
  JourneyData? get activeJourney => _activeJourney;
  TravelMode get currentTravelMode => SpeedMonitor.instance.detectedMode;

  // ─── PERMISSION ──────────────────────────────────────────────
  Future<bool> requestPermission() async {
    bool svc = await Geolocator.isLocationServiceEnabled();
    if (!svc) {
      await Geolocator.openLocationSettings();
      return false;
    }
    LocationPermission p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return false;
    }
    return p == LocationPermission.always ||
        p == LocationPermission.whileInUse;
  }

  // ─── INIT ────────────────────────────────────────────────────
  Future<void> initializeServices() async {
    await GeofenceService.instance.loadZones();

    _geofenceEventSub?.cancel();
    _geofenceEventSub =
        GeofenceService.instance.eventStream.listen((event) {
          _geofenceCtrl.add(event);
          if (event['action'] == 'start_sharing') {
            startLiveTracking(shareToFirebase: true);
          } else if (event['action'] == 'stop_sharing') {
            stopLiveTracking();
          }
        });

    _cachedDangerZones = await loadDangerZones();

    _dangerZoneTimer?.cancel();
    _dangerZoneTimer =
        Timer.periodic(const Duration(minutes: 5), (_) async {
          _cachedDangerZones = await loadDangerZones();
        });
  }

  // ─── GET CURRENT LOCATION ────────────────────────────────────
  Future<LocationData?> getCurrentLocation() async {
    if (!await requestPermission()) return null;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 15));
      return await _posToData(pos);
    } catch (_) {
      return _lastLocation;
    }
  }

  Future<LocationData> _posToData(Position pos) async {
    final address =
    await _reverseGeocode(pos.latitude, pos.longitude);
    final data = LocationData(
      lat: pos.latitude,
      lng: pos.longitude,
      accuracy: pos.accuracy,
      speed: (pos.speed * 3.6).clamp(0, 300),
      heading: pos.heading,
      altitude: pos.altitude,
      address: address,
      timestamp: DateTime.now(),
    );
    _lastLocation = data;
    _locationCtrl.add(data);
    return data;
  }

  // ─── START LIVE TRACKING ─────────────────────────────────────
  Future<void> startLiveTracking(
      {bool shareToFirebase = false}) async {
    if (!await requestPermission()) return;
    _isSharingLive = shareToFirebase;
    await _positionSub?.cancel();

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) async {
      final data = await _posToData(pos);

      SpeedMonitor.instance.processLocation(data);
      GeofenceService.instance.checkGeofences(data);

      if (_activeJourney != null && _activeJourney!.isActive) {
        _breadcrumbs.add(data);
        _activeJourney = _activeJourney!
            .copyWith(breadcrumbs: List.from(_breadcrumbs));
        _journeyCtrl.add(_activeJourney);
        _checkArrival(data);
        if (_breadcrumbs.length % 5 == 0) _saveBreadcrumb(data);
      }

      _checkDangerZonesSync(data);
    });

    if (shareToFirebase) {
      _firebaseTimer?.cancel();
      _firebaseTimer =
          Timer.periodic(const Duration(seconds: 5), (_) {
            if (_lastLocation != null) _pushLiveLocation(_lastLocation!);
          });
      await BackgroundLocationService.instance.startBackgroundTracking();
    }
  }

  Future<void> _pushLiveLocation(LocationData data) async {
    if (_uid.isEmpty) return;
    try {
      await _db.ref('users/$_uid/liveLocation').update({
        ...data.toJson(),
        'uid': _uid,
        'userName': _auth.currentUser?.displayName ?? 'User',
        'userPhoto': _auth.currentUser?.photoURL ?? '',
        'isSharing': true,
        'travelMode': SpeedMonitor.instance.detectedMode.name,
      });
    } catch (_) {}
  }

  Future<void> stopLiveTracking() async {
    await _positionSub?.cancel();
    _firebaseTimer?.cancel();
    _isSharingLive = false;
    await BackgroundLocationService.instance.stopBackgroundTracking();
    if (_uid.isNotEmpty) {
      try {
        await _db.ref('users/$_uid/liveLocation').update({
          'isSharing': false,
          'stoppedAt': ServerValue.timestamp,
        });
      } catch (_) {}
    }
  }

  // ─── CONTACT LIVE TRACKING ───────────────────────────────────
  void startTrackingContacts(List<String> contactUids) {
    for (final uid in contactUids) {
      if (_contactSubs.containsKey(uid)) continue;
      _contactSubs[uid] = _db
          .ref('users/$uid/liveLocation')
          .onValue
          .listen((event) {
        if (event.snapshot.value == null) {
          _contactLocations.remove(uid);
          _contactCtrl.add(Map.from(_contactLocations));
          return;
        }
        try {
          final raw = Map<String, dynamic>.from(
              event.snapshot.value as Map);
          if (raw['isSharing'] != true) {
            _contactLocations.remove(uid);
          } else {
            _contactLocations[uid] = ContactLocation(
              uid: uid,
              name: raw['userName'] as String? ?? 'Contact',
              photoUrl: raw['userPhoto'] as String?,
              location: LocationData.fromJson(raw),
              isSharing: true,
            );
          }
          _contactCtrl.add(Map.from(_contactLocations));
        } catch (_) {}
      });
    }
  }

  void stopTrackingContact(String uid) {
    _contactSubs[uid]?.cancel();
    _contactSubs.remove(uid);
    _contactLocations.remove(uid);
    _contactCtrl.add(Map.from(_contactLocations));
  }

  Stream<LocationData?> streamContactLocation(String contactUid) {
    return _db
        .ref('users/$contactUid/liveLocation')
        .onValue
        .map((event) {
      if (event.snapshot.value == null) return null;
      final raw = Map<String, dynamic>.from(
          event.snapshot.value as Map);
      if (raw['isSharing'] != true) return null;
      return LocationData.fromJson(raw);
    });
  }

  // ─── REAL DIRECTIONS API ROUTE ───────────────────────────────
  Future<RouteInfo?> getSafeRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    TravelMode mode = TravelMode.walking,
  }) async {
    final midLat = (fromLat + toLat) / 2;
    final midLng = (fromLng + toLng) / 2;
    final places = await getNearbyPlaces(
        lat: midLat, lng: midLng, radiusKm: 5);

    final route = await _directions.getRoute(
      fromLat: fromLat,
      fromLng: fromLng,
      toLat: toLat,
      toLng: toLng,
      mode: mode,
      nearbyPlaces: places,
      dangerZones: _cachedDangerZones,
    );

    if (route != null) return route;

    return _buildFallbackRoute(
        fromLat, fromLng, toLat, toLng, places, mode);
  }

  RouteInfo _buildFallbackRoute(
      double lat1,
      double lng1,
      double lat2,
      double lng2,
      List<SafePlace> places,
      TravelMode mode,
      ) {
    const steps = 30;
    final points = List.generate(steps + 1, (i) {
      final t = i / steps;
      final curve = sin(t * pi) * 0.0005;
      return LatLngPoint(
        lat1 + (lat2 - lat1) * t + curve,
        lng1 + (lng2 - lng1) * t + curve,
      );
    });
    final distKm = _haversine(lat1, lng1, lat2, lng2);
    final speedKmh = mode == TravelMode.driving
        ? 40
        : mode == TravelMode.transit
        ? 25
        : 4;
    final dur =
    (distKm / speedKmh * 60).round().clamp(1, 9999);

    return RouteInfo(
      polylinePoints: points,
      distanceKm: distKm,
      durationMinutes: dur,
      safePlacesAlongRoute: places.take(3).toList(),
      dangerZonesOnRoute: [],
      distanceText: distKm < 1
          ? '${(distKm * 1000).toStringAsFixed(0)} m'
          : '${distKm.toStringAsFixed(1)} km',
      durationText:
      dur < 60 ? '$dur min' : '${dur ~/ 60}h ${dur % 60}m',
      travelMode: mode,
    );
  }

  // ─── DANGER ZONES ─────────────────────────────────────────────
  Future<List<DangerZone>> loadDangerZones() async {
    try {
      final snap =
      await _firestore.collection('dangerZones').limit(200).get();
      final zones = snap.docs.map((doc) {
        final d = doc.data();
        return DangerZone(
          id: doc.id,
          lat: (d['lat'] as num).toDouble(),
          lng: (d['lng'] as num).toDouble(),
          radiusMeters:
          (d['radiusMeters'] as num?)?.toDouble() ?? 200,
          sosCount: (d['sosCount'] as int?) ?? 1,
          lastIncident: d['lastIncident'] != null
              ? (d['lastIncident'] as Timestamp).toDate()
              : DateTime.now(),
        );
      }).toList();
      _cachedDangerZones = zones;
      return zones;
    } catch (_) {
      return _cachedDangerZones;
    }
  }

  void _checkDangerZonesSync(LocationData loc) {
    for (final z in _cachedDangerZones) {
      if (_haversine(loc.lat, loc.lng, z.lat, z.lng) * 1000 <=
          z.radiusMeters + 100) {
        _dangerCtrl.add(z);
        return;
      }
    }
    _dangerCtrl.add(null);
  }

  Future<void> reportDangerZone(double lat, double lng) async {
    try {
      for (final z in _cachedDangerZones) {
        if (_haversine(lat, lng, z.lat, z.lng) * 1000 <
            z.radiusMeters) {
          await _firestore
              .collection('dangerZones')
              .doc(z.id)
              .update({
            'sosCount': FieldValue.increment(1),
            'lastIncident': FieldValue.serverTimestamp(),
          });
          return;
        }
      }
      await _firestore.collection('dangerZones').add({
        'lat': lat,
        'lng': lng,
        'radiusMeters': 300.0,
        'sosCount': 1,
        'lastIncident': FieldValue.serverTimestamp(),
        'reportedBy': _uid,
      });
      _cachedDangerZones = await loadDangerZones();
    } catch (_) {}
  }

  // ─── JOURNEY MODE ─────────────────────────────────────────────
  Future<JourneyData> startJourney({
    required String destinationName,
    required double destLat,
    required double destLng,
    required int estimatedMinutes,
    TravelMode mode = TravelMode.walking,
  }) async {
    _breadcrumbs.clear();
    final now = DateTime.now();
    _activeJourney = JourneyData(
      id: now.millisecondsSinceEpoch.toString(),
      destinationName: destinationName,
      destLat: destLat,
      destLng: destLng,
      startTime: now,
      expectedArrival: now.add(Duration(minutes: estimatedMinutes)),
      isActive: true,
      breadcrumbs: [],
      travelMode: mode,
    );
    _journeyCtrl.add(_activeJourney);

    await startLiveTracking(shareToFirebase: true);

    if (_uid.isNotEmpty) {
      await _db.ref('users/$_uid/journey').set({
        'id': _activeJourney!.id,
        'destinationName': destinationName,
        'destLat': destLat,
        'destLng': destLng,
        'startTime': now.millisecondsSinceEpoch,
        'expectedArrival':
        _activeJourney!.expectedArrival.millisecondsSinceEpoch,
        'isActive': true,
        'isOverdue': false,
        'uid': _uid,
        'travelMode': mode.name,
      });
    }

    _journeyTimer?.cancel();
    _journeyTimer = Timer(
        Duration(minutes: estimatedMinutes + 10), _triggerOverdue);
    return _activeJourney!;
  }

  Future<void> endJourney({bool arrived = true}) async {
    _journeyTimer?.cancel();
    final j = _activeJourney;
    _activeJourney = null;
    _breadcrumbs.clear();
    _journeyCtrl.add(null);
    if (_uid.isNotEmpty && j != null) {
      await _db.ref('users/$_uid/journey').update({
        'isActive': false,
        'arrived': arrived,
        'endedAt': ServerValue.timestamp,
      });
    }
    await stopLiveTracking();
  }

  void _checkArrival(LocationData loc) {
    if (_activeJourney == null) return;
    final d = _haversine(loc.lat, loc.lng, _activeJourney!.destLat,
        _activeJourney!.destLng) *
        1000;
    if (d < 100) endJourney(arrived: true);
  }

  Future<void> _saveBreadcrumb(LocationData data) async {
    if (_uid.isEmpty) return;
    try {
      await _db
          .ref('users/$_uid/journey/breadcrumbs')
          .push()
          .set({
        'lat': data.lat,
        'lng': data.lng,
        'timestamp': data.timestamp.millisecondsSinceEpoch,
        'speed': data.speed,
      });
    } catch (_) {}
  }

  Future<void> _triggerOverdue() async {
    if (_activeJourney == null || !_activeJourney!.isActive) return;
    _activeJourney = _activeJourney!.copyWith(isOverdue: true);
    _journeyCtrl.add(_activeJourney);
    if (_uid.isNotEmpty) {
      await _db.ref('users/$_uid/journey').update({
        'isOverdue': true,
        'overdueAt': ServerValue.timestamp,
      });
    }
  }

  // ─── NEARBY SAFE PLACES ──────────────────────────────────────
  Future<List<SafePlace>> getNearbyPlaces({
    required double lat,
    required double lng,
    double radiusKm = 3.0,
    bool forceRefresh = false,
  }) async {
    final places = await PlacesService.instance.fetchRealPlaces(
      lat: lat,
      lng: lng,
      forceRefresh: forceRefresh,
    );
    if (places.isNotEmpty) return places;
    return _fallbackPlaces(lat, lng);
  }

  List<SafePlace> _fallbackPlaces(double lat, double lng) => [
    SafePlace(
        id: 'p1',
        name: 'Police Station',
        type: 'police',
        lat: lat + 0.008,
        lng: lng + 0.005,
        distanceKm:
        _haversine(lat, lng, lat + 0.008, lng + 0.005),
        address: 'Estimated nearby',
        phone: '100'),
    SafePlace(
        id: 'h1',
        name: 'Hospital',
        type: 'hospital',
        lat: lat - 0.006,
        lng: lng + 0.009,
        distanceKm:
        _haversine(lat, lng, lat - 0.006, lng + 0.009),
        address: 'Estimated nearby',
        phone: '108'),
    SafePlace(
        id: 's1',
        name: 'Women Safety Shelter',
        type: 'shelter',
        lat: lat + 0.004,
        lng: lng - 0.007,
        distanceKm:
        _haversine(lat, lng, lat + 0.004, lng - 0.007),
        address: 'Estimated nearby',
        phone: '1091'),
  ];

  // ─── HELPERS ─────────────────────────────────────────────────
  double _haversine(
      double lat1, double lng1, double lat2, double lng2) {
    const R = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) *
            cos(_rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return 2 * R * asin(sqrt(a));
  }

  double _rad(double d) => d * pi / 180;

  Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng)
          .timeout(const Duration(seconds: 5));
      if (marks.isNotEmpty) {
        final p = marks.first;
        return [p.subLocality, p.locality, p.administrativeArea]
            .where((s) => s != null && s!.isNotEmpty)
            .join(', ');
      }
    } catch (_) {}
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  Future<LatLngPoint?> geocodeAddress(String address) async {
    try {
      final locs = await locationFromAddress(address)
          .timeout(const Duration(seconds: 8));
      if (locs.isNotEmpty) {
        return LatLngPoint(
            locs.first.latitude, locs.first.longitude);
      }
    } catch (_) {}
    return null;
  }

  void dispose() {
    _positionSub?.cancel();
    _firebaseTimer?.cancel();
    _journeyTimer?.cancel();
    _dangerZoneTimer?.cancel();
    _geofenceEventSub?.cancel();
    for (final s in _contactSubs.values) {
      s.cancel();
    }
    _locationCtrl.close();
    _dangerCtrl.close();
    _journeyCtrl.close();
    _contactCtrl.close();
    _speedAlertCtrl.close();
    _geofenceCtrl.close();
    GeofenceService.instance.dispose();
    SpeedMonitor.instance.dispose();
  }
}