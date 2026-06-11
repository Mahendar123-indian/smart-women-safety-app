// lib/features/home/widgets/ml_danger_card.dart
// ─────────────────────────────────────────────────────────────────────────────
// INDUSTRIAL SENTINEL — ML DANGER VISUALIZER v4.1 (2026 PRODUCTION)
// ─────────────────────────────────────────────────────────────────────────────
// ✅ [FIXED] RenderFlex Overflow: Wrapped status text in Flexible to prevent crashes.
// ✅ [SYNC] Interlinked with Python v4.0 7-Factor Fusion Engine.
// ✅ [LOGIC] sosTriggered mapped to Auto-SOS status indicator.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/services/ml_monitoring_service.dart';
import '../../../core/theme/app_colors.dart';

class MlDangerCard extends StatelessWidget {
  final MLDangerResult ml;
  final AnimationController radarCtrl;
  final AnimationController breathCtrl;

  const MlDangerCard({
    super.key,
    required this.ml,
    required this.radarCtrl,
    required this.breathCtrl,
  });

  Color get _color {
    switch (ml.level) {
      case DangerLevel.safe:     return AppColors.safeGreen;
      case DangerLevel.low:      return AppColors.warningAmber;
      case DangerLevel.medium:   return const Color(0xFFFF8F00);
      case DangerLevel.high:
      case DangerLevel.critical: return AppColors.sosRed;
    }
  }

  String get _label {
    switch (ml.level) {
      case DangerLevel.safe:     return 'You Are Safe';
      case DangerLevel.low:      return 'Stay Alert';
      case DangerLevel.medium:   return 'Warning — Be Careful';
      case DangerLevel.high:     return 'Danger Detected!';
      case DangerLevel.critical: return 'Emergency!';
    }
  }

  CustomPainter get _iconPainter {
    switch (ml.level) {
      case DangerLevel.safe:
        return _ShieldCheckPainter(color: Colors.white);
      case DangerLevel.low:
        return _InfoCirclePainter(color: Colors.white);
      case DangerLevel.medium:
        return _WarningTrianglePainter(color: Colors.white);
      case DangerLevel.high:
      case DangerLevel.critical:
        return _EmergencyPainter(color: Colors.white);
    }
  }

  bool get _isConnected => ml.dangerLevelString != 'SAFE' || ml.scoreRaw > 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: breathCtrl,
      builder: (_, __) => AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_color, _color.withValues(alpha: 0.72)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: _color.withValues(alpha: 0.30 + 0.15 * breathCtrl.value),
              blurRadius: 28 + 10 * breathCtrl.value,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Top row: radar + info ─────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: AnimatedBuilder(
                    animation: radarCtrl,
                    builder: (_, __) => Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 72 * radarCtrl.value,
                          height: 72 * radarCtrl.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.12 * (1 - radarCtrl.value)),
                          ),
                        ),
                        Container(
                          width: 52 * radarCtrl.value,
                          height: 52 * radarCtrl.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.08 * (1 - radarCtrl.value)),
                          ),
                        ),
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.20),
                          ),
                          child: Center(
                            child: CustomPaint(
                              size: const Size(26, 26),
                              painter: _iconPainter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Poppins',
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: ml.score.clamp(0.0, 1.0),
                          backgroundColor: Colors.white.withValues(alpha: 0.25),
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                          minHeight: 7,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // ✅ FIXED: Wrapped in Flexible to prevent 6.6 pixel overflow crash
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Danger: ${(ml.scoreRaw).toInt()}%',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 10,
                                fontFamily: 'Poppins',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Sentinel: ${ml.sosTriggered ? "DISPATCHING" : "ACTIVE"}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.70),
                                fontSize: 10,
                                fontFamily: 'Poppins',
                              ),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Component bars (Mapped to 7-Factor Fusion) ───────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _Bar(
                    label: 'Kinematics AI',
                    value: ml.movementProb / 100,
                    painter: _VibrateBarPainter(),
                  ),
                  const SizedBox(height: 7),
                  _Bar(
                    label: 'Acoustic AI',
                    value: ml.audioProb / 100,
                    painter: _MicBarPainter(),
                  ),
                  const SizedBox(height: 7),
                  _Bar(
                    label: 'Location Risk',
                    value: (ml.scoreBreakdown['location'] as num? ?? 0.0) / 100,
                    painter: _LocationBarPainter(),
                  ),
                  const SizedBox(height: 7),
                  _Bar(
                    label: 'Context Layer',
                    value: (ml.scoreBreakdown['context'] as num? ?? 0.0) / 100,
                    painter: _ClockBarPainter(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ── Status pills ──────────────────────────────────
            Row(
              children: [
                _Pill('🤖 AI Guard', true),
                const SizedBox(width: 7),
                _Pill(
                  ml.level == DangerLevel.safe ? '✅ Safe' : '⚠️ $_label',
                  ml.level != DangerLevel.safe,
                ),
                const SizedBox(width: 7),
                _Pill(
                  _isConnected ? '🔗 Cloud Run' : '📵 Offline',
                  _isConnected,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// BAR WIDGET
// ════════════════════════════════════════════════════════════════

class _Bar extends StatelessWidget {
  final String label;
  final double value;
  final CustomPainter painter;

  const _Bar({
    required this.label,
    required this.value,
    required this.painter,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).toInt();
    final c = value > 0.65
        ? AppColors.sosRed
        : value > 0.4
        ? AppColors.warningAmber
        : Colors.white;

    return Row(
      children: [
        CustomPaint(
          size: const Size(12, 12),
          painter: painter,
        ),
        const SizedBox(width: 5),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontFamily: 'Poppins',
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(c),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 32,
          child: Text(
            '$pct%',
            style: TextStyle(
              color: c,
              fontSize: 10,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PILL WIDGET
// ════════════════════════════════════════════════════════════════

class _Pill extends StatelessWidget {
  final String label;
  final bool active;
  const _Pill(this.label, this.active);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: active ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withValues(alpha: active ? 0.50 : 0.15),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w700,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════
// ALL CUSTOM PAINTERS (FORENSIC STYLE)
// ════════════════════════════════════════════════════════════════

class _ShieldCheckPainter extends CustomPainter {
  final Color color;
  const _ShieldCheckPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.8..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final shield = Path(); shield.moveTo(s.width * 0.50, 0); shield.lineTo(s.width, s.height * 0.22); shield.cubicTo(s.width, s.height * 0.22, s.width * 0.98, s.height * 0.72, s.width * 0.50, s.height); shield.cubicTo(s.width * 0.02, s.height * 0.72, 0, s.height * 0.22, 0, s.height * 0.22); shield.close(); canvas.drawPath(shield, p);
    final check = Path(); check.moveTo(s.width * 0.28, s.height * 0.52); check.lineTo(s.width * 0.44, s.height * 0.68); check.lineTo(s.width * 0.72, s.height * 0.36); canvas.drawPath(check, p);
  }
  @override bool shouldRepaint(_ShieldCheckPainter o) => o.color != color;
}

class _InfoCirclePainter extends CustomPainter {
  final Color color;
  const _InfoCirclePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2; final r = s.width * 0.46; final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.6..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), r, p); canvas.drawCircle(Offset(cx, cy - r * 0.40), s.width * 0.07, Paint()..color = color);
    canvas.drawLine(Offset(cx, cy - r * 0.15), Offset(cx, cy + r * 0.42), Paint()..color = color..strokeWidth = 1.8..strokeCap = StrokeCap.round);
  }
  @override bool shouldRepaint(_InfoCirclePainter o) => o.color != color;
}

class _WarningTrianglePainter extends CustomPainter {
  final Color color;
  const _WarningTrianglePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.8..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final path = Path(); path.moveTo(cx, s.height * 0.04); path.lineTo(s.width * 0.96, s.height * 0.94); path.lineTo(s.width * 0.04, s.height * 0.94); path.close(); canvas.drawPath(path, p);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - 2, s.height * 0.36, 4, s.height * 0.30), const Radius.circular(2)), Paint()..color = color);
    canvas.drawCircle(Offset(cx, s.height * 0.78), 3, Paint()..color = color);
  }
  @override bool shouldRepaint(_WarningTrianglePainter o) => o.color != color;
}

class _EmergencyPainter extends CustomPainter {
  final Color color;
  const _EmergencyPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2; final r = s.width * 0.44; final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.8..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), r, p);
    final tp = TextPainter(text: TextSpan(text: 'SOS', style: TextStyle(color: color, fontSize: 7, fontWeight: FontWeight.w900, fontFamily: 'Poppins', letterSpacing: 0.8)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2 - 2));
    canvas.drawLine(Offset(cx, cy + r * 0.30), Offset(cx, cy + r * 0.55), Paint()..color = color..strokeWidth = 1.8..strokeCap = StrokeCap.round);
  }
  @override bool shouldRepaint(_EmergencyPainter o) => o.color != color;
}

class _VibrateBarPainter extends CustomPainter {
  @override void paint(Canvas canvas, Size s) {
    final p = Paint()..color = Colors.white70..style = PaintingStyle.stroke..strokeWidth = 1.2..strokeCap = StrokeCap.round;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s.width * 0.28, s.height * 0.10, s.width * 0.44, s.height * 0.80), const Radius.circular(2)), p);
    for (final x in [s.width * 0.08, s.width * 0.84]) { canvas.drawLine(Offset(x, s.height * 0.32), Offset(x, s.height * 0.68), p); }
  }
  @override bool shouldRepaint(_VibrateBarPainter o) => false;
}

class _MicBarPainter extends CustomPainter {
  @override void paint(Canvas canvas, Size s) {
    final p = Paint()..color = Colors.white70..style = PaintingStyle.stroke..strokeWidth = 1.2..strokeCap = StrokeCap.round;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s.width * 0.30, 0, s.width * 0.40, s.height * 0.58), Radius.circular(s.width * 0.20)), p);
    canvas.drawArc(Rect.fromLTWH(s.width * 0.12, s.height * 0.28, s.width * 0.76, s.height * 0.52), 0, math.pi, false, p);
    canvas.drawLine(Offset(s.width * 0.50, s.height * 0.80), Offset(s.width * 0.50, s.height), p);
  }
  @override bool shouldRepaint(_MicBarPainter o) => false;
}

class _LocationBarPainter extends CustomPainter {
  @override void paint(Canvas canvas, Size s) {
    final p = Paint()..color = Colors.white70..style = PaintingStyle.stroke..strokeWidth = 1.2..strokeJoin = StrokeJoin.round;
    final path = Path(); path.moveTo(s.width * 0.50, 0); path.cubicTo(s.width * 0.18, 0, 0, s.height * 0.26, 0, s.height * 0.46); path.cubicTo(0, s.height * 0.66, s.width * 0.18, s.height * 0.80, s.width * 0.50, s.height); path.cubicTo(s.width * 0.82, s.height * 0.80, s.width, s.height * 0.66, s.width, s.height * 0.46); path.cubicTo(s.width, s.height * 0.26, s.width * 0.82, 0, s.width * 0.50, 0); path.close(); canvas.drawPath(path, p);
    canvas.drawCircle(Offset(s.width / 2, s.height * 0.44), s.width * 0.14, Paint()..color = Colors.white70);
  }
  @override bool shouldRepaint(_LocationBarPainter o) => false;
}

class _ClockBarPainter extends CustomPainter {
  @override void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2; final r = s.width * 0.44; final p = Paint()..color = Colors.white70..style = PaintingStyle.stroke..strokeWidth = 1.2..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), r, p); canvas.drawLine(Offset(cx, cy), Offset(cx, cy - r * 0.55), p); canvas.drawLine(Offset(cx, cy), Offset(cx + r * 0.40, cy), p);
  }
  @override bool shouldRepaint(_ClockBarPainter o) => false;
}