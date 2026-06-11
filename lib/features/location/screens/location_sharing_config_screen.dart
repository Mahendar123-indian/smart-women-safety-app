// lib/features/location/screens/location_sharing_config_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// LOCATION SHARING CONFIG — Zero Material Icons · Dark Theme Matched
// Granular control: when, how precise, what data, contact notifications
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';

enum SharingMode { always, nightOnly, journeyOnly, sosOnly, manual, never }
enum SharingPrecision { exact, neighborhood, city }

class LocationSharingConfigScreen extends StatefulWidget {
  const LocationSharingConfigScreen({super.key});
  @override
  State<LocationSharingConfigScreen> createState() =>
      _LocationSharingConfigScreenState();
}

class _LocationSharingConfigScreenState
    extends State<LocationSharingConfigScreen>
    with TickerProviderStateMixin {

  late AnimationController _entryCtrl;
  late Animation<double>   _entryFade;
  late AnimationController _bgCtrl;

  SharingMode      _mode                = SharingMode.nightOnly;
  SharingPrecision _precision           = SharingPrecision.exact;
  bool _shareSpeed                      = true;
  bool _shareAltitude                   = false;
  bool _shareAddress                    = true;
  bool _notifyContactsOnStart           = true;
  bool _notifyContactsOnStop            = true;
  bool _autoStopOnArrival               = true;
  int  _autoStopMinutes                 = 30;
  bool _saving                          = false;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entryCtrl.forward();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sharing_mode', _mode.name);
    await prefs.setString('sharing_precision', _precision.name);
    await prefs.setBool('share_speed', _shareSpeed);
    await prefs.setBool('share_altitude', _shareAltitude);
    await prefs.setBool('share_address', _shareAddress);
    await prefs.setBool('notify_on_start', _notifyContactsOnStart);
    await prefs.setBool('notify_on_stop', _notifyContactsOnStop);
    await prefs.setBool('auto_stop_arrival', _autoStopOnArrival);
    await prefs.setInt('auto_stop_minutes', _autoStopMinutes);
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Location sharing settings saved',
            style: TextStyle(fontFamily: 'Poppins', color: Colors.white)),
        backgroundColor: AppColors.safeGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          _buildBackground(size),
          SafeArea(
            child: FadeTransition(
              opacity: _entryFade,
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      children: [
                        // ── When to Share ──────────────────────
                        _ConfigSection(
                          painter: _SchedulePainter(color: AppColors.primary),
                          iconColor: AppColors.primary,
                          title: 'When to Share',
                          child: Column(
                            children: SharingMode.values.map((mode) =>
                                _ModeOption(
                                  mode: mode,
                                  selected: _mode == mode,
                                  onTap: () { HapticFeedback.selectionClick(); setState(() => _mode = mode); },
                                )).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Precision ──────────────────────────
                        _ConfigSection(
                          painter: _GpsCrosshairPainter(color: AppColors.secondary),
                          iconColor: AppColors.secondary,
                          title: 'Location Precision',
                          child: Column(
                            children: SharingPrecision.values.map((p) =>
                                _PrecisionOption(
                                  precision: p,
                                  selected: _precision == p,
                                  onTap: () { HapticFeedback.selectionClick(); setState(() => _precision = p); },
                                )).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Data Shared ────────────────────────
                        _ConfigSection(
                          painter: _DataIconPainter(color: AppColors.warningAmber),
                          iconColor: AppColors.warningAmber,
                          title: 'Data Shared with Contacts',
                          child: Column(children: [
                            _SwitchRow(painter: _SpeedPainter(color: Colors.grey), label: 'Show Speed',
                                value: _shareSpeed, onChanged: (v) => setState(() => _shareSpeed = v)),
                            _SwitchRow(painter: _LocationDotPainter(color: Colors.grey), label: 'Show Address',
                                value: _shareAddress, onChanged: (v) => setState(() => _shareAddress = v)),
                            _SwitchRow(painter: _AltitudePainter(color: Colors.grey), label: 'Show Altitude',
                                value: _shareAltitude, onChanged: (v) => setState(() => _shareAltitude = v)),
                          ]),
                        ),
                        const SizedBox(height: 12),

                        // ── Notifications ──────────────────────
                        _ConfigSection(
                          painter: _BellSmallPainter(color: AppColors.safeGreen),
                          iconColor: AppColors.safeGreen,
                          title: 'Contact Notifications',
                          child: Column(children: [
                            _SwitchRow(
                              painter: _PlaySmallPainter(color: Colors.grey),
                              label: 'Notify when sharing starts',
                              value: _notifyContactsOnStart,
                              onChanged: (v) => setState(() => _notifyContactsOnStart = v),
                            ),
                            _SwitchRow(
                              painter: _StopSmallPainter(color: Colors.grey),
                              label: 'Notify when sharing stops',
                              value: _notifyContactsOnStop,
                              onChanged: (v) => setState(() => _notifyContactsOnStop = v),
                            ),
                            _SwitchRow(
                              painter: _FlagSmallPainter(color: Colors.grey),
                              label: 'Auto-stop on arrival',
                              value: _autoStopOnArrival,
                              onChanged: (v) => setState(() => _autoStopOnArrival = v),
                            ),
                            if (_autoStopOnArrival) ...[
                              const SizedBox(height: 12),
                              Row(children: [
                                CustomPaint(size: const Size(16, 16), painter: _TimerPainter(color: AppColors.warningAmber)),
                                const SizedBox(width: 8),
                                const Expanded(child: Text('Stop sharing after arrival:',
                                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.white))),
                                _TimeDropdown(
                                  value: _autoStopMinutes,
                                  onChanged: (v) => setState(() => _autoStopMinutes = v ?? 30),
                                ),
                              ]),
                            ],
                          ]),
                        ),
                        const SizedBox(height: 12),

                        // ── Privacy Info ───────────────────────
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              CustomPaint(size: const Size(16, 16), painter: _InfoSmallPainter(color: Colors.white)),
                              const SizedBox(width: 8),
                              const Text('Your Privacy', style: TextStyle(color: Colors.white,
                                  fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 13)),
                            ]),
                            const SizedBox(height: 8),
                            Text(
                              'Location is only visible to your emergency contacts. Police dispatch uses location only during active SOS. You can stop sharing at any time.',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.80),
                                  fontFamily: 'Poppins', fontSize: 11, height: 1.5),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 20),

                        // ── Save Button ────────────────────────
                        GestureDetector(
                          onTap: _saving ? null : _save,
                          child: Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: AppColors.primaryShadow,
                            ),
                            child: _saving
                                ? const Center(child: SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              CustomPaint(size: const Size(18, 18), painter: _SaveIconPainter()),
                              const SizedBox(width: 8),
                              const Text('Save Settings', style: TextStyle(
                                color: Colors.white, fontFamily: 'Poppins',
                                fontWeight: FontWeight.w800, fontSize: 15,
                              )),
                            ]),
                          ),
                        ),
                      ],
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

  Widget _buildBackground(Size size) {
    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (_, __) {
        final t = _bgCtrl.value;
        return Stack(children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF060614), Color(0xFF0A0A1C)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            bottom: -size.height * 0.06 - t * 18, left: -size.width * 0.15,
            child: Container(
              width: size.width * 0.65, height: size.width * 0.65,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.secondary.withValues(alpha: 0.04 + t * 0.02),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
        ]);
      },
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: () { HapticFeedback.selectionClick(); Navigator.pop(context); },
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Center(child: CustomPaint(size: const Size(16, 16), painter: _BackArrowPainter())),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Location Sharing', style: TextStyle(fontFamily: 'Poppins',
                fontWeight: FontWeight.w800, fontSize: 20, color: Colors.white)),
            Text('Configure when & how you share', style: TextStyle(
                fontFamily: 'Poppins', fontSize: 11, color: Colors.white.withValues(alpha: 0.40))),
          ])),
          GestureDetector(
            onTap: _save,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Save', style: TextStyle(color: Colors.white,
                  fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Widgets ─────────────────────────────────────────────────────────────────

class _ConfigSection extends StatelessWidget {
  final CustomPainter painter;
  final Color iconColor;
  final String title;
  final Widget child;

  const _ConfigSection({
    required this.painter, required this.iconColor,
    required this.title, required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: CustomPaint(size: const Size(16, 16), painter: painter)),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontFamily: 'Poppins',
            fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white)),
      ]),
      const SizedBox(height: 14),
      child,
    ]),
  );
}

class _ModeOption extends StatelessWidget {
  final SharingMode mode;
  final bool selected;
  final VoidCallback onTap;
  const _ModeOption({required this.mode, required this.selected, required this.onTap});

  String get _label => switch (mode) {
    SharingMode.always      => 'Always Share',
    SharingMode.nightOnly   => 'Night Only (9PM–6AM)',
    SharingMode.journeyOnly => 'During Journey Mode',
    SharingMode.sosOnly     => 'SOS Trigger Only',
    SharingMode.manual      => 'Manual (I control)',
    SharingMode.never       => 'Never',
  };

  String get _subtitle => switch (mode) {
    SharingMode.always      => 'Contacts always see your location',
    SharingMode.nightOnly   => 'Auto-starts at 9PM, stops at 6AM — recommended',
    SharingMode.journeyOnly => 'Only active when journey mode is running',
    SharingMode.sosOnly     => 'Only when SOS is triggered',
    SharingMode.manual      => 'You tap Share to start and stop',
    SharingMode.never       => 'Location never shared — not recommended',
  };

  Color get _color => switch (mode) {
    SharingMode.always      => AppColors.sosRed,
    SharingMode.nightOnly   => AppColors.primary,
    SharingMode.journeyOnly => AppColors.secondary,
    SharingMode.sosOnly     => AppColors.warningAmber,
    SharingMode.manual      => AppColors.safeGreen,
    SharingMode.never       => Colors.grey,
  };

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected ? _color.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? _color.withValues(alpha: 0.40) : Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Row(children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle,
              color: selected ? _color : Colors.white.withValues(alpha: 0.18)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_label, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700,
              fontSize: 12, color: selected ? _color : Colors.white.withValues(alpha: 0.80))),
          Text(_subtitle, style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: Colors.grey)),
        ])),
        if (selected)
          CustomPaint(size: const Size(16, 16), painter: _CheckCircleSmallPainter(color: _color)),
      ]),
    ),
  );
}

class _PrecisionOption extends StatelessWidget {
  final SharingPrecision precision;
  final bool selected;
  final VoidCallback onTap;
  const _PrecisionOption({required this.precision, required this.selected, required this.onTap});

  String get _label => switch (precision) {
    SharingPrecision.exact        => 'Exact Location',
    SharingPrecision.neighborhood => 'Neighborhood',
    SharingPrecision.city         => 'City Only',
  };

  String get _desc => switch (precision) {
    SharingPrecision.exact        => 'Precise GPS — best for emergencies',
    SharingPrecision.neighborhood => '~500m radius — balanced privacy',
    SharingPrecision.city         => 'City-level only — maximum privacy',
  };

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? AppColors.secondary.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppColors.secondary.withValues(alpha: 0.40) : Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_label, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700,
              fontSize: 12, color: selected ? AppColors.secondary : Colors.white.withValues(alpha: 0.80))),
          Text(_desc, style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: Colors.grey)),
        ])),
        if (selected)
          CustomPaint(size: const Size(16, 16), painter: _CheckCircleSmallPainter(color: AppColors.secondary)),
      ]),
    ),
  );
}

class _SwitchRow extends StatelessWidget {
  final CustomPainter painter;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({required this.painter, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      CustomPaint(size: const Size(16, 16), painter: painter),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: const TextStyle(fontFamily: 'Poppins',
          fontSize: 12, color: Colors.white))),
      Switch.adaptive(value: value, onChanged: onChanged, activeColor: AppColors.primary,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
    ]),
  );
}

class _TimeDropdown extends StatelessWidget {
  final int value;
  final ValueChanged<int?> onChanged;
  const _TimeDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => DropdownButton<int>(
    value: value,
    underline: const SizedBox(),
    dropdownColor: AppColors.darkCard,
    style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700,
        fontSize: 12, color: Colors.white),
    items: [5, 10, 15, 30, 60].map((m) => DropdownMenuItem(
      value: m,
      child: Text('$m min'),
    )).toList(),
    onChanged: onChanged,
  );
}

// ═══════════════════════════════════════════════════════════════════════
// CUSTOM PAINTERS
// ═══════════════════════════════════════════════════════════════════════

class _BackArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.8..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final cy = s.height / 2;
    canvas.drawLine(Offset(s.width * 0.80, cy), Offset(s.width * 0.20, cy), p);
    final h = Path();
    h.moveTo(s.width * 0.46, cy - s.height * 0.30);
    h.lineTo(s.width * 0.20, cy);
    h.lineTo(s.width * 0.46, cy + s.height * 0.30);
    canvas.drawPath(h, p);
  }
  @override
  bool shouldRepaint(_BackArrowPainter o) => false;
}

class _SchedulePainter extends CustomPainter {
  final Color color;
  const _SchedulePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2;
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), s.width * 0.44, p);
    canvas.drawLine(Offset(cx, cy * 0.40), Offset(cx, cy), p);
    canvas.drawLine(Offset(cx, cy), Offset(cx + s.width * 0.22, cy + s.height * 0.14), p);
    canvas.drawLine(Offset(cx - s.width * 0.18, 0), Offset(cx + s.width * 0.18, 0),
        Paint()..color = color..strokeWidth = 1.4..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(_SchedulePainter o) => o.color != color;
}

class _GpsCrosshairPainter extends CustomPainter {
  final Color color;
  const _GpsCrosshairPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2;
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), s.width * 0.28, p);
    canvas.drawCircle(Offset(cx, cy), s.width * 0.08, Paint()..color = color);
    canvas.drawLine(Offset(cx, 0), Offset(cx, s.height * 0.18), p);
    canvas.drawLine(Offset(cx, s.height * 0.82), Offset(cx, s.height), p);
    canvas.drawLine(Offset(0, cy), Offset(s.width * 0.18, cy), p);
    canvas.drawLine(Offset(s.width * 0.82, cy), Offset(s.width, cy), p);
  }
  @override
  bool shouldRepaint(_GpsCrosshairPainter o) => o.color != color;
}

class _DataIconPainter extends CustomPainter {
  final Color color;
  const _DataIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4..strokeCap = StrokeCap.round;
    final bars = [0.40, 0.65, 0.85, 1.0];
    final bw = s.width / (bars.length * 2.2);
    for (int i = 0; i < bars.length; i++) {
      final x = s.width * (0.10 + i * 0.26);
      canvas.drawLine(Offset(x, s.height),
          Offset(x, s.height * (1 - bars[i])),
          Paint()..color = color..strokeWidth = bw * 1.2..strokeCap = StrokeCap.round);
    }
  }
  @override
  bool shouldRepaint(_DataIconPainter o) => o.color != color;
}

class _BellSmallPainter extends CustomPainter {
  final Color color;
  const _BellSmallPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final bell = Path();
    bell.moveTo(s.width * 0.20, s.height * 0.70);
    bell.lineTo(s.width * 0.12, s.height * 0.70);
    bell.quadraticBezierTo(s.width * 0.12, s.height * 0.58, s.width * 0.20, s.height * 0.54);
    bell.quadraticBezierTo(s.width * 0.20, s.height * 0.18, s.width * 0.50, s.height * 0.18);
    bell.quadraticBezierTo(s.width * 0.80, s.height * 0.18, s.width * 0.80, s.height * 0.54);
    bell.lineTo(s.width * 0.88, s.height * 0.58);
    bell.quadraticBezierTo(s.width * 0.88, s.height * 0.70, s.width * 0.80, s.height * 0.70);
    bell.close();
    canvas.drawPath(bell, p);
    canvas.drawArc(Rect.fromCenter(center: Offset(s.width * 0.50, s.height * 0.84),
        width: s.width * 0.22, height: s.height * 0.22), 0, math.pi, false, p);
  }
  @override
  bool shouldRepaint(_BellSmallPainter o) => o.color != color;
}

class _SpeedPainter extends CustomPainter {
  final Color color;
  const _SpeedPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2;
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), s.width * 0.46, p);
    canvas.drawLine(Offset(cx, cy), Offset(cx + s.width * 0.28, cy - s.height * 0.18), p);
  }
  @override
  bool shouldRepaint(_SpeedPainter o) => o.color != color;
}

class _AltitudePainter extends CustomPainter {
  final Color color;
  const _AltitudePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(0, s.height);
    path.lineTo(s.width * 0.30, s.height * 0.50);
    path.lineTo(s.width * 0.50, s.height * 0.20);
    path.lineTo(s.width * 0.70, s.height * 0.50);
    path.lineTo(s.width, s.height);
    canvas.drawPath(path, p);
    canvas.drawLine(Offset(s.width * 0.50, 0), Offset(s.width * 0.50, s.height * 0.20), p);
    final arrow = Path();
    arrow.moveTo(s.width * 0.38, s.height * 0.12);
    arrow.lineTo(s.width * 0.50, 0);
    arrow.lineTo(s.width * 0.62, s.height * 0.12);
    canvas.drawPath(arrow, p);
  }
  @override
  bool shouldRepaint(_AltitudePainter o) => o.color != color;
}

class _PlaySmallPainter extends CustomPainter {
  final Color color;
  const _PlaySmallPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final path = Path();
    path.moveTo(s.width * 0.20, 0);
    path.lineTo(s.width, s.height * 0.50);
    path.lineTo(s.width * 0.20, s.height);
    path.close();
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
  }
  @override
  bool shouldRepaint(_PlaySmallPainter o) => o.color != color;
}

class _StopSmallPainter extends CustomPainter {
  final Color color;
  const _StopSmallPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * 0.14, s.height * 0.14, s.width * 0.72, s.height * 0.72),
        const Radius.circular(2)),
        Paint()..color = color..style = PaintingStyle.fill);
  }
  @override
  bool shouldRepaint(_StopSmallPainter o) => o.color != color;
}

class _FlagSmallPainter extends CustomPainter {
  final Color color;
  const _FlagSmallPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(s.width * 0.18, s.height * 0.08), Offset(s.width * 0.18, s.height), p);
    final flag = Path();
    flag.moveTo(s.width * 0.18, s.height * 0.08);
    flag.lineTo(s.width * 0.86, s.height * 0.28);
    flag.lineTo(s.width * 0.18, s.height * 0.48);
    flag.close();
    canvas.drawPath(flag, Paint()..color = color.withValues(alpha: 0.75)..style = PaintingStyle.fill);
    canvas.drawPath(flag, p);
  }
  @override
  bool shouldRepaint(_FlagSmallPainter o) => o.color != color;
}

class _TimerPainter extends CustomPainter {
  final Color color;
  const _TimerPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2;
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), s.width * 0.44, p);
    canvas.drawLine(Offset(cx, cy * 0.40), Offset(cx, cy), p);
    canvas.drawLine(Offset(cx, cy), Offset(cx + s.width * 0.22, cy + s.height * 0.14), p);
    canvas.drawLine(Offset(cx - s.width * 0.18, 0), Offset(cx + s.width * 0.18, 0),
        Paint()..color = color..strokeWidth = 1.4..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(_TimerPainter o) => o.color != color;
}

class _InfoSmallPainter extends CustomPainter {
  final Color color;
  const _InfoSmallPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2; final r = s.width * 0.46;
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3..strokeCap = StrokeCap.round);
    canvas.drawCircle(Offset(cx, cy - r * 0.38), s.width * 0.07, Paint()..color = color);
    canvas.drawLine(Offset(cx, cy - r * 0.12), Offset(cx, cy + r * 0.44),
        Paint()..color = color..strokeWidth = 1.6..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(_InfoSmallPainter o) => o.color != color;
}

class _SaveIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, s.width, s.height), const Radius.circular(3)), p);
    canvas.drawRect(Rect.fromLTWH(s.width * 0.26, 0, s.width * 0.48, s.height * 0.46),
        Paint()..color = Colors.white.withValues(alpha: 0.20)..style = PaintingStyle.fill);
    canvas.drawLine(Offset(s.width * 0.38, s.height * 0.08), Offset(s.width * 0.38, s.height * 0.38), p);
  }
  @override
  bool shouldRepaint(_SaveIconPainter o) => false;
}

class _CheckCircleSmallPainter extends CustomPainter {
  final Color color;
  const _CheckCircleSmallPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2; final r = s.width * 0.46;
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color.withValues(alpha: 0.18)..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4);
    final check = Path();
    check.moveTo(cx - r * 0.42, cy);
    check.lineTo(cx - r * 0.08, cy + r * 0.40);
    check.lineTo(cx + r * 0.42, cy - r * 0.36);
    canvas.drawPath(check, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.6..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
  }
  @override
  bool shouldRepaint(_CheckCircleSmallPainter o) => o.color != color;
}

class _LocationDotPainter extends CustomPainter {
  final Color color;
  const _LocationDotPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3;
    final path = Path();
    path.moveTo(s.width * 0.50, 0);
    path.cubicTo(s.width * 0.18, 0, 0, s.height * 0.26, 0, s.height * 0.46);
    path.cubicTo(0, s.height * 0.66, s.width * 0.18, s.height * 0.80, s.width * 0.50, s.height);
    path.cubicTo(s.width * 0.82, s.height * 0.80, s.width, s.height * 0.66, s.width, s.height * 0.46);
    path.cubicTo(s.width, s.height * 0.26, s.width * 0.82, 0, s.width * 0.50, 0);
    path.close();
    canvas.drawPath(path, p);
    canvas.drawCircle(Offset(s.width / 2, s.height * 0.44), s.width * 0.14, Paint()..color = color);
  }
  @override
  bool shouldRepaint(_LocationDotPainter o) => o.color != color;
}