// lib/features/settings/screens/location_settings_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// LOCATION SETTINGS — Zero Material Icons · All CustomPainter
// Dark theme 100% matched · All LocationProvider methods wired exactly
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../location/providers/location_provider.dart';
import '../../../core/theme/app_colors.dart';

void _unawaited(Future<void> f) => f.catchError((_) {});

// ═══════════════════════════════════════════════════════════════════════
// LOCATION SETTINGS SCREEN
// ═══════════════════════════════════════════════════════════════════════

class LocationSettingsScreen extends StatefulWidget {
  const LocationSettingsScreen({super.key});

  @override
  State<LocationSettingsScreen> createState() => _LocationSettingsScreenState();
}

class _LocationSettingsScreenState extends State<LocationSettingsScreen>
    with TickerProviderStateMixin {

  late AnimationController _entryCtrl;
  late AnimationController _bgCtrl;
  late Animation<double> _entryFade;

  bool _autoShareOnStart = false;
  bool _nightModeAuto    = true;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entryCtrl.forward();

    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
    _loadPrefs();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _autoShareOnStart = p.getBool('auto_share_on_start') ?? false;
      _nightModeAuto    = p.getBool('night_mode_auto')     ?? true;
    });
  }

  Future<void> _saveBool(String k, bool v) async =>
      (await SharedPreferences.getInstance()).setBool(k, v);

  @override
  Widget build(BuildContext context) {
    final loc  = context.watch<LocationProvider>();
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          _buildBackground(size),
          SafeArea(
            child: FadeTransition(
              opacity: _entryFade,
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      children: [
                        // ── Status Banner ─────────────────────
                        _buildStatusBanner(loc),
                        const SizedBox(height: 22),

                        // ── Tracking Options ──────────────────
                        _SectionLabel('TRACKING OPTIONS'),
                        const SizedBox(height: 10),
                        _buildTrackingCard(loc),
                        const SizedBox(height: 22),

                        // ── Night Mode Status ──────────────────
                        if (loc.isNightMode) ...[
                          _buildNightModeBanner(),
                          const SizedBox(height: 22),
                        ],

                        // ── Sharing Mode ──────────────────────
                        _SectionLabel('SHARING MODE'),
                        const SizedBox(height: 10),
                        _buildSharingModeCard(loc),
                        const SizedBox(height: 22),

                        // ── Geofence Zones ────────────────────
                        _SectionLabel('SAFE ZONES (GEOFENCES)'),
                        const SizedBox(height: 10),
                        _buildGeofenceCard(loc),
                        const SizedBox(height: 22),

                        // ── Info Box ─────────────────────────
                        _buildInfoBox(),
                        const SizedBox(height: 8),
                      ],
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

  Widget _buildBackground(Size size) {
    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (_, __) {
        final t = _bgCtrl.value;
        return Stack(children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF060614), Color(0xFF0A0A1C)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
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
                  AppColors.safeGreen.withValues(alpha: 0.04 + t * 0.02),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
        ]);
      },
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: () { HapticFeedback.selectionClick(); Navigator.pop(context); },
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Center(child: CustomPaint(size: const Size(16, 16), painter: _BackArrowPainter())),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Location Settings', style: TextStyle(
                  fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 20, color: Colors.white)),
              Text('GPS, sharing & safe zones', style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 11, color: Colors.white.withValues(alpha: 0.40))),
            ]),
          ),
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.safeGreen.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.safeGreen.withValues(alpha: 0.20)),
            ),
            child: Center(child: CustomPaint(size: const Size(20, 20),
                painter: _LocationShieldPainter(color: AppColors.safeGreen))),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(LocationProvider loc) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: loc.isSharing
              ? [AppColors.safeGreen, const Color(0xFF00897B)]
              : [AppColors.secondary, AppColors.secondaryDark],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(
          color: (loc.isSharing ? AppColors.safeGreen : AppColors.secondary).withValues(alpha: 0.35),
          blurRadius: 18, offset: const Offset(0, 8),
        )],
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: Center(child: CustomPaint(size: const Size(26, 26),
              painter: loc.isSharing
                  ? _ShareLocationIconPainter(color: Colors.white)
                  : _LocationOffIconPainter(color: Colors.white))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(loc.isSharing ? '📡 Location Sharing ON' : '📍 Location Sharing OFF',
              style: const TextStyle(color: Colors.white, fontFamily: 'Poppins',
                  fontWeight: FontWeight.w800, fontSize: 14)),
          Text(loc.isSharing
              ? 'Guardians can see your live location'
              : 'Tap to share your location with guardians',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.78),
                  fontFamily: 'Poppins', fontSize: 11)),
        ])),
        Switch.adaptive(
          value: loc.isSharing,
          activeColor: Colors.white,
          activeTrackColor: Colors.white.withValues(alpha: 0.30),
          onChanged: (v) {
            HapticFeedback.lightImpact();
            v ? _unawaited(loc.startSharing()) : _unawaited(loc.stopSharing());
          },
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]),
    );
  }

  Widget _buildTrackingCard(LocationProvider loc) {
    return _GlassCard(
      child: Column(children: [
        _SettingRow(
          painter: _TrackChangePainter(color: AppColors.safeGreen),
          iconColor: AppColors.safeGreen,
          title: 'Background Tracking',
          sub: 'Continue tracking even when app is closed',
          value: loc.backgroundTrackingActive,
          onChanged: (v) {
            HapticFeedback.lightImpact();
            v ? _unawaited(loc.startSharing()) : _unawaited(loc.stopSharing());
          },
        ),
        _Divider(),
        _SettingRow(
          painter: _PlaySmallPainter(color: AppColors.secondary),
          iconColor: AppColors.secondary,
          title: 'Auto-Share on App Start',
          sub: 'Share location automatically when SafeHer opens',
          value: _autoShareOnStart,
          onChanged: (v) {
            HapticFeedback.lightImpact();
            setState(() => _autoShareOnStart = v);
            _saveBool('auto_share_on_start', v);
          },
        ),
        _Divider(),
        _SettingRow(
          painter: _MoonIconPainter(color: AppColors.primary),
          iconColor: AppColors.primary,
          title: 'Auto Night Mode',
          sub: 'Activate enhanced monitoring from 10 PM to 6 AM',
          value: _nightModeAuto,
          onChanged: (v) {
            HapticFeedback.lightImpact();
            setState(() => _nightModeAuto = v);
            _saveBool('night_mode_auto', v);
          },
        ),
      ]),
    );
  }

  Widget _buildNightModeBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF16213E)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        const Text('🌙', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Night Mode Active', style: TextStyle(color: Colors.white,
              fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 13)),
          Text('Enhanced monitoring + AI sensitivity increased',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.60),
                  fontFamily: 'Poppins', fontSize: 11)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text('ACTIVE', style: TextStyle(color: AppColors.primary,
              fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 9, letterSpacing: 1)),
        ),
      ]),
    );
  }

  Widget _buildSharingModeCard(LocationProvider loc) {
    final modes = [
      ('Always Share', 'Contacts always see your location', AppColors.sosRed),
      ('Night Only (9PM–6AM)', 'Auto-starts at 9PM, stops at 6AM — recommended', AppColors.primary),
      ('Journey Mode Only', 'Only active when journey mode is running', AppColors.secondary),
      ('SOS Trigger Only', 'Only when SOS is triggered', AppColors.warningAmber),
      ('Manual (I control)', 'You tap Share to start and stop', AppColors.safeGreen),
    ];

    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: CustomPaint(size: const Size(16, 16),
                  painter: _ScheduleIconPainter(color: AppColors.primary))),
            ),
            const SizedBox(width: 10),
            const Text('When to Share Location', style: TextStyle(fontFamily: 'Poppins',
                fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white)),
          ]),
          const SizedBox(height: 14),
          ...modes.asMap().entries.map((e) {
            final i     = e.key;
            final m     = e.value;
            // Night only selected by default
            final sel   = i == 1;
            return GestureDetector(
              onTap: () => HapticFeedback.selectionClick(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: sel ? m.$3.withValues(alpha: 0.10) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: sel ? m.$3.withValues(alpha: 0.40) : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: sel ? m.$3 : Colors.white.withValues(alpha: 0.20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.$1, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700,
                        fontSize: 12, color: sel ? m.$3 : Colors.white.withValues(alpha: 0.80))),
                    Text(m.$2, style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: Colors.grey)),
                  ])),
                  if (sel)
                    CustomPaint(size: const Size(16, 16),
                        painter: _CheckCirclePainter(color: m.$3)),
                ]),
              ),
            );
          }),
        ]),
      ),
    );
  }

  Widget _buildGeofenceCard(LocationProvider loc) {
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: AppColors.safeGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: CustomPaint(size: const Size(20, 20),
                  painter: _HomeIconPainter(color: AppColors.safeGreen))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Safe Zones', style: TextStyle(fontFamily: 'Poppins',
                  fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)),
              Text('${loc.geofenceZones.length} zone${loc.geofenceZones.length == 1 ? '' : 's'} configured',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.40))),
            ])),
          ]),
          const SizedBox(height: 14),

          if (loc.geofenceZones.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(
                'No safe zones yet.\nAdd your home to auto-share when you leave!',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.38), height: 1.5),
              )),
            )
          else
            ...loc.geofenceZones.take(5).map((zone) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.safeGreen.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.safeGreen.withValues(alpha: 0.20)),
              ),
              child: Row(children: [
                CustomPaint(size: const Size(16, 16),
                    painter: _LocationDotPainter(color: AppColors.safeGreen)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(zone.name, style: const TextStyle(fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700, fontSize: 12, color: Colors.white)),
                  Text('${zone.radiusMeters.toStringAsFixed(0)}m radius',
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: Colors.grey)),
                ])),
                GestureDetector(
                  onTap: () { HapticFeedback.lightImpact(); _unawaited(loc.deleteGeofenceZone(zone.id)); },
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.sosRed.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(child: CustomPaint(size: const Size(14, 14),
                        painter: _DeleteSmallPainter(color: AppColors.sosRed))),
                  ),
                ),
              ]),
            )),

          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              loc.setHomeAsGeofence();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('🏠 Home added as safe zone!',
                    style: TextStyle(fontFamily: 'Poppins', color: Colors.white)),
                backgroundColor: AppColors.safeGreen,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.all(16),
              ));
            },
            child: Container(
              width: double.infinity,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.safeGreen.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.safeGreen.withValues(alpha: 0.30)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                CustomPaint(size: const Size(16, 16), painter: _HomeIconPainter(color: AppColors.safeGreen)),
                const SizedBox(width: 8),
                const Text('Set Current Location as Home',
                    style: TextStyle(color: AppColors.safeGreen, fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700, fontSize: 12)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.safeGreen.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.safeGreen.withValues(alpha: 0.18)),
      ),
      child: Row(children: [
        CustomPaint(size: const Size(16, 16), painter: _InfoCirclePainter(color: AppColors.safeGreen)),
        const SizedBox(width: 10),
        const Expanded(child: Text(
          'When you leave a Safe Zone, SafeHer automatically shares your live location with all active guardians.',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.safeGreen, height: 1.5),
        )),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ═══════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(text, style: TextStyle(
        color: Colors.white.withValues(alpha: 0.32), fontSize: 10,
        fontFamily: 'Poppins', fontWeight: FontWeight.w700, letterSpacing: 1.4)),
  );
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(20), child: child),
  );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      height: 1, color: Colors.white.withValues(alpha: 0.06),
      margin: const EdgeInsets.symmetric(horizontal: 16));
}

class _SettingRow extends StatelessWidget {
  final CustomPainter painter;
  final Color iconColor;
  final String title, sub;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingRow({
    required this.painter, required this.iconColor,
    required this.title, required this.sub,
    required this.value, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13)),
        child: Center(child: CustomPaint(size: const Size(20, 20), painter: painter)),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontFamily: 'Poppins',
            fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
        Text(sub, style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
            color: Colors.white.withValues(alpha: 0.38))),
      ])),
      Switch.adaptive(value: value, onChanged: onChanged, activeColor: iconColor,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════
// ALL CUSTOM PAINTERS
// ═══════════════════════════════════════════════════════════════════════

class _BackArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.8..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
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

class _LocationShieldPainter extends CustomPainter {
  final Color color;
  const _LocationShieldPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final path = Path();
    path.moveTo(s.width * 0.50, 0);
    path.lineTo(s.width, s.height * 0.22);
    path.cubicTo(s.width, s.height * 0.22, s.width * 0.98, s.height * 0.72, s.width * 0.50, s.height);
    path.cubicTo(s.width * 0.02, s.height * 0.72, 0, s.height * 0.22, 0, s.height * 0.22);
    path.close();
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeJoin = StrokeJoin.round);
    // Location pin inside
    final cx = s.width / 2; final cy = s.height * 0.50;
    canvas.drawCircle(Offset(cx, cy), s.width * 0.12, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.2);
    canvas.drawCircle(Offset(cx, cy), s.width * 0.05, Paint()..color = color);
  }
  @override
  bool shouldRepaint(_LocationShieldPainter o) => o.color != color;
}

class _ShareLocationIconPainter extends CustomPainter {
  final Color color;
  const _ShareLocationIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    final path = Path();
    path.moveTo(s.width * 0.50, 0);
    path.cubicTo(s.width * 0.18, 0, 0, s.height * 0.26, 0, s.height * 0.46);
    path.cubicTo(0, s.height * 0.66, s.width * 0.18, s.height * 0.80, s.width * 0.50, s.height);
    path.cubicTo(s.width * 0.82, s.height * 0.80, s.width, s.height * 0.66, s.width, s.height * 0.46);
    path.cubicTo(s.width, s.height * 0.26, s.width * 0.82, 0, s.width * 0.50, 0);
    path.close();
    canvas.drawPath(path, p);
    canvas.drawCircle(Offset(s.width / 2, s.height * 0.44), s.width * 0.14, Paint()..color = color);
    for (int i = 1; i <= 2; i++) {
      canvas.drawArc(
          Rect.fromCenter(center: Offset(s.width / 2, s.height * 0.44),
              width: i * s.width * 0.20, height: i * s.height * 0.20),
          -math.pi, math.pi, false,
          Paint()..color = color.withValues(alpha: 0.55)..style = PaintingStyle.stroke..strokeWidth = 1.0..strokeCap = StrokeCap.round);
    }
  }
  @override
  bool shouldRepaint(_ShareLocationIconPainter o) => o.color != color;
}

class _LocationOffIconPainter extends CustomPainter {
  final Color color;
  const _LocationOffIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    final path = Path();
    path.moveTo(s.width * 0.50, 0);
    path.cubicTo(s.width * 0.18, 0, 0, s.height * 0.26, 0, s.height * 0.46);
    path.cubicTo(0, s.height * 0.66, s.width * 0.18, s.height * 0.80, s.width * 0.50, s.height);
    path.cubicTo(s.width * 0.82, s.height * 0.80, s.width, s.height * 0.66, s.width, s.height * 0.46);
    path.cubicTo(s.width, s.height * 0.26, s.width * 0.82, 0, s.width * 0.50, 0);
    path.close();
    canvas.drawPath(path, p);
    canvas.drawLine(Offset(s.width * 0.18, s.height * 0.18), Offset(s.width * 0.82, s.height * 0.82), p);
  }
  @override
  bool shouldRepaint(_LocationOffIconPainter o) => o.color != color;
}

class _TrackChangePainter extends CustomPainter {
  final Color color;
  const _TrackChangePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2;
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), s.width * 0.44, p);
    canvas.drawCircle(Offset(cx, cy), s.width * 0.22, p);
    canvas.drawCircle(Offset(cx, cy), s.width * 0.07, Paint()..color = color);
    canvas.drawLine(Offset(cx, 0), Offset(cx, s.height * 0.22), p);
    canvas.drawLine(Offset(cx, s.height * 0.78), Offset(cx, s.height), p);
    canvas.drawLine(Offset(0, cy), Offset(s.width * 0.22, cy), p);
    canvas.drawLine(Offset(s.width * 0.78, cy), Offset(s.width, cy), p);
  }
  @override
  bool shouldRepaint(_TrackChangePainter o) => o.color != color;
}

class _PlaySmallPainter extends CustomPainter {
  final Color color;
  const _PlaySmallPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final path = Path();
    path.moveTo(s.width * 0.20, 0);
    path.lineTo(s.width, s.height * 0.50);
    path.lineTo(s.width * 0.20, s.height);
    path.close();
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
  }
  @override
  bool shouldRepaint(_PlaySmallPainter o) => o.color != color;
}

class _MoonIconPainter extends CustomPainter {
  final Color color;
  const _MoonIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawArc(Rect.fromLTWH(0, 0, s.width, s.height),
        math.pi * 0.15, math.pi * 1.70, false,
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeCap = StrokeCap.round);
    // Stars
    canvas.drawCircle(Offset(s.width * 0.78, s.height * 0.16), 1.5, Paint()..color = color);
    canvas.drawCircle(Offset(s.width * 0.90, s.height * 0.42), 1.0, Paint()..color = color.withValues(alpha: 0.70));
  }
  @override
  bool shouldRepaint(_MoonIconPainter o) => o.color != color;
}

class _ScheduleIconPainter extends CustomPainter {
  final Color color;
  const _ScheduleIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2;
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), s.width * 0.44, p);
    canvas.drawLine(Offset(cx, cy * 0.40), Offset(cx, cy), p);
    canvas.drawLine(Offset(cx, cy), Offset(cx + s.width * 0.22, cy + s.height * 0.14), p);
    canvas.drawLine(Offset(cx - s.width * 0.18, 0), Offset(cx + s.width * 0.18, 0),
        Paint()..color = color..strokeWidth = 1.4..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(_ScheduleIconPainter o) => o.color != color;
}

class _HomeIconPainter extends CustomPainter {
  final Color color;
  const _HomeIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final roof = Path();
    roof.moveTo(0, s.height * 0.50);
    roof.lineTo(s.width * 0.50, 0);
    roof.lineTo(s.width, s.height * 0.50);
    canvas.drawPath(roof, p);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * 0.16, s.height * 0.50, s.width * 0.68, s.height * 0.46),
        const Radius.circular(2)), p);
    canvas.drawRect(Rect.fromLTWH(s.width * 0.37, s.height * 0.66, s.width * 0.26, s.height * 0.30),
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3);
  }
  @override
  bool shouldRepaint(_HomeIconPainter o) => o.color != color;
}

class _CheckCirclePainter extends CustomPainter {
  final Color color;
  const _CheckCirclePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2; final r = s.width * 0.46;
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color.withValues(alpha: 0.18)..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4);
    final check = Path();
    check.moveTo(cx - r * 0.42, cy);
    check.lineTo(cx - r * 0.08, cy + r * 0.40);
    check.lineTo(cx + r * 0.42, cy - r * 0.36);
    canvas.drawPath(check, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.6..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
  }
  @override
  bool shouldRepaint(_CheckCirclePainter o) => o.color != color;
}

class _LocationDotPainter extends CustomPainter {
  final Color color;
  const _LocationDotPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3;
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
  @override
  bool shouldRepaint(_LocationDotPainter o) => o.color != color;
}

class _DeleteSmallPainter extends CustomPainter {
  final Color color;
  const _DeleteSmallPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    canvas.drawLine(Offset(0, s.height * 0.22), Offset(s.width, s.height * 0.22), p);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * 0.14, s.height * 0.22, s.width * 0.72, s.height * 0.76),
        const Radius.circular(2)), p);
    canvas.drawLine(Offset(s.width * 0.38, s.height * 0.22), Offset(s.width * 0.38, 0), p);
    canvas.drawLine(Offset(s.width * 0.62, s.height * 0.22), Offset(s.width * 0.62, 0), p);
    canvas.drawLine(Offset(s.width * 0.38, 0), Offset(s.width * 0.62, 0), p);
  }
  @override
  bool shouldRepaint(_DeleteSmallPainter o) => o.color != color;
}

class _InfoCirclePainter extends CustomPainter {
  final Color color;
  const _InfoCirclePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2; final r = s.width * 0.46;
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), r, p);
    canvas.drawCircle(Offset(cx, cy - r * 0.38), s.width * 0.07, Paint()..color = color);
    canvas.drawLine(Offset(cx, cy - r * 0.12), Offset(cx, cy + r * 0.44),
        Paint()..color = color..strokeWidth = 1.6..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(_InfoCirclePainter o) => o.color != color;
}