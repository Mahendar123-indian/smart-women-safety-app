// lib/features/location/providers/location_provider.dart
// ─────────────────────────────────────────────────────────────────────────────
// INDUSTRIAL SENTINEL — LOCATION ENGINE v5.0 (2026 PRODUCTION)
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

// Core Services
import '../../../core/services/location_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/location/journey_monitor_service.dart';
import '../../../core/services/location/night_mode_service.dart';
import '../../../core/services/location/location_intelligence_service.dart';

// Headless SOS Service Integration
import '../../sos/services/sos_service.dart';

enum LocationStatus { initial, loading, tracking, error }

class LocationProvider extends ChangeNotifier {
  final _service      = LocationService.instance;
  final _notif        = NotificationService.instance;
  final _monitor      = JourneyMonitorService.instance;
  final _nightMode    = NightModeService.instance;
  final _intelligence = LocationIntelligenceService.instance;

  // ── Status ─────────────────────────────────────────────────
  LocationStatus _status           = LocationStatus.initial;
  LocationData?  _current;
  bool   _isSharing               = false;
  bool   _loading                 = false;
  String? _error;

  // ── Journey ────────────────────────────────────────────────
  JourneyData?   _journey;
  bool   _journeyLoading          = false;
  TravelMode _selectedTravelMode  = TravelMode.walking;
  DateTime? _journeyBecameOverdueAt;

  // ── Threats & Escalation ───────────────────────────────────
  JourneyThreatEvent? _latestThreat;
  bool _threatDismissed            = false;
  bool _awaitingSafeConfirmation   = false;
  Timer? _autoSosEscalationTimer;

  // ── Location data ──────────────────────────────────────────
  DangerZone?        _nearbyDangerZone;
  List<DangerZone>   _allDangerZones  = [];
  List<SafePlace>    _nearbyPlaces    = [];
  bool   _placesLoading             = false;
  RiskScore?         _currentRisk;

  // ── Route ──────────────────────────────────────────────────
  RouteInfo? _currentRoute;
  bool   _routeLoading              = false;
  String? _routeDestination;

  // ── Contacts ───────────────────────────────────────────────
  Map<String, ContactLocation> _contactLocations = {};
  SpeedAlertData?  _latestSpeedAlert;

  // ── Geofence ───────────────────────────────────────────────
  List<GeofenceZone> _geofenceZones = [];
  GeofenceEvent?   _lastGeofenceEvent;
  String?          _lastGeofenceZoneName;
  bool   _backgroundTrackingActive  = false;

  // Singleton Lock
  bool   _initCalled               = false;
  bool   _isNightMode              = false;

  // ── Subscriptions ──────────────────────────────────────────
  StreamSubscription? _locationSub;
  StreamSubscription? _dangerSub;
  StreamSubscription? _journeySub;
  StreamSubscription? _contactSub;
  StreamSubscription? _speedSub;
  StreamSubscription? _geofenceSub;
  StreamSubscription? _threatSub;
  StreamSubscription? _nightModeSub;

  // ── Getters ────────────────────────────────────────────────
  LocationStatus get status              => _status;
  LocationData?  get current             => _current;
  bool get isSharing                     => _isSharing;
  bool get isLoading                     => _loading;
  String? get error                      => _error;
  JourneyData?   get journey             => _journey;
  bool get isJourneyActive               => _journey?.isActive == true;
  bool get isJourneyOverdue              => _journey?.isOverdue == true;
  bool get journeyLoading                => _journeyLoading;
  TravelMode get selectedTravelMode      => _selectedTravelMode;
  DangerZone? get nearbyDangerZone       => _nearbyDangerZone;
  List<DangerZone> get allDangerZones    => _allDangerZones;
  List<SafePlace>  get nearbyPlaces      => _nearbyPlaces;
  bool get placesLoading                 => _placesLoading;
  RouteInfo? get currentRoute            => _currentRoute;
  bool get routeLoading                  => _routeLoading;
  String? get routeDestination           => _routeDestination;
  Map<String, ContactLocation> get contactLocations => _contactLocations;
  SpeedAlertData? get latestSpeedAlert   => _latestSpeedAlert;
  List<GeofenceZone> get geofenceZones   => _geofenceZones;
  GeofenceEvent?  get lastGeofenceEvent  => _lastGeofenceEvent;
  String? get lastGeofenceZoneName       => _lastGeofenceZoneName;
  bool get backgroundTrackingActive      => _backgroundTrackingActive;
  TravelMode get detectedTravelMode      => _service.currentTravelMode;
  bool get isNightMode                   => _nightMode.isNightMode;
  JourneyThreatEvent? get latestThreat   => _threatDismissed ? null : _latestThreat;
  bool get awaitingSafeConfirmation      => _awaitingSafeConfirmation;
  RiskScore? get currentRisk             => _currentRisk;
  MonitorState get monitorState          => _monitor.state;

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION (LOCKED)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> init() async {
    if (_initCalled) return;

    _initCalled = true;
    _status  = LocationStatus.loading;
    _loading = true;
    notifyListeners();

    await _service.initializeServices();
    await _notif.init();
    await _nightMode.init();

    _geofenceZones = GeofenceService.instance.zones;

    _startStreams();

    final loc = await _service.getCurrentLocation();
    if (loc != null) {
      _current = loc;
      _status  = LocationStatus.tracking;
      unawaited(loadNearbyPlaces());
      unawaited(_loadAllDangerZones());
      unawaited(_loadRiskScore(loc));
    } else {
      _status = LocationStatus.error;
      _error  = 'Location permission denied or GPS unavailable';
    }

    _loading = false;
    notifyListeners();
  }

  void _startStreams() {
    _locationSub?.cancel();
    _locationSub = _service.locationStream.listen((loc) {
      _current = loc;
      _status  = LocationStatus.tracking;
      _loading = false;
      _monitor.processLocation(loc);
      notifyListeners();
    }, onError: (e) {
      _status  = LocationStatus.error;
      _error   = 'Location unavailable — check GPS permissions';
      _loading = false;
      notifyListeners();
    });

    _dangerSub?.cancel();
    _dangerSub = _service.dangerZoneStream.listen((zone) {
      final isNew = _nearbyDangerZone == null && zone != null;
      _nearbyDangerZone = zone;
      notifyListeners();

      if (isNew && zone != null) {
        if (_current != null) {
          _monitor.onDangerZoneEntered(location: _current!, sosCount: zone.sosCount);
        }
        unawaited(_notif.showDangerZoneNearby(sosReportCount: zone.sosCount, distanceMeters: 0));
      }
    });

    _journeySub?.cancel();
    _journeySub = _service.journeyStream.listen((j) {
      final wasOverdue = _journey?.isOverdue ?? false;
      if (j != null && j.isOverdue && !wasOverdue) {
        _journeyBecameOverdueAt = DateTime.now();
      } else if (j == null || !j.isOverdue) {
        _journeyBecameOverdueAt = null;
      }

      _journey = j;
      notifyListeners();

      if (j != null && j.isOverdue && !wasOverdue) {
        final mins = _journeyBecameOverdueAt != null
            ? DateTime.now().difference(_journeyBecameOverdueAt!).inMinutes
            : 1;
        unawaited(_notif.showJourneyOverdue(destination: j.destinationName, overdueMinutes: mins > 0 ? mins : 1));
      }
    });

    _contactSub?.cancel();
    _contactSub = _service.contactLocationStream.listen((contacts) {
      _contactLocations = contacts;
      notifyListeners();
    });

    _speedSub?.cancel();
    _speedSub = _service.speedAlertStream.listen((alert) {
      _latestSpeedAlert = alert;

      if (alert.type == SpeedAlert.vehicleSpeed && !_isSharing && (_isNightMode || isJourneyActive)) {
        startSharing();
      }
      notifyListeners();
    });

    _geofenceSub?.cancel();
    _geofenceSub = _service.geofenceStream.listen((event) {
      final zone     = event['zone'] as GeofenceZone?;
      final eventStr = event['event'] as String?;

      if (zone != null && eventStr != null) {
        _lastGeofenceZoneName = zone.name;
        _lastGeofenceEvent    = eventStr == 'entered' ? GeofenceEvent.entered : GeofenceEvent.exited;

        if (eventStr == 'exited') {
          unawaited(_notif.showGeofenceExited(zoneName: zone.name));
        } else {
          unawaited(_notif.showGeofenceEntered(zoneName: zone.name));
        }

        if (event['action'] == 'start_sharing') {
          startSharing();
        }

        if (event['action'] == 'stop_sharing') {
          stopSharing();
        }
      }
      notifyListeners();
    });

    _threatSub?.cancel();
    _threatSub = _monitor.threatStream.listen((threat) {
      _latestThreat     = threat;
      _threatDismissed  = false;

      if (threat.severity >= 0.9) {
        _awaitingSafeConfirmation = true;
        notifyListeners();

        unawaited(_notif.showSosSentToContacts(contactsReached: 0, totalContacts: 0, address: _current?.address ?? ''));

        if (threat.metadata['autoTriggered'] == true) {
          _triggerAutoSos(threat);
        } else {
          _startEscalationTimer(threat);
        }
      } else {
        notifyListeners();
      }
    });

    _nightModeSub?.cancel();
    _nightModeSub = _nightMode.eventStream.listen((event) {
      _isNightMode = _nightMode.isNightMode;
      _monitor.setNightMode(_isNightMode);
      notifyListeners();

      if (event.type == NightAlert.nightModeActivated && _nightMode.autoSharingEnabled) {
        startSharing();
      }

      if (event.type == NightAlert.lateNightCheckIn) {
        _awaitingSafeConfirmation = true;
        notifyListeners();

        if (_current != null) {
          _startEscalationTimer(JourneyThreatEvent(
              type: JourneyThreat.routeDeviation,
              location: _current!,
              severity: 1.0,
              timestamp: DateTime.now(),
              message: "Late Night Check-in Missed",
              metadata: {}
          ));
        }
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // THREAT ESCALATION & AUTO-SOS
  // ═══════════════════════════════════════════════════════════════════════════

  void _startEscalationTimer(JourneyThreatEvent threat) {
    _autoSosEscalationTimer?.cancel();
    _autoSosEscalationTimer = Timer(const Duration(seconds: 15), () {
      if (_awaitingSafeConfirmation) {
        debugPrint('🚨 [LOCATION PROVIDER] User Unresponsive. Escalating to SOS.');
        _triggerAutoSos(threat);
      }
    });
  }

  Future<void> _triggerAutoSos(JourneyThreatEvent threat) async {
    _autoSosEscalationTimer?.cancel();

    if (_current != null) {
      await _intelligence.recordIncident(
        lat:  _current!.lat,
        lng:  _current!.lng,
        type: threat.type.name,
      );
    }

    SosService.instance.updateDangerScore(1.0);
    await SosService.instance.triggerSilentSOS(
        triggerType: 'auto_ml_monitor'
    );

    _awaitingSafeConfirmation = false;
    notifyListeners();
  }

  Future<void> confirmSafe() async {
    _autoSosEscalationTimer?.cancel();
    await _monitor.confirmSafe();

    _awaitingSafeConfirmation = false;
    _latestThreat             = null;
    _threatDismissed          = true;
    notifyListeners();
  }

  void dismissThreat() {
    _threatDismissed = true;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INTELLIGENCE & SHARING
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _loadRiskScore(LocationData loc) async {
    try {
      final report = await _intelligence.generateReport(lat: loc.lat, lng: loc.lng, nearbyPlaces: _nearbyPlaces);
      _currentRisk = report.riskScore;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> startSharing() async {
    _isSharing = true;
    notifyListeners();

    await _service.startLiveTracking(shareToFirebase: true);
    _backgroundTrackingActive = BackgroundLocationService.instance.isRunning;
    _isSharing                = _service.isSharingLive;

    notifyListeners();
    unawaited(_notif.showLocationSharingOn(contactsCount: 0));
  }

  Future<void> stopSharing() async {
    await _service.stopLiveTracking();

    _isSharing                = false;
    _backgroundTrackingActive = false;

    notifyListeners();
    unawaited(_notif.showLocationSharingOff());
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // JOURNEY & ROUTING
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> planRoute({required double toLat, required double toLng, required String destinationName, TravelMode? mode}) async {
    if (_current == null) return;

    _routeLoading = true;
    _routeDestination = destinationName;
    _currentRoute = null;
    notifyListeners();

    _currentRoute = await _service.getSafeRoute(
      fromLat: _current!.lat, fromLng: _current!.lng,
      toLat: toLat, toLng: toLng, mode: mode ?? _selectedTravelMode,
    );

    _routeLoading = false;
    notifyListeners();
  }

  void clearRoute() {
    _currentRoute = null;
    _routeDestination = null;
    notifyListeners();
  }

  void setTravelMode(TravelMode mode) {
    _selectedTravelMode = mode;
    notifyListeners();
  }

  Future<JourneyData?> startJourney({required String destinationName, required double destLat, required double destLng, required int estimatedMinutes, int contactsCount = 0}) async {
    _journeyLoading = true;
    _journeyBecameOverdueAt = null;
    notifyListeners();

    try {
      final j = await _service.startJourney(
        destinationName: destinationName, destLat: destLat, destLng: destLng,
        estimatedMinutes: estimatedMinutes, mode: _selectedTravelMode,
      );

      _journey = j;
      _isSharing = true;
      _backgroundTrackingActive = true;

      final routePoints = _currentRoute?.polylinePoints.map((p) => LocationData(
        lat: p.lat, lng: p.lng, accuracy: 0, speed: 0, heading: 0, altitude: 0,
        address: '', timestamp: DateTime.now(),
      )).toList() ?? [];

      await _monitor.startMonitoring(journey: j, plannedRoute: routePoints, nightMode: _isNightMode);

      if (j != null) {
        unawaited(_notif.showJourneyStarted(destination: destinationName, estimatedMinutes: estimatedMinutes, contactsCount: contactsCount));
      }
      return j;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _journeyLoading = false;
      notifyListeners();
    }
  }

  Future<void> endJourney({bool arrived = true}) async {
    final destination = _journey?.destinationName ?? 'destination';
    await _monitor.stopMonitoring();
    await _service.endJourney(arrived: arrived);

    _journey = null;
    _journeyBecameOverdueAt = null;
    _isSharing = false;
    _backgroundTrackingActive = false;
    notifyListeners();

    if (arrived) {
      unawaited(_notif.showJourneyArrived(destination: destination));
    } else {
      unawaited(_notif.showJourneyCancelled(destination: destination));
    }

    unawaited(_notif.dismissJourneyAll());
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SAFE PLACES & ZONES
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<DangerZone>> loadDangerZones() async {
    _allDangerZones = await _service.loadDangerZones();
    notifyListeners();
    return _allDangerZones;
  }

  Future<void> _loadAllDangerZones() async {
    _allDangerZones = await _service.loadDangerZones();
    notifyListeners();
  }

  Future<void> reportDangerZone() async {
    if (_current == null) return;

    await _service.reportDangerZone(_current!.lat, _current!.lng);
    await _intelligence.recordIncident(lat: _current!.lat, lng: _current!.lng, type: 'manual_report');
    await _loadAllDangerZones();

    unawaited(_notif.showDangerZoneReported());
  }

  // ✅ FIXED: UI Filtering added. Allows the UI to specifically request police, hospital, etc.
  Future<void> loadNearbyPlaces({bool forceRefresh = false, String? filterType}) async {
    if (_current == null) return;

    _placesLoading = true;
    notifyListeners();

    List<SafePlace> allPlaces = await _service.getNearbyPlaces(
        lat: _current!.lat,
        lng: _current!.lng,
        forceRefresh: forceRefresh
    );

    if (filterType != null && filterType != 'safe') {
      _nearbyPlaces = allPlaces.where((p) => p.type == filterType).toList();
    } else {
      _nearbyPlaces = allPlaces;
    }

    _placesLoading = false;
    unawaited(_loadRiskScore(_current!));
    notifyListeners();
  }

  Future<void> addGeofenceZone(GeofenceZone zone) async {
    await GeofenceService.instance.saveZone(zone);
    _geofenceZones = GeofenceService.instance.zones;
    notifyListeners();
  }

  Future<void> deleteGeofenceZone(String id) async {
    await GeofenceService.instance.deleteZone(id);
    _geofenceZones = GeofenceService.instance.zones;
    notifyListeners();
  }

  void setHomeAsGeofence() {
    if (_current == null) return;

    addGeofenceZone(GeofenceZone(
      id: 'home_${DateTime.now().millisecondsSinceEpoch}', name: 'Home',
      lat: _current!.lat, lng: _current!.lng, radiusMeters: 150,
      isHome: true, autoSharingStart: const TimeOfDay(hour: 22, minute: 0),
    ));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CLEANUP & UTILS
  // ═══════════════════════════════════════════════════════════════════════════

  void clearSpeedAlert() {
    _latestSpeedAlert = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    final loc = await _service.getCurrentLocation();
    if (loc != null) {
      _current = loc;
      notifyListeners();
      await loadNearbyPlaces();
      await _loadRiskScore(loc);
    }
  }

  Future<LatLngPoint?> geocode(String address) => _service.geocodeAddress(address);

  @override
  void dispose() {
    _locationSub?.cancel();
    _dangerSub?.cancel();
    _journeySub?.cancel();
    _contactSub?.cancel();
    _speedSub?.cancel();
    _geofenceSub?.cancel();
    _threatSub?.cancel();
    _nightModeSub?.cancel();
    _autoSosEscalationTimer?.cancel();

    _monitor.dispose();
    _nightMode.dispose();
    super.dispose();
  }
}

void unawaited(Future<void> future) =>
    future.catchError((e) => debugPrint('⚠️ [LOCATION UNAWAITED ERROR]: $e'));