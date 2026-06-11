// lib/features/home/widgets/sos_banners.dart

import 'package:flutter/material.dart';
import '../../../core/services/ml_monitoring_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../sos/providers/sos_provider.dart';

// ════════════════════════════════════════════════════════════════
// ACTIVE SOS BANNER
// ════════════════════════════════════════════════════════════════

class SosActiveBanner extends StatelessWidget {
  final SosProvider sos;
  const SosActiveBanner({super.key, required this.sos});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRouter.sos),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: AppColors.sosGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.sosRed.withValues(alpha: 0.50),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(22, 22),
                  painter: _SosTextPainter(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🚨 SOS IS ACTIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    'Duration: ${sos.activeDurationStr} · Tap to manage',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontFamily: 'Poppins',
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            CustomPaint(
              size: const Size(14, 14),
              painter: _ChevronRightPainter(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// COUNTDOWN BANNER
// ════════════════════════════════════════════════════════════════

class SosCountdownBanner extends StatelessWidget {
  final SosProvider sos;
  final VoidCallback onCancel;
  const SosCountdownBanner({
    super.key,
    required this.sos,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRouter.sos),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE65100), Color(0xFFFF6D00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6D00).withValues(alpha: 0.40),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.20),
              ),
              child: Center(
                child: Text(
                  '${sos.countdown}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⏱️ SOS Countdown Active',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Sending alert to all contacts…',
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Poppins',
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onCancel,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'CANCEL',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ML DANGER ALERT BANNER
// ════════════════════════════════════════════════════════════════

class MlDangerAlertBanner extends StatelessWidget {
  final MLDangerResult ml;
  const MlDangerAlertBanner({super.key, required this.ml});

  String get _label {
    switch (ml.level) {
      case DangerLevel.high:     return 'Danger Detected!';
      case DangerLevel.critical: return 'Emergency!';
      default:                   return 'Alert';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRouter.sos),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFB71C1C), Color(0xFFE53935)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.sosRed.withValues(alpha: 0.40),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(22, 22),
                  painter: _BrainIconPainter(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🤖 AI Danger Detected!',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '$_label · ${(ml.score * 100).toInt()}% — Tap to open SOS',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontFamily: 'Poppins',
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            CustomPaint(
              size: const Size(14, 14),
              painter: _ChevronRightPainter(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PAINTERS
// ════════════════════════════════════════════════════════════════

class _SosTextPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final tp = TextPainter(
      text: const TextSpan(
        text: 'SOS',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          fontFamily: 'Poppins',
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(s.width / 2 - tp.width / 2, s.height / 2 - tp.height / 2),
    );

    // Ring
    canvas.drawCircle(
      Offset(s.width / 2, s.height / 2),
      s.width * 0.46,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_SosTextPainter o) => false;
}

class _ChevronRightPainter extends CustomPainter {
  final Color color;
  const _ChevronRightPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(s.width * 0.25, s.height * 0.18);
    path.lineTo(s.width * 0.72, s.height * 0.50);
    path.lineTo(s.width * 0.25, s.height * 0.82);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_ChevronRightPainter o) => o.color != color;
}

class _BrainIconPainter extends CustomPainter {
  final Color color;
  const _BrainIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Left lobe
    final left = Path();
    left.moveTo(s.width * 0.50, s.height * 0.80);
    left.cubicTo(s.width * 0.10, s.height * 0.80, s.width * 0.04, s.height * 0.50,
        s.width * 0.14, s.height * 0.30);
    left.cubicTo(s.width * 0.18, s.height * 0.10, s.width * 0.38, s.height * 0.06,
        s.width * 0.50, s.height * 0.20);
    canvas.drawPath(left, p);

    // Right lobe
    final right = Path();
    right.moveTo(s.width * 0.50, s.height * 0.80);
    right.cubicTo(s.width * 0.90, s.height * 0.80, s.width * 0.96, s.height * 0.50,
        s.width * 0.86, s.height * 0.30);
    right.cubicTo(s.width * 0.82, s.height * 0.10, s.width * 0.62, s.height * 0.06,
        s.width * 0.50, s.height * 0.20);
    canvas.drawPath(right, p);

    // Center line
    canvas.drawLine(
      Offset(s.width * 0.50, s.height * 0.20),
      Offset(s.width * 0.50, s.height * 0.80),
      p,
    );

    // Wrinkle lines
    canvas.drawArc(
      Rect.fromCenter(center: Offset(s.width * 0.28, s.height * 0.44),
          width: s.width * 0.22, height: s.height * 0.22),
      0, 3.14, false, p,
    );
    canvas.drawArc(
      Rect.fromCenter(center: Offset(s.width * 0.72, s.height * 0.44),
          width: s.width * 0.22, height: s.height * 0.22),
      0, 3.14, false, p,
    );
  }

  @override
  bool shouldRepaint(_BrainIconPainter o) => o.color != color;
}