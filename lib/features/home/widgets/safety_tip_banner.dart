// lib/features/home/widgets/safety_tip_banner.dart

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class SafetyTipBanner extends StatelessWidget {
  final String tip;
  const SafetyTipBanner({super.key, required this.tip});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(tip),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(13, 13),
                  painter: _LightbulbPainter(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                tip,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
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
// PAINTER
// ════════════════════════════════════════════════════════════════

class _LightbulbPainter extends CustomPainter {
  final Color color;
  const _LightbulbPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Bulb circle top
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(s.width / 2, s.height * 0.38),
        width: s.width * 0.80,
        height: s.height * 0.72,
      ),
      3.14 * 0.1,
      3.14 * 1.8,
      false,
      p,
    );
    // Base lines
    canvas.drawLine(
      Offset(s.width * 0.33, s.height * 0.74),
      Offset(s.width * 0.33, s.height * 0.88),
      p,
    );
    canvas.drawLine(
      Offset(s.width * 0.67, s.height * 0.74),
      Offset(s.width * 0.67, s.height * 0.88),
      p,
    );
    canvas.drawLine(
      Offset(s.width * 0.36, s.height * 0.88),
      Offset(s.width * 0.64, s.height * 0.88),
      p,
    );
    canvas.drawLine(
      Offset(s.width * 0.40, s.height * 0.96),
      Offset(s.width * 0.60, s.height * 0.96),
      p,
    );
    // Filament lines
    canvas.drawLine(
      Offset(s.width * 0.38, s.height * 0.74),
      Offset(s.width * 0.62, s.height * 0.74),
      p,
    );
    canvas.drawLine(
      Offset(s.width * 0.38, s.height * 0.65),
      Offset(s.width * 0.62, s.height * 0.65),
      p,
    );
  }

  @override
  bool shouldRepaint(_LightbulbPainter o) => o.color != color;
}