// lib/features/auth/screens/otp_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_widgets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/router/app_router.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen>
    with TickerProviderStateMixin {
  final List<TextEditingController> _controllers =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
  List.generate(6, (_) => FocusNode());

  Timer? _timer;
  int  _secondsRemaining = 60;
  bool _canResend        = false;

  // ── Animations ────────────────────────────────────────────────
  late AnimationController _bgCtrl;
  late AnimationController _entryCtrl;
  late AnimationController _iconFloatCtrl;
  late AnimationController _timerPulseCtrl;
  late Animation<double>   _contentFade;
  late Animation<Offset>   _contentSlide;
  late Animation<double>   _iconFloat;
  late Animation<double>   _timerPulse;

  // Track filled boxes for styling
  final List<bool> _filled = List.generate(6, (_) => false);

  @override
  void initState() {
    super.initState();
    _setupControllers();
    _startTimer();
    _entryCtrl.forward();
  }

  void _setupControllers() {
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

    _timerPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _timerPulse = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _timerPulseCtrl, curve: Curves.easeInOut),
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
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 60;
      _canResend        = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        timer.cancel();
        if (mounted) setState(() => _canResend = true);
      } else {
        if (mounted) setState(() => _secondsRemaining--);
      }
    });
  }

  String get _otp => _controllers.map((c) => c.text).join();

  // ── Auth logic (unchanged) ────────────────────────────────────
  void _onOtpDigitChanged(int index, String value) {
    setState(() => _filled[index] = value.isNotEmpty);

    if (value.isNotEmpty && index < 5) {
      FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
    } else if (value.isEmpty && index > 0) {
      FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
    }

    if (_otp.length == 6) _verifyOtp();
  }

  Future<void> _verifyOtp() async {
    if (_otp.length != 6) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();

    final success = await context.read<AuthProvider>().verifyOtp(otp: _otp);
    if (success && mounted) {
      Navigator.pushReplacementNamed(context, AppRouter.home);
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;
    HapticFeedback.selectionClick();
    await context.read<AuthProvider>().sendOtp(widget.phone);
    _startTimer();
    for (var c in _controllers) c.clear();
    setState(() {
      for (int i = 0; i < 6; i++) _filled[i] = false;
    });
    FocusScope.of(context).requestFocus(_focusNodes[0]);
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
    _bgCtrl.dispose();
    _entryCtrl.dispose();
    _iconFloatCtrl.dispose();
    _timerPulseCtrl.dispose();
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
                              const SizedBox(height: 32),

                              // Error banner
                              Consumer<AuthProvider>(
                                builder: (_, auth, __) => AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 280),
                                  child: auth.errorMessage != null
                                      ? Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: ErrorBanner(
                                      message: auth.errorMessage!,
                                    ),
                                  )
                                      : const SizedBox.shrink(),
                                ),
                              ),

                              // OTP boxes
                              _buildOtpRow(),
                              const SizedBox(height: 28),

                              // Timer / resend
                              _buildTimerSection(),
                              const SizedBox(height: 32),

                              // Verify button
                              Consumer<AuthProvider>(
                                builder: (_, auth, __) => GradientButton(
                                  text: 'Verify & Continue',
                                  onTap: _verifyOtp,
                                  isLoading: auth.isLoading,
                                  iconPainter: const ShieldIconPainter(
                                    color: Colors.white,
                                    filled: false,
                                  ),
                                ),
                              ),

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

  // ── Icon section ──────────────────────────────────────────────
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
                painter: _SmsIconPainter(),
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
                text: 'Verify\n',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontFamily: 'Poppins',
                  height: 1.1,
                ),
              ),
              TextSpan(
                text: 'Your Number',
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
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.42),
            ),
            children: [
              const TextSpan(text: 'OTP sent to '),
              TextSpan(
                text: widget.phone,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── OTP boxes row ─────────────────────────────────────────────
  Widget _buildOtpRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (index) => _buildOtpBox(index)),
    );
  }

  Widget _buildOtpBox(int index) {
    final isFilled = _filled[index];
    final isFocused = _focusNodes[index].hasFocus;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 46,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isFilled
            ? AppColors.primary.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: isFocused
              ? AppColors.primary
              : isFilled
              ? AppColors.primary.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.08),
          width: isFocused ? 2.0 : 1.5,
        ),
        boxShadow: isFocused
            ? [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 12,
          ),
        ]
            : [],
      ),
      child: TextFormField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          fontFamily: 'Poppins',
          color: isFilled ? AppColors.primary : Colors.white,
        ),
        decoration: const InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        onChanged: (val) => _onOtpDigitChanged(index, val),
      ),
    );
  }

  // ── Timer section ─────────────────────────────────────────────
  Widget _buildTimerSection() {
    return Center(
      child: _canResend
          ? GestureDetector(
        onTap: _resendOtp,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: const Text(
            'Resend OTP',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
              fontSize: 14,
            ),
          ),
        ),
      )
          : AnimatedBuilder(
        animation: _timerPulse,
        builder: (_, __) => Opacity(
          opacity: _timerPulse.value,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: const Size(14, 14),
                painter: _TimerIconPainter(),
              ),
              const SizedBox(width: 8),
              Text(
                'Resend OTP in ${_secondsRemaining}s',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.40),
                  fontFamily: 'Poppins',
                  fontSize: 13,
                ),
              ),
            ],
          ),
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
// PAINTERS
// ════════════════════════════════════════════════════════════════

class _SmsIconPainter extends CustomPainter {
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

    // Message bubble
    final bubble = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h * 0.74),
      const Radius.circular(8),
    );
    canvas.drawRRect(bubble, p);

    // Tail
    final tail = Path();
    tail.moveTo(w * 0.20, h * 0.74);
    tail.lineTo(w * 0.14, h);
    tail.lineTo(w * 0.36, h * 0.74);
    canvas.drawPath(tail, p);

    // Dots inside bubble
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(w * (0.28 + i * 0.22), h * 0.36),
        w * 0.06,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(_SmsIconPainter old) => false;
}

class _TimerIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width * 0.46;
    final p  = Paint()
      ..color = Colors.white.withValues(alpha: 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(cx, cy), r, p);
    // Clock hands
    canvas.drawLine(Offset(cx, cy), Offset(cx, cy - r * 0.55), p);
    canvas.drawLine(Offset(cx, cy), Offset(cx + r * 0.40, cy), p);
  }

  @override
  bool shouldRepaint(_TimerIconPainter old) => false;
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