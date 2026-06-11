// lib/features/settings/screens/decoy_settings_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// SAFEHER — DECOY APP SETTINGS
// Wired to DecoyService: isEnabled, isSetup, mode, setupPins, setEnabled,
// setMode, clearAll, isLockedOut, lockoutRemaining
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/services/decoy_service.dart';
import '../../../core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────

class DecoySettingsScreen extends StatefulWidget {
  const DecoySettingsScreen({super.key});

  @override
  State<DecoySettingsScreen> createState() => _DecoySettingsScreenState();
}

class _DecoySettingsScreenState extends State<DecoySettingsScreen>
    with SingleTickerProviderStateMixin {

  final _decoy = DecoyService.instance;

  // Setup form controllers
  final _realCtrl  = TextEditingController();
  final _decoyCtrl = TextEditingController();
  final _panicCtrl = TextEditingController();
  bool _showReal   = false;
  bool _showDecoy  = false;
  bool _showPanic  = false;
  bool _saving     = false;
  String _error    = '';

  late final AnimationController _lockAnim;

  @override
  void initState() {
    super.initState();
    _lockAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _lockAnim.dispose();
    _realCtrl.dispose();
    _decoyCtrl.dispose();
    _panicCtrl.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    setState(() { _error = ''; _saving = true; });
    final real  = _realCtrl.text.trim();
    final decoy = _decoyCtrl.text.trim();
    final panic = _panicCtrl.text.trim();

    if (real.length  < 4) { setState(() { _error = 'Real PIN must be 4+ digits'; _saving = false; }); return; }
    if (decoy.length < 4) { setState(() { _error = 'Decoy PIN must be 4+ digits'; _saving = false; }); return; }
    if (real == decoy)    { setState(() { _error = 'Real and Decoy PINs must differ'; _saving = false; }); return; }
    if (panic.isNotEmpty && panic.length < 4) {
      setState(() { _error = 'Panic PIN must be 4+ digits'; _saving = false; }); return;
    }

    final ok = await _decoy.setupPins(
      realPin:  real, decoyPin: decoy,
      panicPin: panic.isEmpty ? null : panic,
    );
    setState(() => _saving = false);

    if (ok) {
      _realCtrl.clear(); _decoyCtrl.clear(); _panicCtrl.clear();
      HapticFeedback.mediumImpact();
      _snack('🎭 Decoy App configured!', AppColors.safeGreen);
    } else {
      setState(() => _error = 'Setup failed — PINs may conflict');
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context, builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      return AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear Decoy Setup?',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800)),
        content: const Text(
            'This will remove all PINs and disable Decoy App completely.',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(
                  fontFamily: 'Poppins', color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sosRed, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Clear All', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      );
    },
    );
    if (confirm == true) {
      await _decoy.clearAll();
      HapticFeedback.mediumImpact();
      _snack('🗑️ Decoy setup cleared', AppColors.warningAmber);
    }
  }

  void _snack(String m, [Color c = AppColors.sosRed]) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, style: const TextStyle(
            fontFamily: 'Poppins', fontWeight: FontWeight.w600,
            color: Colors.white)),
        backgroundColor: c, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? AppColors.darkBackground : const Color(0xFFFFF8F0);

    return Scaffold(
      backgroundColor: bg,
      appBar: _AppBar('Decoy App', isDark),
      body: ListenableBuilder(
        listenable: _decoy,
        builder: (_, __) => ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [

            // ── Hero Card ─────────────────────────────────────
            FadeInDown(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF2D1B69), Color(0xFF11090E)]),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(
                      color: const Color(0xFF2D1B69).withValues(alpha: 0.4),
                      blurRadius: 20)],
                ),
                child: Row(children: [
                  // Animated lock icon
                  AnimatedBuilder(animation: _lockAnim, builder: (_, __) =>
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1 + 0.05 * _lockAnim.value),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2 + 0.1 * _lockAnim.value),
                              width: 1),
                        ),
                        child: const Icon(Icons.theater_comedy_rounded,
                            color: Colors.white, size: 28),
                      ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Decoy App Protection',
                            style: TextStyle(color: Colors.white,
                                fontFamily: 'Poppins', fontWeight: FontWeight.w900,
                                fontSize: 16)),
                        const SizedBox(height: 3),
                        Text(
                          _decoy.isSetup
                              ? 'Configured · ${_decoy.isEnabled ? "Active 🟢" : "Disabled 🔴"}'
                              : 'Not configured — set up PINs below',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontFamily: 'Poppins', fontSize: 11),
                        ),
                        if (_decoy.isSetup && _decoy.isLockedOut) ...[
                          const SizedBox(height: 4),
                          Text(
                              '🔒 Locked out — ${_decoy.lockoutRemaining.inMinutes}m ${_decoy.lockoutRemaining.inSeconds % 60}s remaining',
                              style: const TextStyle(
                                  color: AppColors.warningAmber,
                                  fontFamily: 'Poppins', fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ])),
                  if (_decoy.isSetup)
                    Switch.adaptive(
                      value: _decoy.isEnabled,
                      activeColor: AppColors.safeGreen,
                      activeTrackColor: AppColors.safeGreen.withValues(alpha: 0.3),
                      inactiveThumbColor: Colors.grey,
                      onChanged: (v) {
                        HapticFeedback.lightImpact();
                        _decoy.setEnabled(v);
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 14),

            // How it works explainer
            FadeInDown(delay: const Duration(milliseconds: 60),
              child: _Card(isDark: isDark, child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  _HowRow('🔑', 'Real PIN', 'Opens SafeHer normally'),
                  const SizedBox(height: 8),
                  _HowRow('🎭', 'Decoy PIN', 'Shows fake app (calculator/notepad)'),
                  const SizedBox(height: 8),
                  _HowRow('🆘', 'Panic PIN', 'Silent SOS first, then shows decoy'),
                ]),
              )),
            ),
            const SizedBox(height: 22),

            // ── DECOY MODE ────────────────────────────────────
            FadeInUp(child: _Label('DECOY APP APPEARANCE')),
            const SizedBox(height: 10),
            FadeInUp(delay: const Duration(milliseconds: 50),
              child: _Card(isDark: isDark, child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('When Decoy PIN is entered, show:',
                          style: TextStyle(fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 12),
                      Row(children: DecoyMode.values.map((m) {
                        final sel = _decoy.mode == m;
                        final data = {
                          DecoyMode.calculator: ('🧮', 'Calculator'),
                          DecoyMode.notepad:    ('📝', 'Notepad'),
                          DecoyMode.weather:    ('🌤️', 'Weather'),
                        }[m]!;
                        return Expanded(child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _decoy.setMode(m);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              gradient: sel ? const LinearGradient(
                                  colors: [Color(0xFF2D1B69), Color(0xFF4A44C6)])
                                  : null,
                              color: sel ? null
                                  : Colors.grey.withValues(alpha: isDark ? 0.1 : 0.07),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: sel ? [const BoxShadow(
                                  color: Color(0x552D1B69), blurRadius: 12)] : [],
                            ),
                            child: Column(children: [
                              Text(data.$1, style: const TextStyle(fontSize: 22)),
                              const SizedBox(height: 4),
                              Text(data.$2, style: TextStyle(
                                  fontFamily: 'Poppins', fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: sel ? Colors.white : Colors.grey)),
                            ]),
                          ),
                        ));
                      }).toList()),
                    ]),
              )),
            ),
            const SizedBox(height: 22),

            // ── PIN SETUP ─────────────────────────────────────
            FadeInUp(delay: const Duration(milliseconds: 80),
                child: _Label(_decoy.isSetup ? 'CHANGE PINS' : 'SET UP PINS')),
            const SizedBox(height: 10),
            FadeInUp(delay: const Duration(milliseconds: 100),
              child: _Card(isDark: isDark, child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PinField(ctrl: _realCtrl, label: 'Real PIN (opens SafeHer)',
                          show: _showReal, isDark: isDark, color: AppColors.primary,
                          onToggle: () => setState(() => _showReal = !_showReal)),
                      const SizedBox(height: 10),
                      _PinField(ctrl: _decoyCtrl, label: 'Decoy PIN (fake app)',
                          show: _showDecoy, isDark: isDark,
                          color: AppColors.secondary,
                          onToggle: () => setState(() => _showDecoy = !_showDecoy)),
                      const SizedBox(height: 10),
                      _PinField(ctrl: _panicCtrl,
                          label: 'Panic PIN (SOS + fake app) — optional',
                          show: _showPanic, isDark: isDark,
                          color: AppColors.sosRed,
                          onToggle: () => setState(() => _showPanic = !_showPanic)),

                      if (_error.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              color: AppColors.sosRed.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(10)),
                          child: Row(children: [
                            const Icon(Icons.error_outline_rounded,
                                color: AppColors.sosRed, size: 15),
                            const SizedBox(width: 8),
                            Text(_error, style: const TextStyle(
                                color: AppColors.sosRed, fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600, fontSize: 12)),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _setup,
                          icon: _saving
                              ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.theater_comedy_rounded, size: 18),
                          label: Text(
                            _saving ? 'Saving...'
                                : (_decoy.isSetup ? 'Update Pins' : 'Activate Decoy'),
                            style: const TextStyle(fontFamily: 'Poppins',
                                fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D1B69),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ]),
              )),
            ),

            if (_decoy.isSetup) ...[
              const SizedBox(height: 12),
              FadeInUp(delay: const Duration(milliseconds: 120),
                child: SizedBox(width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _clearAll,
                    icon: const Icon(Icons.delete_forever_rounded, size: 18),
                    label: const Text('Clear All Decoy Settings',
                        style: TextStyle(fontFamily: 'Poppins',
                            fontWeight: FontWeight.w700, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.sosRed,
                      side: BorderSide(
                          color: AppColors.sosRed.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _HowRow extends StatelessWidget {
  final String emoji, label, sub;
  const _HowRow(this.emoji, this.label, this.sub);
  @override
  Widget build(BuildContext context) => Row(children: [
    Text(emoji, style: const TextStyle(fontSize: 18)),
    const SizedBox(width: 10),
    Text('$label: ', style: const TextStyle(fontFamily: 'Poppins',
        fontWeight: FontWeight.w700, fontSize: 12)),
    Expanded(child: Text(sub, style: const TextStyle(
        color: Colors.grey, fontFamily: 'Poppins', fontSize: 11))),
  ]);
}

PreferredSizeWidget _AppBar(String title, bool isDark) => AppBar(
  backgroundColor: Colors.transparent, elevation: 0,
  iconTheme: IconThemeData(
      color: isDark ? Colors.white : AppColors.lightText),
  title: Text(title, style: const TextStyle(
      fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 18)),
  bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: Colors.grey.withValues(alpha: 0.1))),
);

class _Label extends StatelessWidget {
  final String text; const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(color: Colors.grey.withValues(alpha: 0.6),
          fontSize: 10, fontFamily: 'Poppins',
          fontWeight: FontWeight.w800, letterSpacing: 1.4));
}

class _Card extends StatelessWidget {
  final bool isDark; final Widget child;
  const _Card({required this.isDark, required this.child});
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.cardShadow),
      child: ClipRRect(borderRadius: BorderRadius.circular(20), child: child));
}

class _PinField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label; final bool show, isDark; final Color color;
  final VoidCallback onToggle;
  const _PinField({required this.ctrl, required this.label,
    required this.show, required this.isDark,
    required this.color, required this.onToggle});
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl, obscureText: !show,
    keyboardType: TextInputType.number, maxLength: 8,
    style: const TextStyle(fontFamily: 'Poppins', fontSize: 18,
        letterSpacing: 6, fontWeight: FontWeight.w800),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 11),
      prefixIcon: Icon(Icons.pin_rounded, color: color, size: 20),
      suffixIcon: IconButton(
          icon: Icon(show ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: Colors.grey, size: 20),
          onPressed: onToggle),
      counterText: '', filled: true,
      fillColor: isDark ? AppColors.darkBackground
          : color.withValues(alpha: 0.04),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 1.5)),
    ),
  );
}