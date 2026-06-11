// lib/features/settings/screens/sos_settings_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// SAFEHER — SOS SETTINGS SCREEN
// ✅ Zero Material icons — all CustomPainter
// ✅ All withValues(alpha:) — zero withOpacity()
// ✅ No animate_do — pure Flutter animations
// ✅ All SosProvider methods wired exactly
// ✅ Design language matches sos_screen.dart 100%
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../sos/providers/sos_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/notification_service.dart';

void _unawaited(Future<void> f) => f.catchError((_) {});

// ═══════════════════════════════════════════════════════════════
// SOS SETTINGS SCREEN
// ═══════════════════════════════════════════════════════════════

class SosSettingsScreen extends StatefulWidget {
  const SosSettingsScreen({super.key});

  @override
  State<SosSettingsScreen> createState() => _SosSettingsScreenState();
}

class _SosSettingsScreenState extends State<SosSettingsScreen>
    with TickerProviderStateMixin {

  // ── PIN state ─────────────────────────────────────────────────
  final _oldCtrl  = TextEditingController();
  final _newCtrl  = TextEditingController();
  final _conCtrl  = TextEditingController();
  bool   _showOld = false;
  bool   _showNew = false;
  bool   _showCon = false;
  bool   _pinSaving = false;
  String _pinError   = '';
  bool   _pinSuccess = false;

  // ── Animations ────────────────────────────────────────────────
  late AnimationController _entryCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _bgCtrl;
  late Animation<double>   _entryFade;
  late Animation<double>   _pulse;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _entryFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: Curves.easeOut,
    );
    _entryCtrl.forward();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(
      parent: _pulseCtrl,
      curve: Curves.easeInOut,
    );

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    _bgCtrl.dispose();
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _conCtrl.dispose();
    super.dispose();
  }

  // ── PIN change ────────────────────────────────────────────────
  Future<void> _changePin() async {
    setState(() { _pinError = ''; _pinSuccess = false; });
    final old = _oldCtrl.text.trim();
    final nw  = _newCtrl.text.trim();
    final con = _conCtrl.text.trim();

    if (old.length < 4) { setState(() => _pinError = 'Current PIN must be 4+ digits'); return; }
    if (nw.length  < 4) { setState(() => _pinError = 'New PIN must be at least 4 digits'); return; }
    if (nw != con)       { setState(() => _pinError = 'New PINs do not match'); return; }
    if (nw == old)       { setState(() => _pinError = 'New PIN must be different from current'); return; }

    setState(() => _pinSaving = true);
    final ok = await context.read<SosProvider>().changePin(old, nw);
    if (!mounted) return;
    setState(() => _pinSaving = false);

    if (ok) {
      _oldCtrl.clear(); _newCtrl.clear(); _conCtrl.clear();
      setState(() => _pinSuccess = true);
      HapticFeedback.mediumImpact();
      _unawaited(NotificationService.instance.showPinChanged());
      _showSnack('SOS PIN updated successfully', AppColors.safeGreen);
    } else {
      HapticFeedback.heavyImpact();
      setState(() => _pinError = 'Current PIN is incorrect');
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            CustomPaint(
              size: const Size(16, 16),
              painter: color == AppColors.safeGreen
                  ? _CheckCirclePainter(color: Colors.white)
                  : _WarningPainter(color: Colors.white),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sos  = context.watch<SosProvider>();
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          // Background
          _buildBackground(size),

          // Content
          SafeArea(
            child: FadeTransition(
              opacity: _entryFade,
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 50),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([

                              // ── Live Status Card ─────────────────────────
                              _buildStatusCard(sos),
                              const SizedBox(height: 22),

                              // ── Triggers ─────────────────────────────────
                              _SectionLabel('SOS TRIGGERS'),
                              const SizedBox(height: 10),
                              _buildTriggersCard(sos),
                              const SizedBox(height: 22),

                              // ── Countdown ────────────────────────────────
                              _SectionLabel('COUNTDOWN BEFORE SOS FIRES'),
                              const SizedBox(height: 10),
                              _buildCountdownCard(sos),
                              const SizedBox(height: 22),

                              // ── SOS PIN ───────────────────────────────────
                              _SectionLabel('SOS SAFE PIN'),
                              const SizedBox(height: 10),
                              _buildPinCard(),
                              const SizedBox(height: 22),

                              // ── Evidence info ─────────────────────────────
                              _SectionLabel('AUTO EVIDENCE ON SOS'),
                              const SizedBox(height: 10),
                              _buildEvidenceCard(),
                              const SizedBox(height: 12),
                            ]),
                          ),
                        ),
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

  // ── Background ────────────────────────────────────────────────
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
                  colors: [Color(0xFF0A0010), Color(0xFF120008), Color(0xFF0D0D1A)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              top: -size.height * 0.08 + t * 25,
              left: size.width * 0.05,
              child: Container(
                width: size.width * 0.75,
                height: size.width * 0.75,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.sosRed.withValues(alpha: 0.05 + t * 0.03),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -size.height * 0.05 - t * 20,
              right: -size.width * 0.15,
              child: Container(
                width: size.width * 0.60,
                height: size.width * 0.60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.04 + t * 0.02),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Top bar ───────────────────────────────────────────────────
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
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
                  'SOS Settings',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Configure emergency response',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.40),
                  ),
                ),
              ],
            ),
          ),
          // SOS indicator dot
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.sosRed.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: AppColors.sosRed.withValues(alpha: 0.20),
                width: 1,
              ),
            ),
            child: Center(
              child: CustomPaint(
                size: const Size(20, 20),
                painter: _SosShieldPainter(color: AppColors.sosRed),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Status card ───────────────────────────────────────────────
  Widget _buildStatusCard(SosProvider sos) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final active = sos.isSosActive;
        final color  = active ? AppColors.sosRed : AppColors.primary;
        final t      = _pulse.value;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: active
                  ? [AppColors.sosRed, const Color(0xFFB71C1C)]
                  : [AppColors.primary, AppColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.30 + 0.15 * t),
                blurRadius: 20 + 10 * t,
                offset: const Offset(0, 8),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              // Animated icon container
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Transform.scale(
                  scale: active ? 1.0 + _pulseCtrl.value * 0.06 : 1.0,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: CustomPaint(
                        size: const Size(28, 28),
                        painter: active
                            ? _SosActiveIconPainter()
                            : _ShieldCheckPainter(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      active ? 'SOS ACTIVE' : 'SOS Ready',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      active
                          ? 'Emergency active · ${sos.activeDurationStr}'
                          : 'Shake · Voice · Hardware · Manual',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.80),
                        fontFamily: 'Poppins',
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Active systems row
                    Row(
                      children: [
                        _StatusPill(
                          painter: _VibrateSmallPainter(
                            color: sos.shakeEnabled
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.40),
                          ),
                          label: 'Shake',
                          active: sos.shakeEnabled,
                        ),
                        const SizedBox(width: 5),
                        _StatusPill(
                          painter: _SoundWaveSmallPainter(
                            color: sos.alarmEnabled
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.40),
                          ),
                          label: 'Alarm',
                          active: sos.alarmEnabled,
                        ),
                        const SizedBox(width: 5),
                        _StatusPill(
                          painter: _TimerSmallPainter(color: Colors.white),
                          label: '${sos.countdownTotal}s',
                          active: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Countdown badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.30),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '${sos.countdownTotal}s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      'DELAY',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontFamily: 'Poppins',
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Triggers card ─────────────────────────────────────────────
  Widget _buildTriggersCard(SosProvider sos) {
    return _GlassCard(
      child: Column(
        children: [
          _ToggleRow(
            painter: _VibrateIconPainter(color: AppColors.primary),
            iconColor: AppColors.primary,
            title: 'Shake to SOS',
            sub: 'Shake phone 3× rapidly to trigger emergency',
            value: sos.shakeEnabled,
            onChanged: (v) async {
              HapticFeedback.selectionClick();
              await sos.toggleShake(v);
              _unawaited(
                NotificationService.instance.showShakeToggled(enabled: v),
              );
            },
          ),
          _CardDivider(),
          _ToggleRow(
            painter: _SoundWavePainter(color: AppColors.sosRed),
            iconColor: AppColors.sosRed,
            title: 'SOS Alarm Sound',
            sub: 'Loud siren plays immediately on SOS trigger',
            value: sos.alarmEnabled,
            onChanged: (v) async {
              HapticFeedback.selectionClick();
              await sos.toggleAlarm(v);
            },
          ),
        ],
      ),
    );
  }

  // ── Countdown card ────────────────────────────────────────────
  Widget _buildCountdownCard(SosProvider sos) {
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.warningAmber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: CustomPaint(
                      size: const Size(20, 20),
                      painter: _TimerIconPainter(color: AppColors.warningAmber),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Countdown Duration',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${sos.countdownTotal}s window to cancel accidental triggers',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.40),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Countdown selector buttons
            Row(
              children: [3, 5, 10].map((s) {
                final sel = sos.countdownTotal == s;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      sos.setCountdownSeconds(s);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 86,
                      decoration: BoxDecoration(
                        gradient: sel ? AppColors.primaryGradient : null,
                        color: sel
                            ? null
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: sel
                            ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ]
                            : [],
                        border: sel
                            ? null
                            : Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${s}s',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w900,
                              fontSize: 26,
                              color: sel
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.38),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s == 3 ? 'Quick' : s == 5 ? 'Normal' : 'Cautious',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: sel
                                  ? Colors.white.withValues(alpha: 0.80)
                                  : Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Info banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningAmber.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warningAmber.withValues(alpha: 0.18),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  CustomPaint(
                    size: const Size(14, 14),
                    painter: _InfoCirclePainter(color: AppColors.warningAmber),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Shorter countdown = faster help, but more chance of accidental triggers.',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: AppColors.warningAmber,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── PIN card ──────────────────────────────────────────────────
  Widget _buildPinCard() {
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.sosRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: CustomPaint(
                      size: const Size(20, 20),
                      painter: _LockIconPainter(color: AppColors.sosRed),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Change SOS PIN',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Required to safely resolve an active SOS',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.40),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // PIN fields
            _PinInputField(
              ctrl: _oldCtrl,
              label: 'Current PIN',
              show: _showOld,
              iconPainter: _LockIconPainter(color: AppColors.sosRed),
              onToggle: () => setState(() => _showOld = !_showOld),
            ),
            const SizedBox(height: 10),
            _PinInputField(
              ctrl: _newCtrl,
              label: 'New PIN (min 4 digits)',
              show: _showNew,
              iconPainter: _LockOpenPainter(color: AppColors.secondary),
              onToggle: () => setState(() => _showNew = !_showNew),
            ),
            const SizedBox(height: 10),
            _PinInputField(
              ctrl: _conCtrl,
              label: 'Confirm New PIN',
              show: _showCon,
              iconPainter: _LockOpenPainter(color: AppColors.secondary),
              onToggle: () => setState(() => _showCon = !_showCon),
            ),

            // Error message
            if (_pinError.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.sosRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.sosRed.withValues(alpha: 0.22),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    CustomPaint(
                      size: const Size(14, 14),
                      painter: _ErrorCirclePainter(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _pinError,
                        style: const TextStyle(
                          color: AppColors.sosRed,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Success message
            if (_pinSuccess) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.safeGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.safeGreen.withValues(alpha: 0.22),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    CustomPaint(
                      size: const Size(14, 14),
                      painter: _CheckCirclePainter(color: AppColors.safeGreen),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'PIN updated successfully',
                      style: TextStyle(
                        color: AppColors.safeGreen,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),

            // Update button
            GestureDetector(
              onTap: _pinSaving ? null : _changePin,
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: _pinSaving
                      ? null
                      : AppColors.sosGradient,
                  color: _pinSaving
                      ? Colors.white.withValues(alpha: 0.06)
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _pinSaving
                      ? []
                      : [
                    BoxShadow(
                      color: AppColors.sosRed.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_pinSaving)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white.withValues(alpha: 0.60),
                          strokeWidth: 2,
                        ),
                      )
                    else
                      CustomPaint(
                        size: const Size(18, 18),
                        painter: _LockResetPainter(),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      _pinSaving ? 'Updating...' : 'Update SOS PIN',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: _pinSaving
                            ? Colors.white.withValues(alpha: 0.38)
                            : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Hint
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomPaint(
                    size: const Size(11, 11),
                    painter: _InfoCirclePainter(
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Default PIN is 1234 — change it now for security.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Evidence card ─────────────────────────────────────────────
  Widget _buildEvidenceCard() {
    final items = [
      (
      _AudioIconPainter(color: AppColors.primary),
      'Audio Recording',
      '60s ambient audio captured on SOS',
      AppColors.primary,
      ),
      (
      _CameraIconPainter(color: AppColors.secondary),
      'Photo Burst',
      '3 photos front + 3 back captured instantly',
      AppColors.secondary,
      ),
      (
      _VideoIconPainter(color: AppColors.warningAmber),
      'Video Evidence',
      '30s front + 30s back auto-recorded',
      AppColors.warningAmber,
      ),
      (
      _GpsTrailPainter(color: AppColors.safeGreen),
      'GPS Trail',
      'Location logged every 5s as breadcrumbs',
      AppColors.safeGreen,
      ),
      (
      _SensorIconPainter(color: AppColors.sosRed),
      'Sensor Log',
      'Accelerometer + gyroscope logged for fall detection',
      AppColors.sosRed,
      ),
    ];

    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.safeGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: CustomPaint(
                      size: const Size(16, 16),
                      painter: _ShieldCheckPainter(color: AppColors.safeGreen),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Auto-captured when SOS fires',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.safeGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'AUTO',
                    style: TextStyle(
                      color: AppColors.safeGreen,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w800,
                      fontSize: 9,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.06),
            ),
            const SizedBox(height: 10),

            // Evidence rows
            ...items.asMap().entries.map((e) {
              final i    = e.key;
              final item = e.value;
              return Column(
                children: [
                  _EvidenceRow(
                    painter: item.$1,
                    title: item.$2,
                    sub: item.$3,
                    color: item.$4,
                  ),
                  if (i < items.length - 1) ...[
                    const SizedBox(height: 4),
                    Container(
                      height: 1,
                      margin: const EdgeInsets.only(left: 52),
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    const SizedBox(height: 4),
                  ],
                ],
              );
            }),

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  CustomPaint(
                    size: const Size(12, 12),
                    painter: _LockIconPainter(
                      color: AppColors.primary.withValues(alpha: 0.70),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Encrypted · Firebase Storage · Court-ready PDF auto-generated',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.38),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// REUSABLE SMALL WIDGETS
// ═══════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.32),
        fontSize: 10,
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    ),
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
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.08),
        width: 1,
      ),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: child,
    ),
  );
}

class _CardDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    margin: const EdgeInsets.symmetric(horizontal: 16),
    color: Colors.white.withValues(alpha: 0.06),
  );
}

class _ToggleRow extends StatelessWidget {
  final CustomPainter painter;
  final Color iconColor;
  final String title;
  final String sub;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.painter,
    required this.iconColor,
    required this.title,
    required this.sub,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Center(
              child: CustomPaint(
                size: const Size(20, 20),
                painter: painter,
              ),
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
                  sub,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
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
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final CustomPainter painter;
  final String label;
  final bool active;
  const _StatusPill({
    required this.painter,
    required this.label,
    required this.active,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: active ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: active ? 0.35 : 0.12),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: const Size(9, 9),
            painter: painter,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: active ? 1.0 : 0.38),
              fontFamily: 'Poppins',
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PinInputField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final bool show;
  final CustomPainter iconPainter;
  final VoidCallback onToggle;

  const _PinInputField({
    required this.ctrl,
    required this.label,
    required this.show,
    required this.iconPainter,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      obscureText: !show,
      keyboardType: TextInputType.number,
      maxLength: 8,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 20,
        letterSpacing: 8,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          color: Colors.white.withValues(alpha: 0.40),
          fontWeight: FontWeight.w500,
        ),
        counterText: '',
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: CustomPaint(
            size: const Size(18, 18),
            painter: iconPainter,
          ),
        ),
        suffixIcon: GestureDetector(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: CustomPaint(
              size: const Size(18, 18),
              painter: show
                  ? _EyeOffPainter(color: Colors.white.withValues(alpha: 0.35))
                  : _EyePainter(color: Colors.white.withValues(alpha: 0.35)),
            ),
          ),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  final CustomPainter painter;
  final String title;
  final String sub;
  final Color color;

  const _EvidenceRow({
    required this.painter,
    required this.title,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: CustomPaint(
                size: const Size(18, 18),
                painter: painter,
              ),
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
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
                Text(
                  sub,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.38),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.safeGreen.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'AUTO',
              style: TextStyle(
                color: AppColors.safeGreen,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w800,
                fontSize: 9,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ALL CUSTOM PAINTERS — ZERO MATERIAL ICONS
// ═══════════════════════════════════════════════════════════════

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

class _SosShieldPainter extends CustomPainter {
  final Color color;
  const _SosShieldPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(s.width * 0.50, 0);
    path.lineTo(s.width, s.height * 0.22);
    path.cubicTo(s.width, s.height * 0.22, s.width * 0.98, s.height * 0.72,
        s.width * 0.50, s.height);
    path.cubicTo(s.width * 0.02, s.height * 0.72, 0, s.height * 0.22,
        0, s.height * 0.22);
    path.close();
    canvas.drawPath(path, p);
    // SOS text
    final tp = TextPainter(
      text: TextSpan(
        text: 'SOS',
        style: TextStyle(
          color: color,
          fontSize: 6,
          fontWeight: FontWeight.w900,
          fontFamily: 'Poppins',
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(
      s.width / 2 - tp.width / 2,
      s.height * 0.44 - tp.height / 2,
    ));
  }
  @override
  bool shouldRepaint(_SosShieldPainter o) => o.color != color;
}

class _ShieldCheckPainter extends CustomPainter {
  final Color color;
  const _ShieldCheckPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(s.width * 0.50, 0);
    path.lineTo(s.width, s.height * 0.22);
    path.cubicTo(s.width, s.height * 0.22, s.width * 0.98, s.height * 0.72,
        s.width * 0.50, s.height);
    path.cubicTo(s.width * 0.02, s.height * 0.72, 0, s.height * 0.22,
        0, s.height * 0.22);
    path.close();
    canvas.drawPath(path, p);
    final check = Path();
    check.moveTo(s.width * 0.28, s.height * 0.52);
    check.lineTo(s.width * 0.44, s.height * 0.68);
    check.lineTo(s.width * 0.72, s.height * 0.36);
    canvas.drawPath(check, p);
  }
  @override
  bool shouldRepaint(_ShieldCheckPainter o) => o.color != color;
}

class _SosActiveIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    canvas.drawCircle(Offset(cx, cy), s.width * 0.46,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.22)
          ..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(cx, cy), s.width * 0.46,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 2.5, cy - s.height * 0.24, 5, s.height * 0.28),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(Offset(cx, cy + s.height * 0.14), 3,
        Paint()..color = Colors.white);
  }
  @override
  bool shouldRepaint(_SosActiveIconPainter o) => false;
}

class _VibrateIconPainter extends CustomPainter {
  final Color color;
  const _VibrateIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * 0.28, s.height * 0.12,
            s.width * 0.44, s.height * 0.76),
        const Radius.circular(4),
      ),
      p,
    );
    for (final x in [s.width * 0.08, s.width * 0.84]) {
      canvas.drawLine(Offset(x, s.height * 0.30),
          Offset(x, s.height * 0.70), p);
    }
  }
  @override
  bool shouldRepaint(_VibrateIconPainter o) => o.color != color;
}

class _VibrateSmallPainter extends CustomPainter {
  final Color color;
  const _VibrateSmallPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * 0.28, s.height * 0.12,
            s.width * 0.44, s.height * 0.76),
        const Radius.circular(3),
      ),
      p,
    );
    for (final x in [s.width * 0.08, s.width * 0.84]) {
      canvas.drawLine(Offset(x, s.height * 0.32),
          Offset(x, s.height * 0.68), p);
    }
  }
  @override
  bool shouldRepaint(_VibrateSmallPainter o) => o.color != color;
}

class _SoundWavePainter extends CustomPainter {
  final Color color;
  const _SoundWavePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    // Speaker body
    canvas.drawLine(Offset(0, s.height * 0.32), Offset(0, s.height * 0.68), p);
    canvas.drawLine(Offset(0, s.height * 0.32),
        Offset(s.width * 0.28, s.height * 0.14), p);
    canvas.drawLine(Offset(0, s.height * 0.68),
        Offset(s.width * 0.28, s.height * 0.86), p);
    canvas.drawLine(Offset(s.width * 0.28, s.height * 0.14),
        Offset(s.width * 0.28, s.height * 0.86), p);
    // Waves
    for (int i = 1; i <= 3; i++) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(s.width * 0.28, s.height / 2),
          width: i * s.width * 0.24,
          height: i * s.height * 0.38,
        ),
        -math.pi * 0.35, math.pi * 0.70, false,
        Paint()
          ..color = color.withValues(alpha: 0.80 - i * 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );
    }
  }
  @override
  bool shouldRepaint(_SoundWavePainter o) => o.color != color;
}

class _SoundWaveSmallPainter extends CustomPainter {
  final Color color;
  const _SoundWaveSmallPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, s.height * 0.34), Offset(0, s.height * 0.66), p);
    canvas.drawLine(Offset(0, s.height * 0.34),
        Offset(s.width * 0.26, s.height * 0.16), p);
    canvas.drawLine(Offset(0, s.height * 0.66),
        Offset(s.width * 0.26, s.height * 0.84), p);
    canvas.drawLine(Offset(s.width * 0.26, s.height * 0.16),
        Offset(s.width * 0.26, s.height * 0.84), p);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(s.width * 0.26, s.height / 2),
        width: s.width * 0.36,
        height: s.height * 0.48,
      ),
      -math.pi * 0.35, math.pi * 0.70, false,
      Paint()
        ..color = color.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round,
    );
  }
  @override
  bool shouldRepaint(_SoundWaveSmallPainter o) => o.color != color;
}

class _TimerIconPainter extends CustomPainter {
  final Color color;
  const _TimerIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), s.width * 0.44, p);
    canvas.drawLine(Offset(cx, cy * 0.40), Offset(cx, cy), p);
    canvas.drawLine(Offset(cx, cy),
        Offset(cx + s.width * 0.24, cy + s.height * 0.12), p);
    canvas.drawLine(
      Offset(cx - s.width * 0.18, 0),
      Offset(cx + s.width * 0.18, 0),
      Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }
  @override
  bool shouldRepaint(_TimerIconPainter o) => o.color != color;
}

class _TimerSmallPainter extends CustomPainter {
  final Color color;
  const _TimerSmallPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), s.width * 0.44, p);
    canvas.drawLine(Offset(cx, cy * 0.40), Offset(cx, cy), p);
    canvas.drawLine(Offset(cx, cy),
        Offset(cx + s.width * 0.24, cy + s.height * 0.12), p);
  }
  @override
  bool shouldRepaint(_TimerSmallPainter o) => o.color != color;
}

class _LockIconPainter extends CustomPainter {
  final Color color;
  const _LockIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * 0.10, s.height * 0.44,
            s.width * 0.80, s.height * 0.52),
        const Radius.circular(4),
      ),
      p,
    );
    final arc = Path();
    arc.moveTo(s.width * 0.30, s.height * 0.44);
    arc.lineTo(s.width * 0.30, s.height * 0.26);
    arc.quadraticBezierTo(s.width * 0.30, s.height * 0.08,
        s.width * 0.50, s.height * 0.08);
    arc.quadraticBezierTo(s.width * 0.70, s.height * 0.08,
        s.width * 0.70, s.height * 0.26);
    arc.lineTo(s.width * 0.70, s.height * 0.44);
    canvas.drawPath(arc, p);
    canvas.drawCircle(Offset(s.width * 0.50, s.height * 0.70), s.width * 0.09,
        Paint()..color = color);
  }
  @override
  bool shouldRepaint(_LockIconPainter o) => o.color != color;
}

class _LockOpenPainter extends CustomPainter {
  final Color color;
  const _LockOpenPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * 0.10, s.height * 0.44,
            s.width * 0.80, s.height * 0.52),
        const Radius.circular(4),
      ),
      p,
    );
    // Open shackle — arc on left side open
    final arc = Path();
    arc.moveTo(s.width * 0.30, s.height * 0.44);
    arc.lineTo(s.width * 0.30, s.height * 0.22);
    arc.quadraticBezierTo(s.width * 0.30, s.height * 0.06,
        s.width * 0.50, s.height * 0.06);
    arc.quadraticBezierTo(s.width * 0.72, s.height * 0.06,
        s.width * 0.72, s.height * 0.22);
    // Left side open (not drawn)
    canvas.drawPath(arc, p);
    canvas.drawCircle(Offset(s.width * 0.50, s.height * 0.70), s.width * 0.09,
        Paint()..color = color);
  }
  @override
  bool shouldRepaint(_LockOpenPainter o) => o.color != color;
}

class _LockResetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromLTWH(s.width * 0.12, s.height * 0.12,
          s.width * 0.76, s.height * 0.76),
      -math.pi * 0.4, math.pi * 1.8, false, p,
    );
    final arrow = Path();
    arrow.moveTo(s.width * 0.80, s.height * 0.18);
    arrow.lineTo(s.width * 0.88, s.height * 0.08);
    arrow.moveTo(s.width * 0.80, s.height * 0.18);
    arrow.lineTo(s.width * 0.70, s.height * 0.14);
    canvas.drawPath(arrow, p);
    canvas.drawCircle(Offset(s.width / 2, s.height / 2), s.width * 0.14,
        Paint()..color = Colors.white);
  }
  @override
  bool shouldRepaint(_LockResetPainter o) => false;
}

class _InfoCirclePainter extends CustomPainter {
  final Color color;
  const _InfoCirclePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    final r  = s.width * 0.46;
    final p  = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), r, p);
    canvas.drawCircle(Offset(cx, cy - r * 0.40), s.width * 0.07,
        Paint()..color = color);
    canvas.drawLine(
      Offset(cx, cy - r * 0.14),
      Offset(cx, cy + r * 0.42),
      Paint()
        ..color = color
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
  }
  @override
  bool shouldRepaint(_InfoCirclePainter o) => o.color != color;
}

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
          ..color = color.withValues(alpha: 0.18)
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

class _WarningPainter extends CustomPainter {
  final Color color;
  const _WarningPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final path = Path();
    path.moveTo(cx, s.height * 0.04);
    path.lineTo(s.width * 0.96, s.height * 0.94);
    path.lineTo(s.width * 0.04, s.height * 0.94);
    path.close();
    canvas.drawPath(path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeJoin = StrokeJoin.round);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 1.5, s.height * 0.36, 3, s.height * 0.28),
        const Radius.circular(1.5),
      ),
      Paint()..color = color,
    );
    canvas.drawCircle(Offset(cx, s.height * 0.78), 2.5,
        Paint()..color = color);
  }
  @override
  bool shouldRepaint(_WarningPainter o) => o.color != color;
}

class _ErrorCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    final r  = s.width * 0.46;
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()
          ..color = AppColors.sosRed
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4);
    final p = Paint()
      ..color = AppColors.sosRed
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - r * 0.35, cy - r * 0.35),
        Offset(cx + r * 0.35, cy + r * 0.35), p);
    canvas.drawLine(Offset(cx + r * 0.35, cy - r * 0.35),
        Offset(cx - r * 0.35, cy + r * 0.35), p);
  }
  @override
  bool shouldRepaint(_ErrorCirclePainter o) => false;
}

class _EyePainter extends CustomPainter {
  final Color color;
  const _EyePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    final eye = Path();
    eye.moveTo(0, s.height * 0.50);
    eye.cubicTo(s.width * 0.25, s.height * 0.15, s.width * 0.75, s.height * 0.15,
        s.width, s.height * 0.50);
    eye.cubicTo(s.width * 0.75, s.height * 0.85, s.width * 0.25, s.height * 0.85,
        0, s.height * 0.50);
    canvas.drawPath(eye, p);
    canvas.drawCircle(Offset(s.width / 2, s.height / 2), s.width * 0.16,
        Paint()..color = color);
  }
  @override
  bool shouldRepaint(_EyePainter o) => o.color != color;
}

class _EyeOffPainter extends CustomPainter {
  final Color color;
  const _EyeOffPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    final eye = Path();
    eye.moveTo(0, s.height * 0.45);
    eye.cubicTo(s.width * 0.25, s.height * 0.12, s.width * 0.75, s.height * 0.12,
        s.width, s.height * 0.45);
    eye.cubicTo(s.width * 0.75, s.height * 0.82, s.width * 0.25, s.height * 0.82,
        0, s.height * 0.45);
    canvas.drawPath(eye, p);
    canvas.drawCircle(Offset(s.width / 2, s.height * 0.45), s.width * 0.14,
        Paint()..color = color);
    canvas.drawLine(
      Offset(s.width * 0.15, s.height * 0.12),
      Offset(s.width * 0.85, s.height * 0.88),
      Paint()
        ..color = color
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
  }
  @override
  bool shouldRepaint(_EyeOffPainter o) => o.color != color;
}

class _AudioIconPainter extends CustomPainter {
  final Color color;
  const _AudioIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * 0.30, 0, s.width * 0.40, s.height * 0.58),
        Radius.circular(s.width * 0.20),
      ),
      p,
    );
    canvas.drawArc(
      Rect.fromLTWH(s.width * 0.12, s.height * 0.30,
          s.width * 0.76, s.height * 0.50),
      0, math.pi, false, p,
    );
    canvas.drawLine(Offset(s.width * 0.50, s.height * 0.80),
        Offset(s.width * 0.50, s.height), p);
    canvas.drawLine(Offset(s.width * 0.28, s.height),
        Offset(s.width * 0.72, s.height), p);
  }
  @override
  bool shouldRepaint(_AudioIconPainter o) => o.color != color;
}

class _CameraIconPainter extends CustomPainter {
  final Color color;
  const _CameraIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, s.height * 0.22, s.width, s.height * 0.70),
        const Radius.circular(4),
      ),
      p,
    );
    canvas.drawCircle(
        Offset(s.width / 2, s.height * 0.57), s.width * 0.20, p);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * 0.34, 0, s.width * 0.32, s.height * 0.24),
        const Radius.circular(3),
      ),
      p,
    );
    // Recording indicator
    canvas.drawCircle(
        Offset(s.width * 0.84, s.height * 0.38), s.width * 0.07,
        Paint()..color = color);
  }
  @override
  bool shouldRepaint(_CameraIconPainter o) => o.color != color;
}

class _VideoIconPainter extends CustomPainter {
  final Color color;
  const _VideoIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, s.height * 0.18, s.width * 0.65, s.height * 0.64),
        const Radius.circular(4),
      ),
      p,
    );
    final play = Path();
    play.moveTo(s.width * 0.68, s.height * 0.22);
    play.lineTo(s.width, s.height * 0.38);
    play.lineTo(s.width, s.height * 0.62);
    play.lineTo(s.width * 0.68, s.height * 0.78);
    play.close();
    canvas.drawPath(play, p);
    canvas.drawCircle(Offset(s.width * 0.16, s.height * 0.38),
        s.width * 0.07, Paint()..color = color);
  }
  @override
  bool shouldRepaint(_VideoIconPainter o) => o.color != color;
}

class _GpsTrailPainter extends CustomPainter {
  final Color color;
  const _GpsTrailPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final path = Path();
    path.moveTo(s.width * 0.10, s.height * 0.80);
    path.cubicTo(s.width * 0.10, s.height * 0.40,
        s.width * 0.90, s.height * 0.60, s.width * 0.90, s.height * 0.20);
    canvas.drawPath(path, p);
    for (final pt in [
      Offset(s.width * 0.10, s.height * 0.80),
      Offset(s.width * 0.45, s.height * 0.60),
      Offset(s.width * 0.90, s.height * 0.20),
    ]) {
      canvas.drawCircle(pt, 2.5, Paint()..color = color);
    }
  }
  @override
  bool shouldRepaint(_GpsTrailPainter o) => o.color != color;
}

class _SensorIconPainter extends CustomPainter {
  final Color color;
  const _SensorIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final path = Path();
    path.moveTo(0, s.height / 2);
    for (int i = 0; i <= 36; i++) {
      final x = i / 36 * s.width;
      final y = s.height / 2 +
          math.sin(i / 36 * 4 * math.pi) * s.height * 0.38;
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    canvas.drawPath(path, p);
  }
  @override
  bool shouldRepaint(_SensorIconPainter o) => o.color != color;
}