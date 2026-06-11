// lib/features/home/widgets/ml_insights_card.dart
// ─────────────────────────────────────────────────────────────────────────────
// INDUSTRIAL SENTINEL — ML INSIGHTS ENGINE v4.0 (2026 PRODUCTION)
// ─────────────────────────────────────────────────────────────────────────────
// ✅ [SYNC] Unified with Python v4.0 7-Factor score_breakdown.
// ✅ [LOGIC] Advanced threshold detection for human-readable safety tips.
// ✅ [UI] Clean, tactical list presentation of forensic insights.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../../core/services/ml_monitoring_service.dart';
import '../../../core/theme/app_colors.dart';

class MlInsightsCard extends StatelessWidget {
  final MLDangerResult ml;
  final bool isDark;

  const MlInsightsCard({super.key, required this.ml, required this.isDark});

  List<String> get _insights {
    final tips = <String>[];

    // 1. Kinetic Insight
    if (ml.movementProb > 60) {
      tips.add('⚠️ Unusual movement patterns detected (${ml.movementProb.toInt()}%).');
    }

    // 2. Acoustic Insight
    if (ml.audioProb > 60) {
      tips.add('🔊 Distress audio patterns identified (${ml.audioProb.toInt()}%).');
    }

    // 3. Location & Context Insights (Mapped from 7-Factor Breakdown)
    final locRisk = (ml.scoreBreakdown['location'] as num? ?? 0.0);
    final ctxRisk = (ml.scoreBreakdown['context'] as num? ?? 0.0);

    if (locRisk > 50) {
      tips.add('📍 Elevated location risk profile (${locRisk.toInt()}%).');
    }
    if (ctxRisk > 50) {
      tips.add('🕐 Temporal/Contextual risk factors active (${ctxRisk.toInt()}%).');
    }

    // 4. Master Fusion Insights
    if (ml.insights.isNotEmpty) {
      // Prioritize specific insights returned by the Python Fusion Engine
      tips.addAll(ml.insights.take(2));
    }

    // 5. Critical Dispatch Recommendation
    if (ml.sosTriggered) {
      tips.add('🚨 CRITICAL: Immediate SOS dispatch recommended.');
    }

    // Fallback if system is clear
    if (tips.isEmpty) {
      tips.add('✅ All systems nominal. Sentinel AI is actively monitoring.');
    }

    return tips;
  }

  @override
  Widget build(BuildContext context) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: CustomPaint(
                    size: const Size(17, 17),
                    painter: _BrainIconPainter(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'AI Safety Insights',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: isDark ? Colors.white : AppColors.lightText,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._insights.map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.60)
                          : AppColors.lightTextSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 8),
          Row(
            children: [
              CustomPaint(
                size: const Size(11, 11),
                painter: _ClockSmallPainter(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.35)
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Sync at ${ml.timestamp.hour.toString().padLeft(2, '0')}:${ml.timestamp.minute.toString().padLeft(2, '0')}:${ml.timestamp.second.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.35)
                      : AppColors.lightTextSecondary,
                  fontFamily: 'Poppins',
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PAINTERS
// ════════════════════════════════════════════════════════════════

class _BrainIconPainter extends CustomPainter {
  final Color color;
  const _BrainIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final left = Path(); left.moveTo(s.width * 0.50, s.height * 0.80); left.cubicTo(s.width * 0.10, s.height * 0.80, s.width * 0.04, s.height * 0.48, s.width * 0.15, s.height * 0.28); left.cubicTo(s.width * 0.20, s.height * 0.08, s.width * 0.38, s.height * 0.06, s.width * 0.50, s.height * 0.18); canvas.drawPath(left, p);
    final right = Path(); right.moveTo(s.width * 0.50, s.height * 0.80); right.cubicTo(s.width * 0.90, s.height * 0.80, s.width * 0.96, s.height * 0.48, s.width * 0.85, s.height * 0.28); right.cubicTo(s.width * 0.80, s.height * 0.08, s.width * 0.62, s.height * 0.06, s.width * 0.50, s.height * 0.18); canvas.drawPath(right, p);
    canvas.drawLine(Offset(s.width * 0.50, s.height * 0.18), Offset(s.width * 0.50, s.height * 0.80), p);
  }
  @override bool shouldRepaint(_BrainIconPainter o) => o.color != color;
}

class _ClockSmallPainter extends CustomPainter {
  final Color color;
  const _ClockSmallPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2; final r = s.width * 0.46; final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.2..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), r, p); canvas.drawLine(Offset(cx, cy), Offset(cx, cy - r * 0.55), p); canvas.drawLine(Offset(cx, cy), Offset(cx + r * 0.38, cy), p);
  }
  @override bool shouldRepaint(_ClockSmallPainter o) => o.color != color;
}