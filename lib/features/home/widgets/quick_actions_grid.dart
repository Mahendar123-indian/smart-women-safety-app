// lib/features/home/widgets/quick_actions_grid.dart
// ─────────────────────────────────────────────────────────────────────────────
// QUICK ACTIONS GRID — Full Custom Painters · Zero Material Icons
// 6 action cards in 3 rows × 2 cols:
//   Row 1 → Share Location · Plan Journey
//   Row 2 → Quick SOS     · Silent SOS
//   Row 3 → Call Police   · Report Zone
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../sos/providers/sos_provider.dart';
import '../../location/providers/location_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════
// QUICK ACTIONS GRID
// ═══════════════════════════════════════════════════════════════════════════

class QuickActionsGrid extends StatelessWidget {
  final bool isDark;
  const QuickActionsGrid({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final location = context.watch<LocationProvider>();
    final sos = context.watch<SosProvider>();

    return Column(
      children: [
        // ── Row 1 ─────────────────────────────────────────────────────────
        Row(
          children: [
            _ActionBtn(
              isDark: isDark,
              painter: _ShareLocationPainter(color: AppColors.secondary),
              label: 'Share Location',
              sub: location.isSharing ? '● Live now' : 'Start sharing',
              color: AppColors.secondary,
              active: location.isSharing,
              onTap: () {
                HapticFeedback.selectionClick();
                location.isSharing
                    ? location.stopSharing()
                    : location.startSharing();
              },
            ),
            const SizedBox(width: 10),
            _ActionBtn(
              isDark: isDark,
              painter: _JourneyPainter(color: AppColors.safeGreen),
              label: 'Plan Journey',
              sub: location.isJourneyActive ? '● Active' : 'Set destination',
              color: AppColors.safeGreen,
              active: location.isJourneyActive,
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.pushNamed(context, AppRouter.location);
              },
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Row 2 ─────────────────────────────────────────────────────────
        Row(
          children: [
            _ActionBtn(
              isDark: isDark,
              painter: _SosRingPainter(color: AppColors.sosRed),
              label: 'Quick SOS',
              sub: 'Alert all contacts',
              color: AppColors.sosRed,
              active: false,
              onTap: () {
                HapticFeedback.heavyImpact();
                Navigator.pushNamed(context, AppRouter.sos);
              },
            ),
            const SizedBox(width: 10),
            _ActionBtn(
              isDark: isDark,
              painter: _SilentSosPainter(color: AppColors.warningAmber),
              label: 'Silent SOS',
              sub: 'No alarm mode',
              color: AppColors.warningAmber,
              active: false,
              onTap: () {
                HapticFeedback.heavyImpact();
                sos.triggerSilentSOS();
                Navigator.pushNamed(context, AppRouter.sos);
              },
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Row 3 ─────────────────────────────────────────────────────────
        Row(
          children: [
            _ActionBtn(
              isDark: isDark,
              painter: _PoliceBadgePainter(color: const Color(0xFF1565C0)),
              label: 'Call Police',
              sub: 'Dial 112',
              color: const Color(0xFF1565C0),
              active: false,
              onTap: () async {
                HapticFeedback.heavyImpact();
                final uri = Uri.parse('tel:112');
                if (await canLaunchUrl(uri)) launchUrl(uri);
              },
            ),
            const SizedBox(width: 10),
            _ActionBtn(
              isDark: isDark,
              painter: _ReportZonePainter(color: AppColors.accent),
              label: 'Report Zone',
              sub: 'Mark as danger',
              color: AppColors.accent,
              active: false,
              onTap: () {
                HapticFeedback.selectionClick();
                context.read<LocationProvider>().reportDangerZone();
              },
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ACTION BUTTON WIDGET
// ═══════════════════════════════════════════════════════════════════════════

class _ActionBtn extends StatelessWidget {
  final bool isDark;
  final CustomPainter painter;
  final String label;
  final String sub;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.isDark,
    required this.painter,
    required this.label,
    required this.sub,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: 0.10)
                : isDark
                ? AppColors.darkCard
                : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppColors.cardShadow,
            border: active
                ? Border.all(color: color.withValues(alpha: 0.45), width: 1.2)
                : Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : AppColors.lightBorder,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon + active dot
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: active
                          ? color.withValues(alpha: 0.18)
                          : color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: CustomPaint(
                        size: const Size(20, 20),
                        painter: painter,
                      ),
                    ),
                  ),
                  if (active)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.55),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Label
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: isDark ? Colors.white : AppColors.lightText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),

              // Sub
              Text(
                sub,
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Poppins',
                  color: active
                      ? color
                      : isDark
                      ? Colors.white.withValues(alpha: 0.38)
                      : AppColors.lightTextSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ALL CUSTOM PAINTERS — ZERO MATERIAL ICONS
// ═══════════════════════════════════════════════════════════════════════════

/// Location pin with share arrow
class _ShareLocationPainter extends CustomPainter {
  final Color color;
  const _ShareLocationPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Location pin (left-center)
    final pin = Path();
    pin.moveTo(s.width * 0.34, 0);
    pin.cubicTo(s.width * 0.12, 0, 0, s.height * 0.22,
        0, s.height * 0.40);
    pin.cubicTo(0, s.height * 0.58, s.width * 0.12,
        s.height * 0.72, s.width * 0.34, s.height * 0.82);
    pin.cubicTo(s.width * 0.56, s.height * 0.72, s.width * 0.68,
        s.height * 0.58, s.width * 0.68, s.height * 0.40);
    pin.cubicTo(s.width * 0.68, s.height * 0.22, s.width * 0.56,
        0, s.width * 0.34, 0);
    pin.close();
    canvas.drawPath(pin, p);
    canvas.drawCircle(Offset(s.width * 0.34, s.height * 0.38),
        s.width * 0.09, Paint()..color = color);

    // Share arrow (right side)
    canvas.drawLine(
      Offset(s.width * 0.72, s.height * 0.38),
      Offset(s.width * 0.97, s.height * 0.38),
      p,
    );
    final arrowHead = Path();
    arrowHead.moveTo(s.width * 0.78, s.height * 0.24);
    arrowHead.lineTo(s.width * 0.97, s.height * 0.38);
    arrowHead.lineTo(s.width * 0.78, s.height * 0.52);
    canvas.drawPath(arrowHead, p);
  }

  @override
  bool shouldRepaint(_ShareLocationPainter o) => o.color != color;
}

/// Start dot → curved route → flag destination
class _JourneyPainter extends CustomPainter {
  final Color color;
  const _JourneyPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Start filled circle
    canvas.drawCircle(
      Offset(s.width * 0.18, s.height * 0.22),
      s.width * 0.10,
      Paint()..color = color,
    );
    canvas.drawCircle(
      Offset(s.width * 0.18, s.height * 0.22),
      s.width * 0.10,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Curved dashed route
    final routePath = Path();
    routePath.moveTo(s.width * 0.18, s.height * 0.32);
    routePath.cubicTo(
      s.width * 0.18, s.height * 0.65,
      s.width * 0.75, s.height * 0.55,
      s.width * 0.75, s.height * 0.82,
    );
    canvas.drawPath(
      routePath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round,
    );

    // Flag pole at destination
    canvas.drawLine(
      Offset(s.width * 0.75, s.height * 0.08),
      Offset(s.width * 0.75, s.height * 0.58),
      p,
    );
    // Flag banner
    final flag = Path();
    flag.moveTo(s.width * 0.75, s.height * 0.08);
    flag.lineTo(s.width * 0.98, s.height * 0.20);
    flag.lineTo(s.width * 0.75, s.height * 0.32);
    flag.close();
    canvas.drawPath(flag, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_JourneyPainter o) => o.color != color;
}

/// SOS ring — concentric circles with SOS text
class _SosRingPainter extends CustomPainter {
  final Color color;
  const _SosRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;

    // Outer faint ring
    canvas.drawCircle(
      Offset(cx, cy),
      s.width * 0.47,
      Paint()
        ..color = color.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Inner solid ring
    canvas.drawCircle(
      Offset(cx, cy),
      s.width * 0.34,
      Paint()
        ..color = color.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      s.width * 0.34,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // SOS text inside
    final tp = TextPainter(
      text: TextSpan(
        text: 'SOS',
        style: TextStyle(
          color: color,
          fontSize: s.width * 0.28,
          fontWeight: FontWeight.w900,
          fontFamily: 'Poppins',
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(cx - tp.width / 2, cy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(_SosRingPainter o) => o.color != color;
}

/// Speaker with a mute/slash — silent SOS
class _SilentSosPainter extends CustomPainter {
  final Color color;
  const _SilentSosPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Speaker cone body
    final speaker = Path();
    speaker.moveTo(s.width * 0.30, s.height * 0.32);
    speaker.lineTo(s.width * 0.14, s.height * 0.32);
    speaker.lineTo(s.width * 0.14, s.height * 0.68);
    speaker.lineTo(s.width * 0.30, s.height * 0.68);
    speaker.lineTo(s.width * 0.58, s.height * 0.88);
    speaker.lineTo(s.width * 0.58, s.height * 0.12);
    speaker.close();
    canvas.drawPath(speaker, p);

    // Mute slash — diagonal line over right half
    canvas.drawLine(
      Offset(s.width * 0.68, s.height * 0.18),
      Offset(s.width * 0.96, s.height * 0.82),
      Paint()
        ..color = color
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );

    // SOS small text at bottom-right
    final tp = TextPainter(
      text: TextSpan(
        text: 'SOS',
        style: TextStyle(
          color: color,
          fontSize: s.width * 0.20,
          fontWeight: FontWeight.w900,
          fontFamily: 'Poppins',
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(s.width * 0.62 - tp.width / 2, s.height * 0.75),
    );
  }

  @override
  bool shouldRepaint(_SilentSosPainter o) => o.color != color;
}

/// Police badge (hexagon + star center + phone receiver)
class _PoliceBadgePainter extends CustomPainter {
  final Color color;
  const _PoliceBadgePainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height * 0.46;
    final r = s.width * 0.46;

    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Hexagon badge
    final badge = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i - math.pi / 6;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) badge.moveTo(x, y);
      else badge.lineTo(x, y);
    }
    badge.close();
    canvas.drawPath(badge, p);

    // Inner star (5-point)
    final starPath = Path();
    const n = 5;
    final outerR = s.width * 0.18;
    final innerR = s.width * 0.08;
    for (int i = 0; i < n * 2; i++) {
      final angle = (i * math.pi / n) - math.pi / 2;
      final radius = i.isEven ? outerR : innerR;
      final x = cx + radius * math.cos(angle);
      final y = cy + radius * math.sin(angle);
      if (i == 0) starPath.moveTo(x, y);
      else starPath.lineTo(x, y);
    }
    starPath.close();
    canvas.drawPath(starPath, Paint()..color = color..style = PaintingStyle.fill);

    // Phone icon small at bottom
    final phoneP = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final phone = Path();
    phone.moveTo(s.width * 0.34, s.height * 0.82);
    phone.quadraticBezierTo(s.width * 0.28, s.height * 0.88,
        s.width * 0.30, s.height * 0.94);
    phone.quadraticBezierTo(s.width * 0.32, s.height * 1.0,
        s.width * 0.38, s.height * 0.96);
    phone.quadraticBezierTo(s.width * 0.52, s.height * 0.88,
        s.width * 0.58, s.height * 0.82);
    phone.quadraticBezierTo(s.width * 0.64, s.height * 0.76,
        s.width * 0.60, s.height * 0.72);
    phone.quadraticBezierTo(s.width * 0.56, s.height * 0.68,
        s.width * 0.50, s.height * 0.74);
    phone.quadraticBezierTo(s.width * 0.38, s.height * 0.64,
        s.width * 0.32, s.height * 0.76);
    canvas.drawPath(phone, phoneP);
  }

  @override
  bool shouldRepaint(_PoliceBadgePainter o) => o.color != color;
}

/// Location pin with exclamation + plus sign for report zone
class _ReportZonePainter extends CustomPainter {
  final Color color;
  const _ReportZonePainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Location pin (smaller, left-offset)
    final pin = Path();
    pin.moveTo(s.width * 0.32, 0);
    pin.cubicTo(s.width * 0.10, 0, 0, s.height * 0.20,
        0, s.height * 0.38);
    pin.cubicTo(0, s.height * 0.56, s.width * 0.10,
        s.height * 0.70, s.width * 0.32, s.height * 0.80);
    pin.cubicTo(s.width * 0.54, s.height * 0.70, s.width * 0.64,
        s.height * 0.56, s.width * 0.64, s.height * 0.38);
    pin.cubicTo(s.width * 0.64, s.height * 0.20, s.width * 0.54,
        0, s.width * 0.32, 0);
    pin.close();
    canvas.drawPath(pin, p);

    // Exclamation ! inside pin
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * 0.29, s.height * 0.14, s.width * 0.06,
            s.height * 0.24),
        const Radius.circular(1.5),
      ),
      Paint()..color = color,
    );
    canvas.drawCircle(
      Offset(s.width * 0.32, s.height * 0.50),
      s.width * 0.04,
      Paint()..color = color,
    );

    // Plus sign (top-right) for "add/report"
    canvas.drawLine(
      Offset(s.width * 0.80, s.height * 0.30),
      Offset(s.width * 0.80, s.height * 0.70),
      Paint()
        ..color = color
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(s.width * 0.60, s.height * 0.50),
      Offset(s.width * 1.00, s.height * 0.50),
      Paint()
        ..color = color
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ReportZonePainter o) => o.color != color;
}