// lib/features/location/tabs/live_map_tab.dart
// ─────────────────────────────────────────────────────────────────────────────
// LIVE MAP TAB — Real-time map with risk overlay, contact tracking
// ✅ Zero Material Icons — all CustomPainter
// ✅ All withValues(alpha:) — zero withOpacity()
// ✅ 100% matched to location_screen dark theme
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../providers/location_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/location/location_intelligence_service.dart';

class LiveMapTab extends StatefulWidget {
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
  final bool isDark;
  final VoidCallback onClearRoute;

  const LiveMapTab({
    super.key,
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
    required this.isDark,
    required this.onClearRoute,
  });

  @override
  State<LiveMapTab> createState() => _LiveMapTabState();
}

class _LiveMapTabState extends State<LiveMapTab>
    with TickerProviderStateMixin {
  RiskScore? _currentRisk;
  bool _loading = false;

  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRisk());
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRisk() async {
    final loc = widget.provider.current;
    if (loc == null || _loading) return;
    setState(() => _loading = true);
    try {
      final report = await LocationIntelligenceService.instance.generateReport(
        lat: loc.lat,
        lng: loc.lng,
        nearbyPlaces: widget.provider.nearbyPlaces,
      );
      if (mounted) setState(() => _currentRisk = report.riskScore);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Color get _riskColor {
    if (_currentRisk == null) return AppColors.safeGreen;
    final s = _currentRisk!.score;
    if (s < 0.3) return AppColors.safeGreen;
    if (s < 0.6) return AppColors.warningAmber;
    return AppColors.sosRed;
  }

  CustomPainter get _riskPainter {
    if (_currentRisk == null || (_currentRisk!.score) < 0.6) {
      return _ShieldCheckSmallPainter(color: Colors.white);
    }
    return _WarningTriSmallPainter(color: Colors.white);
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.provider.current;

    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: loc == null
                ? _LoadingMapView()
                : Stack(
              children: [
                // Map
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(loc.lat, loc.lng),
                    zoom: 15.5,
                  ),
                  onMapCreated: widget.onMapCreated,
                  mapType: widget.mapType,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: true,
                  tiltGesturesEnabled: true,
                  rotateGesturesEnabled: true,
                  markers: widget.allMarkers,
                  polylines: widget.polylines,
                  circles: widget.allCircles,
                ),

                // Risk badge (top left)
                if (_currentRisk != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _showRiskDialog();
                      },
                      child: AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (_, __) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _riskColor.withValues(
                              alpha: 0.80 + 0.10 * _pulseCtrl.value,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: _riskColor.withValues(alpha: 0.45),
                                blurRadius:
                                10 + 6 * _pulseCtrl.value,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CustomPaint(
                                size: const Size(12, 12),
                                painter: _riskPainter,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _currentRisk!.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // LIVE badge
                if (widget.provider.isSharing)
                  Positioned(
                    top: _currentRisk != null ? 48 : 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.darkCard
                            .withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.safeGreen
                              .withValues(alpha: 0.40),
                        ),
                      ),
                      child: const Text(
                        '● LIVE TRACKING',
                        style: TextStyle(
                          color: AppColors.safeGreen,
                          fontFamily: 'Poppins',
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                // Map controls (top right)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Column(
                    children: [
                      _MapControlBtn(
                        painter: _GpsCrosshairPainter(
                          color: widget.followUser
                              ? AppColors.primary
                              : Colors.grey,
                        ),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          widget.onFollowToggle();
                        },
                      ),
                      const SizedBox(height: 8),
                      _MapControlBtn(
                        painter: _SatelliteTogglePainter(
                          isSatellite:
                          widget.mapType == MapType.satellite,
                        ),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          widget.onMapTypeChange(
                            widget.mapType == MapType.normal
                                ? MapType.satellite
                                : MapType.normal,
                          );
                        },
                      ),
                      if (widget.polylines.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _MapControlBtn(
                          painter: _ClosePainter(
                              color: AppColors.sosRed),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            widget.onClearRoute();
                          },
                        ),
                      ],
                    ],
                  ),
                ),

                // Bottom address bar
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: AppColors.darkCard
                          .withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Row(
                      children: [
                        CustomPaint(
                          size: const Size(13, 13),
                          painter: _LocationDotPainter(
                              color: AppColors.primary),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            loc.address,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.provider.isSharing) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.safeGreen
                                  .withValues(alpha: 0.15),
                              borderRadius:
                              BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '● LIVE',
                              style: TextStyle(
                                color: AppColors.safeGreen,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Stats row
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Row(
            children: [
              _StatChip(
                painter: _SpeedGaugePainter(color: AppColors.secondary),
                value: loc != null
                    ? '${loc.speed.toStringAsFixed(1)}'
                    : '--',
                label: 'km/h',
                color: AppColors.secondary,
              ),
              const SizedBox(width: 6),
              _StatChip(
                painter:
                _GpsCrosshairPainter(color: AppColors.safeGreen),
                value: loc != null
                    ? '±${loc.accuracy.toStringAsFixed(0)}m'
                    : '--',
                label: 'accuracy',
                color: AppColors.safeGreen,
              ),
              const SizedBox(width: 6),
              _StatChip(
                painter: _PeopleSmallPainter(color: AppColors.primary),
                value:
                '${widget.provider.contactLocations.length}',
                label: 'contacts',
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              _StatChip(
                painter: _WarningTriSmallPainter(
                    color: AppColors.sosRed),
                value:
                '${widget.provider.allDangerZones.length}',
                label: 'zones',
                color: AppColors.sosRed,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showRiskDialog() {
    if (_currentRisk == null) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding:
        const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color:
              _riskColor.withValues(alpha: 0.30),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _riskColor.withValues(alpha: 0.15),
                      borderRadius:
                      BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: CustomPaint(
                        size: const Size(20, 20),
                        painter: _ShieldCheckSmallPainter(
                            color: _riskColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Area: ${_currentRisk!.label}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: _riskColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _currentRisk!.score,
                  backgroundColor:
                  Colors.white.withValues(alpha: 0.10),
                  valueColor: AlwaysStoppedAnimation(
                      _riskColor),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 12),
              if (_currentRisk!.factors.isNotEmpty)
                ..._currentRisk!.factors.map((f) => Padding(
                  padding:
                  const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.warningAmber,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          f,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Colors.white
                                .withValues(alpha: 0.72),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient:
                    AppColors.primaryGradient,
                    borderRadius:
                    BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'OK',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ════════════════════════════════════════════════════════════════

class _MapControlBtn extends StatelessWidget {
  final CustomPainter painter;
  final VoidCallback onTap;
  const _MapControlBtn(
      {required this.painter, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        shape: BoxShape.circle,
        border: Border.all(
          color:
          Colors.white.withValues(alpha: 0.10),
        ),
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

class _StatChip extends StatelessWidget {
  final CustomPainter painter;
  final String value;
  final String label;
  final Color color;
  const _StatChip({
    required this.painter,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding:
      const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
          Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomPaint(
            size: const Size(14, 14),
            painter: painter,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontFamily: 'Poppins',
              fontSize: 12,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 8,
              fontFamily: 'Poppins',
              color: Colors.grey,
            ),
          ),
        ],
      ),
    ),
  );
}

class _LoadingMapView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.darkCard,
    child: const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
              color: AppColors.primary),
          SizedBox(height: 14),
          Text(
            'Getting your location...',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Allow location permission if prompted',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════
// ALL CUSTOM PAINTERS
// ════════════════════════════════════════════════════════════════

class _ShieldCheckSmallPainter extends CustomPainter {
  final Color color;
  const _ShieldCheckSmallPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final path = Path();
    path.moveTo(s.width * 0.50, 0);
    path.lineTo(s.width, s.height * 0.22);
    path.cubicTo(s.width, s.height * 0.22, s.width * 0.98,
        s.height * 0.72, s.width * 0.50, s.height);
    path.cubicTo(s.width * 0.02, s.height * 0.72, 0,
        s.height * 0.22, 0, s.height * 0.22);
    path.close();
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeJoin = StrokeJoin.round);
    final check = Path();
    check.moveTo(s.width * 0.28, s.height * 0.52);
    check.lineTo(s.width * 0.44, s.height * 0.68);
    check.lineTo(s.width * 0.72, s.height * 0.36);
    canvas.drawPath(
        check,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
  }
  @override
  bool shouldRepaint(_ShieldCheckSmallPainter o) =>
      o.color != color;
}

class _WarningTriSmallPainter extends CustomPainter {
  final Color color;
  const _WarningTriSmallPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final path = Path();
    path.moveTo(cx, s.height * 0.04);
    path.lineTo(s.width * 0.96, s.height * 0.94);
    path.lineTo(s.width * 0.04, s.height * 0.94);
    path.close();
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeJoin = StrokeJoin.round);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(
                cx - 1.5, s.height * 0.36, 3, s.height * 0.28),
            const Radius.circular(1.5)),
        Paint()..color = color);
    canvas.drawCircle(
        Offset(cx, s.height * 0.78), 2.5,
        Paint()..color = color);
  }
  @override
  bool shouldRepaint(_WarningTriSmallPainter o) =>
      o.color != color;
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
    canvas.drawLine(Offset(cx, 0), Offset(cx, s.height * 0.20), p);
    canvas.drawLine(
        Offset(cx, s.height * 0.80), Offset(cx, s.height), p);
    canvas.drawLine(Offset(0, cy), Offset(s.width * 0.20, cy), p);
    canvas.drawLine(
        Offset(s.width * 0.80, cy), Offset(s.width, cy), p);
  }
  @override
  bool shouldRepaint(_GpsCrosshairPainter o) => o.color != color;
}

class _SatelliteTogglePainter extends CustomPainter {
  final bool isSatellite;
  const _SatelliteTogglePainter({required this.isSatellite});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = isSatellite ? AppColors.primary : AppColors.secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    if (isSatellite) {
      // Map pin icon
      final path = Path();
      path.moveTo(s.width * 0.50, 0);
      path.cubicTo(s.width * 0.18, 0, 0, s.height * 0.26, 0,
          s.height * 0.46);
      path.cubicTo(0, s.height * 0.66, s.width * 0.18,
          s.height * 0.80, s.width * 0.50, s.height);
      path.cubicTo(s.width * 0.82, s.height * 0.80, s.width,
          s.height * 0.66, s.width, s.height * 0.46);
      path.cubicTo(s.width, s.height * 0.26, s.width * 0.82, 0,
          s.width * 0.50, 0);
      path.close();
      canvas.drawPath(path, p);
      canvas.drawCircle(Offset(s.width / 2, s.height * 0.44),
          s.width * 0.14, Paint()..color = p.color);
    } else {
      // Satellite icon
      canvas.drawRect(
          Rect.fromLTWH(s.width * 0.30, s.height * 0.30,
              s.width * 0.40, s.height * 0.40),
          p);
      canvas.drawLine(Offset(0, s.height * 0.50),
          Offset(s.width * 0.28, s.height * 0.50), p);
      canvas.drawLine(Offset(s.width * 0.72, s.height * 0.50),
          Offset(s.width, s.height * 0.50), p);
      canvas.drawLine(Offset(s.width * 0.50, 0),
          Offset(s.width * 0.50, s.height * 0.28), p);
      canvas.drawCircle(Offset(s.width * 0.50, s.height * 0.10),
          2.0, Paint()..color = p.color);
    }
  }
  @override
  bool shouldRepaint(_SatelliteTogglePainter o) =>
      o.isSatellite != isSatellite;
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

class _LocationDotPainter extends CustomPainter {
  final Color color;
  const _LocationDotPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path();
    path.moveTo(s.width * 0.50, 0);
    path.cubicTo(s.width * 0.18, 0, 0, s.height * 0.26, 0,
        s.height * 0.46);
    path.cubicTo(0, s.height * 0.66, s.width * 0.18,
        s.height * 0.80, s.width * 0.50, s.height);
    path.cubicTo(s.width * 0.82, s.height * 0.80, s.width,
        s.height * 0.66, s.width, s.height * 0.46);
    path.cubicTo(s.width, s.height * 0.26, s.width * 0.82, 0,
        s.width * 0.50, 0);
    path.close();
    canvas.drawPath(path, p);
    canvas.drawCircle(Offset(s.width / 2, s.height * 0.44),
        s.width * 0.14, Paint()..color = color);
  }
  @override
  bool shouldRepaint(_LocationDotPainter o) => o.color != color;
}

class _SpeedGaugePainter extends CustomPainter {
  final Color color;
  const _SpeedGaugePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        Rect.fromCircle(
            center: Offset(cx, cy), radius: s.width * 0.46),
        math.pi,
        math.pi,
        false,
        p);
    canvas.drawLine(Offset(cx, cy),
        Offset(cx + s.width * 0.28, cy - s.height * 0.18), p);
    canvas.drawCircle(
        Offset(cx, cy), 2.5, Paint()..color = color);
  }
  @override
  bool shouldRepaint(_SpeedGaugePainter o) => o.color != color;
}

class _PeopleSmallPainter extends CustomPainter {
  final Color color;
  const _PeopleSmallPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(
        Offset(s.width * 0.36, s.height * 0.28), s.width * 0.16, p);
    final b = Path();
    b.moveTo(0, s.height);
    b.quadraticBezierTo(
        0, s.height * 0.60, s.width * 0.36, s.height * 0.60);
    b.quadraticBezierTo(
        s.width * 0.68, s.height * 0.60, s.width * 0.68, s.height);
    canvas.drawPath(b, p);
    canvas.drawCircle(Offset(s.width * 0.76, s.height * 0.22),
        s.width * 0.13,
        Paint()
          ..color = color.withValues(alpha: 0.60)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1);
  }
  @override
  bool shouldRepaint(_PeopleSmallPainter o) => o.color != color;
}