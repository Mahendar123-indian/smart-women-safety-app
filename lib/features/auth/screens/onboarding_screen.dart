// lib/features/auth/screens/onboarding_screen.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  // ✅ FIX: Removed PageController entirely since this screen uses a custom
  // GestureDetector swipe system instead of a PageView widget.
  int _currentPage = 0;

  // Per-page entry animation
  late AnimationController _pageAnimCtrl;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;

  // Button press animation
  late AnimationController _btnCtrl;
  late Animation<double> _btnScale;

  // Continuous floating for illustration
  late AnimationController _floatCtrl;
  late Animation<double> _floatAnim;

  // Background particle
  late AnimationController _bgCtrl;

  // Drag tracking for manual swipe detection
  double _dragStartX = 0;
  bool _isDragging = false;

  static const _pages = [
    _PageData(
      tag: 'AI PROTECTION',
      title: 'Predict Danger\nBefore It Happens',
      description:
      'Our ML model analyzes your surroundings in real-time and alerts you before any threat escalates — fully automatic.',
      primaryColor: Color(0xFFE91E8C),
      secondaryColor: Color(0xFF9C27B0),
      accentColor: Color(0xFFF48FB1),
      illustration: _IllustrationType.aiShield,
      statLabel1: 'Accuracy',
      statValue1: '97.3%',
      statLabel2: 'Response',
      statValue2: '<0.3s',
    ),
    _PageData(
      tag: 'SMART SENSORS',
      title: 'Always Watching,\nAlways Ready',
      description:
      'GPS, accelerometer, gyroscope, and microphone work in harmony 24/7 to build a live safety picture around you.',
      primaryColor: Color(0xFF6C63FF),
      secondaryColor: Color(0xFF3F51B5),
      accentColor: Color(0xFFB39DDB),
      illustration: _IllustrationType.sensors,
      statLabel1: 'Sensors',
      statValue1: '6 Active',
      statLabel2: 'Uptime',
      statValue2: '24/7',
    ),
    _PageData(
      tag: 'INSTANT SOS',
      title: 'Help Arrives\nBefore You Ask',
      description:
      'When danger is detected, SOS fires automatically — alerts your contacts, shares live location, records evidence.',
      primaryColor: Color(0xFFFF1744),
      secondaryColor: Color(0xFFFF6B6B),
      accentColor: Color(0xFFFFCDD2),
      illustration: _IllustrationType.sos,
      statLabel1: 'Alerts',
      statValue1: '5 Types',
      statLabel2: 'Evidence',
      statValue2: 'Auto',
    ),
  ];

  @override
  void initState() {
    super.initState();

    _pageAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _contentFade = CurvedAnimation(
      parent: _pageAnimCtrl,
      curve: Curves.easeOut,
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _pageAnimCtrl,
      curve: Curves.easeOut,
    ));

    _btnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _btnScale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _btnCtrl, curve: Curves.easeIn),
    );

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat(reverse: true);

    _pageAnimCtrl.forward();
  }

  @override
  void dispose() {
    _pageAnimCtrl.dispose();
    _btnCtrl.dispose();
    _floatCtrl.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _pageAnimCtrl.reset();
    _pageAnimCtrl.forward();
    HapticFeedback.selectionClick();
  }

  Future<void> _onNext() async {
    HapticFeedback.mediumImpact();
    await _btnCtrl.forward();
    await _btnCtrl.reverse();

    if (_currentPage < _pages.length - 1) {
      // ✅ FIX: Trigger page change manually instead of using a PageController
      _onPageChanged(_currentPage + 1);
    } else {
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRouter.login);
      }
    }
  }

  void _onSkip() {
    HapticFeedback.selectionClick();
    Navigator.pushReplacementNamed(context, AppRouter.login);
  }

  /// Handle horizontal swipe manually so that Skip tap is never intercepted.
  void _onHorizontalDragStart(DragStartDetails details) {
    _dragStartX = details.globalPosition.dx;
    _isDragging = true;
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;
    final velocity = details.primaryVelocity ?? 0;

    // Swipe left → next page
    if (velocity < -300 && _currentPage < _pages.length - 1) {
      // ✅ FIX: Use _onPageChanged to update state and trigger animation
      _onPageChanged(_currentPage + 1);
    }
    // Swipe right → previous page
    else if (velocity > 300 && _currentPage > 0) {
      // ✅ FIX: Use _onPageChanged to update state and trigger animation
      _onPageChanged(_currentPage - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final page = _pages[_currentPage];
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.darkBackground,
              page.primaryColor.withValues(alpha: 0.08),
              AppColors.darkBackground,
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        // ── KEY FIX: Use GestureDetector at root for swipe, NOT PageView ──
        child: GestureDetector(
          onHorizontalDragStart: _onHorizontalDragStart,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              // ── Animated background blobs ───────────────────
              _buildBackgroundBlobs(size, page),

              // ── Page content ────────────────────────────────
              _buildPageContent(size, page, topPad, bottomPad),

              // ── Skip button — topmost, never intercepted ────
              // KEY FIX: No PageView in the tree, so Skip always gets taps.
              if (_currentPage < _pages.length - 1)
                Positioned(
                  top: topPad + 16,
                  right: 24,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _onSkip,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                            width: 1,
                          ),
                        ),
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundBlobs(Size size, _PageData page) {
    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (_, __) {
        final t = _bgCtrl.value;
        return Stack(
          children: [
            Positioned(
              top: size.height * 0.05 + t * 20,
              right: -size.width * 0.15,
              child: Container(
                width: size.width * 0.7,
                height: size.width * 0.7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      page.primaryColor.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: size.height * 0.15 - t * 15,
              left: -size.width * 0.2,
              child: Container(
                width: size.width * 0.65,
                height: size.width * 0.65,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      page.secondaryColor.withValues(alpha: 0.10),
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

  Widget _buildPageContent(
      Size size,
      _PageData page,
      double topPad,
      double bottomPad,
      ) {
    return FadeTransition(
      opacity: _contentFade,
      child: SlideTransition(
        position: _contentSlide,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;
            final illustHeight =
            (availableHeight * 0.28).clamp(140.0, 220.0);
            final illustWidth = size.width * 0.68;

            return SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: availableHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      SizedBox(height: topPad + 60),

                      // ── Tag pill ────────────────────────────
                      _buildTag(page),

                      const Spacer(flex: 1),

                      // ── Illustration ────────────────────────
                      AnimatedBuilder(
                        animation: _floatAnim,
                        builder: (_, __) => Transform.translate(
                          offset: Offset(0, _floatAnim.value),
                          child: SizedBox(
                            width: illustWidth,
                            height: illustHeight,
                            child: _OnboardingIllustration(
                              type: page.illustration,
                              primaryColor: page.primaryColor,
                              secondaryColor: page.secondaryColor,
                              accentColor: page.accentColor,
                            ),
                          ),
                        ),
                      ),

                      const Spacer(flex: 1),

                      // ── Title ───────────────────────────────
                      _buildTitle(page),

                      const SizedBox(height: 12),

                      // ── Description ─────────────────────────
                      _buildDescription(page),

                      const SizedBox(height: 18),

                      // ── Stats row ───────────────────────────
                      _buildStats(page),

                      const Spacer(flex: 2),

                      // ── Dots + Button ───────────────────────
                      _buildBottomControls(page, bottomPad),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTag(_PageData page) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            page.primaryColor.withValues(alpha: 0.2),
            page.secondaryColor.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: page.primaryColor.withValues(alpha: 0.35),
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
              color: page.primaryColor,
              boxShadow: [
                BoxShadow(
                  color: page.primaryColor.withValues(alpha: 0.6),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Text(
            page.tag,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: page.primaryColor,
              fontFamily: 'Poppins',
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(_PageData page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          colors: [page.primaryColor, page.accentColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
        blendMode: BlendMode.srcIn,
        child: Text(
          page.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontFamily: 'Poppins',
            height: 1.25,
            letterSpacing: -0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildDescription(_PageData page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Text(
        page.description,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          color: Colors.white.withValues(alpha: 0.55),
          fontFamily: 'Poppins',
          height: 1.60,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildStats(_PageData page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: [
          Expanded(
              child: _StatCard(
                label: page.statLabel1,
                value: page.statValue1,
                color: page.primaryColor,
              )),
          const SizedBox(width: 12),
          Expanded(
              child: _StatCard(
                label: page.statLabel2,
                value: page.statValue2,
                color: page.secondaryColor,
              )),
        ],
      ),
    );
  }

  Widget _buildBottomControls(_PageData page, double bottomPad) {
    return Padding(
      padding: EdgeInsets.fromLTRB(28, 0, 28, bottomPad + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dot indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pages.length, (i) {
              final isActive = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 28 : 7,
                height: 7,
                decoration: BoxDecoration(
                  gradient: isActive
                      ? LinearGradient(
                    colors: [page.primaryColor, page.secondaryColor],
                  )
                      : null,
                  color:
                  isActive ? null : Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: isActive
                      ? [
                    BoxShadow(
                      color: page.primaryColor.withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ]
                      : null,
                ),
              );
            }),
          ),

          const SizedBox(height: 20),

          // CTA Button
          ScaleTransition(
            scale: _btnScale,
            child: GestureDetector(
              onTap: _onNext,
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [page.primaryColor, page.secondaryColor],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: page.primaryColor.withValues(alpha: 0.45),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Shimmer overlay
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: AnimatedBuilder(
                        animation: _bgCtrl,
                        builder: (_, __) => Align(
                          alignment:
                          Alignment(_bgCtrl.value * 3 - 1.5, 0),
                          child: Container(
                            width: 60,
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withValues(alpha: 0.10),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentPage < _pages.length - 1
                              ? 'Continue'
                              : 'Get Started',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat card widget ──────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
              fontFamily: 'Poppins',
              height: 1.0,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.45),
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Illustration widget ───────────────────────────────────────────
class _OnboardingIllustration extends StatelessWidget {
  final _IllustrationType type;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;

  const _OnboardingIllustration({
    required this.type,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _IllustrationPainter(
        type: type,
        primary: primaryColor,
        secondary: secondaryColor,
        accent: accentColor,
      ),
    );
  }
}

class _IllustrationPainter extends CustomPainter {
  final _IllustrationType type;
  final Color primary;
  final Color secondary;
  final Color accent;

  const _IllustrationPainter({
    required this.type,
    required this.primary,
    required this.secondary,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case _IllustrationType.aiShield:
        _drawAiShield(canvas, size);
      case _IllustrationType.sensors:
        _drawSensors(canvas, size);
      case _IllustrationType.sos:
        _drawSos(canvas, size);
    }
  }

  void _drawAiShield(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    for (int i = 3; i >= 1; i--) {
      final paint = Paint()
        ..color = primary.withAlpha((30 * (4 - i)).round())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(Offset(cx, cy), 60.0 + i * 22, paint);
    }

    final shieldPath = Path();
    final sw = size.width * 0.38;
    final sh = size.height * 0.52;
    final sx = cx - sw / 2;
    final sy = cy - sh / 2 - 10;

    shieldPath.moveTo(cx, sy);
    shieldPath.quadraticBezierTo(sx + sw, sy, sx + sw, sy + sh * 0.45);
    shieldPath.quadraticBezierTo(sx + sw, sy + sh * 0.78, cx, sy + sh);
    shieldPath.quadraticBezierTo(sx, sy + sh * 0.78, sx, sy + sh * 0.45);
    shieldPath.quadraticBezierTo(sx, sy, cx, sy);
    shieldPath.close();

    final shieldGrad = Paint()
      ..shader = LinearGradient(
        colors: [primary.withAlpha(200), secondary.withAlpha(180)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(sx, sy, sw, sh));
    canvas.drawPath(shieldPath, shieldGrad);

    final borderPaint = Paint()
      ..color = accent.withAlpha(180)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(shieldPath, borderPaint);

    final checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final checkPath = Path();
    checkPath.moveTo(cx - 14, cy - 2);
    checkPath.lineTo(cx - 4, cy + 10);
    checkPath.lineTo(cx + 16, cy - 12);
    canvas.drawPath(checkPath, checkPaint);

    final dotPositions = [
      Offset(cx - 70, cy - 30),
      Offset(cx + 68, cy - 20),
      Offset(cx - 55, cy + 40),
      Offset(cx + 60, cy + 35),
      Offset(cx, cy - 80),
    ];
    for (int i = 0; i < dotPositions.length; i++) {
      final dotPaint = Paint()
        ..color = (i % 2 == 0 ? primary : secondary).withAlpha(180);
      canvas.drawCircle(dotPositions[i], 5.0, dotPaint);

      final linePaint = Paint()
        ..color = primary.withAlpha(40)
        ..strokeWidth = 1.0;
      canvas.drawLine(dotPositions[i], Offset(cx, cy), linePaint);
    }
  }

  void _drawSensors(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final phoneRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: size.width * 0.32,
        height: size.height * 0.72,
      ),
      const Radius.circular(18),
    );
    final phonePaint = Paint()
      ..color = const Color(0xFF1A1A2E)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(phoneRect, phonePaint);
    final phoneBorder = Paint()
      ..color = secondary.withAlpha(120)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(phoneRect, phoneBorder);

    final sensors = [
      _SensorItem(offset: Offset(cx - 90, cy - 50), icon: 'GPS', color: primary),
      _SensorItem(offset: Offset(cx + 80, cy - 50), icon: 'MIC', color: secondary),
      _SensorItem(offset: Offset(cx - 90, cy + 20), icon: 'ACC', color: accent),
      _SensorItem(offset: Offset(cx + 80, cy + 20), icon: 'CAM', color: primary),
      _SensorItem(offset: Offset(cx - 20, cy - 90), icon: 'GYR', color: secondary),
    ];

    for (final sensor in sensors) {
      final linePaint = Paint()
        ..color = sensor.color.withAlpha(50)
        ..strokeWidth = 1.0;
      canvas.drawLine(sensor.offset, Offset(cx, cy), linePaint);

      final bgPaint = Paint()..color = sensor.color.withAlpha(30);
      canvas.drawCircle(sensor.offset, 22, bgPaint);
      final borderPaint = Paint()
        ..color = sensor.color.withAlpha(150)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(sensor.offset, 22, borderPaint);

      final tp = TextPainter(
        text: TextSpan(
          text: sensor.icon,
          style: TextStyle(
            color: sensor.color,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            fontFamily: 'Poppins',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, sensor.offset - Offset(tp.width / 2, tp.height / 2));
    }

    final linePaint2 = Paint()
      ..color = secondary.withAlpha(80)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 5; i++) {
      final y = cy - 40 + i * 18.0;
      final w = i == 2 ? 50.0 : (i % 2 == 0 ? 70.0 : 55.0);
      canvas.drawLine(
        Offset(cx - w / 2, y),
        Offset(cx + w / 2, y),
        linePaint2,
      );
    }
  }

  void _drawSos(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    for (int i = 3; i >= 1; i--) {
      final rPaint = Paint()
        ..color = primary.withAlpha((20 * (4 - i)).round())
        ..style = PaintingStyle.stroke
        ..strokeWidth = i.toDouble();
      canvas.drawCircle(Offset(cx, cy), 40.0 + i * 24, rPaint);
    }

    final btnGrad = Paint()
      ..shader = RadialGradient(
        colors: [primary.withAlpha(240), secondary.withAlpha(200)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 52));
    canvas.drawCircle(Offset(cx, cy), 52, btnGrad);

    final sosTp = TextPainter(
      text: const TextSpan(
        text: 'SOS',
        style: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          fontFamily: 'Poppins',
          letterSpacing: 3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    sosTp.paint(canvas, Offset(cx - sosTp.width / 2, cy - sosTp.height / 2 - 4));

    final holdTp = TextPainter(
      text: TextSpan(
        text: 'Hold 2s',
        style: TextStyle(
          color: Colors.white.withAlpha(160),
          fontSize: 9,
          fontFamily: 'Poppins',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    holdTp.paint(canvas, Offset(cx - holdTp.width / 2, cy + 10));

    final alerts = [
      _AlertItem(Offset(cx - 95, cy - 45), 'SMS', primary),
      _AlertItem(Offset(cx + 80, cy - 55), 'CALL', secondary),
      _AlertItem(Offset(cx - 85, cy + 45), 'FCM', accent),
      _AlertItem(Offset(cx + 75, cy + 40), 'LOC', primary),
    ];

    for (final alert in alerts) {
      final bgPaint = Paint()..color = alert.color.withAlpha(25);
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: alert.offset, width: 44, height: 24),
        const Radius.circular(12),
      );
      canvas.drawRRect(rect, bgPaint);
      final borderPaint = Paint()
        ..color = alert.color.withAlpha(120)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawRRect(rect, borderPaint);

      final tp = TextPainter(
        text: TextSpan(
          text: alert.label,
          style: TextStyle(
            color: alert.color,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            fontFamily: 'Poppins',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, alert.offset - Offset(tp.width / 2, tp.height / 2));

      final linePaint = Paint()
        ..color = alert.color.withAlpha(60)
        ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(cx, cy) + _directionOffset(alert.offset - Offset(cx, cy), 55),
        alert.offset,
        linePaint,
      );
    }
  }

  Offset _directionOffset(Offset dir, double dist) {
    final len = math.sqrt(dir.dx * dir.dx + dir.dy * dir.dy);
    return Offset(dir.dx / len * dist, dir.dy / len * dist);
  }

  @override
  bool shouldRepaint(_IllustrationPainter old) =>
      old.type != type || old.primary != primary || old.secondary != secondary;
}

class _SensorItem {
  final Offset offset;
  final String icon;
  final Color color;
  const _SensorItem({
    required this.offset,
    required this.icon,
    required this.color,
  });
}

class _AlertItem {
  final Offset offset;
  final String label;
  final Color color;
  const _AlertItem(this.offset, this.label, this.color);
}

// ── Page data ─────────────────────────────────────────────────────
enum _IllustrationType { aiShield, sensors, sos }

class _PageData {
  final String tag;
  final String title;
  final String description;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final _IllustrationType illustration;
  final String statLabel1;
  final String statValue1;
  final String statLabel2;
  final String statValue2;

  const _PageData({
    required this.tag,
    required this.title,
    required this.description,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.illustration,
    required this.statLabel1,
    required this.statValue1,
    required this.statLabel2,
    required this.statValue2,
  });
}