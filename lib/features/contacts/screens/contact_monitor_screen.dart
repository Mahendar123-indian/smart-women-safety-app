// lib/features/contacts/screens/contact_monitor_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../models/emergency_contact_model.dart';

class ContactMonitorScreen extends StatefulWidget {
  final EmergencyContact contact;
  final String trackedUid;

  const ContactMonitorScreen({
    super.key,
    required this.contact,
    required this.trackedUid,
  });

  @override
  State<ContactMonitorScreen> createState() => _ContactMonitorScreenState();
}

class _ContactMonitorScreenState extends State<ContactMonitorScreen>
    with TickerProviderStateMixin {

  static const _rtdbUrl =
      'https://smart-women-safety-app-b1988-default-rtdb.asia-southeast1.firebasedatabase.app';

  late final FirebaseDatabase _db;

  // ── Map ───────────────────────────────────────────────────────
  GoogleMapController? _mapCtrl;
  final List<LatLng>   _trail  = [];
  bool     _follow  = true;
  MapType  _mapType = MapType.normal;

  // ── Live data ─────────────────────────────────────────────────
  double?   _lat, _lng, _speed, _accuracy;
  String?   _address;
  int?      _battery;
  bool      _isSharing  = false;
  bool      _signalLost = false;
  bool      _sosActive  = false;
  double?   _dangerScore;
  String?   _journeyDest;
  DateTime? _lastUpdate;
  String    _statusLabel = 'Connecting...';

  // ── Subscriptions ─────────────────────────────────────────────
  StreamSubscription? _locSub;
  StreamSubscription? _alertSub;

  // ── Animations ────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late AnimationController _sosCtrl;
  late AnimationController _entryCtrl;
  late Animation<double>   _topBarFade;
  late Animation<Offset>   _topBarSlide;
  late Animation<double>   _panelFade;

  @override
  void initState() {
    super.initState();

    _db = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: _rtdbUrl,
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _sosCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..repeat(reverse: true);

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _topBarFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    _topBarSlide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    ));
    _panelFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );

    _entryCtrl.forward();
    _subscribe();
  }

  @override
  void dispose() {
    _locSub?.cancel();
    _alertSub?.cancel();
    _mapCtrl?.dispose();
    _pulseCtrl.dispose();
    _sosCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  // ── Subscribe to RTDB streams ─────────────────────────────────
  void _subscribe() {
    // Live location stream
    _locSub = _db
        .ref('users/${widget.trackedUid}/liveLocation')
        .onValue
        .listen(
          (ev) {
        if (!mounted) return;
        if (ev.snapshot.value == null) {
          setState(() {
            _isSharing  = false;
            _signalLost = true;
            _statusLabel = 'Offline';
          });
          return;
        }
        try {
          final d = Map<String, dynamic>.from(ev.snapshot.value as Map);
          final lat = (d['lat'] as num?)?.toDouble();
          final lng = (d['lng'] as num?)?.toDouble();
          if (lat == null || lng == null) return;

          setState(() {
            _lat         = lat;
            _lng         = lng;
            _speed       = (d['speed']    as num?)?.toDouble() ?? 0;
            _accuracy    = (d['accuracy'] as num?)?.toDouble() ?? 0;
            _address     = d['address']   as String?;
            _isSharing   = d['isSharing'] == true;
            _signalLost  = false;
            _lastUpdate  = DateTime.now();
            _statusLabel = _isSharing ? '● LIVE' : 'Last known';
            _battery     = (d['battery']  as int?) ?? _battery;
            _journeyDest = d['journeyDest'] as String?;
          });

          if (_trail.length > 500) _trail.removeAt(0);
          _trail.add(LatLng(lat, lng));

          if (_follow && _mapCtrl != null) {
            _mapCtrl!.animateCamera(
              CameraUpdate.newLatLng(LatLng(lat, lng)),
            );
          }
        } catch (e) {
          debugPrint('Monitor parse: $e');
        }
      },
      onError: (_) {
        if (mounted) {
          setState(() {
            _signalLost  = true;
            _statusLabel = 'Signal lost';
          });
        }
      },
    );

    // Active SOS alert
    _alertSub = _db
        .ref('users/${widget.trackedUid}/activeAlert')
        .onValue
        .listen((ev) {
      if (!mounted || ev.snapshot.value == null) return;
      try {
        final d = Map<String, dynamic>.from(ev.snapshot.value as Map);
        setState(() {
          _sosActive   = d['isActive'] == true;
          _dangerScore = (d['dangerScore'] as num?)?.toDouble();
        });
      } catch (_) {}
    });
  }

  // ── Helpers ───────────────────────────────────────────────────
  String _timeAgo() {
    if (_lastUpdate == null) return '--';
    final s = DateTime.now().difference(_lastUpdate!).inSeconds;
    if (s < 5)  return 'Just now';
    if (s < 60) return '${s}s ago';
    return '${DateTime.now().difference(_lastUpdate!).inMinutes}m ago';
  }

  String _speedLabel() {
    final s = _speed ?? 0;
    if (s < 1)  return 'Stationary';
    if (s < 8)  return 'Walking';
    if (s < 30) return 'Cycling';
    return 'Vehicle';
  }

  Color _speedColor() {
    final s = _speed ?? 0;
    if (s < 1)  return Colors.grey;
    if (s < 8)  return AppColors.safeGreen;
    if (s < 30) return AppColors.warningAmber;
    return AppColors.sosRed;
  }

  Set<Polyline> get _polylines {
    if (_trail.length < 2) return {};
    return {
      Polyline(
        polylineId: const PolylineId('trail'),
        points: _trail,
        color: _sosActive ? AppColors.sosRed : AppColors.primary,
        width: 4,
        patterns: [PatternItem.dot, PatternItem.gap(6)],
      ),
    };
  }

  Set<Marker> get _markers {
    if (_lat == null || _lng == null) return {};
    return {
      Marker(
        markerId: const MarkerId('tracked'),
        position: LatLng(_lat!, _lng!),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          _sosActive
              ? BitmapDescriptor.hueRed
              : BitmapDescriptor.hueViolet,
        ),
        infoWindow: InfoWindow(
          title: widget.contact.name,
          snippet: _address ?? 'Updating...',
        ),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          // ── Full screen map ──────────────────────────────────
          Positioned.fill(
            child: _lat == null ? _buildLoading() : _buildMap(),
          ),

          // ── SOS pulse overlay ────────────────────────────────
          if (_sosActive) _buildSosPulse(),

          // ── Top content ──────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                FadeTransition(
                  opacity: _topBarFade,
                  child: SlideTransition(
                    position: _topBarSlide,
                    child: _buildTopBar(),
                  ),
                ),
                if (_sosActive)   _buildSosBanner(),
                if (_signalLost)  _buildSignalBanner(),
                if (_journeyDest != null) _buildJourneyBanner(),
              ],
            ),
          ),

          // ── Map controls ─────────────────────────────────────
          Positioned(
            top: 140,
            right: 12,
            child: FadeTransition(
              opacity: _panelFade,
              child: Column(
                children: [
                  _MapControlBtn(
                    painter: _follow
                        ? _GpsFocusedPainter(color: AppColors.primary)
                        : _GpsSearchingPainter(
                        color: Colors.grey),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _follow = !_follow);
                    },
                  ),
                  const SizedBox(height: 8),
                  _MapControlBtn(
                    painter: _mapType == MapType.normal
                        ? _SatellitePainter(color: AppColors.secondary)
                        : _MapPainter(color: AppColors.secondary),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _mapType = _mapType == MapType.normal
                          ? MapType.satellite
                          : MapType.normal);
                    },
                  ),
                  const SizedBox(height: 8),
                  _MapControlBtn(
                    painter: _TrailClearPainter(
                        color: AppColors.warningAmber),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _trail.clear());
                    },
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom panel ─────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _panelFade,
              child: _buildBottomPanel(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Map ───────────────────────────────────────────────────────
  Widget _buildMap() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(_lat!, _lng!),
        zoom: 16,
      ),
      onMapCreated: (c) => setState(() => _mapCtrl = c),
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      mapType: _mapType,
      compassEnabled: true,
      markers: _markers,
      polylines: _polylines,
    );
  }

  Widget _buildLoading() {
    return Container(
      color: AppColors.darkBackground,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Connecting to live location...',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SOS pulse ─────────────────────────────────────────────────
  Widget _buildSosPulse() {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) => Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.sosRed
                    .withValues(alpha: 0.40 * (1 - _pulseCtrl.value)),
                width: 14 * _pulseCtrl.value,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.darkCard.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
            },
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(16, 16),
                  painter: _BackArrowPainter(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Avatar
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                widget.contact.name.isNotEmpty
                    ? widget.contact.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.contact.name,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, __) => Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isSharing
                              ? AppColors.safeGreen
                              : Colors.grey,
                          boxShadow: _isSharing
                              ? [
                            BoxShadow(
                              color: AppColors.safeGreen.withValues(
                                  alpha:
                                  0.6 * _pulseCtrl.value),
                              blurRadius: 6,
                            ),
                          ]
                              : [],
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$_statusLabel · ${_timeAgo()}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        color: _isSharing
                            ? AppColors.safeGreen
                            : Colors.white.withValues(alpha: 0.40),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Recenter
          GestureDetector(
            onTap: () {
              if (_lat != null) {
                HapticFeedback.selectionClick();
                _mapCtrl?.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                        target: LatLng(_lat!, _lng!), zoom: 16),
                  ),
                );
              }
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(18, 18),
                  painter: _GpsFocusedPainter(color: AppColors.primary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Banners ───────────────────────────────────────────────────
  Widget _buildSosBanner() {
    return AnimatedBuilder(
      animation: _sosCtrl,
      builder: (_, __) => Container(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Color.lerp(
            AppColors.sosRed,
            AppColors.sosRed.withValues(alpha: 0.70),
            _sosCtrl.value,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            CustomPaint(
              size: const Size(18, 18),
              painter: _WarningIconPainter(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🚨 SOS ACTIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  if (_dangerScore != null)
                    Text(
                      'AI Danger: ${(_dangerScore! * 100).toInt()}%',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontFamily: 'Poppins',
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _callPolice,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Call 100',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warningAmber.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CustomPaint(
            size: const Size(16, 16),
            painter: _SignalOffPainter(),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Signal lost — last known location shown',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CustomPaint(
            size: const Size(16, 16),
            painter: _WalkIconPainter(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Journey to $_journeyDest',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom panel ──────────────────────────────────────────────
  Widget _buildBottomPanel() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkCard.withValues(alpha: 0.97),
        borderRadius:
        const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Address
          if (_address != null)
            Row(
              children: [
                CustomPaint(
                  size: const Size(14, 14),
                  painter: _LocationPinSmallPainter(
                      color: AppColors.primary),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _address!,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),

          // Stats row
          Row(
            children: [
              _StatTileCard(
                painter: _SpeedIconPainter(color: _speedColor()),
                value: '${(_speed ?? 0).toStringAsFixed(0)} km/h',
                sub: _speedLabel(),
                color: _speedColor(),
              ),
              const SizedBox(width: 8),
              _StatTileCard(
                painter: _BatteryIconPainter(
                  color: _battery != null && _battery! < 20
                      ? AppColors.sosRed
                      : AppColors.safeGreen,
                ),
                value: _battery != null ? '$_battery%' : '--',
                sub: _battery != null
                    ? (_battery! > 30 ? 'OK' : 'LOW!')
                    : 'Unknown',
                color: _battery != null && _battery! < 20
                    ? AppColors.sosRed
                    : AppColors.safeGreen,
              ),
              const SizedBox(width: 8),
              _StatTileCard(
                painter: _GpsFocusedPainter(color: AppColors.secondary),
                value: _accuracy != null
                    ? '±${_accuracy!.toStringAsFixed(0)}m'
                    : '--',
                sub: 'accuracy',
                color: AppColors.secondary,
              ),
              const SizedBox(width: 8),
              _StatTileCard(
                painter:
                _TrailIconPainter(color: AppColors.primary),
                value: '${_trail.length}',
                sub: 'breadcrumbs',
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: _ActionBtn(
                  painter: _CallIconSmallPainter(
                      color: AppColors.safeGreen),
                  label: 'Call',
                  color: AppColors.safeGreen,
                  onTap: _callTracked,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionBtn(
                  painter: _NavigateIconPainter(
                      color: AppColors.secondary),
                  label: 'Navigate',
                  color: AppColors.secondary,
                  onTap: _navigateToTracked,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionBtn(
                  painter:
                  _ShareIconPainter(color: AppColors.primary),
                  label: 'Share',
                  color: AppColors.primary,
                  onTap: _shareLocation,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionBtn(
                  painter: _PoliceIconPainter(color: AppColors.sosRed),
                  label: 'Police',
                  color: AppColors.sosRed,
                  onTap: _callPolice,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Actions (all logic unchanged) ─────────────────────────────
  Future<void> _callTracked() async {
    HapticFeedback.mediumImpact();
    final uri = Uri.parse('tel:${widget.contact.phone}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _callPolice() async {
    HapticFeedback.heavyImpact();
    final uri = Uri.parse('tel:100');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _navigateToTracked() async {
    if (_lat == null) return;
    HapticFeedback.selectionClick();
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$_lat,$_lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareLocation() async {
    if (_lat == null) return;
    HapticFeedback.selectionClick();
    final text =
        '📍 ${widget.contact.name} is at: https://maps.google.com/?q=$_lat,$_lng';
    final uri =
    Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ════════════════════════════════════════════════════════════════
// SUB-WIDGETS
// ════════════════════════════════════════════════════════════════

class _MapControlBtn extends StatelessWidget {
  final CustomPainter painter;
  final VoidCallback onTap;
  const _MapControlBtn({required this.painter, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.darkCard.withValues(alpha: 0.95),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
            ),
          ],
        ),
        child: Center(
          child: CustomPaint(
            size: const Size(18, 18),
            painter: painter,
          ),
        ),
      ),
    );
  }
}

class _StatTileCard extends StatelessWidget {
  final CustomPainter painter;
  final String value;
  final String sub;
  final Color color;
  const _StatTileCard({
    required this.painter,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border:
          Border.all(color: color.withValues(alpha: 0.15), width: 1),
        ),
        child: Column(
          children: [
            CustomPaint(
              size: const Size(14, 14),
              painter: painter,
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
            Text(
              sub,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontFamily: 'Poppins',
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final CustomPainter painter;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.painter,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: 0.28),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            CustomPaint(
              size: const Size(20, 20),
              painter: painter,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PAINTERS — all custom, zero Material icons
// ════════════════════════════════════════════════════════════════

class _BackArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final cy = s.height / 2;
    canvas.drawLine(
        Offset(s.width * 0.78, cy), Offset(s.width * 0.22, cy), p);
    final head = Path();
    head.moveTo(s.width * 0.46, cy - s.height * 0.30);
    head.lineTo(s.width * 0.22, cy);
    head.lineTo(s.width * 0.46, cy + s.height * 0.30);
    canvas.drawPath(head, p);
  }

  @override
  bool shouldRepaint(_BackArrowPainter o) => false;
}

class _GpsFocusedPainter extends CustomPainter {
  final Color color;
  const _GpsFocusedPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), s.width * 0.32, p);
    canvas.drawCircle(Offset(cx, cy), s.width * 0.10,
        Paint()..color = color);
    canvas.drawLine(Offset(cx, 0), Offset(cx, s.height * 0.22), p);
    canvas.drawLine(
        Offset(cx, s.height * 0.78), Offset(cx, s.height), p);
    canvas.drawLine(Offset(0, cy), Offset(s.width * 0.22, cy), p);
    canvas.drawLine(
        Offset(s.width * 0.78, cy), Offset(s.width, cy), p);
  }

  @override
  bool shouldRepaint(_GpsFocusedPainter o) => o.color != color;
}

class _GpsSearchingPainter extends CustomPainter {
  final Color color;
  const _GpsSearchingPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (int i = 1; i <= 3; i++) {
      canvas.drawArc(
          Rect.fromCircle(
              center: Offset(s.width / 2, s.height / 2),
              radius: i * s.width * 0.15),
          -math.pi * 0.7, math.pi * 1.4, false, p);
    }
  }

  @override
  bool shouldRepaint(_GpsSearchingPainter o) => o.color != color;
}

class _SatellitePainter extends CustomPainter {
  final Color color;
  const _SatellitePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    // Body rect
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(
                s.width * 0.34, s.height * 0.34, s.width * 0.32, s.height * 0.32),
            const Radius.circular(2)),
        p);
    // Solar panels
    canvas.drawLine(Offset(s.width * 0.12, s.height * 0.38),
        Offset(s.width * 0.34, s.height * 0.38), p);
    canvas.drawLine(Offset(s.width * 0.66, s.height * 0.62),
        Offset(s.width * 0.88, s.height * 0.62), p);
    canvas.drawLine(Offset(s.width * 0.12, s.height * 0.48),
        Offset(s.width * 0.34, s.height * 0.48), p);
    canvas.drawLine(Offset(s.width * 0.66, s.height * 0.52),
        Offset(s.width * 0.88, s.height * 0.52), p);
  }

  @override
  bool shouldRepaint(_SatellitePainter o) => o.color != color;
}

class _MapPainter extends CustomPainter {
  final Color color;
  const _MapPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, s.width, s.height), const Radius.circular(3)),
        p);
    canvas.drawLine(
        Offset(s.width * 0.33, 0), Offset(s.width * 0.33, s.height), p);
    canvas.drawLine(
        Offset(s.width * 0.66, 0), Offset(s.width * 0.66, s.height), p);
    canvas.drawLine(
        Offset(0, s.height * 0.50), Offset(s.width, s.height * 0.50), p);
  }

  @override
  bool shouldRepaint(_MapPainter o) => o.color != color;
}

class _TrailClearPainter extends CustomPainter {
  final Color color;
  const _TrailClearPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(s.width * 0.20, s.height * 0.20),
        Offset(s.width * 0.80, s.height * 0.80), p);
    canvas.drawLine(Offset(s.width * 0.80, s.height * 0.20),
        Offset(s.width * 0.20, s.height * 0.80), p);
  }

  @override
  bool shouldRepaint(_TrailClearPainter o) => o.color != color;
}

class _WarningIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final path = Path();
    path.moveTo(cx, 0);
    path.lineTo(s.width, s.height);
    path.lineTo(0, s.height);
    path.close();
    canvas.drawPath(path,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.20)
          ..style = PaintingStyle.fill);
    canvas.drawPath(path,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeJoin = StrokeJoin.round);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - 2, s.height * 0.36, 4, s.height * 0.28),
            const Radius.circular(2)),
        Paint()..color = Colors.white);
    canvas.drawCircle(Offset(cx, s.height * 0.78), 2.5,
        Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_WarningIconPainter o) => false;
}

class _SignalOffPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (int i = 1; i <= 3; i++) {
      canvas.drawArc(
          Rect.fromCircle(
              center: Offset(s.width * 0.40, s.height * 0.60),
              radius: i * s.width * 0.16),
          -math.pi * 0.8, math.pi * 0.6, false,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.30)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..strokeCap = StrokeCap.round);
    }
    canvas.drawLine(Offset(s.width * 0.10, s.height * 0.10),
        Offset(s.width * 0.90, s.height * 0.90), p);
  }

  @override
  bool shouldRepaint(_SignalOffPainter o) => false;
}

class _WalkIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawCircle(Offset(s.width * 0.55, s.height * 0.12), s.width * 0.12, p);
    final body = Path();
    body.moveTo(s.width * 0.55, s.height * 0.24);
    body.lineTo(s.width * 0.50, s.height * 0.55);
    body.lineTo(s.width * 0.30, s.height * 0.80);
    body.moveTo(s.width * 0.50, s.height * 0.55);
    body.lineTo(s.width * 0.72, s.height * 0.78);
    body.moveTo(s.width * 0.38, s.height * 0.38);
    body.lineTo(s.width * 0.15, s.height * 0.50);
    body.moveTo(s.width * 0.38, s.height * 0.38);
    body.lineTo(s.width * 0.70, s.height * 0.32);
    canvas.drawPath(body, p);
  }

  @override
  bool shouldRepaint(_WalkIconPainter o) => false;
}

class _SpeedIconPainter extends CustomPainter {
  final Color color;
  const _SpeedIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height * 0.60;
    final r  = s.width * 0.44;
    canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        math.pi, math.pi, false,
        Paint()
          ..color = color.withValues(alpha: 0.30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round);
    canvas.drawLine(
        Offset(cx, cy),
        Offset(cx - r * 0.30, cy - r * 0.70),
        Paint()
          ..color = color
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(Offset(cx, cy), 2.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SpeedIconPainter o) => o.color != color;
}

class _BatteryIconPainter extends CustomPainter {
  final Color color;
  const _BatteryIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0, s.height * 0.20, s.width * 0.88, s.height * 0.60),
            const Radius.circular(2)),
        p);
    canvas.drawLine(Offset(s.width * 0.90, s.height * 0.36),
        Offset(s.width * 0.90, s.height * 0.64),
        Paint()
          ..color = color
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(s.width * 0.06, s.height * 0.28, s.width * 0.55, s.height * 0.44),
            const Radius.circular(1)),
        Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BatteryIconPainter o) => o.color != color;
}

class _TrailIconPainter extends CustomPainter {
  final Color color;
  const _TrailIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final path = Path();
    path.moveTo(s.width * 0.10, s.height * 0.80);
    path.cubicTo(s.width * 0.10, s.height * 0.40, s.width * 0.90,
        s.height * 0.60, s.width * 0.90, s.height * 0.20);
    canvas.drawPath(path, p);
    for (final pt in [
      Offset(s.width * 0.10, s.height * 0.80),
      Offset(s.width * 0.45, s.height * 0.60),
      Offset(s.width * 0.90, s.height * 0.20),
    ]) {
      canvas.drawCircle(pt, 2.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_TrailIconPainter o) => o.color != color;
}

class _CallIconSmallPainter extends CustomPainter {
  final Color color;
  const _CallIconSmallPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(s.width * 0.20, s.height * 0.08);
    path.quadraticBezierTo(s.width * 0.08, s.height * 0.22,
        s.width * 0.22, s.height * 0.38);
    path.quadraticBezierTo(
        s.width * 0.36, s.height * 0.54, s.width * 0.50, s.height * 0.68);
    path.quadraticBezierTo(s.width * 0.64, s.height * 0.82,
        s.width * 0.78, s.height * 0.82);
    path.quadraticBezierTo(s.width * 0.94, s.height * 0.82,
        s.width * 0.94, s.height * 0.66);
    path.lineTo(s.width * 0.72, s.height * 0.44);
    path.lineTo(s.width * 0.60, s.height * 0.52);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_CallIconSmallPainter o) => o.color != color;
}

class _NavigateIconPainter extends CustomPainter {
  final Color color;
  const _NavigateIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(s.width * 0.50, 0);
    path.lineTo(s.width, s.height * 0.60);
    path.lineTo(s.width * 0.50, s.height * 0.44);
    path.lineTo(0, s.height * 0.60);
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_NavigateIconPainter o) => o.color != color;
}

class _ShareIconPainter extends CustomPainter {
  final Color color;
  const _ShareIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(s.width * 0.78, s.height * 0.20), s.width * 0.12, p);
    canvas.drawCircle(Offset(s.width * 0.78, s.height * 0.80), s.width * 0.12, p);
    canvas.drawCircle(Offset(s.width * 0.20, s.height * 0.50), s.width * 0.12, p);
    canvas.drawLine(Offset(s.width * 0.32, s.height * 0.46),
        Offset(s.width * 0.66, s.height * 0.26), p);
    canvas.drawLine(Offset(s.width * 0.32, s.height * 0.54),
        Offset(s.width * 0.66, s.height * 0.74), p);
  }

  @override
  bool shouldRepaint(_ShareIconPainter o) => o.color != color;
}

class _PoliceIconPainter extends CustomPainter {
  final Color color;
  const _PoliceIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Badge outline
    final path = Path();
    path.moveTo(s.width * 0.50, 0);
    path.lineTo(s.width, s.height * 0.28);
    path.lineTo(s.width * 0.92, s.height * 0.76);
    path.lineTo(s.width * 0.50, s.height);
    path.lineTo(s.width * 0.08, s.height * 0.76);
    path.lineTo(0, s.height * 0.28);
    path.close();
    canvas.drawPath(path, p);
    // Star
    const n = 5;
    final cx = s.width / 2;
    final cy = s.height * 0.50;
    final outer = s.width * 0.22;
    final inner = s.width * 0.10;
    final star = Path();
    for (int i = 0; i < n * 2; i++) {
      final r = i.isEven ? outer : inner;
      final a = (i * math.pi / n) - math.pi / 2;
      final x = cx + r * math.cos(a);
      final y = cy + r * math.sin(a);
      if (i == 0) star.moveTo(x, y);
      else star.lineTo(x, y);
    }
    star.close();
    canvas.drawPath(star, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PoliceIconPainter o) => o.color != color;
}

class _LocationPinSmallPainter extends CustomPainter {
  final Color color;
  const _LocationPinSmallPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(s.width * 0.50, 0);
    path.cubicTo(
        s.width * 0.18, 0, 0, s.height * 0.26, 0, s.height * 0.46);
    path.cubicTo(0, s.height * 0.66, s.width * 0.18, s.height * 0.80,
        s.width * 0.50, s.height);
    path.cubicTo(s.width * 0.82, s.height * 0.80, s.width,
        s.height * 0.66, s.width, s.height * 0.46);
    path.cubicTo(s.width, s.height * 0.26, s.width * 0.82, 0, s.width * 0.50, 0);
    path.close();
    canvas.drawPath(path, p);
    canvas.drawCircle(
        Offset(s.width / 2, s.height * 0.44), s.width * 0.14,
        Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LocationPinSmallPainter o) => o.color != color;
}