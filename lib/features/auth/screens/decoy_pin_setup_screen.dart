// lib/features/auth/screens/decoy_pin_setup_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// DECOY PIN SETUP SCREEN
// Step-by-step setup: real PIN → decoy PIN → panic PIN (optional)
// Beautiful animated PIN entry UI
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/services/decoy_service.dart';
import '../../../core/theme/app_colors.dart';

class DecoyPinSetupScreen extends StatefulWidget {
  const DecoyPinSetupScreen({super.key});
  @override
  State<DecoyPinSetupScreen> createState() => _DecoyPinSetupScreenState();
}

class _DecoyPinSetupScreenState extends State<DecoyPinSetupScreen>
    with TickerProviderStateMixin {

  int    _step        = 0; // 0=real, 1=confirm_real, 2=decoy, 3=panic, 4=done
  String _realPin     = '';
  String _decoyPin    = '';
  String _panicPin    = '';
  String _confirmReal = '';
  String _currentPin  = '';
  String _error       = '';
  bool   _saving      = false;

  late AnimationController _shakeCtrl;
  late Animation<double>   _shakeAnim;
  late AnimationController _pulseCtrl;

  final List<String> _stepTitles = [
    'Set Real PIN',
    'Confirm Real PIN',
    'Set Decoy PIN',
    'Set Panic PIN\n(Optional)',
  ];
  final List<String> _stepSubs = [
    'This PIN opens SafeHer. Keep it secret.',
    'Enter your real PIN again to confirm.',
    'This PIN opens a fake calculator.\nUse when forced to unlock.',
    'This PIN triggers silent SOS first,\nthen shows fake app.\nTap skip to skip.',
  ];

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));
    _pulseCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 600))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onDigit(String d) {
    if (_currentPin.length >= 6) return;
    setState(() {
      _currentPin += d;
      _error       = '';
    });
    if (_currentPin.length == 4) _onPinComplete();
  }

  void _onDelete() {
    if (_currentPin.isEmpty) return;
    setState(() => _currentPin = _currentPin.substring(0, _currentPin.length - 1));
  }

  void _onPinComplete() async {
    await Future.delayed(const Duration(milliseconds: 200));
    switch (_step) {
      case 0: // set real PIN
        if (_currentPin.length < 4) { _showError('Min 4 digits'); return; }
        setState(() { _realPin = _currentPin; _currentPin = ''; _step = 1; });
        break;

      case 1: // confirm real PIN
        if (_currentPin != _realPin) {
          _showError('PINs do not match');
        } else {
          setState(() { _confirmReal = _currentPin; _currentPin = ''; _step = 2; });
        }
        break;

      case 2: // set decoy PIN
        if (_currentPin == _realPin) {
          _showError('Must differ from real PIN');
        } else {
          setState(() { _decoyPin = _currentPin; _currentPin = ''; _step = 3; });
        }
        break;

      case 3: // panic PIN (optional)
        if (_currentPin == _realPin || _currentPin == _decoyPin) {
          _showError('Must differ from other PINs');
        } else {
          setState(() { _panicPin = _currentPin; });
          await _saveAndFinish();
        }
        break;
    }
  }

  void _showError(String msg) {
    setState(() { _error = msg; _currentPin = ''; });
    _shakeCtrl.forward(from: 0);
  }

  Future<void> _skipPanicPin() async {
    setState(() { _panicPin = ''; });
    await _saveAndFinish();
  }

  Future<void> _saveAndFinish() async {
    setState(() => _saving = true);
    final ok = await DecoyService.instance.setupPins(
      realPin:  _realPin,
      decoyPin: _decoyPin,
      panicPin: _panicPin.isEmpty ? null : _panicPin,
    );
    setState(() => _saving = false);

    if (ok && mounted) {
      setState(() => _step = 4);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context, true);
    } else {
      _showError('Setup failed. Try again.');
      setState(() { _step = 0; _currentPin = ''; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF5F5FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation:       0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Decoy Protection',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: _step == 4 ? _buildSuccess() : _buildSetup(isDark),
    );
  }

  Widget _buildSetup(bool isDark) => SafeArea(
    child: Column(children: [
      // Progress bar
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value:           (_step + 1) / 4,
            backgroundColor: Colors.grey.withOpacity(0.2),
            valueColor:      const AlwaysStoppedAnimation(AppColors.primary),
            minHeight:       4,
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text('Step ${_step + 1} of 4',
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.grey)),

      Expanded(child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            // Icon
            FadeIn(child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient:     AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow:    AppColors.primaryShadow,
              ),
              child: Icon(_stepIcon(), color: Colors.white, size: 38),
            )),
            const SizedBox(height: 20),

            // Title
            FadeInDown(child: Text(_stepTitles[_step],
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 22))),
            const SizedBox(height: 8),
            FadeInDown(delay: const Duration(milliseconds: 60),
                child: Text(_stepSubs[_step],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 13, color: Colors.grey, height: 1.5))),

            const SizedBox(height: 36),

            // PIN dots
            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (_, child) => Transform.translate(
                offset: Offset(8 * (0.5 - _shakeAnim.value).abs() * (_shakeAnim.value > 0.5 ? 1 : -1), 0),
                child: child,
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children:
              List.generate(6, (i) {
                final filled = i < _currentPin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width:  filled ? 18 : 16,
                  height: filled ? 18 : 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? AppColors.primary : Colors.grey.withOpacity(0.3),
                    boxShadow: filled ? [BoxShadow(
                        color: AppColors.primary.withOpacity(0.4), blurRadius: 8)] : [],
                  ),
                );
              }),
              ),
            ),

            if (_error.isNotEmpty) ...[
              const SizedBox(height: 12),
              FadeIn(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.sosRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_error,
                    style: const TextStyle(
                        color: AppColors.sosRed, fontFamily: 'Poppins',
                        fontSize: 12, fontWeight: FontWeight.w600)),
              )),
            ],

            const SizedBox(height: 36),

            // Numpad
            _buildNumpad(isDark),

            if (_step == 3) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _skipPanicPin,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    border:       Border.all(color: Colors.grey.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text('Skip Panic PIN',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.grey)),
                ),
              ),
            ],

            if (_saving) ...[
              const SizedBox(height: 20),
              const CircularProgressIndicator(color: AppColors.primary),
            ],
          ]),
        ),
      )),
    ]),
  );

  Widget _buildNumpad(bool isDark) => Column(
    children: [
      _numRow(['1', '2', '3'], isDark),
      const SizedBox(height: 12),
      _numRow(['4', '5', '6'], isDark),
      const SizedBox(height: 12),
      _numRow(['7', '8', '9'], isDark),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _numBtn('', isDark, invisible: true),
        const SizedBox(width: 12),
        _numBtn('0', isDark),
        const SizedBox(width: 12),
        _deleteBtn(isDark),
      ]),
    ],
  );

  Widget _numRow(List<String> digits, bool isDark) =>
      Row(mainAxisAlignment: MainAxisAlignment.center, children:
      digits.asMap().entries.map((e) => Padding(
        padding: EdgeInsets.only(left: e.key > 0 ? 12 : 0),
        child: _numBtn(e.value, isDark),
      )).toList());

  Widget _numBtn(String d, bool isDark, {bool invisible = false}) {
    if (invisible) return const SizedBox(width: 72, height: 72);
    return GestureDetector(
      onTap: () => _onDigit(d),
      child: Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          shape: BoxShape.circle,
          boxShadow: AppColors.cardShadow,
        ),
        child: Center(child: Text(d,
            style: const TextStyle(
                fontFamily: 'Poppins', fontWeight: FontWeight.w700,
                fontSize: 26))),
      ),
    );
  }

  Widget _deleteBtn(bool isDark) => GestureDetector(
    onTap: _onDelete,
    child: Container(
      width: 72, height: 72,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        shape: BoxShape.circle,
        boxShadow: AppColors.cardShadow,
      ),
      child: const Center(child: Icon(Icons.backspace_rounded,
          color: AppColors.sosRed, size: 24)),
    ),
  );

  Widget _buildSuccess() => Center(child: FadeIn(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 100, height: 100,
        decoration: BoxDecoration(
          gradient: AppColors.safeGradient, shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: AppColors.safeGreen.withOpacity(0.4), blurRadius: 30)],
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 52),
      ),
      const SizedBox(height: 24),
      const Text('Decoy Protection Active! 🛡️',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 20)),
      const SizedBox(height: 12),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          'Enter decoy PIN → fake calculator\nEnter real PIN → SafeHer opens',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.grey, height: 1.6),
        ),
      ),
    ],
  )));

  IconData _stepIcon() {
    switch (_step) {
      case 0: return Icons.lock_rounded;
      case 1: return Icons.lock_reset_rounded;
      case 2: return Icons.calculate_rounded;
      default: return Icons.warning_amber_rounded;
    }
  }
}