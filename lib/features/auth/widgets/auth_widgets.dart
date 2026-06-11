// lib/features/auth/widgets/auth_widgets.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';

// ════════════════════════════════════════════════════════════════
// APP TEXT FIELD  — animated focus border, custom icons
// ════════════════════════════════════════════════════════════════
class AppTextField extends StatefulWidget {
  final String label;
  final String hint;
  final CustomPainter prefixPainter;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final bool isPassword;
  final bool enabled;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final FocusNode? focusNode;
  final FocusNode? nextFocusNode;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final void Function(String)? onChanged;

  const AppTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.prefixPainter,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.focusNode,
    this.nextFocusNode,
    this.inputFormatters,
    this.enabled = true,
    this.maxLength,
    this.onChanged,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField>
    with SingleTickerProviderStateMixin {
  bool _obscure   = true;
  bool _isFocused = false;

  late AnimationController _focusCtrl;
  late Animation<double>   _focusAnim;

  @override
  void initState() {
    super.initState();
    _focusCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _focusAnim = CurvedAnimation(
      parent: _focusCtrl,
      curve: Curves.easeOut,
    );
    widget.focusNode?.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    final focused = widget.focusNode?.hasFocus ?? false;
    if (mounted) setState(() => _isFocused = focused);
    focused ? _focusCtrl.forward() : _focusCtrl.reverse();
  }

  @override
  void dispose() {
    widget.focusNode?.removeListener(_onFocusChange);
    _focusCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Animated label
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              fontFamily: 'Poppins',
              color: _isFocused
                  ? AppColors.primary
                  : isDark
                  ? Colors.white.withValues(alpha: 0.45)
                  : AppColors.lightTextSecondary,
            ),
            child: Text(widget.label.toUpperCase()),
          ),
        ),

        // Animated border container
        AnimatedBuilder(
          animation: _focusAnim,
          builder: (_, __) => Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Color.lerp(
                  isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : AppColors.lightBorder,
                  AppColors.primary,
                  _focusAnim.value,
                )!,
                width: 1.5,
              ),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.white.withValues(alpha: 0.85),
              boxShadow: _isFocused
                  ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 14,
                ),
              ]
                  : [],
            ),
            child: TextFormField(
              controller:       widget.controller,
              focusNode:        widget.focusNode,
              keyboardType:     widget.keyboardType,
              enabled:          widget.enabled,
              obscureText:      widget.isPassword && _obscure,
              textInputAction:  widget.textInputAction,
              inputFormatters:  widget.inputFormatters,
              maxLength:        widget.maxLength,
              onChanged:        widget.onChanged,
              onFieldSubmitted: (_) {
                if (widget.nextFocusNode != null) {
                  FocusScope.of(context).requestFocus(widget.nextFocusNode);
                }
              },
              validator: widget.validator,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.lightText,
                fontSize: 15,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                hintText:    widget.hint,
                counterText: '',
                hintStyle: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.22)
                      : AppColors.lightTextSecondary.withValues(alpha: 0.6),
                  fontSize: 14,
                  fontFamily: 'Poppins',
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _isFocused ? 1.0 : 0.45,
                    child: CustomPaint(
                      size: const Size(20, 20),
                      painter: widget.prefixPainter,
                    ),
                  ),
                ),
                suffixIcon: widget.isPassword
                    ? GestureDetector(
                  onTap: () => setState(() => _obscure = !_obscure),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: CustomPaint(
                      size: const Size(20, 20),
                      painter: _EyeIconPainter(
                        visible: !_obscure,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.35)
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                )
                    : null,
                border:             InputBorder.none,
                enabledBorder:      InputBorder.none,
                focusedBorder:      InputBorder.none,
                errorBorder:        InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                errorStyle: const TextStyle(
                  color:      AppColors.sosRed,
                  fontSize:   11,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// GRADIENT BUTTON  — press scale + loading state
// ════════════════════════════════════════════════════════════════
class GradientButton extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isLoading;
  final List<Color>? colors;
  final double height;
  final CustomPainter? iconPainter;

  const GradientButton({
    super.key,
    required this.text,
    required this.onTap,
    this.isLoading = false,
    this.colors,
    this.height = 56,
    this.iconPainter,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double>   _pressScale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradColors = widget.isLoading
        ? [Colors.grey.shade500, Colors.grey.shade600]
        : (widget.colors ?? [AppColors.primary, AppColors.secondary]);

    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) async {
        await _pressCtrl.reverse();
        if (!widget.isLoading) {
          HapticFeedback.mediumImpact();
          widget.onTap?.call();
        }
      },
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _pressScale,
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradColors,
              begin: Alignment.centerLeft,
              end:   Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: widget.isLoading
                ? []
                : [
              BoxShadow(
                color:  AppColors.primary.withValues(alpha: 0.38),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
              width:  22,
              height: 22,
              child: CircularProgressIndicator(
                color:       Colors.white,
                strokeWidth: 2.5,
              ),
            )
                : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.iconPainter != null) ...[
                  CustomPaint(
                    size: const Size(18, 18),
                    painter: widget.iconPainter!,
                  ),
                  const SizedBox(width: 9),
                ],
                Text(
                  widget.text,
                  style: const TextStyle(
                    color:       Colors.white,
                    fontSize:    16,
                    fontWeight:  FontWeight.w600,
                    fontFamily:  'Poppins',
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SOCIAL LOGIN BUTTON
// ════════════════════════════════════════════════════════════════
class SocialLoginButton extends StatefulWidget {
  final String label;
  final CustomPainter iconPainter;
  final VoidCallback onTap;
  final bool isLoading;

  const SocialLoginButton({
    super.key,
    required this.label,
    required this.iconPainter,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  State<SocialLoginButton> createState() => _SocialLoginButtonState();
}

class _SocialLoginButtonState extends State<SocialLoginButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) async {
        await _ctrl.reverse();
        if (!widget.isLoading) {
          HapticFeedback.selectionClick();
          widget.onTap();
        }
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : AppColors.lightBorder,
              width: 1,
            ),
            boxShadow: isDark ? [] : AppColors.cardShadow,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              widget.isLoading
                  ? SizedBox(
                width:  20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
                  : CustomPaint(
                size: const Size(22, 22),
                painter: widget.iconPainter,
              ),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.80)
                      : AppColors.lightText,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily:  'Poppins',
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
// OR DIVIDER
// ════════════════════════════════════════════════════════════════
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lineColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : AppColors.lightBorder;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, lineColor],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or continue with',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.32)
                  : AppColors.lightTextSecondary,
              fontFamily: 'Poppins',
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [lineColor, Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ERROR BANNER
// ════════════════════════════════════════════════════════════════
class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;

  const ErrorBanner({super.key, required this.message, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.sosRed.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.sosRed.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          CustomPaint(
            size: const Size(18, 18),
            painter: _AlertCircleIconPainter(color: AppColors.sosRed),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color:      AppColors.sosRed,
                fontSize:   12,
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          if (onDismiss != null)
            GestureDetector(
              onTap: onDismiss,
              child: CustomPaint(
                size: const Size(16, 16),
                painter: _CloseIconPainter(color: AppColors.sosRed),
              ),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SUCCESS BANNER
// ════════════════════════════════════════════════════════════════
class SuccessBanner extends StatelessWidget {
  final String message;

  const SuccessBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.safeGreen.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.safeGreen.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          CustomPaint(
            size: const Size(18, 18),
            painter: _CheckCircleIconPainter(color: AppColors.safeGreen),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color:      AppColors.safeGreen,
                fontSize:   12,
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// GLASS CARD
// ════════════════════════════════════════════════════════════════
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double borderRadius;
  final double opacity;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 20,
    this.opacity = 0.1,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: opacity)
            : Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

// ════════════════════════════════════════════════════════════════
// AUTH GRADIENT BACKGROUND
// ════════════════════════════════════════════════════════════════
class AuthGradientBackground extends StatelessWidget {
  final Widget child;
  const AuthGradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
          colors: [
            Color(0xFF0D0D1A),
            Color(0xFF120820),
            Color(0xFF0A1020),
          ],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        )
            : const LinearGradient(
          colors: [
            Color(0xFFFCE4EC),
            Color(0xFFEDE7F6),
            Color(0xFFE3F2FD),
          ],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
      ),
      child: child,
    );
  }
}

// ════════════════════════════════════════════════════════════════
// AUTH SECTION HEADER
// ════════════════════════════════════════════════════════════════
class AuthSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const AuthSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final parts = title.split(' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '${parts.first}\n',
                style: const TextStyle(
                  fontSize:    30,
                  fontWeight:  FontWeight.w700,
                  color:       Colors.white,
                  fontFamily:  'Poppins',
                  height:      1.1,
                ),
              ),
              TextSpan(
                text: parts.skip(1).join(' '),
                style: const TextStyle(
                  fontSize:   30,
                  fontWeight: FontWeight.w700,
                  color:      AppColors.primary,
                  fontFamily: 'Poppins',
                  height:     1.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            fontSize:   13,
            color:      Colors.white.withValues(alpha: 0.45),
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ── ALL CUSTOM ICON PAINTERS ──────────────────────────────────
// ════════════════════════════════════════════════════════════════

// Email icon
class EmailIconPainter extends CustomPainter {
  final Color color;
  const EmailIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap  = StrokeCap.round;

    // Envelope body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, h * 0.18, w, h * 0.64),
        const Radius.circular(3),
      ),
      p,
    );
    // V flap
    final flap = Path();
    flap.moveTo(0, h * 0.18);
    flap.lineTo(w * 0.50, h * 0.60);
    flap.lineTo(w, h * 0.18);
    canvas.drawPath(flap, p);
  }

  @override
  bool shouldRepaint(EmailIconPainter old) => old.color != color;
}

// Lock icon
class LockIconPainter extends CustomPainter {
  final Color color;
  const LockIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap  = StrokeCap.round;

    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.10, h * 0.44, w * 0.80, h * 0.52),
        const Radius.circular(4),
      ),
      p,
    );
    // Shackle
    final arc = Path();
    arc.moveTo(w * 0.30, h * 0.44);
    arc.lineTo(w * 0.30, h * 0.28);
    arc.quadraticBezierTo(w * 0.30, h * 0.06, w * 0.50, h * 0.06);
    arc.quadraticBezierTo(w * 0.70, h * 0.06, w * 0.70, h * 0.28);
    arc.lineTo(w * 0.70, h * 0.44);
    canvas.drawPath(arc, p);

    // Keyhole dot
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.68),
      w * 0.08,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(LockIconPainter old) => old.color != color;
}

// Shield icon (for button / top bar)
class ShieldIconPainter extends CustomPainter {
  final Color color;
  final bool filled;
  const ShieldIconPainter({required this.color, this.filled = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path();
    path.moveTo(w * 0.50, 0);
    path.lineTo(w, h * 0.22);
    path.cubicTo(w, h * 0.22, w * 0.98, h * 0.72, w * 0.50, h);
    path.cubicTo(w * 0.02, h * 0.72, 0, h * 0.22, 0, h * 0.22);
    path.close();

    if (filled) {
      canvas.drawPath(
        path,
        Paint()
          ..shader = const LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
          ).createShader(Rect.fromLTWH(0, 0, w, h)),
      );
    } else {
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill,
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth  = 1.4
        ..strokeJoin   = StrokeJoin.round,
    );

    // Check
    final check = Path();
    check.moveTo(w * 0.28, h * 0.52);
    check.lineTo(w * 0.44, h * 0.68);
    check.lineTo(w * 0.72, h * 0.36);
    canvas.drawPath(
      check,
      Paint()
        ..color      = filled ? Colors.white : color
        ..style      = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap  = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(ShieldIconPainter old) =>
      old.color != color || old.filled != filled;
}

// Google icon (4-color G logo)
class GoogleIconPainter extends CustomPainter {
  const GoogleIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final r  = w * 0.46;

    // Draw 4 arcs for G logo
    final colors = [
      const Color(0xFFEA4335), // red    — top-right
      const Color(0xFFFBBC05), // yellow — bottom-right
      const Color(0xFF34A853), // green  — bottom-left
      const Color(0xFF4285F4), // blue   — top-left
    ];

    for (int i = 0; i < 4; i++) {
      final startAngle = (-90 + i * 90) * (3.14159 / 180.0);
      final sweepAngle = 90 * (3.14159 / 180.0);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startAngle,
        sweepAngle,
        false,
        Paint()
          ..color       = colors[i]
          ..style       = PaintingStyle.stroke
          ..strokeWidth = w * 0.18,
      );
    }

    // White bar for G opening
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - w * 0.12, r + w * 0.10, w * 0.24),
      Paint()..color = Colors.white,
    );
    // Horizontal bar of G
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - w * 0.10, r * 0.9, w * 0.20),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(GoogleIconPainter old) => false;
}

// Phone icon
class PhoneIconPainter extends CustomPainter {
  final Color color;
  const PhoneIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin  = StrokeJoin.round
      ..strokeCap   = StrokeCap.round;

    // Phone body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.20, 0, w * 0.60, h),
        const Radius.circular(4),
      ),
      p,
    );
    // Screen
    canvas.drawRect(
      Rect.fromLTWH(w * 0.26, h * 0.14, w * 0.48, h * 0.60),
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill,
    );
    // Home button dot
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.86),
      w * 0.06,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(PhoneIconPainter old) => old.color != color;
}

// Eye icon (visibility toggle)
class _EyeIconPainter extends CustomPainter {
  final bool  visible;
  final Color color;
  const _EyeIconPainter({required this.visible, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint()
      ..color      = color
      ..style      = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap  = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (visible) {
      // Eye outline
      final eye = Path();
      eye.moveTo(0, h * 0.50);
      eye.cubicTo(w * 0.25, h * 0.15, w * 0.75, h * 0.15, w, h * 0.50);
      eye.cubicTo(w * 0.75, h * 0.85, w * 0.25, h * 0.85, 0, h * 0.50);
      canvas.drawPath(eye, p);
      // Pupil
      canvas.drawCircle(
        Offset(w * 0.50, h * 0.50),
        w * 0.16,
        Paint()..color = color,
      );
    } else {
      // Eye with slash
      final eye = Path();
      eye.moveTo(0, h * 0.50);
      eye.cubicTo(w * 0.25, h * 0.15, w * 0.75, h * 0.15, w, h * 0.50);
      eye.cubicTo(w * 0.75, h * 0.85, w * 0.25, h * 0.85, 0, h * 0.50);
      canvas.drawPath(
        eye,
        Paint()
          ..color      = color.withValues(alpha: 0.35)
          ..style      = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      // Diagonal slash
      canvas.drawLine(
        Offset(w * 0.20, h * 0.82),
        Offset(w * 0.80, h * 0.18),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_EyeIconPainter old) =>
      old.visible != visible || old.color != color;
}

// Alert circle (!) icon
class _AlertCircleIconPainter extends CustomPainter {
  final Color color;
  const _AlertCircleIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final r  = size.width  * 0.46;

    canvas.drawCircle(
      Offset(cx, cy), r,
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(cx, cy), r,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Exclamation body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - size.width * 0.07, cy - r * 0.72,
            size.width * 0.14, r * 0.80),
        const Radius.circular(2),
      ),
      Paint()..color = color,
    );
    // Dot
    canvas.drawCircle(
      Offset(cx, cy + r * 0.52),
      size.width * 0.07,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_AlertCircleIconPainter old) => old.color != color;
}

// Check circle icon
class _CheckCircleIconPainter extends CustomPainter {
  final Color color;
  const _CheckCircleIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final r  = size.width  * 0.46;

    canvas.drawCircle(
      Offset(cx, cy), r,
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(cx, cy), r,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    final check = Path();
    check.moveTo(cx - r * 0.45, cy);
    check.lineTo(cx - r * 0.10, cy + r * 0.42);
    check.lineTo(cx + r * 0.45, cy - r * 0.38);
    canvas.drawPath(
      check,
      Paint()
        ..color      = color
        ..style      = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap  = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckCircleIconPainter old) => old.color != color;
}

// Close (X) icon
class _CloseIconPainter extends CustomPainter {
  final Color color;
  const _CloseIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color      = color
      ..style      = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap  = StrokeCap.round;

    canvas.drawLine(Offset(0, 0), Offset(size.width, size.height), p);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), p);
  }

  @override
  bool shouldRepaint(_CloseIconPainter old) => old.color != color;
}