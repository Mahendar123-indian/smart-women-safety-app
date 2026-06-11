// lib/features/location/widgets/threat_alert_widget.dart
// ─────────────────────────────────────────────────────────────────────────────
// THREAT ALERT WIDGET — Zero Material Icons · Dark Theme Matched
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/location_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/location/journey_monitor_service.dart';

class ThreatAlertWidget extends StatefulWidget {
  final LocationProvider provider;
  final VoidCallback onSosTriggered;

  const ThreatAlertWidget({
    super.key,
    required this.provider,
    required this.onSosTriggered,
  });

  @override
  State<ThreatAlertWidget> createState() => _ThreatAlertWidgetState();
}

class _ThreatAlertWidgetState extends State<ThreatAlertWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeCtrl;
  int _countdown = 120;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    final threat = widget.provider.latestThreat;
    if (threat != null && threat.severity >= 0.9) {
      _startCountdown();
    }
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdown = 120;
    _countdownTimer?.cancel();
    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted) { t.cancel(); return; }
          setState(() => _countdown--);
          if (_countdown <= 0) {
            t.cancel();
            widget.onSosTriggered();
          }
        });
    _shakeCtrl.repeat(reverse: true);
  }

  Color get _threatColor {
    final s = widget.provider.latestThreat?.severity ?? 0;
    if (s >= 0.9) return AppColors.sosRed;
    if (s >= 0.7) return AppColors.warningAmber;
    return AppColors.secondary;
  }

  CustomPainter _threatPainter(JourneyThreat? type) {
    switch (type) {
      case JourneyThreat.stationary:
        return _StationaryIconPainter(color: Colors.white);
      case JourneyThreat.routeDeviation:
        return _RouteDeviationIconPainter(color: Colors.white);
      case JourneyThreat.speedAnomaly:
        return _SpeedAnomalyPainter(color: Colors.white);
      case JourneyThreat.signalLoss:
        return _SignalLossPainter(color: Colors.white);
      case JourneyThreat.sosNotResponded:
        return _SosNotRespondedPainter(color: Colors.white);
      case JourneyThreat.restrictedArea:
        return _RestrictedAreaPainter(color: Colors.white);
      default:
        return _WarningTrianglePainter(color: Colors.white);
    }
  }

  String _threatTitle(JourneyThreat? type) {
    switch (type) {
      case JourneyThreat.stationary:
        return '⚠️ No Movement Detected';
      case JourneyThreat.routeDeviation:
        return '🗺️ Off Route Alert';
      case JourneyThreat.speedAnomaly:
        return '🚨 Speed Anomaly — Possible Forced Entry';
      case JourneyThreat.signalLoss:
        return '📡 GPS Signal Lost';
      case JourneyThreat.sosNotResponded:
        return '🚨 No Response — Auto-SOS Arming';
      case JourneyThreat.restrictedArea:
        return '🔴 Danger Zone Entered';
      case JourneyThreat.phoneDropped:
        return '📱 Phone Dropped';
      default:
        return 'Safety Alert';
    }
  }

  @override
  Widget build(BuildContext context) {
    final threat = widget.provider.latestThreat;
    if (threat == null) return const SizedBox.shrink();
    final isHigh = threat.severity >= 0.9;

    return AnimatedBuilder(
      animation: _shakeCtrl,
      builder: (_, child) => Transform.translate(
        offset: isHigh
            ? Offset(_shakeCtrl.value * 4 - 2, 0)
            : Offset.zero,
        child: child,
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        decoration: BoxDecoration(
          color: _threatColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _threatColor.withValues(alpha: 0.40),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: CustomPaint(
                        size: const Size(20, 20),
                        painter: _threatPainter(threat.type),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          _threatTitle(threat.type),
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          threat.message,
                          style: TextStyle(
                            color: Colors.white
                                .withValues(alpha: 0.85),
                            fontFamily: 'Poppins',
                            fontSize: 10,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (isHigh) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white
                            .withValues(alpha: 0.20),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${_countdown}s',
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding:
              const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        HapticFeedback.mediumImpact();
                        _countdownTimer?.cancel();
                        await widget.provider.confirmSafe();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                          BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment:
                          MainAxisAlignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(14, 14),
                              painter:
                              _SafeCheckPainter(
                                  color:
                                  _threatColor),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "I'm Safe",
                              style: TextStyle(
                                color: _threatColor,
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (isHigh) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.heavyImpact();
                          _countdownTimer?.cancel();
                          widget.onSosTriggered();
                        },
                        child: Container(
                          padding:
                          const EdgeInsets.symmetric(
                              vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white
                                .withValues(alpha: 0.20),
                            borderRadius:
                            BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white
                                  .withValues(alpha: 0.50),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            children: [
                              CustomPaint(
                                size: const Size(14, 14),
                                painter: _SosSmallPainter(),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'SOS Now',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                  fontWeight:
                                  FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.provider.dismissThreat();
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white
                              .withValues(alpha: 0.20),
                          borderRadius:
                          BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: CustomPaint(
                            size: const Size(14, 14),
                            painter: _ClosePainter(
                                color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ALL CUSTOM PAINTERS
// ════════════════════════════════════════════════════════════════

class _WarningTrianglePainter extends CustomPainter {
  final Color color;
  const _WarningTrianglePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(cx, s.height * 0.04);
    path.lineTo(s.width * 0.96, s.height * 0.94);
    path.lineTo(s.width * 0.04, s.height * 0.94);
    path.close();
    canvas.drawPath(path, p);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(
                cx - 2, s.height * 0.34, 4, s.height * 0.30),
            const Radius.circular(2)),
        Paint()..color = color);
    canvas.drawCircle(Offset(cx, s.height * 0.76), 3,
        Paint()..color = color);
  }
  @override
  bool shouldRepaint(_WarningTrianglePainter o) =>
      o.color != color;
}

class _StationaryIconPainter extends CustomPainter {
  final Color color;
  const _StationaryIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    // Person standing still
    canvas.drawCircle(Offset(s.width * 0.50, s.height * 0.18),
        s.width * 0.15, p);
    canvas.drawLine(Offset(s.width * 0.50, s.height * 0.33),
        Offset(s.width * 0.50, s.height * 0.68), p);
    canvas.drawLine(Offset(s.width * 0.28, s.height * 0.46),
        Offset(s.width * 0.72, s.height * 0.46), p);
    canvas.drawLine(Offset(s.width * 0.38, s.height * 0.68),
        Offset(s.width * 0.38, s.height), p);
    canvas.drawLine(Offset(s.width * 0.62, s.height * 0.68),
        Offset(s.width * 0.62, s.height), p);
    // Pause bars
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(
          Offset(s.width * 0.80, s.height * (0.20 + i * 0.15)),
          1.5,
          Paint()..color = color.withValues(alpha: 0.70));
    }
  }
  @override
  bool shouldRepaint(_StationaryIconPainter o) =>
      o.color != color;
}

class _RouteDeviationIconPainter extends CustomPainter {
  final Color color;
  const _RouteDeviationIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    // Normal route (dashed)
    final dash = Path();
    dash.moveTo(s.width * 0.10, s.height * 0.80);
    dash.lineTo(s.width * 0.90, s.height * 0.20);
    canvas.drawPath(
        dash,
        Paint()
          ..color = color.withValues(alpha: 0.40)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round);
    // Deviation path
    final deviation = Path();
    deviation.moveTo(s.width * 0.10, s.height * 0.80);
    deviation.cubicTo(s.width * 0.30, s.height * 0.80,
        s.width * 0.70, s.height * 0.50, s.width * 0.90,
        s.height * 0.80);
    canvas.drawPath(deviation, p);
    // Exclamation at deviation end
    canvas.drawCircle(Offset(s.width * 0.90, s.height * 0.80),
        3.5, Paint()..color = color);
  }
  @override
  bool shouldRepaint(_RouteDeviationIconPainter o) =>
      o.color != color;
}

class _SpeedAnomalyPainter extends CustomPainter {
  final Color color;
  const _SpeedAnomalyPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height * 0.58;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        Rect.fromCircle(
            center: Offset(cx, cy), radius: s.width * 0.44),
        math.pi,
        math.pi,
        false,
        p);
    // Needle at high speed position
    final angle = math.pi * 1.75;
    canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + s.width * 0.32 * math.cos(angle),
            cy + s.height * 0.32 * math.sin(angle)),
        Paint()
          ..color = color
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(
        Offset(cx, cy), 2.5, Paint()..color = color);
    // Warning ticks
    for (int i = 0; i < 3; i++) {
      canvas.drawLine(
          Offset(cx + s.width * 0.12 + i * 5, s.height * 0.10),
          Offset(cx + s.width * 0.12 + i * 5, s.height * 0.22),
          Paint()
            ..color = color.withValues(alpha: 0.70)
            ..strokeWidth = 1.2
            ..strokeCap = StrokeCap.round);
    }
  }
  @override
  bool shouldRepaint(_SpeedAnomalyPainter o) =>
      o.color != color;
}

class _SignalLossPainter extends CustomPainter {
  final Color color;
  const _SignalLossPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    // Signal arcs (faded)
    for (int i = 1; i <= 3; i++) {
      canvas.drawArc(
          Rect.fromCenter(
              center: Offset(s.width * 0.40, s.height * 0.60),
              width: i * s.width * 0.26,
              height: i * s.height * 0.26),
          -math.pi * 0.8,
          math.pi * 0.6,
          false,
          Paint()
            ..color =
            color.withValues(alpha: 0.25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..strokeCap = StrokeCap.round);
    }
    // Slash line through
    canvas.drawLine(Offset(s.width * 0.10, s.height * 0.10),
        Offset(s.width * 0.90, s.height * 0.90), p);
    // Base dot
    canvas.drawCircle(
        Offset(s.width * 0.40, s.height * 0.60), 3,
        Paint()..color = color.withValues(alpha: 0.40));
  }
  @override
  bool shouldRepaint(_SignalLossPainter o) => o.color != color;
}

class _SosNotRespondedPainter extends CustomPainter {
  final Color color;
  const _SosNotRespondedPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    canvas.drawCircle(
        Offset(cx, cy),
        s.width * 0.44,
        Paint()
          ..color = color.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6);
    final tp = TextPainter(
      text: TextSpan(
        text: 'SOS',
        style: TextStyle(
          color: color,
          fontSize: 6,
          fontWeight: FontWeight.w900,
          fontFamily: 'Poppins',
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        Offset(cx - tp.width / 2, cy - tp.height / 2 - 3));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - 2, cy + 2, 4, s.height * 0.20),
            const Radius.circular(2)),
        Paint()..color = color);
    canvas.drawCircle(Offset(cx, cy + s.height * 0.36), 2,
        Paint()..color = color);
  }
  @override
  bool shouldRepaint(_SosNotRespondedPainter o) =>
      o.color != color;
}

class _RestrictedAreaPainter extends CustomPainter {
  final Color color;
  const _RestrictedAreaPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(s.width / 2, s.height / 2),
        s.width * 0.44, p);
    canvas.drawLine(
        Offset(s.width * 0.18, s.height * 0.82),
        Offset(s.width * 0.82, s.height * 0.18),
        Paint()
          ..color = color
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(_RestrictedAreaPainter o) =>
      o.color != color;
}

class _SafeCheckPainter extends CustomPainter {
  final Color color;
  const _SafeCheckPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(s.width * 0.15, s.height * 0.50);
    path.lineTo(s.width * 0.42, s.height * 0.75);
    path.lineTo(s.width * 0.85, s.height * 0.25);
    canvas.drawPath(path, p);
  }
  @override
  bool shouldRepaint(_SafeCheckPainter o) => o.color != color;
}

class _SosSmallPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    canvas.drawCircle(Offset(cx, cy), s.width * 0.44,
        Paint()..color = Colors.white.withValues(alpha: 0.80));
    final tp = TextPainter(
      text: const TextSpan(
        text: 'SOS',
        style: TextStyle(
          color: Colors.red,
          fontSize: 5,
          fontWeight: FontWeight.w900,
          fontFamily: 'Poppins',
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        Offset(cx - tp.width / 2, cy - tp.height / 2));
  }
  @override
  bool shouldRepaint(_SosSmallPainter o) => false;
}

class _ClosePainter extends CustomPainter {
  final Color color;
  const _ClosePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(0, 0), Offset(s.width, s.height), p);
    canvas.drawLine(
        Offset(s.width, 0), Offset(0, s.height), p);
  }
  @override
  bool shouldRepaint(_ClosePainter o) => o.color != color;
}