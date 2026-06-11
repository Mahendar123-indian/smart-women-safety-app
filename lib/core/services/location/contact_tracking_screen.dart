// lib/features/location/screens/contact_tracking_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// CONTACT TRACKING SCREEN
// What emergency contacts see when woman shares live location or triggers SOS
// Real-time map, breadcrumb trail, call/SMS, evidence preview
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/location_service.dart';

class ContactTrackingScreen extends StatefulWidget {
  final String trackedUid;
  final String trackedName;
  final String? photoUrl;
  final String? incidentId;
  final bool isSosMode;

  const ContactTrackingScreen({
    super.key,
    required this.trackedUid,
    required this.trackedName,
    this.photoUrl,
    this.incidentId,
    this.isSosMode = false,
  });

  @override
  State<ContactTrackingScreen> createState() => _ContactTrackingScreenState();
}

class _ContactTrackingScreenState extends State<ContactTrackingScreen>
    with TickerProviderStateMixin {

  static const String _rtdbUrl =
      'https://smart-women-safety-app-b1988-default-rtdb.asia-southeast1.firebasedatabase.app';

  final _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(), databaseURL: _rtdbUrl,
  );

  GoogleMapController? _mapController;
  StreamSubscription?  _locationSub;
  StreamSubscription?  _breadcrumbSub;

  LocationData?        _currentLocation;
  final List<LatLng>   _breadcrumbs  = [];
  bool                 _isActive      = false;
  bool                 _signalLost    = false;
  DateTime?            _lastUpdate;
  String               _statusText    = 'Connecting...';

  // SOS data
  String?  _lastAddress;
  double?  _dangerScore;
  int      _photoCount  = 0;
  int      _videoCount  = 0;
  String?  _audioUrl;

  late AnimationController _pulseCtrl;
  late AnimationController _sosCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 2),
    )..repeat();
    _sosCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _startListening();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _breadcrumbSub?.cancel();
    _mapController?.dispose();
    _pulseCtrl.dispose();
    _sosCtrl.dispose();
    super.dispose();
  }

  void _startListening() {
    // Live location stream
    _locationSub = _db
        .ref('users/${widget.trackedUid}/liveLocation')
        .onValue
        .listen((event) {
      if (!mounted) return;
      if (event.snapshot.value == null) {
        setState(() {
          _isActive   = false;
          _statusText = 'Location sharing stopped';
          _signalLost = true;
        });
        return;
      }
      try {
        final raw = Map<String, dynamic>.from(event.snapshot.value as Map);
        final loc = LocationData.fromJson(raw);
        _lastAddress = raw['address'] as String?;
        setState(() {
          _currentLocation = loc;
          _isActive        = raw['isSharing'] == true;
          _signalLost      = false;
          _lastUpdate      = DateTime.now();
          _statusText      = _isActive ? 'Live' : 'Last known';
        });

        if (_isActive) _moveCamera(loc.lat, loc.lng);

        // Add to breadcrumbs
        if (_breadcrumbs.length > 200) _breadcrumbs.removeAt(0);
        _breadcrumbs.add(LatLng(loc.lat, loc.lng));
      } catch (e) {
        debugPrint('ContactTracking location parse: $e');
      }
    }, onError: (_) {
      if (mounted) setState(() => _signalLost = true);
    });

    // SOS data if in SOS mode
    if (widget.isSosMode && widget.incidentId != null) {
      _db.ref('users/${widget.trackedUid}/activeAlert').onValue.listen((ev) {
        if (!mounted || ev.snapshot.value == null) return;
        try {
          final raw = Map<String, dynamic>.from(ev.snapshot.value as Map);
          setState(() {
            _dangerScore = (raw['dangerScore'] as num?)?.toDouble();
            _photoCount  = (raw['photoCount']  as int?) ?? 0;
            _videoCount  = (raw['videoCount']  as int?) ?? 0;
            _audioUrl    = raw['audioUrl']     as String?;
          });
        } catch (_) {}
      });
    }
  }

  void _moveCamera(double lat, double lng) {
    if (_mapController == null) return;
    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(lat, lng), zoom: 16),
      ),
    );
  }

  Set<Polyline> get _polylines {
    if (_breadcrumbs.length < 2) return {};
    return {
      Polyline(
        polylineId: const PolylineId('trail'),
        points:     _breadcrumbs,
        color:      widget.isSosMode ? AppColors.sosRed : AppColors.primary,
        width:      4,
        patterns:   widget.isSosMode ? [] : [PatternItem.dot, PatternItem.gap(8)],
      ),
    };
  }

  Set<Marker> get _markers {
    if (_currentLocation == null) return {};
    return {
      Marker(
        markerId: const MarkerId('woman'),
        position: LatLng(_currentLocation!.lat, _currentLocation!.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          widget.isSosMode ? BitmapDescriptor.hueRed : BitmapDescriptor.hueRose,
        ),
        infoWindow: InfoWindow(
          title:   widget.trackedName,
          snippet: _lastAddress ?? 'Location updating...',
        ),
        zIndex: 5,
      ),
    };
  }

  String _timeAgo() {
    if (_lastUpdate == null) return 'Never';
    final d = DateTime.now().difference(_lastUpdate!);
    if (d.inSeconds < 10)  return 'Just now';
    if (d.inSeconds < 60)  return '${d.inSeconds}s ago';
    if (d.inMinutes < 60)  return '${d.inMinutes}m ago';
    return '${d.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Stack(children: [
        // ── FULL SCREEN MAP ──
        _currentLocation == null
            ? _buildLoadingState(isDark)
            : GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(
              _currentLocation!.lat,
              _currentLocation!.lng,
            ),
            zoom: 16,
          ),
          onMapCreated: (c) => setState(() => _mapController = c),
          myLocationEnabled:       false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled:     false,
          mapToolbarEnabled:       false,
          compassEnabled:          true,
          markers:  _markers,
          polylines: _polylines,
        ),

        // ── TOP BAR ──
        SafeArea(
          child: Column(children: [
            _buildTopBar(isDark),
            if (widget.isSosMode) _buildSosBanner(),
            if (_signalLost)      _buildSignalLostBanner(),
          ]),
        ),

        // ── BOTTOM PANEL ──
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: _buildBottomPanel(isDark),
        ),

        // ── SOS PULSE OVERLAY ──
        if (widget.isSosMode && _isActive)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.sosRed.withOpacity(
                        0.3 * (1 - _pulseCtrl.value),
                      ),
                      width: 12 * _pulseCtrl.value,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildTopBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow:    AppColors.cardShadow,
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_rounded, size: 18),
          ),
        ),
        const SizedBox(width: 10),
        // Avatar
        CircleAvatar(
          radius:          18,
          backgroundColor: AppColors.primary.withOpacity(0.1),
          backgroundImage: widget.photoUrl != null
              ? NetworkImage(widget.photoUrl!)
              : null,
          child: widget.photoUrl == null
              ? Text(
            widget.trackedName.isNotEmpty
                ? widget.trackedName[0].toUpperCase()
                : '?',
            style: const TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.w800),
          )
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.trackedName,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
            Row(children: [
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isActive ? AppColors.safeGreen : Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '$_statusText · ${_timeAgo()}',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    color: _isActive ? AppColors.safeGreen : Colors.grey),
              ),
            ]),
          ]),
        ),
        // Recenter button
        GestureDetector(
          onTap: () {
            if (_currentLocation != null) {
              _moveCamera(_currentLocation!.lat, _currentLocation!.lng);
            }
          },
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.my_location_rounded,
                color: AppColors.primary, size: 18),
          ),
        ),
      ]),
    );
  }

  Widget _buildSosBanner() {
    return AnimatedBuilder(
      animation: _sosCtrl,
      builder: (_, __) => Container(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Color.lerp(
              AppColors.sosRed, AppColors.sosRed.withOpacity(0.7), _sosCtrl.value),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          const Icon(Icons.warning_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('🚨 SOS ALERT ACTIVE',
                  style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w900,
                      fontSize: 13)),
              if (_dangerScore != null)
                Text('AI Danger Score: ${(_dangerScore! * 100).toInt()}%',
                    style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'Poppins',
                        fontSize: 10)),
            ]),
          ),
          if (_dangerScore != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${(_dangerScore! * 100).toInt()}%',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Poppins',
                    fontSize: 12),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildSignalLostBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.warningAmber,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(children: [
        Icon(Icons.signal_cellular_off_rounded, color: Colors.white, size: 16),
        SizedBox(width: 8),
        Expanded(
          child: Text('Signal lost — showing last known location',
              style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _buildBottomPanel(bool isDark) {
    final loc = _currentLocation;
    return Container(
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color:       Colors.black.withOpacity(0.15),
            blurRadius:  20,
            offset:      const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Drag handle
        Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 14),

        // Location info
        if (loc != null) ...[
          Row(children: [
            const Icon(Icons.location_on_rounded,
                color: AppColors.primary, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _lastAddress ?? '${loc.lat.toStringAsFixed(4)}, ${loc.lng.toStringAsFixed(4)}',
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
                maxLines: 2,
              ),
            ),
          ]),
          const SizedBox(height: 8),

          // Stats row
          Row(children: [
            _MiniStat(
                icon: Icons.speed_rounded,
                value: '${loc.speed.toStringAsFixed(0)}',
                label: 'km/h',
                color: AppColors.secondary),
            const SizedBox(width: 8),
            _MiniStat(
                icon: Icons.timeline_rounded,
                value: '${_breadcrumbs.length}',
                label: 'points',
                color: AppColors.primary),
            if (widget.isSosMode) ...[
              const SizedBox(width: 8),
              _MiniStat(
                  icon: Icons.photo_camera_rounded,
                  value: '$_photoCount',
                  label: 'photos',
                  color: AppColors.warningAmber),
              const SizedBox(width: 8),
              _MiniStat(
                  icon: Icons.videocam_rounded,
                  value: '$_videoCount',
                  label: 'videos',
                  color: AppColors.sosRed),
            ],
          ]),
          const SizedBox(height: 14),
        ],

        // Action buttons
        Row(children: [
          Expanded(
            child: _ActionBtn(
              icon:    Icons.call_rounded,
              label:   'Call Now',
              color:   AppColors.safeGreen,
              onTap:   () => _makeCall(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionBtn(
              icon:    Icons.directions_rounded,
              label:   'Navigate',
              color:   AppColors.secondary,
              onTap:   () => _openNavigation(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionBtn(
              icon:    Icons.share_rounded,
              label:   'Share',
              color:   AppColors.primary,
              onTap:   () => _shareLocation(),
            ),
          ),
        ]),

        if (widget.isSosMode) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _callPolice,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: AppColors.sosGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_police_rounded,
                        color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Call Police — 100',
                        style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w900,
                            fontSize: 15)),
                  ]),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Container(
      color: isDark ? AppColors.darkBackground : const Color(0xFFE8F5E9),
      child: const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text('Connecting to live location...',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
        ]),
      ),
    );
  }

  Future<void> _makeCall() async {
    // In real app, get phone from contact record
    final uri = Uri.parse('tel:+91');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openNavigation() async {
    if (_currentLocation == null) return;
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${_currentLocation!.lat},${_currentLocation!.lng}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareLocation() async {
    if (_currentLocation == null) return;
    final uri = Uri.parse('https://maps.google.com/?q=${_currentLocation!.lat},${_currentLocation!.lng}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _callPolice() async {
    final uri = Uri.parse('tel:100');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  const _MiniStat({
    required this.icon, required this.value,
    required this.label, required this.color,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(
              color: color, fontWeight: FontWeight.w800,
              fontFamily: 'Poppins', fontSize: 12)),
          Text(label, style: const TextStyle(
              fontSize: 8, fontFamily: 'Poppins', color: Colors.grey)),
        ]),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.icon, required this.label,
    required this.color, required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(
            color: color, fontFamily: 'Poppins',
            fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}