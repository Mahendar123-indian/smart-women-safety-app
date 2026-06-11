// lib/features/home/widgets/live_metrics_row.dart

import 'package:flutter/material.dart';
import '../../../core/services/ml_monitoring_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../contacts/providers/contact_provider.dart';
import '../../location/providers/location_provider.dart';

class LiveMetricsRow extends StatelessWidget {
  final MLDangerResult ml;
  final ContactProvider contacts;
  final LocationProvider location;
  final bool isDark;

  const LiveMetricsRow({
    super.key,
    required this.ml,
    required this.contacts,
    required this.location,
    required this.isDark,
  });

  Color get _dangerColor {
    switch (ml.level) {
      case DangerLevel.safe:     return AppColors.safeGreen;
      case DangerLevel.low:      return AppColors.warningAmber;
      case DangerLevel.medium:   return const Color(0xFFFF8F00);
      case DangerLevel.high:
      case DangerLevel.critical: return AppColors.sosRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final motionPct   = (ml.movementProb * 100).toInt();
    final motionLabel = motionPct > 65 ? 'High'
        : motionPct > 40 ? 'Mid' : 'Low';
    final motionColor = motionPct > 65 ? AppColors.sosRed
        : motionPct > 40 ? AppColors.warningAmber : AppColors.safeGreen;

    return Row(
      children: [
        _Chip(
          value: '${(ml.score * 100).toInt()}%',
          label: 'AI Danger',
          painter: _BrainIconPainter(color: _dangerColor),
          color: _dangerColor,
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        _Chip(
          value: motionLabel,
          label: 'Motion',
          painter: _VibrateIconPainter(color: motionColor),
          color: motionColor,
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        _Chip(
          value: '${contacts.activeCount}',
          label: 'Guardians',
          painter: _PeopleIconPainter(color: AppColors.primary),
          color: AppColors.primary,
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        _Chip(
          value: location.isSharing ? '● Live' : '○ Off',
          label: 'Tracking',
          painter: _GpsIconPainter(
            color: location.isSharing ? AppColors.safeGreen : Colors.grey,
          ),
          color: location.isSharing ? AppColors.safeGreen : Colors.grey,
          isDark: isDark,
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String value;
  final String label;
  final CustomPainter painter;
  final Color color;
  final bool isDark;

  const _Chip({
    required this.value,
    required this.label,
    required this.painter,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
        border: Border.all(
          color: color.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: CustomPaint(
                size: const Size(15, 15),
                painter: painter,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              fontFamily: 'Poppins',
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.38)
                  : AppColors.lightTextSecondary,
              fontSize: 9,
              fontFamily: 'Poppins',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════
// PAINTERS
// ════════════════════════════════════════════════════════════════

class _BrainIconPainter extends CustomPainter {
  final Color color;
  const _BrainIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final left = Path();
    left.moveTo(s.width * 0.50, s.height * 0.80);
    left.cubicTo(s.width * 0.10, s.height * 0.80,
        s.width * 0.04, s.height * 0.48, s.width * 0.15, s.height * 0.28);
    left.cubicTo(s.width * 0.20, s.height * 0.08,
        s.width * 0.38, s.height * 0.06, s.width * 0.50, s.height * 0.18);
    canvas.drawPath(left, p);

    final right = Path();
    right.moveTo(s.width * 0.50, s.height * 0.80);
    right.cubicTo(s.width * 0.90, s.height * 0.80,
        s.width * 0.96, s.height * 0.48, s.width * 0.85, s.height * 0.28);
    right.cubicTo(s.width * 0.80, s.height * 0.08,
        s.width * 0.62, s.height * 0.06, s.width * 0.50, s.height * 0.18);
    canvas.drawPath(right, p);

    canvas.drawLine(
      Offset(s.width * 0.50, s.height * 0.18),
      Offset(s.width * 0.50, s.height * 0.80),
      p,
    );
  }

  @override
  bool shouldRepaint(_BrainIconPainter o) => o.color != color;
}

class _VibrateIconPainter extends CustomPainter {
  final Color color;
  const _VibrateIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    // Phone body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * 0.28, s.height * 0.12,
            s.width * 0.44, s.height * 0.76),
        const Radius.circular(3),
      ),
      p,
    );
    // Vibration lines
    for (final x in [s.width * 0.08, s.width * 0.84]) {
      canvas.drawLine(Offset(x, s.height * 0.32),
          Offset(x, s.height * 0.68), p);
    }
  }

  @override
  bool shouldRepaint(_VibrateIconPainter o) => o.color != color;
}

class _PeopleIconPainter extends CustomPainter {
  final Color color;
  const _PeopleIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    // Front person head
    canvas.drawCircle(Offset(s.width * 0.36, s.height * 0.28),
        s.width * 0.16, p);
    // Front person body
    final b = Path();
    b.moveTo(0, s.height);
    b.quadraticBezierTo(0, s.height * 0.60,
        s.width * 0.36, s.height * 0.60);
    b.quadraticBezierTo(s.width * 0.68, s.height * 0.60,
        s.width * 0.68, s.height);
    canvas.drawPath(b, p);
    // Back person head (partial)
    canvas.drawCircle(Offset(s.width * 0.76, s.height * 0.22),
        s.width * 0.13,
        Paint()
          ..color = color.withValues(alpha: 0.60)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1);
  }

  @override
  bool shouldRepaint(_PeopleIconPainter o) => o.color != color;
}

class _GpsIconPainter extends CustomPainter {
  final Color color;
  const _GpsIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    // Crosshair circle
    canvas.drawCircle(Offset(cx, cy), s.width * 0.30, p);
    // Center dot
    canvas.drawCircle(Offset(cx, cy), s.width * 0.08,
        Paint()..color = color);
    // Crosshair lines
    canvas.drawLine(Offset(cx, 0), Offset(cx, s.height * 0.20), p);
    canvas.drawLine(Offset(cx, s.height * 0.80), Offset(cx, s.height), p);
    canvas.drawLine(Offset(0, cy), Offset(s.width * 0.20, cy), p);
    canvas.drawLine(Offset(s.width * 0.80, cy), Offset(s.width, cy), p);
  }

  @override
  bool shouldRepaint(_GpsIconPainter o) => o.color != color;
}