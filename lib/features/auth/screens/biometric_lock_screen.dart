// lib/features/auth/screens/biometric_lock_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../../settings/providers/biometric_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/router/app_router.dart';

class BiometricLockScreen extends StatefulWidget {
  const BiometricLockScreen({super.key});
  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  // This screen has 2 modes:
  // 1. Lock/Unlock settings (when navigated from drawer)
  // 2. App gate (when app opened with lock enabled — future use)
  bool get _isSettingsMode =>
      ModalRoute.of(context)?.settings.name == AppRouter.biometricLock;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);

    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _triggerShake() {
    HapticFeedback.heavyImpact();
    _shakeCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<BiometricProvider>(
      builder: (_, bio, __) {
        // In settings mode — show enable/disable toggle UI
        if (_isSettingsMode) {
          return _buildSettingsView(context, bio, isDark);
        }
        // Lock gate mode
        return _buildLockGateView(context, bio, isDark);
      },
    );
  }

  // ── SETTINGS MODE: Manage biometric lock ──────────────────
  Widget _buildSettingsView(
      BuildContext context, BiometricProvider bio, bool isDark) {
    return Scaffold(
      backgroundColor:
      isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppColors.cardShadow,
            ),
            child: Icon(Icons.arrow_back_ios_rounded,
                size: 16,
                color: isDark ? Colors.white : AppColors.lightText),
          ),
        ),
        title: const Text('App Lock & Security',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w800,
                fontSize: 18)),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Status Banner ──────────────────────────────────
          FadeInDown(
            child: _StatusBanner(bio: bio, isDark: isDark),
          ),
          const SizedBox(height: 24),

          // ── Biometric card ─────────────────────────────────
          FadeInUp(
            delay: const Duration(milliseconds: 80),
            child: _SectionLabel('BIOMETRIC LOCK'),
          ),
          const SizedBox(height: 10),
          FadeInUp(
            delay: const Duration(milliseconds: 100),
            child: _SettingsCard(isDark: isDark, children: [
              _BigToggleRow(
                icon: bio.hasFaceID
                    ? Icons.face_rounded
                    : Icons.fingerprint_rounded,
                label: bio.biometricLabel,
                subtitle: bio.isEnabled
                    ? 'Tap to disable app lock'
                    : 'Secure app with ${bio.biometricLabel.toLowerCase()}',
                value: bio.isEnabled,
                color: AppColors.primary,
                isLoading: bio.isLoading,
                isSupported: bio.isSupported,
                onToggle: (v) async {
                  if (v) {
                    final ok = await bio.enableBiometric();
                    if (!ok && context.mounted) {
                      _showSnack(context, '❌ Authentication failed. Try again.');
                    } else if (ok && context.mounted) {
                      _showSnack(context, '✅ App lock enabled successfully!');
                    }
                  } else {
                    final ok = await bio.disableBiometric();
                    if (!ok && context.mounted) {
                      _showSnack(context, '❌ Could not disable. Verify again.');
                    } else if (ok && context.mounted) {
                      _showSnack(context, '🔓 App lock disabled.');
                    }
                  }
                },
              ),
            ]),
          ),

          const SizedBox(height: 20),

          // ── Device capability info ─────────────────────────
          FadeInUp(
            delay: const Duration(milliseconds: 140),
            child: _SectionLabel('YOUR DEVICE'),
          ),
          const SizedBox(height: 10),
          FadeInUp(
            delay: const Duration(milliseconds: 160),
            child: _SettingsCard(isDark: isDark, children: [
              _InfoRow(
                icon: Icons.devices_rounded,
                label: 'Device Support',
                value: bio.isSupported ? 'Supported ✅' : 'Not supported ❌',
                color: bio.isSupported
                    ? AppColors.safeGreen
                    : AppColors.sosRed,
                isDark: isDark,
              ),
              _Divider(isDark),
              _InfoRow(
                icon: Icons.fingerprint_rounded,
                label: 'Fingerprint',
                value: bio.hasFingerprint ? 'Available ✅' : 'Not enrolled',
                color: bio.hasFingerprint
                    ? AppColors.safeGreen
                    : Colors.grey,
                isDark: isDark,
              ),
              _Divider(isDark),
              _InfoRow(
                icon: Icons.face_rounded,
                label: 'Face ID',
                value: bio.hasFaceID ? 'Available ✅' : 'Not enrolled',
                color: bio.hasFaceID
                    ? AppColors.safeGreen
                    : Colors.grey,
                isDark: isDark,
              ),
            ]),
          ),

          const SizedBox(height: 20),

          // ── How it works ───────────────────────────────────
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: _SectionLabel('HOW IT WORKS'),
          ),
          const SizedBox(height: 10),
          FadeInUp(
            delay: const Duration(milliseconds: 220),
            child: _SettingsCard(isDark: isDark, children: [
              _StepRow(step: '1', text: 'Enable App Lock above', isDark: isDark),
              _Divider(isDark),
              _StepRow(
                  step: '2',
                  text: 'App requires biometric every time you open it',
                  isDark: isDark),
              _Divider(isDark),
              _StepRow(
                  step: '3',
                  text: 'After 3 failed attempts, 1 min lockout applies',
                  isDark: isDark),
              _Divider(isDark),
              _StepRow(
                  step: '4',
                  text: 'SOS still works even when app is locked',
                  isDark: isDark),
            ]),
          ),

          const SizedBox(height: 20),

          // ── Test biometric ─────────────────────────────────
          if (bio.isSupported) ...[
            FadeInUp(
              delay: const Duration(milliseconds: 260),
              child: GestureDetector(
                onTap: () async {
                  final result = await bio.authenticate(
                    reason: 'Test your biometric authentication',
                  );
                  if (!context.mounted) return;
                  switch (result) {
                    case BiometricAuthResult.success:
                      _showSnack(context, '✅ Biometric works perfectly!',
                          color: AppColors.safeGreen);
                    case BiometricAuthResult.failed:
                      _showSnack(context,
                          '❌ Authentication failed (${bio.failedAttempts}/${bio.maxAttempts} attempts)');
                    case BiometricAuthResult.notEnrolled:
                      _showSnack(context,
                          '⚠️ No biometric enrolled. Set up in device settings.');
                    case BiometricAuthResult.unavailable:
                      _showSnack(context, '⚠️ Biometric unavailable on this device.');
                    case BiometricAuthResult.cancelled:
                      break;
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: AppColors.primary.withOpacity(0.4)),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          bio.hasFaceID
                              ? Icons.face_rounded
                              : Icons.fingerprint_rounded,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Test ${bio.biometricLabel}',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700,
                              fontSize: 15),
                        ),
                      ]),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ]),
      ),
    );
  }

  // ── LOCK GATE MODE: Actual authentication on app open ─────
  Widget _buildLockGateView(
      BuildContext context, BiometricProvider bio, bool isDark) {
    return WillPopScope(
      onWillPop: () async => false, // can't back out of lock
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF07071A) : Colors.white,
        body: SafeArea(
          child: Column(children: [
            // Top logo area
            Expanded(
              child: Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated shield
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (_, __) => Container(
                          width: 120 + 8 * _pulseCtrl.value,
                          height: 120 + 8 * _pulseCtrl.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.primaryGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(
                                    0.3 + 0.2 * _pulseCtrl.value),
                                blurRadius: 30 + 15 * _pulseCtrl.value,
                              )
                            ],
                          ),
                          child: const Icon(Icons.shield_rounded,
                              color: Colors.white, size: 56),
                        ),
                      ),

                      const SizedBox(height: 28),
                      const Text('SafeHer',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w900,
                              fontSize: 30,
                              letterSpacing: 1)),
                      const SizedBox(height: 8),
                      Text(
                        'Your safety, protected.',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: Colors.grey.withOpacity(0.7)),
                      ),
                    ]),
              ),
            ),

            // Bottom auth area
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 48),
              child: Column(children: [
                // Lockout warning
                if (bio.isLockedOut) ...[
                  FadeIn(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.sosRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.sosRed.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.timer_off_rounded,
                            color: AppColors.sosRed, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Too many failed attempts. Try again in ${bio.lockoutSecondsRemaining}s',
                            style: const TextStyle(
                                color: AppColors.sosRed,
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Failed attempt dots
                if (bio.failedAttempts > 0 && !bio.isLockedOut) ...[
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    ...List.generate(
                        bio.maxAttempts,
                            (i) => Container(
                          width: 10,
                          height: 10,
                          margin:
                          const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i < bio.failedAttempts
                                ? AppColors.sosRed
                                : Colors.grey.withOpacity(0.3),
                          ),
                        )),
                  ]),
                  const SizedBox(height: 16),
                ],

                // Biometric button
                AnimatedBuilder(
                  animation: _shakeAnim,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(
                        8 * (0.5 - _shakeAnim.value).abs() *
                            (_shakeCtrl.isAnimating ? 1 : 0),
                        0),
                    child: child,
                  ),
                  child: GestureDetector(
                    onTap: bio.isLockedOut
                        ? null
                        : () async {
                      final result = await bio.authenticate();
                      if (!context.mounted) return;
                      if (result == BiometricAuthResult.success) {
                        Navigator.pushReplacementNamed(
                            context, AppRouter.home);
                      } else if (result == BiometricAuthResult.failed) {
                        _triggerShake();
                      } else if (result ==
                          BiometricAuthResult.notEnrolled) {
                        _showEnrollDialog(context);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: bio.isLockedOut
                            ? const LinearGradient(
                            colors: [Colors.grey, Colors.grey])
                            : AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: bio.isLockedOut
                            ? []
                            : [
                          BoxShadow(
                            color:
                            AppColors.primary.withOpacity(0.4),
                            blurRadius: 20,
                          )
                        ],
                      ),
                      child: bio.isLoading
                          ? const Center(
                          child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5)))
                          : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            bio.hasFaceID
                                ? Icons.face_rounded
                                : Icons.fingerprint_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            bio.isLockedOut
                                ? 'Locked (${bio.lockoutSecondsRemaining}s)'
                                : 'Unlock with ${bio.biometricLabel}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w800,
                                fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Error message
                if (bio.error != null)
                  Text(
                    bio.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.sosRed,
                        fontFamily: 'Poppins',
                        fontSize: 12),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  void _showEnrollDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('No Biometric Enrolled',
            style: TextStyle(
                fontFamily: 'Poppins', fontWeight: FontWeight.w800)),
        content: const Text(
            'Please set up fingerprint or Face ID in your device Settings to use App Lock.',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              Navigator.pop(context);
              // Open device settings - user handles enrollment there
            },
            child: const Text('Open Settings',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnack(BuildContext context, String msg,
      {Color color = AppColors.sosRed}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(
              fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }
}

// ── Shared Widgets ──────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final BiometricProvider bio;
  final bool isDark;
  const _StatusBanner({required this.bio, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isOn = bio.isEnabled;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isOn ? AppColors.primaryGradient : AppColors.darkCardGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isOn
            ? [
          BoxShadow(
              color: AppColors.primary.withOpacity(0.35),
              blurRadius: 20)
        ]
            : AppColors.cardShadow,
      ),
      child: Row(children: [
        Container(
          width: 54, height: 54,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(isOn ? 0.2 : 0.08)),
          child: Icon(
            isOn ? Icons.lock_rounded : Icons.lock_open_rounded,
            color: isOn ? Colors.white : Colors.grey,
            size: 26,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            isOn ? '🔒 App Lock Active' : '🔓 App Lock Disabled',
            style: TextStyle(
                color: isOn ? Colors.white : Colors.grey,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w800,
                fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            isOn
                ? 'Your app is secured with ${bio.biometricLabel}'
                : 'Enable to protect your SafeHer data',
            style: TextStyle(
                color: isOn
                    ? Colors.white.withOpacity(0.85)
                    : Colors.grey.withOpacity(0.7),
                fontFamily: 'Poppins',
                fontSize: 12),
          ),
        ])),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) => Text(label,
      style: TextStyle(
          color: Colors.grey.withOpacity(0.6),
          fontSize: 11,
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2));
}

class _SettingsCard extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;
  const _SettingsCard({required this.isDark, required this.children});
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.cardShadow),
      child: Column(children: children));
}

class _BigToggleRow extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final bool value, isLoading, isSupported;
  final Color color;
  final void Function(bool) onToggle;
  const _BigToggleRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.color,
    required this.isLoading,
    required this.isSupported,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(children: [
      Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, color: color, size: 24),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
                fontSize: 14)),
        const SizedBox(height: 3),
        Text(
          !isSupported
              ? 'Not available on this device'
              : subtitle,
          style: const TextStyle(
              color: Colors.grey,
              fontFamily: 'Poppins',
              fontSize: 11),
        ),
      ])),
      isLoading
          ? const SizedBox(
          width: 28, height: 28,
          child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2.5))
          : Switch(
        value: value,
        onChanged: isSupported ? onToggle : null,
        activeColor: color,
      ),
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  final bool isDark;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(label,
          style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
              fontSize: 13))),
      Text(value,
          style: TextStyle(
              color: color,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 12)),
    ]),
  );
}

class _StepRow extends StatelessWidget {
  final String step, text;
  final bool isDark;
  const _StepRow(
      {required this.step, required this.text, required this.isDark});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 24, height: 24,
        decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle),
        child: Center(
          child: Text(step,
              style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w800,
                  fontSize: 11)),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(text,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.4)),
      ),
    ]),
  );
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider(this.isDark);
  @override
  Widget build(BuildContext context) => Divider(
      height: 1,
      indent: 62,
      color: isDark
          ? Colors.white.withOpacity(0.06)
          : Colors.grey.withOpacity(0.12));
}