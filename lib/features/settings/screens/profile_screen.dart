// lib/features/profile/screens/profile_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// PROFILE SCREEN — Full Production Grade
// ✅ Zero Material Icons — all CustomPainter
// ✅ All withValues(alpha:) — zero withOpacity()
// ✅ No animate_do — pure Flutter animations
// ✅ Dark theme 100% matched to all SafeHer screens
// ✅ Photo upload: Gallery + Camera with ImagePicker + Firebase Storage
// ✅ Full form: name, phone, DOB, blood type, emergency notes
// ✅ Medical info, trust contacts display, app settings
// ✅ Firebase Auth + Firestore wired
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';

// ═══════════════════════════════════════════════════════════════════════
// PROFILE SCREEN ROOT
// ═══════════════════════════════════════════════════════════════════════

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {

  late AnimationController _entryCtrl;
  late AnimationController _bgCtrl;
  late AnimationController _avatarCtrl;
  late Animation<double> _entryFade;
  late Animation<double> _avatarScale;

  // Form controllers
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl   = TextEditingController();
  final _noteCtrl  = TextEditingController();
  final _cityCtrl  = TextEditingController();

  // State
  bool _loading      = true;
  bool _saving       = false;
  bool _uploadingImg = false;
  String? _photoUrl;
  File?   _localPhoto;
  String  _bloodType = 'O+';
  String  _gender    = 'Female';
  bool    _shareLocation   = true;
  bool    _nightMode       = true;
  bool    _biometricLock   = false;
  int     _emergencyDelay  = 5;
  int     _totalSosCount   = 0;
  int     _safeJourneys    = 0;
  int     _guardians       = 0;

  final _auth      = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage   = FirebaseStorage.instance;
  final _picker    = ImagePicker();

  static const _bloodTypes = ['A+','A-','B+','B-','O+','O-','AB+','AB-'];
  static const _genders    = ['Female','Male','Non-binary','Prefer not to say'];

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);

    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);

    _avatarCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _avatarScale = CurvedAnimation(parent: _avatarCtrl, curve: Curves.elasticOut);

    _entryCtrl.forward();
    _loadProfile();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _bgCtrl.dispose();
    _avatarCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    _noteCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = _auth.currentUser;
    if (user == null) { setState(() => _loading = false); return; }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final prefs = await SharedPreferences.getInstance();

      // Load stats
      final sosSnap = await _firestore
          .collection('sos_events')
          .where('uid', isEqualTo: user.uid)
          .get();
      final guardSnap = await _firestore
          .collection('contacts')
          .where('uid', isEqualTo: user.uid)
          .get();

      if (!mounted) return;

      final d = doc.data() ?? {};
      setState(() {
        _nameCtrl.text  = d['displayName'] ?? user.displayName ?? '';
        _phoneCtrl.text = d['phone']       ?? user.phoneNumber ?? '';
        _dobCtrl.text   = d['dob']         ?? '';
        _noteCtrl.text  = d['emergencyNote'] ?? '';
        _cityCtrl.text  = d['city']          ?? '';
        _photoUrl       = d['photoUrl']      ?? user.photoURL;
        _bloodType      = d['bloodType']     ?? 'O+';
        _gender         = d['gender']        ?? 'Female';
        _shareLocation  = prefs.getBool('auto_share_on_start') ?? true;
        _nightMode      = prefs.getBool('night_mode_auto')     ?? true;
        _biometricLock  = prefs.getBool('biometric_lock')      ?? false;
        _emergencyDelay = prefs.getInt('emergency_delay')      ?? 5;
        _totalSosCount  = sosSnap.docs.length;
        _guardians      = guardSnap.docs.length;
        _safeJourneys   = d['safeJourneys'] ?? 0;
        _loading        = false;
      });

      _avatarCtrl.forward();
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    HapticFeedback.selectionClick();
    Navigator.pop(context); // close bottom sheet

    try {
      final xf = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (xf == null || !mounted) return;
      final file = File(xf.path);
      setState(() { _localPhoto = file; _uploadingImg = true; });

      // Upload to Firebase Storage
      final user = _auth.currentUser;
      if (user != null) {
        final ref = _storage.ref('profile_photos/${user.uid}.jpg');
        await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
        final url = await ref.getDownloadURL();
        await _firestore.collection('users').doc(user.uid).set(
            {'photoUrl': url}, SetOptions(merge: true));
        await user.updatePhotoURL(url);
        if (mounted) setState(() { _photoUrl = url; _uploadingImg = false; });
      } else {
        if (mounted) setState(() => _uploadingImg = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingImg = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Photo upload failed: $e',
              style: const TextStyle(fontFamily: 'Poppins')),
          backgroundColor: AppColors.sosRed,
        ));
      }
    }
  }

  Future<void> _saveProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'displayName':   _nameCtrl.text.trim(),
        'phone':         _phoneCtrl.text.trim(),
        'dob':           _dobCtrl.text.trim(),
        'emergencyNote': _noteCtrl.text.trim(),
        'city':          _cityCtrl.text.trim(),
        'bloodType':     _bloodType,
        'gender':        _gender,
        'updatedAt':     FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await user.updateDisplayName(_nameCtrl.text.trim());

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_share_on_start', _shareLocation);
      await prefs.setBool('night_mode_auto', _nightMode);
      await prefs.setBool('biometric_lock', _biometricLock);
      await prefs.setInt('emergency_delay', _emergencyDelay);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Profile saved successfully ✓',
              style: TextStyle(fontFamily: 'Poppins', color: Colors.white)),
          backgroundColor: AppColors.safeGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Save failed: $e',
              style: const TextStyle(fontFamily: 'Poppins')),
          backgroundColor: AppColors.sosRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.sosRed.withValues(alpha: 0.25)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: AppColors.sosRed.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Center(child: CustomPaint(size: const Size(26, 26),
                  painter: _LogoutPainter(color: AppColors.sosRed))),
            ),
            const SizedBox(height: 16),
            const Text('Sign Out?', style: TextStyle(fontFamily: 'Poppins',
                fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
            const SizedBox(height: 8),
            Text('You will need to sign in again to use SafeHer.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.50), height: 1.5)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, false),
                  child: Container(height: 46,
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14)),
                      child: const Center(child: Text('Cancel',
                          style: TextStyle(color: Colors.white,
                              fontFamily: 'Poppins', fontWeight: FontWeight.w600)))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, true),
                  child: Container(height: 46,
                      decoration: BoxDecoration(color: AppColors.sosRed,
                          borderRadius: BorderRadius.circular(14)),
                      child: const Center(child: Text('Sign Out',
                          style: TextStyle(color: Colors.white,
                              fontFamily: 'Poppins', fontWeight: FontWeight.w800)))),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
    if (confirm == true) {
      await _auth.signOut();
      if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Update Profile Photo', style: TextStyle(
              fontFamily: 'Poppins', fontWeight: FontWeight.w800,
              fontSize: 16, color: Colors.white)),
          const SizedBox(height: 20),
          _PhotoOptionTile(
            painter: _CameraIconPainter(color: AppColors.primary),
            iconColor: AppColors.primary,
            title: 'Take Photo',
            sub: 'Open camera and take a new photo',
            onTap: () => _pickPhoto(ImageSource.camera),
          ),
          const SizedBox(height: 10),
          _PhotoOptionTile(
            painter: _GalleryIconPainter(color: AppColors.secondary),
            iconColor: AppColors.secondary,
            title: 'Choose from Gallery',
            sub: 'Select an existing photo',
            onTap: () => _pickPhoto(ImageSource.gallery),
          ),
          if (_photoUrl != null || _localPhoto != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                final user = _auth.currentUser;
                if (user != null) {
                  try {
                    await _storage.ref('profile_photos/${user.uid}.jpg').delete();
                  } catch (_) {}
                  await _firestore.collection('users').doc(user.uid)
                      .update({'photoUrl': FieldValue.delete()});
                  await user.updatePhotoURL(null);
                }
                if (mounted) setState(() { _photoUrl = null; _localPhoto = null; });
              },
              child: Container(
                width: double.infinity, height: 46,
                decoration: BoxDecoration(
                  color: AppColors.sosRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.sosRed.withValues(alpha: 0.25)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  CustomPaint(size: const Size(16, 16),
                      painter: _DeleteSmPainter(color: AppColors.sosRed)),
                  const SizedBox(width: 8),
                  const Text('Remove Photo', style: TextStyle(
                      color: AppColors.sosRed, fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(children: [
        _buildBackground(size),
        SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : FadeTransition(
            opacity: _entryFade,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: Column(children: [
                  _buildTopBar(user),
                  _buildAvatarSection(user),
                  _buildStatsRow(),
                ])),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList(delegate: SliverChildListDelegate([
                    _buildSectionTitle('PERSONAL INFORMATION'),
                    const SizedBox(height: 10),
                    _buildPersonalCard(),
                    const SizedBox(height: 22),

                    _buildSectionTitle('MEDICAL INFORMATION'),
                    const SizedBox(height: 10),
                    _buildMedicalCard(),
                    const SizedBox(height: 22),

                    _buildSectionTitle('SAFETY PREFERENCES'),
                    const SizedBox(height: 10),
                    _buildSafetyCard(),
                    const SizedBox(height: 22),

                    _buildSectionTitle('ACCOUNT'),
                    const SizedBox(height: 10),
                    _buildAccountCard(user),
                    const SizedBox(height: 22),

                    // Save Button
                    GestureDetector(
                      onTap: _saving ? null : _saveProfile,
                      child: Container(
                        width: double.infinity, height: 56,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppColors.primaryShadow,
                        ),
                        child: _saving
                            ? const Center(child: SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)))
                            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          CustomPaint(size: const Size(20, 20),
                              painter: _SaveSmPainter(color: Colors.white)),
                          const SizedBox(width: 10),
                          const Text('Save Profile', style: TextStyle(
                              color: Colors.white, fontFamily: 'Poppins',
                              fontWeight: FontWeight.w800, fontSize: 16)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Sign out button
                    GestureDetector(
                      onTap: _signOut,
                      child: Container(
                        width: double.infinity, height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.sosRed.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.sosRed.withValues(alpha: 0.22)),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          CustomPaint(size: const Size(18, 18),
                              painter: _LogoutPainter(color: AppColors.sosRed)),
                          const SizedBox(width: 8),
                          const Text('Sign Out', style: TextStyle(
                              color: AppColors.sosRed, fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700, fontSize: 14)),
                        ]),
                      ),
                    ),
                  ])),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ─── Background ──────────────────────────────────────────────────────────
  Widget _buildBackground(Size size) {
    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (_, __) {
        final t = _bgCtrl.value;
        return Stack(children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF060614), Color(0xFF0C0C1E)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            top: -size.height * 0.05 + t * 20,
            right: -size.width * 0.20,
            child: Container(
              width: size.width * 0.70,
              height: size.width * 0.70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.primary.withValues(alpha: 0.04 + t * 0.03),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: -size.height * 0.06, left: -size.width * 0.10,
            child: Container(
              width: size.width * 0.65,
              height: size.width * 0.65,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.secondary.withValues(alpha: 0.03 + t * 0.02),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
        ]);
      },
    );
  }

  // ─── Top bar ─────────────────────────────────────────────────────────────
  Widget _buildTopBar(User? user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(children: [
        GestureDetector(
          onTap: () { HapticFeedback.selectionClick(); Navigator.pop(context); },
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Center(child: CustomPaint(size: const Size(16, 16),
                painter: _BackArrowPainter())),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('My Profile', style: TextStyle(fontFamily: 'Poppins',
              fontWeight: FontWeight.w800, fontSize: 20, color: Colors.white)),
          Text(user?.email ?? 'SafeHer User',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.40)),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.safeGreen.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.safeGreen.withValues(alpha: 0.25)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6,
                decoration: const BoxDecoration(
                    color: AppColors.safeGreen, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            const Text('Protected', style: TextStyle(color: AppColors.safeGreen,
                fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 10)),
          ]),
        ),
      ]),
    );
  }

  // ─── Avatar ──────────────────────────────────────────────────────────────
  Widget _buildAvatarSection(User? user) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(children: [
        ScaleTransition(
          scale: _avatarScale,
          child: GestureDetector(
            onTap: _showPhotoOptions,
            child: Stack(alignment: Alignment.center, children: [
              // Outer glow ring
              Container(
                width: 116, height: 116,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.60),
                      AppColors.secondary.withValues(alpha: 0.40),
                      AppColors.primary.withValues(alpha: 0.60),
                    ],
                  ),
                ),
              ),
              // Photo or initials
              Container(
                width: 110, height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.darkCard,
                ),
                clipBehavior: Clip.antiAlias,
                child: _uploadingImg
                    ? const Center(child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2.5))
                    : _localPhoto != null
                    ? Image.file(_localPhoto!, fit: BoxFit.cover)
                    : _photoUrl != null
                    ? Image.network(_photoUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildInitialsAvatar())
                    : _buildInitialsAvatar(),
              ),
              // Edit badge
              Positioned(
                bottom: 4, right: 4,
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.darkBackground, width: 2),
                    boxShadow: [BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.40), blurRadius: 8)],
                  ),
                  child: Center(child: CustomPaint(size: const Size(14, 14),
                      painter: _EditCamPainter(color: Colors.white))),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _nameCtrl.text.isEmpty
              ? (user?.displayName ?? 'SafeHer User')
              : _nameCtrl.text,
          style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800,
              fontSize: 20, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(_bloodType != 'Unknown' ? '🩸 Blood: $_bloodType  ·  $_gender' : _gender,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
                color: Colors.white.withValues(alpha: 0.45))),
      ]),
    );
  }

  Widget _buildInitialsAvatar() {
    final name = _nameCtrl.text.trim();
    final initials = name.isEmpty
        ? 'S'
        : name.split(' ').take(2).map((w) => w.isEmpty ? '' : w[0].toUpperCase()).join();
    return Container(
      color: AppColors.primary.withValues(alpha: 0.15),
      child: Center(
        child: Text(initials,
            style: const TextStyle(color: AppColors.primary,
                fontFamily: 'Poppins', fontWeight: FontWeight.w900, fontSize: 36)),
      ),
    );
  }

  // ─── Stats row ───────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(children: [
        _StatCard(
          value: '$_guardians',
          label: 'Guardians',
          painter: _ShieldSm(color: AppColors.primary),
          color: AppColors.primary,
        ),
        const SizedBox(width: 8),
        _StatCard(
          value: '$_totalSosCount',
          label: 'SOS Sent',
          painter: _SosSmPainter(color: AppColors.sosRed),
          color: AppColors.sosRed,
        ),
        const SizedBox(width: 8),
        _StatCard(
          value: '$_safeJourneys',
          label: 'Safe Trips',
          painter: _RouteSmPainter(color: AppColors.safeGreen),
          color: AppColors.safeGreen,
        ),
      ]),
    );
  }

  // ─── Personal card ───────────────────────────────────────────────────────
  Widget _buildPersonalCard() {
    return _GlassCard(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _ProfileField(
          label: 'Full Name',
          ctrl: _nameCtrl,
          hint: 'Your full name',
          painter: _PersonSmPainter(color: AppColors.primary),
        ),
        const SizedBox(height: 12),
        _ProfileField(
          label: 'Phone Number',
          ctrl: _phoneCtrl,
          hint: '+91 XXXXX XXXXX',
          keyboard: TextInputType.phone,
          painter: _PhoneSmPainter(color: AppColors.secondary),
        ),
        const SizedBox(height: 12),
        _ProfileField(
          label: 'Date of Birth',
          ctrl: _dobCtrl,
          hint: 'DD/MM/YYYY',
          painter: _CalSmPainter(color: AppColors.warningAmber),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime(2000),
              firstDate: DateTime(1940),
              lastDate: DateTime.now(),
              builder: (ctx, child) => Theme(
                data: ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(primary: AppColors.primary),
                ),
                child: child!,
              ),
            );
            if (picked != null) {
              _dobCtrl.text = '${picked.day.toString().padLeft(2,'0')}/${picked.month.toString().padLeft(2,'0')}/${picked.year}';
            }
          },
        ),
        const SizedBox(height: 12),
        _ProfileField(
          label: 'City / Area',
          ctrl: _cityCtrl,
          hint: 'Your city or area',
          painter: _CitySmPainter(color: AppColors.safeGreen),
        ),
        const SizedBox(height: 12),
        // Gender picker
        _DropdownField<String>(
          label: 'Gender',
          value: _gender,
          items: _genders,
          painter: _GenderSmPainter(color: AppColors.primary),
          onChanged: (v) => setState(() => _gender = v ?? 'Female'),
        ),
      ]),
    ));
  }

  // ─── Medical card ────────────────────────────────────────────────────────
  Widget _buildMedicalCard() {
    return _GlassCard(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Blood type
        _DropdownField<String>(
          label: 'Blood Type',
          value: _bloodType,
          items: _bloodTypes,
          painter: _BloodSmPainter(color: AppColors.sosRed),
          onChanged: (v) => setState(() => _bloodType = v ?? 'O+'),
        ),
        const SizedBox(height: 12),
        // Emergency note
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CustomPaint(size: const Size(16, 16),
                painter: _NoteSmPainter(color: AppColors.warningAmber)),
            const SizedBox(width: 8),
            const Text('Emergency Medical Notes', style: TextStyle(
                fontFamily: 'Poppins', fontWeight: FontWeight.w700,
                fontSize: 12, color: Colors.white)),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            maxLines: 3,
            maxLength: 200,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12,
                color: Colors.white, height: 1.5),
            decoration: InputDecoration(
              hintText: 'Allergies, conditions, medications... (optional)',
              hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.28)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              counterStyle: TextStyle(fontFamily: 'Poppins', fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.30)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ]),
      ]),
    ));
  }

  // ─── Safety preferences card ─────────────────────────────────────────────
  Widget _buildSafetyCard() {
    return _GlassCard(child: Column(children: [
      _PrefToggle(
        painter: _LocationSmPainter(color: AppColors.safeGreen),
        iconColor: AppColors.safeGreen,
        title: 'Auto-Share Location',
        sub: 'Share location on app start',
        value: _shareLocation,
        onChanged: (v) => setState(() => _shareLocation = v),
      ),
      _GlassDivider(),
      _PrefToggle(
        painter: _MoonSmPainter(color: AppColors.secondary),
        iconColor: AppColors.secondary,
        title: 'Auto Night Mode',
        sub: 'Enhanced monitoring 10PM–6AM',
        value: _nightMode,
        onChanged: (v) => setState(() => _nightMode = v),
      ),
      _GlassDivider(),
      _PrefToggle(
        painter: _FingerprintSmPainter(color: AppColors.primary),
        iconColor: AppColors.primary,
        title: 'Biometric Lock',
        sub: 'Lock app with fingerprint/face',
        value: _biometricLock,
        onChanged: (v) => setState(() => _biometricLock = v),
      ),
      _GlassDivider(),
      // Emergency delay
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.warningAmber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: CustomPaint(size: const Size(20, 20),
                painter: _TimerSmPainter(color: AppColors.warningAmber))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('SOS Countdown', style: TextStyle(fontFamily: 'Poppins',
                fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
            Text('Seconds before SOS fires',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.38))),
          ])),
          Row(children: [3, 5, 10].map((s) {
            final sel = _emergencyDelay == s;
            return GestureDetector(
              onTap: () { HapticFeedback.selectionClick(); setState(() => _emergencyDelay = s); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: sel ? AppColors.primaryGradient : null,
                  color: sel ? null : Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text('${s}s', style: TextStyle(fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700, fontSize: 11,
                    color: sel ? Colors.white : Colors.grey)),
              ),
            );
          }).toList()),
        ]),
      ),
    ]));
  }

  // ─── Account card ────────────────────────────────────────────────────────
  Widget _buildAccountCard(User? user) {
    return _GlassCard(child: Column(children: [
      _AccountTile(
        painter: _EmailSmPainter(color: AppColors.primary),
        iconColor: AppColors.primary,
        title: 'Email Address',
        value: user?.email ?? 'Not set',
      ),
      _GlassDivider(),
      _AccountTile(
        painter: _PhoneSmPainter(color: AppColors.secondary),
        iconColor: AppColors.secondary,
        title: 'Phone Number',
        value: user?.phoneNumber?.isNotEmpty == true
            ? user!.phoneNumber!
            : _phoneCtrl.text.trim().isEmpty
            ? 'Not set'
            : _phoneCtrl.text.trim(),
      ),
      _GlassDivider(),
      _AccountTile(
        painter: _VerifiedSmPainter(color: AppColors.safeGreen),
        iconColor: AppColors.safeGreen,
        title: 'Email Verified',
        value: user?.emailVerified == true ? '✓ Verified' : 'Not verified',
        valueColor: user?.emailVerified == true ? AppColors.safeGreen : AppColors.warningAmber,
      ),
      _GlassDivider(),
      GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/settings/sos'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.sosRed.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: CustomPaint(size: const Size(20, 20),
                  painter: _SosSmPainter(color: AppColors.sosRed))),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SOS Settings', style: TextStyle(fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
              Text('Triggers, countdown, PIN', style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 11, color: Colors.grey)),
            ])),
            CustomPaint(size: const Size(14, 14),
                painter: _ChevRightPainter(color: Colors.grey)),
          ]),
        ),
      ),
    ]));
  }

  Widget _buildSectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(t, style: TextStyle(
        fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 10,
        letterSpacing: 1.4, color: Colors.white.withValues(alpha: 0.32))),
  );
}

// ═══════════════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ═══════════════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final String value, label;
  final CustomPainter painter;
  final Color color;
  const _StatCard({required this.value, required this.label,
    required this.painter, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(children: [
        CustomPaint(size: const Size(20, 20), painter: painter),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: color, fontFamily: 'Poppins',
            fontWeight: FontWeight.w900, fontSize: 20)),
        Text(label, style: const TextStyle(fontFamily: 'Poppins',
            fontSize: 10, color: Colors.grey)),
      ]),
    ),
  );
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(20), child: child),
  );
}

class _GlassDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      height: 1, color: Colors.white.withValues(alpha: 0.06),
      margin: const EdgeInsets.symmetric(horizontal: 16));
}

class _ProfileField extends StatelessWidget {
  final String label, hint;
  final TextEditingController ctrl;
  final TextInputType? keyboard;
  final CustomPainter painter;
  final VoidCallback? onTap;

  const _ProfileField({
    required this.label, required this.hint,
    required this.ctrl, required this.painter,
    this.keyboard, this.onTap,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        CustomPaint(size: const Size(14, 14), painter: painter),
        const SizedBox(width: 7),
        Text(label, style: const TextStyle(fontFamily: 'Poppins',
            fontWeight: FontWeight.w700, fontSize: 12, color: Colors.white)),
      ]),
      const SizedBox(height: 7),
      GestureDetector(
        onTap: onTap,
        child: AbsorbPointer(
          absorbing: onTap != null,
          child: TextField(
            controller: ctrl,
            keyboardType: keyboard,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.28)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ),
    ],
  );
}

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final CustomPainter painter;
  final void Function(T?) onChanged;

  const _DropdownField({
    required this.label, required this.value,
    required this.items, required this.painter, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        CustomPaint(size: const Size(14, 14), painter: painter),
        const SizedBox(width: 7),
        Text(label, style: const TextStyle(fontFamily: 'Poppins',
            fontWeight: FontWeight.w700, fontSize: 12, color: Colors.white)),
      ]),
      const SizedBox(height: 7),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            dropdownColor: AppColors.darkCard,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white),
            icon: CustomPaint(size: const Size(12, 12),
                painter: _ChevDownPainter(color: Colors.grey)),
            items: items.map((item) => DropdownMenuItem<T>(
              value: item,
              child: Text(item.toString(),
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white)),
            )).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    ],
  );
}

class _PrefToggle extends StatelessWidget {
  final CustomPainter painter;
  final Color iconColor;
  final String title, sub;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PrefToggle({
    required this.painter, required this.iconColor,
    required this.title, required this.sub,
    required this.value, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    child: Row(children: [
      Container(width: 44, height: 44,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: CustomPaint(size: const Size(20, 20), painter: painter)),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontFamily: 'Poppins',
            fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
        Text(sub, style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
            color: Colors.white.withValues(alpha: 0.38))),
      ])),
      Switch.adaptive(value: value, onChanged: onChanged, activeColor: iconColor,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
    ]),
  );
}

class _AccountTile extends StatelessWidget {
  final CustomPainter painter;
  final Color iconColor;
  final String title, value;
  final Color? valueColor;

  const _AccountTile({
    required this.painter, required this.iconColor,
    required this.title, required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    child: Row(children: [
      Container(width: 44, height: 44,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: CustomPaint(size: const Size(20, 20), painter: painter)),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontFamily: 'Poppins',
            fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
        Text(value, style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
            color: valueColor ?? Colors.white.withValues(alpha: 0.45)),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
    ]),
  );
}

class _PhotoOptionTile extends StatelessWidget {
  final CustomPainter painter;
  final Color iconColor;
  final String title, sub;
  final VoidCallback onTap;

  const _PhotoOptionTile({
    required this.painter, required this.iconColor,
    required this.title, required this.sub, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(children: [
        Container(width: 46, height: 46,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Center(child: CustomPaint(size: const Size(22, 22), painter: painter)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontFamily: 'Poppins',
              fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
          Text(sub, style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
              color: Colors.white.withValues(alpha: 0.38))),
        ])),
        CustomPaint(size: const Size(14, 14), painter: _ChevRightPainter(color: Colors.grey)),
      ]),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════
// ALL CUSTOM PAINTERS
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

class _EditCamPainter extends CustomPainter {
  final Color color;
  const _EditCamPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, s.height * 0.22, s.width, s.height * 0.70), const Radius.circular(3)), p);
    canvas.drawCircle(Offset(s.width / 2, s.height * 0.57), s.width * 0.18, p);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * 0.35, 0, s.width * 0.30, s.height * 0.24), const Radius.circular(2)), p);
  }
  @override
  bool shouldRepaint(_EditCamPainter o) => o.color != color;
}

class _CameraIconPainter extends CustomPainter {
  final Color color;
  const _CameraIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, s.height * 0.20, s.width, s.height * 0.72), const Radius.circular(4)), p);
    canvas.drawCircle(Offset(s.width / 2, s.height * 0.56), s.width * 0.22, p);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * 0.34, 0, s.width * 0.32, s.height * 0.22), const Radius.circular(3)), p);
    canvas.drawCircle(Offset(s.width * 0.78, s.height * 0.32), s.width * 0.06, Paint()..color = color);
  }
  @override
  bool shouldRepaint(_CameraIconPainter o) => o.color != color;
}

class _GalleryIconPainter extends CustomPainter {
  final Color color;
  const _GalleryIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, s.width, s.height), const Radius.circular(4)), p);
    canvas.drawCircle(Offset(s.width * 0.28, s.height * 0.30), s.width * 0.12, p);
    final mtn = Path();
    mtn.moveTo(0, s.height * 0.78);
    mtn.lineTo(s.width * 0.36, s.height * 0.46);
    mtn.lineTo(s.width * 0.60, s.height * 0.64);
    mtn.lineTo(s.width * 0.78, s.height * 0.50);
    mtn.lineTo(s.width, s.height * 0.70);
    mtn.lineTo(s.width, s.height);
    mtn.lineTo(0, s.height);
    mtn.close();
    canvas.drawPath(mtn, Paint()..color = color.withValues(alpha: 0.25)..style = PaintingStyle.fill);
    canvas.drawPath(mtn, p);
  }
  @override
  bool shouldRepaint(_GalleryIconPainter o) => o.color != color;
}

class _ShieldSm extends CustomPainter {
  final Color color;
  const _ShieldSm({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final path = Path();
    path.moveTo(s.width * 0.50, 0);
    path.lineTo(s.width, s.height * 0.22);
    path.cubicTo(s.width, s.height * 0.22, s.width * 0.98, s.height * 0.72, s.width * 0.50, s.height);
    path.cubicTo(s.width * 0.02, s.height * 0.72, 0, s.height * 0.22, 0, s.height * 0.22);
    path.close();
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4..strokeJoin = StrokeJoin.round);
    canvas.drawCircle(Offset(s.width / 2, s.height * 0.48), s.width * 0.12, Paint()..color = color);
  }
  @override
  bool shouldRepaint(_ShieldSm o) => o.color != color;
}

class _SosSmPainter extends CustomPainter {
  final Color color;
  const _SosSmPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2;
    canvas.drawCircle(Offset(cx, cy), s.width * 0.44,
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 2, cy - s.height * 0.22, 4, s.height * 0.26), const Radius.circular(2)),
        Paint()..color = color);
    canvas.drawCircle(Offset(cx, cy + s.height * 0.14), 2.5, Paint()..color = color);
  }
  @override
  bool shouldRepaint(_SosSmPainter o) => o.color != color;
}

class _RouteSmPainter extends CustomPainter {
  final Color color;
  const _RouteSmPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    final path = Path();
    path.moveTo(s.width * 0.10, s.height * 0.80);
    path.cubicTo(s.width * 0.10, s.height * 0.40, s.width * 0.90, s.height * 0.60, s.width * 0.90, s.height * 0.20);
    canvas.drawPath(path, p);
    canvas.drawCircle(Offset(s.width * 0.10, s.height * 0.80), 2.5, Paint()..color = color);
    canvas.drawCircle(Offset(s.width * 0.90, s.height * 0.20), 2.5, Paint()..color = color);
  }
  @override
  bool shouldRepaint(_RouteSmPainter o) => o.color != color;
}

class _PersonSmPainter extends CustomPainter {
  final Color color;
  const _PersonSmPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(s.width * 0.50, s.height * 0.30), s.width * 0.20, p);
    final b = Path();
    b.moveTo(0, s.height);
    b.quadraticBezierTo(0, s.height * 0.60, s.width / 2, s.height * 0.60);
    b.quadraticBezierTo(s.width, s.height * 0.60, s.width, s.height);
    canvas.drawPath(b, p);
  }
  @override
  bool shouldRepaint(_PersonSmPainter o) => o.color != color;
}

class _PhoneSmPainter extends CustomPainter {
  final Color color;
  const _PhoneSmPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * 0.20, 0, s.width * 0.60, s.height), Radius.circular(s.width * 0.12)), p);
    canvas.drawLine(Offset(s.width * 0.38, s.height * 0.88), Offset(s.width * 0.62, s.height * 0.88), p);
  }
  @override
  bool shouldRepaint(_PhoneSmPainter o) => o.color != color;
}

class _CalSmPainter extends CustomPainter {
  final Color color;
  const _CalSmPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, s.height * 0.14, s.width, s.height * 0.86), const Radius.circular(3)), p);
    canvas.drawLine(Offset(0, s.height * 0.40), Offset(s.width, s.height * 0.40), p);
    canvas.drawLine(Offset(s.width * 0.28, 0), Offset(s.width * 0.28, s.height * 0.28), p);
    canvas.drawLine(Offset(s.width * 0.72, 0), Offset(s.width * 0.72, s.height * 0.28), p);
    canvas.drawCircle(Offset(s.width * 0.38, s.height * 0.65), 1.8, Paint()..color = color);
    canvas.drawCircle(Offset(s.width * 0.62, s.height * 0.65), 1.8, Paint()..color = color);
  }
  @override
  bool shouldRepaint(_CalSmPainter o) => o.color != color;
}

class _CitySmPainter extends CustomPainter {
  final Color color;
  const _CitySmPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3..strokeJoin = StrokeJoin.round;
    // Simple map pin
    final path = Path();
    path.moveTo(s.width / 2, 0);
    path.cubicTo(s.width * 0.16, 0, 0, s.height * 0.26, 0, s.height * 0.44);
    path.cubicTo(0, s.height * 0.62, s.width * 0.16, s.height * 0.76, s.width / 2, s.height);
    path.cubicTo(s.width * 0.84, s.height * 0.76, s.width, s.height * 0.62, s.width, s.height * 0.44);
    path.cubicTo(s.width, s.height * 0.26, s.width * 0.84, 0, s.width / 2, 0);
    path.close();
    canvas.drawPath(path, p);
    canvas.drawCircle(Offset(s.width / 2, s.height * 0.42), s.width * 0.14, Paint()..color = color);
  }
  @override
  bool shouldRepaint(_CitySmPainter o) => o.color != color;
}

class _GenderSmPainter extends CustomPainter {
  final Color color;
  const _GenderSmPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4..strokeCap = StrokeCap.round;
    // Venus symbol
    canvas.drawCircle(Offset(s.width / 2, s.height * 0.44), s.width * 0.28, p);
    canvas.drawLine(Offset(s.width / 2, s.height * 0.72), Offset(s.width / 2, s.height), p);
    canvas.drawLine(Offset(s.width * 0.30, s.height * 0.86), Offset(s.width * 0.70, s.height * 0.86), p);
  }
  @override
  bool shouldRepaint(_GenderSmPainter o) => o.color != color;
}

class _BloodSmPainter extends CustomPainter {
  final Color color;
  const _BloodSmPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final path = Path();
    path.moveTo(s.width / 2, 0);
    path.cubicTo(s.width * 0.80, s.height * 0.28, s.width, s.height * 0.52, s.width / 2, s.height);
    path.cubicTo(0, s.height * 0.52, s.width * 0.20, s.height * 0.28, s.width / 2, 0);
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.22)..style = PaintingStyle.fill);
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4..strokeJoin = StrokeJoin.round);
  }
  @override
  bool shouldRepaint(_BloodSmPainter o) => o.color != color;
}

class _NoteSmPainter extends CustomPainter {
  final Color color;
  const _NoteSmPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, s.width * 0.84, s.height), const Radius.circular(3)), p);
    for (int i = 0; i < 3; i++) {
      canvas.drawLine(Offset(s.width * 0.14, s.height * (0.28 + i * 0.22)),
          Offset(s.width * 0.70, s.height * (0.28 + i * 0.22)),
          Paint()..color = color..strokeWidth = 1.0..strokeCap = StrokeCap.round);
    }
    // Dog ear
    canvas.drawLine(Offset(s.width * 0.84, 0), Offset(s.width, s.height * 0.20), p);
    canvas.drawLine(Offset(s.width * 0.84, s.height * 0.20), Offset(s.width, s.height * 0.20), p);
  }
  @override
  bool shouldRepaint(_NoteSmPainter o) => o.color != color;
}

class _LocationSmPainter extends CustomPainter {
  final Color color;
  const _LocationSmPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3;
    final path = Path();
    path.moveTo(s.width / 2, 0);
    path.cubicTo(s.width * 0.18, 0, 0, s.height * 0.26, 0, s.height * 0.46);
    path.cubicTo(0, s.height * 0.66, s.width * 0.18, s.height * 0.80, s.width / 2, s.height);
    path.cubicTo(s.width * 0.82, s.height * 0.80, s.width, s.height * 0.66, s.width, s.height * 0.46);
    path.cubicTo(s.width, s.height * 0.26, s.width * 0.82, 0, s.width / 2, 0);
    path.close();
    canvas.drawPath(path, p);
    canvas.drawCircle(Offset(s.width / 2, s.height * 0.44), s.width * 0.14, Paint()..color = color);
  }
  @override
  bool shouldRepaint(_LocationSmPainter o) => o.color != color;
}

class _MoonSmPainter extends CustomPainter {
  final Color color;
  const _MoonSmPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawArc(Rect.fromLTWH(0, 0, s.width, s.height),
        math.pi * 0.15, math.pi * 1.70, false,
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4..strokeCap = StrokeCap.round);
    canvas.drawCircle(Offset(s.width * 0.76, s.height * 0.18), 1.5, Paint()..color = color);
  }
  @override
  bool shouldRepaint(_MoonSmPainter o) => o.color != color;
}

class _FingerprintSmPainter extends CustomPainter {
  final Color color;
  const _FingerprintSmPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2;
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.2..strokeCap = StrokeCap.round;
    for (int i = 1; i <= 4; i++) {
      canvas.drawArc(
          Rect.fromCenter(center: Offset(cx, cy), width: i * s.width * 0.22, height: i * s.height * 0.22),
          math.pi * 0.80, math.pi * 1.40, false, p);
    }
    canvas.drawCircle(Offset(cx, cy), s.width * 0.06, Paint()..color = color);
  }
  @override
  bool shouldRepaint(_FingerprintSmPainter o) => o.color != color;
}

class _TimerSmPainter extends CustomPainter {
  final Color color;
  const _TimerSmPainter({required this.color});
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
  bool shouldRepaint(_TimerSmPainter o) => o.color != color;
}

class _EmailSmPainter extends CustomPainter {
  final Color color;
  const _EmailSmPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, s.height * 0.14, s.width, s.height * 0.72), const Radius.circular(3)), p);
    final env = Path();
    env.moveTo(0, s.height * 0.14);
    env.lineTo(s.width / 2, s.height * 0.58);
    env.lineTo(s.width, s.height * 0.14);
    canvas.drawPath(env, p);
  }
  @override
  bool shouldRepaint(_EmailSmPainter o) => o.color != color;
}

class _VerifiedSmPainter extends CustomPainter {
  final Color color;
  const _VerifiedSmPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2; final r = s.width * 0.46;
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color.withValues(alpha: 0.15)..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4);
    final check = Path();
    check.moveTo(cx - r * 0.42, cy);
    check.lineTo(cx - r * 0.08, cy + r * 0.40);
    check.lineTo(cx + r * 0.42, cy - r * 0.36);
    canvas.drawPath(check, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.6..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
  }
  @override
  bool shouldRepaint(_VerifiedSmPainter o) => o.color != color;
}

class _LogoutPainter extends CustomPainter {
  final Color color;
  const _LogoutPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, s.height * 0.14, s.width * 0.62, s.height * 0.72), const Radius.circular(3)), p);
    canvas.drawLine(Offset(s.width * 0.48, s.height / 2), Offset(s.width, s.height / 2), p);
    final h = Path();
    h.moveTo(s.width * 0.72, s.height * 0.28);
    h.lineTo(s.width, s.height * 0.50);
    h.lineTo(s.width * 0.72, s.height * 0.72);
    canvas.drawPath(h, p);
  }
  @override
  bool shouldRepaint(_LogoutPainter o) => o.color != color;
}

class _SaveSmPainter extends CustomPainter {
  final Color color;
  const _SaveSmPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, s.width, s.height), const Radius.circular(3)), p);
    canvas.drawRect(Rect.fromLTWH(s.width * 0.24, 0, s.width * 0.52, s.height * 0.44),
        Paint()..color = color.withValues(alpha: 0.20)..style = PaintingStyle.fill);
    canvas.drawLine(Offset(s.width * 0.36, s.height * 0.08), Offset(s.width * 0.36, s.height * 0.36), p);
  }
  @override
  bool shouldRepaint(_SaveSmPainter o) => o.color != color;
}

class _DeleteSmPainter extends CustomPainter {
  final Color color;
  const _DeleteSmPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.3..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, s.height * 0.20), Offset(s.width, s.height * 0.20), p);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * 0.14, s.height * 0.20, s.width * 0.72, s.height * 0.76), const Radius.circular(2)), p);
    canvas.drawLine(Offset(s.width * 0.38, s.height * 0.20), Offset(s.width * 0.38, 0), p);
    canvas.drawLine(Offset(s.width * 0.62, s.height * 0.20), Offset(s.width * 0.62, 0), p);
    canvas.drawLine(Offset(s.width * 0.38, 0), Offset(s.width * 0.62, 0), p);
  }
  @override
  bool shouldRepaint(_DeleteSmPainter o) => o.color != color;
}

class _ChevRightPainter extends CustomPainter {
  final Color color;
  const _ChevRightPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(s.width * 0.25, s.height * 0.18);
    path.lineTo(s.width * 0.72, s.height * 0.50);
    path.lineTo(s.width * 0.25, s.height * 0.82);
    canvas.drawPath(path, p);
  }
  @override
  bool shouldRepaint(_ChevRightPainter o) => o.color != color;
}

class _ChevDownPainter extends CustomPainter {
  final Color color;
  const _ChevDownPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(s.width * 0.16, s.height * 0.30);
    path.lineTo(s.width * 0.50, s.height * 0.70);
    path.lineTo(s.width * 0.84, s.height * 0.30);
    canvas.drawPath(path, p);
  }
  @override
  bool shouldRepaint(_ChevDownPainter o) => o.color != color;
}