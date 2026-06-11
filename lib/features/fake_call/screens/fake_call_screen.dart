// lib/features/fake_call/screens/fake_call_screen.dart
// ═══════════════════════════════════════════════════════════════════════════
// FULL ADVANCED FAKE CALL FEATURE
// ✅ Realistic incoming call UI (matches Android/iOS system call screen)
// ✅ Ringtone plays on call arrival (via audioplayers)
// ✅ Vibration pattern (via vibration package)
// ✅ Countdown with live ticker
// ✅ Active call timer, mute, speaker, hold, keypad, add call
// ✅ Swipe-to-answer gesture (like real phone)
// ✅ Call ends automatically after configurable duration
// ✅ Works on all screen sizes + notch-safe
//
// pubspec.yaml dependencies needed:
//   audioplayers: ^6.0.0
//   vibration: ^2.0.0
//
// assets needed (add to pubspec.yaml):
//   assets/sounds/ringtone.mp3   ← any short ringtone MP3
//
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import '../../../core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const _kPrimaryBlue = Color(0xFF1A237E);
const _kDeepBlue    = Color(0xFF0D1642);
const _kAcceptGreen = Color(0xFF2E7D32);
const _kDeclineRed  = Color(0xFFE53935);
const _kActiveGreen = Color(0xFF4CAF50);

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

class _CallerPreset {
  final String name, number, emoji, relation;
  const _CallerPreset(this.name, this.number, this.emoji, this.relation);
}

const _presets = [
  _CallerPreset('Mom',         '+91 98765 43210', '👩',    'Mother'),
  _CallerPreset('Dad',         '+91 87654 32109', '👨',    'Father'),
  _CallerPreset('Sister',      '+91 76543 21098', '👧',    'Sister'),
  _CallerPreset('Best Friend', '+91 65432 10987', '👯',    'Friend'),
  _CallerPreset('Boss',        '+91 54321 09876', '👔',    'Manager'),
  _CallerPreset('Doctor',      '+91 43210 98765', '👨‍⚕️', 'Doctor'),
  _CallerPreset('Boyfriend',   '+91 32109 87654', '💑',    'Partner'),
  _CallerPreset('Police',      '100',             '👮',    'Officer'),
];

const _delays = [
  {'label': 'Now',   'seconds': 2},
  {'label': '30s',   'seconds': 30},
  {'label': '1 min', 'seconds': 60},
  {'label': '2 min', 'seconds': 120},
  {'label': '5 min', 'seconds': 300},
];

const _callDurations = [
  {'label': '30 sec', 'seconds': 30},
  {'label': '1 min',  'seconds': 60},
  {'label': '2 min',  'seconds': 120},
  {'label': '5 min',  'seconds': 300},
  {'label': 'Manual', 'seconds': 0},
];

// ═══════════════════════════════════════════════════════════════════════════
// FAKE CALL SETUP SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class FakeCallScreen extends StatefulWidget {
  const FakeCallScreen({super.key});
  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen>
    with TickerProviderStateMixin {

  int  _selectedCaller    = 0;
  int  _delaySeconds      = 2;
  int  _callDurationIndex = 2; // default 2 min
  bool _useCustomName     = false;
  bool _autoEnd           = true;

  final _nameCtrl   = TextEditingController();
  final _numberCtrl = TextEditingController();

  Timer? _countdownTimer;
  int    _countdown = 0;
  bool   _counting  = false;

  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _numberCtrl.dispose();
    _countdownTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ─── helpers ───────────────────────────────────────────────
  String get _resolvedName   => _useCustomName && _nameCtrl.text.isNotEmpty   ? _nameCtrl.text   : _presets[_selectedCaller].name;
  String get _resolvedNumber => _useCustomName && _numberCtrl.text.isNotEmpty ? _numberCtrl.text : _presets[_selectedCaller].number;
  String get _resolvedEmoji  => _useCustomName ? '📱' : _presets[_selectedCaller].emoji;
  int    get _autoDuration   => _callDurations[_callDurationIndex]['seconds'] as int;

  void _startFakeCall() {
    FocusScope.of(context).unfocus();
    if (_delaySeconds <= 2) { _triggerCall(); return; }
    setState(() { _counting = true; _countdown = _delaySeconds; });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        if (mounted) setState(() => _counting = false);
        _triggerCall();
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    setState(() { _counting = false; _countdown = 0; });
  }

  void _triggerCall() {
    HapticFeedback.heavyImpact();
    Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, __, ___) => IncomingCallScreen(
        callerName:   _resolvedName,
        callerNumber: _resolvedNumber,
        callerEmoji:  _resolvedEmoji,
        autoDuration: _autoEnd ? _autoDuration : 0,
      ),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 400),
    ));
  }

  // ─── BUILD ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF4F6FB),
      body: Column(children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildInfoBanner(isDark),
              const SizedBox(height: 18),
              FadeInLeft(child: _buildCallerCard(isDark)),
              const SizedBox(height: 14),
              FadeInLeft(delay: const Duration(milliseconds: 80),  child: _buildDelayCard(isDark)),
              const SizedBox(height: 14),
              FadeInLeft(delay: const Duration(milliseconds: 120), child: _buildDurationCard(isDark)),
              const SizedBox(height: 22),
              FadeInUp(delay: const Duration(milliseconds: 150),   child: _buildTriggerSection()),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader() => Container(
    padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 10, 16, 16),
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [_kPrimaryBlue, Color(0xFF283593)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
    ),
    child: Row(children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 18),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Fake Call', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 18)),
        Text('Rings with real sound + vibration', style: TextStyle(color: Colors.white.withOpacity(0.75), fontFamily: 'Poppins', fontSize: 11)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(10)),
        child: const Text('📞 Safe Escape', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 10)),
      ),
    ]),
  );

  Widget _buildInfoBanner(bool isDark) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _kPrimaryBlue.withOpacity(0.07),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _kPrimaryBlue.withOpacity(0.2)),
    ),
    child: const Row(children: [
      Text('💡', style: TextStyle(fontSize: 20)),
      SizedBox(width: 10),
      Expanded(child: Text(
        'Your phone will ring with a real ringtone and vibration, just like an actual incoming call. No one will know it\'s fake.',
        style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.grey, height: 1.5),
      )),
    ]),
  );

  Widget _buildCallerCard(bool isDark) => _SectionCard(
    isDark: isDark, title: '👤  Who is calling?',
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(
        spacing: 8, runSpacing: 8,
        children: List.generate(_presets.length, (i) {
          final sel = !_useCustomName && _selectedCaller == i;
          return GestureDetector(
            onTap: () => setState(() { _selectedCaller = i; _useCustomName = false; }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? _kPrimaryBlue : (isDark ? AppColors.darkBackground : const Color(0xFFF0F0F0)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: sel ? _kPrimaryBlue : Colors.transparent, width: 1.5),
                boxShadow: sel ? [BoxShadow(color: _kPrimaryBlue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_presets[i].emoji, style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 5),
                Text(_presets[i].name, style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : null,
                )),
              ]),
            ),
          );
        }),
      ),
      const SizedBox(height: 14),
      const Divider(),
      const SizedBox(height: 8),
      Row(children: [
        Transform.scale(
          scale: 0.9,
          child: Switch(value: _useCustomName, onChanged: (v) => setState(() => _useCustomName = v), activeColor: _kPrimaryBlue),
        ),
        const SizedBox(width: 6),
        const Text('Use custom caller info', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
      if (_useCustomName) ...[
        const SizedBox(height: 10),
        _InputField(ctrl: _nameCtrl,   hint: 'Caller name…',  icon: Icons.person_rounded),
        const SizedBox(height: 8),
        _InputField(ctrl: _numberCtrl, hint: 'Phone number…', icon: Icons.phone_rounded, type: TextInputType.phone),
      ],
    ]),
  );

  Widget _buildDelayCard(bool isDark) => _SectionCard(
    isDark: isDark, title: '⏱  When should it ring?',
    child: Row(
      children: _delays.map((d) {
        final sel = _delaySeconds == (d['seconds'] as int);
        return Expanded(child: GestureDetector(
          onTap: () => setState(() => _delaySeconds = d['seconds'] as int),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: sel ? _kPrimaryBlue : (isDark ? AppColors.darkBackground : const Color(0xFFF0F0F0)),
              borderRadius: BorderRadius.circular(12),
              boxShadow: sel ? [BoxShadow(color: _kPrimaryBlue.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))] : [],
            ),
            child: Text(d['label'] as String, textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, color: sel ? Colors.white : Colors.grey)),
          ),
        ));
      }).toList(),
    ),
  );

  Widget _buildDurationCard(bool isDark) => _SectionCard(
    isDark: isDark, title: '📏  How long should the call last?',
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
        children: List.generate(_callDurations.length, (i) {
          final sel = _callDurationIndex == i;
          return Expanded(child: GestureDetector(
            onTap: () => setState(() {
              _callDurationIndex = i;
              _autoEnd = (_callDurations[i]['seconds'] as int) != 0;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: sel ? _kPrimaryBlue : (isDark ? AppColors.darkBackground : const Color(0xFFF0F0F0)),
                borderRadius: BorderRadius.circular(11),
                boxShadow: sel ? [BoxShadow(color: _kPrimaryBlue.withOpacity(0.28), blurRadius: 6, offset: const Offset(0, 3))] : [],
              ),
              child: Text(_callDurations[i]['label'] as String, textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w700, color: sel ? Colors.white : Colors.grey)),
            ),
          ));
        }),
      ),
      const SizedBox(height: 8),
      Text(
        _autoEnd ? 'Call will auto-end after ${_callDurations[_callDurationIndex]['label']}' : 'You control when to end the call manually',
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.grey),
      ),
    ]),
  );

  Widget _buildTriggerSection() {
    if (_counting) {
      return Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
          decoration: BoxDecoration(
            color: _kPrimaryBlue.withOpacity(0.07),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _kPrimaryBlue.withOpacity(0.25)),
          ),
          child: Column(children: [
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Transform.scale(
                scale: 1.0 + _pulseCtrl.value * 0.07,
                child: Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kPrimaryBlue.withOpacity(0.1),
                    border: Border.all(color: _kPrimaryBlue.withOpacity(0.3), width: 2),
                  ),
                  child: Center(child: Text('$_countdown',
                      style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w900, fontSize: 42, color: _kPrimaryBlue))),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text('📞 Fake call incoming…',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 15, color: _kPrimaryBlue)),
            const SizedBox(height: 4),
            const Text('Put your phone face-down now!',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.grey)),
          ]),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _cancelCountdown,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(border: Border.all(color: _kDeclineRed.withOpacity(0.5)), borderRadius: BorderRadius.circular(16)),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.cancel_rounded, color: _kDeclineRed, size: 18),
              SizedBox(width: 6),
              Text('Cancel', style: TextStyle(color: _kDeclineRed, fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 15)),
            ]),
          ),
        ),
      ]);
    }

    final delayEntry = _delays.firstWhere(
          (d) => d['seconds'] == _delaySeconds,
      orElse: () => _delays.first,
    );

    return Column(children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kPrimaryBlue.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kPrimaryBlue.withOpacity(0.15)),
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [_kPrimaryBlue, Color(0xFF3949AB)])),
            child: Center(child: Text(_resolvedEmoji, style: const TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_resolvedName, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 16)),
            Text(_resolvedNumber, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            Row(children: [
              _MiniChip('⏱ ${delayEntry['label']}', _kPrimaryBlue),
              const SizedBox(width: 6),
              _MiniChip(_autoEnd ? '📏 ${_callDurations[_callDurationIndex]['label']}' : '📏 Manual', _kAcceptGreen),
            ]),
          ])),
        ]),
      ),
      const SizedBox(height: 14),
      GestureDetector(
        onTap: _startFakeCall,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_kPrimaryBlue, Color(0xFF283593)]),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: _kPrimaryBlue.withOpacity(0.45), blurRadius: 22, offset: const Offset(0, 8))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Transform.scale(
                scale: 1.0 + _pulseCtrl.value * 0.08,
                child: const Icon(Icons.phone_rounded, color: Colors.white, size: 24),
              ),
            ),
            const SizedBox(width: 10),
            const Text('Start Fake Call',
                style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 18)),
          ]),
        ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// INCOMING CALL SCREEN — Full realistic system-call UI
// ═══════════════════════════════════════════════════════════════════════════

class IncomingCallScreen extends StatefulWidget {
  final String callerName, callerNumber, callerEmoji;
  final int    autoDuration; // 0 = manual

  const IncomingCallScreen({
    super.key,
    required this.callerName,
    required this.callerNumber,
    required this.callerEmoji,
    this.autoDuration = 120,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin {

  bool   _answered   = false;
  bool   _muted      = false;
  bool   _speakerOn  = false;
  bool   _onHold     = false;
  bool   _showKeypad = false;
  String _keypadStr  = '';

  Timer? _callTimer;
  Timer? _autoEndTimer;
  int    _callSeconds = 0;

  final AudioPlayer _audioPlayer = AudioPlayer();

  late AnimationController _rippleCtrl;
  late AnimationController _acceptPulseCtrl;

  double _swipeOffset = 0;

  @override
  void initState() {
    super.initState();
    _rippleCtrl      = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _acceptPulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);

    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light,
    ));

    _startRingtone();
    _startVibration();
  }

  @override
  void dispose() {
    _rippleCtrl.dispose();
    _acceptPulseCtrl.dispose();
    _callTimer?.cancel();
    _autoEndTimer?.cancel();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    Vibration.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark,
    ));
    super.dispose();
  }

  Future<void> _startRingtone() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play(AssetSource('sounds/ringtone.mp3'));
    } catch (_) {
      // Asset not found — vibration-only mode
    }
  }

  Future<void> _stopRingtone() async {
    try { await _audioPlayer.stop(); } catch (_) {}
  }

  Future<void> _startVibration() async {
    try {
      final hasVib = await Vibration.hasVibrator() ?? false;
      if (!hasVib) return;
      Vibration.vibrate(pattern: [0, 600, 700, 600, 700, 600], repeat: 3);
    } catch (_) {}
  }

  void _answerCall() {
    if (_answered) return;
    HapticFeedback.heavyImpact();
    _stopRingtone();
    Vibration.cancel();
    setState(() { _answered = true; });
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _callSeconds++);
    });
    if (widget.autoDuration > 0) {
      _autoEndTimer = Timer(Duration(seconds: widget.autoDuration), () {
        if (mounted) _endCall();
      });
    }
  }

  void _declineCall() {
    HapticFeedback.heavyImpact();
    _stopRingtone();
    Vibration.cancel();
    if (mounted) Navigator.pop(context);
  }

  void _endCall() {
    HapticFeedback.heavyImpact();
    _stopRingtone();
    Vibration.cancel();
    if (mounted) Navigator.pop(context);
  }

  void _onSwipeUpdate(DragUpdateDetails d) =>
      setState(() => _swipeOffset = (_swipeOffset + d.delta.dx).clamp(-140.0, 140.0));

  void _onSwipeEnd(DragEndDetails _) {
    if      (_swipeOffset >  90) _answerCall();
    else if (_swipeOffset < -90) _declineCall();
    else setState(() => _swipeOffset = 0);
  }

  String get _callDuration {
    final m = _callSeconds ~/ 60, s = _callSeconds % 60;
    return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  String _formatRemaining() {
    final rem = widget.autoDuration - _callSeconds;
    if (rem <= 0) return '0:00';
    final m = rem ~/ 60, s = rem % 60;
    return '$m:${s.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          child: _answered ? _buildActiveCall() : _buildIncomingCall(),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // INCOMING CALL
  // ──────────────────────────────────────────────────────────
  Widget _buildIncomingCall() {
    final size = MediaQuery.of(context).size;
    final rng  = math.Random(42);

    return Container(
      key: const ValueKey('incoming'),
      width: double.infinity, height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [_kPrimaryBlue, _kDeepBlue, Colors.black],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        child: Stack(children: [

          // Background animated particles
          ...List.generate(8, (i) {
            final x = rng.nextDouble();
            final y = rng.nextDouble();
            final r = 30.0 + rng.nextDouble() * 80;
            return Positioned(
              left: x * size.width - r, top: y * size.height - r,
              child: AnimatedBuilder(
                animation: _rippleCtrl,
                builder: (_, __) {
                  final phase = ((_rippleCtrl.value + i * 0.13) % 1.0);
                  return Container(
                    width: r * 2, height: r * 2,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity((1 - phase) * 0.04)),
                  );
                },
              ),
            );
          }),

          Column(children: [
            const SizedBox(height: 16),

            // Live indicator
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    AnimatedBuilder(
                      animation: _acceptPulseCtrl,
                      builder: (_, __) => Container(
                        width: 7, height: 7,
                        decoration: BoxDecoration(
                          color: _kActiveGreen.withOpacity(0.6 + _acceptPulseCtrl.value * 0.4),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('Incoming Call', style: TextStyle(color: Colors.white70, fontFamily: 'Poppins', fontSize: 11)),
                  ]),
                ),
              ),
            ),

            const Spacer(flex: 1),

            // Caller avatar + ripple
            SlideInDown(duration: const Duration(milliseconds: 600), child: Column(children: [
              AnimatedBuilder(
                animation: _rippleCtrl,
                builder: (_, __) => SizedBox(
                  width: 220, height: 220,
                  child: Stack(alignment: Alignment.center, children: [
                    Transform.scale(
                      scale: 1.0 + _rippleCtrl.value * 0.7,
                      child: Container(width: 210, height: 210,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity((1 - _rippleCtrl.value) * 0.06))),
                    ),
                    Transform.scale(
                      scale: 1.0 + _rippleCtrl.value * 0.35,
                      child: Container(width: 170, height: 170,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity((1 - _rippleCtrl.value) * 0.1))),
                    ),
                    Container(
                      width: 120, height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [_kPrimaryBlue, Color(0xFF3949AB)]),
                        border: Border.all(color: Colors.white.withOpacity(0.35), width: 3),
                        boxShadow: [BoxShadow(color: _kPrimaryBlue.withOpacity(0.6), blurRadius: 35, spreadRadius: 6)],
                      ),
                      child: Center(child: Text(widget.callerEmoji, style: const TextStyle(fontSize: 54))),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 20),
              Text(widget.callerName,
                  style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w900, fontSize: 34, letterSpacing: -0.5)),
              const SizedBox(height: 6),
              Text(widget.callerNumber, style: TextStyle(color: Colors.white.withOpacity(0.7), fontFamily: 'Poppins', fontSize: 15)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                child: const Text('mobile', style: TextStyle(color: Colors.white60, fontFamily: 'Poppins', fontSize: 12, letterSpacing: 0.8)),
              ),
            ])),

            const Spacer(flex: 2),

            // Controls
            FadeInUp(delay: const Duration(milliseconds: 300), child: Column(children: [
              Text('← Decline           Accept →',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontFamily: 'Poppins', fontSize: 11)),
              const SizedBox(height: 18),

              // Swipe gesture area + buttons
              GestureDetector(
                onHorizontalDragUpdate: _onSwipeUpdate,
                onHorizontalDragEnd:    _onSwipeEnd,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    _RingButton(icon: Icons.call_end_rounded, color: _kDeclineRed, label: 'Decline', onTap: _declineCall, offset: _swipeOffset < 0 ? _swipeOffset.abs() : 0),
                    Column(children: [
                      Container(width: 4, height: 36, decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 4),
                      Icon(Icons.swap_horiz_rounded, color: Colors.white.withOpacity(0.3), size: 16),
                    ]),
                    _RingButton(icon: Icons.call_rounded, color: _kAcceptGreen, label: 'Accept', onTap: _answerCall, pulse: _acceptPulseCtrl, offset: _swipeOffset > 0 ? _swipeOffset : 0),
                  ]),
                ),
              ),
              const SizedBox(height: 20),

              // Quick actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 44),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  _QuickAction(icon: Icons.message_rounded,     label: 'Message'),
                  _QuickAction(icon: Icons.watch_later_rounded, label: 'Remind me'),
                  _QuickAction(icon: Icons.volume_off_rounded,  label: 'Silence', onTap: () { _stopRingtone(); Vibration.cancel(); }),
                ]),
              ),
              const SizedBox(height: 28),
            ])),
          ]),
        ]),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // ACTIVE CALL
  // ──────────────────────────────────────────────────────────
  Widget _buildActiveCall() {
    return Container(
      key: const ValueKey('active'),
      width: double.infinity, height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0E27), Color(0xFF0D1220), Colors.black]),
      ),
      child: SafeArea(child: _showKeypad ? _buildKeypad() : _buildCallControls()),
    );
  }

  Widget _buildCallControls() => Column(children: [
    const SizedBox(height: 24),
    Text(widget.callerName, style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 28)),
    const SizedBox(height: 6),
    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: _kActiveGreen)),
      const SizedBox(width: 6),
      Text(_callDuration, style: const TextStyle(color: _kActiveGreen, fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600)),
      if (_onHold) ...[
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
          child: const Text('ON HOLD', style: TextStyle(color: Colors.orange, fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w700)),
        ),
      ],
    ]),
    if (widget.autoDuration > 0) ...[
      const SizedBox(height: 4),
      Text('Auto-ends in ${_formatRemaining()}',
          style: TextStyle(color: Colors.white.withOpacity(0.35), fontFamily: 'Poppins', fontSize: 10)),
    ],
    const Spacer(),
    Container(
      width: 90, height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle, color: _kPrimaryBlue,
        border: Border.all(color: Colors.white.withOpacity(0.18), width: 2),
      ),
      child: Center(child: Text(widget.callerEmoji, style: const TextStyle(fontSize: 42))),
    ),
    const Spacer(),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _CtrlBtn(icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded, label: _muted ? 'Unmute' : 'Mute', active: _muted,
              onTap: () { setState(() => _muted = !_muted); HapticFeedback.selectionClick(); }),
          _CtrlBtn(icon: _speakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded, label: _speakerOn ? 'Speaker On' : 'Speaker', active: _speakerOn,
              onTap: () { setState(() => _speakerOn = !_speakerOn); HapticFeedback.selectionClick(); }),
          _CtrlBtn(icon: Icons.dialpad_rounded, label: 'Keypad',
              onTap: () { setState(() => _showKeypad = true); HapticFeedback.selectionClick(); }),
        ]),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _CtrlBtn(icon: Icons.person_add_rounded, label: 'Add Call', onTap: () => HapticFeedback.selectionClick()),
          _CtrlBtn(icon: _onHold ? Icons.play_arrow_rounded : Icons.pause_rounded, label: _onHold ? 'Resume' : 'Hold', active: _onHold,
              onTap: () { setState(() => _onHold = !_onHold); HapticFeedback.selectionClick(); }),
          _CtrlBtn(icon: Icons.videocam_rounded, label: 'Video', onTap: () => HapticFeedback.selectionClick()),
        ]),
      ]),
    ),
    const SizedBox(height: 28),
    GestureDetector(
      onTap: _endCall,
      child: Container(
        width: 72, height: 72,
        decoration: const BoxDecoration(color: _kDeclineRed, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Color(0x66E53935), blurRadius: 22, spreadRadius: 3)]),
        child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 32),
      ),
    ),
    const SizedBox(height: 6),
    const Text('End', style: TextStyle(color: Colors.white54, fontFamily: 'Poppins', fontSize: 12)),
    const SizedBox(height: 26),
  ]);

  Widget _buildKeypad() {
    const keys = [['1','2','3'],['4','5','6'],['7','8','9'],['*','0','#']];
    return Column(children: [
      const SizedBox(height: 16),
      Row(children: [
        const SizedBox(width: 16),
        GestureDetector(onTap: () => setState(() => _showKeypad = false),
            child: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white70, size: 20)),
        const Spacer(),
        const Text('Keypad', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 16)),
        const Spacer(),
        GestureDetector(
          onTap: () { if (_keypadStr.isNotEmpty) setState(() => _keypadStr = _keypadStr.substring(0, _keypadStr.length - 1)); },
          child: const Padding(padding: EdgeInsets.only(right: 16), child: Icon(Icons.backspace_outlined, color: Colors.white54, size: 20)),
        ),
      ]),
      const SizedBox(height: 14),
      Text(_keypadStr.isEmpty ? ' ' : _keypadStr,
          style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 28, fontWeight: FontWeight.w300, letterSpacing: 5)),
      const SizedBox(height: 16),
      ...keys.map((row) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((k) => _KeypadKey(label: k, onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _keypadStr = (_keypadStr + k).length > 12 ? (_keypadStr + k).substring((_keypadStr + k).length - 12) : _keypadStr + k);
            })).toList()),
      )),
      const Spacer(),
      GestureDetector(onTap: _endCall,
          child: Container(width: 68, height: 68, decoration: const BoxDecoration(color: _kDeclineRed, shape: BoxShape.circle),
              child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 30))),
      const SizedBox(height: 28),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _RingButton extends StatelessWidget {
  final IconData icon; final Color color; final String label;
  final VoidCallback onTap; final double offset; final AnimationController? pulse;
  const _RingButton({required this.icon, required this.color, required this.label, required this.onTap, this.offset = 0, this.pulse});

  @override
  Widget build(BuildContext context) {
    Widget btn = GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(width: 74, height: 74,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: color.withOpacity(0.55), blurRadius: 22, spreadRadius: 2)]),
            child: Icon(icon, color: Colors.white, size: 32)),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(color: Colors.white70, fontFamily: 'Poppins', fontSize: 12)),
      ]),
    );
    if (pulse != null) {
      btn = AnimatedBuilder(animation: pulse!, builder: (_, child) => Transform.scale(scale: 1.0 + pulse!.value * 0.06, child: child), child: btn);
    }
    return Transform.translate(offset: Offset(offset * 0.25, 0), child: btn);
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback? onTap;
  const _QuickAction({required this.icon, required this.label, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap ?? () {},
    child: Column(children: [
      Container(width: 50, height: 50, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1)),
          child: Icon(icon, color: Colors.white60, size: 22)),
      const SizedBox(height: 5),
      Text(label, style: const TextStyle(color: Colors.white38, fontFamily: 'Poppins', fontSize: 10)),
    ]),
  );
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon; final String label; final bool active; final VoidCallback onTap;
  const _CtrlBtn({required this.icon, required this.label, required this.onTap, this.active = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(children: [
      AnimatedContainer(duration: const Duration(milliseconds: 200),
          width: 62, height: 62,
          decoration: BoxDecoration(color: active ? Colors.white : Colors.white.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, color: active ? Colors.black87 : Colors.white, size: 26)),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(color: Colors.white60, fontFamily: 'Poppins', fontSize: 10)),
    ]),
  );
}

class _KeypadKey extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const _KeypadKey({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(width: 74, height: 74,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1)),
        child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w300, fontSize: 30)))),
  );
}

class _SectionCard extends StatelessWidget {
  final bool isDark; final String title; final Widget child;
  const _SectionCard({required this.isDark, required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: isDark ? AppColors.darkCard : Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: AppColors.cardShadow,
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 13)),
      const SizedBox(height: 12),
      child,
    ]),
  );
}

class _InputField extends StatelessWidget {
  final TextEditingController ctrl; final String hint; final IconData icon; final TextInputType? type;
  const _InputField({required this.ctrl, required this.hint, required this.icon, this.type});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: ctrl, keyboardType: type,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
      decoration: InputDecoration(
        hintText: hint, hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
        prefixIcon: Icon(icon, color: _kPrimaryBlue, size: 20),
        filled: true, fillColor: isDark ? AppColors.darkBackground : const Color(0xFFF5F5F5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String text; final Color color;
  const _MiniChip(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w700, color: color)),
  );
}