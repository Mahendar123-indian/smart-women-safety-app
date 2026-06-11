// lib/features/auth/screens/forgot_password_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_widgets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _emailFocus      = FocusNode();
  final _formKey         = GlobalKey<FormState>();
  bool _emailSent        = false;

  late AnimationController _bgCtrl;
  late AnimationController _entryCtrl;
  late AnimationController _iconCtrl;
  late Animation<double>   _iconScale;
  late Animation<double>   _contentFade;
  late Animation<Offset>   _contentSlide;

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _iconCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _iconScale = CurvedAnimation(parent: _iconCtrl, curve: Curves.elasticOut);

    _contentFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
    ));

    _entryCtrl.forward();
    _iconCtrl.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocus.dispose();
    _bgCtrl.dispose();
    _entryCtrl.dispose();
    _iconCtrl.dispose();
    super.dispose();
  }

  // ── Auth logic (unchanged) ────────────────────────────────────
  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();

    final success = await context.read<AuthProvider>().sendPasswordResetEmail(
      _emailController.text.trim(),
    );

    if (success && mounted) {
      setState(() => _emailSent = true);
      _iconCtrl.reset();
      _iconCtrl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size   = MediaQuery.of(context).size;
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          _buildBackground(size),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: size.height - topPad),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildTopBar(),
                      const SizedBox(height: 40),
                      _buildIconSection(),
                      const SizedBox(height: 36),

                      // Animated switcher between form and success
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 420),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.1),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: _emailSent
                            ? _buildSuccessView()
                            : _buildFormView(),
                      ),

                      const SizedBox(height: 40),
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
                  colors: [Color(0xFF0D0D1A), Color(0xFF110820), Color(0xFF0A0F1E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              top: -size.height * 0.05 + t * 28,
              right: -size.width * 0.18,
              child: _blob(size.width * 0.70,
                  AppColors.primary.withValues(alpha: 0.11)),
            ),
            Positioned(
              bottom: -size.height * 0.04 - t * 20,
              left: -size.width * 0.20,
              child: _blob(size.width * 0.65,
                  AppColors.secondary.withValues(alpha: 0.08)),
            ),
          ],
        );
      },
    );
  }

  Widget _blob(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, Colors.transparent]),
    ),
  );

  // ── Top bar ───────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Row(
      children: [
        _BackButton(),
        const Spacer(),
        ShaderMask(
          shaderCallback: (b) => AppColors.primaryGradient.createShader(b),
          blendMode: BlendMode.srcIn,
          child: const Text(
            'SafeHer',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontFamily: 'Poppins',
            ),
          ),
        ),
      ],
    );
  }

  // ── Icon section ──────────────────────────────────────────────
  Widget _buildIconSection() {
    return Center(
      child: ScaleTransition(
        scale: _iconScale,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: _emailSent
              ? _GlowCircle(
            key: const ValueKey('sent'),
            gradient: AppColors.safeGradient,
            glowColor: AppColors.safeGreen,
            size: 96,
            child: CustomPaint(
              size: const Size(40, 40),
              painter: _EmailCheckPainter(),
            ),
          )
              : _GlowCircle(
            key: const ValueKey('lock'),
            gradient: AppColors.primaryGradient,
            glowColor: AppColors.primary,
            size: 96,
            child: CustomPaint(
              size: const Size(40, 40),
              painter: _KeyIconPainter(),
            ),
          ),
        ),
      ),
    );
  }

  // ── Success view ──────────────────────────────────────────────
  Widget _buildSuccessView() {
    return FadeTransition(
      key: const ValueKey('success'),
      opacity: _contentFade,
      child: SlideTransition(
        position: _contentSlide,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Email Sent!',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'We\'ve sent a password reset link to ${_emailController.text}. Check your inbox and follow the instructions.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.50),
                fontFamily: 'Poppins',
                height: 1.65,
              ),
            ),
            const SizedBox(height: 32),
            // Success info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.safeGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.safeGreen.withValues(alpha: 0.20),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  CustomPaint(
                    size: const Size(20, 20),
                    painter: _InfoIconPainter(color: AppColors.safeGreen),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Check your spam folder if you don\'t see the email within a few minutes.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.safeGreen.withValues(alpha: 0.85),
                        fontFamily: 'Poppins',
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            GradientButton(
              text: 'Back to Login',
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  // ── Form view ─────────────────────────────────────────────────
  Widget _buildFormView() {
    return FadeTransition(
      key: const ValueKey('form'),
      opacity: _contentFade,
      child: SlideTransition(
        position: _contentSlide,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Forgot\n',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      height: 1.1,
                    ),
                  ),
                  TextSpan(
                    text: 'Password?',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      fontFamily: 'Poppins',
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Enter your registered email to receive a password reset link.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.42),
                fontFamily: 'Poppins',
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),

            // Error banner
            Consumer<AuthProvider>(
              builder: (_, auth, __) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: auth.errorMessage != null
                    ? Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ErrorBanner(message: auth.errorMessage!),
                )
                    : const SizedBox.shrink(),
              ),
            ),

            Form(
              key: _formKey,
              child: AppTextField(
                label: 'Email Address',
                hint: 'your@email.com',
                prefixPainter: const EmailIconPainter(color: AppColors.primary),
                controller: _emailController,
                focusNode: _emailFocus,
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Email is required';
                  if (!RegExp(AppConstants.emailRegex).hasMatch(val)) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
            ),

            const SizedBox(height: 28),

            Consumer<AuthProvider>(
              builder: (_, auth, __) => GradientButton(
                text: 'Send Reset Link',
                onTap: _sendReset,
                isLoading: auth.isLoading,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Glow circle container ─────────────────────────────────────────
class _GlowCircle extends StatelessWidget {
  final Gradient gradient;
  final Color glowColor;
  final double size;
  final Widget child;

  const _GlowCircle({
    super.key,
    required this.gradient,
    required this.glowColor,
    required this.size,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.38),
            blurRadius: 28,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Center(child: child),
    );
  }
}

// ── Back button ───────────────────────────────────────────────────
class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.pop(context);
      },
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary.withValues(alpha: 0.10),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Center(
          child: CustomPaint(
            size: const Size(18, 18),
            painter: _BackArrowPainter(),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PAINTERS
// ════════════════════════════════════════════════════════════════

class _KeyIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Key circle
    canvas.drawCircle(Offset(w * 0.35, h * 0.38), w * 0.22, p);
    // Key shaft
    canvas.drawLine(
      Offset(w * 0.52, h * 0.52),
      Offset(w * 0.88, h * 0.88),
      p,
    );
    // Key teeth
    canvas.drawLine(Offset(w * 0.72, h * 0.68), Offset(w * 0.72, h * 0.80), p);
    canvas.drawLine(Offset(w * 0.82, h * 0.78), Offset(w * 0.82, h * 0.90), p);
  }

  @override
  bool shouldRepaint(_KeyIconPainter old) => false;
}

class _EmailCheckPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Envelope
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, h * 0.20, w, h * 0.60),
        const Radius.circular(4),
      ),
      p,
    );
    // Check instead of V flap
    final check = Path();
    check.moveTo(w * 0.22, h * 0.54);
    check.lineTo(w * 0.42, h * 0.72);
    check.lineTo(w * 0.78, h * 0.38);
    canvas.drawPath(check, p);
  }

  @override
  bool shouldRepaint(_EmailCheckPainter old) => false;
}

class _InfoIconPainter extends CustomPainter {
  final Color color;
  const _InfoIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width * 0.46;

    canvas.drawCircle(Offset(cx, cy), r,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4);
    // i dot
    canvas.drawCircle(Offset(cx, cy - r * 0.42), size.width * 0.07,
        Paint()..color = color);
    // i stem
    canvas.drawLine(
      Offset(cx, cy - r * 0.15),
      Offset(cx, cy + r * 0.42),
      Paint()
        ..color = color
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_InfoIconPainter old) => old.color != color;
}

class _BackArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final cy = size.height / 2;
    canvas.drawLine(Offset(size.width * 0.80, cy), Offset(size.width * 0.20, cy), p);
    final head = Path();
    head.moveTo(size.width * 0.45, cy - size.height * 0.28);
    head.lineTo(size.width * 0.20, cy);
    head.lineTo(size.width * 0.45, cy + size.height * 0.28);
    canvas.drawPath(head, p);
  }

  @override
  bool shouldRepaint(_BackArrowPainter old) => false;
}