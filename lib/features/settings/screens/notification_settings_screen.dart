// lib/features/settings/screens/notification_settings_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// SAFEHER — NOTIFICATION SETTINGS
// Per-channel toggles: SOS, Journey, Contacts, Community, System
// All stored via SharedPreferences
//
// FIX: Overflow on right side of _ChanTile rows
//   Root cause: Row(title + badge) had no Flexible/Expanded wrapping,
//   causing badge + switch to overflow at ~1.7–84px on right edge.
//   Fix: Wrapped title Text in Flexible so it truncates before pushing
//   badge and switch off screen.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {

  static const _kSosNotif       = 'notif_sos';
  static const _kJourneyNotif   = 'notif_journey';
  static const _kContactNotif   = 'notif_contact';
  static const _kCommunityNotif = 'notif_community';
  static const _kSystemNotif    = 'notif_system';
  static const _kSosSound       = 'notif_sos_sound';
  static const _kSosVibrate     = 'notif_sos_vibrate';
  static const _kJourneySound   = 'notif_journey_sound';
  static const _kSilentMode     = 'notif_silent_mode';

  bool _sosNotif       = true;
  bool _journeyNotif   = true;
  bool _contactNotif   = true;
  bool _communityNotif = true;
  bool _systemNotif    = true;
  bool _sosSound       = true;
  bool _sosVibrate     = true;
  bool _journeySound   = true;
  bool _silentMode     = false;
  bool _loaded         = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _sosNotif       = p.getBool(_kSosNotif)       ?? true;
      _journeyNotif   = p.getBool(_kJourneyNotif)   ?? true;
      _contactNotif   = p.getBool(_kContactNotif)   ?? true;
      _communityNotif = p.getBool(_kCommunityNotif) ?? true;
      _systemNotif    = p.getBool(_kSystemNotif)    ?? true;
      _sosSound       = p.getBool(_kSosSound)       ?? true;
      _sosVibrate     = p.getBool(_kSosVibrate)     ?? true;
      _journeySound   = p.getBool(_kJourneySound)   ?? true;
      _silentMode     = p.getBool(_kSilentMode)     ?? false;
      _loaded         = true;
    });
  }

  Future<void> _set(String k, bool v) async =>
      (await SharedPreferences.getInstance()).setBool(k, v);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? AppColors.darkBackground : const Color(0xFFF0F4FF);

    if (!_loaded) {
      return Scaffold(
        backgroundColor: bg,
        body: const Center(child: CircularProgressIndicator(
            color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: _AppBar('Notifications', isDark),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [

          // ── Silent Mode banner ────────────────────────────────
          FadeInDown(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _silentMode = !_silentMode);
                _set(_kSilentMode, _silentMode);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _silentMode
                        ? [const Color(0xFF424242), const Color(0xFF212121)]
                        : [AppColors.primary, AppColors.secondary],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(
                    color: (_silentMode ? Colors.grey : AppColors.primary)
                        .withOpacity(0.3),
                    blurRadius: 16,
                  )],
                ),
                child: Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle),
                    child: Icon(
                        _silentMode
                            ? Icons.volume_off_rounded
                            : Icons.notifications_active_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _silentMode ? '🔕 Silent Mode ON' : '🔔 Notifications Active',
                        style: const TextStyle(color: Colors.white,
                            fontFamily: 'Poppins', fontWeight: FontWeight.w800,
                            fontSize: 15),
                      ),
                      Text(
                        _silentMode
                            ? 'Only critical SOS alerts will play sound'
                            : 'All notification channels active',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontFamily: 'Poppins', fontSize: 11),
                      ),
                    ],
                  )),
                  Switch.adaptive(
                    value: _silentMode,
                    activeColor: Colors.white,
                    activeTrackColor: Colors.white.withOpacity(0.3),
                    onChanged: (v) {
                      HapticFeedback.lightImpact();
                      setState(() => _silentMode = v);
                      _set(_kSilentMode, v);
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 22),

          // ── CHANNELS ─────────────────────────────────────────
          FadeInUp(child: const _Label('NOTIFICATION CHANNELS')),
          const SizedBox(height: 10),
          FadeInUp(
            delay: const Duration(milliseconds: 50),
            child: _Card(isDark: isDark, child: Column(children: [
              _ChanTile(
                icon: Icons.emergency_rounded,
                iconBg: AppColors.sosRed,
                title: 'SOS & Emergency Alerts',
                sub: 'Critical SOS triggers, countdowns, AI danger alerts',
                badge: 'CRITICAL',
                badgeColor: AppColors.sosRed,
                value: _sosNotif,
                onChanged: (v) { setState(() => _sosNotif = v); _set(_kSosNotif, v); },
                isDark: isDark,
              ),
              _Div(isDark),
              _ChanTile(
                icon: Icons.route_rounded,
                iconBg: AppColors.safeGreen,
                title: 'Journey Tracking',
                sub: 'Journey start, arrival, overdue alerts',
                badge: 'HIGH',
                badgeColor: AppColors.safeGreen,
                value: _journeyNotif,
                onChanged: (v) { setState(() => _journeyNotif = v); _set(_kJourneyNotif, v); },
                isDark: isDark,
              ),
              _Div(isDark),
              _ChanTile(
                icon: Icons.people_rounded,
                iconBg: AppColors.secondary,
                title: 'Guardian Activity',
                sub: 'Contact added, removed, SOS alerts sent',
                badge: 'MED',
                badgeColor: AppColors.secondary,
                value: _contactNotif,
                onChanged: (v) { setState(() => _contactNotif = v); _set(_kContactNotif, v); },
                isDark: isDark,
              ),
              _Div(isDark),
              _ChanTile(
                icon: Icons.public_rounded,
                iconBg: AppColors.warningAmber,
                title: 'Community & Danger Zones',
                sub: 'Nearby danger zone reports, community alerts',
                badge: 'MED',
                badgeColor: AppColors.warningAmber,
                value: _communityNotif,
                onChanged: (v) { setState(() => _communityNotif = v); _set(_kCommunityNotif, v); },
                isDark: isDark,
              ),
              _Div(isDark),
              _ChanTile(
                icon: Icons.info_rounded,
                iconBg: AppColors.primary,
                title: 'System & App Updates',
                sub: 'Profile saved, PIN changed, app status',
                badge: 'LOW',
                badgeColor: Colors.grey,
                value: _systemNotif,
                onChanged: (v) { setState(() => _systemNotif = v); _set(_kSystemNotif, v); },
                isDark: isDark,
              ),
            ])),
          ),
          const SizedBox(height: 22),

          // ── SOUND & VIBRATION ─────────────────────────────────
          FadeInUp(
            delay: const Duration(milliseconds: 80),
            child: const _Label('SOUND & VIBRATION'),
          ),
          const SizedBox(height: 10),
          FadeInUp(
            delay: const Duration(milliseconds: 100),
            child: _Card(isDark: isDark, child: Column(children: [
              _Toggle(
                icon: Icons.volume_up_rounded, iconBg: AppColors.sosRed,
                title: 'SOS Alarm Sound',
                sub: 'Loud siren when SOS activates',
                value: _sosSound,
                onChanged: (v) {
                  HapticFeedback.lightImpact();
                  setState(() => _sosSound = v);
                  _set(_kSosSound, v);
                },
              ),
              _Div(isDark),
              _Toggle(
                icon: Icons.vibration_rounded, iconBg: AppColors.primary,
                title: 'SOS Vibration',
                sub: 'Vibrate pattern during SOS countdown',
                value: _sosVibrate,
                onChanged: (v) {
                  HapticFeedback.lightImpact();
                  setState(() => _sosVibrate = v);
                  _set(_kSosVibrate, v);
                },
              ),
              _Div(isDark),
              _Toggle(
                icon: Icons.music_note_rounded, iconBg: AppColors.safeGreen,
                title: 'Journey Alert Sound',
                sub: 'Play sound on arrival and overdue alerts',
                value: _journeySound,
                onChanged: (v) {
                  HapticFeedback.lightImpact();
                  setState(() => _journeySound = v);
                  _set(_kJourneySound, v);
                },
              ),
            ])),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ChanTile — FIXED overflow
// Root cause: Row([Text(title), badge]) inside Column had no Flexible on Text,
//             so long titles pushed badge + Switch off screen right edge.
// Fix: Wrap title Text in Flexible(child: Text(...)) so it truncates.
//      Switch is outside the Expanded content column — always visible.
// ─────────────────────────────────────────────────────────────────────────────

class _ChanTile extends StatelessWidget {
  final IconData icon;
  final Color    iconBg;
  final String   title, sub, badge;
  final Color    badgeColor;
  final bool     value, isDark;
  final ValueChanged<bool> onChanged;

  const _ChanTile({
    required this.icon,     required this.iconBg,
    required this.title,    required this.sub,
    required this.badge,    required this.badgeColor,
    required this.value,    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
                color: iconBg.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconBg, size: 22),
          ),
          const SizedBox(width: 12),

          // Title + subtitle + badge — Expanded prevents overflow
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ FIX: Row with Flexible title so badge never overflows
              Row(children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    badge,
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: badgeColor),
                  ),
                ),
              ]),
              const SizedBox(height: 3),
              Text(
                sub,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.grey,
                    fontFamily: 'Poppins',
                    fontSize: 11),
              ),
            ],
          )),

          // Switch — always at far right, never displaced
          const SizedBox(width: 8),
          Switch.adaptive(
            value:    value,
            onChanged: onChanged,
            activeColor: iconBg,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

PreferredSizeWidget _AppBar(String title, bool isDark) => AppBar(
  backgroundColor: Colors.transparent,
  elevation:       0,
  iconTheme: IconThemeData(
      color: isDark ? Colors.white : AppColors.lightText),
  title: Text(title, style: const TextStyle(
      fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 18)),
  bottom: PreferredSize(
    preferredSize: const Size.fromHeight(1),
    child: Container(height: 1, color: Colors.grey.withOpacity(0.1)),
  ),
);

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
        color:       Colors.grey.withOpacity(0.6),
        fontSize:    10,
        fontFamily:  'Poppins',
        fontWeight:  FontWeight.w800,
        letterSpacing: 1.4),
  );
}

class _Card extends StatelessWidget {
  final bool   isDark;
  final Widget child;
  const _Card({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
        color:         isDark ? AppColors.darkCard : Colors.white,
        borderRadius:  BorderRadius.circular(20),
        boxShadow:     AppColors.cardShadow),
    child: ClipRRect(
        borderRadius: BorderRadius.circular(20), child: child),
  );
}

class _Toggle extends StatelessWidget {
  final IconData icon;
  final Color    iconBg;
  final String   title, sub;
  final bool     value;
  final ValueChanged<bool> onChanged;

  const _Toggle({
    required this.icon,  required this.iconBg,
    required this.title, required this.sub,
    required this.value, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    child: Row(children: [
      Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
            color: iconBg.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: iconBg, size: 22),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(
              fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 13)),
          Text(sub, style: const TextStyle(
              color: Colors.grey, fontFamily: 'Poppins', fontSize: 11)),
        ],
      )),
      Switch.adaptive(
        value:    value,
        onChanged: onChanged,
        activeColor: iconBg,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ]),
  );
}

class _Div extends StatelessWidget {
  final bool isDark;
  const _Div(this.isDark);

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    indent: 70,
    color: isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.06),
  );
}