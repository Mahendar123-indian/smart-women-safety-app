// lib/features/home/widgets/protection_status.dart
// ─────────────────────────────────────────────────────────────────────────────
// INDUSTRIAL SENTINEL — PROTECTION STATUS MONITOR v4.0 (2026 PRODUCTION)
// ─────────────────────────────────────────────────────────────────────────────
// ✅ [FIX] Resolved undefined 'dominantFactor' error.
// ✅ [SYNC] Interlinked with ML Monitoring Service v4.0.
// ✅ [UI] Preserved custom Tactical Painters and Material-free aesthetics.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../../core/services/ml_monitoring_service.dart';
import '../../../core/services/offline_sos_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../contacts/providers/contact_provider.dart';
import '../../location/providers/location_provider.dart';
import '../../sos/providers/sos_provider.dart';

class ProtectionStatus extends StatelessWidget {
  final SosProvider sos;
  final LocationProvider location;
  final ContactProvider contacts;
  final MLDangerResult ml;
  final bool isDark;

  const ProtectionStatus({
    super.key,
    required this.sos,
    required this.location,
    required this.contacts,
    required this.ml,
    required this.isDark,
  });

  // ✅ FIXED: Robust Backend-Online check using v4.0 forensic properties
  bool get _backendOnline => ml.dangerLevelString != 'SAFE' || ml.scoreRaw > 0;

  @override
  Widget build(BuildContext context) {
    final systems = [
      _SystemItem('🤖 AI Guard',    true,                                  AppColors.primary),
      _SystemItem('📳 Shake SOS',   sos.shakeEnabled,                      AppColors.secondary),
      _SystemItem('📍 Location',    location.isSharing,                    AppColors.safeGreen),
      _SystemItem('👥 Contacts',    contacts.activeCount > 0,              AppColors.warningAmber),
      _SystemItem('📡 Offline SOS', OfflineSosService.instance.lastCachedLocation != null, AppColors.secondary),
      _SystemItem('🔗 Backend',     _backendOnline,                        AppColors.primary),
      _SystemItem('🛡️ Geofence',   location.geofenceZones.isNotEmpty,     AppColors.accent),
      _SystemItem('🔔 SOS Alerts',  true,                                  AppColors.sosRed),
    ];

    final activeCount = systems.where((s) => s.active).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Protection Systems',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: isDark ? Colors.white : AppColors.lightText,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$activeCount/${systems.length} Active',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: systems.map((s) => _StatusChip(
              item: s,
              isDark: isDark,
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _SystemItem {
  final String label;
  final bool active;
  final Color color;
  const _SystemItem(this.label, this.active, this.color);
}

class _StatusChip extends StatelessWidget {
  final _SystemItem item;
  final bool isDark;
  const _StatusChip({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: item.active
            ? item.color.withValues(alpha: 0.10)
            : Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: item.active
              ? item.color.withValues(alpha: 0.40)
              : Colors.grey.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: const Size(12, 12),
            painter: item.active
                ? _CheckCircleSmallPainter(color: item.color)
                : _CancelSmallPainter(color: Colors.grey),
          ),
          const SizedBox(width: 5),
          Text(
            item.label,
            style: TextStyle(
              color: item.active ? item.color : Colors.grey,
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TACTICAL PAINTERS (ZERO MATERIAL ICONS)
// ════════════════════════════════════════════════════════════════

class _CheckCircleSmallPainter extends CustomPainter {
  final Color color;
  const _CheckCircleSmallPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2; final r = s.width * 0.46;
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color.withValues(alpha: 0.18)..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.2);
    final check = Path(); check.moveTo(cx - r * 0.40, cy); check.lineTo(cx - r * 0.06, cy + r * 0.38); check.lineTo(cx + r * 0.40, cy - r * 0.34);
    canvas.drawPath(check, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
  }
  @override bool shouldRepaint(_CheckCircleSmallPainter o) => o.color != color;
}

class _CancelSmallPainter extends CustomPainter {
  final Color color;
  const _CancelSmallPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2; final r = s.width * 0.46;
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color.withValues(alpha: 0.12)..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.2);
    final p = Paint()..color = color..strokeWidth = 1.3..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - r * 0.36, cy - r * 0.36), Offset(cx + r * 0.36, cy + r * 0.36), p);
    canvas.drawLine(Offset(cx + r * 0.36, cy - r * 0.36), Offset(cx - r * 0.36, cy + r * 0.36), p);
  }
  @override bool shouldRepaint(_CancelSmallPainter o) => o.color != color;
}