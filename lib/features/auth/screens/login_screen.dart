// lib/features/auth/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_widgets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/constants/app_constants.dart';

// ════════════════════════════════════════════════════════════════
// LOGIN SCREEN
// ════════════════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {

  final _formKey             = GlobalKey<FormState>();
  final _emailController     = TextEditingController();
  final _passwordController  = TextEditingController();
  final _emailFocus          = FocusNode();
  final _passwordFocus       = FocusNode();

  bool _googleLoading = false;

  // ── Animation controllers ─────────────────────────────────────
  late AnimationController _bgCtrl;
  late AnimationController _entryCtrl;
  late AnimationController _floatCtrl;
  late Animation<double>   _floatAnim;

  // Staggered entries
  late Animation<double> _topBarFade;
  late Animation<Offset> _topBarSlide;
  late Animation<double> _illustFade;
  late Animation<Offset> _illustSlide;
  late Animation<double> _formFade;
  late Animation<Offset> _formSlide;
  late Animation<double> _socialFade;

  @override
  void initState() {
    super.initState();
    _setupControllers();
    _entryCtrl.forward();
  }

  void _setupControllers() {
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    _floatAnim = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    // Staggered animations
    _topBarFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.40, curve: Curves.easeOut),
    );
    _topBarSlide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end:   Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.40, curve: Curves.easeOut),
    ));

    _illustFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.15, 0.52, curve: Curves.easeOut),
    );
    _illustSlide = Tween<Offset>(
      begin: const Offset(0.12, 0),
      end:   Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.15, 0.52, curve: Curves.easeOut),
    ));

    _formFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
    );
    _formSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end:   Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic),
    ));

    _socialFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.60, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _bgCtrl.dispose();
    _entryCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  // ── Auth logic ────────────────────────────────────────────────
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();

    final success = await context.read<AuthProvider>().loginWithEmail(
      email:    _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) {
      Navigator.pushReplacementNamed(context, AppRouter.home);
    }
  }

  Future<void> _googleLogin() async {
    setState(() => _googleLoading = true);
    HapticFeedback.mediumImpact();

    final success = await context.read<AuthProvider>().signInWithGoogle();
    if (mounted) {
      setState(() => _googleLoading = false);
      if (success) Navigator.pushReplacementNamed(context, AppRouter.home);
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size   = MediaQuery.of(context).size;
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          // Animated background
          _buildBackground(size),

          // Scrollable content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: size.height - topPad,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      // Top bar
                      FadeTransition(
                        opacity: _topBarFade,
                        child: SlideTransition(
                          position: _topBarSlide,
                          child: _buildTopBar(),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Illustration
                      FadeTransition(
                        opacity: _illustFade,
                        child: SlideTransition(
                          position: _illustSlide,
                          child: _buildIllustration(size),
                        ),
                      ),
                      const SizedBox(height: 26),

                      // Welcome heading
                      FadeTransition(
                        opacity: _formFade,
                        child: SlideTransition(
                          position: _formSlide,
                          child: _buildHeading(),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Error banner
                      Consumer<AuthProvider>(
                        builder: (_, auth, __) => AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          child: auth.errorMessage != null
                              ? Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: ErrorBanner(
                              message:   auth.errorMessage!,
                              onDismiss: auth.clearError,
                            ),
                          )
                              : const SizedBox.shrink(),
                        ),
                      ),

                      // Form
                      FadeTransition(
                        opacity: _formFade,
                        child: SlideTransition(
                          position: _formSlide,
                          child: _buildForm(),
                        ),
                      ),
                      const SizedBox(height: 26),

                      // Social section
                      FadeTransition(
                        opacity: _socialFade,
                        child: _buildSocial(),
                      ),
                      const SizedBox(height: 24),

                      // Register link
                      FadeTransition(
                        opacity: _socialFade,
                        child: _buildRegisterLink(),
                      ),
                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── ANIMATED BACKGROUND ───────────────────────────────────────
  Widget _buildBackground(Size size) {
    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (_, __) {
        final t = _bgCtrl.value;
        return Stack(
          children: [
            // Base gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0D0D1A),
                    Color(0xFF110820),
                    Color(0xFF0A0F1E),
                  ],
                  begin: Alignment.topLeft,
                  end:   Alignment.bottomRight,
                ),
              ),
            ),
            // Top-right primary blob
            Positioned(
              top:   -size.height * 0.06 + t * 28,
              right: -size.width  * 0.18,
              child: _blob(size.width * 0.72,
                  AppColors.primary.withValues(alpha: 0.13)),
            ),
            // Bottom-left secondary blob
            Positioned(
              bottom: -size.height * 0.04 - t * 22,
              left:   -size.width  * 0.22,
              child: _blob(size.width * 0.68,
                  AppColors.secondary.withValues(alpha: 0.09)),
            ),
          ],
        );
      },
    );
  }

  Widget _blob(double size, Color color) => Container(
    width:  size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [color, Colors.transparent],
      ),
    ),
  );

  // ── TOP BAR ───────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Row(
      children: [
        // Logo circle — custom shield painter
        Container(
          width:  44,
          height: 44,
          decoration: const BoxDecoration(
            shape:    BoxShape.circle,
            gradient: AppColors.primaryGradient,
          ),
          child: Center(
            child: CustomPaint(
              size: const Size(22, 22),
              painter: ShieldIconPainter(
                color:  Colors.white,
                filled: false,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // App name gradient
        ShaderMask(
          shaderCallback: (b) => AppColors.primaryGradient.createShader(b),
          blendMode: BlendMode.srcIn,
          child: const Text(
            'SafeHer',
            style: TextStyle(
              fontSize:    22,
              fontWeight:  FontWeight.w800,
              color:       Colors.white,
              fontFamily:  'Poppins',
              letterSpacing: 0.5,
            ),
          ),
        ),

        const Spacer(),

        // Secured badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.safeGreen.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.safeGreen.withValues(alpha: 0.22),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width:  6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.safeGreen,
                  boxShadow: [
                    BoxShadow(
                      color:      AppColors.safeGreen.withValues(alpha: 0.6),
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Secured',
                style: TextStyle(
                  fontSize:   10,
                  color:      AppColors.safeGreen,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── ILLUSTRATION ──────────────────────────────────────────────
  Widget _buildIllustration(Size size) {
    return AnimatedBuilder(
      animation: _floatAnim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _floatAnim.value),
        child: SizedBox(
          width:  double.infinity,
          height: size.height * 0.20,
          child: const CustomPaint(
            painter: _LoginIllustrationPainter(),
          ),
        ),
      ),
    );
  }

  // ── WELCOME HEADING ───────────────────────────────────────────
  Widget _buildHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Welcome\n',
                style: TextStyle(
                  fontSize:   32,
                  fontWeight: FontWeight.w700,
                  color:      Colors.white,
                  fontFamily: 'Poppins',
                  height:     1.10,
                ),
              ),
              TextSpan(
                text: 'Back',
                style: TextStyle(
                  fontSize:   32,
                  fontWeight: FontWeight.w700,
                  color:      AppColors.primary,
                  fontFamily: 'Poppins',
                  height:     1.10,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Sign in to stay protected',
          style: TextStyle(
            fontSize:   13,
            color:      Colors.white.withValues(alpha: 0.42),
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // ── FORM ──────────────────────────────────────────────────────
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Email
          AppTextField(
            label:           'Email Address',
            hint:            'you@example.com',
            prefixPainter:   const EmailIconPainter(color: AppColors.primary),
            controller:      _emailController,
            focusNode:       _emailFocus,
            nextFocusNode:   _passwordFocus,
            keyboardType:    TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (val) {
              if (val == null || val.isEmpty) return 'Email is required';
              if (!RegExp(AppConstants.emailRegex).hasMatch(val)) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Password
          AppTextField(
            label:           'Password',
            hint:            '••••••••',
            prefixPainter:   const LockIconPainter(color: AppColors.primary),
            controller:      _passwordController,
            focusNode:       _passwordFocus,
            isPassword:      true,
            textInputAction: TextInputAction.done,
            validator: (val) {
              if (val == null || val.isEmpty) return 'Password is required';
              if (val.length < 6) return 'Minimum 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 10),

          // Forgot password
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.pushNamed(context, AppRouter.forgotPassword);
              },
              child: const Text(
                'Forgot password?',
                style: TextStyle(
                  color:      AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                  fontSize:   13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Sign in button
          Consumer<AuthProvider>(
            builder: (_, auth, __) => GradientButton(
              text:       'Sign In Securely',
              onTap:      _login,
              isLoading:  auth.isLoading,
              iconPainter: const ShieldIconPainter(
                color:  Colors.white,
                filled: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── SOCIAL SECTION ────────────────────────────────────────────
  Widget _buildSocial() {
    return Column(
      children: [
        const OrDivider(),
        const SizedBox(height: 18),

        // Google
        SocialLoginButton(
          label:       'Continue with Google',
          iconPainter: const GoogleIconPainter(),
          onTap:       _googleLogin,
          isLoading:   _googleLoading,
        ),
        const SizedBox(height: 12),

        // Phone OTP
        SocialLoginButton(
          label:       'Continue with Phone OTP',
          iconPainter: const PhoneIconPainter(color: AppColors.safeGreen),
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.pushNamed(context, AppRouter.phoneAuth);
          },
        ),
      ],
    );
  }

  // ── REGISTER LINK ─────────────────────────────────────────────
  Widget _buildRegisterLink() {
    return Center(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.pushReplacementNamed(context, AppRouter.register);
        },
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
            children: [
              TextSpan(
                text: "Don't have an account? ",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.42),
                ),
              ),
              const TextSpan(
                text: 'Sign up',
                style: TextStyle(
                  color:      AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// LOGIN ILLUSTRATION PAINTER
// ════════════════════════════════════════════════════════════════
class _LoginIllustrationPainter extends CustomPainter {
  const _LoginIllustrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;

    // ── Concentric glow rings ─────────────────────────────────
    for (int i = 4; i >= 1; i--) {
      canvas.drawCircle(
        Offset(cx, cy),
        28.0 + i * 18,
        Paint()
          ..color      = AppColors.primary.withValues(alpha: 0.04 * (5 - i))
          ..style      = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }

    // ── Central shield ────────────────────────────────────────
    const sw = 52.0;
    const sh = 60.0;
    final sx = cx - sw / 2;
    final sy = cy - sh / 2;

    final shieldPath = Path();
    shieldPath.moveTo(cx, sy);
    shieldPath.quadraticBezierTo(sx + sw, sy,       sx + sw, sy + sh * 0.44);
    shieldPath.quadraticBezierTo(sx + sw, sy + sh * 0.80, cx, sy + sh);
    shieldPath.quadraticBezierTo(sx,      sy + sh * 0.80, sx, sy + sh * 0.44);
    shieldPath.quadraticBezierTo(sx, sy, cx, sy);
    shieldPath.close();

    // Gradient fill
    canvas.drawPath(
      shieldPath,
      Paint()
        ..shader = const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(sx, sy, sw, sh)),
    );

    // Border glow
    canvas.drawPath(
      shieldPath,
      Paint()
        ..color      = AppColors.primaryLight.withValues(alpha: 0.55)
        ..style      = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin  = StrokeJoin.round,
    );

    // Checkmark
    final check = Path();
    check.moveTo(cx - 11, cy - 1);
    check.lineTo(cx - 3,  cy + 9);
    check.lineTo(cx + 13, cy - 9);
    canvas.drawPath(
      check,
      Paint()
        ..color      = Colors.white
        ..style      = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap  = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // ── Floating security dots with connection lines ───────────
    final dots = [
      (Offset(cx - 82, cy - 22), AppColors.primary),
      (Offset(cx + 76, cy - 28), AppColors.secondary),
      (Offset(cx - 68, cy + 32), AppColors.secondary),
      (Offset(cx + 72, cy + 28), AppColors.primary),
      (Offset(cx - 8,  cy - 72), AppColors.primary),
      (Offset(cx + 8,  cy + 72), AppColors.secondary),
    ];

    for (final d in dots) {
      canvas.drawLine(
        d.$1, Offset(cx, cy),
        Paint()
          ..color      = d.$2.withValues(alpha: 0.14)
          ..strokeWidth = 1.0,
      );
      canvas.drawCircle(
        d.$1, 7.5,
        Paint()..color = d.$2.withValues(alpha: 0.10),
      );
      canvas.drawCircle(
        d.$1, 4.5,
        Paint()..color = d.$2.withValues(alpha: 0.80),
      );
    }

    // ── Horizontal data lines (right side) ────────────────────
    final lineData = [
      (Offset(cx + 92, cy - 42), 52.0, AppColors.primary,   0.22),
      (Offset(cx + 92, cy - 22), 38.0, AppColors.secondary, 0.16),
      (Offset(cx + 92, cy +  2), 60.0, AppColors.primary,   0.20),
      (Offset(cx - 92, cy - 32), 48.0, AppColors.secondary, 0.18),
      (Offset(cx - 92, cy - 10), 36.0, AppColors.primary,   0.14),
      (Offset(cx - 92, cy + 14), 44.0, AppColors.secondary, 0.16),
    ];

    for (final d in lineData) {
      canvas.drawLine(
        d.$1,
        Offset(d.$1.dx - d.$2, d.$1.dy),
        Paint()
          ..color      = d.$3.withValues(alpha: d.$4)
          ..strokeWidth = 1.0
          ..strokeCap  = StrokeCap.round,
      );
    }

    // ── Lock icons (small circles with keyhole) ────────────────
    final locks = [
      Offset(cx + 110, cy - 56),
      Offset(cx - 108, cy + 46),
      Offset(cx + 112, cy + 40),
    ];

    for (final l in locks) {
      canvas.drawCircle(l, 10,
          Paint()..color = AppColors.primary.withValues(alpha: 0.08));
      canvas.drawCircle(l, 10,
          Paint()
            ..color = AppColors.primary.withValues(alpha: 0.30)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0);
      canvas.drawCircle(l, 3,
          Paint()..color = AppColors.primary.withValues(alpha: 0.55));
    }
  }

  @override
  bool shouldRepaint(_LoginIllustrationPainter old) => false;
}