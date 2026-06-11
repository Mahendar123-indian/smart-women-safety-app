// lib/features/home/drawer/safeher_drawer.dart
// ─────────────────────────────────────────────────────────────────────────────
// SAFEHER DRAWER — Full Custom Painters · Zero Material Icons
// Sections: Navigate · Safety Tools · Advanced Protection · Account
// All features preserved · withValues(alpha:) throughout · No duplicates
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../contacts/providers/contact_provider.dart';
import '../../location/providers/location_provider.dart';
import '../../sos/providers/sos_provider.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../safety_places/screens/police_stations_screen.dart';
import '../../community/screens/community_map_screen.dart';
import '../../community/screens/report_danger_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SAFEHER DRAWER
// ═══════════════════════════════════════════════════════════════════════════

class SafeHerDrawer extends StatelessWidget {
  const SafeHerDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthProvider>();
    final contacts = context.watch<ContactProvider>();
    final sos      = context.watch<SosProvider>();
    final location = context.watch<LocationProvider>();
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final name     = auth.user?.name ?? 'User';
    final email    = auth.user?.email ?? auth.user?.phone ?? '';

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.84,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
            colors: [Color(0xFF08081C), Color(0xFF10102A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
              : const LinearGradient(
            colors: [Colors.white, Color(0xFFF6F2FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── HEADER ─────────────────────────────────────────────────
              _DrawerHeader(
                name: name,
                email: email,
                isDark: isDark,
                guardians: contacts.activeCount,
                incidents: sos.incidents.length,
                isLive: location.isSharing,
                onClose: () => Navigator.pop(context),
              ),

              // ── MENU BODY ──────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── NAVIGATE ────────────────────────────────────────
                      _SectionLabel('NAVIGATE'),
                      const SizedBox(height: 8),
                      _Tile(
                        painter: _HomeIconPainter(color: AppColors.primary),
                        label: 'Home',
                        color: AppColors.primary,
                        isDark: isDark,
                        onTap: () => Navigator.pop(context),
                      ),
                      _Tile(
                        painter: _HistoryIconPainter(color: AppColors.secondary),
                        label: 'Incident History',
                        color: AppColors.secondary,
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRouter.incidents);
                        },
                      ),
                      _Tile(
                        painter: _PeopleIconPainter(color: AppColors.safeGreen),
                        label: 'Emergency Contacts',
                        color: AppColors.safeGreen,
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRouter.contacts);
                        },
                      ),
                      _Tile(
                        painter: _LocationPinPainter(color: AppColors.secondary),
                        label: 'Location & Journey',
                        color: AppColors.secondary,
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRouter.location);
                        },
                      ),
                      _Tile(
                        painter: _BellIconPainter(color: AppColors.warningAmber),
                        label: 'Notifications',
                        color: AppColors.warningAmber,
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationsScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),

                      // ── SAFETY TOOLS ────────────────────────────────────
                      _SectionLabel('SAFETY TOOLS'),
                      const SizedBox(height: 8),
                      _Tile(
                        painter: _HospitalCrossPainter(color: const Color(0xFF1976D2)),
                        label: 'Nearest Safety Places',
                        color: const Color(0xFF1976D2),
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRouter.nearestSafetyPlaces);
                        },
                      ),
                      _Tile(
                        painter: _PoliceBadgePainter(color: const Color(0xFF1A237E)),
                        label: 'Police Stations',
                        color: const Color(0xFF1A237E),
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PoliceStationsScreen(),
                            ),
                          );
                        },
                      ),
                      _Tile(
                        painter: _FakeCallPainter(color: const Color(0xFF7B1FA2)),
                        label: 'Fake Call Escape',
                        color: const Color(0xFF7B1FA2),
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRouter.fakeCall);
                        },
                      ),
                      _Tile(
                        painter: _MapPinPainter(color: AppColors.safeGreen),
                        label: 'Community Danger Map',
                        color: AppColors.safeGreen,
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CommunityMapScreen(),
                            ),
                          );
                        },
                      ),
                      _Tile(
                        painter: _ReportPinPainter(color: AppColors.sosRed),
                        label: 'Report Danger Spot',
                        color: AppColors.sosRed,
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ReportDangerScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),

                      // ── ADVANCED PROTECTION ─────────────────────────────
                      _SectionLabel('ADVANCED PROTECTION'),
                      const SizedBox(height: 8),
                      _Tile(
                        painter: _VibrateIconPainter(color: const Color(0xFF00897B)),
                        label: 'Shake SOS (5-Layer AI)',
                        color: const Color(0xFF00897B),
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRouter.settings);
                        },
                      ),
                      _Tile(
                        painter: _MicIconPainter(color: AppColors.primary),
                        label: 'Voice SOS Settings',
                        color: AppColors.primary,
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRouter.settings);
                        },
                      ),
                      _Tile(
                        painter: _HardwareBtnPainter(color: AppColors.secondary),
                        label: 'Hardware Button SOS',
                        color: AppColors.secondary,
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRouter.settings);
                        },
                      ),
                      _Tile(
                        painter: _CalcIconPainter(color: const Color(0xFF4A148C)),
                        label: 'Decoy PIN Setup',
                        color: const Color(0xFF4A148C),
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRouter.settings);
                        },
                      ),
                      _Tile(
                        painter: _PdfIconPainter(color: AppColors.primary),
                        label: 'Evidence PDF Reports',
                        color: AppColors.primary,
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRouter.incidents);
                        },
                      ),
                      const SizedBox(height: 14),

                      // ── ACCOUNT ─────────────────────────────────────────
                      _SectionLabel('ACCOUNT'),
                      const SizedBox(height: 8),
                      _Tile(
                        painter: _SettingsGearPainter(color: AppColors.primary),
                        label: 'Settings',
                        color: AppColors.primary,
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRouter.settings);
                        },
                      ),
                      _Tile(
                        painter: _FingerprintPainter(color: AppColors.warningAmber),
                        label: 'App Lock & Security',
                        color: AppColors.warningAmber,
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRouter.biometricLock);
                        },
                      ),

                      // Sign Out — special destructive style
                      _SignOutTile(
                        isDark: isDark,
                        onTap: () async {
                          HapticFeedback.heavyImpact();
                          Navigator.pop(context);
                          await context.read<AuthProvider>().signOut();
                          if (context.mounted) {
                            Navigator.pushReplacementNamed(
                                context, AppRouter.login);
                          }
                        },
                      ),

                      const SizedBox(height: 28),

                      // ── FOOTER ──────────────────────────────────────────
                      _DrawerFooter(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DRAWER HEADER
// ═══════════════════════════════════════════════════════════════════════════

class _DrawerHeader extends StatelessWidget {
  final String name, email;
  final bool isDark;
  final int guardians, incidents;
  final bool isLive;
  final VoidCallback onClose;

  const _DrawerHeader({
    required this.name,
    required this.email,
    required this.isDark,
    required this.guardians,
    required this.incidents,
    required this.isLive,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.only(topRight: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SafeHer logo row + close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: CustomPaint(
                        size: const Size(16, 16),
                        painter: _ShieldCheckPainter(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'SafeHer',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      fontFamily: 'Poppins',
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: CustomPaint(
                      size: const Size(12, 12),
                      painter: _CloseXPainter(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Avatar + name + email + protected badge
          Row(
            children: [
              // Avatar circle with initial
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.30),
                      Colors.white.withValues(alpha: 0.15),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        fontFamily: 'Poppins',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 11,
                          fontFamily: 'Poppins',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 5),
                    // Protected pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.safeGreen.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.safeGreen.withValues(alpha: 0.45),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CustomPaint(
                            size: const Size(10, 10),
                            painter: _ShieldCheckPainter(
                                color: AppColors.safeGreen),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Protected',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Poppins',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Stats row
          Row(
            children: [
              _StatChip(
                value: '$guardians',
                label: 'Guardians',
                painter: _PeopleIconPainter(color: Colors.white),
              ),
              const SizedBox(width: 8),
              _StatChip(
                value: '$incidents',
                label: 'Incidents',
                painter: _HistoryIconPainter(color: Colors.white),
              ),
              const SizedBox(width: 8),
              _StatChip(
                value: isLive ? 'LIVE' : 'OFF',
                label: 'Tracking',
                painter: _GpsIconPainter(
                  color: isLive ? AppColors.safeGreen : Colors.white,
                ),
                valueColor: isLive ? AppColors.safeGreen : Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Stat chip inside header ──────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String value, label;
  final CustomPainter painter;
  final Color? valueColor;

  const _StatChip({
    required this.value,
    required this.label,
    required this.painter,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.20),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            CustomPaint(
              size: const Size(13, 13),
              painter: painter,
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                fontFamily: 'Poppins',
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 8,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SECTION LABEL
// ═══════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          color: isDark
              ? Colors.white.withValues(alpha: 0.35)
              : Colors.black.withValues(alpha: 0.30),
          fontSize: 10,
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TILE — standard menu row
// ═══════════════════════════════════════════════════════════════════════════

class _Tile extends StatelessWidget {
  final CustomPainter painter;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _Tile({
    required this.painter,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppColors.cardShadow,
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.04),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Icon box
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(18, 18),
                  painter: painter,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Label
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.88)
                      : AppColors.lightText,
                ),
              ),
            ),

            // Chevron
            CustomPaint(
              size: const Size(10, 10),
              painter: _ChevronRightPainter(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.22)
                    : Colors.black.withValues(alpha: 0.18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SIGN OUT TILE — destructive, red accent
// ═══════════════════════════════════════════════════════════════════════════

class _SignOutTile extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _SignOutTile({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.sosRed.withValues(alpha: isDark ? 0.08 : 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.sosRed.withValues(alpha: 0.20),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.sosRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(18, 18),
                  painter: _LogoutArrowPainter(color: AppColors.sosRed),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Sign Out',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppColors.sosRed,
                ),
              ),
            ),
            CustomPaint(
              size: const Size(10, 10),
              painter: _ChevronRightPainter(
                color: AppColors.sosRed.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FOOTER
// ═══════════════════════════════════════════════════════════════════════════

class _DrawerFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // Divider
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.08),
                Colors.transparent,
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Shield icon
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.30),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: CustomPaint(
              size: const Size(18, 18),
              painter: _ShieldCheckPainter(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 8),

        ShaderMask(
          shaderCallback: (bounds) =>
              AppColors.primaryGradient.createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: const Text(
            'SafeHer v2.0',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'VJIT Hyderabad · Powered by AI\nProtecting women everywhere 🛡️',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark
                ? Colors.white.withValues(alpha: 0.30)
                : Colors.black.withValues(alpha: 0.28),
            fontSize: 10,
            fontFamily: 'Poppins',
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ALL CUSTOM PAINTERS — ZERO MATERIAL ICONS
// ═══════════════════════════════════════════════════════════════════════════

/// Shield with checkmark inside
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

    final shield = Path();
    shield.moveTo(s.width * 0.50, 0);
    shield.lineTo(s.width, s.height * 0.22);
    shield.cubicTo(s.width, s.height * 0.22, s.width * 0.98,
        s.height * 0.72, s.width * 0.50, s.height);
    shield.cubicTo(s.width * 0.02, s.height * 0.72, 0,
        s.height * 0.22, 0, s.height * 0.22);
    shield.close();
    canvas.drawPath(shield, p);

    final check = Path();
    check.moveTo(s.width * 0.28, s.height * 0.52);
    check.lineTo(s.width * 0.44, s.height * 0.68);
    check.lineTo(s.width * 0.72, s.height * 0.36);
    canvas.drawPath(check, p);
  }

  @override
  bool shouldRepaint(_ShieldCheckPainter o) => o.color != color;
}

/// X close icon
class _CloseXPainter extends CustomPainter {
  final Color color;
  const _CloseXPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, 0), Offset(s.width, s.height), p);
    canvas.drawLine(Offset(s.width, 0), Offset(0, s.height), p);
  }

  @override
  bool shouldRepaint(_CloseXPainter o) => o.color != color;
}

/// Home icon — roof + walls + door
class _HomeIconPainter extends CustomPainter {
  final Color color;
  const _HomeIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Roof
    final roof = Path();
    roof.moveTo(0, s.height * 0.50);
    roof.lineTo(s.width * 0.50, 0);
    roof.lineTo(s.width, s.height * 0.50);
    canvas.drawPath(roof, p);

    // Walls + floor
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * 0.16, s.height * 0.50,
            s.width * 0.68, s.height * 0.46),
        const Radius.circular(2),
      ),
      p,
    );

    // Door
    canvas.drawRect(
      Rect.fromLTWH(s.width * 0.37, s.height * 0.66,
          s.width * 0.26, s.height * 0.30),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
  }

  @override
  bool shouldRepaint(_HomeIconPainter o) => o.color != color;
}

/// Clock / history icon
class _HistoryIconPainter extends CustomPainter {
  final Color color;
  const _HistoryIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(s.width / 2, s.height / 2), s.width * 0.44, p);
    canvas.drawLine(Offset(s.width / 2, s.height * 0.26),
        Offset(s.width / 2, s.height / 2), p);
    canvas.drawLine(Offset(s.width / 2, s.height / 2),
        Offset(s.width * 0.70, s.height / 2), p);
  }

  @override
  bool shouldRepaint(_HistoryIconPainter o) => o.color != color;
}

/// Two people silhouette
class _PeopleIconPainter extends CustomPainter {
  final Color color;
  const _PeopleIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    // Front head
    canvas.drawCircle(
        Offset(s.width * 0.36, s.height * 0.27), s.width * 0.15, p);
    // Front body arc
    final body = Path();
    body.moveTo(0, s.height);
    body.quadraticBezierTo(0, s.height * 0.60, s.width * 0.36, s.height * 0.60);
    body.quadraticBezierTo(
        s.width * 0.68, s.height * 0.60, s.width * 0.68, s.height);
    canvas.drawPath(body, p);
    // Back head
    canvas.drawCircle(
        Offset(s.width * 0.76, s.height * 0.22), s.width * 0.12,
        Paint()
          ..color = color.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1);
  }

  @override
  bool shouldRepaint(_PeopleIconPainter o) => o.color != color;
}

/// Location pin
class _LocationPinPainter extends CustomPainter {
  final Color color;
  const _LocationPinPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(s.width * 0.50, 0);
    path.cubicTo(s.width * 0.18, 0, 0, s.height * 0.26, 0, s.height * 0.46);
    path.cubicTo(0, s.height * 0.66, s.width * 0.18, s.height * 0.80,
        s.width * 0.50, s.height);
    path.cubicTo(s.width * 0.82, s.height * 0.80, s.width, s.height * 0.66,
        s.width, s.height * 0.46);
    path.cubicTo(
        s.width, s.height * 0.26, s.width * 0.82, 0, s.width * 0.50, 0);
    path.close();
    canvas.drawPath(path, p);
    canvas.drawCircle(Offset(s.width / 2, s.height * 0.44), s.width * 0.14,
        Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LocationPinPainter o) => o.color != color;
}

/// Bell notification icon
class _BellIconPainter extends CustomPainter {
  final Color color;
  const _BellIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final bell = Path();
    bell.moveTo(s.width * 0.18, s.height * 0.70);
    bell.lineTo(s.width * 0.10, s.height * 0.70);
    bell.quadraticBezierTo(
        s.width * 0.10, s.height * 0.58, s.width * 0.20, s.height * 0.54);
    bell.quadraticBezierTo(
        s.width * 0.20, s.height * 0.18, s.width * 0.50, s.height * 0.18);
    bell.quadraticBezierTo(
        s.width * 0.80, s.height * 0.18, s.width * 0.80, s.height * 0.54);
    bell.lineTo(s.width * 0.90, s.height * 0.58);
    bell.quadraticBezierTo(
        s.width * 0.90, s.height * 0.70, s.width * 0.82, s.height * 0.70);
    bell.close();
    canvas.drawPath(bell, p);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(s.width * 0.50, s.height * 0.84),
        width: s.width * 0.22, height: s.height * 0.22,
      ),
      0, math.pi, false, p,
    );
    canvas.drawLine(Offset(s.width * 0.44, 0), Offset(s.width * 0.56, 0),
        Paint()
          ..color = color
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_BellIconPainter o) => o.color != color;
}

/// Hospital cross in rounded square
class _HospitalCrossPainter extends CustomPainter {
  final Color color;
  const _HospitalCrossPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, s.width, s.height),
        Radius.circular(s.width * 0.22),
      ),
      p,
    );
    canvas.drawLine(
      Offset(s.width * 0.50, s.height * 0.22),
      Offset(s.width * 0.50, s.height * 0.78),
      Paint()
        ..color = color
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(s.width * 0.22, s.height * 0.50),
      Offset(s.width * 0.78, s.height * 0.50),
      Paint()
        ..color = color
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_HospitalCrossPainter o) => o.color != color;
}

/// Police badge hexagon + star
class _PoliceBadgePainter extends CustomPainter {
  final Color color;
  const _PoliceBadgePainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    final r  = s.width * 0.46;

    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;

    // Hexagon
    final badge = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i - math.pi / 6;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) badge.moveTo(x, y);
      else badge.lineTo(x, y);
    }
    badge.close();
    canvas.drawPath(badge, p);

    // 5-point star center
    final star = Path();
    const n = 5;
    final outerR = s.width * 0.18;
    final innerR = s.width * 0.08;
    for (int i = 0; i < n * 2; i++) {
      final angle = (i * math.pi / n) - math.pi / 2;
      final rad = i.isEven ? outerR : innerR;
      final x = cx + rad * math.cos(angle);
      final y = cy + rad * math.sin(angle);
      if (i == 0) star.moveTo(x, y);
      else star.lineTo(x, y);
    }
    star.close();
    canvas.drawPath(star, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_PoliceBadgePainter o) => o.color != color;
}

/// Phone handset with sparkle (fake call)
class _FakeCallPainter extends CustomPainter {
  final Color color;
  const _FakeCallPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final phone = Path();
    phone.moveTo(s.width * 0.14, s.height * 0.08);
    phone.lineTo(s.width * 0.14, s.height * 0.30);
    phone.quadraticBezierTo(s.width * 0.14, s.height * 0.44,
        s.width * 0.24, s.height * 0.50);
    phone.quadraticBezierTo(s.width * 0.50, s.height * 0.76,
        s.width * 0.62, s.height * 0.84);
    phone.quadraticBezierTo(s.width * 0.68, s.height * 0.90,
        s.width * 0.80, s.height * 0.90);
    phone.lineTo(s.width * 0.90, s.height * 0.90);
    phone.quadraticBezierTo(s.width, s.height * 0.90, s.width, s.height * 0.78);
    phone.lineTo(s.width, s.height * 0.70);
    phone.quadraticBezierTo(s.width, s.height * 0.58, s.width * 0.86, s.height * 0.58);
    phone.lineTo(s.width * 0.76, s.height * 0.58);
    canvas.drawPath(phone, p);

    // Sparkle
    final sp = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(s.width * 0.72, s.height * 0.08),
        Offset(s.width * 0.72, 0), sp);
    canvas.drawLine(Offset(s.width * 0.82, s.height * 0.12),
        Offset(s.width * 0.94, s.height * 0.02), sp);
    canvas.drawLine(Offset(s.width * 0.88, s.height * 0.22),
        Offset(s.width, s.height * 0.22), sp);
  }

  @override
  bool shouldRepaint(_FakeCallPainter o) => o.color != color;
}

/// Map pin for community map
class _MapPinPainter extends CustomPainter {
  final Color color;
  const _MapPinPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(s.width * 0.50, 0);
    path.cubicTo(s.width * 0.18, 0, 0, s.height * 0.24, 0, s.height * 0.44);
    path.cubicTo(0, s.height * 0.64, s.width * 0.18, s.height * 0.78,
        s.width * 0.50, s.height);
    path.cubicTo(s.width * 0.82, s.height * 0.78, s.width, s.height * 0.64,
        s.width, s.height * 0.44);
    path.cubicTo(s.width, s.height * 0.24, s.width * 0.82, 0, s.width * 0.50, 0);
    path.close();
    canvas.drawPath(path, p);

    // Inner dot
    canvas.drawCircle(Offset(s.width / 2, s.height * 0.42), s.width * 0.14,
        Paint()..color = color);
    // Horizontal lines (map grid hint)
    canvas.drawLine(Offset(s.width * 0.22, s.height * 0.56),
        Offset(s.width * 0.78, s.height * 0.56),
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..strokeWidth = 0.8
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_MapPinPainter o) => o.color != color;
}

/// Location pin with exclamation + plus (report danger)
class _ReportPinPainter extends CustomPainter {
  final Color color;
  const _ReportPinPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;

    final pin = Path();
    pin.moveTo(s.width * 0.32, 0);
    pin.cubicTo(s.width * 0.10, 0, 0, s.height * 0.20, 0, s.height * 0.38);
    pin.cubicTo(0, s.height * 0.56, s.width * 0.10, s.height * 0.70,
        s.width * 0.32, s.height * 0.80);
    pin.cubicTo(s.width * 0.54, s.height * 0.70, s.width * 0.64,
        s.height * 0.56, s.width * 0.64, s.height * 0.38);
    pin.cubicTo(s.width * 0.64, s.height * 0.20, s.width * 0.54, 0,
        s.width * 0.32, 0);
    pin.close();
    canvas.drawPath(pin, p);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * 0.29, s.height * 0.13,
            s.width * 0.06, s.height * 0.22),
        const Radius.circular(1.5),
      ),
      Paint()..color = color,
    );
    canvas.drawCircle(Offset(s.width * 0.32, s.height * 0.48),
        s.width * 0.04, Paint()..color = color);

    // Plus sign
    final thick = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(s.width * 0.80, s.height * 0.28),
        Offset(s.width * 0.80, s.height * 0.72), thick);
    canvas.drawLine(Offset(s.width * 0.58, s.height * 0.50),
        Offset(s.width * 1.02, s.height * 0.50), thick);
  }

  @override
  bool shouldRepaint(_ReportPinPainter o) => o.color != color;
}

/// Vibrate / phone shake (Shake SOS)
class _VibrateIconPainter extends CustomPainter {
  final Color color;
  const _VibrateIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
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

/// Microphone (voice SOS)
class _MicIconPainter extends CustomPainter {
  final Color color;
  const _MicIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
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
    canvas.drawLine(Offset(s.width * 0.30, s.height),
        Offset(s.width * 0.70, s.height), p);
  }

  @override
  bool shouldRepaint(_MicIconPainter o) => o.color != color;
}

/// Volume button / hardware SOS
class _HardwareBtnPainter extends CustomPainter {
  final Color color;
  const _HardwareBtnPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Phone body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * 0.20, 0, s.width * 0.60, s.height),
        Radius.circular(s.width * 0.12),
      ),
      p,
    );

    // Volume buttons on left side
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, s.height * 0.26, s.width * 0.18, s.height * 0.20),
        const Radius.circular(3),
      ),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, s.height * 0.50, s.width * 0.18, s.height * 0.20),
        const Radius.circular(3),
      ),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Sound waves from speaker
    for (int i = 0; i < 2; i++) {
      final off = i * s.width * 0.12;
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(s.width * 0.50, s.height * 0.50),
          width: s.width * (0.40 + off),
          height: s.height * (0.40 + off),
        ),
        -0.7, 1.4, false,
        Paint()
          ..color = color.withValues(alpha: 0.50 - i * 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }
  }

  @override
  bool shouldRepaint(_HardwareBtnPainter o) => o.color != color;
}

/// Calculator icon (decoy PIN)
class _CalcIconPainter extends CustomPainter {
  final Color color;
  const _CalcIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, s.width, s.height),
        const Radius.circular(3),
      ),
      p,
    );
    // Display strip
    canvas.drawRect(
      Rect.fromLTWH(s.width * 0.10, s.height * 0.10,
          s.width * 0.80, s.height * 0.22),
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill,
    );
    // Key dots
    final dotP = Paint()..color = color;
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        canvas.drawCircle(
          Offset(s.width * (0.22 + col * 0.28),
              s.height * (0.52 + row * 0.16)),
          s.width * 0.05,
          dotP,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CalcIconPainter o) => o.color != color;
}

/// PDF document icon
class _PdfIconPainter extends CustomPainter {
  final Color color;
  const _PdfIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;

    final doc = Path();
    doc.moveTo(s.width * 0.18, 0);
    doc.lineTo(s.width * 0.68, 0);
    doc.lineTo(s.width, s.height * 0.30);
    doc.lineTo(s.width, s.height);
    doc.lineTo(s.width * 0.18, s.height);
    doc.close();
    canvas.drawPath(doc, p);

    // Fold corner
    final fold = Path();
    fold.moveTo(s.width * 0.68, 0);
    fold.lineTo(s.width * 0.68, s.height * 0.30);
    fold.lineTo(s.width, s.height * 0.30);
    canvas.drawPath(fold,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);

    // Lines
    for (int i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(s.width * 0.32, s.height * (0.46 + i * 0.16)),
        Offset(s.width * 0.82, s.height * (0.46 + i * 0.16)),
        Paint()
          ..color = color
          ..strokeWidth = 1.0
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_PdfIconPainter o) => o.color != color;
}

/// Settings gear icon
class _SettingsGearPainter extends CustomPainter {
  final Color color;
  const _SettingsGearPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    // Center circle
    canvas.drawCircle(Offset(cx, cy), s.width * 0.22, p);

    // Gear teeth (8 teeth)
    const teeth = 8;
    for (int i = 0; i < teeth; i++) {
      final angle = (2 * math.pi / teeth) * i;
      final inner = s.width * 0.32;
      final outer = s.width * 0.46;
      canvas.drawLine(
        Offset(cx + inner * math.cos(angle), cy + inner * math.sin(angle)),
        Offset(cx + outer * math.cos(angle), cy + outer * math.sin(angle)),
        Paint()
          ..color = color
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_SettingsGearPainter o) => o.color != color;
}

/// Fingerprint arc lines
class _FingerprintPainter extends CustomPainter {
  final Color color;
  const _FingerprintPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height * 0.55;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Concentric arcs — each slightly smaller
    final radii = [s.width * 0.46, s.width * 0.34, s.width * 0.22, s.width * 0.10];
    for (int i = 0; i < radii.length; i++) {
      p.strokeWidth = 1.2 - i * 0.05;
      canvas.drawArc(
        Rect.fromCenter(
            center: Offset(cx, cy), width: radii[i] * 2, height: radii[i] * 2),
        math.pi * 0.10,
        math.pi * 0.80,
        false,
        Paint()
          ..color = color.withValues(alpha: 0.85 - i * 0.05)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round,
      );
    }

    // Vertical base line
    canvas.drawLine(
      Offset(cx, cy + s.height * 0.46),
      Offset(cx, s.height * 0.98),
      Paint()
        ..color = color.withValues(alpha: 0.55)
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_FingerprintPainter o) => o.color != color;
}

/// Logout arrow (door + arrow pointing right)
class _LogoutArrowPainter extends CustomPainter {
  final Color color;
  const _LogoutArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Door frame (open on right)
    final door = Path();
    door.moveTo(s.width * 0.54, s.height * 0.08);
    door.lineTo(s.width * 0.16, s.height * 0.08);
    door.lineTo(s.width * 0.16, s.height * 0.92);
    door.lineTo(s.width * 0.54, s.height * 0.92);
    canvas.drawPath(door, p);

    // Horizontal arrow pointing right (exit)
    canvas.drawLine(
      Offset(s.width * 0.40, s.height * 0.50),
      Offset(s.width * 0.92, s.height * 0.50),
      p,
    );

    // Arrowhead
    final head = Path();
    head.moveTo(s.width * 0.70, s.height * 0.32);
    head.lineTo(s.width * 0.92, s.height * 0.50);
    head.lineTo(s.width * 0.70, s.height * 0.68);
    canvas.drawPath(head, p);
  }

  @override
  bool shouldRepaint(_LogoutArrowPainter o) => o.color != color;
}

/// GPS crosshair
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

    canvas.drawCircle(Offset(cx, cy), s.width * 0.28, p);
    canvas.drawCircle(Offset(cx, cy), s.width * 0.07,
        Paint()..color = color);
    canvas.drawLine(Offset(cx, 0), Offset(cx, s.height * 0.20), p);
    canvas.drawLine(
        Offset(cx, s.height * 0.80), Offset(cx, s.height), p);
    canvas.drawLine(Offset(0, cy), Offset(s.width * 0.20, cy), p);
    canvas.drawLine(
        Offset(s.width * 0.80, cy), Offset(s.width, cy), p);
  }

  @override
  bool shouldRepaint(_GpsIconPainter o) => o.color != color;
}

/// Chevron right arrow
class _ChevronRightPainter extends CustomPainter {
  final Color color;
  const _ChevronRightPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(s.width * 0.22, s.height * 0.16);
    path.lineTo(s.width * 0.72, s.height * 0.50);
    path.lineTo(s.width * 0.22, s.height * 0.84);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_ChevronRightPainter o) => o.color != color;
}