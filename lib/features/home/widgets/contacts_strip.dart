// lib/features/home/widgets/contacts_strip.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../contacts/providers/contact_provider.dart';

class ContactsStrip extends StatelessWidget {
  final ContactProvider contacts;
  final bool isDark;

  const ContactsStrip({super.key, required this.contacts, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (contacts.contacts.isEmpty) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.pushNamed(context, AppRouter.contacts);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppColors.cardShadow,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.20)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: CustomPaint(
                    size: const Size(20, 20),
                    painter: _PersonAddPainter(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Emergency Contacts',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: isDark ? Colors.white : AppColors.lightText,
                      ),
                    ),
                    Text(
                      'They\'ll be alerted instantly in SOS',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.40)
                            : AppColors.lightTextSecondary,
                        fontSize: 11,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
              CustomPaint(
                size: const Size(12, 12),
                painter: _ChevronRightPainter(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.30)
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 92,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: contacts.contacts.length + 1,
        itemBuilder: (_, i) {
          if (i == contacts.contacts.length) {
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.pushNamed(context, AppRouter.contacts);
              },
              child: Container(
                width: 72,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  color: AppColors.primary.withValues(alpha: 0.05),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: CustomPaint(
                          size: const Size(14, 14),
                          painter: _PlusPainter(color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Add',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final c = contacts.contacts[i];
          return Container(
            width: 76,
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: AppColors.cardShadow,
              border: c.isPrimary
                  ? Border.all(color: AppColors.primary.withValues(alpha: 0.45))
                  : Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : AppColors.lightBorder,
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar with status indicator
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: c.isPrimary
                            ? AppColors.primaryGradient
                            : AppColors.purpleGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (c.isPrimary
                                ? AppColors.primary
                                : AppColors.secondary)
                                .withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ),
                    // Active indicator
                    if (c.isActive)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.safeGreen,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? AppColors.darkCard : Colors.white,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  c.name.split(' ').first,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.lightText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                if (c.isPrimary || c.isAppUser)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      c.isPrimary ? '⭐' : '📱',
                      style: const TextStyle(fontSize: 8),
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

// ════════════════════════════════════════════════════════════════
// PAINTERS
// ════════════════════════════════════════════════════════════════

class _PersonAddPainter extends CustomPainter {
  final Color color;
  const _PersonAddPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Head circle
    canvas.drawCircle(Offset(s.width * 0.38, s.height * 0.26), s.width * 0.18, p);
    // Body arc
    final body = Path();
    body.moveTo(0, s.height);
    body.quadraticBezierTo(0, s.height * 0.58, s.width * 0.38, s.height * 0.58);
    body.quadraticBezierTo(s.width * 0.72, s.height * 0.58, s.width * 0.72, s.height);
    canvas.drawPath(body, p);
    // Plus sign
    canvas.drawLine(Offset(s.width * 0.82, s.height * 0.28),
        Offset(s.width * 0.82, s.height * 0.68), p);
    canvas.drawLine(Offset(s.width * 0.62, s.height * 0.48),
        Offset(s.width * 1.02, s.height * 0.48), p);
  }

  @override
  bool shouldRepaint(_PersonAddPainter o) => o.color != color;
}

class _PlusPainter extends CustomPainter {
  final Color color;
  const _PlusPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(s.width / 2, 0), Offset(s.width / 2, s.height), p);
    canvas.drawLine(Offset(0, s.height / 2), Offset(s.width, s.height / 2), p);
  }

  @override
  bool shouldRepaint(_PlusPainter o) => o.color != color;
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