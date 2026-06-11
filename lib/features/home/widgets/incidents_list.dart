// lib/features/home/widgets/incidents_list.dart

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../sos/providers/sos_provider.dart';

class IncidentsList extends StatelessWidget {
  final SosProvider sos;
  final bool isDark;

  const IncidentsList({super.key, required this.sos, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (sos.incidents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.cardShadow,
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : AppColors.lightBorder,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.safeGreen.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(22, 22),
                  painter: _CheckCirclePainter(color: AppColors.safeGreen),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No incidents recorded',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: isDark ? Colors.white : AppColors.lightText,
                    ),
                  ),
                  Text(
                    'Stay safe. AI is watching over you.',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.38)
                          : AppColors.lightTextSecondary,
                      fontSize: 11,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: sos.incidents.take(3).map((e) {
        final c = switch (e.status) {
          'resolved'    => AppColors.safeGreen,
          'false_alarm' => AppColors.warningAmber,
          _             => AppColors.sosRed,
        };

        final d   = DateTime.now().difference(e.triggeredAt);
        final ago = d.inMinutes < 60
            ? '${d.inMinutes}m ago'
            : d.inHours < 24
            ? '${d.inHours}h ago'
            : '${d.inDays}d ago';

        final locationStr =
            '${e.lat.toStringAsFixed(4)}, ${e.lng.toStringAsFixed(4)}';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppColors.cardShadow,
            border: Border.all(
              color: c.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: CustomPaint(
                    size: const Size(22, 22),
                    painter: _EmergencyCirclePainter(color: c),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      switch (e.triggerType) {
                        'manual'   => 'Manual SOS',
                        'shake'    => '📳 Shake SOS',
                        'silent'   => 'Silent SOS',
                        'voice'    => '🎙️ Voice SOS',
                        'hardware' => '🔊 Hardware SOS',
                        _          => '🤖 Auto AI SOS',
                      },
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: isDark ? Colors.white : AppColors.lightText,
                      ),
                    ),
                    Text(
                      locationStr,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.38)
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      e.status.toUpperCase(),
                      style: TextStyle(
                        color: c,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ago,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.35)
                          : AppColors.lightTextSecondary,
                      fontSize: 10,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PAINTERS
// ════════════════════════════════════════════════════════════════

class _CheckCirclePainter extends CustomPainter {
  final Color color;
  const _CheckCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    final r  = s.width * 0.46;
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()
          ..color = color.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4);
    final check = Path();
    check.moveTo(cx - r * 0.42, cy);
    check.lineTo(cx - r * 0.08, cy + r * 0.40);
    check.lineTo(cx + r * 0.42, cy - r * 0.36);
    canvas.drawPath(check,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_CheckCirclePainter o) => o.color != color;
}

class _EmergencyCirclePainter extends CustomPainter {
  final Color color;
  const _EmergencyCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    final r  = s.width * 0.44;

    canvas.drawCircle(Offset(cx, cy), r,
        Paint()
          ..color = color.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4);

    // ! exclamation
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 2.5, cy - r * 0.68, 5, r * 0.72),
        const Radius.circular(2),
      ),
      Paint()..color = color,
    );
    canvas.drawCircle(Offset(cx, cy + r * 0.52), 2.5,
        Paint()..color = color);
  }

  @override
  bool shouldRepaint(_EmergencyCirclePainter o) => o.color != color;
}