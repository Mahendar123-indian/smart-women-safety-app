// lib/features/auth/screens/register_screen.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_widgets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/constants/app_constants.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey             = GlobalKey<FormState>();
  final _nameController      = TextEditingController();
  final _emailController     = TextEditingController();
  final _phoneController     = TextEditingController();
  final _passwordController  = TextEditingController();
  final _confirmController   = TextEditingController();

  final _nameFocus     = FocusNode();
  final _emailFocus    = FocusNode();
  final _phoneFocus    = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus  = FocusNode();

  bool _agreedToTerms = false;

  // ── Animations ────────────────────────────────────────────────
  late AnimationController _bgCtrl;
  late AnimationController _entryCtrl;
  late Animation<double>   _headerFade;
  late Animation<Offset>   _headerSlide;
  late Animation<double>   _formFade;
  late Animation<Offset>   _formSlide;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat(reverse: true);

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _headerFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));

    _formFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.3, 0.85, curve: Curves.easeOut),
    );
    _formSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.3, 0.85, curve: Curves.easeOutCubic),
    ));

    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    _bgCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  // ── Auth logic (unchanged) ────────────────────────────────────
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please agree to Terms & Privacy Policy',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: AppColors.darkCard,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();

    final success = await context.read<AuthProvider>().register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      phone: _phoneController.text.isNotEmpty
          ? '+91${_phoneController.text.trim()}'
          : null,
    );

    if (success && mounted) _showSuccessDialog();
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => _SuccessDialog(
        onContinue: () {
          Navigator.of(context).pop();
          Navigator.pushReplacementNamed(context, AppRouter.home);
        },
      ),
    );
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
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: size.height - topPad),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      // Header
                      FadeTransition(
                        opacity: _headerFade,
                        child: SlideTransition(
                          position: _headerSlide,
                          child: _buildHeader(),
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
                            child: ErrorBanner(
                              message: auth.errorMessage!,
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

                      const SizedBox(height: 24),

                      // Login link
                      FadeTransition(
                        opacity: _formFade,
                        child: _buildLoginLink(),
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
              top: -size.height * 0.05 + t * 25,
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

  // ── Header ────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back + logo row
        Row(
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
        ),
        const SizedBox(height: 28),
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Create\n',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontFamily: 'Poppins',
                  height: 1.1,
                ),
              ),
              TextSpan(
                text: 'Account',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  fontFamily: 'Poppins',
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Join thousands of women staying safe with AI',
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.42),
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }

  // ── Form ──────────────────────────────────────────────────────
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Full name
          AppTextField(
            label: 'Full Name',
            hint: 'Your full name',
            prefixPainter: const _PersonIconPainter(color: AppColors.primary),
            controller: _nameController,
            focusNode: _nameFocus,
            nextFocusNode: _emailFocus,
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Name is required';
              if (val.trim().length < 2) return 'Name too short';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Email
          AppTextField(
            label: 'Email Address',
            hint: 'your@email.com',
            prefixPainter: const EmailIconPainter(color: AppColors.primary),
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            focusNode: _emailFocus,
            nextFocusNode: _phoneFocus,
            validator: (val) {
              if (val == null || val.isEmpty) return 'Email is required';
              if (!RegExp(AppConstants.emailRegex).hasMatch(val)) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Phone
          AppTextField(
            label: 'Phone Number (Optional)',
            hint: '9876543210',
            prefixPainter: const PhoneIconPainter(color: AppColors.primary),
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            focusNode: _phoneFocus,
            nextFocusNode: _passwordFocus,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (val) {
              if (val != null && val.isNotEmpty && val.length != 10) {
                return 'Enter a valid 10-digit number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Password
          AppTextField(
            label: 'Password',
            hint: 'Min 8 chars with number',
            prefixPainter: const LockIconPainter(color: AppColors.primary),
            controller: _passwordController,
            isPassword: true,
            focusNode: _passwordFocus,
            nextFocusNode: _confirmFocus,
            validator: (val) {
              if (val == null || val.isEmpty) return 'Password is required';
              if (val.length < 8) return 'At least 8 characters required';
              if (!RegExp(r'(?=.*[0-9])').hasMatch(val)) {
                return 'Must include a number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Confirm password
          AppTextField(
            label: 'Confirm Password',
            hint: 'Re-enter your password',
            prefixPainter: const LockIconPainter(color: AppColors.primary),
            controller: _confirmController,
            isPassword: true,
            focusNode: _confirmFocus,
            textInputAction: TextInputAction.done,
            validator: (val) {
              if (val == null || val.isEmpty) return 'Please confirm password';
              if (val != _passwordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Terms checkbox
          _TermsCheckbox(
            agreed: _agreedToTerms,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _agreedToTerms = !_agreedToTerms);
            },
          ),
          const SizedBox(height: 26),

          // Register button
          Consumer<AuthProvider>(
            builder: (_, auth, __) => GradientButton(
              text: 'Create Account',
              onTap: _register,
              isLoading: auth.isLoading,
              iconPainter: const ShieldIconPainter(
                color: Colors.white,
                filled: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Login link ────────────────────────────────────────────────
  Widget _buildLoginLink() {
    return Center(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.pushReplacementNamed(context, AppRouter.login);
        },
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
            children: [
              TextSpan(
                text: 'Already have an account? ',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.42)),
              ),
              const TextSpan(
                text: 'Sign In',
                style: TextStyle(
                  color: AppColors.primary,
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

// ── Terms checkbox ────────────────────────────────────────────────
class _TermsCheckbox extends StatelessWidget {
  final bool agreed;
  final VoidCallback onTap;

  const _TermsCheckbox({required this.agreed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: agreed ? AppColors.primaryGradient : null,
              color: agreed ? null : Colors.transparent,
              border: Border.all(
                color: agreed
                    ? AppColors.primary
                    : Colors.white.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: agreed
                ? Center(
              child: CustomPaint(
                size: const Size(12, 12),
                painter: _CheckMarkPainter(),
              ),
            )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Poppins',
                  color: Colors.white.withValues(alpha: 0.55),
                  height: 1.5,
                ),
                children: const [
                  TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Terms of Service',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
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
}

// ── Success dialog ────────────────────────────────────────────────
class _SuccessDialog extends StatelessWidget {
  final VoidCallback onContinue;
  const _SuccessDialog({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.20),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success icon
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.safeGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.safeGreen.withValues(alpha: 0.35),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(38, 38),
                  painter: _LargeCheckPainter(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Account Created!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Welcome to SafeHer! Your account has been successfully created.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'Poppins',
                color: Colors.white.withValues(alpha: 0.55),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: onContinue,
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.38),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Start My Safety Journey',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
// CUSTOM PAINTERS — local to this file
// ════════════════════════════════════════════════════════════════

class _PersonIconPainter extends CustomPainter {
  final Color color;
  const _PersonIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Head circle
    canvas.drawCircle(Offset(w * 0.50, h * 0.28), w * 0.20, p);
    // Body arc
    final body = Path();
    body.moveTo(w * 0.05, h);
    body.quadraticBezierTo(w * 0.05, h * 0.60, w * 0.50, h * 0.60);
    body.quadraticBezierTo(w * 0.95, h * 0.60, w * 0.95, h);
    canvas.drawPath(body, p);
  }

  @override
  bool shouldRepaint(_PersonIconPainter old) => old.color != color;
}

class _CheckMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(size.width * 0.15, size.height * 0.50);
    path.lineTo(size.width * 0.42, size.height * 0.75);
    path.lineTo(size.width * 0.85, size.height * 0.25);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_CheckMarkPainter old) => false;
}

class _LargeCheckPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(size.width * 0.18, size.height * 0.52);
    path.lineTo(size.width * 0.42, size.height * 0.74);
    path.lineTo(size.width * 0.82, size.height * 0.28);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_LargeCheckPainter old) => false;
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
    final cx = size.width / 2;
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