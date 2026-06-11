// lib/features/home/widgets/safety_tools_row.dart
// ─────────────────────────────────────────────────────────────────────────────
// SAFETY TOOLS ROW — Full Custom Painters · Zero Material Icons
// 3 gradient cards: Nearest Places · Fake Call Escape · Offline SOS SMS
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/offline_sos_service.dart';
import '../../contacts/providers/contact_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SAFETY TOOLS ROW
// ═══════════════════════════════════════════════════════════════════════════

class SafetyToolsRow extends StatelessWidget {
  final bool isDark;
  const SafetyToolsRow({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final contacts = context.watch<ContactProvider>();

    // FIX: Wrap in IntrinsicHeight so that CrossAxisAlignment.stretch
    // gets a bounded height to work with inside a SliverList.
    //
    // Root cause of the crash:
    //   A SliverList item receives BoxConstraints(w=328, 0<=h<=∞).
    //   Row with crossAxisAlignment: stretch tells each child "be as tall
    //   as the tallest sibling." Flutter must first measure all children
    //   unconstrained to find the tallest, then re-layout them at that
    //   height. When the height is infinite, this measurement loop cannot
    //   resolve → "BoxConstraints forces an infinite height" → crash.
    //
    // IntrinsicHeight resolves this by first doing an "intrinsic size"
    // pass on all children (which returns finite values because _ToolCard
    // uses Column + MainAxisSize.min with concrete content), then sets
    // the Row's height to the maximum of those intrinsic heights, giving
    // the Row a concrete, bounded height before it lays out its children.
    //
    // Note: IntrinsicHeight is slightly more expensive than a fixed
    // SizedBox because it does two layout passes. For a row of 3 static
    // cards rendered once per scroll frame this cost is negligible.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 1. Nearest Safety Places ──────────────────────────────────────
          _ToolCard(
            painter: _HospitalCrossPainter(),
            label: 'Nearest\nPlaces',
            sub: 'Hospitals · Police',
            gradient: const LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            accentColor: const Color(0xFF1976D2),
            badge: null,
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.pushNamed(context, AppRouter.nearestSafetyPlaces);
            },
          ),
          const SizedBox(width: 10),

          // ── 2. Fake Call Escape ───────────────────────────────────────────
          _ToolCard(
            painter: _FakeCallPainter(),
            label: 'Fake Call\nEscape',
            sub: 'Discreet exit',
            gradient: const LinearGradient(
              colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            accentColor: const Color(0xFF7B1FA2),
            badge: null,
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.pushNamed(context, AppRouter.fakeCall);
            },
          ),
          const SizedBox(width: 10),

          // ── 3. Offline SOS SMS ────────────────────────────────────────────
          _ToolCard(
            painter: _OfflineSmsPainter(),
            label: 'Offline\nSOS SMS',
            sub: 'No internet needed',
            gradient: const LinearGradient(
              colors: [Color(0xFFB71C1C), Color(0xFFE53935)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            accentColor: AppColors.sosRed,
            badge: contacts.activeCount > 0
                ? '${contacts.activeCount}'
                : null,
            onTap: () async {
              HapticFeedback.heavyImpact();
              final list = contacts.contacts
                  .map((c) => {'name': c.name, 'phone': c.phone})
                  .toList();
              final sent = await OfflineSosService.instance.triggerOfflineSOS(
                triggerType: 'manual_offline',
                contacts: list,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        CustomPaint(
                          size: const Size(16, 16),
                          painter: sent
                              ? _CheckCircleSmallPainter(color: Colors.white)
                              : _WarningSmallPainter(color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            sent
                                ? 'Emergency SMS sent to all contacts!'
                                : 'No contacts found. Add emergency contacts first.',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor:
                    sent ? AppColors.safeGreen : AppColors.sosRed,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TOOL CARD WIDGET
// ═══════════════════════════════════════════════════════════════════════════

class _ToolCard extends StatelessWidget {
  final CustomPainter painter;
  final String label;
  final String sub;
  final LinearGradient gradient;
  final Color accentColor;
  final String? badge;
  final VoidCallback onTap;

  const _ToolCard({
    required this.painter,
    required this.label,
    required this.sub,
    required this.gradient,
    required this.accentColor,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.38),
                blurRadius: 14,
                offset: const Offset(0, 6),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon box + optional badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Center(
                      child: CustomPaint(
                        size: const Size(20, 20),
                        painter: painter,
                      ),
                    ),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins',
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 9),

              // Label
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 3),

              // Sub
              Text(
                sub,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontFamily: 'Poppins',
                  fontSize: 9,
                  height: 1.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 8),

              // Bottom arrow indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CustomPaint(
                    size: const Size(12, 12),
                    painter: _ArrowRightSmallPainter(
                        color: Colors.white.withValues(alpha: 0.55)),
                  ),
                ],
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

/// Hospital cross / plus in a rounded square
class _HospitalCrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Outer rounded square
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, s.width, s.height),
        Radius.circular(s.width * 0.22),
      ),
      p,
    );

    // Cross / plus inside
    final crossP = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    // Vertical bar
    canvas.drawLine(
      Offset(s.width * 0.50, s.height * 0.22),
      Offset(s.width * 0.50, s.height * 0.78),
      crossP,
    );
    // Horizontal bar
    canvas.drawLine(
      Offset(s.width * 0.22, s.height * 0.50),
      Offset(s.width * 0.78, s.height * 0.50),
      crossP,
    );
  }

  @override
  bool shouldRepaint(_HospitalCrossPainter o) => false;
}

/// Phone receiver with a sparkle — Fake Call icon
class _FakeCallPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Phone handset path
    final phone = Path();
    phone.moveTo(s.width * 0.14, s.height * 0.10);
    phone.lineTo(s.width * 0.14, s.height * 0.32);
    phone.quadraticBezierTo(
      s.width * 0.14, s.height * 0.44,
      s.width * 0.22, s.height * 0.50,
    );
    phone.quadraticBezierTo(
      s.width * 0.50, s.height * 0.78,
      s.width * 0.62, s.height * 0.86,
    );
    phone.quadraticBezierTo(
      s.width * 0.68, s.height * 0.92,
      s.width * 0.80, s.height * 0.92,
    );
    phone.lineTo(s.width * 0.90, s.height * 0.92);
    phone.quadraticBezierTo(
      s.width, s.height * 0.92,
      s.width, s.height * 0.80,
    );
    phone.lineTo(s.width, s.height * 0.70);
    phone.quadraticBezierTo(
      s.width, s.height * 0.58,
      s.width * 0.88, s.height * 0.58,
    );
    phone.lineTo(s.width * 0.78, s.height * 0.58);
    phone.quadraticBezierTo(
      s.width * 0.66, s.height * 0.58,
      s.width * 0.66, s.height * 0.68,
    );
    phone.lineTo(s.width * 0.66, s.height * 0.68);
    canvas.drawPath(phone, p);

    // Sparkle lines (fake/magic indicator) top-right corner
    final sp = Paint()
      ..color = Colors.white.withValues(alpha: 0.80)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(s.width * 0.72, s.height * 0.08),
      Offset(s.width * 0.72, 0),
      sp,
    );
    canvas.drawLine(
      Offset(s.width * 0.82, s.height * 0.12),
      Offset(s.width * 0.92, s.height * 0.04),
      sp,
    );
    canvas.drawLine(
      Offset(s.width * 0.88, s.height * 0.22),
      Offset(s.width, s.height * 0.22),
      sp,
    );
  }

  @override
  bool shouldRepaint(_FakeCallPainter o) => false;
}

/// Signal tower / antenna for offline SMS
class _OfflineSmsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Vertical antenna pole
    canvas.drawLine(
      Offset(s.width * 0.50, s.height * 0.08),
      Offset(s.width * 0.50, s.height * 0.75),
      p,
    );

    // 3 signal arcs
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(s.width * 0.50, s.height * 0.75),
        width: s.width * 0.84,
        height: s.height * 0.84,
      ),
      math.pi, math.pi, false, p,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(s.width * 0.50, s.height * 0.75),
        width: s.width * 0.56,
        height: s.height * 0.56,
      ),
      math.pi, math.pi, false, p,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(s.width * 0.50, s.height * 0.75),
        width: s.width * 0.28,
        height: s.height * 0.28,
      ),
      math.pi, math.pi, false, p,
    );

    // Base dot
    canvas.drawCircle(
      Offset(s.width * 0.50, s.height * 0.75),
      s.width * 0.06,
      Paint()..color = Colors.white,
    );

    // Small envelope at bottom
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * 0.30, s.height * 0.82,
            s.width * 0.40, s.height * 0.18),
        const Radius.circular(2),
      ),
      p,
    );
    final flap = Path();
    flap.moveTo(s.width * 0.30, s.height * 0.82);
    flap.lineTo(s.width * 0.50, s.height * 0.93);
    flap.lineTo(s.width * 0.70, s.height * 0.82);
    canvas.drawPath(flap, p);
  }

  @override
  bool shouldRepaint(_OfflineSmsPainter o) => false;
}

/// Small check circle for snackbar
class _CheckCircleSmallPainter extends CustomPainter {
  final Color color;
  const _CheckCircleSmallPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    final r = s.width * 0.46;
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4);
    final check = Path();
    check.moveTo(cx - r * 0.40, cy);
    check.lineTo(cx - r * 0.06, cy + r * 0.38);
    check.lineTo(cx + r * 0.40, cy - r * 0.34);
    canvas.drawPath(
      check,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckCircleSmallPainter o) => o.color != color;
}

/// Small warning triangle for snackbar
class _WarningSmallPainter extends CustomPainter {
  final Color color;
  const _WarningSmallPainter({required this.color});

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
        Rect.fromLTWH(cx - 1.5, s.height * 0.36, 3, s.height * 0.28),
        const Radius.circular(1.5),
      ),
      Paint()..color = color,
    );
    canvas.drawCircle(
      Offset(cx, s.height * 0.78),
      2.5,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_WarningSmallPainter o) => o.color != color;
}

/// Small right-pointing chevron arrow
class _ArrowRightSmallPainter extends CustomPainter {
  final Color color;
  const _ArrowRightSmallPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(s.width * 0.22, s.height * 0.18);
    path.lineTo(s.width * 0.72, s.height * 0.50);
    path.lineTo(s.width * 0.22, s.height * 0.82);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_ArrowRightSmallPainter o) => o.color != color;
}