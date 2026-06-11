// lib/features/location/screens/location_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// LOCATION SCREEN — Full Advanced Location System
// ✅ Zero Material Icons — all CustomPainter
// ✅ All withValues(alpha:) — zero withOpacity()
// ✅ No animate_do — pure Flutter animations
// ✅ Dark theme 100% matched to home/sos screens
// ✅ 5 tabs: Live Map · Journey · Route · Safety · Geofence
// ✅ Full Google Maps API integration
// ✅ Auto-alert contacts on danger detection
// ✅ Real GPS trail, geofencing, threat alerts
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../providers/location_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/location_service.dart';
import '../widgets/threat_alert_widget.dart';

// ═══════════════════════════════════════════════════════════════════════
// LOCATION SCREEN ROOT
// ═══════════════════════════════════════════════════════════════════════

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen>
    with TickerProviderStateMixin {

  late TabController _tabCtrl;
  late AnimationController _entryCtrl;
  late AnimationController _bgCtrl;
  late Animation<double> _entryFade;

  GoogleMapController? _mapController;
  MapType _mapType = MapType.normal;
  bool _followUser = true;
  Set<Polyline> _polylines = {};
  Set<Circle>  _dangerCircles  = {};
  Set<Circle>  _geofenceCircles = {};
  Set<Marker>  _routeSafeMarkers = {};
  RouteInfo?   _lastRenderedRoute;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entryCtrl.forward();

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<LocationProvider>();
      await provider.init();
      if (mounted) _refreshMapOverlays(provider);
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _entryCtrl.dispose();
    _bgCtrl.dispose();
    final ctrl = _mapController;
    _mapController = null;
    ctrl?.dispose();
    super.dispose();
  }

  void _refreshMapOverlays(LocationProvider provider) async {
    if (!mounted) return;
    final zones = await provider.loadDangerZones();
    final dCircles = <Circle>{};
    for (final z in zones) {
      dCircles.add(Circle(
        circleId: CircleId('danger_${z.id}'),
        center: LatLng(z.lat, z.lng),
        radius: z.radiusMeters,
        fillColor: AppColors.sosRed.withValues(alpha: 0.12),
        strokeColor: AppColors.sosRed.withValues(alpha: 0.50),
        strokeWidth: 2,
      ));
    }
    final gCircles = <Circle>{};
    for (final g in provider.geofenceZones) {
      gCircles.add(Circle(
        circleId: CircleId('geo_${g.id}'),
        center: LatLng(g.lat, g.lng),
        radius: g.radiusMeters,
        fillColor: AppColors.safeGreen.withValues(alpha: 0.10),
        strokeColor: AppColors.safeGreen.withValues(alpha: 0.45),
        strokeWidth: 2,
      ));
    }
    if (mounted) setState(() { _dangerCircles = dCircles; _geofenceCircles = gCircles; });
  }

  void _animateCamera(double lat, double lng, {double zoom = 16}) {
    if (!_followUser || _mapController == null || !mounted) return;
    try {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(lat, lng), zoom: zoom),
        ),
      );
    } catch (_) {}
  }

  void _updateRouteOnMap(RouteInfo route) {
    if (!mounted) return;
    final safeMarkers = <Marker>{};
    for (final p in route.safePlacesAlongRoute) {
      final hue = p.type == 'police'
          ? BitmapDescriptor.hueBlue
          : p.type == 'hospital'
          ? BitmapDescriptor.hueGreen
          : BitmapDescriptor.hueCyan;
      safeMarkers.add(Marker(
        markerId: MarkerId('route_${p.id}'),
        position: LatLng(p.lat, p.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(title: p.name, snippet: p.address),
      ));
    }
    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('safe_route'),
          points: route.polylinePoints.map((p) => LatLng(p.lat, p.lng)).toList(),
          color: AppColors.secondary,
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      };
      _routeSafeMarkers = safeMarkers;
    });
    if (route.polylinePoints.isNotEmpty && _mapController != null) {
      try {
        double minLat = route.polylinePoints.map((p) => p.lat).reduce(math.min);
        double maxLat = route.polylinePoints.map((p) => p.lat).reduce(math.max);
        double minLng = route.polylinePoints.map((p) => p.lng).reduce(math.min);
        double maxLng = route.polylinePoints.map((p) => p.lng).reduce(math.max);
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(minLat - 0.005, minLng - 0.005),
              northeast: LatLng(maxLat + 0.005, maxLng + 0.005),
            ),
            60,
          ),
        );
      } catch (_) {}
    }
  }

  Set<Marker> _buildAllMarkers(LocationProvider provider) {
    final markers = <Marker>{};
    final loc = provider.current;
    if (loc != null) {
      markers.add(Marker(
        markerId: const MarkerId('user'),
        position: LatLng(loc.lat, loc.lng),
        infoWindow: InfoWindow(title: '📍 You', snippet: loc.address),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
        zIndex: 3,
        rotation: loc.heading,
      ));
    }
    for (final entry in provider.contactLocations.entries) {
      final c = entry.value;
      markers.add(Marker(
        markerId: MarkerId('contact_${entry.key}'),
        position: LatLng(c.location.lat, c.location.lng),
        infoWindow: InfoWindow(title: c.name, snippet: '${c.location.speed.toStringAsFixed(0)} km/h'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        zIndex: 2,
      ));
    }
    for (final p in provider.nearbyPlaces) {
      final hue = p.type == 'police' ? BitmapDescriptor.hueBlue
          : p.type == 'hospital' ? BitmapDescriptor.hueGreen
          : BitmapDescriptor.hueCyan;
      markers.add(Marker(
        markerId: MarkerId('place_${p.id}'),
        position: LatLng(p.lat, p.lng),
        infoWindow: InfoWindow(title: p.name, snippet: p.address),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        zIndex: 1,
      ));
    }
    markers.addAll(_routeSafeMarkers);
    if (provider.isJourneyActive && provider.journey != null) {
      markers.add(Marker(
        markerId: const MarkerId('dest'),
        position: LatLng(provider.journey!.destLat, provider.journey!.destLng),
        infoWindow: InfoWindow(title: '🏁 ${provider.journey!.destinationName}'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        zIndex: 4,
      ));
    }
    return markers;
  }

  Set<Circle> _buildAllCircles(LocationProvider provider) {
    final circles = <Circle>{};
    circles.addAll(_dangerCircles);
    circles.addAll(_geofenceCircles);
    final loc = provider.current;
    if (loc != null) {
      circles.add(Circle(
        circleId: const CircleId('accuracy'),
        center: LatLng(loc.lat, loc.lng),
        radius: loc.accuracy.clamp(5, 100),
        fillColor: AppColors.primary.withValues(alpha: 0.06),
        strokeColor: AppColors.primary.withValues(alpha: 0.20),
        strokeWidth: 1,
      ));
    }
    return circles;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          _buildBackground(size),
          SafeArea(
            child: FadeTransition(
              opacity: _entryFade,
              child: Consumer<LocationProvider>(
                builder: (_, provider, __) {
                  final loc = provider.current;
                  if (loc != null && _followUser) {
                    WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _animateCamera(loc.lat, loc.lng));
                  }
                  if (provider.currentRoute != null &&
                      provider.currentRoute != _lastRenderedRoute) {
                    _lastRenderedRoute = provider.currentRoute;
                    WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _updateRouteOnMap(provider.currentRoute!));
                  }
                  return Column(
                    children: [
                      _buildHeader(provider),
                      _buildAlertBanners(provider),
                      _buildTabBar(),
                      Expanded(
                        child: TabBarView(
                          controller: _tabCtrl,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _LiveMapTab(
                              provider: provider,
                              mapController: _mapController,
                              onMapCreated: (c) {
                                if (mounted) setState(() => _mapController = c);
                              },
                              mapType: _mapType,
                              onMapTypeChange: (t) => setState(() => _mapType = t),
                              polylines: _polylines,
                              allCircles: _buildAllCircles(provider),
                              allMarkers: _buildAllMarkers(provider),
                              followUser: _followUser,
                              onFollowToggle: () => setState(() => _followUser = !_followUser),
                              onClearRoute: () {
                                provider.clearRoute();
                                setState(() {
                                  _polylines = {};
                                  _routeSafeMarkers = {};
                                  _lastRenderedRoute = null;
                                });
                              },
                            ),
                            _JourneyTab(provider: provider),
                            _RouteTab(
                              provider: provider,
                              onRoutePlanned: (route) {
                                _tabCtrl.animateTo(0);
                                _updateRouteOnMap(route);
                              },
                            ),
                            _SafePlacesTab(provider: provider),
                            _GeofenceTab(
                              provider: provider,
                              onZoneAdded: () => _refreshMapOverlays(provider),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(Size size) {
    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (_, __) {
        final t = _bgCtrl.value;
        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF060614), Color(0xFF0E0E20)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              top: -size.height * 0.05 + t * 20,
              right: -size.width * 0.15,
              child: Container(
                width: size.width * 0.60,
                height: size.width * 0.60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppColors.secondary.withValues(alpha: 0.05 + t * 0.03),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(LocationProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Location',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: provider.isSharing
                            ? AppColors.safeGreen
                            : provider.isJourneyActive
                            ? AppColors.warningAmber
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      provider.isJourneyActive
                          ? '🚗 Journey Active'
                          : provider.isSharing
                          ? '● Live Sharing'
                          : '○ GPS Ready',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: provider.isSharing
                            ? AppColors.safeGreen
                            : Colors.white.withValues(alpha: 0.40),
                      ),
                    ),
                    if (provider.detectedTravelMode != TravelMode.walking) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          provider.detectedTravelMode == TravelMode.driving
                              ? '🚗 Driving'
                              : '🚌 Transit',
                          style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 9,
                            color: AppColors.secondary, fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Map type toggle
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _mapType = _mapType == MapType.normal
                  ? MapType.satellite
                  : MapType.normal);
            },
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(20, 20),
                  painter: _mapType == MapType.normal
                      ? _SatellitePainter()
                      : _MapPainter(color: AppColors.primary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Share toggle
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              if (provider.isSharing) {
                provider.stopSharing();
              } else {
                provider.startSharing();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: provider.isSharing
                    ? AppColors.sosGradient
                    : AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (provider.isSharing ? AppColors.sosRed : AppColors.primary)
                        .withValues(alpha: 0.35),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                CustomPaint(
                  size: const Size(14, 14),
                  painter: provider.isSharing
                      ? _StopPainter()
                      : _ShareLocationPainter(color: Colors.white),
                ),
                const SizedBox(width: 5),
                Text(
                  provider.isSharing ? 'Stop' : 'Share',
                  style: const TextStyle(
                    color: Colors.white, fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700, fontSize: 12,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBanners(LocationProvider provider) {
    return Column(
      children: [
        if (provider.nearbyDangerZone != null)
          _AlertBanner(
            painter: _WarningPainter(color: Colors.white),
            color: AppColors.sosRed,
            text: '⚠️ Danger zone! ${provider.nearbyDangerZone!.sosCount} incidents reported.',
          ),
        if (provider.isJourneyOverdue)
          _AlertBanner(
            painter: _TimerAlertPainter(),
            color: AppColors.sosRed,
            text: 'Journey overdue! Confirm safe or SOS triggers automatically.',
            onTap: () => _showJourneyOverdueDialog(provider),
          ),
        if (provider.latestSpeedAlert != null)
          _AlertBanner(
            painter: _SpeedPainter(color: Colors.white),
            color: AppColors.warningAmber,
            text: provider.latestSpeedAlert!.message,
            onDismiss: provider.clearSpeedAlert,
          ),
        if (provider.latestThreat != null)
          ThreatAlertWidget(
            provider: provider,
            onSosTriggered: () => Navigator.pushNamed(context, '/sos'),
          ),
        if (provider.backgroundTrackingActive)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.safeGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.safeGreen.withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              CustomPaint(
                size: const Size(12, 12),
                painter: _BackgroundTrackPainter(),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Background tracking active — updates when screen is off',
                  style: TextStyle(
                    color: AppColors.safeGreen, fontFamily: 'Poppins',
                    fontSize: 10, fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ]),
          ),
      ],
    );
  }

  // ─── FIX: _buildTabBar ────────────────────────────────────────────────────
  // Root cause: Tab's internal Column (icon + SizedBox(2) + Text) was
  // overflowing the 46 px height Flutter allocates for tab content.
  // Fix: use a fixed 52 px tab bar height so the content has room, and
  // replace the manual Column with Tab(icon:, text:) so Flutter can size it
  // properly — OR keep the custom Column but wrap it in a tight SizedBox.
  // We use the SizedBox approach here to keep the exact same visual design.
  Widget _buildTabBar() {
    final tabs = [
      (_MapPainter(color: Colors.white), 'Live Map'),
      (_RoutePathPainter(color: Colors.white), 'Journey'),
      (_DirectionsPainter(color: Colors.white), 'Route'),
      (_ShieldSmallPainter(color: Colors.white), 'Safety'),
      (_HomePinPainter(color: Colors.white), 'Zones'),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      // ── FIX: give the tab bar enough height so its children never overflow ──
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: TabBar(
        controller: _tabCtrl,
        indicator: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(13),
        ),
        // ── FIX: remove indicator padding so it fills the bar correctly ──
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.38),
        labelStyle: const TextStyle(
            fontSize: 9, fontFamily: 'Poppins', fontWeight: FontWeight.w700),
        unselectedLabelStyle:
        const TextStyle(fontSize: 9, fontFamily: 'Poppins'),
        // ── FIX: zero out label padding so text doesn't push height further ──
        labelPadding: EdgeInsets.zero,
        tabs: tabs
            .map(
              (t) => SizedBox(
            height: 58,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,   // ← key fix
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomPaint(
                      size: const Size(15, 15), painter: t.$1),
                  const SizedBox(height: 2),
                  Text(t.$2),
                ],
              ),
            ),
          ),
        )
            .toList(),
      ),
    );
  }

  void _showJourneyOverdueDialog(LocationProvider provider) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.sosRed.withValues(alpha: 0.30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: AppColors.sosRed.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: CustomPaint(size: const Size(28, 28), painter: _WarningPainter(color: AppColors.sosRed)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Journey Overdue!',
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800,
                      fontSize: 18, color: AppColors.sosRed)),
              const SizedBox(height: 8),
              Text(
                "You haven't reached ${provider.journey?.destinationName ?? 'your destination'} yet. Your contacts have been notified.",
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.55), height: 1.5),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      provider.endJourney(arrived: true);
                    },
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.safeGreen,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Text('I Arrived Safely',
                            style: TextStyle(color: Colors.white,
                                fontFamily: 'Poppins', fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/sos');
                    },
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.sosRed,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Text('Trigger SOS',
                            style: TextStyle(color: Colors.white,
                                fontFamily: 'Poppins', fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// TAB 1: LIVE MAP
// ═══════════════════════════════════════════════════════════════════════

class _LiveMapTab extends StatelessWidget {
  final LocationProvider provider;
  final GoogleMapController? mapController;
  final void Function(GoogleMapController) onMapCreated;
  final MapType mapType;
  final void Function(MapType) onMapTypeChange;
  final Set<Polyline> polylines;
  final Set<Circle> allCircles;
  final Set<Marker> allMarkers;
  final bool followUser;
  final VoidCallback onFollowToggle;
  final VoidCallback onClearRoute;

  const _LiveMapTab({
    required this.provider,
    required this.mapController,
    required this.onMapCreated,
    required this.mapType,
    required this.onMapTypeChange,
    required this.polylines,
    required this.allCircles,
    required this.allMarkers,
    required this.followUser,
    required this.onFollowToggle,
    required this.onClearRoute,
  });

  @override
  Widget build(BuildContext context) {
    final loc = provider.current;
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            clipBehavior: Clip.antiAlias,
            child: loc == null
                ? _LoadingMap()
                : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                      target: LatLng(loc.lat, loc.lng), zoom: 15.5),
                  onMapCreated: onMapCreated,
                  mapType: mapType,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: true,
                  tiltGesturesEnabled: true,
                  rotateGesturesEnabled: true,
                  markers: allMarkers,
                  polylines: polylines,
                  circles: allCircles,
                ),
                // Map controls
                Positioned(
                  top: 12, right: 12,
                  child: Column(children: [
                    _MapControlBtn(
                      painter: followUser
                          ? _GpsCrosshairPainter(color: AppColors.primary)
                          : _GpsCrosshairPainter(color: Colors.grey),
                      onTap: onFollowToggle,
                    ),
                    const SizedBox(height: 8),
                    if (polylines.isNotEmpty)
                      _MapControlBtn(
                        painter: _ClosePainter(color: AppColors.sosRed),
                        onTap: onClearRoute,
                      ),
                  ]),
                ),
                // Bottom address bar
                Positioned(
                  bottom: 12, left: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: AppColors.darkCard.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                    ),
                    child: Row(children: [
                      CustomPaint(
                        size: const Size(13, 13),
                        painter: _LocationDotPainter(color: AppColors.primary),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(loc.address,
                            style: const TextStyle(fontFamily: 'Poppins',
                                fontSize: 11, fontWeight: FontWeight.w500,
                                color: Colors.white),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (provider.isSharing) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.safeGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('● LIVE',
                              style: TextStyle(color: AppColors.safeGreen,
                                  fontSize: 9, fontWeight: FontWeight.w800,
                                  fontFamily: 'Poppins')),
                        ),
                      ],
                    ]),
                  ),
                ),
                // LIVE badge
                if (provider.isSharing)
                  Positioned(
                    top: 12, left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.sosRed.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 6, height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text('LIVE TRACKING',
                            style: TextStyle(color: Colors.white,
                                fontFamily: 'Poppins', fontSize: 9,
                                fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Stats row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            _StatChip(
              painter: _SpeedPainter(color: AppColors.secondary),
              value: loc != null ? '${loc.speed.toStringAsFixed(1)}' : '--',
              label: 'km/h',
              color: AppColors.secondary,
            ),
            const SizedBox(width: 6),
            _StatChip(
              painter: _GpsCrosshairPainter(color: AppColors.safeGreen),
              value: loc != null ? '±${loc.accuracy.toStringAsFixed(0)}m' : '--',
              label: 'accuracy',
              color: AppColors.safeGreen,
            ),
            const SizedBox(width: 6),
            _StatChip(
              painter: _PeopleSmallPainter(color: AppColors.primary),
              value: '${provider.contactLocations.length}',
              label: 'contacts',
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            _StatChip(
              painter: _WarningPainter(color: AppColors.sosRed),
              value: '${provider.allDangerZones.length}',
              label: 'zones',
              color: AppColors.sosRed,
            ),
          ]),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// TAB 2: JOURNEY MODE
// ═══════════════════════════════════════════════════════════════════════

class _JourneyTab extends StatefulWidget {
  final LocationProvider provider;
  const _JourneyTab({required this.provider});
  @override
  State<_JourneyTab> createState() => _JourneyTabState();
}

class _JourneyTabState extends State<_JourneyTab> {
  final _destCtrl = TextEditingController();
  final _timeCtrl = TextEditingController(text: '30');
  bool _searching = false;
  LatLngPoint? _destPoint;

  @override
  void dispose() {
    _destCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchDest() async {
    if (_destCtrl.text.trim().isEmpty) return;
    setState(() => _searching = true);
    _destPoint = await widget.provider.geocode(_destCtrl.text.trim());
    if (!mounted) return;
    setState(() => _searching = false);
    if (_destPoint == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Location not found. Try a specific address.',
            style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: AppColors.warningAmber,
      ));
    }
  }

  Future<void> _startJourney() async {
    if (_destPoint == null) await _searchDest();
    if (_destPoint == null) return;
    final mins = int.tryParse(_timeCtrl.text) ?? 30;
    final j = await widget.provider.startJourney(
      destinationName: _destCtrl.text.trim(),
      destLat: _destPoint!.lat,
      destLng: _destPoint!.lng,
      estimatedMinutes: mins,
    );
    if (j != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Journey started! Auto-alert if not arrived in ${mins + 10} min.',
            style: const TextStyle(fontFamily: 'Poppins')),
        backgroundColor: AppColors.safeGreen,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;
    if (p.isJourneyActive && p.journey != null) {
      return _ActiveJourneyView(provider: p);
    }
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppColors.primaryShadow,
          ),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: CustomPaint(size: const Size(24, 24), painter: _RoutePathPainter(color: Colors.white)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Journey Mode', style: TextStyle(
                  color: Colors.white, fontFamily: 'Poppins',
                  fontWeight: FontWeight.w800, fontSize: 16)),
              Text('Set destination + time. Auto-SOS if overdue.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75),
                      fontFamily: 'Poppins', fontSize: 11)),
            ])),
          ]),
        ),
        const SizedBox(height: 14),

        // Travel mode
        _GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Travel Mode', style: TextStyle(fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
              const SizedBox(height: 10),
              Row(children: [
                _TravelModeBtn(
                  painter: _WalkPainter(color: Colors.white),
                  label: 'Walk',
                  selected: p.selectedTravelMode == TravelMode.walking,
                  onTap: () => p.setTravelMode(TravelMode.walking),
                ),
                const SizedBox(width: 8),
                _TravelModeBtn(
                  painter: _BusPainter(color: Colors.white),
                  label: 'Transit',
                  selected: p.selectedTravelMode == TravelMode.transit,
                  onTap: () => p.setTravelMode(TravelMode.transit),
                ),
                const SizedBox(width: 8),
                _TravelModeBtn(
                  painter: _CarPainter(color: Colors.white),
                  label: 'Drive',
                  selected: p.selectedTravelMode == TravelMode.driving,
                  onTap: () => p.setTravelMode(TravelMode.driving),
                ),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 10),

        // Destination
        _GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Destination', style: TextStyle(fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: _DarkTextField(
                    ctrl: _destCtrl,
                    hint: 'Enter destination...',
                    prefixPainter: _SearchIconPainter(color: AppColors.primary),
                    onSubmitted: (_) => _searchDest(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _searching ? null : _searchDest,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _searching
                        ? const Center(child: SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                        : Center(child: CustomPaint(size: const Size(18, 18),
                        painter: _SearchIconPainter(color: Colors.white))),
                  ),
                ),
              ]),
              if (_destPoint != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.safeGreen.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.safeGreen.withValues(alpha: 0.25)),
                  ),
                  child: Row(children: [
                    CustomPaint(size: const Size(12, 12), painter: _CheckCircleSmallPainter(color: AppColors.safeGreen)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_destPoint!.lat.toStringAsFixed(4)}, ${_destPoint!.lng.toStringAsFixed(4)}',
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.safeGreen),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => widget.provider.planRoute(
                        toLat: _destPoint!.lat, toLng: _destPoint!.lng,
                        destinationName: _destCtrl.text, mode: p.selectedTravelMode,
                      ),
                      child: Text('View Route →',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
                              color: AppColors.secondary, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 10),

        // Time
        _GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Estimated Time', style: TextStyle(fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
              const SizedBox(height: 8),
              _DarkTextField(
                ctrl: _timeCtrl,
                hint: 'Minutes',
                suffixText: 'min',
                keyboardType: TextInputType.number,
                prefixPainter: _TimerPainter(color: AppColors.secondary),
              ),
              const SizedBox(height: 10),
              Row(
                children: [15, 30, 45, 60].map((m) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: GestureDetector(
                      onTap: () => setState(() => _timeCtrl.text = '$m'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          gradient: _timeCtrl.text == '$m' ? AppColors.primaryGradient : null,
                          color: _timeCtrl.text == '$m' ? null : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _timeCtrl.text == '$m'
                                ? Colors.transparent
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Text('${m}m', textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _timeCtrl.text == '$m' ? Colors.white : Colors.grey)),
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // Start button
        GestureDetector(
          onTap: p.journeyLoading ? null : _startJourney,
          child: Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppColors.primaryShadow,
            ),
            child: p.journeyLoading
                ? const Center(child: SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              CustomPaint(size: const Size(20, 20), painter: _PlayPainter()),
              const SizedBox(width: 10),
              const Text('Start Journey', style: TextStyle(
                color: Colors.white, fontFamily: 'Poppins',
                fontWeight: FontWeight.w800, fontSize: 16,
              )),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ─── Active Journey View ─────────────────────────────────────────────────────

class _ActiveJourneyView extends StatefulWidget {
  final LocationProvider provider;
  const _ActiveJourneyView({required this.provider});
  @override
  State<_ActiveJourneyView> createState() => _ActiveJourneyViewState();
}

class _ActiveJourneyViewState extends State<_ActiveJourneyView> {
  late Timer _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final j = widget.provider.journey!;
    final now = DateTime.now();
    final total = j.expectedArrival.difference(j.startTime).inSeconds;
    final elapsed = now.difference(j.startTime).inSeconds;
    final progress = (elapsed / total).clamp(0.0, 1.0);
    final eta = j.expectedArrival.difference(now);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: j.isOverdue ? AppColors.sosGradient : AppColors.safeGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                CustomPaint(
                  size: const Size(20, 20),
                  painter: j.isOverdue ? _WarningPainter(color: Colors.white)
                      : _RoutePathPainter(color: Colors.white),
                ),
                const SizedBox(width: 8),
                Text(j.isOverdue ? '⚠️ Journey Overdue' : '🚗 Journey Active',
                    style: const TextStyle(color: Colors.white, fontFamily: 'Poppins',
                        fontWeight: FontWeight.w800, fontSize: 15)),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('● LIVE', style: TextStyle(color: Colors.white,
                    fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 10),
            Text(j.destinationName, style: const TextStyle(color: Colors.white,
                fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 3),
            Text(eta.isNegative
                ? 'Overdue by ${eta.abs().inMinutes} min'
                : '${eta.inMinutes} min remaining',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.80),
                    fontFamily: 'Poppins', fontSize: 12)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
                minHeight: 7,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          _InfoStatCard(label: 'Breadcrumbs', value: '${j.breadcrumbs.length}',
              painter: _LocationDotPainter(color: AppColors.primary), color: AppColors.primary),
          const SizedBox(width: 8),
          _InfoStatCard(label: 'Mode', value: j.travelMode.name,
              painter: _DirectionsPainter(color: AppColors.secondary), color: AppColors.secondary),
          const SizedBox(width: 8),
          _InfoStatCard(label: 'Sharing', value: '● Live',
              painter: _ShareLocationPainter(color: AppColors.safeGreen), color: AppColors.safeGreen),
        ]),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () async {
            final r = await _showEndJourneyDialog(context);
            if (r == true) await widget.provider.endJourney(arrived: true);
            if (r == false) {
              await widget.provider.endJourney(arrived: false);
              if (context.mounted) Navigator.pushNamed(context, '/sos');
            }
          },
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppColors.sosGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(
                color: AppColors.sosRed.withValues(alpha: 0.35),
                blurRadius: 14, offset: const Offset(0, 5),
              )],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              CustomPaint(size: const Size(18, 18), painter: _FlagPainter()),
              const SizedBox(width: 8),
              const Text('End Journey', style: TextStyle(color: Colors.white,
                  fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 15)),
            ]),
          ),
        ),
      ]),
    );
  }

  Future<bool?> _showEndJourneyDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('End Journey?', style: TextStyle(fontFamily: 'Poppins',
                fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pop(context, true),
              child: Container(width: double.infinity, height: 46,
                  decoration: BoxDecoration(color: AppColors.safeGreen, borderRadius: BorderRadius.circular(14)),
                  child: const Center(child: Text('Arrived Safely ✓',
                      style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w800)))),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => Navigator.pop(context, false),
              child: Container(width: double.infinity, height: 46,
                  decoration: BoxDecoration(color: AppColors.sosRed, borderRadius: BorderRadius.circular(14)),
                  child: const Center(child: Text('Need Help 🚨',
                      style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w800)))),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => Navigator.pop(context, null),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontFamily: 'Poppins')),
            ),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// TAB 3: ROUTE PLANNER
// ═══════════════════════════════════════════════════════════════════════

class _RouteTab extends StatefulWidget {
  final LocationProvider provider;
  final void Function(RouteInfo) onRoutePlanned;
  const _RouteTab({required this.provider, required this.onRoutePlanned});
  @override
  State<_RouteTab> createState() => _RouteTabState();
}

class _RouteTabState extends State<_RouteTab> {
  final _destCtrl = TextEditingController();
  bool _searching = false;
  LatLngPoint? _destPoint;

  @override
  void dispose() { _destCtrl.dispose(); super.dispose(); }

  Future<void> _planRoute() async {
    if (_destCtrl.text.trim().isEmpty) return;
    setState(() => _searching = true);
    _destPoint = await widget.provider.geocode(_destCtrl.text.trim());
    if (_destPoint == null) {
      if (mounted) {
        setState(() => _searching = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Location not found', style: TextStyle(fontFamily: 'Poppins')),
          backgroundColor: AppColors.warningAmber,
        ));
      }
      return;
    }
    await widget.provider.planRoute(
      toLat: _destPoint!.lat, toLng: _destPoint!.lng,
      destinationName: _destCtrl.text.trim(),
      mode: widget.provider.selectedTravelMode,
    );
    if (!mounted) return;
    setState(() => _searching = false);
    if (widget.provider.currentRoute != null) {
      widget.onRoutePlanned(widget.provider.currentRoute!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;
    final route = p.currentRoute;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF42A5F5)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(child: CustomPaint(size: const Size(22, 22),
                  painter: _DirectionsPainter(color: Colors.white))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Safe Route Planner', style: TextStyle(color: Colors.white,
                  fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 15)),
              Text('Real roads via Google Directions API',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.72),
                      fontFamily: 'Poppins', fontSize: 11)),
            ])),
          ]),
        ),
        const SizedBox(height: 12),

        // Travel mode
        _GlassCard(child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Travel Mode', style: TextStyle(fontFamily: 'Poppins',
                fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
            const SizedBox(height: 8),
            Row(children: [
              _TravelModeBtn(painter: _WalkPainter(color: Colors.white), label: 'Walk',
                  selected: p.selectedTravelMode == TravelMode.walking,
                  onTap: () => p.setTravelMode(TravelMode.walking)),
              const SizedBox(width: 8),
              _TravelModeBtn(painter: _BusPainter(color: Colors.white), label: 'Transit',
                  selected: p.selectedTravelMode == TravelMode.transit,
                  onTap: () => p.setTravelMode(TravelMode.transit)),
              const SizedBox(width: 8),
              _TravelModeBtn(painter: _CarPainter(color: Colors.white), label: 'Drive',
                  selected: p.selectedTravelMode == TravelMode.driving,
                  onTap: () => p.setTravelMode(TravelMode.driving)),
            ]),
          ]),
        )),
        const SizedBox(height: 10),

        // Destination
        _GlassCard(child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Enter Destination', style: TextStyle(fontFamily: 'Poppins',
                fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _DarkTextField(ctrl: _destCtrl, hint: 'e.g. Airport, Hospital...',
                  prefixPainter: _SearchIconPainter(color: AppColors.primary),
                  onSubmitted: (_) => _planRoute())),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _searching ? null : _planRoute,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12)),
                  child: _searching
                      ? const Center(child: SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                      : Center(child: CustomPaint(size: const Size(18, 18),
                      painter: _DirectionsPainter(color: Colors.white))),
                ),
              ),
            ]),
          ]),
        )),
        const SizedBox(height: 10),

        if (p.routeLoading)
          _GlassCard(child: const Padding(padding: EdgeInsets.all(24),
              child: Center(child: Column(children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 12),
                Text('Getting safe route...', style: TextStyle(fontFamily: 'Poppins',
                    fontSize: 13, color: Colors.white70)),
              ]))))
        else if (route != null)
          _GlassCard(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CustomPaint(size: const Size(18, 18), painter: _RoutePathPainter(color: AppColors.primary)),
                const SizedBox(width: 8),
                Expanded(child: Text(p.routeDestination ?? 'Destination',
                    style: const TextStyle(fontFamily: 'Poppins',
                        fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                GestureDetector(
                  onTap: p.clearRoute,
                  child: CustomPaint(size: const Size(16, 16), painter: _ClosePainter(color: Colors.grey)),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _RouteStatChip(painter: _DistancePainter(color: AppColors.primary),
                    value: route.distanceText, label: 'Distance', color: AppColors.primary),
                const SizedBox(width: 8),
                _RouteStatChip(painter: _TimerPainter(color: AppColors.secondary),
                    value: route.durationText, label: 'Duration', color: AppColors.secondary),
                const SizedBox(width: 8),
                _RouteStatChip(
                  painter: route.travelMode == TravelMode.walking ? _WalkPainter(color: AppColors.safeGreen)
                      : route.travelMode == TravelMode.transit ? _BusPainter(color: AppColors.safeGreen)
                      : _CarPainter(color: AppColors.safeGreen),
                  value: route.travelMode.name, label: 'Mode', color: AppColors.safeGreen,
                ),
              ]),
              if (route.dangerZonesOnRoute.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.sosRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.sosRed.withValues(alpha: 0.20)),
                  ),
                  child: Row(children: [
                    CustomPaint(size: const Size(16, 16), painter: _WarningPainter(color: AppColors.sosRed)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      '${route.dangerZonesOnRoute.length} danger zone(s) on this route. Stay alert!',
                      style: const TextStyle(color: AppColors.sosRed,
                          fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600),
                    )),
                  ]),
                ),
              ],
              if (route.safePlacesAlongRoute.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('Safe Places on Route:', style: TextStyle(fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700, fontSize: 12, color: Colors.white)),
                const SizedBox(height: 6),
                ...route.safePlacesAlongRoute.take(3).map((pl) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    CustomPaint(
                      size: const Size(14, 14),
                      painter: pl.type == 'police'
                          ? _PoliceBadgePainter(color: AppColors.secondary)
                          : _HospitalCrossPainter(color: AppColors.safeGreen),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(pl.name, style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 12, color: Colors.white))),
                    Text('${(pl.distanceKm * 1000).toStringAsFixed(0)}m',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
                            color: pl.type == 'police' ? AppColors.secondary : AppColors.safeGreen,
                            fontWeight: FontWeight.w700)),
                  ]),
                )),
              ],
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  if (_destPoint == null) return;
                  final uri = Uri.parse(
                    'https://www.google.com/maps/dir/?api=1&destination=${_destPoint!.lat},${_destPoint!.lng}&travelmode=${route.travelMode.name}',
                  );
                  if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                child: Container(
                  width: double.infinity,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    CustomPaint(size: const Size(15, 15), painter: _ExternalLinkPainter()),
                    const SizedBox(width: 8),
                    const Text('Open in Google Maps', style: TextStyle(
                      color: Colors.white, fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700, fontSize: 13,
                    )),
                  ]),
                ),
              ),
            ]),
          )),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// TAB 4: SAFE PLACES
// ═══════════════════════════════════════════════════════════════════════

class _SafePlacesTab extends StatelessWidget {
  final LocationProvider provider;
  const _SafePlacesTab({required this.provider});

  Color _placeColor(String type) => type == 'police'
      ? AppColors.secondary
      : type == 'hospital'
      ? AppColors.safeGreen
      : AppColors.warningAmber;

  CustomPainter _placePainter(String type, Color c) => type == 'police'
      ? _PoliceBadgePainter(color: c)
      : type == 'hospital'
      ? _HospitalCrossPainter(color: c)
      : _ShieldSmallPainter(color: c);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => provider.loadNearbyPlaces(forceRefresh: true),
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF42A5F5)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(child: CustomPaint(size: const Size(22, 22),
                    painter: _ShieldSmallPainter(color: Colors.white))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Nearby Safety', style: TextStyle(color: Colors.white,
                    fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 15)),
                Text('Police, hospitals & shelters near you',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.72),
                        fontFamily: 'Poppins', fontSize: 11)),
              ])),
              Text('↓ Refresh', style: TextStyle(color: Colors.white.withValues(alpha: 0.55),
                  fontFamily: 'Poppins', fontSize: 10)),
            ]),
          ),
          const SizedBox(height: 12),

          if (provider.placesLoading)
            ...List.generate(3, (_) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(18),
                  )),
            ))
          else if (provider.nearbyPlaces.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(children: [
                CustomPaint(size: const Size(48, 48),
                    painter: _LocationOffPainter(color: Colors.grey.withValues(alpha: 0.35))),
                const SizedBox(height: 12),
                const Text('No places found nearby',
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: Colors.white70)),
                const SizedBox(height: 4),
                const Text('Pull to refresh', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.grey)),
              ]),
            )
          else
            ...provider.nearbyPlaces.asMap().entries.map((entry) {
              final i = entry.key;
              final p = entry.value;
              final color = _placeColor(p.type);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: color.withValues(alpha: 0.18)),
                ),
                child: Row(children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14)),
                    child: Center(child: CustomPaint(size: const Size(22, 22),
                        painter: _placePainter(p.type, color))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.name, style: const TextStyle(fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
                    Text(p.address.isEmpty ? 'Tap directions for address' : p.address,
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.40)),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        p.distanceKm < 1
                            ? '${(p.distanceKm * 1000).toStringAsFixed(0)}m away'
                            : '${p.distanceKm.toStringAsFixed(1)}km away',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 10,
                            fontWeight: FontWeight.w700, color: color),
                      ),
                    ),
                  ])),
                  Column(children: [
                    if (p.phone != null) ...[
                      GestureDetector(
                        onTap: () async {
                          final uri = Uri.parse('tel:${p.phone}');
                          if (await canLaunchUrl(uri)) launchUrl(uri);
                        },
                        child: Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.safeGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(child: CustomPaint(size: const Size(16, 16),
                              painter: _PhoneCallPainter(color: AppColors.safeGreen))),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    GestureDetector(
                      onTap: () async {
                        final uri = Uri.parse(
                            'https://www.google.com/maps/dir/?api=1&destination=${p.lat},${p.lng}&travelmode=walking');
                        if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
                      child: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(child: CustomPaint(size: const Size(16, 16),
                            painter: _NavigatePainter(color: AppColors.secondary))),
                      ),
                    ),
                  ]),
                ]),
              );
            }),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// TAB 5: GEOFENCE ZONES
// ═══════════════════════════════════════════════════════════════════════

class _GeofenceTab extends StatefulWidget {
  final LocationProvider provider;
  final VoidCallback onZoneAdded;
  const _GeofenceTab({required this.provider, required this.onZoneAdded});
  @override
  State<_GeofenceTab> createState() => _GeofenceTabState();
}

class _GeofenceTabState extends State<_GeofenceTab> {
  final _nameCtrl = TextEditingController();
  final _radiusCtrl = TextEditingController(text: '150');
  bool _isHome = false;
  bool _autoShare = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _radiusCtrl.dispose();
    super.dispose();
  }

  Future<void> _addZone() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter a zone name', style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: AppColors.warningAmber,
      ));
      return;
    }
    final loc = widget.provider.current;
    if (loc == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Waiting for GPS...', style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: AppColors.warningAmber,
      ));
      return;
    }
    final radius = double.tryParse(_radiusCtrl.text) ?? 150;
    final zone = GeofenceZone(
      id: const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      lat: loc.lat, lng: loc.lng,
      radiusMeters: radius,
      isHome: _isHome,
      autoSharingStart: _autoShare ? const TimeOfDay(hour: 22, minute: 0) : null,
    );
    await widget.provider.addGeofenceZone(zone);
    if (!mounted) return;
    _nameCtrl.clear();
    widget.onZoneAdded();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('"${zone.name}" zone added at your current location.',
          style: const TextStyle(fontFamily: 'Poppins')),
      backgroundColor: AppColors.safeGreen,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppColors.safeGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(child: CustomPaint(size: const Size(22, 22),
                  painter: _HomePinPainter(color: Colors.white))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Safe Zones', style: TextStyle(color: Colors.white,
                  fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 15)),
              Text('Auto-share when you leave home at night',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.72),
                      fontFamily: 'Poppins', fontSize: 11)),
            ])),
          ]),
        ),
        const SizedBox(height: 12),

        // Set home button
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            widget.provider.setHomeAsGeofence();
            widget.onZoneAdded();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('🏠 Home zone set! Auto-sharing after 10pm.',
                    style: TextStyle(fontFamily: 'Poppins')),
                backgroundColor: AppColors.safeGreen,
              ));
            }
          },
          child: Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppColors.primaryShadow,
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              CustomPaint(size: const Size(18, 18), painter: _HomePinPainter(color: Colors.white)),
              const SizedBox(width: 10),
              const Text('Set Current Location as Home', style: TextStyle(
                color: Colors.white, fontFamily: 'Poppins',
                fontWeight: FontWeight.w800, fontSize: 13,
              )),
            ]),
          ),
        ),
        const SizedBox(height: 14),

        // Add custom zone
        _GlassCard(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Add Custom Zone', style: TextStyle(fontFamily: 'Poppins',
                fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)),
            Text('Uses your current GPS location as the center',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.40))),
            const SizedBox(height: 12),
            _DarkTextField(ctrl: _nameCtrl, hint: 'Zone name (e.g. Office, College)',
                prefixPainter: _LabelPainter(color: AppColors.primary)),
            const SizedBox(height: 10),
            _DarkTextField(ctrl: _radiusCtrl, hint: 'Radius in meters',
                suffixText: 'meters', keyboardType: TextInputType.number,
                prefixPainter: _RadarPainter(color: AppColors.secondary)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _ToggleTile(
                label: '🏠 Mark as Home',
                value: _isHome,
                onChanged: (v) => setState(() => _isHome = v),
              )),
              const SizedBox(width: 8),
              Expanded(child: _ToggleTile(
                label: '📡 Auto-share night',
                value: _autoShare,
                onChanged: (v) => setState(() => _autoShare = v),
              )),
            ]),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _addZone,
              child: Container(
                width: double.infinity,
                height: 46,
                decoration: BoxDecoration(
                  gradient: AppColors.safeGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  CustomPaint(size: const Size(16, 16),
                      painter: _AddLocationPainter(color: Colors.white)),
                  const SizedBox(width: 8),
                  const Text('Add Zone at My Location', style: TextStyle(
                    color: Colors.white, fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700, fontSize: 13,
                  )),
                ]),
              ),
            ),
          ]),
        )),
        const SizedBox(height: 14),

        if (p.geofenceZones.isNotEmpty) ...[
          const Text('Active Zones', style: TextStyle(fontFamily: 'Poppins',
              fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)),
          const SizedBox(height: 8),
          ...p.geofenceZones.map((z) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: (z.isHome ? AppColors.primary : AppColors.safeGreen)
                  .withValues(alpha: 0.20)),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: (z.isHome ? AppColors.primary : AppColors.safeGreen).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: CustomPaint(size: const Size(20, 20),
                    painter: z.isHome
                        ? _HomePinPainter(color: AppColors.primary)
                        : _LocationDotPainter(color: AppColors.safeGreen))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(z.name, style: const TextStyle(fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (z.isHome) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6)),
                      child: const Text('HOME', style: TextStyle(fontFamily: 'Poppins',
                          fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    ),
                  ],
                ]),
                Text('${z.radiusMeters.toStringAsFixed(0)}m radius  •  ${z.lat.toStringAsFixed(4)}, ${z.lng.toStringAsFixed(4)}',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.38))),
                if (z.autoSharingStart != null)
                  Text('Auto-shares after ${z.autoSharingStart!.format(context)}',
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 10,
                          color: AppColors.warningAmber, fontWeight: FontWeight.w600)),
              ])),
              GestureDetector(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  await p.deleteGeofenceZone(z.id);
                  widget.onZoneAdded();
                },
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.sosRed.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: CustomPaint(size: const Size(16, 16),
                      painter: _DeletePainter(color: AppColors.sosRed))),
                ),
              ),
            ]),
          )),
        ] else
          Padding(
            padding: const EdgeInsets.all(30),
            child: Column(children: [
              CustomPaint(size: const Size(48, 48),
                  painter: _FencePainter(color: Colors.grey.withValues(alpha: 0.28))),
              const SizedBox(height: 10),
              const Text('No safe zones set', style: TextStyle(fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700, color: Colors.white70)),
              const SizedBox(height: 4),
              const Text('Set your home to get auto-safety alerts',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.grey)),
            ]),
          ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SHARED SMALL WIDGETS
// ═══════════════════════════════════════════════════════════════════════

class _AlertBanner extends StatelessWidget {
  final CustomPainter painter;
  final Color color;
  final String text;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const _AlertBanner({
    required this.painter,
    required this.color,
    required this.text,
    this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          CustomPaint(size: const Size(15, 15), painter: painter),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(
              color: Colors.white, fontFamily: 'Poppins',
              fontSize: 11, fontWeight: FontWeight.w600))),
          if (onDismiss != null)
            GestureDetector(onTap: onDismiss,
                child: CustomPaint(size: const Size(14, 14), painter: _ClosePainter(color: Colors.white))),
          if (onTap != null)
            CustomPaint(size: const Size(14, 14), painter: _ChevronRightPainter(color: Colors.white)),
        ]),
      ),
    );
  }
}

class _LoadingMap extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.darkCard,
      child: const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 14),
          Text('Getting your location...', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white70)),
          SizedBox(height: 6),
          Text('Allow location permission if prompted',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.grey)),
        ]),
      ),
    );
  }
}

class _MapControlBtn extends StatelessWidget {
  final CustomPainter painter;
  final VoidCallback onTap;
  const _MapControlBtn({required this.painter, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Center(child: CustomPaint(size: const Size(18, 18), painter: painter)),
    ),
  );
}

class _StatChip extends StatelessWidget {
  final CustomPainter painter;
  final String value, label;
  final Color color;
  const _StatChip({required this.painter, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CustomPaint(size: const Size(14, 14), painter: painter),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800,
              fontFamily: 'Poppins', fontSize: 12)),
          Text(label, style: const TextStyle(fontSize: 8, fontFamily: 'Poppins', color: Colors.grey)),
        ]),
      ),
    );
  }
}

class _InfoStatCard extends StatelessWidget {
  final String label, value;
  final CustomPainter painter;
  final Color color;
  const _InfoStatCard({required this.label, required this.value, required this.painter, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(children: [
        CustomPaint(size: const Size(16, 16), painter: painter),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800,
            fontFamily: 'Poppins', fontSize: 13)),
        Text(label, style: const TextStyle(fontSize: 9, fontFamily: 'Poppins', color: Colors.grey)),
      ]),
    ),
  );
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(20), child: child),
  );
}

class _TravelModeBtn extends StatelessWidget {
  final CustomPainter painter;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TravelModeBtn({required this.painter, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.primaryGradient : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CustomPaint(size: const Size(18, 18), painter: painter),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 10,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : Colors.grey)),
        ]),
      ),
    ),
  );
}

class _DarkTextField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final String? suffixText;
  final TextInputType? keyboardType;
  final CustomPainter? prefixPainter;
  final void Function(String)? onSubmitted;

  const _DarkTextField({
    required this.ctrl,
    required this.hint,
    this.suffixText,
    this.keyboardType,
    this.prefixPainter,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 12,
            color: Colors.white.withValues(alpha: 0.30)),
        suffixText: suffixText,
        suffixStyle: TextStyle(fontFamily: 'Poppins', color: Colors.white.withValues(alpha: 0.50)),
        prefixIcon: prefixPainter != null
            ? Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: CustomPaint(size: const Size(18, 18), painter: prefixPainter!),
        )
            : null,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
    );
  }
}

class _RouteStatChip extends StatelessWidget {
  final CustomPainter painter;
  final String value, label;
  final Color color;
  const _RouteStatChip({required this.painter, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(children: [
        CustomPaint(size: const Size(14, 14), painter: painter),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800,
            fontFamily: 'Poppins', fontSize: 11),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(label, style: const TextStyle(fontSize: 9, fontFamily: 'Poppins', color: Colors.grey)),
      ]),
    ),
  );
}

class _ToggleTile extends StatelessWidget {
  final String label;
  final bool value;
  final void Function(bool) onChanged;
  const _ToggleTile({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: value ? AppColors.primary.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: value ? AppColors.primary.withValues(alpha: 0.30) : Colors.white.withValues(alpha: 0.06),
      ),
    ),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(fontFamily: 'Poppins',
          fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white))),
      Switch.adaptive(value: value, onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          activeColor: AppColors.primary),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════
// ALL CUSTOM PAINTERS — ZERO MATERIAL ICONS
// ═══════════════════════════════════════════════════════════════════════

class _MapPainter extends CustomPainter {
  final Color color;
  const _MapPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(s.width * 0.50, 0);
    path.cubicTo(s.width * 0.18, 0, 0, s.height * 0.26, 0, s.height * 0.46);
    path.cubicTo(0, s.height * 0.66, s.width * 0.18, s.height * 0.80, s.width * 0.50, s.height);
    path.cubicTo(s.width * 0.82, s.height * 0.80, s.width, s.height * 0.66, s.width, s.height * 0.46);
    path.cubicTo(s.width, s.height * 0.26, s.width * 0.82, 0, s.width * 0.50, 0);
    path.close();
    canvas.drawPath(path, p);
    canvas.drawCircle(Offset(s.width / 2, s.height * 0.44), s.width * 0.15, Paint()..color = color);
  }
  @override
  bool shouldRepaint(_MapPainter o) => o.color != color;
}

class _SatellitePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.4..strokeCap = StrokeCap.round;
    canvas.drawRect(Rect.fromLTWH(s.width * 0.30, s.height * 0.30, s.width * 0.40, s.height * 0.40), p);
    canvas.drawLine(Offset(0, s.height * 0.50), Offset(s.width * 0.28, s.height * 0.50), p);
    canvas.drawLine(Offset(s.width * 0.72, s.height * 0.50), Offset(s.width, s.height * 0.50), p);
    canvas.drawRect(Rect.fromLTWH(s.width * 0.04, s.height * 0.38, s.width * 0.24, s.height * 0.24), p);
    canvas.drawRect(Rect.fromLTWH(s.width * 0.72, s.height * 0.38, s.width * 0.24, s.height * 0.24), p);
    canvas.drawLine(Offset(s.width * 0.50, 0), Offset(s.width * 0.50, s.height * 0.28), p);
    canvas.drawCircle(Offset(s.width * 0.50, s.height * 0.08), 2, Paint()..color = Colors.white);
  }
  @override
  bool shouldRepaint(_SatellitePainter o) => false;
}

class _RoutePathPainter extends CustomPainter {
  final Color color;
  const _RoutePathPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    final path = Path();
    path.moveTo(s.width * 0.10, s.height * 0.80);
    path.cubicTo(s.width * 0.10, s.height * 0.40, s.width * 0.90, s.height * 0.60, s.width * 0.90, s.height * 0.20);
    canvas.drawPath(path, p);
    canvas.drawCircle(Offset(s.width * 0.10, s.height * 0.80), 3, Paint()..color = color);
    canvas.drawCircle(Offset(s.width * 0.90, s.height * 0.20), 3, Paint()..color = color);
    canvas.drawCircle(Offset(s.width * 0.45, s.height * 0.58), 2, Paint()..color = color);
  }
  @override
  bool shouldRepaint(_RoutePathPainter o) => o.color != color;
}

class _DirectionsPainter extends CustomPainter {
  final Color color;
  const _DirectionsPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    canvas.drawLine(Offset(s.width * 0.10, s.height / 2), Offset(s.width * 0.80, s.height / 2), p);
    final head = Path();
    head.moveTo(s.width * 0.55, s.height * 0.24);
    head.lineTo(s.width * 0.80, s.height * 0.50);
    head.lineTo(s.width * 0.55, s.height * 0.76);
    canvas.drawPath(head, p);
    canvas.drawArc(Rect.fromLTWH(s.width * 0.02, s.height * 0.18, s.width * 0.44, s.height * 0.48),
        -math.pi * 0.5, math.pi * 0.5, false, p);
  }
  @override
  bool shouldRepaint(_DirectionsPainter o) => o.color != color;
}

class _ShieldSmallPainter extends CustomPainter {
  final Color color;
  const _ShieldSmallPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final path = Path();
    path.moveTo(s.width * 0.50, 0);
    path.lineTo(s.width, s.height * 0.22);
    path.cubicTo(s.width, s.height * 0.22, s.width * 0.98, s.height * 0.72, s.width * 0.50, s.height);
    path.cubicTo(s.width * 0.02, s.height * 0.72, 0, s.height * 0.22, 0, s.height * 0.22);
    path.close();
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4..strokeJoin = StrokeJoin.round);
    final check = Path();
    check.moveTo(s.width * 0.28, s.height * 0.52);
    check.lineTo(s.width * 0.44, s.height * 0.68);
    check.lineTo(s.width * 0.72, s.height * 0.36);
    canvas.drawPath(check, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
  }
  @override
  bool shouldRepaint(_ShieldSmallPainter o) => o.color != color;
}

class _HomePinPainter extends CustomPainter {
  final Color color;
  const _HomePinPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final roof = Path();
    roof.moveTo(0, s.height * 0.50);
    roof.lineTo(s.width * 0.50, 0);
    roof.lineTo(s.width, s.height * 0.50);
    canvas.drawPath(roof, p);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * 0.16, s.height * 0.50, s.width * 0.68, s.height * 0.46),
        const Radius.circular(2)), p);
    canvas.drawRect(Rect.fromLTWH(s.width * 0.37, s.height * 0.66, s.width * 0.26, s.height * 0.30),
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3);
  }
  @override
  bool shouldRepaint(_HomePinPainter o) => o.color != color;
}

class _GpsCrosshairPainter extends CustomPainter {
  final Color color;
  const _GpsCrosshairPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2;
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), s.width * 0.28, p);
    canvas.drawCircle(Offset(cx, cy), s.width * 0.08, Paint()..color = color);
    canvas.drawLine(Offset(cx, 0), Offset(cx, s.height * 0.20), p);
    canvas.drawLine(Offset(cx, s.height * 0.80), Offset(cx, s.height), p);
    canvas.drawLine(Offset(0, cy), Offset(s.width * 0.20, cy), p);
    canvas.drawLine(Offset(s.width * 0.80, cy), Offset(s.width, cy), p);
  }
  @override
  bool shouldRepaint(_GpsCrosshairPainter o) => o.color != color;
}

class _SpeedPainter extends CustomPainter {
  final Color color;
  const _SpeedPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3..strokeCap = StrokeCap.round;
    final cx = s.width / 2; final cy = s.height / 2;
    canvas.drawCircle(Offset(cx, cy), s.width * 0.46, p);
    canvas.drawLine(Offset(cx, cy), Offset(cx + s.width * 0.28, cy - s.height * 0.18), p);
  }
  @override
  bool shouldRepaint(_SpeedPainter o) => o.color != color;
}

class _PeopleSmallPainter extends CustomPainter {
  final Color color;
  const _PeopleSmallPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(s.width * 0.36, s.height * 0.28), s.width * 0.16, p);
    final b = Path();
    b.moveTo(0, s.height);
    b.quadraticBezierTo(0, s.height * 0.60, s.width * 0.36, s.height * 0.60);
    b.quadraticBezierTo(s.width * 0.68, s.height * 0.60, s.width * 0.68, s.height);
    canvas.drawPath(b, p);
  }
  @override
  bool shouldRepaint(_PeopleSmallPainter o) => o.color != color;
}

class _WarningPainter extends CustomPainter {
  final Color color;
  const _WarningPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final path = Path();
    path.moveTo(cx, s.height * 0.04);
    path.lineTo(s.width * 0.96, s.height * 0.94);
    path.lineTo(s.width * 0.04, s.height * 0.94);
    path.close();
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4..strokeJoin = StrokeJoin.round);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 1.5, s.height * 0.36, 3, s.height * 0.28), const Radius.circular(1.5)),
        Paint()..color = color);
    canvas.drawCircle(Offset(cx, s.height * 0.78), 2.5, Paint()..color = color);
  }
  @override
  bool shouldRepaint(_WarningPainter o) => o.color != color;
}

class _TimerAlertPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2;
    final p = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.4..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), s.width * 0.44, p);
    canvas.drawLine(Offset(cx, cy * 0.40), Offset(cx, cy), p);
    canvas.drawLine(Offset(cx, cy), Offset(cx + s.width * 0.22, cy + s.height * 0.14), p);
  }
  @override
  bool shouldRepaint(_TimerAlertPainter o) => false;
}

class _BackgroundTrackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = AppColors.safeGreen..style = PaintingStyle.stroke..strokeWidth = 1.3..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(s.width / 2, s.height / 2), s.width * 0.44, p);
    canvas.drawLine(Offset(s.width / 2, s.height * 0.15), Offset(s.width / 2, s.height / 2), p);
    canvas.drawCircle(Offset(s.width / 2, s.height / 2), s.width * 0.08, Paint()..color = AppColors.safeGreen);
  }
  @override
  bool shouldRepaint(_BackgroundTrackPainter o) => false;
}

class _ShareLocationPainter extends CustomPainter {
  final Color color;
  const _ShareLocationPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4..strokeCap = StrokeCap.round;
    final path = Path();
    path.moveTo(s.width * 0.50, 0);
    path.cubicTo(s.width * 0.18, 0, 0, s.height * 0.26, 0, s.height * 0.46);
    path.cubicTo(0, s.height * 0.66, s.width * 0.18, s.height * 0.80, s.width * 0.50, s.height);
    path.cubicTo(s.width * 0.82, s.height * 0.80, s.width, s.height * 0.66, s.width, s.height * 0.46);
    path.cubicTo(s.width, s.height * 0.26, s.width * 0.82, 0, s.width * 0.50, 0);
    path.close();
    canvas.drawPath(path, p);
    for (int i = 1; i <= 2; i++) {
      canvas.drawArc(
          Rect.fromCenter(center: Offset(s.width * 0.50, s.height * 0.44),
              width: i * s.width * 0.18, height: i * s.height * 0.18),
          -math.pi, math.pi, false,
          Paint()..color = color.withValues(alpha: 0.6)..style = PaintingStyle.stroke..strokeWidth = 0.9..strokeCap = StrokeCap.round);
    }
  }
  @override
  bool shouldRepaint(_ShareLocationPainter o) => o.color != color;
}

class _StopPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * 0.20, s.height * 0.20, s.width * 0.60, s.height * 0.60),
        const Radius.circular(3)),
        Paint()..color = Colors.white);
  }
  @override
  bool shouldRepaint(_StopPainter o) => false;
}

class _ClosePainter extends CustomPainter {
  final Color color;
  const _ClosePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, 0), Offset(s.width, s.height), p);
    canvas.drawLine(Offset(s.width, 0), Offset(0, s.height), p);
  }
  @override
  bool shouldRepaint(_ClosePainter o) => o.color != color;
}

class _ChevronRightPainter extends CustomPainter {
  final Color color;
  const _ChevronRightPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(s.width * 0.25, s.height * 0.18);
    path.lineTo(s.width * 0.72, s.height * 0.50);
    path.lineTo(s.width * 0.25, s.height * 0.82);
    canvas.drawPath(path, p);
  }
  @override
  bool shouldRepaint(_ChevronRightPainter o) => o.color != color;
}

class _LocationDotPainter extends CustomPainter {
  final Color color;
  const _LocationDotPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4;
    final path = Path();
    path.moveTo(s.width * 0.50, 0);
    path.cubicTo(s.width * 0.18, 0, 0, s.height * 0.26, 0, s.height * 0.46);
    path.cubicTo(0, s.height * 0.66, s.width * 0.18, s.height * 0.80, s.width * 0.50, s.height);
    path.cubicTo(s.width * 0.82, s.height * 0.80, s.width, s.height * 0.66, s.width, s.height * 0.46);
    path.cubicTo(s.width, s.height * 0.26, s.width * 0.82, 0, s.width * 0.50, 0);
    path.close();
    canvas.drawPath(path, p);
    canvas.drawCircle(Offset(s.width / 2, s.height * 0.44), s.width * 0.14, Paint()..color = color);
  }
  @override
  bool shouldRepaint(_LocationDotPainter o) => o.color != color;
}

class _PlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final path = Path();
    path.moveTo(s.width * 0.20, 0);
    path.lineTo(s.width, s.height * 0.50);
    path.lineTo(s.width * 0.20, s.height);
    path.close();
    canvas.drawPath(path, Paint()..color = Colors.white..style = PaintingStyle.fill);
  }
  @override
  bool shouldRepaint(_PlayPainter o) => false;
}

class _FlagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(s.width * 0.20, s.height * 0.10), Offset(s.width * 0.20, s.height), p);
    final flag = Path();
    flag.moveTo(s.width * 0.20, s.height * 0.10);
    flag.lineTo(s.width * 0.90, s.height * 0.30);
    flag.lineTo(s.width * 0.20, s.height * 0.52);
    flag.close();
    canvas.drawPath(flag, Paint()..color = Colors.white.withValues(alpha: 0.80)..style = PaintingStyle.fill);
    canvas.drawPath(flag, p);
  }
  @override
  bool shouldRepaint(_FlagPainter o) => false;
}

class _SearchIconPainter extends CustomPainter {
  final Color color;
  const _SearchIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(s.width * 0.44, s.height * 0.44), s.width * 0.32, p);
    canvas.drawLine(Offset(s.width * 0.68, s.height * 0.68), Offset(s.width, s.height), p);
  }
  @override
  bool shouldRepaint(_SearchIconPainter o) => o.color != color;
}

class _TimerPainter extends CustomPainter {
  final Color color;
  const _TimerPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2;
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), s.width * 0.44, p);
    canvas.drawLine(Offset(cx, cy * 0.40), Offset(cx, cy), p);
    canvas.drawLine(Offset(cx, cy), Offset(cx + s.width * 0.22, cy + s.height * 0.14), p);
    canvas.drawLine(Offset(cx - s.width * 0.18, 0), Offset(cx + s.width * 0.18, 0),
        Paint()..color = color..strokeWidth = 1.4..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(_TimerPainter o) => o.color != color;
}

class _WalkPainter extends CustomPainter {
  final Color color;
  const _WalkPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    canvas.drawCircle(Offset(s.width * 0.60, s.height * 0.10), s.width * 0.11, Paint()..color = color);
    final body = Path();
    body.moveTo(s.width * 0.60, s.height * 0.22);
    body.lineTo(s.width * 0.52, s.height * 0.52);
    body.lineTo(s.width * 0.34, s.height * 0.72);
    body.moveTo(s.width * 0.52, s.height * 0.52);
    body.lineTo(s.width * 0.72, s.height * 0.72);
    body.moveTo(s.width * 0.40, s.height * 0.36);
    body.lineTo(s.width * 0.76, s.height * 0.30);
    canvas.drawPath(body, p);
  }
  @override
  bool shouldRepaint(_WalkPainter o) => o.color != color;
}

class _BusPainter extends CustomPainter {
  final Color color;
  const _BusPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * 0.06, s.height * 0.10, s.width * 0.88, s.height * 0.70),
        const Radius.circular(4)), p);
    canvas.drawLine(Offset(s.width * 0.06, s.height * 0.40), Offset(s.width * 0.94, s.height * 0.40), p);
    canvas.drawCircle(Offset(s.width * 0.28, s.height * 0.88), s.width * 0.10, p);
    canvas.drawCircle(Offset(s.width * 0.72, s.height * 0.88), s.width * 0.10, p);
    canvas.drawLine(Offset(0, s.height * 0.10), Offset(0, s.height * 0.80), p);
    canvas.drawLine(Offset(s.width, s.height * 0.10), Offset(s.width, s.height * 0.80), p);
  }
  @override
  bool shouldRepaint(_BusPainter o) => o.color != color;
}

class _CarPainter extends CustomPainter {
  final Color color;
  const _CarPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4..strokeJoin = StrokeJoin.round;
    final body = Path();
    body.moveTo(s.width * 0.04, s.height * 0.64);
    body.lineTo(s.width * 0.04, s.height * 0.44);
    body.lineTo(s.width * 0.24, s.height * 0.22);
    body.lineTo(s.width * 0.76, s.height * 0.22);
    body.lineTo(s.width * 0.96, s.height * 0.44);
    body.lineTo(s.width * 0.96, s.height * 0.64);
    body.close();
    canvas.drawPath(body, p);
    canvas.drawCircle(Offset(s.width * 0.26, s.height * 0.74), s.width * 0.12, p);
    canvas.drawCircle(Offset(s.width * 0.74, s.height * 0.74), s.width * 0.12, p);
  }
  @override
  bool shouldRepaint(_CarPainter o) => o.color != color;
}

class _PoliceBadgePainter extends CustomPainter {
  final Color color;
  const _PoliceBadgePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2;
    final r = s.width * 0.46;
    final badge = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i - math.pi / 6;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) badge.moveTo(x, y); else badge.lineTo(x, y);
    }
    badge.close();
    canvas.drawPath(badge, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4..strokeJoin = StrokeJoin.round);
    canvas.drawCircle(Offset(cx, cy), s.width * 0.14, Paint()..color = color);
  }
  @override
  bool shouldRepaint(_PoliceBadgePainter o) => o.color != color;
}

class _HospitalCrossPainter extends CustomPainter {
  final Color color;
  const _HospitalCrossPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, s.width, s.height), Radius.circular(s.width * 0.22)), p);
    canvas.drawLine(Offset(s.width * 0.50, s.height * 0.22), Offset(s.width * 0.50, s.height * 0.78),
        Paint()..color = color..strokeWidth = 2.0..strokeCap = StrokeCap.round);
    canvas.drawLine(Offset(s.width * 0.22, s.height * 0.50), Offset(s.width * 0.78, s.height * 0.50),
        Paint()..color = color..strokeWidth = 2.0..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(_HospitalCrossPainter o) => o.color != color;
}

class _DistancePainter extends CustomPainter {
  final Color color;
  const _DistancePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, s.height / 2), Offset(s.width, s.height / 2), p);
    canvas.drawLine(Offset(0, s.height * 0.28), Offset(0, s.height * 0.72), p);
    canvas.drawLine(Offset(s.width, s.height * 0.28), Offset(s.width, s.height * 0.72), p);
  }
  @override
  bool shouldRepaint(_DistancePainter o) => o.color != color;
}

class _ExternalLinkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.4..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, s.height * 0.26, s.width * 0.70, s.height * 0.74),
        const Radius.circular(2)), p);
    canvas.drawLine(Offset(s.width * 0.44, s.height * 0.56), Offset(s.width, 0), p);
    final arr = Path();
    arr.moveTo(s.width * 0.54, 0);
    arr.lineTo(s.width, 0);
    arr.lineTo(s.width, s.height * 0.46);
    canvas.drawPath(arr, p);
  }
  @override
  bool shouldRepaint(_ExternalLinkPainter o) => false;
}

class _PhoneCallPainter extends CustomPainter {
  final Color color;
  const _PhoneCallPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final phone = Path();
    phone.moveTo(s.width * 0.14, s.height * 0.10);
    phone.lineTo(s.width * 0.14, s.height * 0.32);
    phone.quadraticBezierTo(s.width * 0.14, s.height * 0.44, s.width * 0.22, s.height * 0.50);
    phone.quadraticBezierTo(s.width * 0.50, s.height * 0.78, s.width * 0.62, s.height * 0.86);
    phone.quadraticBezierTo(s.width * 0.68, s.height * 0.92, s.width * 0.80, s.height * 0.92);
    phone.lineTo(s.width * 0.90, s.height * 0.92);
    phone.quadraticBezierTo(s.width, s.height * 0.92, s.width, s.height * 0.80);
    phone.lineTo(s.width, s.height * 0.70);
    phone.quadraticBezierTo(s.width, s.height * 0.58, s.width * 0.88, s.height * 0.58);
    phone.lineTo(s.width * 0.78, s.height * 0.58);
    canvas.drawPath(phone, p);
  }
  @override
  bool shouldRepaint(_PhoneCallPainter o) => o.color != color;
}

class _NavigatePainter extends CustomPainter {
  final Color color;
  const _NavigatePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final path = Path();
    path.moveTo(s.width * 0.50, 0);
    path.lineTo(s.width, s.height * 0.70);
    path.lineTo(s.width * 0.50, s.height * 0.52);
    path.lineTo(0, s.height * 0.70);
    path.close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.20)..style = PaintingStyle.fill);
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4..strokeJoin = StrokeJoin.round);
  }
  @override
  bool shouldRepaint(_NavigatePainter o) => o.color != color;
}

class _LocationOffPainter extends CustomPainter {
  final Color color;
  const _LocationOffPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    final path = Path();
    path.moveTo(s.width * 0.50, 0);
    path.cubicTo(s.width * 0.18, 0, 0, s.height * 0.26, 0, s.height * 0.46);
    path.cubicTo(0, s.height * 0.66, s.width * 0.18, s.height * 0.80, s.width * 0.50, s.height);
    path.cubicTo(s.width * 0.82, s.height * 0.80, s.width, s.height * 0.66, s.width, s.height * 0.46);
    path.cubicTo(s.width, s.height * 0.26, s.width * 0.82, 0, s.width * 0.50, 0);
    path.close();
    canvas.drawPath(path, p);
    canvas.drawLine(Offset(s.width * 0.15, s.height * 0.15), Offset(s.width * 0.85, s.height * 0.85), p);
  }
  @override
  bool shouldRepaint(_LocationOffPainter o) => o.color != color;
}

class _CheckCircleSmallPainter extends CustomPainter {
  final Color color;
  const _CheckCircleSmallPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2; final r = s.width * 0.46;
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3);
    final check = Path();
    check.moveTo(cx - r * 0.42, cy);
    check.lineTo(cx - r * 0.08, cy + r * 0.40);
    check.lineTo(cx + r * 0.42, cy - r * 0.36);
    canvas.drawPath(check, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
  }
  @override
  bool shouldRepaint(_CheckCircleSmallPainter o) => o.color != color;
}

class _LabelPainter extends CustomPainter {
  final Color color;
  const _LabelPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * 0.08, s.height * 0.18, s.width * 0.84, s.height * 0.64),
        const Radius.circular(3)), p);
    canvas.drawLine(Offset(s.width * 0.08, s.height * 0.50), Offset(0, s.height * 0.50), p);
    canvas.drawCircle(Offset(0, s.height * 0.50), 2.5, Paint()..color = color);
  }
  @override
  bool shouldRepaint(_LabelPainter o) => o.color != color;
}

class _RadarPainter extends CustomPainter {
  final Color color;
  const _RadarPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2;
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3..strokeCap = StrokeCap.round;
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(Offset(cx, cy), s.width * (0.15 * i), p);
    }
    canvas.drawLine(Offset(cx, 0), Offset(cx, s.height), p);
    canvas.drawLine(Offset(0, cy), Offset(s.width, cy), p);
    canvas.drawLine(Offset(cx, cy), Offset(cx + s.width * 0.32, cy - s.height * 0.32),
        Paint()..color = color.withValues(alpha: 0.70)..strokeWidth = 1.5..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(_RadarPainter o) => o.color != color;
}

class _AddLocationPainter extends CustomPainter {
  final Color color;
  const _AddLocationPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    final pin = Path();
    pin.moveTo(s.width * 0.46, 0);
    pin.cubicTo(s.width * 0.14, 0, 0, s.height * 0.24, 0, s.height * 0.44);
    pin.cubicTo(0, s.height * 0.62, s.width * 0.14, s.height * 0.74, s.width * 0.46, s.height * 0.88);
    pin.cubicTo(s.width * 0.78, s.height * 0.74, s.width * 0.92, s.height * 0.62, s.width * 0.92, s.height * 0.44);
    pin.cubicTo(s.width * 0.92, s.height * 0.24, s.width * 0.78, 0, s.width * 0.46, 0);
    pin.close();
    canvas.drawPath(pin, p);
    canvas.drawLine(Offset(s.width * 0.90, s.height * 0.38), Offset(s.width * 0.90, s.height * 0.78), p);
    canvas.drawLine(Offset(s.width * 0.70, s.height * 0.58), Offset(s.width * 1.10, s.height * 0.58), p);
  }
  @override
  bool shouldRepaint(_AddLocationPainter o) => o.color != color;
}

class _DeletePainter extends CustomPainter {
  final Color color;
  const _DeletePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    canvas.drawLine(Offset(0, s.height * 0.20), Offset(s.width, s.height * 0.20), p);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * 0.14, s.height * 0.20, s.width * 0.72, s.height * 0.76),
        const Radius.circular(3)), p);
    canvas.drawLine(Offset(s.width * 0.40, s.height * 0.20), Offset(s.width * 0.40, 0),
        Paint()..color = color..strokeWidth = 1.4..strokeCap = StrokeCap.round);
    canvas.drawLine(Offset(s.width * 0.60, s.height * 0.20), Offset(s.width * 0.60, 0),
        Paint()..color = color..strokeWidth = 1.4..strokeCap = StrokeCap.round);
    canvas.drawLine(Offset(s.width * 0.40, 0), Offset(s.width * 0.60, 0),
        Paint()..color = color..strokeWidth = 1.4..strokeCap = StrokeCap.round);
    for (int i = 0; i < 3; i++) {
      canvas.drawLine(
          Offset(s.width * (0.32 + i * 0.18), s.height * 0.40),
          Offset(s.width * (0.32 + i * 0.18), s.height * 0.84), p);
    }
  }
  @override
  bool shouldRepaint(_DeletePainter o) => o.color != color;
}

class _FencePainter extends CustomPainter {
  final Color color;
  const _FencePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, s.height * 0.35), Offset(s.width, s.height * 0.35), p);
    canvas.drawLine(Offset(0, s.height * 0.65), Offset(s.width, s.height * 0.65), p);
    for (int i = 0; i <= 4; i++) {
      final x = s.width * (i / 4.0);
      canvas.drawLine(Offset(x, s.height * 0.08), Offset(x, s.height * 0.92), p);
    }
  }
  @override
  bool shouldRepaint(_FencePainter o) => o.color != color;
}