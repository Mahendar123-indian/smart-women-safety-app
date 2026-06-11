// lib/features/settings/screens/app_security_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// SAFEHER — APP SECURITY SETTINGS
// Wired to: BiometricProvider (enableBiometric, disableBiometric, biometricLabel,
//           isEnabled, isSupported, isLockedOut, lockoutSecondsRemaining,
//           hasFingerprint, hasFaceID, failedAttempts, maxAttempts)
// Also links to: DecoyService (isSetup, isEnabled)
// Auth: Firebase password reset via email
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../auth/providers/auth_provider.dart';
import '../providers/biometric_provider.dart';
import '../../../core/services/decoy_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/notification_service.dart';
import 'decoy_settings_screen.dart';

void _unawaited(Future<void> f) => f.catchError((_) {});

// ─────────────────────────────────────────────────────────────────────────────

class AppSecurityScreen extends StatefulWidget {
  const AppSecurityScreen({super.key});

  @override
  State<AppSecurityScreen> createState() => _AppSecurityScreenState();
}

class _AppSecurityScreenState extends State<AppSecurityScreen>
    with SingleTickerProviderStateMixin {

  bool _resettingPwd = false;
  late final AnimationController _shieldCtrl;

  @override
  void initState() {
    super.initState();
    _shieldCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _shieldCtrl.dispose(); super.dispose(); }

  Future<void> _resetPassword() async {
    final auth  = context.read<AuthProvider>();
    final email = auth.user?.email ?? '';
    if (email.isEmpty) { _snack('No email found on account'); return; }
    setState(() => _resettingPwd = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _snack('📧 Reset email sent to $email', AppColors.safeGreen);
    } catch (e) {
      _snack('❌ Failed to send reset email');
    }
    setState(() => _resettingPwd = false);
  }

  Future<void> _toggleBiometric(BiometricProvider bio) async {
    HapticFeedback.mediumImpact();
    bool ok;
    if (bio.isEnabled) {
      ok = await bio.disableBiometric();
    } else {
      ok = await bio.enableBiometric();
    }
    if (ok) {
      _unawaited(NotificationService.instance
          .showBiometricChanged(enabled: !bio.isEnabled));
      _snack(bio.isEnabled ? '🔒 App Lock enabled' : '🔓 App Lock disabled',
          bio.isEnabled ? AppColors.warningAmber : Colors.grey);
    } else if (bio.error != null) {
      _snack('⚠️ ${bio.error}');
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
    final bio    = context.watch<BiometricProvider>();
    final auth   = context.watch<AuthProvider>();
    final decoy  = DecoyService.instance;
    final bg     = isDark ? AppColors.darkBackground : const Color(0xFFFFF5F0);

    // Security score
    int score = 0;
    if (bio.isEnabled) score += 35;
    if (decoy.isEnabled && decoy.isSetup) score += 35;
    score += 30; // base (PIN exists)

    return Scaffold(
      backgroundColor: bg,
      appBar: _AppBar('App Security', isDark),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [

          // ── Security Score ────────────────────────────────────
          FadeInDown(
            child: AnimatedBuilder(animation: _shieldCtrl, builder: (_, __) {
              final secColor = score >= 80 ? AppColors.safeGreen
                  : score >= 50 ? AppColors.warningAmber : AppColors.sosRed;
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [secColor.withValues(alpha: 0.9), secColor],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(
                      color: secColor.withValues(
                          alpha: 0.35 + 0.1 * _shieldCtrl.value),
                      blurRadius: 20 + 6 * _shieldCtrl.value)],
                ),
                child: Row(children: [
                  // Score ring
                  SizedBox(width: 72, height: 72,
                    child: Stack(alignment: Alignment.center, children: [
                      SizedBox(width: 72, height: 72,
                        child: CircularProgressIndicator(
                          value: score / 100,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                          strokeWidth: 5,
                        ),
                      ),
                      Column(mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('$score',
                                style: const TextStyle(color: Colors.white,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w900, fontSize: 22)),
                            const Text('%', style: TextStyle(
                                color: Colors.white70, fontFamily: 'Poppins',
                                fontSize: 9)),
                          ]),
                    ]),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          score >= 80 ? '🛡️ Highly Secure'
                              : score >= 50 ? '⚠️ Moderately Secure'
                              : '🔓 Needs Improvement',
                          style: const TextStyle(color: Colors.white,
                              fontFamily: 'Poppins', fontWeight: FontWeight.w900,
                              fontSize: 17),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          score >= 80
                              ? 'All security layers active'
                              : 'Enable more features to increase score',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8),
                              fontFamily: 'Poppins', fontSize: 11),
                        ),
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, children: [
                          _ScorePill('SOS PIN ✓', Colors.white),
                          if (bio.isEnabled) _ScorePill('App Lock ✓', Colors.white),
                          if (decoy.isEnabled) _ScorePill('Decoy ✓', Colors.white),
                        ]),
                      ])),
                ]),
              );
            }),
          ),
          const SizedBox(height: 22),

          // ── BIOMETRIC / APP LOCK ──────────────────────────────
          FadeInUp(child: _Label('APP LOCK')),
          const SizedBox(height: 10),
          FadeInUp(delay: const Duration(milliseconds: 50),
            child: _Card(isDark: isDark, child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(width: 50, height: 50,
                          decoration: BoxDecoration(
                              color: (bio.isEnabled
                                  ? AppColors.warningAmber : Colors.grey)
                                  .withValues(alpha: 0.1),
                              shape: BoxShape.circle),
                          child: Icon(
                            bio.hasFingerprint
                                ? Icons.fingerprint_rounded
                                : bio.hasFaceID
                                ? Icons.face_rounded
                                : Icons.lock_rounded,
                            color: bio.isEnabled
                                ? AppColors.warningAmber : Colors.grey,
                            size: 26,
                          )),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(bio.biometricLabel,
                                style: const TextStyle(fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w800, fontSize: 14)),
                            Text(
                              bio.isEnabled
                                  ? 'App locked — ${bio.biometricLabel} required to open'
                                  : bio.isSupported
                                  ? 'Tap to enable biometric app lock'
                                  : 'Not supported on this device',
                              style: const TextStyle(color: Colors.grey,
                                  fontFamily: 'Poppins', fontSize: 11),
                            ),
                          ])),
                      bio.isLoading
                          ? const SizedBox(width: 24, height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary))
                          : Switch.adaptive(
                        value: bio.isEnabled,
                        activeColor: AppColors.warningAmber,
                        onChanged: bio.isSupported
                            ? (_) => _toggleBiometric(bio) : null,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ]),

                    if (bio.isLockedOut) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: AppColors.sosRed.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          const Icon(Icons.lock_clock_rounded,
                              color: AppColors.sosRed, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Locked out — ${bio.lockoutSecondsRemaining}s remaining '
                                '(${bio.failedAttempts}/${bio.maxAttempts} failed attempts)',
                            style: const TextStyle(color: AppColors.sosRed,
                                fontFamily: 'Poppins', fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ]),
                      ),
                    ],
                    if (!bio.isSupported) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Row(children: [
                          Icon(Icons.info_outline_rounded,
                              color: Colors.grey, size: 15),
                          SizedBox(width: 8),
                          Expanded(child: Text(
                              'Device does not support biometric authentication.',
                              style: TextStyle(color: Colors.grey,
                                  fontFamily: 'Poppins', fontSize: 11))),
                        ]),
                      ),
                    ],
                  ]),
            )),
          ),
          const SizedBox(height: 22),

          // ── DECOY APP ─────────────────────────────────────────
          FadeInUp(delay: const Duration(milliseconds: 70),
              child: _Label('DECOY APP')),
          const SizedBox(height: 10),
          FadeInUp(delay: const Duration(milliseconds: 80),
            child: GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const DecoySettingsScreen())),
              child: _Card(isDark: isDark,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(children: [
                    Container(width: 42, height: 42,
                        decoration: BoxDecoration(
                            color: const Color(0xFF2D1B69).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.theater_comedy_rounded,
                            color: Color(0xFF2D1B69), size: 22)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Decoy App',
                              style: TextStyle(fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                          Text(
                            ListenableBuilder(
                              listenable: decoy,
                              builder: (_, __) => const SizedBox.shrink(),
                            ) != null
                                ? ''
                                : '',
                            style: const TextStyle(color: Colors.grey,
                                fontFamily: 'Poppins', fontSize: 11),
                          ),
                          ListenableBuilder(
                            listenable: decoy,
                            builder: (_, __) => Text(
                              decoy.isSetup && decoy.isEnabled
                                  ? '✅ Active — Real/Decoy PINs configured'
                                  : decoy.isSetup && !decoy.isEnabled
                                  ? '⏸️ Configured but disabled'
                                  : '⚠️ Not configured — tap to set up',
                              style: const TextStyle(color: Colors.grey,
                                  fontFamily: 'Poppins', fontSize: 11),
                            ),
                          ),
                        ])),
                    const Icon(Icons.chevron_right_rounded,
                        color: Colors.grey, size: 22),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),

          // ── PASSWORD RESET ────────────────────────────────────
          FadeInUp(delay: const Duration(milliseconds: 100),
              child: _Label('ACCOUNT SECURITY')),
          const SizedBox(height: 10),
          FadeInUp(delay: const Duration(milliseconds: 120),
            child: _Card(isDark: isDark, child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _IconBadge(Icons.email_rounded, AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Reset Password',
                                style: TextStyle(fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w800, fontSize: 14)),
                            Text('Send link to: ${auth.user?.email ?? '—'}',
                                style: const TextStyle(color: Colors.grey,
                                    fontFamily: 'Poppins', fontSize: 11),
                                overflow: TextOverflow.ellipsis),
                          ])),
                    ]),
                    const SizedBox(height: 14),
                    SizedBox(width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _resettingPwd ? null : _resetPassword,
                        icon: _resettingPwd
                            ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(_resettingPwd
                            ? 'Sending...' : 'Send Reset Email',
                            style: const TextStyle(fontFamily: 'Poppins',
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
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

class _ScorePill extends StatelessWidget {
  final String text; final Color color;
  const _ScorePill(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: TextStyle(color: color,
        fontFamily: 'Poppins', fontSize: 9, fontWeight: FontWeight.w700)),
  );
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

class _IconBadge extends StatelessWidget {
  final IconData icon; final Color color;
  const _IconBadge(this.icon, this.color);
  @override
  Widget build(BuildContext context) => Container(
      width: 42, height: 42,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: color, size: 22));
}