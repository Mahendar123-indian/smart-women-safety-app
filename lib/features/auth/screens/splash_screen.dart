// lib/features/auth/screens/splash_screen.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // ── Master sequence controller ────────────────────────────────
  late AnimationController _masterCtrl;

  // ── Orbital ring controllers ──────────────────────────────────
  late AnimationController _orbit1Ctrl;
  late AnimationController _orbit2Ctrl;
  late AnimationController _orbit3Ctrl;

  // ── Pulse glow ────────────────────────────────────────────────
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  // ── Progress ──────────────────────────────────────────────────
  late AnimationController _progressCtrl;
  late Animation<double> _progressAnim;

  // ── Content fade/slide animations ────────────────────────────
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _titleSlide;
  late Animation<double> _titleOpacity;
  late Animation<Offset> _taglineSlide;
  late Animation<double> _taglineOpacity;
  late Animation<double> _progressOpacity;
  late Animation<double> _badgeOpacity;

  // ── Floating particle controller ──────────────────────────────
  late AnimationController _particleCtrl;

  static const _totalDuration = Duration(milliseconds: 3200);

  @override
  void initState() {
    super.initState();

    // Master (drives entry animations)
    _masterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Orbital rings — different speeds for depth
    _orbit1Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();
    _orbit2Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9000),
    )..repeat(reverse: false);
    _orbit3Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 13000),
    )..repeat(reverse: false);

    // Glow pulse
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    // Progress
    _progressCtrl = AnimationController(
      vsync: this,
      duration: _totalDuration,
    )..forward();
    _progressAnim = CurvedAnimation(
      parent: _progressCtrl,
      curve: Curves.easeInOut,
    );

    // Particles
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);

    // ── Entry sequence ─────────────────────────────────────────
    _logoScale = TweenSequence([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.0, 0.55),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.35, 0.65, curve: Curves.easeOut),
      ),
    );
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.35, 0.65),
      ),
    );

    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.50, 0.75, curve: Curves.easeOut),
      ),
    );
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.50, 0.75),
      ),
    );

    _progressOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.65, 0.85),
      ),
    );

    _badgeOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.75, 1.0),
      ),
    );

    _masterCtrl.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(_totalDuration);
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    await Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      return authProvider.status == AuthStatus.initial ||
          authProvider.status == AuthStatus.loading;
    });

    if (!mounted) return;

    if (authProvider.isAuthenticated) {
      Navigator.pushReplacementNamed(context, AppRouter.home);
    } else {
      Navigator.pushReplacementNamed(context, AppRouter.onboarding);
    }
  }

  @override
  void dispose() {
    _masterCtrl.dispose();
    _orbit1Ctrl.dispose();
    _orbit2Ctrl.dispose();
    _orbit3Ctrl.dispose();
    _glowCtrl.dispose();
    _progressCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          // ── Deep space background ────────────────────────────
          _buildBackground(size),

          // ── Floating particles ───────────────────────────────
          ..._buildParticles(size),

          // ── Main content ─────────────────────────────────────
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLogoSection(),
                const SizedBox(height: 40),
                _buildTitleSection(),
                const SizedBox(height: 12),
                _buildTagline(),
                const SizedBox(height: 20),
                _buildBadges(),
                const SizedBox(height: 56),
                _buildProgress(),
              ],
            ),
          ),

          // ── Bottom version tag ───────────────────────────────
          _buildVersionTag(),
        ],
      ),
    );
  }

  // ── Background with mesh blobs ────────────────────────────────
  Widget _buildBackground(Size size) {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, __) => Stack(
        children: [
          // Top-right primary blob
          Positioned(
            top: -size.height * 0.12,
            right: -size.width * 0.2,
            child: Container(
              width: size.width * 0.75,
              height: size.width * 0.75,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary
                        .withValues(alpha: 0.18 * _glowAnim.value),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Bottom-left secondary blob
          Positioned(
            bottom: -size.height * 0.1,
            left: -size.width * 0.25,
            child: Container(
              width: size.width * 0.8,
              height: size.width * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.secondary
                        .withValues(alpha: 0.13 * _glowAnim.value),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Center subtle glow
          Positioned(
            top: size.height * 0.3,
            left: size.width * 0.1,
            child: Container(
              width: size.width * 0.8,
              height: size.height * 0.4,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary
                        .withValues(alpha: 0.06 * _glowAnim.value),
                    Colors.transparent,
                  ],
                  radius: 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Logo with orbital rings ───────────────────────────────────
  Widget _buildLogoSection() {
    return AnimatedBuilder(
      animation: _logoOpacity,
      builder: (_, __) => Opacity(
        opacity: _logoOpacity.value,
        child: Transform.scale(
          scale: _logoScale.value,
          child: SizedBox(
            width: 220,
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Orbit ring 3 — outermost, slowest
                AnimatedBuilder(
                  animation: _orbit3Ctrl,
                  builder: (_, __) => Transform.rotate(
                    angle: _orbit3Ctrl.value * 2 * math.pi,
                    child: CustomPaint(
                      size: const Size(210, 210),
                      painter: _OrbitRingPainter(
                        dotColor: AppColors.secondary
                            .withValues(alpha: 0.7),
                        ringColor: AppColors.secondary
                            .withValues(alpha: 0.08),
                        dotCount: 3,
                        dotSize: 3.5,
                        strokeWidth: 0.8,
                      ),
                    ),
                  ),
                ),

                // Orbit ring 2 — middle
                AnimatedBuilder(
                  animation: _orbit2Ctrl,
                  builder: (_, __) => Transform.rotate(
                    angle: -_orbit2Ctrl.value * 2 * math.pi,
                    child: CustomPaint(
                      size: const Size(168, 168),
                      painter: _OrbitRingPainter(
                        dotColor: AppColors.primary
                            .withValues(alpha: 0.8),
                        ringColor: AppColors.primary
                            .withValues(alpha: 0.10),
                        dotCount: 2,
                        dotSize: 4.5,
                        strokeWidth: 1.0,
                      ),
                    ),
                  ),
                ),

                // Orbit ring 1 — inner, fastest
                AnimatedBuilder(
                  animation: _orbit1Ctrl,
                  builder: (_, __) => Transform.rotate(
                    angle: _orbit1Ctrl.value * 2 * math.pi,
                    child: CustomPaint(
                      size: const Size(126, 126),
                      painter: _OrbitRingPainter(
                        dotColor: Colors.white.withValues(alpha: 0.9),
                        ringColor: Colors.white.withValues(alpha: 0.06),
                        dotCount: 4,
                        dotSize: 3.0,
                        strokeWidth: 0.6,
                      ),
                    ),
                  ),
                ),

                // Glow disc behind logo
                AnimatedBuilder(
                  animation: _glowAnim,
                  builder: (_, __) => Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary
                              .withValues(alpha: 0.6 * _glowAnim.value),
                          blurRadius: 50,
                          spreadRadius: 20,
                        ),
                        BoxShadow(
                          color: AppColors.secondary
                              .withValues(alpha: 0.3 * _glowAnim.value),
                          blurRadius: 35,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),

                // Logo hexagon container
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: _ShieldIcon(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── App name ──────────────────────────────────────────────────
  Widget _buildTitleSection() {
    return AnimatedBuilder(
      animation: _titleOpacity,
      builder: (_, __) => FractionalTranslation(
        translation: _titleSlide.value,
        child: Opacity(
          opacity: _titleOpacity.value,
          child: Column(
            children: [
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppColors.primaryGradient.createShader(bounds),
                blendMode: BlendMode.srcIn,
                child: const Text(
                  'SafeHer',
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    letterSpacing: 2.5,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tagline ───────────────────────────────────────────────────
  Widget _buildTagline() {
    return AnimatedBuilder(
      animation: _taglineOpacity,
      builder: (_, __) => FractionalTranslation(
        translation: _taglineSlide.value,
        child: Opacity(
          opacity: _taglineOpacity.value,
          child: const Text(
            'YOUR SAFETY, OUR PRIORITY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white38,
              fontFamily: 'Poppins',
              letterSpacing: 3.5,
            ),
          ),
        ),
      ),
    );
  }

  // ── Feature badges ────────────────────────────────────────────
  Widget _buildBadges() {
    return AnimatedBuilder(
      animation: _badgeOpacity,
      builder: (_, __) => Opacity(
        opacity: _badgeOpacity.value,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Badge(
              icon: Icons.shield_outlined,
              label: 'AI Protected',
              color: AppColors.primary,
            ),
            const SizedBox(width: 10),
            _Badge(
              icon: Icons.location_on_outlined,
              label: 'Live Tracking',
              color: AppColors.secondary,
            ),
            const SizedBox(width: 10),
            _Badge(
              icon: Icons.notifications_active_outlined,
              label: 'Auto SOS',
              color: AppColors.sosRed,
            ),
          ],
        ),
      ),
    );
  }

  // ── Progress bar ──────────────────────────────────────────────
  Widget _buildProgress() {
    return AnimatedBuilder(
      animation: _progressOpacity,
      builder: (_, __) => Opacity(
        opacity: _progressOpacity.value,
        child: Column(
          children: [
            SizedBox(
              width: 160,
              child: AnimatedBuilder(
                animation: _progressAnim,
                builder: (_, __) => Stack(
                  children: [
                    // Track
                    Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    // Fill with glow
                    FractionallySizedBox(
                      widthFactor: _progressAnim.value,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.secondary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color:
                              AppColors.primary.withValues(alpha: 0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Initializing safety systems...',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white24,
                fontFamily: 'Poppins',
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Version tag ───────────────────────────────────────────────
  Widget _buildVersionTag() {
    return Positioned(
      bottom: 32,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _badgeOpacity,
        builder: (_, __) => Opacity(
          opacity: _badgeOpacity.value * 0.4,
          child: const Text(
            'v1.0.0 · Powered by Anthropic AI',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white38,
              fontFamily: 'Poppins',
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }

  // ── Floating particles ────────────────────────────────────────
  List<Widget> _buildParticles(Size size) {
    const particles = [
      _ParticleData(dx: 0.08, dy: 0.18, size: 2.5, phase: 0.0,  isSecondary: false),
      _ParticleData(dx: 0.88, dy: 0.12, size: 2.0, phase: 0.25, isSecondary: true),
      _ParticleData(dx: 0.72, dy: 0.72, size: 3.0, phase: 0.5,  isSecondary: false),
      _ParticleData(dx: 0.18, dy: 0.78, size: 1.8, phase: 0.15, isSecondary: true),
      _ParticleData(dx: 0.92, dy: 0.48, size: 2.8, phase: 0.7,  isSecondary: false),
      _ParticleData(dx: 0.42, dy: 0.08, size: 2.0, phase: 0.4,  isSecondary: true),
      _ParticleData(dx: 0.05, dy: 0.55, size: 2.2, phase: 0.6,  isSecondary: false),
      _ParticleData(dx: 0.78, dy: 0.30, size: 1.6, phase: 0.85, isSecondary: true),
      _ParticleData(dx: 0.55, dy: 0.92, size: 2.5, phase: 0.35, isSecondary: false),
      _ParticleData(dx: 0.30, dy: 0.35, size: 1.5, phase: 0.9,  isSecondary: true),
    ];

    return particles.map((p) {
      return AnimatedBuilder(
        animation: _particleCtrl,
        builder: (_, __) {
          final t = (_particleCtrl.value + p.phase) % 1.0;
          final floatY = math.sin(t * math.pi) * 18.0 - 9.0;
          final opacity =
              0.12 + 0.35 * math.sin(t * math.pi).clamp(0.0, 1.0);
          final color = p.isSecondary
              ? AppColors.secondary
              : AppColors.primary;
          return Positioned(
            left: size.width * p.dx,
            top: size.height * p.dy + floatY,
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: p.size,
                height: p.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.7),
                      blurRadius: p.size * 2.5,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }).toList();
  }
}

// ── Orbit ring painter ────────────────────────────────────────────
class _OrbitRingPainter extends CustomPainter {
  final Color dotColor;
  final Color ringColor;
  final int dotCount;
  final double dotSize;
  final double strokeWidth;

  const _OrbitRingPainter({
    required this.dotColor,
    required this.ringColor,
    required this.dotCount,
    required this.dotSize,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw ring
    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, ringPaint);

    // Draw orbiting dots
    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < dotCount; i++) {
      final angle = (2 * math.pi / dotCount) * i;
      final dx = center.dx + radius * math.cos(angle);
      final dy = center.dy + radius * math.sin(angle);
      canvas.drawCircle(Offset(dx, dy), dotSize, dotPaint);

      // Glow for dot
      final glowPaint = Paint()
        ..color = dotColor.withAlpha(60)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(dx, dy), dotSize * 1.8, glowPaint);
    }
  }

  @override
  bool shouldRepaint(_OrbitRingPainter old) => false;
}

// ── Custom shield icon ────────────────────────────────────────────
class _ShieldIcon extends StatelessWidget {
  const _ShieldIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.shield_rounded,
      color: Colors.white,
      size: 46,
    );
  }
}

// ── Small feature badge ───────────────────────────────────────────
class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Badge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Particle data ─────────────────────────────────────────────────
class _ParticleData {
  final double dx;
  final double dy;
  final double size;
  final double phase;
  final bool isSecondary;

  const _ParticleData({
    required this.dx,
    required this.dy,
    required this.size,
    required this.phase,
    required this.isSecondary,
  });
}