// lib/features/community/screens/community_map_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// COMMUNITY MAP SCREEN
// ✅ Zero Material Icons — all CustomPainter
// ✅ Firebase Firestore real-time streams
// ✅ 100% matched dark theme
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/community_service.dart';
import '../../../core/theme/app_colors.dart';
import 'report_danger_screen.dart';

class CommunityMapScreen extends StatefulWidget {
  const CommunityMapScreen({super.key});
  @override
  State<CommunityMapScreen> createState() =>
      _CommunityMapScreenState();
}

class _CommunityMapScreenState extends State<CommunityMapScreen>
    with TickerProviderStateMixin {
  final _service = CommunityService.instance;
  GoogleMapController? _mapCtrl;
  double? _lat, _lng;
  bool _loading = true;
  DangerType? _filter;
  Set<Circle> _circles = {};
  Set<Marker> _markers = {};
  DangerReport? _selected;

  late AnimationController _entryCtrl;
  late AnimationController _bgCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _entryFade;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _entryFade =
        CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entryCtrl.forward();

    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);

    _init();
  }

  @override
  void dispose() {
    _service.stopLiveStream();
    _service.removeListener(_rebuildOverlays);
    _entryCtrl.dispose();
    _bgCtrl.dispose();
    _pulseCtrl.dispose();
    _mapCtrl?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      _lat = pos.latitude;
      _lng = pos.longitude;
    } catch (_) {}

    if (mounted) setState(() => _loading = false);

    if (_lat != null) {
      await _service.loadNearbyReports(
          lat: _lat!, lng: _lng!);
      _service.startLiveStream(_lat!, _lng!);
      _service.addListener(_rebuildOverlays);
      _rebuildOverlays();
    }
  }

  void _rebuildOverlays() {
    if (!mounted) return;
    final circles = <Circle>{};
    final markers = <Marker>{};
    final reports = _filter == null
        ? _service.reports
        : _service.reports
        .where((r) => r.type == _filter)
        .toList();

    for (final r in reports) {
      final color =
      r.isHighRisk ? AppColors.sosRed : AppColors.warningAmber;
      circles.add(Circle(
        circleId: CircleId(r.id),
        center: LatLng(r.lat, r.lng),
        radius: r.isHighRisk ? 80.0 : 50.0,
        fillColor: color.withValues(alpha: 0.18),
        strokeColor: color.withValues(alpha: 0.70),
        strokeWidth: 2,
      ));
      markers.add(Marker(
        markerId: MarkerId(r.id),
        position: LatLng(r.lat, r.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          r.isHighRisk
              ? BitmapDescriptor.hueRed
              : BitmapDescriptor.hueOrange,
        ),
        onTap: () => setState(() => _selected = r),
        infoWindow: InfoWindow(
          title: '${r.typeEmoji} ${r.typeLabel}',
          snippet: '${r.voteCount} reports',
        ),
      ));
    }
    setState(() { _circles = circles; _markers = markers; });
  }

  Future<void> _reportDanger() async {
    HapticFeedback.mediumImpact();
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ReportDangerScreen(lat: _lat, lng: _lng),
      ),
    );
    if (result == true && _lat != null) {
      await _service.loadNearbyReports(
          lat: _lat!, lng: _lng!, radiusKm: 10);
      _rebuildOverlays();
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

          // Map fills entire screen
          _loading || _lat == null
              ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary))
              : Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(_lat!, _lng!),
                zoom: 14,
              ),
              onMapCreated: (c) =>
                  setState(() => _mapCtrl = c),
              circles: _circles,
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              onTap: (_) =>
                  setState(() => _selected = null),
            ),
          ),

          // Top overlay
          SafeArea(
            child: FadeTransition(
              opacity: _entryFade,
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  _buildFilterChips(),
                ],
              ),
            ),
          ),

          // Legend bottom left
          Positioned(
            bottom: _selected != null ? 220 : 110,
            left: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _legendItem(AppColors.sosRed,
                    '5+ reports · High Risk'),
                const SizedBox(height: 4),
                _legendItem(AppColors.warningAmber,
                    '1–4 reports'),
              ],
            ),
          ),

          // Map controls bottom right
          Positioned(
            bottom: _selected != null ? 230 : 120,
            right: 16,
            child: Column(
              children: [
                _MapBtn(
                  painter: _GpsCrosshairPainter(
                      color: AppColors.primary),
                  onTap: () {
                    if (_lat != null) {
                      HapticFeedback.selectionClick();
                      _mapCtrl?.animateCamera(
                        CameraUpdate.newLatLngZoom(
                            LatLng(_lat!, _lng!), 15),
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),
                _MapBtn(
                  painter: _RefreshIconPainter(
                      color: AppColors.secondary),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (_lat != null) {
                      _service.loadNearbyReports(
                          lat: _lat!, lng: _lng!);
                    }
                  },
                ),
              ],
            ),
          ),

          // Selected report panel
          if (_selected != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildReportPanel(_selected!),
            ),

          // Stats bar (when nothing selected)
          if (_selected == null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildStatsBar(),
            ),

          // FAB
          Positioned(
            bottom: _selected != null ? 200 : 90,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _reportDanger,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 13),
                  decoration: BoxDecoration(
                    gradient: AppColors.sosGradient,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.sosRed
                            .withValues(alpha: 0.45),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomPaint(
                        size: const Size(18, 18),
                        painter: _PinAddPainter(
                            color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Report Danger',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
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
      builder: (_, __) => Positioned.fill(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF060614), Color(0xFF0A0A20)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.darkCard.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
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
                  size: const Size(14, 14),
                  painter: _BackArrowPainter(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Community Safety Map',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                ListenableBuilder(
                  listenable: _service,
                  builder: (_, __) => Text(
                    _service.isLoading
                        ? 'Loading reports...'
                        : '${_service.reports.length} danger zones nearby',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      color:
                      Colors.white.withValues(alpha: 0.40),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Safety score
          ListenableBuilder(
            listenable: _service,
            builder: (_, __) {
              final score =
                  _service.stats?.safetysScore ?? 100;
              final color = score >= 70
                  ? AppColors.safeGreen
                  : score >= 40
                  ? AppColors.warningAmber
                  : AppColors.sosRed;
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: color.withValues(alpha: 0.25)),
                ),
                child: Column(
                  children: [
                    Text(
                      '${score.toInt()}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: color,
                      ),
                    ),
                    Text(
                      'Safe',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 8,
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _FilterChip(
            label: 'All',
            emoji: '🗺️',
            selected: _filter == null,
            onTap: () {
              setState(() => _filter = null);
              _rebuildOverlays();
            },
          ),
          ...DangerType.values.map((t) => _FilterChip(
            label: DangerReport.typeLabels[t]!,
            emoji: DangerReport.typeEmojis[t]!,
            selected: _filter == t,
            onTap: () {
              setState(() =>
              _filter = _filter == t ? null : t);
              _rebuildOverlays();
            },
          )),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) => Row(
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.w700,
          shadows: const [
            Shadow(color: Colors.black87, blurRadius: 6)
          ],
        ),
      ),
    ],
  );

  Widget _buildReportPanel(DangerReport r) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCard.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: (r.isHighRisk
              ? AppColors.sosRed
              : AppColors.warningAmber)
              .withValues(alpha: 0.30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(r.typeEmoji,
                  style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.typeLabel,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      r.distanceKm < 1
                          ? '${(r.distanceKm * 1000).toInt()}m away'
                          : '${r.distanceKm.toStringAsFixed(1)}km away',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: Colors.white
                            .withValues(alpha: 0.40),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () =>
                    setState(() => _selected = null),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white
                        .withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: CustomPaint(
                      size: const Size(12, 12),
                      painter: _ClosePainter(
                          color: Colors.white
                              .withValues(alpha: 0.55)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (r.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              r.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.60),
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (r.isHighRisk
                      ? AppColors.sosRed
                      : AppColors.warningAmber)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${r.voteCount} reports',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: r.isHighRisk
                        ? AppColors.sosRed
                        : AppColors.warningAmber,
                  ),
                ),
              ),
              if (r.verified) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary
                        .withValues(alpha: 0.10),
                    borderRadius:
                    BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Verified',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _service.upvoteReport(r.id);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.sosRed
                        .withValues(alpha: 0.10),
                    borderRadius:
                    BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.sosRed
                            .withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      CustomPaint(
                        size: const Size(12, 12),
                        painter: _ThumbUpPainter(
                            color: AppColors.sosRed),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'Confirm',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: AppColors.sosRed,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    return ListenableBuilder(
      listenable: _service,
      builder: (_, __) {
        final stats = _service.stats;
        if (stats == null) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.darkCard.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color:
                Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceAround,
            children: [
              _statItem(
                  '${stats.activeReports}',
                  'Active',
                  AppColors.sosRed),
              _statItem(
                  '${stats.verifiedZones}',
                  'Verified',
                  AppColors.primary),
              _statItem(
                  '${stats.safetysScore.toInt()}%',
                  'Safe Score',
                  stats.safetysScore >= 70
                      ? AppColors.safeGreen
                      : stats.safetysScore >= 40
                      ? AppColors.warningAmber
                      : AppColors.sosRed),
            ],
          ),
        );
      },
    );
  }

  Widget _statItem(String val, String label, Color color) =>
      Column(
        children: [
          Text(
            val,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 9,
              color: Colors.grey,
            ),
          ),
        ],
      );
}

// ════════════════════════════════════════════════════════════════
// FILTER CHIP WIDGET
// ════════════════════════════════════════════════════════════════

class _FilterChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      HapticFeedback.selectionClick();
      onTap();
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.sosRed
            : AppColors.darkCard.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? AppColors.sosRed
              : Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji,
              style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Colors.grey,
            ),
          ),
        ],
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════
// MAP CONTROL BUTTON
// ════════════════════════════════════════════════════════════════

class _MapBtn extends StatelessWidget {
  final CustomPainter painter;
  final VoidCallback onTap;
  const _MapBtn({required this.painter, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        shape: BoxShape.circle,
        border: Border.all(
            color:
            Colors.white.withValues(alpha: 0.10)),
        boxShadow: AppColors.cardShadow,
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

// ════════════════════════════════════════════════════════════════
// ALL CUSTOM PAINTERS
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
        Offset(s.width * 0.80, cy), Offset(s.width * 0.20, cy), p);
    final h = Path();
    h.moveTo(s.width * 0.46, cy - s.height * 0.30);
    h.lineTo(s.width * 0.20, cy);
    h.lineTo(s.width * 0.46, cy + s.height * 0.30);
    canvas.drawPath(h, p);
  }
  @override
  bool shouldRepaint(_BackArrowPainter o) => false;
}

class _GpsCrosshairPainter extends CustomPainter {
  final Color color;
  const _GpsCrosshairPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), s.width * 0.28, p);
    canvas.drawCircle(
        Offset(cx, cy), s.width * 0.08, Paint()..color = color);
    canvas.drawLine(Offset(cx, 0), Offset(cx, s.height * 0.18), p);
    canvas.drawLine(
        Offset(cx, s.height * 0.82), Offset(cx, s.height), p);
    canvas.drawLine(Offset(0, cy), Offset(s.width * 0.18, cy), p);
    canvas.drawLine(
        Offset(s.width * 0.82, cy), Offset(s.width, cy), p);
  }
  @override
  bool shouldRepaint(_GpsCrosshairPainter o) => o.color != color;
}

class _RefreshIconPainter extends CustomPainter {
  final Color color;
  const _RefreshIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        Rect.fromLTWH(s.width * 0.10, s.height * 0.10,
            s.width * 0.80, s.height * 0.80),
        -math.pi * 0.5,
        math.pi * 1.5,
        false,
        p);
    final arr = Path();
    arr.moveTo(s.width * 0.50, 0);
    arr.lineTo(s.width * 0.72, s.height * 0.18);
    arr.moveTo(s.width * 0.50, 0);
    arr.lineTo(s.width * 0.28, s.height * 0.18);
    canvas.drawPath(arr, p);
  }
  @override
  bool shouldRepaint(_RefreshIconPainter o) => o.color != color;
}

class _PinAddPainter extends CustomPainter {
  final Color color;
  const _PinAddPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final pin = Path();
    pin.moveTo(s.width * 0.36, 0);
    pin.cubicTo(s.width * 0.14, 0, 0, s.height * 0.22,
        0, s.height * 0.42);
    pin.cubicTo(0, s.height * 0.60, s.width * 0.14,
        s.height * 0.74, s.width * 0.36, s.height * 0.86);
    pin.cubicTo(s.width * 0.58, s.height * 0.74,
        s.width * 0.72, s.height * 0.60, s.width * 0.72,
        s.height * 0.42);
    pin.cubicTo(s.width * 0.72, s.height * 0.22,
        s.width * 0.58, 0, s.width * 0.36, 0);
    pin.close();
    canvas.drawPath(pin, p);
    canvas.drawLine(Offset(s.width * 0.84, s.height * 0.36),
        Offset(s.width * 0.84, s.height * 0.76), p);
    canvas.drawLine(Offset(s.width * 0.64, s.height * 0.56),
        Offset(s.width * 1.04, s.height * 0.56), p);
  }
  @override
  bool shouldRepaint(_PinAddPainter o) => o.color != color;
}

class _ClosePainter extends CustomPainter {
  final Color color;
  const _ClosePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, 0), Offset(s.width, s.height), p);
    canvas.drawLine(Offset(s.width, 0), Offset(0, s.height), p);
  }
  @override
  bool shouldRepaint(_ClosePainter o) => o.color != color;
}

class _ThumbUpPainter extends CustomPainter {
  final Color color;
  const _ThumbUpPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final thumb = Path();
    thumb.moveTo(s.width * 0.10, s.height * 0.50);
    thumb.lineTo(s.width * 0.10, s.height);
    thumb.lineTo(s.width * 0.34, s.height);
    thumb.lineTo(s.width * 0.34, s.height * 0.50);
    thumb.lineTo(s.width * 0.52, s.height * 0.20);
    thumb.cubicTo(s.width * 0.60, s.height * 0.04,
        s.width * 0.84, s.height * 0.08, s.width * 0.82,
        s.height * 0.30);
    thumb.lineTo(s.width * 0.72, s.height * 0.30);
    thumb.lineTo(s.width * 0.90, s.height * 0.30);
    thumb.lineTo(s.width * 0.88, s.height * 0.56);
    thumb.lineTo(s.width * 0.34, s.height * 0.56);
    canvas.drawPath(thumb, p);
  }
  @override
  bool shouldRepaint(_ThumbUpPainter o) => o.color != color;
}

class _LocationPinSmallPainter extends CustomPainter {
  final Color color;
  const _LocationPinSmallPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path();
    path.moveTo(s.width * 0.50, 0);
    path.cubicTo(s.width * 0.18, 0, 0, s.height * 0.26,
        0, s.height * 0.46);
    path.cubicTo(0, s.height * 0.66, s.width * 0.18,
        s.height * 0.80, s.width * 0.50, s.height);
    path.cubicTo(s.width * 0.82, s.height * 0.80, s.width,
        s.height * 0.66, s.width, s.height * 0.46);
    path.cubicTo(s.width, s.height * 0.26, s.width * 0.82,
        0, s.width * 0.50, 0);
    path.close();
    canvas.drawPath(path, p);
    canvas.drawCircle(Offset(s.width / 2, s.height * 0.44),
        s.width * 0.14, Paint()..color = color);
  }
  @override
  bool shouldRepaint(_LocationPinSmallPainter o) =>
      o.color != color;
}

class _LargeCheckPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(s.width * 0.18, s.height * 0.52);
    path.lineTo(s.width * 0.42, s.height * 0.74);
    path.lineTo(s.width * 0.82, s.height * 0.28);
    canvas.drawPath(path, p);
  }
  @override
  bool shouldRepaint(_LargeCheckPainter o) => false;
}