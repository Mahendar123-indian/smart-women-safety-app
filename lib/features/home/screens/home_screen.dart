// lib/features/home/screens/home_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

// Core
import '../../../core/services/ml_monitoring_service.dart';
import '../../../core/services/voice_sos_service.dart';
import '../../../core/services/hardware_sos_service.dart';
import '../../../core/services/shake_sos_service.dart';
import '../../../core/services/community_service.dart';
import '../../../core/services/decoy_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/router/app_router.dart';

// Providers
import '../../auth/providers/auth_provider.dart';
import '../../contacts/providers/contact_provider.dart';
import '../../location/providers/location_provider.dart';
import '../../sos/providers/sos_provider.dart';
import '../../../core/services/audio_evidence_service.dart';

// Screens
import '../../location/screens/location_screen.dart';
import '../../contacts/screens/contacts_screen.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../safety_places/screens/police_stations_screen.dart';
import '../../community/screens/community_map_screen.dart';
import '../../community/screens/report_danger_screen.dart';
import '../../incidents/screens/incident_detail_screen.dart';
import '../../police/screens/police_dashboard_screen.dart';

// Home Widgets
import '../widgets/safety_tip_banner.dart';
import '../widgets/sos_banners.dart';
import '../widgets/ml_danger_card.dart';
import '../widgets/live_metrics_row.dart';
import '../widgets/ml_insights_card.dart';
import '../widgets/quick_actions_grid.dart';
import '../widgets/safety_tools_row.dart';
import '../widgets/location_card.dart';
import '../widgets/contacts_strip.dart';
import '../widgets/protection_status.dart';
import '../widgets/ml_analytics_card.dart';

// ═══════════════════════════════════════════════════════════════════════
// HOME SCREEN
// ═══════════════════════════════════════════════════════════════════════

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  int _tab = 0;

  late AnimationController _sosPulseCtrl;
  late AnimationController _bgCtrl;

  int _unread = 0;
  StreamSubscription? _notifSub;

  @override
  void initState() {
    super.initState();

    _sosPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContactProvider>().init();
      context.read<LocationProvider>().init();
      context.read<SosProvider>().init();
      context.read<SosProvider>().setContactProvider(
        context.read<ContactProvider>(),
      );
      _wireHardwareSos();
      _wireVoiceSos();
      _wireShakeSos();
      AudioEvidenceService.instance.startMlAudioLoop();
    });
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _notifSub = FirebaseFirestore.instance
          .collection('contactNotifications')
          .where('recipientUid', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .snapshots()
          .listen((s) {
        if (mounted) setState(() => _unread = s.docs.length);
      });
    }
  }

  void _wireHardwareSos() {
    final hw = HardwareSosService.instance;
    hw.initialize();
    hw.onSosTriggered = (event) {
      if (!mounted) return;
      final sos = context.read<SosProvider>();
      if (!sos.isSosActive) {
        sos.triggerSilentSOS(triggerType: 'hardware');
        Navigator.pushNamed(context, AppRouter.sos);
      }
    };
  }

  void _wireVoiceSos() {
    final vs = VoiceSosService.instance;
    vs.initialize().then((_) => vs.start());

    vs.onKeywordDetected = (_) {
      if (!mounted) return;
      final sos = context.read<SosProvider>();
      if (!sos.isSosActive) {
        Navigator.pushNamed(context, AppRouter.sos);
      }
    };
  }

  void _wireShakeSos() {
    final shake = ShakeSosService.instance;
    shake.initialize();
    shake.onSosTriggered = (result) {
      if (!mounted) return;
      final sos = context.read<SosProvider>();
      if (!sos.isSosActive) {
        sos.triggerSilentSOS(triggerType: 'shake');
        Navigator.pushNamed(context, AppRouter.sos);
      }
    };
    shake.onCandidate = (confidence, shakeCount) {
      if (!mounted) return;
      HapticFeedback.lightImpact();
    };
  }

  @override
  void dispose() {
    _sosPulseCtrl.dispose();
    _bgCtrl.dispose();
    _notifSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [_HomeTab(), LocationScreen(), ContactsScreen()],
      ),
      floatingActionButton: _SosFab(pulseCtrl: _sosPulseCtrl),
      floatingActionButtonLocation:
      FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomBar(
        current: _tab,
        unread: _unread,
        onTab: (i) => setState(() => _tab = i),
        onNotif: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SOS FAB
// ═══════════════════════════════════════════════════════════════════════

class _SosFab extends StatelessWidget {
  final AnimationController pulseCtrl;
  const _SosFab({required this.pulseCtrl});

  @override
  Widget build(BuildContext context) {
    final sos = context.watch<SosProvider>();
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRouter.sos),
      onLongPress: () {
        HapticFeedback.heavyImpact();
        sos.triggerManualSOS();
        Navigator.pushNamed(context, AppRouter.sos);
      },
      child: AnimatedBuilder(
        animation: pulseCtrl,
        builder: (_, __) {
          final glow = sos.isSosActive ? 0.9 : 0.35 + 0.35 * pulseCtrl.value;
          final blur = sos.isSosActive ? 50.0 : 18 + 20 * pulseCtrl.value;
          return Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: sos.isSosActive
                  ? const LinearGradient(
                  colors: [Color(0xFFFF6D00), Color(0xFFFF1744)])
                  : AppColors.sosGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.sosRed.withValues(alpha: glow),
                  blurRadius: blur,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomPaint(
                  size: const Size(26, 26),
                  painter: sos.isSosActive
                      ? _WarningIconPainter()
                      : _SosIconPainter(),
                ),
                Text(
                  sos.isSosActive ? 'ACTIVE' : 'SOS',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Poppins',
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// BOTTOM BAR
// ═══════════════════════════════════════════════════════════════════════

class _BottomBar extends StatelessWidget {
  final int current;
  final int unread;
  final void Function(int) onTab;
  final VoidCallback onNotif;

  const _BottomBar({
    required this.current,
    required this.unread,
    required this.onTab,
    required this.onNotif,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 10,
      color: AppColors.darkSurface,
      elevation: 8,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavBtn(
              painter: _HomeIconPainter(),
              label: 'Home',
              index: 0,
              current: current,
              onTap: onTab,
            ),
            _NavBtn(
              painter: _MapIconPainter(),
              label: 'Location',
              index: 1,
              current: current,
              onTap: onTab,
            ),
            const SizedBox(width: 70),
            _NavBtn(
              painter: _PeopleIconPainter(),
              label: 'Contacts',
              index: 2,
              current: current,
              onTap: onTab,
            ),
            Expanded(
              child: GestureDetector(
                onTap: onNotif,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CustomPaint(
                          size: const Size(22, 22),
                          painter: _BellIconPainter(color: Colors.grey),
                        ),
                        if (unread > 0)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                gradient: AppColors.sosGradient,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  unread > 9 ? '9+' : '$unread',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Alerts',
                      style: TextStyle(
                        fontSize: 9,
                        fontFamily: 'Poppins',
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final CustomPainter painter;
  final String label;
  final int index;
  final int current;
  final void Function(int) onTap;

  const _NavBtn({
    required this.painter,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sel = index == current;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap(index);
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: sel
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: CustomPaint(
                size: const Size(20, 20),
                painter: _ColoredPainter(
                  painter: painter,
                  color: sel ? AppColors.primary : Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontFamily: 'Poppins',
                fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                color: sel ? AppColors.primary : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// HOME TAB
// ═══════════════════════════════════════════════════════════════════════

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> with TickerProviderStateMixin {
  late AnimationController _radarCtrl;
  late AnimationController _breathCtrl;
  late AnimationController _entryCtrl;
  late Animation<double> _entryFade;

  MLDangerResult _ml = MLDangerResult.safe();
  StreamSubscription? _mlSub;
  StreamSubscription? _autoSosSub;

  int _tipIdx = 0;
  Timer? _tipTimer;
  DateTime _now = DateTime.now();
  Timer? _clock;

  static const _tips = [
    '💡 Share your live location when traveling alone at night.',
    '💡 Shake phone 3× rapidly to trigger emergency SOS.',
    '💡 Fake Call helps escape uncomfortable situations discreetly.',
    '💡 Add at least 3 emergency contacts for maximum protection.',
    '💡 Offline SOS works even without internet — keep it enabled.',
    '💡 AI guard monitors your movement 24/7 in background.',
    '💡 Enable geofence zones around your home and workplace.',
    '💡 Silent SOS sends alert without any alarm sound.',
    '💡 Hold Volume Down 3s to trigger instant silent SOS.',
    '💡 Say "Help" or "Bachao" to activate Voice SOS.',
    '💡 Report danger zones to protect other women in your area.',
    '💡 Decoy PIN shows fake calculator to anyone snooping.',
  ];

  @override
  void initState() {
    super.initState();
    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _entryFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: Curves.easeOut,
    );
    _entryCtrl.forward();

    _clock = Timer.periodic(
      const Duration(minutes: 1),
          (_) {
        if (mounted) setState(() => _now = DateTime.now());
      },
    );
    _tipTimer = Timer.periodic(
      const Duration(seconds: 8),
          (_) {
        if (mounted) {
          setState(() => _tipIdx = (_tipIdx + 1) % _tips.length);
        }
      },
    );

    _startML();
  }

  void _startML() {
    final ml = MLMonitoringService.instance;
    if (!ml.isRunning) ml.start();

    _mlSub = ml.resultStream.listen((r) {
      if (!mounted) return;
      setState(() => _ml = r);
      context.read<SosProvider>().updateDangerScore(r.score);
      ShakeSosService.instance.updateMlDangerScore(r.score);
    });

    _autoSosSub = ml.autoSosStream.listen((r) {
      if (!mounted) return;
      final sos = context.read<SosProvider>();
      if (!sos.isSosActive && !sos.isCountingDown) {
        r.sosTriggered
            ? sos.triggerManualSOS()
            : sos.startCountdown();
        Navigator.pushNamed(context, AppRouter.sos);
      }
    });
  }

  @override
  void dispose() {
    _radarCtrl.dispose();
    _breathCtrl.dispose();
    _entryCtrl.dispose();
    _mlSub?.cancel();
    _autoSosSub?.cancel();
    _clock?.cancel();
    _tipTimer?.cancel();
    super.dispose();
  }

  String get _greeting {
    final h = _now.hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final contacts = context.watch<ContactProvider>();
    final location = context.watch<LocationProvider>();
    final sos = context.watch<SosProvider>();
    final size = MediaQuery.of(context).size;
    final firstName = (auth.user?.name ?? 'User').split(' ').first;

    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: const SafeHerDrawer(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF07071A), Color(0xFF0F0F28)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: _buildBgBlobs(size)),
            SafeArea(
              child: FadeTransition(
                opacity: _entryFade,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          _buildItems(
                            auth: auth,
                            contacts: contacts,
                            location: location,
                            sos: sos,
                            firstName: firstName,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildItems({
    required AuthProvider auth,
    required ContactProvider contacts,
    required LocationProvider location,
    required SosProvider sos,
    required String firstName,
  }) {
    return [
      const SizedBox(height: 12),

      // ── Top bar ──────────────────────────────────────────────
      _TopBar(
        greeting: _greeting,
        firstName: firstName,
        ml: _ml,
        sos: sos,
      ),
      const SizedBox(height: 14),

      // ── Tip banner ───────────────────────────────────────────
      SafetyTipBanner(tip: _tips[_tipIdx]),
      const SizedBox(height: 8),

      _VoiceSosStatusBar(),
      _ShakeSosStatusBar(),
      const SizedBox(height: 4),

      // ── Alert banners ────────────────────────────────────────
      if (sos.isSosActive) ...[
        SosActiveBanner(sos: sos),
        const SizedBox(height: 10),
      ],
      if (sos.isCountingDown && !sos.isSosActive) ...[
        SosCountdownBanner(
          sos: sos,
          onCancel: sos.cancelCountdown,
        ),
        const SizedBox(height: 10),
      ],
      if (_ml.level == DangerLevel.high ||
          _ml.level == DangerLevel.critical) ...[
        MlDangerAlertBanner(ml: _ml),
        const SizedBox(height: 10),
      ],

      // ── ML Danger card ───────────────────────────────────────
      MlDangerCard(
        ml: _ml,
        radarCtrl: _radarCtrl,
        breathCtrl: _breathCtrl,
      ),
      const SizedBox(height: 14),

      // ── Live metrics ─────────────────────────────────────────
      LiveMetricsRow(
        ml: _ml,
        contacts: contacts,
        location: location,
        isDark: true,
      ),
      const SizedBox(height: 16),

      // ── AI Insights ──────────────────────────────────────────
      MlInsightsCard(ml: _ml, isDark: true),
      const SizedBox(height: 18),

      // ── Quick Actions ────────────────────────────────────────
      _SectionHeader(
        painter: _BoltIconPainter(color: AppColors.warningAmber),
        title: 'Quick Actions',
        color: AppColors.warningAmber,
      ),
      const SizedBox(height: 10),
      QuickActionsGrid(isDark: true),
      const SizedBox(height: 18),

      // ── Safety Tools ─────────────────────────────────────────
      _SectionHeader(
        painter: _ShieldIconPainter(color: AppColors.secondary),
        title: 'Safety Tools',
        color: AppColors.secondary,
      ),
      const SizedBox(height: 10),
      SafetyToolsRow(isDark: true),
      const SizedBox(height: 18),

      // ── Advanced Protection ──────────────────────────────────
      _SectionHeader(
        painter: _LockShieldPainter(color: AppColors.primary),
        title: 'Advanced Protection',
        color: AppColors.primary,
      ),
      const SizedBox(height: 10),
      _AdvancedGrid(ml: _ml),
      const SizedBox(height: 18),

      // ── Community ────────────────────────────────────────────
      _SectionHeader(
        painter: _PeopleIconPainter(color: AppColors.safeGreen),
        title: 'Community Safety',
        color: AppColors.safeGreen,
        onSeeAll: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CommunityMapScreen()),
        ),
      ),
      const SizedBox(height: 10),
      _CommunitySafetyCard(ml: _ml),
      const SizedBox(height: 18),

      // ── Location ─────────────────────────────────────────────
      _SectionHeader(
        painter: _LocationPinPainter(color: AppColors.secondary),
        title: 'Location',
        color: AppColors.secondary,
        onSeeAll: () =>
            Navigator.pushNamed(context, AppRouter.location),
      ),
      const SizedBox(height: 10),
      LocationCard(location: location, isDark: true),
      const SizedBox(height: 18),

      // ── Emergency Contacts ───────────────────────────────────
      _SectionHeader(
        painter: _PeopleIconPainter(color: AppColors.primary),
        title: 'Emergency Contacts',
        color: AppColors.primary,
        badge: '${contacts.activeCount} active',
        onSeeAll: () =>
            Navigator.pushNamed(context, AppRouter.contacts),
      ),
      const SizedBox(height: 10),
      ContactsStrip(contacts: contacts, isDark: true),
      const SizedBox(height: 18),

      // ── Incidents ────────────────────────────────────────────
      _SectionHeader(
        painter: _HistoryIconPainter(color: AppColors.sosRed),
        title: 'Recent Incidents',
        color: AppColors.sosRed,
        badge: '${sos.incidents.length}',
        onSeeAll: () =>
            Navigator.pushNamed(context, AppRouter.incidents),
      ),
      const SizedBox(height: 10),
      _IncidentsSection(sos: sos),
      const SizedBox(height: 18),

      // ── Protection status ────────────────────────────────────
      ProtectionStatus(
        sos: sos,
        location: location,
        contacts: contacts,
        ml: _ml,
        isDark: true,
      ),
      const SizedBox(height: 18),

      // ── AI Analytics ─────────────────────────────────────────
      _SectionHeader(
        painter: _AnalyticsIconPainter(color: AppColors.secondary),
        title: 'AI Analytics',
        color: AppColors.secondary,
      ),
      const SizedBox(height: 10),
      MlAnalyticsCard(ml: _ml, isDark: true),
      const SizedBox(height: 8),
    ];
  }

  Widget _buildBgBlobs(Size size) {
    return AnimatedBuilder(
      animation: _breathCtrl,
      builder: (_, __) {
        final t = _breathCtrl.value;
        return Stack(
          children: [
            Positioned(
              top: -size.height * 0.05 + t * 20,
              right: -size.width * 0.18,
              child: Container(
                width: size.width * 0.65,
                height: size.width * 0.65,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary
                          .withValues(alpha: 0.07 * (1 + t * 0.5)),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -size.height * 0.05 - t * 15,
              left: -size.width * 0.2,
              child: Container(
                width: size.width * 0.60,
                height: size.width * 0.60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.secondary
                          .withValues(alpha: 0.05 * (1 + t * 0.5)),
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
}

// ═══════════════════════════════════════════════════════════════════════
// TOP BAR
// ═══════════════════════════════════════════════════════════════════════

class _TopBar extends StatelessWidget {
  final String greeting;
  final String firstName;
  final MLDangerResult ml;
  final SosProvider sos;

  const _TopBar({
    required this.greeting,
    required this.firstName,
    required this.ml,
    required this.sos,
  });

  Color get _mlColor {
    switch (ml.level) {
      case DangerLevel.safe:
        return AppColors.safeGreen;
      case DangerLevel.low:
        return AppColors.warningAmber;
      case DangerLevel.medium:
        return const Color(0xFFFF8F00);
      case DangerLevel.high:
      case DangerLevel.critical:
        return AppColors.sosRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Builder(
          builder: (ctx) => GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              Scaffold.of(ctx).openDrawer();
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(20, 14),
                  painter: _HamburgerPainter(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    greeting,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Poppins',
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.safeGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Text(
                    'AI On',
                    style: TextStyle(
                      fontSize: 9,
                      fontFamily: 'Poppins',
                      color: AppColors.safeGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                firstName,
                style: const TextStyle(
                  fontSize: 20,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (ml.level != DangerLevel.safe) ...[
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _mlColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _mlColor.withValues(alpha: 0.45),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _mlColor,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '${(ml.score * 100).toInt()}%',
                  style: TextStyle(
                    color: _mlColor,
                    fontSize: 11,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (sos.isCountingDown)
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRouter.sos),
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                gradient: AppColors.sosGradient,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                'SOS ${sos.countdown}s',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          )
        else
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const NotificationsScreen()),
            ),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(22, 22),
                  painter: _BellIconPainter(color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SECTION HEADER
// ═══════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final CustomPainter painter;
  final String title;
  final Color color;
  final String? badge;
  final VoidCallback? onSeeAll;

  const _SectionHeader({
    required this.painter,
    required this.title,
    required this.color,
    this.badge,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: CustomPaint(
              size: const Size(15, 15),
              painter: painter,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge!,
                    maxLines: 1,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onSeeAll != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSeeAll,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'See all',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 2),
                CustomPaint(
                  size: const Size(10, 10),
                  painter: _ChevronRightPainter(color: color),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// VOICE SOS STATUS BAR
// ═══════════════════════════════════════════════════════════════════════

class _VoiceSosStatusBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: VoiceSosService.instance,
      builder: (_, __) {
        final vs = VoiceSosService.instance;
        if (!vs.isEnabled) return const SizedBox.shrink();
        final isDetected = vs.state == VoiceSosState.detected;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDetected
                ? AppColors.sosRed.withValues(alpha: 0.12)
                : AppColors.safeGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDetected
                  ? AppColors.sosRed.withValues(alpha: 0.30)
                  : AppColors.safeGreen.withValues(alpha: 0.20),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              CustomPaint(
                size: const Size(12, 12),
                painter: _MicIconPainter(
                  color: isDetected ? AppColors.sosRed : AppColors.safeGreen,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  isDetected
                      ? '🚨 Keyword Detected — Triggering SOS...'
                      : '🎙️ Voice SOS Listening',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDetected
                        ? AppColors.sosRed
                        : AppColors.safeGreen,
                  ),
                ),
              ),
              if (isDetected)
                GestureDetector(
                  onTap: vs.cancelDetection,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.safeGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Safe',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9,
                        color: AppColors.safeGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SHAKE SOS STATUS BAR
// ═══════════════════════════════════════════════════════════════════════

class _ShakeSosStatusBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ShakeSosService.instance,
      builder: (_, __) {
        final shake = ShakeSosService.instance;
        if (!shake.isEnabled) return const SizedBox.shrink();
        final isCandidate = shake.state == ShakeSosState.candidate;
        final isCooldown = shake.state == ShakeSosState.cooldown;
        if (!isCandidate && !isCooldown) return const SizedBox.shrink();
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isCandidate
                ? AppColors.warningAmber.withValues(alpha: 0.12)
                : AppColors.safeGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isCandidate
                  ? AppColors.warningAmber.withValues(alpha: 0.40)
                  : AppColors.safeGreen.withValues(alpha: 0.20),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              CustomPaint(
                size: const Size(12, 12),
                painter: _VibrateIconPainter(
                  color: isCandidate
                      ? AppColors.warningAmber
                      : AppColors.safeGreen,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  isCandidate
                      ? '⚠️ Shake Detected — AI Analyzing...'
                      : '✅ Shake SOS Cooldown (25s)',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isCandidate
                        ? AppColors.warningAmber
                        : AppColors.safeGreen,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ADVANCED PROTECTION GRID
// ═══════════════════════════════════════════════════════════════════════

class _AdvancedGrid extends StatelessWidget {
  final MLDangerResult ml;
  const _AdvancedGrid({required this.ml});

  String get _voiceStatus {
    final s = VoiceSosService.instance.state;
    switch (s) {
      case VoiceSosState.listening:
        return '● Listening';
      case VoiceSosState.detected:
        return '⚠️ Keyword!';
      default:
        return VoiceSosService.instance.isEnabled ? 'Active' : 'Tap to enable';
    }
  }

  String get _shakeStatus {
    final s = ShakeSosService.instance.state;
    switch (s) {
      case ShakeSosState.detecting:
        return '● Monitoring 24/7';
      case ShakeSosState.candidate:
        return '⚠️ Analyzing...';
      case ShakeSosState.triggered:
        return '🚨 SOS Fired!';
      case ShakeSosState.cooldown:
        return '⏱ Cooldown';
      default:
        return ShakeSosService.instance.isEnabled ? 'Active' : 'Disabled';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _AdvCard(
              emoji: '👮',
              title: 'Police Stations',
              sub: 'Nearest real stations',
              color: const Color(0xFF1A237E),
              gradient: const LinearGradient(
                colors: [Color(0xFF1A237E), Color(0xFF283593)],
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PoliceStationsScreen()),
              ),
            ),
            const SizedBox(width: 10),
            _AdvCard(
              emoji: '🎙️',
              title: 'Voice SOS',
              sub: _voiceStatus,
              color: AppColors.primary,
              gradient: AppColors.primaryGradient,
              onTap: () =>
                  Navigator.pushNamed(context, AppRouter.settings),
              trailing: _VoiceToggle(),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _AdvCard(
              emoji: '🔊',
              title: 'Hardware SOS',
              sub: 'Vol button · Earphone',
              color: AppColors.secondary,
              gradient: LinearGradient(
                colors: [AppColors.secondary, AppColors.secondaryDark],
              ),
              onTap: () =>
                  Navigator.pushNamed(context, AppRouter.settings),
              trailing: _HardwareToggle(),
            ),
            const SizedBox(width: 10),
            _AdvCard(
              emoji: '📳',
              title: 'Shake SOS',
              sub: _shakeStatus,
              color: const Color(0xFF00897B),
              gradient: const LinearGradient(
                colors: [Color(0xFF00897B), Color(0xFF00695C)],
              ),
              onTap: () =>
                  Navigator.pushNamed(context, AppRouter.settings),
              trailing: _ShakeToggle(),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _AdvCard(
              emoji: '🔐',
              title: 'Decoy PIN',
              sub: 'Fake calculator escape',
              color: const Color(0xFF4A148C),
              gradient: const LinearGradient(
                colors: [Color(0xFF4A148C), Color(0xFF6A1B9A)],
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const DecoyPinSetupScreen()),
              ),
            ),
            const SizedBox(width: 10),
            _AdvCard(
              emoji: '📄',
              title: 'Evidence PDF',
              sub: 'Export court-ready report',
              color: AppColors.primary,
              gradient: AppColors.primaryGradient,
              onTap: () =>
                  Navigator.pushNamed(context, AppRouter.incidents),
            ),
          ],
        ),
      ],
    );
  }
}

class _AdvCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String sub;
  final Color color;
  final LinearGradient gradient;
  final VoidCallback onTap;
  final Widget? trailing;

  const _AdvCard({
    required this.emoji,
    required this.title,
    required this.sub,
    required this.color,
    required this.gradient,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.28),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 24)),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                sub,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontFamily: 'Poppins',
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: VoiceSosService.instance,
      builder: (_, __) => Transform.scale(
        scale: 0.72,
        child: Switch.adaptive(
          value: VoiceSosService.instance.isEnabled,
          activeColor: AppColors.primary,
          onChanged: (v) => VoiceSosService.instance.setEnabled(v),
        ),
      ),
    );
  }
}

class _HardwareToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: HardwareSosService.instance,
      builder: (_, __) => Transform.scale(
        scale: 0.72,
        child: Switch.adaptive(
          value: HardwareSosService.instance.isEnabled,
          activeColor: AppColors.secondary,
          onChanged: (v) => HardwareSosService.instance.setEnabled(v),
        ),
      ),
    );
  }
}

class _ShakeToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ShakeSosService.instance,
      builder: (_, __) => Transform.scale(
        scale: 0.72,
        child: Switch.adaptive(
          value: ShakeSosService.instance.isEnabled,
          activeColor: const Color(0xFF00897B),
          onChanged: (v) => ShakeSosService.instance.setEnabled(v),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// COMMUNITY SAFETY CARD
// ═══════════════════════════════════════════════════════════════════════

class _CommunitySafetyCard extends StatelessWidget {
  final MLDangerResult ml;
  const _CommunitySafetyCard({required this.ml});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CommunityService.instance,
      builder: (_, __) {
        final svc = CommunityService.instance;
        final stats = svc.stats;
        final score = stats?.safetysScore ?? 100;
        final active = stats?.activeReports ?? 0;
        final safeColor = score >= 70
            ? AppColors.safeGreen
            : score >= 40
            ? AppColors.warningAmber
            : AppColors.sosRed;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      safeColor.withValues(alpha: 0.80),
                      safeColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Area Safety Score',
                            style: TextStyle(
                              color: Colors.white70,
                              fontFamily: 'Poppins',
                              fontSize: 11,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '${score.toInt()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w900,
                                  fontSize: 32,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                score >= 70
                                    ? 'SAFE ✅'
                                    : score >= 40
                                    ? 'MODERATE ⚠️'
                                    : 'DANGER 🚨',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '$active',
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                        const Text(
                          'Active\nAlerts',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontFamily: 'Poppins',
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: _CommunityBtn(
                        painter: _MapIconPainter(color: AppColors.secondary),
                        label: 'View Danger Map',
                        color: AppColors.secondary,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CommunityMapScreen()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CommunityBtn(
                        painter: _PinAddPainter(color: AppColors.sosRed),
                        label: 'Report Danger',
                        color: AppColors.sosRed,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ReportDangerScreen()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (svc.highRisk.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.sosRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.sosRed.withValues(alpha: 0.20),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text('🚨', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${svc.highRisk.length} verified high-risk zones nearby.',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: AppColors.sosRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CommunityBtn extends StatelessWidget {
  final CustomPainter painter;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _CommunityBtn({
    required this.painter,
    required this.label,
    required this.color,
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomPaint(size: const Size(14, 14), painter: painter),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// INCIDENTS SECTION
// ═══════════════════════════════════════════════════════════════════════

class _IncidentsSection extends StatelessWidget {
  final SosProvider sos;
  const _IncidentsSection({required this.sos});

  @override
  Widget build(BuildContext context) {
    if (sos.incidents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
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
                  const Text(
                    'No incidents recorded',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'AI is actively monitoring your safety.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.40),
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
          'resolved' => AppColors.safeGreen,
          'false_alarm' => AppColors.warningAmber,
          _ => AppColors.sosRed,
        };
        final d = DateTime.now().difference(e.triggeredAt);
        final ago =
        d.inMinutes < 60 ? '${d.inMinutes}m ago' : '${d.inHours}h ago';

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IncidentDetailScreen(incidentId: e.id),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.withValues(alpha: 0.15), width: 1),
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
                      painter: _EmergencyIconPainter(color: c),
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
                          'manual' => 'Manual SOS',
                          'shake' => '📳 Shake SOS',
                          'silent' => 'Silent SOS',
                          'voice' => '🎙️ Voice SOS',
                          'hardware' => '🔊 Hardware SOS',
                          _ => '🤖 Auto AI SOS',
                        },
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${e.lat.toStringAsFixed(4)}, ${e.lng.toStringAsFixed(4)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.38),
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
                        color: c.withValues(alpha: 0.12),
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
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 10,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                CustomPaint(
                  size: const Size(16, 16),
                  painter: _PdfIconPainter(
                    color: AppColors.primary.withValues(alpha: 0.50),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SAFEHER DRAWER
// ═══════════════════════════════════════════════════════════════════════

class SafeHerDrawer extends StatelessWidget {
  const SafeHerDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final contacts = context.watch<ContactProvider>();
    final sos = context.watch<SosProvider>();
    final location = context.watch<LocationProvider>();
    final name = auth.user?.name ?? 'User';

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.82,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0A1A), Color(0xFF12122A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _DrawerHeader(
                name: name,
                email: auth.user?.email ?? auth.user?.phone ?? '',
                guardians: contacts.activeCount,
                incidents: sos.incidents.length,
                isTracking: location.isSharing,
                onClose: () => Navigator.pop(context),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DrawerSection('NAVIGATE'),
                      const SizedBox(height: 8),
                      _DrawerTile(
                        painter: _HomeIconPainter(color: AppColors.primary),
                        label: 'Home',
                        color: AppColors.primary,
                        onTap: () => Navigator.pop(context),
                      ),
                      _DrawerTile(
                        painter:
                        _HistoryIconPainter(color: AppColors.secondary),
                        label: 'Incident History',
                        color: AppColors.secondary,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRouter.incidents);
                        },
                      ),
                      _DrawerTile(
                        painter:
                        _PeopleIconPainter(color: AppColors.safeGreen),
                        label: 'Emergency Contacts',
                        color: AppColors.safeGreen,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRouter.contacts);
                        },
                      ),
                      _DrawerTile(
                        painter: _MapIconPainter(color: AppColors.secondary),
                        label: 'Location & Journey',
                        color: AppColors.secondary,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRouter.location);
                        },
                      ),
                      const SizedBox(height: 14),
                      _DrawerSection('SAFETY'),
                      const SizedBox(height: 8),
                      _DrawerTile(
                        painter: _HospitalIconPainter(
                            color: const Color(0xFF1976D2)),
                        label: 'Nearest Safety Places',
                        color: const Color(0xFF1976D2),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(
                              context, AppRouter.nearestSafetyPlaces);
                        },
                      ),
                      _DrawerTile(
                        painter: _PoliceIconPainter(
                            color: const Color(0xFF1A237E)),
                        label: 'Police Stations',
                        color: const Color(0xFF1A237E),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                  const PoliceStationsScreen()));
                        },
                      ),
                      _DrawerTile(
                        painter: _PhoneIconPainter(
                            color: const Color(0xFF7B1FA2)),
                        label: 'Fake Call Escape',
                        color: const Color(0xFF7B1FA2),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRouter.fakeCall);
                        },
                      ),
                      _DrawerTile(
                        painter:
                        _MapIconPainter(color: AppColors.safeGreen),
                        label: 'Community Danger Map',
                        color: AppColors.safeGreen,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                  const CommunityMapScreen()));
                        },
                      ),
                      const SizedBox(height: 14),
                      _DrawerSection('PROTECTION'),
                      const SizedBox(height: 8),
                      _DrawerTile(
                        painter: _VibrateIconPainter(
                            color: const Color(0xFF00897B)),
                        label: 'Shake SOS (5-Layer AI)',
                        color: const Color(0xFF00897B),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRouter.settings);
                        },
                      ),
                      _DrawerTile(
                        painter: _MicIconPainter(color: AppColors.primary),
                        label: 'Voice SOS Settings',
                        color: AppColors.primary,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRouter.settings);
                        },
                      ),
                      _DrawerTile(
                        painter: _CalcIconPainter(
                            color: const Color(0xFF4A148C)),
                        label: 'Decoy PIN Setup',
                        color: const Color(0xFF4A148C),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                  const DecoyPinSetupScreen()));
                        },
                      ),
                      const SizedBox(height: 14),
                      _DrawerSection('ACCOUNT'),
                      const SizedBox(height: 8),
                      _DrawerTile(
                        painter: _BellIconPainter(
                            color: AppColors.warningAmber),
                        label: 'Notifications',
                        color: AppColors.warningAmber,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                  const NotificationsScreen()));
                        },
                      ),
                      _DrawerTile(
                        painter:
                        _SettingsIconPainter(color: AppColors.primary),
                        label: 'Settings',
                        color: AppColors.primary,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRouter.settings);
                        },
                      ),
                      _DrawerTile(
                        painter:
                        _LogoutIconPainter(color: AppColors.sosRed),
                        label: 'Sign Out',
                        color: AppColors.sosRed,
                        onTap: () async {
                          Navigator.pop(context);
                          await context.read<AuthProvider>().signOut();
                          if (context.mounted) {
                            Navigator.pushReplacementNamed(
                                context, AppRouter.login);
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Column(
                          children: [
                            GestureDetector(
                              onLongPress: () {
                                Navigator.pop(context); // Close the drawer first
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const PoliceDashboardScreen()),
                                );
                              },
                              child: ShaderMask(
                                shaderCallback: (b) =>
                                    AppColors.primaryGradient.createShader(b),
                                blendMode: BlendMode.srcIn,
                                child: const Text(
                                  'SafeHer v2.0',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'VJIT Hyderabad · AI-Powered Safety',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.30),
                                fontSize: 10,
                                fontFamily: 'Poppins',
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
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  final String name;
  final String email;
  final int guardians;
  final int incidents;
  final bool isTracking;
  final VoidCallback onClose;

  const _DrawerHeader({
    required this.name,
    required this.email,
    required this.guardians,
    required this.incidents,
    required this.isTracking,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.only(topRight: Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CustomPaint(
                    size: const Size(20, 20),
                    painter: _ShieldSmallPainter(),
                  ),
                  const SizedBox(width: 7),
                  const Text(
                    'SafeHer',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      fontFamily: 'Poppins',
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
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  child: Center(
                    child: CustomPaint(
                      size: const Size(14, 14),
                      painter: _CloseIconPainter(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.50),
                    width: 2,
                  ),
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 11,
                        fontFamily: 'Poppins',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.safeGreen.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '🛡️ Protected',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _DrawerStat('$guardians', 'Guardians'),
              const SizedBox(width: 8),
              _DrawerStat('$incidents', 'Incidents'),
              const SizedBox(width: 8),
              _DrawerStat(isTracking ? 'LIVE' : 'OFF', 'Tracking'),
            ],
          ),
        ],
      ),
    );
  }
}

class _DrawerStat extends StatelessWidget {
  final String value;
  final String label;
  const _DrawerStat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                fontFamily: 'Poppins',
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.70),
                fontSize: 9,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  final String title;
  const _DrawerSection(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.35),
        fontSize: 10,
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final CustomPainter painter;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.painter,
    required this.label,
    required this.color,
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
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(17, 17),
                  painter: painter,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: label == 'Sign Out'
                      ? AppColors.sosRed
                      : Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
            CustomPaint(
              size: const Size(10, 10),
              painter: _ChevronRightPainter(
                color: Colors.white.withValues(alpha: 0.22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// DECOY PIN SETUP SCREEN
// ═══════════════════════════════════════════════════════════════════════

class DecoyPinSetupScreen extends StatefulWidget {
  const DecoyPinSetupScreen({super.key});

  @override
  State<DecoyPinSetupScreen> createState() => _DecoyPinSetupScreenState();
}

class _DecoyPinSetupScreenState extends State<DecoyPinSetupScreen>
    with TickerProviderStateMixin {
  int _step = 0;
  String _realPin = '';
  String _decoyPin = '';
  String _panicPin = '';
  String _currentPin = '';
  String _error = '';
  bool _saving = false;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  static const _stepTitles = [
    'Set Real PIN',
    'Confirm Real PIN',
    'Set Decoy PIN',
    'Set Panic PIN\n(Optional)',
  ];
  static const _stepSubs = [
    'This PIN opens SafeHer. Keep it secret.',
    'Enter your real PIN again to confirm.',
    'This PIN opens a fake calculator.\nUse when forced to unlock.',
    'This PIN triggers silent SOS first,\nthen shows fake app.',
  ];

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onDigit(String d) {
    if (_currentPin.length >= 6) return;
    setState(() {
      _currentPin += d;
      _error = '';
    });
    if (_currentPin.length == 4) _onPinComplete();
  }

  void _onDelete() {
    if (_currentPin.isEmpty) return;
    setState(
            () => _currentPin = _currentPin.substring(0, _currentPin.length - 1));
  }

  void _onPinComplete() async {
    await Future.delayed(const Duration(milliseconds: 200));
    switch (_step) {
      case 0:
        if (_currentPin.length < 4) {
          _showError('Min 4 digits');
          return;
        }
        setState(() {
          _realPin = _currentPin;
          _currentPin = '';
          _step = 1;
        });
        break;
      case 1:
        if (_currentPin != _realPin) {
          _showError('PINs do not match');
        } else {
          setState(() {
            _currentPin = '';
            _step = 2;
          });
        }
        break;
      case 2:
        if (_currentPin == _realPin) {
          _showError('Must differ from real PIN');
        } else {
          setState(() {
            _decoyPin = _currentPin;
            _currentPin = '';
            _step = 3;
          });
        }
        break;
      case 3:
        if (_currentPin == _realPin || _currentPin == _decoyPin) {
          _showError('Must differ from other PINs');
        } else {
          setState(() => _panicPin = _currentPin);
          await _saveAndFinish();
        }
        break;
    }
  }

  void _showError(String msg) {
    setState(() {
      _error = msg;
      _currentPin = '';
    });
    _shakeCtrl.forward(from: 0);
  }

  Future<void> _skipPanicPin() async {
    setState(() => _panicPin = '');
    await _saveAndFinish();
  }

  Future<void> _saveAndFinish() async {
    setState(() => _saving = true);
    final ok = await DecoyService.instance.setupPins(
      realPin: _realPin,
      decoyPin: _decoyPin,
      panicPin: _panicPin.isEmpty ? null : _panicPin,
    );
    setState(() => _saving = false);
    if (ok && mounted) {
      setState(() => _step = 4);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context, true);
    } else {
      _showError('Setup failed. Try again.');
      setState(() {
        _step = 0;
        _currentPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: CustomPaint(
                size: const Size(16, 16),
                painter: _BackArrowPainter(),
              ),
            ),
          ),
        ),
        title: const Text(
          'Decoy Protection',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: Colors.white,
          ),
        ),
      ),
      body: _step == 4 ? _buildSuccess() : _buildSetup(),
    );
  }

  Widget _buildSetup() {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_step + 1) / 4,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor:
                const AlwaysStoppedAnimation(AppColors.primary),
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Step ${_step + 1} of 4',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.40),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: AppColors.primaryShadow,
                    ),
                    child: Center(
                      child: CustomPaint(
                        size: const Size(38, 38),
                        painter: _stepPainter(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _stepTitles[_step],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _stepSubs[_step],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.45),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 36),
                  AnimatedBuilder(
                    animation: _shakeAnim,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(
                        8 *
                            (0.5 - _shakeAnim.value).abs() *
                            (_shakeAnim.value > 0.5 ? 1 : -1),
                        0,
                      ),
                      child: child,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (i) {
                        final filled = i < _currentPin.length;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin:
                          const EdgeInsets.symmetric(horizontal: 6),
                          width: filled ? 18 : 16,
                          height: filled ? 18 : 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: filled
                                ? AppColors.primary
                                : Colors.white.withValues(alpha: 0.20),
                            boxShadow: filled
                                ? [
                              BoxShadow(
                                color: AppColors.primary
                                    .withValues(alpha: 0.40),
                                blurRadius: 8,
                              ),
                            ]
                                : [],
                          ),
                        );
                      }),
                    ),
                  ),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.sosRed.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _error,
                        style: const TextStyle(
                          color: AppColors.sosRed,
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 36),
                  _buildNumpad(),
                  if (_step == 3) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _skipPanicPin,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'Skip Panic PIN',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.50),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_saving) ...[
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(color: AppColors.primary),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumpad() {
    return Column(
      children: [
        _numRow(['1', '2', '3']),
        const SizedBox(height: 12),
        _numRow(['4', '5', '6']),
        const SizedBox(height: 12),
        _numRow(['7', '8', '9']),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 72 + 12),
            _numBtn('0'),
            const SizedBox(width: 12),
            _deleteBtn(),
          ],
        ),
      ],
    );
  }

  Widget _numRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits.asMap().entries.map((e) {
        return Padding(
          padding: EdgeInsets.only(left: e.key > 0 ? 12 : 0),
          child: _numBtn(e.value),
        );
      }).toList(),
    );
  }

  Widget _numBtn(String d) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _onDigit(d);
      },
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            d,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 26,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _deleteBtn() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _onDelete();
      },
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.sosRed.withValues(alpha: 0.08),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.sosRed.withValues(alpha: 0.20),
            width: 1,
          ),
        ),
        child: Center(
          child: CustomPaint(
            size: const Size(24, 24),
            painter: _BackspaceIconPainter(),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: AppColors.safeGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.safeGreen.withValues(alpha: 0.40),
                  blurRadius: 30,
                ),
              ],
            ),
            child: Center(
              child: CustomPaint(
                size: const Size(48, 48),
                painter: _CheckLargePainter(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Decoy Protection Active! 🛡️',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Enter decoy PIN → fake calculator\nEnter real PIN → SafeHer opens',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.45),
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  CustomPainter _stepPainter() {
    switch (_step) {
      case 0:
        return _LockIconPainter();
      case 1:
        return _LockResetPainter();
      case 2:
        return _CalcIconPainter(color: Colors.white);
      default:
        return _WarningIconPainter();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// HELPER — ColoredPainter wrapper
// ═══════════════════════════════════════════════════════════════════════

class _ColoredPainter extends CustomPainter {
  final CustomPainter painter;
  final Color color;
  const _ColoredPainter({required this.painter, required this.color});

  @override
  void paint(Canvas canvas, Size size) => painter.paint(canvas, size);

  @override
  bool shouldRepaint(_ColoredPainter old) =>
      old.color != color || old.painter != painter;
}

// ═══════════════════════════════════════════════════════════════════════
// ALL CUSTOM PAINTERS
// ═══════════════════════════════════════════════════════════════════════

class _HamburgerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, 0), Offset(s.width, 0), p);
    canvas.drawLine(Offset(s.width * 0.15, s.height / 2),
        Offset(s.width, s.height / 2), p);
    canvas.drawLine(Offset(0, s.height), Offset(s.width, s.height), p);
  }

  @override
  bool shouldRepaint(_HamburgerPainter o) => false;
}

class _SosIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(
        Offset(s.width / 2, s.height / 2), s.width * 0.44, p);
    final tp = TextPainter(
      text: const TextSpan(
        text: 'SOS',
        style: TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          fontFamily: 'Poppins',
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        Offset(s.width / 2 - tp.width / 2, s.height / 2 - tp.height / 2));
  }

  @override
  bool shouldRepaint(_SosIconPainter o) => false;
}

class _WarningIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final path = Path();
    path.moveTo(cx, 0);
    path.lineTo(s.width, s.height);
    path.lineTo(0, s.height);
    path.close();
    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.20)
          ..style = PaintingStyle.fill);
    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeJoin = StrokeJoin.round);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - 2, s.height * 0.30, 4, s.height * 0.30),
            const Radius.circular(2)),
        Paint()..color = Colors.white);
    canvas.drawCircle(
        Offset(cx, s.height * 0.78), 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_WarningIconPainter o) => false;
}

class _HomeIconPainter extends CustomPainter {
  final Color color;
  const _HomeIconPainter({this.color = Colors.white});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final roof = Path();
    roof.moveTo(0, s.height * 0.50);
    roof.lineTo(s.width * 0.50, 0);
    roof.lineTo(s.width, s.height * 0.50);
    canvas.drawPath(roof, p);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(s.width * 0.18, s.height * 0.50, s.width * 0.64,
                s.height * 0.46),
            const Radius.circular(2)),
        p);
    canvas.drawRect(
        Rect.fromLTWH(s.width * 0.38, s.height * 0.68, s.width * 0.24,
            s.height * 0.28),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4);
  }

  @override
  bool shouldRepaint(_HomeIconPainter o) => o.color != color;
}

class _MapIconPainter extends CustomPainter {
  final Color color;
  const _MapIconPainter({this.color = Colors.white});

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
    path.cubicTo(
        s.width * 0.18, 0, 0, s.height * 0.26, 0, s.height * 0.46);
    path.cubicTo(0, s.height * 0.66, s.width * 0.18, s.height * 0.80,
        s.width * 0.50, s.height);
    path.cubicTo(s.width * 0.82, s.height * 0.80, s.width, s.height * 0.66,
        s.width, s.height * 0.46);
    path.cubicTo(s.width, s.height * 0.26, s.width * 0.82, 0,
        s.width * 0.50, 0);
    path.close();
    canvas.drawPath(path, p);
    canvas.drawCircle(Offset(s.width / 2, s.height * 0.44), s.width * 0.15,
        Paint()..color = color);
  }

  @override
  bool shouldRepaint(_MapIconPainter o) => o.color != color;
}

class _PeopleIconPainter extends CustomPainter {
  final Color color;
  const _PeopleIconPainter({this.color = Colors.white});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(
        Offset(s.width * 0.36, s.height * 0.28), s.width * 0.16, p);
    final b = Path();
    b.moveTo(0, s.height);
    b.quadraticBezierTo(
        0, s.height * 0.60, s.width * 0.36, s.height * 0.60);
    b.quadraticBezierTo(
        s.width * 0.68, s.height * 0.60, s.width * 0.68, s.height);
    canvas.drawPath(b, p);
    canvas.drawCircle(
        Offset(s.width * 0.76, s.height * 0.22),
        s.width * 0.13,
        Paint()
          ..color = color.withValues(alpha: 0.60)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
  }

  @override
  bool shouldRepaint(_PeopleIconPainter o) => o.color != color;
}

class _BellIconPainter extends CustomPainter {
  final Color color;
  const _BellIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final bell = Path();
    bell.moveTo(s.width * 0.20, s.height * 0.72);
    bell.lineTo(s.width * 0.12, s.height * 0.72);
    bell.quadraticBezierTo(
        s.width * 0.12, s.height * 0.60, s.width * 0.20, s.height * 0.55);
    bell.quadraticBezierTo(
        s.width * 0.20, s.height * 0.20, s.width * 0.50, s.height * 0.20);
    bell.quadraticBezierTo(
        s.width * 0.80, s.height * 0.20, s.width * 0.80, s.height * 0.55);
    bell.lineTo(s.width * 0.88, s.height * 0.60);
    bell.quadraticBezierTo(
        s.width * 0.88, s.height * 0.72, s.width * 0.80, s.height * 0.72);
    bell.close();
    canvas.drawPath(bell, p);
    canvas.drawLine(Offset(s.width * 0.38, s.height * 0.72),
        Offset(s.width * 0.62, s.height * 0.72), p);
    canvas.drawArc(
        Rect.fromCenter(
            center: Offset(s.width * 0.50, s.height * 0.86),
            width: s.width * 0.24,
            height: s.height * 0.24),
        0,
        math.pi,
        false,
        p);
    canvas.drawLine(Offset(s.width * 0.44, 0), Offset(s.width * 0.56, 0),
        Paint()
          ..color = color
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_BellIconPainter o) => o.color != color;
}

class _BoltIconPainter extends CustomPainter {
  final Color color;
  const _BoltIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final path = Path();
    path.moveTo(s.width * 0.62, 0);
    path.lineTo(s.width * 0.28, s.height * 0.50);
    path.lineTo(s.width * 0.55, s.height * 0.50);
    path.lineTo(s.width * 0.38, s.height);
    path.lineTo(s.width * 0.72, s.height * 0.50);
    path.lineTo(s.width * 0.45, s.height * 0.50);
    path.close();
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_BoltIconPainter o) => o.color != color;
}

class _ShieldIconPainter extends CustomPainter {
  final Color color;
  const _ShieldIconPainter({required this.color});

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
    canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill);
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeJoin = StrokeJoin.round);
    final check = Path();
    check.moveTo(s.width * 0.28, s.height * 0.52);
    check.lineTo(s.width * 0.44, s.height * 0.68);
    check.lineTo(s.width * 0.72, s.height * 0.36);
    canvas.drawPath(
        check,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_ShieldIconPainter o) => o.color != color;
}

class _LockShieldPainter extends CustomPainter {
  final Color color;
  const _LockShieldPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
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
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(s.width * 0.32, s.height * 0.44, s.width * 0.36,
                s.height * 0.30),
            const Radius.circular(3)),
        p);
    final arc = Path();
    arc.moveTo(s.width * 0.36, s.height * 0.44);
    arc.lineTo(s.width * 0.36, s.height * 0.34);
    arc.quadraticBezierTo(s.width * 0.36, s.height * 0.22,
        s.width * 0.50, s.height * 0.22);
    arc.quadraticBezierTo(s.width * 0.64, s.height * 0.22,
        s.width * 0.64, s.height * 0.34);
    arc.lineTo(s.width * 0.64, s.height * 0.44);
    canvas.drawPath(arc, p);
  }

  @override
  bool shouldRepaint(_LockShieldPainter o) => o.color != color;
}

class _LocationPinPainter extends CustomPainter {
  final Color color;
  const _LocationPinPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path();
    path.moveTo(s.width * 0.50, 0);
    path.cubicTo(
        s.width * 0.18, 0, 0, s.height * 0.26, 0, s.height * 0.46);
    path.cubicTo(0, s.height * 0.66, s.width * 0.18, s.height * 0.80,
        s.width * 0.50, s.height);
    path.cubicTo(s.width * 0.82, s.height * 0.80, s.width, s.height * 0.66,
        s.width, s.height * 0.46);
    path.cubicTo(s.width, s.height * 0.26, s.width * 0.82, 0,
        s.width * 0.50, 0);
    path.close();
    canvas.drawPath(path, p);
    canvas.drawCircle(Offset(s.width / 2, s.height * 0.44), s.width * 0.16,
        Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LocationPinPainter o) => o.color != color;
}

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
    canvas.drawCircle(
        Offset(s.width / 2, s.height / 2), s.width * 0.44, p);
    canvas.drawLine(Offset(s.width / 2, s.height * 0.26),
        Offset(s.width / 2, s.height / 2), p);
    canvas.drawLine(Offset(s.width / 2, s.height / 2),
        Offset(s.width * 0.68, s.height / 2), p);
  }

  @override
  bool shouldRepaint(_HistoryIconPainter o) => o.color != color;
}

class _AnalyticsIconPainter extends CustomPainter {
  final Color color;
  const _AnalyticsIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final bars = [0.40, 0.72, 0.55, 0.88, 0.62];
    final barW = s.width / (bars.length * 2);
    for (int i = 0; i < bars.length; i++) {
      final x = barW * (i * 2 + 0.5);
      canvas.drawLine(
          Offset(x, s.height),
          Offset(x, s.height * (1 - bars[i])),
          Paint()
            ..color = color
            ..strokeWidth = barW * 1.4
            ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_AnalyticsIconPainter o) => o.color != color;
}

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
            Rect.fromLTWH(
                s.width * 0.30, 0, s.width * 0.40, s.height * 0.58),
            Radius.circular(s.width * 0.20)),
        p);
    canvas.drawArc(
        Rect.fromLTWH(s.width * 0.12, s.height * 0.30, s.width * 0.76,
            s.height * 0.50),
        0,
        math.pi,
        false,
        p);
    canvas.drawLine(Offset(s.width * 0.50, s.height * 0.80),
        Offset(s.width * 0.50, s.height), p);
    canvas.drawLine(Offset(s.width * 0.30, s.height),
        Offset(s.width * 0.70, s.height), p);
  }

  @override
  bool shouldRepaint(_MicIconPainter o) => o.color != color;
}

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
            Rect.fromLTWH(s.width * 0.28, s.height * 0.12, s.width * 0.44,
                s.height * 0.76),
            const Radius.circular(4)),
        p);
    for (final x in [s.width * 0.08, s.width * 0.84]) {
      canvas.drawLine(
          Offset(x, s.height * 0.30), Offset(x, s.height * 0.70), p);
    }
  }

  @override
  bool shouldRepaint(_VibrateIconPainter o) => o.color != color;
}

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
    path.moveTo(s.width * 0.25, s.height * 0.18);
    path.lineTo(s.width * 0.70, s.height * 0.50);
    path.lineTo(s.width * 0.25, s.height * 0.82);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_ChevronRightPainter o) => o.color != color;
}

class _CheckCirclePainter extends CustomPainter {
  final Color color;
  const _CheckCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    final r = s.width * 0.46;
    canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..color = color.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill);
    canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4);
    final check = Path();
    check.moveTo(cx - r * 0.42, cy);
    check.lineTo(cx - r * 0.08, cy + r * 0.40);
    check.lineTo(cx + r * 0.42, cy - r * 0.36);
    canvas.drawPath(
        check,
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

class _EmergencyIconPainter extends CustomPainter {
  final Color color;
  const _EmergencyIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    canvas.drawCircle(
        Offset(cx, cy), s.width * 0.44, Paint()..color = color.withValues(alpha: 0.15));
    canvas.drawCircle(
        Offset(cx, cy),
        s.width * 0.44,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - 2.5, cy - s.height * 0.22, 5, s.height * 0.28),
            const Radius.circular(2)),
        Paint()..color = color);
    canvas.drawCircle(
        Offset(cx, cy + s.height * 0.14), 2.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_EmergencyIconPainter o) => o.color != color;
}

class _PdfIconPainter extends CustomPainter {
  final Color color;
  const _PdfIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(s.width * 0.20, 0);
    path.lineTo(s.width * 0.70, 0);
    path.lineTo(s.width, s.height * 0.30);
    path.lineTo(s.width, s.height);
    path.lineTo(s.width * 0.20, s.height);
    path.close();
    canvas.drawPath(path, p);
    for (int i = 0; i < 3; i++) {
      canvas.drawLine(
          Offset(s.width * 0.34, s.height * (0.44 + i * 0.16)),
          Offset(s.width * 0.80, s.height * (0.44 + i * 0.16)),
          Paint()
            ..color = color
            ..strokeWidth = 1.0
            ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_PdfIconPainter o) => o.color != color;
}

class _PinAddPainter extends CustomPainter {
  final Color color;
  const _PinAddPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final path = Path();
    path.moveTo(s.width * 0.36, 0);
    path.cubicTo(s.width * 0.14, 0, 0, s.height * 0.22, 0, s.height * 0.38);
    path.cubicTo(0, s.height * 0.56, s.width * 0.14, s.height * 0.68,
        s.width * 0.36, s.height * 0.80);
    path.cubicTo(s.width * 0.58, s.height * 0.68, s.width * 0.72,
        s.height * 0.56, s.width * 0.72, s.height * 0.38);
    path.cubicTo(s.width * 0.72, s.height * 0.22, s.width * 0.58, 0,
        s.width * 0.36, 0);
    path.close();
    canvas.drawPath(path, p);
    canvas.drawLine(Offset(s.width * 0.84, s.height * 0.36),
        Offset(s.width * 0.84, s.height * 0.76), p);
    canvas.drawLine(Offset(s.width * 0.64, s.height * 0.56),
        Offset(s.width * 1.04, s.height * 0.56), p);
  }

  @override
  bool shouldRepaint(_PinAddPainter o) => o.color != color;
}

class _ShieldSmallPainter extends CustomPainter {
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
    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.18)
          ..style = PaintingStyle.fill);
    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeJoin = StrokeJoin.round);
    final check = Path();
    check.moveTo(s.width * 0.28, s.height * 0.52);
    check.lineTo(s.width * 0.44, s.height * 0.68);
    check.lineTo(s.width * 0.72, s.height * 0.36);
    canvas.drawPath(
        check,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_ShieldSmallPainter o) => false;
}

class _CloseIconPainter extends CustomPainter {
  final Color color;
  const _CloseIconPainter({required this.color});

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
  bool shouldRepaint(_CloseIconPainter o) => o.color != color;
}

class _HospitalIconPainter extends CustomPainter {
  final Color color;
  const _HospitalIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, s.width, s.height), const Radius.circular(3)),
        p);
    canvas.drawLine(Offset(s.width * 0.50, s.height * 0.22),
        Offset(s.width * 0.50, s.height * 0.78), p);
    canvas.drawLine(Offset(s.width * 0.22, s.height * 0.50),
        Offset(s.width * 0.78, s.height * 0.50), p);
  }

  @override
  bool shouldRepaint(_HospitalIconPainter o) => o.color != color;
}

class _PoliceIconPainter extends CustomPainter {
  final Color color;
  const _PoliceIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(s.width * 0.50, 0);
    path.lineTo(s.width, s.height * 0.28);
    path.lineTo(s.width * 0.92, s.height * 0.76);
    path.lineTo(s.width * 0.50, s.height);
    path.lineTo(s.width * 0.08, s.height * 0.76);
    path.lineTo(0, s.height * 0.28);
    path.close();
    canvas.drawPath(path, p);
    canvas.drawCircle(Offset(s.width / 2, s.height * 0.50), s.width * 0.14,
        Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PoliceIconPainter o) => o.color != color;
}

class _PhoneIconPainter extends CustomPainter {
  final Color color;
  const _PhoneIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(s.width * 0.20, 0, s.width * 0.60, s.height),
            Radius.circular(s.width * 0.12)),
        p);
    canvas.drawCircle(Offset(s.width * 0.50, s.height * 0.84), s.width * 0.07,
        Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PhoneIconPainter o) => o.color != color;
}

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
            Rect.fromLTWH(0, 0, s.width, s.height), const Radius.circular(3)),
        p);
    canvas.drawRect(
        Rect.fromLTWH(s.width * 0.10, s.height * 0.10, s.width * 0.80,
            s.height * 0.24),
        Paint()
          ..color = color.withValues(alpha: 0.20)
          ..style = PaintingStyle.fill);
    final dp = Paint()..color = color;
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        canvas.drawCircle(
            Offset(s.width * (0.22 + col * 0.28),
                s.height * (0.54 + row * 0.16)),
            s.width * 0.05,
            dp);
      }
    }
  }

  @override
  bool shouldRepaint(_CalcIconPainter o) => o.color != color;
}

class _SettingsIconPainter extends CustomPainter {
  final Color color;
  const _SettingsIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(
        Offset(s.width / 2, s.height / 2), s.width * 0.24, p);
    const teeth = 8;
    for (int i = 0; i < teeth; i++) {
      final a = (i * 2 * math.pi / teeth);
      final inner = s.width * 0.34;
      final outer = s.width * 0.46;
      canvas.drawLine(
          Offset(s.width / 2 + inner * math.cos(a),
              s.height / 2 + inner * math.sin(a)),
          Offset(s.width / 2 + outer * math.cos(a),
              s.height / 2 + outer * math.sin(a)),
          Paint()
            ..color = color
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_SettingsIconPainter o) => o.color != color;
}

class _LogoutIconPainter extends CustomPainter {
  final Color color;
  const _LogoutIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
        Path()
          ..moveTo(s.width * 0.52, s.height * 0.10)
          ..lineTo(s.width * 0.16, s.height * 0.10)
          ..lineTo(s.width * 0.16, s.height * 0.90)
          ..lineTo(s.width * 0.52, s.height * 0.90),
        p);
    canvas.drawLine(Offset(s.width * 0.40, s.height / 2),
        Offset(s.width * 0.90, s.height / 2), p);
    final head = Path();
    head.moveTo(s.width * 0.68, s.height * 0.34);
    head.lineTo(s.width * 0.90, s.height * 0.50);
    head.lineTo(s.width * 0.68, s.height * 0.66);
    canvas.drawPath(head, p);
  }

  @override
  bool shouldRepaint(_LogoutIconPainter o) => o.color != color;
}

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
    final head = Path();
    head.moveTo(s.width * 0.45, cy - s.height * 0.28);
    head.lineTo(s.width * 0.20, cy);
    head.lineTo(s.width * 0.45, cy + s.height * 0.28);
    canvas.drawPath(head, p);
  }

  @override
  bool shouldRepaint(_BackArrowPainter o) => false;
}

class _BackspaceIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = AppColors.sosRed
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(s.width * 0.30, 0);
    path.lineTo(s.width, 0);
    path.lineTo(s.width, s.height);
    path.lineTo(s.width * 0.30, s.height);
    path.lineTo(0, s.height / 2);
    path.close();
    canvas.drawPath(path, p);
    canvas.drawLine(Offset(s.width * 0.52, s.height * 0.30),
        Offset(s.width * 0.78, s.height * 0.70), p);
    canvas.drawLine(Offset(s.width * 0.78, s.height * 0.30),
        Offset(s.width * 0.52, s.height * 0.70), p);
  }

  @override
  bool shouldRepaint(_BackspaceIconPainter o) => false;
}

class _LockIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(s.width * 0.10, s.height * 0.44, s.width * 0.80,
                s.height * 0.52),
            const Radius.circular(5)),
        p);
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
        Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_LockIconPainter o) => false;
}

class _LockResetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        Rect.fromLTWH(s.width * 0.12, s.height * 0.12, s.width * 0.76,
            s.height * 0.76),
        -math.pi * 0.4,
        math.pi * 1.8,
        false,
        p);
    final arrow = Path();
    arrow.moveTo(s.width * 0.82, s.height * 0.20);
    arrow.lineTo(s.width * 0.88, s.height * 0.10);
    arrow.moveTo(s.width * 0.82, s.height * 0.20);
    arrow.lineTo(s.width * 0.72, s.height * 0.16);
    canvas.drawPath(arrow, p);
    canvas.drawCircle(Offset(s.width / 2, s.height / 2), s.width * 0.14,
        Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_LockResetPainter o) => false;
}

class _CheckLargePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(s.width * 0.18, s.height * 0.52);
    path.lineTo(s.width * 0.42, s.height * 0.74);
    path.lineTo(s.width * 0.82, s.height * 0.28);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_CheckLargePainter o) => false;
}