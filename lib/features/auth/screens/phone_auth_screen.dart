// lib/features/auth/screens/phone_auth_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_widgets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/router/app_router.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen>
    with TickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _phoneFocus      = FocusNode();
  final _formKey         = GlobalKey<FormState>();

  String _selectedCountryCode = '+91';
  bool   _sending             = false;
  String _pendingPhone        = '';

  late AuthProvider _authProvider;

  // ── Animations ────────────────────────────────────────────────
  late AnimationController _bgCtrl;
  late AnimationController _entryCtrl;
  late AnimationController _iconFloatCtrl;
  late Animation<double>   _contentFade;
  late Animation<Offset>   _contentSlide;
  late Animation<double>   _iconFloat;

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _iconFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _iconFloat = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _iconFloatCtrl, curve: Curves.easeInOut),
    );

    _contentFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.2, 0.85, curve: Curves.easeOut),
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.2, 0.85, curve: Curves.easeOutCubic),
    ));

    _entryCtrl.forward();

    // Capture provider reference
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authProvider = context.read<AuthProvider>();
      _authProvider.addListener(_onAuthChanged);
    });
  }

  void _onAuthChanged() {
    if (!mounted) return;
    if (_authProvider.otpSent && _pendingPhone.isNotEmpty) {
      final phone  = _pendingPhone;
      _pendingPhone = '';
      setState(() => _sending = false);
      Navigator.pushNamed(context, AppRouter.otp, arguments: {'phone': phone});
    }
    if (_authProvider.errorMessage != null && _sending) {
      setState(() => _sending = false);
    }
  }

  // ── Auth logic (unchanged) ────────────────────────────────────
  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();

    final phone = '$_selectedCountryCode${_phoneController.text.trim()}';
    setState(() {
      _sending      = true;
      _pendingPhone = phone;
    });

    await _authProvider.sendOtp(phone);

    if (mounted && _sending && _authProvider.errorMessage != null) {
      setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    _phoneController.dispose();
    _phoneFocus.dispose();
    _bgCtrl.dispose();
    _entryCtrl.dispose();
    _iconFloatCtrl.dispose();
    super.dispose();
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
                      _buildTopBar(),
                      const SizedBox(height: 36),
                      _buildIconSection(),
                      const SizedBox(height: 32),

                      FadeTransition(
                        opacity: _contentFade,
                        child: SlideTransition(
                          position: _contentSlide,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeading(),
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

                              _buildForm(),
                              const SizedBox(height: 36),
                            ],
                          ),
                        ),
                      ),
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
              top: -size.height * 0.06 + t * 26,
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

  // ── Floating icon ─────────────────────────────────────────────
  Widget _buildIconSection() {
    return Center(
      child: AnimatedBuilder(
        animation: _iconFloat,
        builder: (_, __) => Transform.translate(
          offset: Offset(0, _iconFloat.value),
          child: Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.40),
                  blurRadius: 28,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: CustomPaint(
                size: const Size(40, 40),
                painter: _PhoneRingIconPainter(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Heading ───────────────────────────────────────────────────
  Widget _buildHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Phone\n',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontFamily: 'Poppins',
                  height: 1.1,
                ),
              ),
              TextSpan(
                text: 'Verification',
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
        const SizedBox(height: 8),
        Text(
          "We'll send a 6-digit OTP to verify your number.",
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.42),
            fontFamily: 'Poppins',
            height: 1.55,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              'PHONE NUMBER',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                fontFamily: 'Poppins',
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ),

          Row(
            children: [
              // Country code picker
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1.5,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCountryCode,
                    dropdownColor: AppColors.darkCard,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    items: ['+91', '+1', '+44', '+61', '+971']
                        .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c),
                    ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedCountryCode = v!),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Phone field
              Expanded(
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _phoneFocus.hasFocus
                          ? AppColors.primary
                          : Colors.white.withValues(alpha: 0.08),
                      width: 1.5,
                    ),
                  ),
                  child: TextFormField(
                    controller: _phoneController,
                    focusNode: _phoneFocus,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontFamily: 'Poppins',
                    ),
                    decoration: InputDecoration(
                      hintText: '9876543210',
                      counterText: '',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.22),
                        fontSize: 14,
                        fontFamily: 'Poppins',
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      errorStyle: const TextStyle(
                        color: AppColors.sosRed,
                        fontSize: 11,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Phone required';
                      if (v.length < 10) return 'Enter valid 10-digit number';
                      return null;
                    },
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          GradientButton(
            text: 'Send OTP',
            onTap: _sending ? null : _sendOtp,
            isLoading: _sending,
            iconPainter: const _SendIconPainter(),
          ),
        ],
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
// PAINTERS
// ════════════════════════════════════════════════════════════════

class _PhoneRingIconPainter extends CustomPainter {
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

    // Phone body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.22, h * 0.04, w * 0.56, h * 0.84),
        const Radius.circular(6),
      ),
      p,
    );
    // Screen
    canvas.drawRect(
      Rect.fromLTWH(w * 0.28, h * 0.16, w * 0.44, h * 0.54),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill,
    );
    // Home dot
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.82),
      w * 0.06,
      Paint()..color = Colors.white,
    );
    // Signal arcs top-right
    for (int i = 1; i <= 2; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(w * 0.82, h * 0.18), radius: i * 5.0),
        -2.2, 1.2, false,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.60)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_PhoneRingIconPainter old) => false;
}

class _SendIconPainter extends CustomPainter {
  const _SendIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Arrow right
    canvas.drawLine(
      Offset(size.width * 0.15, size.height / 2),
      Offset(size.width * 0.82, size.height / 2),
      p,
    );
    final head = Path();
    head.moveTo(size.width * 0.56, size.height * 0.22);
    head.lineTo(size.width * 0.82, size.height / 2);
    head.lineTo(size.width * 0.56, size.height * 0.78);
    canvas.drawPath(head, p);
  }

  @override
  bool shouldRepaint(_SendIconPainter old) => false;
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