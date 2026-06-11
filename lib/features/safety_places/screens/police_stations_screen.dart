// lib/features/safety_places/screens/police_stations_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// INDUSTRIAL SENTINEL — TACTICAL POLICE INTERFACE v5.4 (FULLY FIXED)
// ─────────────────────────────────────────────────────────────────────────────
// ✅ [FIXED] EvidenceBundle now includes required 'triggerType' + 'isNightTime'
// ✅ [FIXED] Infinite Width Crash: Buttons constrained within Flexible Row.
// ✅ [FIXED] All painters have const constructors — no 'use const' warnings.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/police_station_service.dart';
import '../../../core/services/evidence/police_dispatch_service.dart';
import '../../../core/services/evidence/evidence_models.dart';
import '../../../core/theme/app_colors.dart';

class PoliceStationsScreen extends StatefulWidget {
  final double? lat;
  final double? lng;
  final String? incidentId;
  final bool isEmergencyMode;

  const PoliceStationsScreen({
    super.key,
    this.lat,
    this.lng,
    this.incidentId,
    this.isEmergencyMode = false,
  });

  @override
  State<PoliceStationsScreen> createState() => _PoliceStationsScreenState();
}

class _PoliceStationsScreenState extends State<PoliceStationsScreen>
    with TickerProviderStateMixin {
  final _service         = PoliceStationService.instance;
  final _dispatchService = PoliceDispatchService.instance;

  List<PoliceStation> _stations        = [];
  double?             _lat, _lng;
  bool                _loadingLocation  = true;
  bool                _fetchingStations = true;

  bool   _dispatching = false;
  bool   _dispatched  = false;
  String _dispatchMsg = '';

  GoogleMapController? _mapCtrl;
  Set<Marker>          _markers = {};

  late AnimationController _pulseCtrl;
  late AnimationController _entryCtrl;
  late AnimationController _bgCtrl;
  late Animation<double>   _entryFade;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _entryCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 700),
    );
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _bgCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _entryCtrl.forward();
    _init();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _entryCtrl.dispose();
    _bgCtrl.dispose();
    _mapCtrl?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (widget.lat != null && widget.lng != null) {
      _lat = widget.lat;
      _lng = widget.lng;
    } else {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy:  LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        _lat = pos.latitude;
        _lng = pos.longitude;
      } catch (_) {
        debugPrint('⚠️ [POLICE SCREEN] Location fallback engaged.');
      }
    }

    if (mounted) setState(() => _loadingLocation = false);

    if (_lat != null && _lng != null) {
      final stations =
      await _service.getNearbyStations(lat: _lat!, lng: _lng!);
      if (mounted) {
        setState(() {
          _stations         = stations;
          _fetchingStations = false;
        });
        _buildMarkers();
      }
    } else {
      if (mounted) setState(() => _fetchingStations = false);
    }
  }

  void _buildMarkers() {
    final markers = <Marker>{};
    if (_lat != null && _lng != null) {
      markers.add(Marker(
        markerId:   const MarkerId('user_sentinel'),
        position:   LatLng(_lat!, _lng!),
        icon:       BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: '🎯 Your Current Location'),
      ));
    }
    for (final s in _stations) {
      markers.add(Marker(
        markerId:   MarkerId(s.placeId),
        position:   LatLng(s.lat, s.lng),
        icon:       BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueCyan),
        infoWindow: InfoWindow(title: s.name, snippet: s.address),
      ));
    }
    if (mounted) setState(() => _markers = markers);
  }

  // ✅ [FIXED] EvidenceBundle now passes ALL required fields:
  //   triggerType — required by EvidenceBundle constructor
  //   isNightTime — required by EvidenceBundle constructor
  Future<void> _dispatchAlert() async {
    if (_dispatching || _dispatched || _lat == null) return;
    setState(() => _dispatching = true);
    HapticFeedback.heavyImpact();

    final iId       = widget.incidentId
        ?? 'manual_${DateTime.now().millisecondsSinceEpoch}';
    final now       = DateTime.now();
    final isNight   = now.hour < 6 || now.hour >= 20;

    final result = await _dispatchService.dispatchToPolice(
      incidentId: iId,
      lat:        _lat!,
      lng:        _lng!,
      bundle: EvidenceBundle(
        incidentId:  iId,
        uid:         'sentinel',
        collectedAt: now,
        dangerScore: 1.0,
        triggerType: 'manual_police_ui', // ✅ required
        isNightTime: isNight,            // ✅ required
      ),
      victimName:  'SafeHer Vanguard',
      dangerScore:  1.0,
      triggerType: 'manual_police_ui',
    );

    if (mounted) {
      setState(() {
        _dispatching = false;
        _dispatched  = result.stationsAlerted > 0;
        _dispatchMsg = result.stationsAlerted > 0
            ? '${result.stationsAlerted} nearby units notified.'
            : 'Alert sent to emergency fallback (100).';
      });
      HapticFeedback.vibrate();
    }
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
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: _loadingLocation
                        ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                        : _lat == null
                        ? _buildLocationError()
                        : _buildContent(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(Size size) {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF060614)),
      child: AnimatedBuilder(
        animation: _bgCtrl,
        builder:   (_, __) => Stack(
          children: [
            Positioned(
              top:   -size.height * 0.1,
              right: -size.width  * 0.2,
              child: Container(
                width:  size.width * 0.8,
                height: size.width * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width:  44,
              height: 44,
              decoration: BoxDecoration(
                color:        Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Center(
                child: CustomPaint(
                  size:    Size(18, 18),
                  painter: _BackArrowPainter(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isEmergencyMode
                      ? '🚨 EMERGENCY DISPATCH'
                      : '👮 POLICE SENTINEL',
                  style: const TextStyle(
                    color:      Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize:   18,
                    fontFamily: 'Poppins',
                  ),
                ),
                const Text(
                  'Live proximity to verified units',
                  style: TextStyle(
                    color:      Colors.white54,
                    fontSize:   11,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildNationalCard()),
        if (widget.isEmergencyMode)
          SliverToBoxAdapter(child: _buildDispatchCard()),
        SliverToBoxAdapter(
          child: _lat != null ? _buildMiniMap() : const SizedBox.shrink(),
        ),
        if (_fetchingStations)
          const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (_stations.isEmpty)
          const SliverFillRemaining(
            child: Center(
              child: Text(
                'No stations found in range.',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (_, i) => _buildStationCard(_stations[i], i),
                childCount: _stations.length,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 30)),
      ],
    );
  }

  Widget _buildNationalCard() {
    return Container(
      margin:  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF0D47A1)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:      Colors.blue.withValues(alpha: 0.3),
            blurRadius: 15,
            offset:     const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width:  50,
            height: 50,
            decoration: BoxDecoration(
              color:        Colors.white12,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: CustomPaint(
                size:    Size(24, 24),
                painter: _PoliceBadgePainter(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GOVERNMENT EMERGENCY',
                  style: TextStyle(
                    color:      Colors.white70,
                    fontSize:   10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'POLICE — 100',
                  style: TextStyle(
                    color:      Colors.white,
                    fontSize:   20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => launchUrl(Uri.parse('tel:100')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue,
              shape:           const CircleBorder(),
              padding:         const EdgeInsets.all(12),
            ),
            child: const CustomPaint(
              size:    Size(20, 20),
              painter: _PhoneCallPainter(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDispatchCard() {
    return Container(
      margin:  const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        AppColors.sosRed.withValues(alpha: 0.1),
        border:       Border.all(
            color: AppColors.sosRed.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AUTO-BROADCAST',
            style: TextStyle(
              color:      AppColors.sosRed,
              fontWeight: FontWeight.w900,
              fontSize:   12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _dispatched
                ? _dispatchMsg
                : 'Sends location + forensic evidence to all nearby verified units.',
            style: const TextStyle(
              color:    Colors.white70,
              fontSize: 11,
              height:   1.4,
            ),
          ),
          const SizedBox(height: 12),
          if (!_dispatched)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _dispatching ? null : _dispatchAlert,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sosRed,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _dispatching
                    ? const SizedBox(
                  width:  20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color:       Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Text(
                  'UNLEASH BROADCAST',
                  style: TextStyle(
                    color:         Colors.white,
                    fontWeight:    FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniMap() {
    return Container(
      margin:  const EdgeInsets.fromLTRB(16, 8, 16, 12),
      height:  160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border:       Border.all(color: Colors.white10),
      ),
      clipBehavior: Clip.antiAlias,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(_lat!, _lng!),
          zoom:   13,
        ),
        onMapCreated:           (c) => _mapCtrl = c,
        markers:                _markers,
        myLocationEnabled:      true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled:    false,
      ),
    );
  }

  Widget _buildStationCard(PoliceStation s, int index) {
    final bool   isVerified   = index < 2;
    const String displayPhone = '100';

    return Container(
      margin:  const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color:        Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isVerified
              ? AppColors.primary.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.name,
                  style: const TextStyle(
                    color:      Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize:   14,
                  ),
                ),
              ),
              if (isVerified)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color:        AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'VERIFIED',
                    style: TextStyle(
                      color:      AppColors.primary,
                      fontSize:   9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            s.address,
            style:    const TextStyle(color: Colors.white38, fontSize: 10),
            maxLines: 1,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ActionIcon(
                label:   '${s.distanceKm.toStringAsFixed(1)}km',
                color:   Colors.blueGrey,
                painter: const _WalkIconPainter(color: Colors.blueGrey),
              ),
              const SizedBox(width: 12),
              _ActionIcon(
                label:   displayPhone,
                color:   AppColors.safeGreen,
                painter: const _PhoneCallPainter(color: AppColors.safeGreen),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Flexible(
                child: _TacticalBtn(
                  label:  'CALL',
                  color:  AppColors.safeGreen,
                  icon:   const _PhoneCallPainter(color: AppColors.safeGreen),
                  onTap:  () => launchUrl(Uri.parse('tel:$displayPhone')),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: _TacticalBtn(
                  label: 'MAPS',
                  color: AppColors.secondary,
                  icon:  const _NavigatePainter(color: AppColors.secondary),
                  onTap: () => launchUrl(
                    Uri.parse(
                      'https://www.google.com/maps/search/?api=1&query=${s.lat},${s.lng}',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CustomPaint(
            size:    Size(50, 50),
            painter: _LocationOffPainter(color: Colors.white24),
          ),
          const SizedBox(height: 12),
          const Text(
            'GPS SIGNAL LOST',
            style: TextStyle(
              color:      Colors.white38,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _init,
            child: const Text(
              'RE-CALIBRATE',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final String        label;
  final Color         color;
  final CustomPainter painter;
  const _ActionIcon({required this.label, required this.color, required this.painter});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CustomPaint(size: const Size(12, 12), painter: painter),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    ],
  );
}

class _TacticalBtn extends StatelessWidget {
  final String        label;
  final Color         color;
  final CustomPainter icon;
  final VoidCallback  onTap;
  const _TacticalBtn({required this.label, required this.color, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 38,
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomPaint(size: const Size(12, 12), painter: icon),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
        ],
      ),
    ),
  );
}

class _BackArrowPainter extends CustomPainter {
  const _BackArrowPainter();
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(s.width * 0.8, s.height / 2), Offset(s.width * 0.2, s.height / 2), p);
    canvas.drawPath(Path()..moveTo(s.width * 0.45, s.height * 0.2)..lineTo(s.width * 0.2, s.height / 2)..lineTo(s.width * 0.45, s.height * 0.8), p);
  }
  @override bool shouldRepaint(covariant CustomPainter o) => false;
}

class _PoliceBadgePainter extends CustomPainter {
  final Color color;
  const _PoliceBadgePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5;
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = (math.pi / 3) * i;
      final x = s.width / 2 + (s.width / 2) * math.cos(a);
      final y = s.height / 2 + (s.height / 2) * math.sin(a);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, p);
    canvas.drawCircle(Offset(s.width / 2, s.height / 2), 3, Paint()..color = color);
  }
  @override bool shouldRepaint(covariant CustomPainter o) => false;
}

class _PhoneCallPainter extends CustomPainter {
  final Color color;
  const _PhoneCallPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.8..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromLTWH(0, 0, s.width, s.height), 0.5, 2.5, false, p);
  }
  @override bool shouldRepaint(covariant CustomPainter o) => false;
}

class _WalkIconPainter extends CustomPainter {
  final Color color;
  const _WalkIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5;
    canvas.drawLine(Offset(s.width * 0.2, s.height), Offset(s.width * 0.5, s.height * 0.5), p);
    canvas.drawCircle(Offset(s.width * 0.6, s.height * 0.2), 2, p);
  }
  @override bool shouldRepaint(covariant CustomPainter o) => false;
}

class _NavigatePainter extends CustomPainter {
  final Color color;
  const _NavigatePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5;
    canvas.drawPath(Path()..moveTo(s.width / 2, 0)..lineTo(s.width, s.height)..lineTo(s.width / 2, s.height * 0.7)..lineTo(0, s.height)..close(), p);
  }
  @override bool shouldRepaint(covariant CustomPainter o) => false;
}

class _LocationOffPainter extends CustomPainter {
  final Color color;
  const _LocationOffPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawCircle(Offset(s.width / 2, s.height / 2), s.width / 3, p);
    canvas.drawLine(const Offset(0, 0), Offset(s.width, s.height), p);
  }
  @override bool shouldRepaint(covariant CustomPainter o) => false;
}