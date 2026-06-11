// lib/features/settings/screens/voice_sos_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/services/voice_sos_service.dart';
import '../../../core/services/hardware_sos_service.dart';
import '../../../core/theme/app_colors.dart';

const List<String> _kDisplayKeywords = [
  'help', 'help me', 'save me', 'danger', 'emergency',
  'let me go', 'leave me', 'stop it', 'dont touch me',
  'bachao', 'madad karo', 'chhodo', 'chhod do',
  'help cheyyi', 'vaddu', 'utavi', 'kaapaatru'
];

class VoiceSosSettingsScreen extends StatefulWidget {
  const VoiceSosSettingsScreen({super.key});

  @override
  State<VoiceSosSettingsScreen> createState() => _VoiceSosSettingsScreenState();
}

class _VoiceSosSettingsScreenState extends State<VoiceSosSettingsScreen> with TickerProviderStateMixin {
  final _voice = VoiceSosService.instance;
  final _hardware = HardwareSosService.instance;

  late final AnimationController _pulseCtrl;
  late final AnimationController _waveCtrl;
  late final Animation<double> _pulse;
  late final Animation<double> _wave;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _waveCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

    _pulse = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _wave = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _waveCtrl, curve: Curves.linear));

    _voice.initialize();
    _hardware.initialize();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF3F0FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Voice & Hardware SOS', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildVoiceSection(isDark),
          const SizedBox(height: 24),
          _buildHardwareSection(isDark),
          const SizedBox(height: 24),
          _buildInfoBanner(),
        ],
      ),
    );
  }

  Widget _buildVoiceSection(bool isDark) {
    return ListenableBuilder(
      listenable: _voice,
      builder: (context, _) {
        final enabled = _voice.isEnabled;
        final state = _voice.state;
        final isDetected = state == VoiceSosState.detected || state == VoiceSosState.triggered;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('VOICE KEYWORD SOS', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: isDetected ? Border.all(color: AppColors.sosRed, width: 2) : null,
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildMicIcon(enabled, state),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Voice Sentinel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(_getStateLabel(state), style: TextStyle(color: _getStateColor(state), fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: enabled,
                        activeColor: AppColors.primary,
                        onChanged: (v) => _voice.setEnabled(v),
                      ),
                    ],
                  ),
                  if (enabled) ...[
                    const Divider(height: 32),
                    if (isDetected) _buildDetectionAlert(),
                    if (state == VoiceSosState.listening) _buildWaveAnimation(),
                    const SizedBox(height: 16),
                    _buildSensitivitySlider(),
                    const SizedBox(height: 20),
                    _buildKeywordChips(),
                  ]
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMicIcon(bool enabled, VoiceSosState state) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        return Container(
          width: 45, height: 45,
          decoration: BoxDecoration(
            color: (enabled ? AppColors.primary : Colors.grey).withOpacity(0.1 + (enabled ? 0.1 * _pulse.value : 0)),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.mic, color: enabled ? AppColors.primary : Colors.grey),
        );
      },
    );
  }

  Widget _buildDetectionAlert() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.sosRed.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          // ✅ FIXED: Removed the deleted countdown variable and replaced it with an animated warning icon
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              return Icon(
                Icons.warning_rounded,
                size: 32,
                color: Color.lerp(AppColors.sosRed, AppColors.sosRedDark, _pulse.value),
              );
            },
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('Keyword Heard!\nSOS triggering...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          ElevatedButton(
            onPressed: () => _voice.cancelDetection(),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.safeGreen),
            child: const Text('I AM SAFE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildWaveAnimation() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        return AnimatedBuilder(
          animation: _wave,
          builder: (context, _) {
            double h = 10 + (15 * Curves.easeInOut.transform((_wave.value + (i * 0.2)) % 1.0));
            return Container(width: 4, height: h, margin: const EdgeInsets.symmetric(horizontal: 2), decoration: BoxDecoration(color: AppColors.safeGreen, borderRadius: BorderRadius.circular(2)));
          },
        );
      }),
    );
  }

  Widget _buildSensitivitySlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Sensitivity', style: TextStyle(fontSize: 12, color: Colors.grey)),
            Text(_getSensitivityLabel(_voice.sensitivity), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: _voice.sensitivity,
          min: 0.3, max: 0.9,
          activeColor: AppColors.primary,
          onChanged: (v) => _voice.setSensitivity(v),
        ),
      ],
    );
  }

  Widget _buildKeywordChips() {
    return Wrap(
      spacing: 6, runSpacing: 6,
      children: _kDisplayKeywords.take(8).map((kw) => Chip(label: Text(kw, style: const TextStyle(fontSize: 10)), backgroundColor: AppColors.primary.withOpacity(0.05))).toList(),
    );
  }

  Widget _buildHardwareSection(bool isDark) {
    return ListenableBuilder(
      listenable: _hardware,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('HARDWARE TRIGGERS', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: isDark ? AppColors.darkCard : Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AppColors.cardShadow),
              child: Column(
                children: [
                  _buildHwRow('Volume Down Hold', 'Hold volume button for 3s', Icons.volume_down, _hardware.volumeEnabled, (v) => _hardware.setVolumeEnabled(v)),
                  const Divider(height: 32),
                  _buildHwRow('Earphone Clicks', 'Double/Triple click media button', Icons.headset, _hardware.earphoneEnabled, (v) => _hardware.setEarphoneEnabled(v)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHwRow(String title, String sub, IconData icon, bool val, Function(bool) toggle) {
    return Row(
      children: [
        Icon(icon, color: AppColors.secondary),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(sub, style: const TextStyle(fontSize: 11, color: Colors.grey))])),
        Switch.adaptive(value: val, onChanged: toggle, activeColor: AppColors.secondary),
      ],
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.secondary.withOpacity(0.1))),
      child: const Text('💡 Sentinel remains active even when the screen is off or the app is minimized.', style: TextStyle(fontSize: 11, color: AppColors.secondary)),
    );
  }

  String _getStateLabel(VoiceSosState s) {
    switch (s) {
      case VoiceSosState.listening: return '● Monitoring Environment';
      case VoiceSosState.detected: return '⚠️ KEYWORD DETECTED';
      case VoiceSosState.triggered: return 'SOS Fired';
      default: return 'Service Idle';
    }
  }

  Color _getStateColor(VoiceSosState s) {
    if (s == VoiceSosState.listening) return AppColors.safeGreen;
    if (s == VoiceSosState.detected) return AppColors.sosRed;
    if (s == VoiceSosState.triggered) return AppColors.sosRed;
    return Colors.grey;
  }

  String _getSensitivityLabel(double v) => v > 0.7 ? 'High' : (v > 0.5 ? 'Medium' : 'Low');
}