// lib/features/settings/screens/settings_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// SAFEHER — SETTINGS HUB SCREEN
// Full rewrite: Profile header + 9 category tiles linking to sub-screens
// All wired to: AuthProvider, SosProvider, BiometricProvider, DecoyService,
//               MLMonitoringService, VoiceSosService, HardwareSosService
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../auth/providers/auth_provider.dart';
import '../../sos/providers/sos_provider.dart';
import '../providers/biometric_provider.dart';
import '../../../core/services/decoy_service.dart';
import '../../../core/services/voice_sos_service.dart';
import '../../../core/services/hardware_sos_service.dart';
import '../../../core/services/ml_monitoring_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';

import 'profile_screen.dart';
import 'sos_settings_screen.dart';
import 'voice_sos_settings_screen.dart';
import 'ai_settings_screen.dart';
import 'location_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'decoy_settings_screen.dart';
import 'app_security_screen.dart';

void _unawaited(Future<void> f) => f.catchError((_) {});

// ─────────────────────────────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {

  late final AnimationController _headerAnim;
  late final AnimationController _shimmerAnim;
  late final Animation<double>   _shimmer;

  @override
  void initState() {
    super.initState();
    _headerAnim  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))..forward();
    _shimmerAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))..repeat();
    _shimmer = Tween<double>(begin: -1.5, end: 2.5)
        .animate(CurvedAnimation(parent: _shimmerAnim, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    _shimmerAnim.dispose();
    super.dispose();
  }

  // ── Navigation helper ──────────────────────────────────────────
  void _go(Widget screen) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => screen));

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Sign Out?',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800)),
          content: const Text('You will need to log in again to access SafeHer.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel',
                    style: TextStyle(fontFamily: 'Poppins', color: Colors.grey))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sosRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: const Text('Sign Out',
                  style: TextStyle(fontFamily: 'Poppins')),
            ),
          ],
        );
      },
    );
    if (confirm == true && mounted) {
      _unawaited(NotificationService.instance.showLogoutSuccess());
      await context.read<AuthProvider>().signOut();
      if (mounted) Navigator.pushNamedAndRemoveUntil(
          context, AppRouter.login, (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth   = context.watch<AuthProvider>();
    final sos    = context.watch<SosProvider>();
    final bio    = context.watch<BiometricProvider>();
    final user   = auth.user;

    // Live service states
    final voice    = VoiceSosService.instance;
    final hardware = HardwareSosService.instance;
    final decoy    = DecoyService.instance;
    final ml       = MLMonitoringService.instance;

    final initials = user?.name.isNotEmpty == true
        ? user!.name[0].toUpperCase() : 'U';

    final bg = isDark ? AppColors.darkBackground : const Color(0xFFF5F0FA);

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [

          // ── Sliver App Bar with Profile ───────────────────────
          SliverAppBar(
            expandedHeight: 210,
            pinned: true,
            stretch: true,
            backgroundColor: AppColors.primary,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Settings',
                style: TextStyle(color: Colors.white, fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800, fontSize: 18)),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(children: [
                // Gradient bg
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFE91E8C), Color(0xFF7C1CBF), Color(0xFF6C63FF)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                  ),
                ),
                // Decorative circles
                Positioned(top: -20, right: -20,
                    child: Container(width: 140, height: 140,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.05)))),
                Positioned(bottom: -10, left: -30,
                    child: Container(width: 100, height: 100,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.04)))),

                // Profile content
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
                    child: GestureDetector(
                      onTap: () => _go(const ProfileScreen()),
                      child: Row(children: [
                        // Avatar with shimmer ring
                        AnimatedBuilder(animation: _shimmer, builder: (_, __) =>
                            Container(
                              width: 74, height: 74,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: SweepGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.0),
                                    Colors.white.withValues(alpha: 0.5),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                  transform: GradientRotation(_shimmer.value * 3.14),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(3),
                                child: ClipOval(
                                  child: user?.photoUrl != null
                                      ? Image.network(user!.photoUrl!, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _Initials(initials))
                                      : _Initials(initials),
                                ),
                              ),
                            ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: FadeTransition(
                          opacity: _headerAnim,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user?.name ?? 'User',
                                    style: const TextStyle(color: Colors.white,
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w900, fontSize: 18),
                                    overflow: TextOverflow.ellipsis),
                                Text(user?.email ?? '',
                                    style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.75),
                                        fontFamily: 'Poppins', fontSize: 12),
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 6),
                                Row(children: [
                                  _MiniPill(
                                      bio.isEnabled ? '🔒 Locked' : '🔓 Open',
                                      bio.isEnabled
                                          ? AppColors.warningAmber : Colors.grey),
                                  const SizedBox(width: 6),
                                  _MiniPill(
                                      sos.isSosActive ? '🚨 SOS' : '🛡️ Safe',
                                      sos.isSosActive
                                          ? AppColors.sosRed : AppColors.safeGreen),
                                ]),
                              ]),
                        )),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3))),
                          child: const Row(mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Edit', style: TextStyle(color: Colors.white,
                                    fontFamily: 'Poppins', fontWeight: FontWeight.w700,
                                    fontSize: 11)),
                                SizedBox(width: 3),
                                Icon(Icons.chevron_right_rounded,
                                    color: Colors.white, size: 14),
                              ]),
                        ),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
          ),

          // ── Settings Body ─────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // SOS ACTIVE warning
                if (sos.isSosActive) ...[
                  FadeInDown(child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        gradient: AppColors.sosGradient,
                        borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      const Icon(Icons.warning_rounded,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                          '🚨 SOS ACTIVE — ${sos.activeDurationStr} · '
                              'Settings limited during emergency',
                          style: const TextStyle(color: Colors.white,
                              fontFamily: 'Poppins', fontWeight: FontWeight.w700,
                              fontSize: 12))),
                    ]),
                  )),
                  const SizedBox(height: 16),
                ],

                // ── PROTECTION ──────────────────────────────────
                _SectionLabel('PROTECTION'),
                const SizedBox(height: 10),
                FadeInUp(delay: const Duration(milliseconds: 50),
                  child: _SettingsGroup(isDark: isDark, children: [
                    _SettingsTile(
                      icon: Icons.emergency_rounded,
                      iconBg: AppColors.sosRed,
                      title: 'SOS Settings',
                      sub: 'Shake · Alarm · ${sos.countdownTotal}s countdown · PIN',
                      trailing: sos.isSosActive
                          ? _StatusDot(AppColors.sosRed, 'ACTIVE')
                          : _StatusDot(AppColors.safeGreen, 'READY'),
                      onTap: () => _go(const SosSettingsScreen()),
                    ),
                    _Divider(isDark),
                    _SettingsTile(
                      icon: Icons.mic_rounded,
                      iconBg: AppColors.primary,
                      title: 'Voice & Hardware SOS',
                      sub: 'Keywords · Volume button · Earphone',
                      trailing: ListenableBuilder(
                        listenable: voice,
                        builder: (_, __) => _StatusDot(
                            voice.isEnabled ? AppColors.safeGreen : Colors.grey,
                            voice.isEnabled ? 'ON' : 'OFF'),
                      ),
                      onTap: () => _go(const VoiceSosSettingsScreen()),
                    ),
                    _Divider(isDark),
                    _SettingsTile(
                      icon: Icons.psychology_rounded,
                      iconBg: AppColors.secondary,
                      title: 'AI Protection',
                      sub: 'Danger detection · Threshold · Auto-SOS',
                      trailing: _StatusDot(
                          ml.isRunning ? AppColors.safeGreen : Colors.grey,
                          ml.isRunning ? 'LIVE' : 'OFF'),
                      onTap: () => _go(const AiSettingsScreen()),
                    ),
                  ]),
                ),
                const SizedBox(height: 22),

                // ── LOCATION & SAFETY ───────────────────────────
                _SectionLabel('LOCATION & SAFETY'),
                const SizedBox(height: 10),
                FadeInUp(delay: const Duration(milliseconds: 100),
                  child: _SettingsGroup(isDark: isDark, children: [
                    _SettingsTile(
                      icon: Icons.location_on_rounded,
                      iconBg: AppColors.safeGreen,
                      title: 'Location Settings',
                      sub: 'Sharing · Night mode · Geofences',
                      onTap: () => _go(const LocationSettingsScreen()),
                    ),
                    _Divider(isDark),
                    _SettingsTile(
                      icon: Icons.place_rounded,
                      iconBg: const Color(0xFF00BFA5),
                      title: 'Nearest Safe Places',
                      sub: 'Police, hospitals, pharmacies nearby',
                      onTap: () => Navigator.pushNamed(
                          context, AppRouter.nearestSafetyPlaces),
                    ),
                    _Divider(isDark),
                    _SettingsTile(
                      icon: Icons.people_rounded,
                      iconBg: AppColors.warningAmber,
                      title: 'Emergency Contacts',
                      sub: 'Add, remove, and manage guardians',
                      onTap: () => Navigator.pushNamed(context, AppRouter.contacts),
                    ),
                  ]),
                ),
                const SizedBox(height: 22),

                // ── PRIVACY & SECURITY ──────────────────────────
                _SectionLabel('PRIVACY & SECURITY'),
                const SizedBox(height: 10),
                FadeInUp(delay: const Duration(milliseconds: 140),
                  child: _SettingsGroup(isDark: isDark, children: [
                    _SettingsTile(
                      icon: Icons.security_rounded,
                      iconBg: AppColors.warningAmber,
                      title: 'App Security',
                      sub: 'Biometric lock · Password reset',
                      trailing: bio.isEnabled
                          ? _StatusDot(AppColors.warningAmber, 'LOCKED')
                          : null,
                      onTap: () => _go(const AppSecurityScreen()),
                    ),
                    _Divider(isDark),
                    _SettingsTile(
                      icon: Icons.theater_comedy_rounded,
                      iconBg: const Color(0xFF2D1B69),
                      title: 'Decoy App',
                      sub: 'Fake calculator/notepad when threatened',
                      trailing: ListenableBuilder(
                        listenable: decoy,
                        builder: (_, __) => _StatusDot(
                            decoy.isEnabled ? AppColors.safeGreen : Colors.grey,
                            decoy.isSetup
                                ? (decoy.isEnabled ? 'ON' : 'OFF')
                                : 'SETUP'),
                      ),
                      onTap: () => _go(const DecoySettingsScreen()),
                    ),
                  ]),
                ),
                const SizedBox(height: 22),

                // ── NOTIFICATIONS ───────────────────────────────
                _SectionLabel('NOTIFICATIONS'),
                const SizedBox(height: 10),
                FadeInUp(delay: const Duration(milliseconds: 170),
                  child: _SettingsGroup(isDark: isDark, children: [
                    _SettingsTile(
                      icon: Icons.notifications_rounded,
                      iconBg: AppColors.secondary,
                      title: 'Notification Preferences',
                      sub: 'SOS · Journey · Contacts · Community',
                      onTap: () => _go(const NotificationSettingsScreen()),
                    ),
                  ]),
                ),
                const SizedBox(height: 22),

                // ── MORE TOOLS ──────────────────────────────────
                _SectionLabel('MORE TOOLS'),
                const SizedBox(height: 10),
                FadeInUp(delay: const Duration(milliseconds: 200),
                  child: _SettingsGroup(isDark: isDark, children: [
                    _SettingsTile(
                      icon: Icons.phone_in_talk_rounded,
                      iconBg: AppColors.accent,
                      title: 'Fake Call Escape',
                      sub: 'Simulate an incoming call to leave safely',
                      onTap: () => Navigator.pushNamed(context, AppRouter.fakeCall),
                    ),
                    _Divider(isDark),
                    _SettingsTile(
                      icon: Icons.history_rounded,
                      iconBg: AppColors.primary,
                      title: 'Incident History',
                      sub: 'Review past SOS events and evidence',
                      onTap: () => Navigator.pushNamed(context, AppRouter.incidents),
                    ),
                  ]),
                ),
                const SizedBox(height: 22),

                // ── ABOUT ────────────────────────────────────────
                _SectionLabel('ABOUT'),
                const SizedBox(height: 10),
                FadeInUp(delay: const Duration(milliseconds: 220),
                  child: _SettingsGroup(isDark: isDark, children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      child: Row(children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(12)),
                          child: const Center(child: Text('🛡️',
                              style: TextStyle(fontSize: 20))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('SafeHer',
                                  style: TextStyle(fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w800, fontSize: 14)),
                              Text('v${AppConstants.appVersion} · ${AppConstants.packageName}',
                                  style: const TextStyle(color: Colors.grey,
                                      fontFamily: 'Poppins', fontSize: 11)),
                            ])),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: AppColors.safeGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10)),
                          child: const Text('AI-Powered',
                              style: TextStyle(color: AppColors.safeGreen,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w700, fontSize: 10)),
                        ),
                      ]),
                    ),
                    _Divider(isDark),
                    _SettingsTile(
                      icon: Icons.info_outline_rounded,
                      iconBg: Colors.grey,
                      title: 'Backend Status',
                      sub: 'asia-south1 · Movement/Audio/Fusion AI',
                      trailing: _StatusDot(
                          ml.isApiConnected ? AppColors.safeGreen : Colors.orange,
                          ml.isApiConnected ? 'LIVE' : 'CHECK'),
                      onTap: () => _go(const AiSettingsScreen()),
                    ),
                  ]),
                ),
                const SizedBox(height: 22),

                // ── SIGN OUT ────────────────────────────────────
                FadeInUp(delay: const Duration(milliseconds: 240),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Sign Out',
                          style: TextStyle(fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? AppColors.darkCard : Colors.white,
                        foregroundColor: AppColors.sosRed,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                                color: AppColors.sosRed.withValues(alpha: 0.3))),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(child: Text(
                    'SafeHer v${AppConstants.appVersion} · '
                        'Made with ❤️ for women\'s safety',
                    style: const TextStyle(color: Colors.grey,
                        fontFamily: 'Poppins', fontSize: 10))),
                const SizedBox(height: 16),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _Initials extends StatelessWidget {
  final String text; const _Initials(this.text);
  @override
  Widget build(BuildContext context) => Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: Center(child: Text(text, style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.w900,
          fontSize: 28, fontFamily: 'Poppins'))));
}

class _MiniPill extends StatelessWidget {
  final String text; final Color color;
  const _MiniPill(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: TextStyle(
        color: color, fontFamily: 'Poppins',
        fontWeight: FontWeight.w700, fontSize: 10)),
  );
}

class _SectionLabel extends StatelessWidget {
  final String text; const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(text,
        style: TextStyle(color: Colors.grey.withValues(alpha: 0.6),
            fontSize: 10, fontFamily: 'Poppins',
            fontWeight: FontWeight.w800, letterSpacing: 1.4)),
  );
}

class _SettingsGroup extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;
  const _SettingsGroup({required this.isDark, required this.children});
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.cardShadow),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(children: children)));
}

class _SettingsTile extends StatelessWidget {
  final IconData icon; final Color iconBg;
  final String title, sub;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _SettingsTile({required this.icon, required this.iconBg,
    required this.title, required this.sub,
    this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap?.call();
      },
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Container(width: 42, height: 42,
              decoration: BoxDecoration(
                  color: iconBg.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconBg, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontFamily: 'Poppins',
                fontWeight: FontWeight.w700, fontSize: 13)),
            Text(sub, style: const TextStyle(color: Colors.grey,
                fontFamily: 'Poppins', fontSize: 11)),
          ])),
          if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
          Icon(Icons.chevron_right_rounded,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.5),
              size: 20),
        ]),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark; const _Divider(this.isDark);
  @override
  Widget build(BuildContext context) => Divider(height: 1, indent: 70,
      color: isDark ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.06));
}

class _StatusDot extends StatelessWidget {
  final Color color; final String label;
  const _StatusDot(this.color, this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 5, height: 5,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(
          color: color, fontFamily: 'Poppins',
          fontWeight: FontWeight.w700, fontSize: 9)),
    ]),
  );
}