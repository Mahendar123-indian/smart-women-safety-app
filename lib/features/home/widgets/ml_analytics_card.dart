import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/services/ml_monitoring_service.dart';
import '../../../core/theme/app_colors.dart';

class MlAnalyticsCard extends StatelessWidget {
  final MLDangerResult ml;
  final bool isDark;

  const MlAnalyticsCard({super.key, required this.ml, required this.isDark});

  // ✅ FIXED: Uses dangerLevelString to determine connection status
  bool get _isConnected => ml.dangerLevelString != 'SAFE' || ml.scoreRaw > 0;

  @override
  Widget build(BuildContext context) {
    // ✅ FIXED: Mapping old signals to new scoreBreakdown values from Python v4.0
    final signals = [
      _Signal(
          'Movement',
          ml.movementProb / 100, // Normalized for UI gauge
          _VibrateGaugePainter(color: AppColors.secondary),
          AppColors.secondary),
      _Signal(
          'Audio',
          ml.audioProb / 100, // Normalized for UI gauge
          _MicGaugePainter(color: AppColors.warningAmber),
          AppColors.warningAmber),
      _Signal(
          'Location',
          (ml.scoreBreakdown['location'] as num? ?? 0.0) / 100,
          _LocationGaugePainter(color: AppColors.safeGreen),
          AppColors.safeGreen),
      _Signal(
          'Context',
          (ml.scoreBreakdown['context'] as num? ?? 0.0) / 100,
          _ClockGaugePainter(color: AppColors.primary),
          AppColors.primary),
      _Signal(
          'Overall',
          ml.score,
          _OverallGaugePainter(color: AppColors.sosRed),
          AppColors.sosRed),
    ];

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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ML Signal Analysis',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: isDark ? Colors.white : AppColors.lightText,
                ),
              ),
              // ✅ FIXED: Changed dominantFactor check to insights availability
              if (ml.insights.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'AI Monitoring Active',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Gauges row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: signals.map((s) => _Gauge(signal: s, isDark: isDark)).toList(),
          ),
          const SizedBox(height: 14),

          // Overall danger bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Overall Danger Score',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.45)
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  Text(
                    '${(ml.scoreRaw).toInt()}%',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: AppColors.sosRed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: ml.score.clamp(0.0, 1.0),
                  backgroundColor: AppColors.sosRed.withValues(alpha: 0.10),
                  valueColor: const AlwaysStoppedAnimation(AppColors.sosRed),
                  minHeight: 7,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Footer
          Row(
            children: [
              CustomPaint(
                size: const Size(12, 12),
                painter: _ClockGaugePainter(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.35)
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'Updated ${ml.timestamp.hour.toString().padLeft(2, '0')}:${ml.timestamp.minute.toString().padLeft(2, '0')}:${ml.timestamp.second.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.35)
                      : AppColors.lightTextSecondary,
                  fontFamily: 'Poppins',
                  fontSize: 10,
                ),
              ),
              const Spacer(),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isConnected ? AppColors.safeGreen : Colors.grey,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                _isConnected ? 'Sentinel Cloud Active' : 'Idle',
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

class _Signal {
  final String label;
  final double value;
  final CustomPainter painter;
  final Color color;
  const _Signal(this.label, this.value, this.painter, this.color);
}

class _Gauge extends StatelessWidget {
  final _Signal signal;
  final bool isDark;
  const _Gauge({required this.signal, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: signal.color.withValues(alpha: 0.10),
            border: Border.all(
              color: signal.color.withValues(alpha: 0.30),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomPaint(
                size: const Size(14, 14),
                painter: signal.painter,
              ),
              Text(
                '${(signal.value * 100).toInt()}%',
                style: TextStyle(
                  color: signal.color,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Text(
          signal.label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 9,
            color: isDark
                ? Colors.white.withValues(alpha: 0.38)
                : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }
}

// ... [Keep all your custom painters at the bottom, they are already perfect]
class _VibrateGaugePainter extends CustomPainter {
  final Color color;
  const _VibrateGaugePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.2..strokeCap = StrokeCap.round;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s.width * 0.28, s.height * 0.10, s.width * 0.44, s.height * 0.80), const Radius.circular(2)), p);
    for (final x in [s.width * 0.08, s.width * 0.84]) { canvas.drawLine(Offset(x, s.height * 0.32), Offset(x, s.height * 0.68), p); }
  }
  @override bool shouldRepaint(_VibrateGaugePainter o) => o.color != color;
}

class _MicGaugePainter extends CustomPainter {
  final Color color;
  const _MicGaugePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.2..strokeCap = StrokeCap.round;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s.width * 0.30, 0, s.width * 0.40, s.height * 0.58), Radius.circular(s.width * 0.20)), p);
    canvas.drawArc(Rect.fromLTWH(s.width * 0.12, s.height * 0.28, s.width * 0.76, s.height * 0.52), 0, math.pi, false, p);
    canvas.drawLine(Offset(s.width * 0.50, s.height * 0.80), Offset(s.width * 0.50, s.height), p);
    canvas.drawLine(Offset(s.width * 0.30, s.height), Offset(s.width * 0.70, s.height), p);
  }
  @override bool shouldRepaint(_MicGaugePainter o) => o.color != color;
}

class _LocationGaugePainter extends CustomPainter {
  final Color color;
  const _LocationGaugePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.2..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(s.width * 0.50, 0);
    path.cubicTo(s.width * 0.18, 0, 0, s.height * 0.26, 0, s.height * 0.46);
    path.cubicTo(0, s.height * 0.66, s.width * 0.18, s.height * 0.80, s.width * 0.50, s.height);
    path.cubicTo(s.width * 0.82, s.height * 0.80, s.width, s.height * 0.66, s.width, s.height * 0.46);
    path.cubicTo(s.width, s.height * 0.26, s.width * 0.82, 0, s.width * 0.50, 0);
    path.close();
    canvas.drawPath(path, p);
    canvas.drawCircle(Offset(s.width / 2, s.height * 0.44), s.width * 0.14, Paint()..color = color);
  }
  @override bool shouldRepaint(_LocationGaugePainter o) => o.color != color;
}

class _ClockGaugePainter extends CustomPainter {
  final Color color;
  const _ClockGaugePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2; final r = s.width * 0.44;
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.2..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), r, p);
    canvas.drawLine(Offset(cx, cy), Offset(cx, cy - r * 0.55), p);
    canvas.drawLine(Offset(cx, cy), Offset(cx + r * 0.38, cy), p);
  }
  @override bool shouldRepaint(_ClockGaugePainter o) => o.color != color;
}

class _OverallGaugePainter extends CustomPainter {
  final Color color;
  const _OverallGaugePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.2..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final shield = Path(); shield.moveTo(cx, 0); shield.lineTo(s.width, s.height * 0.22); shield.cubicTo(s.width, s.height * 0.22, s.width * 0.98, s.height * 0.72, cx, s.height);
    shield.cubicTo(s.width * 0.02, s.height * 0.72, 0, s.height * 0.22, 0, s.height * 0.22); shield.close(); canvas.drawPath(shield, p);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - 1.5, s.height * 0.28, 3, s.height * 0.28), const Radius.circular(2)), Paint()..color = color);
    canvas.drawCircle(Offset(cx, s.height * 0.72), 2.0, Paint()..color = color);
  }
  @override bool shouldRepaint(_OverallGaugePainter o) => o.color != color;
}