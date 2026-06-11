// lib/features/sos/widgets/offline_sos_banner.dart
// ─────────────────────────────────────────────────────────────────────────────
// OFFLINE SOS BANNER — Zero Material icons · All CustomPainter
// All OfflineSosService fields preserved exactly
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/offline_sos_service.dart';
import '../../../core/theme/app_colors.dart';

class OfflineSosBanner extends StatefulWidget {
  const OfflineSosBanner({super.key});

  @override
  State<OfflineSosBanner> createState() => _OfflineSosBannerState();
}

class _OfflineSosBannerState extends State<OfflineSosBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkCtrl;
  Timer? _refreshTimer;

  bool _isOnline       = true;
  CachedLocation? _location;
  int _pendingCount    = 0;

  @override
  void initState() {
    super.initState();
    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _refresh();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
          (_) => _refresh(),
    );
  }

  @override
  void dispose() {
    _blinkCtrl.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final svc = OfflineSosService.instance;
    final pending = await svc.getPendingCount();
    if (mounted) {
      setState(() {
        _isOnline     = svc.isOnline;
        _location     = svc.lastCachedLocation;
        _pendingCount = pending;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Online, no pending — show minimal GPS cache indicator
    if (_isOnline && _pendingCount == 0) {
      return _buildOnlineIndicator();
    }
    return _buildOfflineBanner();
  }

  Widget _buildOnlineIndicator() {
    final loc = _location;
    if (loc == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.safeGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.safeGreen.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          CustomPaint(
            size: const Size(13, 13),
            painter: _GpsPainter(color: AppColors.safeGreen),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'GPS cached ${loc.ageStr} · Ready for offline SOS',
              style: const TextStyle(
                color: AppColors.safeGreen,
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.safeGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner() {
    final hasLoc = _location != null;
    final color =
    _isOnline ? AppColors.warningAmber : AppColors.sosRed;

    return GestureDetector(
      onTap: _pendingCount > 0 ? () => _triggerSync() : null,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Blinking dot
                AnimatedBuilder(
                  animation: _blinkCtrl,
                  builder: (_, __) => Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(
                        alpha: 0.40 + _blinkCtrl.value * 0.60,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CustomPaint(
                  size: const Size(16, 16),
                  painter: _isOnline
                      ? _SyncIconPainter(color: color)
                      : _WifiOffPainter(color: color),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _isOnline
                        ? '$_pendingCount offline SOS record${_pendingCount == 1 ? '' : 's'} pending sync'
                        : '📵 No internet — Offline SOS mode active',
                    style: TextStyle(
                      color: color,
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_isOnline && _pendingCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Sync Now',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Poppins',
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                CustomPaint(
                  size: const Size(11, 11),
                  painter: _LocationDotPainter(
                    color: hasLoc ? color : Colors.grey,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    hasLoc
                        ? '📍 Last GPS: ${_location!.address} (${_location!.ageStr})'
                        : '⚠️ No GPS cached — open app in a known location',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      color: hasLoc
                          ? color.withValues(alpha: 0.80)
                          : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            if (!_isOnline) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Tap SOS button — emergency SMS sent to contacts even without internet.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.50),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _triggerSync() async {
    HapticFeedback.selectionClick();
    await OfflineSosService.instance.syncPendingRecords();
    await _refresh();
  }
}

// ═══════════════════════════════════════════════════════════════════════
// OFFLINE SOS BUTTON (used when isOnline = false)
// ═══════════════════════════════════════════════════════════════════════

class OfflineSOSButton extends StatelessWidget {
  final VoidCallback onTrigger;
  const OfflineSOSButton({super.key, required this.onTrigger});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.heavyImpact();
        onTrigger();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFB71C1C), Color(0xFFD32F2F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.sosRed.withValues(alpha: 0.40),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(22, 22),
                  painter: _WifiOffPainter(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Offline Emergency SOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Sends SMS to all contacts with last GPS location',
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Poppins',
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            CustomPaint(
              size: const Size(20, 20),
              painter: _ChevronRightPainter(
                  color: Colors.white.withValues(alpha: 0.70)),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// CUSTOM PAINTERS
// ═══════════════════════════════════════════════════════════════════════

class _GpsPainter extends CustomPainter {
  final Color color;
  const _GpsPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), s.width * 0.26, p);
    canvas.drawCircle(Offset(cx, cy), s.width * 0.08,
        Paint()..color = color);
    canvas.drawLine(Offset(cx, 0), Offset(cx, s.height * 0.18), p);
    canvas.drawLine(
        Offset(cx, s.height * 0.82), Offset(cx, s.height), p);
    canvas.drawLine(Offset(0, cy), Offset(s.width * 0.18, cy), p);
    canvas.drawLine(
        Offset(s.width * 0.82, cy), Offset(s.width, cy), p);
  }
  @override
  bool shouldRepaint(_GpsPainter o) => o.color != color;
}

class _WifiOffPainter extends CustomPainter {
  final Color color;
  const _WifiOffPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    // 3 arcs (greyed)
    for (int i = 1; i <= 3; i++) {
      canvas.drawArc(
          Rect.fromCenter(
              center: Offset(s.width * 0.40, s.height * 0.65),
              width: i * s.width * 0.22,
              height: i * s.height * 0.22),
          -math.pi * 0.9, math.pi * 0.8, false,
          Paint()
            ..color = color.withValues(alpha: 0.25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3
            ..strokeCap = StrokeCap.round);
    }
    // Slash
    canvas.drawLine(Offset(s.width * 0.12, s.height * 0.12),
        Offset(s.width * 0.88, s.height * 0.88), p);
  }
  @override
  bool shouldRepaint(_WifiOffPainter o) => o.color != color;
}

class _SyncIconPainter extends CustomPainter {
  final Color color;
  const _SyncIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        Rect.fromLTWH(s.width * 0.10, s.height * 0.10,
            s.width * 0.80, s.height * 0.80),
        -math.pi * 0.5, math.pi * 1.5, false, p);
    // Arrow tip
    final tip = Path();
    tip.moveTo(s.width * 0.50, 0);
    tip.lineTo(s.width * 0.72, s.height * 0.18);
    tip.moveTo(s.width * 0.50, 0);
    tip.lineTo(s.width * 0.28, s.height * 0.18);
    canvas.drawPath(tip, p);
  }
  @override
  bool shouldRepaint(_SyncIconPainter o) => o.color != color;
}

class _LocationDotPainter extends CustomPainter {
  final Color color;
  const _LocationDotPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final path = Path();
    path.moveTo(s.width * 0.50, 0);
    path.cubicTo(s.width * 0.18, 0, 0, s.height * 0.26, 0, s.height * 0.46);
    path.cubicTo(0, s.height * 0.66, s.width * 0.18, s.height * 0.80,
        s.width * 0.50, s.height);
    path.cubicTo(s.width * 0.82, s.height * 0.80, s.width, s.height * 0.66,
        s.width, s.height * 0.46);
    path.cubicTo(s.width, s.height * 0.26, s.width * 0.82, 0, s.width * 0.50, 0);
    path.close();
    canvas.drawPath(path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
    canvas.drawCircle(Offset(s.width / 2, s.height * 0.44), s.width * 0.14,
        Paint()..color = color);
  }
  @override
  bool shouldRepaint(_LocationDotPainter o) => o.color != color;
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