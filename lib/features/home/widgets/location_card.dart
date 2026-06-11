// lib/features/home/widgets/location_card.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../location/providers/location_provider.dart';

class LocationCard extends StatelessWidget {
  final LocationProvider location;
  final bool isDark;

  const LocationCard({super.key, required this.location, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final loc = location.current;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: location.isSharing
                      ? AppColors.safeGradient
                      : AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: (location.isSharing
                          ? AppColors.safeGreen
                          : AppColors.primary)
                          .withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: CustomPaint(
                    size: const Size(22, 22),
                    painter: location.isJourneyActive
                        ? _RouteIconPainter(color: Colors.white)
                        : _LocationPinPainter(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.isJourneyActive
                          ? location.journey?.destinationName ?? 'Journey Active'
                          : 'Current Location',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: isDark ? Colors.white : AppColors.lightText,
                      ),
                    ),
                    Text(
                      loc?.address ?? 'Fetching location…',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.40)
                            : AppColors.lightTextSecondary,
                        fontSize: 11,
                        fontFamily: 'Poppins',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Live toggle
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  location.isSharing
                      ? location.stopSharing()
                      : location.startSharing();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (location.isSharing
                        ? AppColors.safeGreen
                        : Colors.grey)
                        .withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (location.isSharing
                          ? AppColors.safeGreen
                          : Colors.grey)
                          .withValues(alpha: 0.30),
                    ),
                  ),
                  child: Text(
                    location.isSharing ? '● LIVE' : '○ OFF',
                    style: TextStyle(
                      color: location.isSharing
                          ? AppColors.safeGreen
                          : Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Stats row if location available
          if (loc != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _Stat(
                  painter: _SpeedIconPainter(color: AppColors.secondary),
                  value: '${loc.speed.toStringAsFixed(1)} km/h',
                  label: 'Speed',
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 8),
                _Stat(
                  painter: _GpsPrecisionPainter(color: AppColors.safeGreen),
                  value: '±${loc.accuracy.toInt()}m',
                  label: 'Accuracy',
                  color: AppColors.safeGreen,
                ),
                const SizedBox(width: 8),
                _Stat(
                  painter: _HeadingIconPainter(color: AppColors.primary),
                  value: '${loc.heading.toInt()}°',
                  label: 'Heading',
                  color: AppColors.primary,
                ),
              ],
            ),
          ],

          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.pushNamed(context, AppRouter.location);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomPaint(
                    size: const Size(14, 14),
                    painter: _MapOpenPainter(color: AppColors.primary),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Open Full Map',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final CustomPainter painter;
  final String value;
  final String label;
  final Color color;

  const _Stat({
    required this.painter,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          CustomPaint(
            size: const Size(13, 13),
            painter: painter,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.60),
                    fontFamily: 'Poppins',
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════
// PAINTERS
// ════════════════════════════════════════════════════════════════

class _LocationPinPainter extends CustomPainter {
  final Color color;
  const _LocationPinPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(s.width * 0.50, 0);
    path.cubicTo(s.width * 0.18, 0, 0, s.height * 0.26,
        0, s.height * 0.48);
    path.cubicTo(0, s.height * 0.68, s.width * 0.18,
        s.height * 0.82, s.width * 0.50, s.height);
    path.cubicTo(s.width * 0.82, s.height * 0.82, s.width,
        s.height * 0.68, s.width, s.height * 0.48);
    path.cubicTo(s.width, s.height * 0.26, s.width * 0.82,
        0, s.width * 0.50, 0);
    path.close();
    canvas.drawPath(path, p);
    canvas.drawCircle(Offset(s.width / 2, s.height * 0.46),
        s.width * 0.16, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LocationPinPainter o) => o.color != color;
}

class _RouteIconPainter extends CustomPainter {
  final Color color;
  const _RouteIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Start circle
    canvas.drawCircle(Offset(s.width * 0.22, s.height * 0.22),
        s.width * 0.12, p);
    // End pin
    final pin = Path();
    pin.moveTo(s.width * 0.78, s.height * 0.30);
    pin.cubicTo(s.width * 0.60, s.height * 0.30, s.width * 0.60,
        s.height * 0.60, s.width * 0.78, s.height * 0.72);
    pin.cubicTo(s.width * 0.96, s.height * 0.60, s.width * 0.96,
        s.height * 0.30, s.width * 0.78, s.height * 0.30);
    canvas.drawPath(pin, p);

    // Curved path between
    final route = Path();
    route.moveTo(s.width * 0.22, s.height * 0.34);
    route.cubicTo(s.width * 0.22, s.height * 0.60,
        s.width * 0.78, s.height * 0.60, s.width * 0.78, s.height * 0.85);
    canvas.drawPath(route, p);

    // Arrow at end
    canvas.drawLine(Offset(s.width * 0.68, s.height * 0.76),
        Offset(s.width * 0.78, s.height * 0.88), p);
    canvas.drawLine(Offset(s.width * 0.88, s.height * 0.76),
        Offset(s.width * 0.78, s.height * 0.88), p);
  }

  @override
  bool shouldRepaint(_RouteIconPainter o) => o.color != color;
}

class _SpeedIconPainter extends CustomPainter {
  final Color color;
  const _SpeedIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height * 0.60;
    final r  = s.width * 0.44;
    final p  = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        3.14, 3.14, false, p);

    canvas.drawLine(
        Offset(cx, cy),
        Offset(cx - r * 0.30, cy - r * 0.70),
        Paint()
          ..color = color
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round);

    canvas.drawCircle(Offset(cx, cy), 2.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SpeedIconPainter o) => o.color != color;
}

class _GpsPrecisionPainter extends CustomPainter {
  final Color color;
  const _GpsPrecisionPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    final p  = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(cx, cy), s.width * 0.30, p);
    canvas.drawCircle(Offset(cx, cy), s.width * 0.08,
        Paint()..color = color);
    canvas.drawLine(Offset(cx, 0), Offset(cx, s.height * 0.20), p);
    canvas.drawLine(
        Offset(cx, s.height * 0.80), Offset(cx, s.height), p);
    canvas.drawLine(Offset(0, cy), Offset(s.width * 0.20, cy), p);
    canvas.drawLine(
        Offset(s.width * 0.80, cy), Offset(s.width, cy), p);
  }

  @override
  bool shouldRepaint(_GpsPrecisionPainter o) => o.color != color;
}

class _HeadingIconPainter extends CustomPainter {
  final Color color;
  const _HeadingIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Arrow head pointing up
    final arrow = Path();
    arrow.moveTo(s.width * 0.50, 0);
    arrow.lineTo(s.width, s.height * 0.65);
    arrow.lineTo(s.width * 0.50, s.height * 0.45);
    arrow.lineTo(0, s.height * 0.65);
    arrow.close();
    canvas.drawPath(arrow, p);

    // Tail
    canvas.drawLine(
      Offset(s.width * 0.50, s.height * 0.45),
      Offset(s.width * 0.50, s.height),
      p,
    );
  }

  @override
  bool shouldRepaint(_HeadingIconPainter o) => o.color != color;
}

class _MapOpenPainter extends CustomPainter {
  final Color color;
  const _MapOpenPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Map outline
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, s.width, s.height),
            const Radius.circular(2)),
        p);
    // Location dot
    canvas.drawCircle(
        Offset(s.width * 0.50, s.height * 0.44), s.width * 0.10,
        Paint()..color = color);
    // Grid lines
    canvas.drawLine(Offset(s.width * 0.33, 0),
        Offset(s.width * 0.33, s.height),
        Paint()
          ..color = color.withValues(alpha: 0.30)
          ..strokeWidth = 0.8);
    canvas.drawLine(Offset(0, s.height * 0.50),
        Offset(s.width, s.height * 0.50),
        Paint()
          ..color = color.withValues(alpha: 0.30)
          ..strokeWidth = 0.8);
  }

  @override
  bool shouldRepaint(_MapOpenPainter o) => o.color != color;
}