// lib/features/location/screens/night_mode_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// NIGHT MODE SETTINGS SCREEN — Full Custom Painters · Zero Material Icons
// 100% matched to location_screen, location_settings, location_sharing styles
// withValues(alpha:) throughout · Pure Flutter animations · Dark theme exact
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/location/night_mode_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// NIGHT MODE SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class NightModeScreen extends StatefulWidget {
  const NightModeScreen({super.key});
  @override
  State<NightModeScreen> createState() => _NightModeScreenState();
}

class _NightModeScreenState extends State<NightModeScreen>
    with TickerProviderStateMixin {

  final _svc = NightModeService.instance;

  bool _autoShare  = true;
  bool _checkIn    = true;
  bool _forceNight = false;

  late AnimationController _moonCtrl;
  late AnimationController _bgCtrl;
  late AnimationController _entryCtrl;
  late Animation<double>   _entryFade;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();

    _autoShare  = _svc.autoSharingEnabled;
    _forceNight = _svc.isNightMode;

    _moonCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _bgCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _entryCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700),
    );
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entryCtrl.forward();

    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _moonCtrl.dispose();
    _bgCtrl.dispose();
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          _buildBackground(size),
          SafeArea(
            child: FadeTransition(
              opacity: _entryFade,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildTopBar()),
                  SliverToBoxAdapter(child: _buildHeroHeader()),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildManualOverrideCard(),
                        const SizedBox(height: 12),
                        _buildAutoBehaviorsCard(),
                        const SizedBox(height: 12),
                        _buildNightChangesCard(),
                        const SizedBox(height: 12),
                        _buildScheduleCard(),
                        const SizedBox(height: 12),
                        _buildInfoCard(),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── BACKGROUND ─────────────────────────────────────────────────────────────
  Widget _buildBackground(Size size) {
    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (_, __) {
        final t = _bgCtrl.value;
        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF06061A), Color(0xFF0A0A20)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              top: -size.height * 0.08 + t * 25,
              right: -size.width * 0.20,
              child: Container(
                width: size.width * 0.70,
                height: size.width * 0.70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFF1A237E).withValues(alpha: 0.08 + t * 0.04),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
            Positioned(
              bottom: -size.height * 0.06 - t * 18,
              left: -size.width * 0.18,
              child: Container(
                width: size.width * 0.60,
                height: size.width * 0.60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFF311B92).withValues(alpha: 0.06 + t * 0.03),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── TOP BAR ────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
            },
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(16, 16),
                  painter: _BackArrowPainter(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Night Mode',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Enhanced protection after dark',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.40),
                  ),
                ),
              ],
            ),
          ),
          // Active indicator
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _svc.isNightMode
                    ? const Color(0xFFFFD54F).withValues(
                    alpha: 0.10 + 0.08 * _pulseCtrl.value)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _svc.isNightMode
                      ? const Color(0xFFFFD54F).withValues(alpha: 0.40)
                      : Colors.white.withValues(alpha: 0.10),
                ),
              ),
              child: Text(
                _svc.isNightMode ? '● ACTIVE' : '○ OFF',
                style: TextStyle(
                  color: _svc.isNightMode
                      ? const Color(0xFFFFD54F)
                      : Colors.white.withValues(alpha: 0.35),
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── HERO HEADER ────────────────────────────────────────────────────────────
  Widget _buildHeroHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF283593), Color(0xFF311B92)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A237E).withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Animated moon painter
          AnimatedBuilder(
            animation: _moonCtrl,
            builder: (_, __) => Transform.translate(
              offset: Offset(0, -4 * _moonCtrl.value + 2),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD54F).withValues(
                          alpha: 0.15 + 0.10 * _moonCtrl.value),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: CustomPaint(
                    size: const Size(38, 38),
                    painter: _MoonStarsPainter(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _svc.isNightMode ? 'NIGHT MODE ACTIVE' : 'NIGHT MODE',
            style: TextStyle(
              color: _svc.isNightMode
                  ? const Color(0xFFFFD54F)
                  : Colors.white.withValues(alpha: 0.80),
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enhanced protection 9PM–6AM\nGPS doubles, thresholds lower, contacts auto-notified',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontFamily: 'Poppins',
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),

          // Status pill
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: _svc.isNightMode
                    ? const Color(0xFFFFD54F).withValues(
                    alpha: 0.12 + 0.06 * _pulseCtrl.value)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _svc.isNightMode
                      ? const Color(0xFFFFD54F).withValues(alpha: 0.45)
                      : Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _svc.isNightMode
                          ? const Color(0xFFFFD54F)
                          : Colors.white.withValues(alpha: 0.40),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _svc.isNightMode
                        ? 'Active — Enhanced Protection ON'
                        : 'Inactive — Normal Mode',
                    style: TextStyle(
                      color: _svc.isNightMode
                          ? const Color(0xFFFFD54F)
                          : Colors.white.withValues(alpha: 0.65),
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── MANUAL OVERRIDE CARD ────────────────────────────────────────────────────
  Widget _buildManualOverrideCard() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            painter: _ToggleSwitchPainter(color: const Color(0xFF7C4DFF)),
            iconColor: const Color(0xFF7C4DFF),
            title: 'Manual Override',
          ),
          _ToggleRow(
            painter: _NightOverridePainter(color: const Color(0xFF7C4DFF)),
            iconColor: const Color(0xFF7C4DFF),
            title: 'Force Night Mode',
            subtitle: 'Override schedule — activate right now',
            value: _forceNight,
            onChanged: (v) async {
              HapticFeedback.lightImpact();
              setState(() => _forceNight = v);
              await _svc.forceNightMode(v);
            },
          ),
        ],
      ),
    );
  }

  // ── AUTO BEHAVIORS CARD ────────────────────────────────────────────────────
  Widget _buildAutoBehaviorsCard() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            painter: _AutoBehaviorPainter(color: AppColors.safeGreen),
            iconColor: AppColors.safeGreen,
            title: 'Automatic Behaviors',
          ),
          _ToggleRow(
            painter: _ShareLocationIconPainter(color: AppColors.safeGreen),
            iconColor: AppColors.safeGreen,
            title: 'Auto-Share Location',
            subtitle: 'Automatically share location with contacts at night',
            value: _autoShare,
            onChanged: (v) async {
              HapticFeedback.lightImpact();
              setState(() => _autoShare = v);
              await _svc.setAutoSharing(v);
            },
          ),
          _CardDivider(),
          _ToggleRow(
            painter: _CheckInPainter(color: AppColors.warningAmber),
            iconColor: AppColors.warningAmber,
            title: 'Midnight Check-In',
            subtitle: 'Prompt at midnight — no response triggers SOS',
            value: _checkIn,
            onChanged: (v) async {
              HapticFeedback.lightImpact();
              setState(() => _checkIn = v);
              await _svc.setCheckIn(v);
            },
          ),
        ],
      ),
    );
  }

  // ── NIGHT CHANGES CARD ─────────────────────────────────────────────────────
  Widget _buildNightChangesCard() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            painter: _ShieldChangePainter(color: AppColors.primary),
            iconColor: AppColors.primary,
            title: 'Night Mode Changes',
          ),
          _InfoRow(
            painter: _GpsCrosshairPainter(color: AppColors.primary),
            color: AppColors.primary,
            text: 'GPS updates every 5 sec (vs 10 sec daytime)',
          ),
          _InfoRow(
            painter: _TimerSmallPainter(color: AppColors.warningAmber),
            color: AppColors.warningAmber,
            text: 'Dead man\'s switch: 3 min (vs 5 min)',
          ),
          _InfoRow(
            painter: _RouteDeviationPainter(color: AppColors.secondary),
            color: AppColors.secondary,
            text: 'Route deviation alert: 150m (vs 300m)',
          ),
          _InfoRow(
            painter: _SpeedGaugePainter(color: AppColors.sosRed),
            color: AppColors.sosRed,
            text: 'Speed anomaly sensitivity: doubled',
          ),
          _InfoRow(
            painter: _SilentSosPainter(color: AppColors.primary),
            color: AppColors.primary,
            text: 'Silent SOS — no alarm, no screen flash',
          ),
          _InfoRow(
            painter: _BellRingPainter(color: AppColors.safeGreen),
            color: AppColors.safeGreen,
            text: 'Contacts notified automatically at activation',
            isLast: true,
          ),
        ],
      ),
    );
  }

  // ── SCHEDULE CARD ──────────────────────────────────────────────────────────
  Widget _buildScheduleCard() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            painter: _ScheduleIconPainter(color: AppColors.secondary),
            iconColor: AppColors.secondary,
            title: 'Active Schedule',
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _TimeCard(
                  label: 'Night Starts',
                  time: '9:00 PM',
                  painter: _MoonSmallPainter(color: const Color(0xFF7C4DFF)),
                  color: const Color(0xFF283593),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimeCard(
                  label: 'Night Ends',
                  time: '6:00 AM',
                  painter: _SunrisePainter(color: AppColors.warningAmber),
                  color: AppColors.warningAmber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── INFO CARD ──────────────────────────────────────────────────────────────
  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border:
        Border.all(color: AppColors.primary.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: CustomPaint(
                size: const Size(16, 16),
                painter: _InfoCirclePainter(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Night Mode activates automatically between 9PM and 6AM daily, or you can force-activate it anytime using the manual override above.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.65),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
    child: child,
  );
}

class _CardDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    margin: const EdgeInsets.symmetric(vertical: 8),
    color: Colors.white.withValues(alpha: 0.06),
  );
}

class _SectionHeader extends StatelessWidget {
  final CustomPainter painter;
  final Color iconColor;
  final String title;

  const _SectionHeader({
    required this.painter,
    required this.iconColor,
    required this.title,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Center(
            child:
            CustomPaint(size: const Size(16, 16), painter: painter),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );
}

class _ToggleRow extends StatelessWidget {
  final CustomPainter painter;
  final Color iconColor;
  final String title, subtitle;
  final bool value;
  final void Function(bool) onChanged;

  const _ToggleRow({
    required this.painter,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child:
          CustomPaint(size: const Size(20, 20), painter: painter),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Colors.white,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.38),
              ),
            ),
          ],
        ),
      ),
      Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: iconColor,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ],
  );
}

class _InfoRow extends StatelessWidget {
  final CustomPainter painter;
  final Color color;
  final String text;
  final bool isLast;

  const _InfoRow({
    required this.painter,
    required this.color,
    required this.text,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
    child: Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child:
            CustomPaint(size: const Size(14, 14), painter: painter),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

class _TimeCard extends StatelessWidget {
  final String label, time;
  final CustomPainter painter;
  final Color color;

  const _TimeCard({
    required this.label,
    required this.time,
    required this.painter,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: 0.22)),
    ),
    child: Column(
      children: [
        CustomPaint(size: const Size(24, 24), painter: painter),
        const SizedBox(height: 8),
        Text(
          time,
          style: TextStyle(
            color: color,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.40),
          ),
        ),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// ALL CUSTOM PAINTERS — ZERO MATERIAL ICONS
// ═══════════════════════════════════════════════════════════════════════════

class _BackArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final cy = s.height / 2;
    canvas.drawLine(Offset(s.width * 0.80, cy), Offset(s.width * 0.20, cy), p);
    final h = Path();
    h.moveTo(s.width * 0.46, cy - s.height * 0.30);
    h.lineTo(s.width * 0.20, cy);
    h.lineTo(s.width * 0.46, cy + s.height * 0.30);
    canvas.drawPath(h, p);
  }
  @override
  bool shouldRepaint(_BackArrowPainter o) => false;
}

class _MoonStarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = const Color(0xFFFFD54F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    // Moon crescent
    canvas.drawArc(
      Rect.fromLTWH(s.width * 0.08, s.height * 0.08, s.width * 0.70, s.height * 0.70),
      math.pi * 0.15, math.pi * 1.70, false, p,
    );
    // Stars
    canvas.drawCircle(Offset(s.width * 0.82, s.height * 0.15), 2.5,
        Paint()..color = const Color(0xFFFFD54F));
    canvas.drawCircle(Offset(s.width * 0.94, s.height * 0.42), 1.8,
        Paint()..color = const Color(0xFFFFD54F).withValues(alpha: 0.70));
    canvas.drawCircle(Offset(s.width * 0.76, s.height * 0.08), 1.5,
        Paint()..color = const Color(0xFFFFD54F).withValues(alpha: 0.55));
    canvas.drawCircle(Offset(s.width * 0.90, s.height * 0.62), 1.2,
        Paint()..color = const Color(0xFFFFD54F).withValues(alpha: 0.45));
  }
  @override
  bool shouldRepaint(_MoonStarsPainter o) => false;
}

class _ToggleSwitchPainter extends CustomPainter {
  final Color color;
  const _ToggleSwitchPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, s.height * 0.28, s.width * 0.68, s.height * 0.44),
        Radius.circular(s.height * 0.22),
      ),
      p,
    );
    canvas.drawCircle(
      Offset(s.width * 0.50, s.height * 0.50),
      s.height * 0.18,
      Paint()..color = color,
    );
  }
  @override
  bool shouldRepaint(_ToggleSwitchPainter o) => o.color != color;
}

class _NightOverridePainter extends CustomPainter {
  final Color color;
  const _NightOverridePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromLTWH(s.width * 0.06, s.height * 0.06, s.width * 0.60, s.height * 0.60),
      math.pi * 0.15, math.pi * 1.70, false, p,
    );
    canvas.drawLine(Offset(s.width * 0.78, 0), Offset(s.width * 0.78, s.height * 0.40), p);
    final arr = Path();
    arr.moveTo(s.width * 0.64, s.height * 0.12);
    arr.lineTo(s.width * 0.78, 0);
    arr.lineTo(s.width * 0.92, s.height * 0.12);
    canvas.drawPath(arr, p);
  }
  @override
  bool shouldRepaint(_NightOverridePainter o) => o.color != color;
}

class _AutoBehaviorPainter extends CustomPainter {
  final Color color;
  const _AutoBehaviorPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromLTWH(s.width * 0.10, s.height * 0.10, s.width * 0.80, s.height * 0.80),
      -math.pi * 0.4, math.pi * 1.8, false, p,
    );
    final arr = Path();
    arr.moveTo(s.width * 0.86, s.height * 0.20);
    arr.lineTo(s.width * 0.92, s.height * 0.10);
    arr.lineTo(s.width * 0.78, s.height * 0.14);
    canvas.drawPath(arr, p);
    canvas.drawCircle(Offset(s.width / 2, s.height / 2), s.width * 0.08,
        Paint()..color = color);
  }
  @override
  bool shouldRepaint(_AutoBehaviorPainter o) => o.color != color;
}

class _ShareLocationIconPainter extends CustomPainter {
  final Color color;
  const _ShareLocationIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(s.width * 0.38, 0);
    path.cubicTo(s.width * 0.14, 0, 0, s.height * 0.22, 0, s.height * 0.42);
    path.cubicTo(0, s.height * 0.60, s.width * 0.14, s.height * 0.74,
        s.width * 0.38, s.height * 0.84);
    path.cubicTo(s.width * 0.62, s.height * 0.74, s.width * 0.76,
        s.height * 0.60, s.width * 0.76, s.height * 0.42);
    path.cubicTo(s.width * 0.76, s.height * 0.22, s.width * 0.62, 0,
        s.width * 0.38, 0);
    path.close();
    canvas.drawPath(path, p);
    canvas.drawCircle(
      Offset(s.width * 0.38, s.height * 0.40),
      s.width * 0.10,
      Paint()..color = color,
    );
    canvas.drawLine(
      Offset(s.width * 0.78, s.height * 0.40),
      Offset(s.width, s.height * 0.40),
      p,
    );
    final arrowHead = Path();
    arrowHead.moveTo(s.width * 0.84, s.height * 0.26);
    arrowHead.lineTo(s.width, s.height * 0.40);
    arrowHead.lineTo(s.width * 0.84, s.height * 0.54);
    canvas.drawPath(arrowHead, p);
  }
  @override
  bool shouldRepaint(_ShareLocationIconPainter o) => o.color != color;
}

class _CheckInPainter extends CustomPainter {
  final Color color;
  const _CheckInPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2; final r = s.width * 0.44;
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4);
    final check = Path();
    check.moveTo(cx - r * 0.40, cy);
    check.lineTo(cx - r * 0.08, cy + r * 0.40);
    check.lineTo(cx + r * 0.42, cy - r * 0.36);
    canvas.drawPath(check,
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
  }
  @override
  bool shouldRepaint(_CheckInPainter o) => o.color != color;
}

class _ShieldChangePainter extends CustomPainter {
  final Color color;
  const _ShieldChangePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final path = Path();
    path.moveTo(s.width * 0.50, 0);
    path.lineTo(s.width, s.height * 0.22);
    path.cubicTo(s.width, s.height * 0.22, s.width * 0.98, s.height * 0.72,
        s.width * 0.50, s.height);
    path.cubicTo(s.width * 0.02, s.height * 0.72, 0, s.height * 0.22,
        0, s.height * 0.22);
    path.close();
    canvas.drawPath(path,
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4
          ..strokeJoin = StrokeJoin.round);
    // Up arrow inside
    final arrow = Path();
    arrow.moveTo(s.width * 0.50, s.height * 0.62);
    arrow.lineTo(s.width * 0.50, s.height * 0.30);
    arrow.moveTo(s.width * 0.34, s.height * 0.46);
    arrow.lineTo(s.width * 0.50, s.height * 0.30);
    arrow.lineTo(s.width * 0.66, s.height * 0.46);
    canvas.drawPath(arrow,
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
  }
  @override
  bool shouldRepaint(_ShieldChangePainter o) => o.color != color;
}

class _GpsCrosshairPainter extends CustomPainter {
  final Color color;
  const _GpsCrosshairPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2;
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), s.width * 0.28, p);
    canvas.drawCircle(Offset(cx, cy), s.width * 0.08, Paint()..color = color);
    canvas.drawLine(Offset(cx, 0), Offset(cx, s.height * 0.20), p);
    canvas.drawLine(Offset(cx, s.height * 0.80), Offset(cx, s.height), p);
    canvas.drawLine(Offset(0, cy), Offset(s.width * 0.20, cy), p);
    canvas.drawLine(Offset(s.width * 0.80, cy), Offset(s.width, cy), p);
  }
  @override
  bool shouldRepaint(_GpsCrosshairPainter o) => o.color != color;
}

class _TimerSmallPainter extends CustomPainter {
  final Color color;
  const _TimerSmallPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2;
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), s.width * 0.44, p);
    canvas.drawLine(Offset(cx, cy * 0.40), Offset(cx, cy), p);
    canvas.drawLine(Offset(cx, cy), Offset(cx + s.width * 0.22, cy + s.height * 0.14), p);
    canvas.drawLine(Offset(cx - s.width * 0.18, 0), Offset(cx + s.width * 0.18, 0),
        Paint()..color = color..strokeWidth = 1.3..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(_TimerSmallPainter o) => o.color != color;
}

class _RouteDeviationPainter extends CustomPainter {
  final Color color;
  const _RouteDeviationPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final route = Path();
    route.moveTo(s.width * 0.10, s.height * 0.80);
    route.cubicTo(s.width * 0.10, s.height * 0.40, s.width * 0.90,
        s.height * 0.60, s.width * 0.90, s.height * 0.20);
    canvas.drawPath(route, p);
    canvas.drawCircle(Offset(s.width * 0.10, s.height * 0.80), 3,
        Paint()..color = color);
    canvas.drawCircle(Offset(s.width * 0.90, s.height * 0.20), 3,
        Paint()..color = color);
    // Deviation indicator
    canvas.drawLine(Offset(s.width * 0.42, s.height * 0.58),
        Offset(s.width * 0.62, s.height * 0.30),
        Paint()..color = color.withValues(alpha: 0.50)..strokeWidth = 1.0
          ..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(_RouteDeviationPainter o) => o.color != color;
}

class _SpeedGaugePainter extends CustomPainter {
  final Color color;
  const _SpeedGaugePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2;
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: s.width * 0.46),
        math.pi, math.pi, false, p);
    canvas.drawLine(Offset(cx, cy), Offset(cx + s.width * 0.32, cy - s.height * 0.20), p);
    canvas.drawCircle(Offset(cx, cy), 2.5, Paint()..color = color);
  }
  @override
  bool shouldRepaint(_SpeedGaugePainter o) => o.color != color;
}

class _SilentSosPainter extends CustomPainter {
  final Color color;
  const _SilentSosPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final speaker = Path();
    speaker.moveTo(s.width * 0.26, s.height * 0.34);
    speaker.lineTo(s.width * 0.12, s.height * 0.34);
    speaker.lineTo(s.width * 0.12, s.height * 0.66);
    speaker.lineTo(s.width * 0.26, s.height * 0.66);
    speaker.lineTo(s.width * 0.50, s.height * 0.88);
    speaker.lineTo(s.width * 0.50, s.height * 0.12);
    speaker.close();
    canvas.drawPath(speaker, p);
    canvas.drawLine(Offset(s.width * 0.62, s.height * 0.22),
        Offset(s.width * 0.88, s.height * 0.78),
        Paint()..color = color..strokeWidth = 1.8..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(_SilentSosPainter o) => o.color != color;
}

class _BellRingPainter extends CustomPainter {
  final Color color;
  const _BellRingPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final bell = Path();
    bell.moveTo(s.width * 0.20, s.height * 0.70);
    bell.lineTo(s.width * 0.10, s.height * 0.70);
    bell.quadraticBezierTo(s.width * 0.10, s.height * 0.56,
        s.width * 0.20, s.height * 0.52);
    bell.quadraticBezierTo(s.width * 0.20, s.height * 0.18,
        s.width * 0.50, s.height * 0.18);
    bell.quadraticBezierTo(s.width * 0.80, s.height * 0.18,
        s.width * 0.80, s.height * 0.52);
    bell.lineTo(s.width * 0.90, s.height * 0.56);
    bell.quadraticBezierTo(s.width * 0.90, s.height * 0.70,
        s.width * 0.80, s.height * 0.70);
    bell.close();
    canvas.drawPath(bell, p);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(s.width * 0.50, s.height * 0.84),
          width: s.width * 0.20, height: s.height * 0.20),
      0, math.pi, false, p,
    );
    // Ring waves right
    for (int i = 1; i <= 2; i++) {
      canvas.drawArc(
        Rect.fromCenter(
            center: Offset(s.width * 0.50, s.height * 0.44),
            width: s.width * (0.40 + i * 0.18),
            height: s.height * (0.40 + i * 0.18)),
        -math.pi * 0.7, math.pi * 0.4, false,
        Paint()..color = color.withValues(alpha: 0.40)..style = PaintingStyle.stroke
          ..strokeWidth = 0.9..strokeCap = StrokeCap.round,
      );
    }
  }
  @override
  bool shouldRepaint(_BellRingPainter o) => o.color != color;
}

class _ScheduleIconPainter extends CustomPainter {
  final Color color;
  const _ScheduleIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2;
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), s.width * 0.44, p);
    canvas.drawLine(Offset(cx, cy * 0.40), Offset(cx, cy), p);
    canvas.drawLine(Offset(cx, cy), Offset(cx + s.width * 0.22, cy + s.height * 0.14), p);
    canvas.drawLine(Offset(cx - s.width * 0.18, 0), Offset(cx + s.width * 0.18, 0),
        Paint()..color = color..strokeWidth = 1.4..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(_ScheduleIconPainter o) => o.color != color;
}

class _MoonSmallPainter extends CustomPainter {
  final Color color;
  const _MoonSmallPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawArc(
      Rect.fromLTWH(0, 0, s.width * 0.80, s.height),
      math.pi * 0.15, math.pi * 1.70, false,
      Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(s.width * 0.84, s.height * 0.18), 2.0,
        Paint()..color = color);
    canvas.drawCircle(Offset(s.width * 0.96, s.height * 0.48), 1.4,
        Paint()..color = color.withValues(alpha: 0.65));
  }
  @override
  bool shouldRepaint(_MoonSmallPainter o) => o.color != color;
}

class _SunrisePainter extends CustomPainter {
  final Color color;
  const _SunrisePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height * 0.60;
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    // Sun half circle
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy), width: s.width * 0.60, height: s.height * 0.60),
      math.pi, math.pi, false, p,
    );
    // Horizon line
    canvas.drawLine(Offset(0, cy), Offset(s.width, cy), p);
    // Rays
    final rays = [
      [cx, 0.0, cx, cy - s.height * 0.38],
      [cx + s.width * 0.34, cy - s.height * 0.24, cx + s.width * 0.44, cy - s.height * 0.32],
      [cx - s.width * 0.34, cy - s.height * 0.24, cx - s.width * 0.44, cy - s.height * 0.32],
    ];
    for (final r in rays) {
      canvas.drawLine(Offset(r[0], r[1]), Offset(r[2], r[3]),
          Paint()..color = color.withValues(alpha: 0.70)..strokeWidth = 1.3
            ..strokeCap = StrokeCap.round);
    }
  }
  @override
  bool shouldRepaint(_SunrisePainter o) => o.color != color;
}

class _InfoCirclePainter extends CustomPainter {
  final Color color;
  const _InfoCirclePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2; final r = s.width * 0.46;
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3);
    canvas.drawCircle(Offset(cx, cy - r * 0.38), s.width * 0.07,
        Paint()..color = color);
    canvas.drawLine(Offset(cx, cy - r * 0.12), Offset(cx, cy + r * 0.44),
        Paint()..color = color..strokeWidth = 1.6..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(_InfoCirclePainter o) => o.color != color;
}