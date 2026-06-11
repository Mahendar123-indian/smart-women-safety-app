// lib/features/settings/screens/ai_settings_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// SAFEHER — AI PROTECTION SETTINGS v4.0 (2026 PRODUCTION)
// ─────────────────────────────────────────────────────────────────────────────
// ✅ [FIX] Resolved undefined 'locationRisk' and 'dominantFactor' errors.
// ✅ [FIX] Mapped 'autoSosRecommended' to 'sosTriggered' for v4.0 sync.
// ✅ [SYNC] Full integration with Cloud Run health and 7-Factor breakdown.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/ml_monitoring_service.dart';
import '../../../core/services/ml_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen>
    with TickerProviderStateMixin {

  bool   _aiOn      = true;
  bool   _soundOn   = false;
  bool   _autoSosOn = true;
  double _threshold = 0.75;
  bool   _loaded    = false;
  bool   _backendOk = false;
  bool   _connecting = false;

  MLDangerResult _ml = MLDangerResult.safe();
  StreamSubscription<MLDangerResult>? _mlSub;
  Timer? _healthTimer;

  late final AnimationController _radarCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulse;

  @override
  void initState() {
    super.initState();
    _radarCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))..repeat();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _loadPrefs();
    _startMl();
    _checkBackend();
    _healthTimer = Timer.periodic(const Duration(seconds: 12), (_) => _checkBackend());
  }

  @override
  void dispose() {
    _radarCtrl.dispose();
    _pulseCtrl.dispose();
    _mlSub?.cancel();
    _healthTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _aiOn      = p.getBool('ai_monitoring')    ?? true;
      _soundOn   = p.getBool('sound_detection')  ?? false;
      _autoSosOn = p.getBool('auto_sos_enabled') ?? true;
      _threshold = p.getDouble(AppConstants.dangerThresholdKey) ?? 0.75;
      _loaded    = true;
    });
  }

  Future<void> _saveBool(String k, bool v) async =>
      (await SharedPreferences.getInstance()).setBool(k, v);
  Future<void> _saveDouble(String k, double v) async =>
      (await SharedPreferences.getInstance()).setDouble(k, v);

  void _startMl() {
    final ml = MLMonitoringService.instance;
    if (!ml.isRunning) ml.start();
    _ml = ml.latestResult;
    _mlSub = ml.resultStream.listen((r) {
      if (mounted) setState(() => _ml = r);
    });
  }

  Future<void> _checkBackend() async {
    final h = await MLMonitoringService.instance.getBackendHealth();
    if (mounted) setState(() => _backendOk = h != null);
  }

  Future<void> _reconnect() async {
    setState(() => _connecting = true);
    HapticFeedback.lightImpact();
    await MLApiService.instance.initialize();
    await _checkBackend();
    setState(() => _connecting = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_backendOk ? '✅ AI Backend connected!' : '⚠️ Backend unreachable — retrying.'),
        backgroundColor: _backendOk ? AppColors.safeGreen : AppColors.warningAmber,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? AppColors.darkBackground : const Color(0xFFEEF3FF);

    if (!_loaded) return Scaffold(backgroundColor: bg, body: const Center(child: CircularProgressIndicator(color: AppColors.primary)));

    final scoreColor   = AppColors.dangerLevelColor(_ml.score);
    final scorePct     = (_ml.scoreRaw).toInt();
    final thresholdPct = (_threshold * 100).toInt();

    // Mapping new score breakdown fields for UI display
    final locRisk = (_ml.scoreBreakdown['location'] as num? ?? 0.0).toInt();

    return Scaffold(
      backgroundColor: bg,
      appBar: _AppBar('AI Protection', isDark),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [

          // ── Live Radar Card ───────────────────────────────────
          FadeInDown(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: scoreColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(
                      color: scoreColor.withValues(alpha: 0.4 + 0.1 * _pulse.value),
                      blurRadius: 22 + 8 * _pulse.value)],
                ),
                child: Row(children: [
                  // Radar
                  AnimatedBuilder(animation: _radarCtrl, builder: (_, __) {
                    return SizedBox(width: 80, height: 80,
                      child: Stack(alignment: Alignment.center, children: [
                        ...List.generate(3, (i) => Container(
                          width: 36.0 + i * 20,
                          height: 36.0 + i * 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withValues(
                                    alpha: (0.4 - i * 0.1) *
                                        (1 - (_radarCtrl.value + i * 0.3) % 1.0)),
                                width: 1.5),
                          ),
                        )),
                        Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              shape: BoxShape.circle),
                          child: Center(child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('$scorePct%',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w900, fontSize: 16)),
                              ])),
                        ),
                      ]),
                    );
                  }),
                  const SizedBox(width: 16),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_ml.dangerLevelString.toUpperCase(),
                            style: const TextStyle(color: Colors.white,
                                fontFamily: 'Poppins', fontWeight: FontWeight.w900,
                                fontSize: 20)),
                        const Text('Live Danger Level',
                            style: TextStyle(
                                color: Colors.white70, fontFamily: 'Poppins',
                                fontSize: 11)),
                        const SizedBox(height: 8),
                        _MlRow('Movement', '${_ml.movementProb.toInt()}%'),
                        _MlRow('Audio Risk', '${_ml.audioProb.toInt()}%'),
                        _MlRow('Location', '$locRisk%'),
                        if (_ml.insights.isNotEmpty)
                          _MlRow('Primary Key', _ml.insights.first),
                      ])),
                  // Backend status pill
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                              color: (_backendOk
                                  ? AppColors.safeGreen : Colors.white)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            AnimatedBuilder(animation: _pulse, builder: (_, __) =>
                                Container(width: 6, height: 6,
                                    decoration: BoxDecoration(
                                        color: _backendOk
                                            ? AppColors.safeGreen : Colors.white,
                                        shape: BoxShape.circle))),
                            const SizedBox(width: 4),
                            Text(_backendOk ? 'Online' : 'Offline',
                                style: const TextStyle(color: Colors.white,
                                    fontFamily: 'Poppins', fontSize: 9,
                                    fontWeight: FontWeight.w700)),
                          ]),
                        ),
                        if (_ml.sosTriggered) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8)),
                            child: const Text('AUTO-SOS',
                                style: TextStyle(color: Colors.white,
                                    fontFamily: 'Poppins', fontSize: 8,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ]),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 22),

          // ── AI TOGGLES ────────────────────────────────────────
          FadeInUp(child: _Label('AI DETECTION MODULES')),
          const SizedBox(height: 10),
          FadeInUp(delay: const Duration(milliseconds: 60),
            child: _Card(isDark: isDark, child: Column(children: [
              _Toggle(
                icon: Icons.psychology_alt_rounded,
                iconBg: AppColors.primary,
                title: 'AI Danger Detection',
                sub: 'Real-time accelerometer + location fusion analysis',
                value: _aiOn,
                onChanged: (v) {
                  HapticFeedback.lightImpact();
                  setState(() => _aiOn = v);
                  _saveBool('ai_monitoring', v);
                  v ? MLMonitoringService.instance.start()
                      : MLMonitoringService.instance.stop();
                },
              ),
              _Div(isDark),
              _Toggle(
                icon: Icons.mic_rounded,
                iconBg: AppColors.warningAmber,
                title: 'Audio Danger Detection',
                sub: 'Detect screams and distress sounds in background',
                value: _soundOn,
                onChanged: (v) {
                  HapticFeedback.lightImpact();
                  setState(() => _soundOn = v);
                  _saveBool('sound_detection', v);
                },
              ),
              _Div(isDark),
              _Toggle(
                icon: Icons.auto_mode_rounded,
                iconBg: AppColors.sosRed,
                title: 'Auto-SOS on Critical Danger',
                sub: 'AI triggers SOS automatically when score exceeds threshold',
                value: _autoSosOn,
                onChanged: (v) {
                  HapticFeedback.lightImpact();
                  setState(() => _autoSosOn = v);
                  _saveBool('auto_sos_enabled', v);
                },
              ),
            ])),
          ),
          const SizedBox(height: 22),

          // ── THRESHOLD SLIDER ──────────────────────────────────
          FadeInUp(delay: const Duration(milliseconds: 80),
              child: _Label('AUTO-SOS TRIGGER THRESHOLD')),
          const SizedBox(height: 10),
          FadeInUp(delay: const Duration(milliseconds: 100),
            child: _Card(isDark: isDark, child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(width: 42, height: 42,
                          decoration: BoxDecoration(
                              color: AppColors.dangerLevelColor(_threshold)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.tune_rounded,
                              color: AppColors.dangerLevelColor(_threshold),
                              size: 22)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Danger Threshold',
                                style: TextStyle(fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w800, fontSize: 14)),
                            Text('Auto-SOS fires when AI score ≥ $thresholdPct%',
                                style: const TextStyle(color: Colors.grey,
                                    fontFamily: 'Poppins', fontSize: 11)),
                          ])),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                            color: AppColors.dangerLevelColor(_threshold),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(
                                color: AppColors.dangerLevelColor(_threshold)
                                    .withValues(alpha: 0.35),
                                blurRadius: 10)]),
                        child: Text('$thresholdPct%',
                            style: const TextStyle(color: Colors.white,
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w900, fontSize: 15)),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // Color-coded slider
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 6,
                        activeTrackColor: AppColors.dangerLevelColor(_threshold),
                        inactiveTrackColor: Colors.grey.withValues(alpha: 0.15),
                        thumbColor: AppColors.dangerLevelColor(_threshold),
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 10),
                        overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 20),
                      ),
                      child: Slider(
                        value: _threshold, min: 0.50, max: 0.95, divisions: 9,
                        onChanged: (v) {
                          setState(() => _threshold = v);
                          _saveDouble(AppConstants.dangerThresholdKey, v);
                        },
                      ),
                    ),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('50%', style: TextStyle(
                                    fontFamily: 'Poppins', fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.safeGreen)),
                                const Text('Sensitive', style: TextStyle(
                                    color: Colors.grey, fontFamily: 'Poppins', fontSize: 9)),
                              ]),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            const Text('95%', style: TextStyle(
                                fontFamily: 'Poppins', fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.sosRed)),
                            const Text('Less Alerts', style: TextStyle(
                                color: Colors.grey, fontFamily: 'Poppins', fontSize: 9)),
                          ]),
                        ]),
                    const SizedBox(height: 14),

                    // Level chips
                    Row(children: [
                      _LvlChip('LOW',  '< 50%',  AppColors.safeGreen, isDark),
                      const SizedBox(width: 6),
                      _LvlChip('MED',  '50-75%', AppColors.warningAmber, isDark),
                      const SizedBox(width: 6),
                      _LvlChip('HIGH', '75-90%', AppColors.dangerHigh, isDark),
                      const SizedBox(width: 6),
                      _LvlChip('CRIT', '> 90%',  AppColors.sosRed, isDark),
                    ]),
                  ]),
            )),
          ),
          const SizedBox(height: 22),

          // ── BACKEND STATUS ────────────────────────────────────
          FadeInUp(delay: const Duration(milliseconds: 120),
              child: _Label('AI BACKEND')),
          const SizedBox(height: 10),
          FadeInUp(delay: const Duration(milliseconds: 140),
            child: _Card(isDark: isDark, child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(children: [
                _InfoRow('Backend', _backendOk ? '🟢 Connected' : '🔴 Offline', isDark),
                _Divider(isDark),
                _InfoRow('Region', 'asia-south1 · Cloud Run', isDark),
                _Divider(isDark),
                _InfoRow('Architecture', '7-Factor Fusion Engine', isDark),
                _Divider(isDark),
                _InfoRow('Forensics', 'Welford Baseline Online', isDark),
                _Divider(isDark),
                _InfoRow('Safety Sync', 'Real-time 3s Analysis', isDark),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _connecting ? null : _reconnect,
                    icon: _connecting
                        ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(_connecting ? 'Reconnecting...' : 'Refresh AI Connection',
                        style: const TextStyle(fontFamily: 'Poppins',
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
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
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

// ─── Sub-widgets (Internal Helpers) ──────────────────────────────────────────

Widget _MlRow(String label, String value) => Padding(
  padding: const EdgeInsets.only(top: 2),
  child: Row(children: [
    Text('$label: ', style: TextStyle(
        color: Colors.white.withValues(alpha: 0.7),
        fontFamily: 'Poppins', fontSize: 10)),
    Text(value, style: const TextStyle(color: Colors.white,
        fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 10)),
  ]),
);

Widget _LvlChip(String label, String range, Color color, bool isDark) =>
    Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Column(children: [
        Text(label, style: TextStyle(color: color, fontFamily: 'Poppins',
            fontWeight: FontWeight.w800, fontSize: 11)),
        Text(range, style: const TextStyle(color: Colors.grey,
            fontFamily: 'Poppins', fontSize: 9)),
      ]),
    ));

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
  final String text;
  const _Label(this.text);
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
      child: ClipRRect(
          borderRadius: BorderRadius.circular(20), child: child));
}

class _Toggle extends StatelessWidget {
  final IconData icon; final Color iconBg;
  final String title, sub; final bool value;
  final ValueChanged<bool> onChanged;
  const _Toggle({required this.icon, required this.iconBg,
    required this.title, required this.sub,
    required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    child: Row(children: [
      Container(width: 42, height: 42,
          decoration: BoxDecoration(color: iconBg.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: iconBg, size: 22)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontFamily: 'Poppins',
                fontWeight: FontWeight.w700, fontSize: 13)),
            Text(sub, style: const TextStyle(color: Colors.grey,
                fontFamily: 'Poppins', fontSize: 11)),
          ])),
      Switch.adaptive(value: value, onChanged: onChanged,
          activeColor: iconBg,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
    ]),
  );
}

class _Div extends StatelessWidget {
  final bool isDark;
  const _Div(this.isDark);
  @override
  Widget build(BuildContext context) => Divider(height: 1, indent: 70,
      color: isDark ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.06));
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider(this.isDark);
  @override
  Widget build(BuildContext context) => Divider(height: 1,
      color: isDark ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.06));
}

class _InfoRow extends StatelessWidget {
  final String label, value; final bool isDark;
  const _InfoRow(this.label, this.value, this.isDark);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(
          fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13))),
      Text(value, style: const TextStyle(
          color: Colors.grey, fontFamily: 'Poppins', fontSize: 12)),
    ]),
  );
}