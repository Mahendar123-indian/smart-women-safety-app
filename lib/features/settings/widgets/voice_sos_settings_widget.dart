// lib/features/settings/widgets/voice_sos_settings_widget.dart
// ─────────────────────────────────────────────────────────────────────────────
// VOICE SOS + HARDWARE SOS SETTINGS WIDGET
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/voice_sos_service.dart';
import '../../../core/services/hardware_sos_service.dart';
import '../../../core/theme/app_colors.dart';

class VoiceSosSettingsWidget extends StatefulWidget {
  const VoiceSosSettingsWidget({super.key});
  @override
  State<VoiceSosSettingsWidget> createState() => _VoiceSosSettingsWidgetState();
}

class _VoiceSosSettingsWidgetState extends State<VoiceSosSettingsWidget>
    with SingleTickerProviderStateMixin {

  final _voiceService    = VoiceSosService.instance;
  final _hardwareService = HardwareSosService.instance;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _voiceService.initialize();
    _hardwareService.initialize();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(children: [
      _buildVoiceSosCard(isDark),
      const SizedBox(height: 12),
      _buildHardwareSosCard(isDark),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────
  // VOICE SOS CARD
  // ─────────────────────────────────────────────────────────────────
  Widget _buildVoiceSosCard(bool isDark) {
    return ListenableBuilder(
      listenable: _voiceService,
      builder: (_, __) {
        final enabled  = _voiceService.isEnabled;
        final state    = _voiceService.state;
        final detected = state == VoiceSosState.detected || state == VoiceSosState.triggered;

        return Container(
          decoration: BoxDecoration(
            color:        isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: enabled ? Border.all(
              color: detected ? AppColors.sosRed : AppColors.primary,
              width: detected ? 2 : 1,
            ) : null,
            boxShadow: AppColors.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header row ────────────────────────────────────
                  Row(children: [
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, __) => Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: (enabled
                              ? (detected ? AppColors.sosRed : AppColors.primary)
                              : Colors.grey)
                              .withValues(alpha: 0.1 + (enabled ? 0.05 * _pulseCtrl.value : 0)),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.mic_rounded,
                          color: enabled
                              ? (detected ? AppColors.sosRed : AppColors.primary)
                              : Colors.grey,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Voice Keyword SOS',
                          style: TextStyle(fontFamily: 'Poppins',
                              fontWeight: FontWeight.w800, fontSize: 14)),
                      Text(_statusLabel(state),
                          style: TextStyle(
                              fontFamily: 'Poppins', fontSize: 11,
                              color: _statusColor(state))),
                    ])),
                    Switch.adaptive(
                      value:       enabled,
                      activeColor: AppColors.primary,
                      onChanged: (v) {
                        HapticFeedback.lightImpact();
                        _voiceService.setEnabled(v);
                      },
                    ),
                  ]),

                  if (enabled) ...[
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    // ── Detected Warning ─────────────────────────────
                    if (detected) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.sosRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppColors.sosRed.withValues(alpha: 0.3)),
                        ),
                        child: Row(children: [
                          AnimatedBuilder(
                            animation: _pulseCtrl,
                            builder: (_, __) => Icon(
                              Icons.mic_external_on_rounded,
                              size: 32,
                              color: Color.lerp(AppColors.sosRed,
                                  AppColors.sosRedDark, _pulseCtrl.value),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Keyword Detected!',
                                    style: TextStyle(fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w800, fontSize: 13,
                                        color: AppColors.sosRed)),
                                Text(
                                  '"${_voiceService.lastEvent?.keyword ?? ''}" heard',
                                  style: const TextStyle(fontFamily: 'Poppins',
                                      fontSize: 11, color: Colors.grey),
                                ),
                              ])),
                          TextButton(
                            onPressed: _voiceService.cancelDetection,
                            child: const Text("I'm Safe",
                                style: TextStyle(fontFamily: 'Poppins',
                                    color: AppColors.safeGreen,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── Sensitivity slider ─────────────────────────
                    Row(children: [
                      const Text('Sensitivity', style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 12, color: Colors.grey)),
                      const Spacer(),
                      Text(_sensitivityLabel(_voiceService.sensitivity),
                          style: const TextStyle(fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700, fontSize: 12,
                              color: AppColors.primary)),
                    ]),
                    Slider(
                      value:       _voiceService.sensitivity,
                      min:         0.3,
                      max:         0.95,
                      divisions:   13,
                      activeColor: AppColors.primary,
                      onChanged:   (v) => _voiceService.setSensitivity(v),
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('More Triggers', style: TextStyle(
                            fontFamily: 'Poppins', fontSize: 9, color: Colors.grey)),
                        Text('Fewer False Alarms', style: TextStyle(
                            fontFamily: 'Poppins', fontSize: 9, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Keywords display ───────────────────────────
                    const Text('Trigger Keywords',
                        style: TextStyle(fontFamily: 'Poppins',
                            fontWeight: FontWeight.w700, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: [
                        'help', 'bachao', 'save me', 'chhodo', 'madad karo',
                        'help me', 'danger', 'chhod do', 'let me go',
                      ].map((kw) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Text(kw, style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 10,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                      )).toList(),
                    ),
                  ],
                ]),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // HARDWARE SOS CARD
  // ─────────────────────────────────────────────────────────────────
  Widget _buildHardwareSosCard(bool isDark) {
    return ListenableBuilder(
      listenable: _hardwareService,
      builder: (_, __) {
        final enabled = _hardwareService.isEnabled;
        return Container(
          decoration: BoxDecoration(
            color:        isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow:    AppColors.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header row ────────────────────────────────────
                  Row(children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: (enabled ? AppColors.secondary : Colors.grey)
                            .withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.volume_down_rounded,
                          color: enabled ? AppColors.secondary : Colors.grey,
                          size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Hardware Button SOS',
                          style: TextStyle(fontFamily: 'Poppins',
                              fontWeight: FontWeight.w800, fontSize: 14)),
                      const Text('Volume hold & earphone triggers',
                          style: TextStyle(fontFamily: 'Poppins',
                              fontSize: 11, color: Colors.grey)),
                    ])),
                    Switch.adaptive(
                      value:       enabled,
                      activeColor: AppColors.secondary,
                      onChanged: (v) {
                        HapticFeedback.lightImpact();
                        _hardwareService.setEnabled(v);
                      },
                    ),
                  ]),

                  if (enabled) ...[
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    // Volume trigger toggle
                    _triggerRow(
                      emoji:     '🔊',
                      title:     'Hold Volume Down',
                      sub: 'Hold for ${(_hardwareService.volumeHoldMs / 1000).toStringAsFixed(1)}s',
                      enabled:   _hardwareService.volumeEnabled,
                      onChanged: _hardwareService.setVolumeEnabled,
                    ),
                    const SizedBox(height: 8),

                    // Earphone trigger toggle
                    _triggerRow(
                      emoji:     '🎧',
                      title:     'Earphone Button',
                      sub:       'Double or triple press',
                      enabled:   _hardwareService.earphoneEnabled,
                      onChanged: _hardwareService.setEarphoneEnabled,
                    ),
                    const SizedBox(height: 12),

                    // Hold duration slider
                    if (_hardwareService.volumeEnabled) ...[
                      Row(children: [
                        const Text('Volume hold duration',
                            style: TextStyle(fontFamily: 'Poppins',
                                fontSize: 12, color: Colors.grey)),
                        const Spacer(),
                        Text(
                          '${(_hardwareService.volumeHoldMs / 1000).toStringAsFixed(1)}s',
                          style: const TextStyle(fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700, fontSize: 12,
                              color: AppColors.secondary),
                        ),
                      ]),
                      Slider(
                        value:       _hardwareService.volumeHoldMs.toDouble(),
                        min:         1500,
                        max:         5000,
                        divisions:   7,
                        activeColor: AppColors.secondary,
                        onChanged:   (v) =>
                            _hardwareService.setVolumeHoldDuration(v.toInt()),
                      ),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('1.5s (Quick)', style: TextStyle(
                              fontFamily: 'Poppins', fontSize: 9, color: Colors.grey)),
                          Text('5s (Deliberate)', style: TextStyle(
                              fontFamily: 'Poppins', fontSize: 9, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Test button
                    SizedBox(width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.heavyImpact();
                          _hardwareService.testTrigger(
                              HardwareTriggerType.volumeHold);
                        },
                        icon:  const Icon(Icons.science_rounded, size: 16),
                        label: const Text('Test Trigger (no real SOS)',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.secondary,
                          side: BorderSide(
                              color: AppColors.secondary.withValues(alpha: 0.4)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ]),
          ),
        );
      },
    );
  }

  // ─── Trigger row helper ─────────────────────────────────────────
  Widget _triggerRow({
    required String emoji,
    required String title,
    required String sub,
    required bool enabled,
    required Future<void> Function(bool) onChanged,
  }) {
    return Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 20)),
      const SizedBox(width: 10),
      Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontFamily: 'Poppins',
            fontWeight: FontWeight.w600, fontSize: 13)),
        Text(sub, style: const TextStyle(fontFamily: 'Poppins',
            fontSize: 11, color: Colors.grey)),
      ])),
      Switch.adaptive(
        value:       enabled,
        activeColor: AppColors.secondary,
        onChanged:   (v) => onChanged(v),
      ),
    ]);
  }

  // ─── Status helpers ─────────────────────────────────────────────
  String _statusLabel(VoiceSosState state) {
    switch (state) {
      case VoiceSosState.inactive:  return 'Disabled';
      case VoiceSosState.listening: return '● Listening for keywords';
      case VoiceSosState.detected:  return '⚠️ Keyword detected!';
      case VoiceSosState.triggered: return 'SOS triggered';
      case VoiceSosState.cooldown:  return 'Cooldown — restarting soon';
    }
  }

  Color _statusColor(VoiceSosState state) {
    switch (state) {
      case VoiceSosState.listening: return AppColors.safeGreen;
      case VoiceSosState.detected:  return AppColors.warningAmber;
      case VoiceSosState.triggered: return AppColors.sosRed;
      case VoiceSosState.cooldown:  return AppColors.warningAmber;
      case VoiceSosState.inactive:  return Colors.grey;
    }
  }

  String _sensitivityLabel(double v) {
    if (v >= 0.85) return 'Very High';
    if (v >= 0.70) return 'High';
    if (v >= 0.55) return 'Medium';
    if (v >= 0.40) return 'Low';
    return 'Very Low';
  }
}