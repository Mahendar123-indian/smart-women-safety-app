// lib/features/sos/screens/sos_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// SOS SCREEN — Full rewrite (OVERFLOW-FREE)
// ✅ Zero Material icons — all CustomPainter
// ✅ All withValues(alpha:) — zero withOpacity()
// ✅ No animate_do — pure Flutter animations
// ✅ All SosProvider methods preserved exactly
// ✅ EvidenceBundle fields matched to evidence_models.dart exactly
// ✅ Camera controllers passed directly to trigger methods
// ✅ Google Maps integrated for active SOS
// ✅ SOS settings panel inline
// ✅ HARDWARE ARMING (Native Sentinel) — added with full UI feedback
// ✅ OVERFLOW-FREE — all views use proper scroll/flex layouts
// ✅ PIN PAD KEYBOARD FIX — bottom controls scroll gracefully under keyboard
// ✅ CONTAINER COLOR+DECORATION BUG FIX — color moved inside BoxDecoration
// ✅ CAMERA LIFECYCLE FIX — previews always mounted at root Stack bottom
// ✅ INCIDENT STATUS COLORS — active/collecting/uploading/complete = blue
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/sos_provider.dart';
import '../services/sos_service.dart';
import '../../../core/services/hardware_sos_service.dart';
import '../../../core/services/evidence/evidence_orchestrator.dart';
import '../../../core/services/evidence/evidence_models.dart';
import '../../../core/services/offline_sos_service.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/evidence_progress_widget.dart';
import '../widgets/offline_sos_banner.dart';

// ═══════════════════════════════════════════════════════════════════════
// SOS SCREEN ROOT
// ═══════════════════════════════════════════════════════════════════════

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _rippleCtrl;
  late AnimationController _glowCtrl;
  late AnimationController _entryCtrl;
  late Animation<double> _entryFade;

  GoogleMapController? _mapController;

  CameraController? _backCamera;
  CameraController? _frontCamera;
  bool _backReady = false;
  bool _frontReady = false;

  double _hwArmingProgress = 0.0;
  bool _isHwArming = false;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entryCtrl.forward();

    HardwareSosService.instance.onArmingProgress = (progress) {
      if (mounted) {
        setState(() {
          _hwArmingProgress = progress;
          _isHwArming = progress > 0 && progress < 1.0;
        });
        if ((progress * 100).toInt() == 50) {
          HapticFeedback.mediumImpact();
        }
      }
    };

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<SosProvider>().init();
      await _initCameras();
    });
  }

  Future<void> _initCameras() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final backDesc = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final back = CameraController(
        backDesc,
        ResolutionPreset.veryHigh,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await back.initialize();
      await back.setFlashMode(FlashMode.off);
      await back.setExposureMode(ExposureMode.auto);
      await back.setFocusMode(FocusMode.auto);
      if (!mounted) {
        back.dispose();
        return;
      }
      setState(() {
        _backCamera = back;
        _backReady = true;
      });

      final frontDesc = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final front = CameraController(
        frontDesc,
        ResolutionPreset.high,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await front.initialize();
      await front.setFlashMode(FlashMode.off);
      if (!mounted) {
        front.dispose();
        return;
      }
      setState(() {
        _frontCamera = front;
        _frontReady = true;
      });
    } catch (e) {
      debugPrint('Camera init: $e');
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rippleCtrl.dispose();
    _glowCtrl.dispose();
    _entryCtrl.dispose();
    _mapController?.dispose();
    _backCamera?.dispose();
    _frontCamera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      // resizeToAvoidBottomInset keeps layout stable when keyboard opens
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Hidden 1×1 camera previews — ALWAYS mounted at root level.
          //    Must live here (not inside _ActiveView) so the camera lenses
          //    stay active during Idle, Countdown, AND Active modes.
          //    Unmounting them during state transitions caused the ML /
          //    Orchestrator fatal camera lifecycle crash.
          if (_backReady && _backCamera != null)
            Positioned(
              left: 0,
              top: 0,
              width: 1,
              height: 1,
              child: CameraPreview(_backCamera!),
            ),
          if (_frontReady && _frontCamera != null)
            Positioned(
              left: 1,
              top: 0,
              width: 1,
              height: 1,
              child: CameraPreview(_frontCamera!),
            ),
          Consumer<SosProvider>(
            builder: (_, provider, __) {
              if (provider.isSosActive) {
                return _ActiveView(
                  provider: provider,
                  pulseCtrl: _pulseCtrl,
                  rippleCtrl: _rippleCtrl,
                  glowCtrl: _glowCtrl,
                  mapController: _mapController,
                  onMapCreated: (c) => setState(() => _mapController = c),
                  backCamera: _backCamera,
                  frontCamera: _frontCamera,
                  backReady: _backReady,
                  frontReady: _frontReady,
                );
              }
              if (provider.isCountingDown) {
                return _CountdownView(
                  provider: provider,
                  rippleCtrl: _rippleCtrl,
                );
              }
              if (provider.status == SosStatus.resolved) {
                return _ResolvedView(provider: provider);
              }
              return FadeTransition(
                opacity: _entryFade,
                child: _IdleView(
                  provider: provider,
                  pulseCtrl: _pulseCtrl,
                  backCamera: _backCamera,
                  frontCamera: _frontCamera,
                ),
              );
            },
          ),
          // Hardware arming overlay
          if (_isHwArming) _buildHardwareArmingOverlay(),
        ],
      ),
    );
  }

  Widget _buildHardwareArmingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: _hwArmingProgress,
                    strokeWidth: 8,
                    color: AppColors.sosRed,
                    backgroundColor: Colors.white10,
                  ),
                ),
                CustomPaint(
                  size: const Size(40, 40),
                  painter: _ShieldCheckPainter(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'ARMING SOS...',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'KEEP HOLDING VOLUME BUTTON',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// IDLE VIEW
// ═══════════════════════════════════════════════════════════════════════

class _IdleView extends StatefulWidget {
  final SosProvider provider;
  final AnimationController pulseCtrl;
  final CameraController? backCamera;
  final CameraController? frontCamera;

  const _IdleView({
    required this.provider,
    required this.pulseCtrl,
    this.backCamera,
    this.frontCamera,
  });

  @override
  State<_IdleView> createState() => _IdleViewState();
}

class _IdleViewState extends State<_IdleView>
    with SingleTickerProviderStateMixin {
  late AnimationController _bgCtrl;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        _buildBackground(size),
        SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 14),
                    _buildTopBar(),
                    const SizedBox(height: 24),
                    _buildMainButton(),
                    const SizedBox(height: 12),
                    _buildTriggerChips(),
                    const SizedBox(height: 24),
                    const OfflineSosBanner(),
                    const SizedBox(height: 16),
                    _buildQuickActions(),
                    const SizedBox(height: 20),
                    _buildEvidencePreview(),
                    const SizedBox(height: 20),
                    _SettingsPanel(provider: widget.provider),
                    if (widget.provider.incidents.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildIncidentsPanel(),
                    ],
                    const SizedBox(height: 20),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackground(Size size) {
    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (_, __) {
        final t = _bgCtrl.value;
        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0A0010), Color(0xFF1A0008)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              top: -size.height * 0.1 + t * 30,
              left: size.width * 0.1,
              child: Container(
                width: size.width * 0.8,
                height: size.width * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.sosRed.withValues(alpha: 0.06 + t * 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Center(
              child: CustomPaint(
                size: const Size(16, 16),
                painter: _BackArrowPainter(),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SOS Emergency',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.safeGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      widget.provider.shakeEnabled
                          ? 'Shake 3× or tap to activate'
                          : 'Tap button to activate',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => _showPinSettings(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.20),
              ),
            ),
            child: Center(
              child: CustomPaint(
                size: const Size(20, 20),
                painter: _SettingsGearPainter(color: AppColors.primary),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainButton() {
    return Center(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.heavyImpact();
          widget.provider.startCountdown(
            backCamera: widget.backCamera,
            frontCamera: widget.frontCamera,
          );
        },
        onLongPress: () {
          HapticFeedback.heavyImpact();
          widget.provider.triggerManualSOS(
            backCamera: widget.backCamera,
            frontCamera: widget.frontCamera,
          );
        },
        child: AnimatedBuilder(
          animation: widget.pulseCtrl,
          builder: (_, __) {
            final t = widget.pulseCtrl.value;
            return Stack(
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: 1.0 + t * 0.12,
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.sosRed.withValues(
                        alpha: 0.04 + t * 0.06,
                      ),
                    ),
                  ),
                ),
                Transform.scale(
                  scale: 1.0 + t * 0.06,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.sosRed.withValues(
                        alpha: 0.08 + t * 0.08,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [
                        Color(0xFFFF4444),
                        AppColors.sosRed,
                        Color(0xFFB71C1C),
                      ],
                      stops: [0.0, 0.6, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.sosRed.withValues(
                          alpha: 0.50 + t * 0.30,
                        ),
                        blurRadius: 40 + t * 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(54, 54),
                        painter: _SosLargePainter(),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          letterSpacing: 5,
                        ),
                      ),
                      Text(
                        'Hold = Instant',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontFamily: 'Poppins',
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTriggerChips() {
    final triggers = [
      ('📳', 'Shake 3×'),
      ('🤙', 'Hold 3s'),
      ('🤫', 'Silent Mode'),
      ('🤖', 'Auto AI'),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: triggers.map((t) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.sosRed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.sosRed.withValues(alpha: 0.20),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t.$1, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 5),
              Text(
                t.$2,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.sosRed,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      (
      _MicOffPainter(color: AppColors.secondary),
      'Silent SOS',
      'No alarm',
      AppColors.secondary,
          () => _confirmSilentSOS(),
      ),
      (
      _PoliceIconPainter(color: AppColors.sosRed),
      'Call 112',
      'Police',
      AppColors.sosRed,
          () async {
        final uri = Uri.parse('tel:112');
        if (await canLaunchUrl(uri)) await launchUrl(uri);
      },
      ),
      (
      _PeopleIconPainter(color: AppColors.warningAmber),
      'Alert All',
      'Immediate',
      AppColors.warningAmber,
          () {
        HapticFeedback.heavyImpact();
        widget.provider.triggerManualSOS(
          backCamera: widget.backCamera,
          frontCamera: widget.frontCamera,
        );
      },
      ),
    ];

    return Row(
      children: actions.asMap().entries.map((entry) {
        final i = entry.key;
        final a = entry.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i > 0 ? 8 : 0),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                a.$5();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 6,
                ),
                decoration: BoxDecoration(
                  color: a.$4.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: a.$4.withValues(alpha: 0.22),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: a.$4.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: CustomPaint(
                          size: const Size(20, 20),
                          painter: a.$1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      a.$2,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: a.$4,
                      ),
                    ),
                    Text(
                      a.$3,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9,
                        color: Colors.white.withValues(alpha: 0.38),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEvidencePreview() {
    final items = [
      (_AudioIconPainter(), '60s Audio\nChunks', AppColors.secondary),
      (_PhotoBurstPainter(), '6 Photos\nFront+Back', AppColors.warningAmber),
      (_VideoIconPainter(), '30s+30s\nBoth Cams', AppColors.sosRed),
      (_GpsTrailPainter(), 'GPS Trail\nEvery 5s', AppColors.safeGreen),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CustomPaint(
                size: const Size(14, 14),
                painter: _ShieldCheckPainter(color: AppColors.safeGreen),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Evidence Auto-Captured on SOS',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: items.asMap().entries.map((e) {
              final i = e.key;
              final item = e.value;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i > 0 ? 8 : 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: item.$3.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: item.$3.withValues(alpha: 0.20),
                      ),
                    ),
                    child: Column(
                      children: [
                        CustomPaint(
                          size: const Size(20, 20),
                          painter: item.$1,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.$2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: item.$3,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              CustomPaint(
                size: const Size(12, 12),
                painter: _LockIconSmallPainter(color: AppColors.safeGreen),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Encrypted · Firebase Storage · Court-ready PDF report',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.38),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentsPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent SOS History',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          ...widget.provider.incidents.take(5).map((e) {
            final c = _statusColor(e.status);
            final d = DateTime.now().difference(e.triggeredAt);
            final ago =
            d.inMinutes < 60 ? '${d.inMinutes}m ago' : '${d.inHours}h ago';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Center(
                      child: CustomPaint(
                        size: const Size(18, 18),
                        painter: _EmergencySmallPainter(color: c),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _triggerLabel(e.triggerType),
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${e.lat.toStringAsFixed(4)}, ${e.lng.toStringAsFixed(4)} · $ago',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.38),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      e.status.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: c,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _statusColor(String s) => switch (s) {
    'resolved' => AppColors.safeGreen,
    'false_alarm' => AppColors.warningAmber,
    'active' || 'collecting' || 'uploading' || 'complete' => const Color(0xFF1976D2),
    _ => AppColors.sosRed,
  };

  String _triggerLabel(String t) => switch (t) {
    'manual' => 'Manual SOS',
    'shake' => '📳 Shake SOS',
    'silent' => 'Silent SOS',
    'voice' => '🎙️ Voice SOS',
    'hardware' => '🔊 Hardware SOS',
    _ => '🤖 Auto AI SOS',
  };

  void _confirmSilentSOS() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withValues(alpha: 0.12),
                ),
                child: Center(
                  child: CustomPaint(
                    size: const Size(28, 28),
                    painter: _MicOffPainter(color: AppColors.secondary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Silent SOS',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sends emergency alert to all contacts without alarm sound. Evidence captured silently from both cameras.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.50),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        HapticFeedback.heavyImpact();
                        widget.provider.triggerSilentSOS(
                          backCamera: widget.backCamera,
                          frontCamera: widget.frontCamera,
                        );
                      },
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.secondary,
                              AppColors.secondaryDark,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.secondary.withValues(alpha: 0.35),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'Send Silent SOS',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPinSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PinSettingsSheet(provider: widget.provider),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// COUNTDOWN VIEW
// ═══════════════════════════════════════════════════════════════════════

class _CountdownView extends StatelessWidget {
  final SosProvider provider;
  final AnimationController rippleCtrl;

  const _CountdownView({required this.provider, required this.rippleCtrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7F0000), AppColors.sosRed],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '⚠️  SOS IN',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: 5,
              ),
            ),
            const SizedBox(height: 40),
            AnimatedBuilder(
              animation: rippleCtrl,
              builder: (_, __) => Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: 1.0 + rippleCtrl.value * 0.55,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: (1 - rippleCtrl.value) * 0.45,
                          ),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  Container(
                    width: 140,
                    height: 140,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: Text(
                          '${provider.countdown}',
                          key: ValueKey(provider.countdown),
                          style: const TextStyle(
                            color: AppColors.sosRed,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w900,
                            fontSize: 68,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            const Text(
              '🚨 SOS + Evidence capturing...',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: ['🎤 Audio', '📸 6 Photos', '🎥 2 Videos', '📍 GPS']
                  .map((label) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 50),
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                provider.cancelCountdown();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 52,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.20),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Text(
                  'Cancel SOS',
                  style: TextStyle(
                    color: AppColors.sosRed,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () {
                HapticFeedback.heavyImpact();
                provider.triggerManualSOS();
              },
              child: Text(
                'Tap here to send IMMEDIATELY',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ACTIVE SOS VIEW — OVERFLOW-FREE + KEYBOARD-SAFE PIN PAD
//
// FIX SUMMARY (RenderFlex overflow by 161px on bottom):
// ─────────────────────────────────────────────────────
// ROOT CAUSE: When the PIN keyboard opens, the AnimatedPadding bottom
// inset shrank the outer Column's available height. The Expanded(map)
// was crushed to zero, yet the fixed-height widgets below it still
// demanded their full space, causing the 161px overflow.
//
// ARCHITECTURAL FIX APPLIED:
//   1. Scaffold.resizeToAvoidBottomInset: false — map never jumps.
//   2. Google Map is a fixed SizedBox(height: 35% of screen) using
//      MediaQuery.of(context).size.height * 0.35. This guarantees the
//      map is always visible and never in an Expanded that can be
//      crushed to zero height.
//   3. All bottom controls (EvidenceProgressWidget, timeline, and the
//      resolve/PIN section) are wrapped in a single Expanded →
//      SingleChildScrollView → Column. When the keyboard appears they
//      simply scroll upward — no overflow possible.
//   4. The outer AnimatedPadding is removed. Keyboard insets are
//      naturally handled by the scrollable bottom section.
// ═══════════════════════════════════════════════════════════════════════

class _ActiveView extends StatefulWidget {
  final SosProvider provider;
  final AnimationController pulseCtrl;
  final AnimationController rippleCtrl;
  final AnimationController glowCtrl;
  final GoogleMapController? mapController;
  final void Function(GoogleMapController) onMapCreated;
  final CameraController? backCamera;
  final CameraController? frontCamera;
  final bool backReady;
  final bool frontReady;

  const _ActiveView({
    required this.provider,
    required this.pulseCtrl,
    required this.rippleCtrl,
    required this.glowCtrl,
    required this.mapController,
    required this.onMapCreated,
    this.backCamera,
    this.frontCamera,
    this.backReady = false,
    this.frontReady = false,
  });

  @override
  State<_ActiveView> createState() => _ActiveViewState();
}

class _ActiveViewState extends State<_ActiveView> {
  final _pinCtrl = TextEditingController();
  bool _showPin = false;
  bool _pinError = false;
  bool _resolveAsFalse = false;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  String _getSentinelSource() {
    final type = widget.provider.activeEvent?.triggerType ?? 'manual';
    return switch (type) {
      'shake' => '🚨 KINETIC TRIGGER (5-LAYER AI)',
      'voice' => '🎙️ ACOUSTIC SENTINEL ACTIVE',
      'hardware' => '🔊 HARDWARE BUTTON OVERRIDE',
      'silent' => '🤫 STEALTH DISPATCH ACTIVE',
      _ => '🔘 MANUAL SOS ENGAGED',
    };
  }

  // ─────────────────────────────────────────────────────────────────────
  // BUILD — OVERFLOW-FREE KEYBOARD-SAFE LAYOUT
  //
  // Structure:
  //   Scaffold(resizeToAvoidBottomInset: false)
  //   └─ Stack
  //      ├─ hidden 1×1 camera previews (Android requirement)
  //      ├─ animated glow background
  //      └─ SafeArea
  //         └─ Column
  //            ├─ _buildTopBar()          ← fixed height
  //            ├─ _buildEvidenceRow()     ← fixed height
  //            ├─ SizedBox(h: 35% screen) ← FIXED-HEIGHT MAP (never crushed)
  //            └─ Expanded               ← takes ALL remaining space
  //               └─ SingleChildScrollView ← scrolls under keyboard
  //                  └─ Column
  //                     ├─ EvidenceProgressWidget
  //                     ├─ _buildTimeline()
  //                     ├─ resolve buttons OR PIN entry
  //                     └─ SizedBox(bottom safe padding)
  // ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final event = provider.activeEvent;

    // 35% of screen height for the map — stays constant regardless of keyboard
    final mapHeight = MediaQuery.of(context).size.height * 0.35;

    // Bottom safe-area padding so content clears the home indicator
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      // KEY FIX: false — map never jumps when keyboard opens
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ── Animated glow background ──
          AnimatedBuilder(
            animation: widget.glowCtrl,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.5,
                  colors: [
                    AppColors.sosRed.withValues(
                      alpha: 0.25 + widget.glowCtrl.value * 0.15,
                    ),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),

          // ── Main layout: SafeArea → Column ──
          SafeArea(
            // bottom: false — we apply bottomPadding manually inside the
            // scroll view so it accounts for the home indicator without
            // conflicting with keyboard insets.
            bottom: false,
            child: Column(
              children: [
                // ── Top bar — intrinsic / fixed height ──
                _buildTopBar(provider, event),

                // ── Evidence chips row — intrinsic / fixed height ──
                _buildEvidenceRow(provider),

                // ── FIXED-HEIGHT MAP — 35% of screen, never crushed ──
                SizedBox(
                  height: mapHeight,
                  child: Stack(
                    children: [
                      _buildMap(event),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: _buildMapOverlay(provider),
                      ),
                    ],
                  ),
                ),

                // ── SCROLLABLE BOTTOM SECTION —
                //    Takes all remaining screen space.
                //    Scrolls upward when keyboard opens → zero overflow. ──
                Expanded(
                  child: SingleChildScrollView(
                    // Reverse: false keeps natural top-to-bottom order.
                    // physics: ClampingScrollPhysics prevents over-scroll
                    // fighting with the map's gesture detector.
                    physics: const ClampingScrollPhysics(),
                    keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Evidence progress widget
                        const EvidenceProgressWidget(),

                        // Timeline horizontal scroll (fixed height 66)
                        _buildTimeline(provider),

                        // Resolve buttons OR PIN entry — intrinsic height
                        _showPin
                            ? _buildPinEntry(provider)
                            : _buildResolveButtons(),

                        // Bottom safe-area clearance (home indicator + 8px)
                        SizedBox(height: bottomPadding + 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(SosProvider p, SosEvent? event) {
    return AnimatedBuilder(
      animation: widget.pulseCtrl,
      builder: (_, __) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          color: Color.lerp(
            AppColors.sosRed,
            AppColors.sosRedDark,
            widget.pulseCtrl.value,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CustomPaint(
                          size: const Size(22, 22),
                          painter: _SosActiveIconPainter(),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'SOS ACTIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getSentinelSource(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      event != null
                          ? '📍 ${event.lat.toStringAsFixed(4)}, ${event.lng.toStringAsFixed(4)}'
                          : 'Getting location...',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontFamily: 'Poppins',
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _DurationDisplay(triggeredAt: event?.triggeredAt),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (widget.backReady) _CamBadge('📷 1080p'),
                      const SizedBox(width: 4),
                      if (widget.frontReady) _CamBadge('🤳 720p'),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEvidenceRow(SosProvider p) {
    final bundle = p.activeBundle;
    final photosCount = bundle?.photoUrls.length ?? 0;
    final videosCount = bundle?.videoUrls.length ?? 0;
    final hasAudio = bundle?.audioUrl != null;

    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          _EvidChip(
            painter: _AudioIconPainter(),
            label: hasAudio ? 'Audio ✓' : 'Recording...',
            active: hasAudio,
            loading: !hasAudio && p.audioRecording,
            color: AppColors.secondary,
          ),
          const SizedBox(width: 4),
          _EvidChip(
            painter: _PhotoBurstPainter(),
            label: p.photoCapturing ? '$photosCount/6...' : '$photosCount/6 ✓',
            active: photosCount > 0 && !p.photoCapturing,
            loading: p.photoCapturing,
            color: AppColors.warningAmber,
          ),
          const SizedBox(width: 4),
          _EvidChip(
            painter: _VideoIconPainter(),
            label: p.videoRecording ? 'Recording...' : '$videosCount clips ✓',
            active: videosCount > 0 && !p.videoRecording,
            loading: p.videoRecording,
            color: const Color(0xFF7C4DFF),
          ),
          const SizedBox(width: 4),
          _EvidChip(
            painter: _SensorIconPainter(),
            label: bundle?.phoneFallen == true ? '⚠️ Fall!' : 'Sensors',
            active: true,
            color: AppColors.safeGreen,
          ),
          const SizedBox(width: 4),
          _EvidChip(
            painter: _GpsTrailPainter(),
            label: 'GPS Live',
            active: true,
            color: AppColors.sosRed,
          ),
        ],
      ),
    );
  }

  Widget _buildMap(SosEvent? event) {
    if (event == null || (event.lat == 0 && event.lng == 0)) {
      return Container(
        color: Colors.grey[900],
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.sosRed),
        ),
      );
    }
    final pos = LatLng(event.lat, event.lng);
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: pos, zoom: 16),
      onMapCreated: widget.onMapCreated,
      mapType: MapType.normal,
      myLocationEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      markers: {
        Marker(
          markerId: const MarkerId('sos_user'),
          position: pos,
          icon:
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: '🚨 SOS Location',
            snippet:
            '${event.lat.toStringAsFixed(4)}, ${event.lng.toStringAsFixed(4)}',
          ),
        ),
      },
      circles: {
        Circle(
          circleId: const CircleId('sos_radius'),
          center: pos,
          radius: 100,
          fillColor: AppColors.sosRed.withValues(alpha: 0.12),
          strokeColor: AppColors.sosRed.withValues(alpha: 0.55),
          strokeWidth: 3,
        ),
      },
    );
  }

  Widget _buildMapOverlay(SosProvider p) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.sosRed.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  'LIVE LOCATION',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.60),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: Text(
              'Danger: ${(p.dangerScore * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(SosProvider p) {
    final timeline = p.evidenceTimeline;
    if (timeline.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 66,
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: timeline.length,
          itemBuilder: (_, i) {
            final text = timeline[timeline.length - 1 - i];
            return Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Center(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildResolveButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              setState(() {
                _showPin = true;
                _resolveAsFalse = false;
              });
            },
            child: Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.safeGreen,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.safeGreen.withValues(alpha: 0.40),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomPaint(
                    size: const Size(22, 22),
                    painter: _CheckCirclePainter(color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'I Am Safe Now',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _showPin = true;
                _resolveAsFalse = true;
              });
            },
            child: Container(
              width: double.infinity,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
              child: const Center(
                child: Text(
                  'False Alarm — Cancel',
                  style: TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinEntry(SosProvider p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _resolveAsFalse ? 'Enter PIN to cancel SOS' : 'Enter PIN to confirm safe',
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  autofocus: true,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 12,
                    fontFamily: 'Poppins',
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: _pinError
                            ? AppColors.sosRed
                            : Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: _pinError
                            ? AppColors.sosRed
                            : Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: _pinError ? AppColors.sosRed : AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                    hintText: '••••',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.25),
                      fontSize: 24,
                      letterSpacing: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  final ok = await p.resolveSosWithPin(
                    pin: _pinCtrl.text,
                    isFalseAlarm: _resolveAsFalse,
                  );
                  if (!ok && mounted) {
                    HapticFeedback.heavyImpact();
                    setState(() {
                      _pinError = true;
                      _pinCtrl.clear();
                    });
                  }
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _resolveAsFalse
                        ? Colors.white.withValues(alpha: 0.18)
                        : AppColors.safeGreen,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _resolveAsFalse
                        ? []
                        : [
                      BoxShadow(
                        color:
                        AppColors.safeGreen.withValues(alpha: 0.35),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Center(
                    child: CustomPaint(
                      size: const Size(22, 22),
                      painter: _ArrowRightPainter(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_pinError) ...[
            const SizedBox(height: 8),
            const Text(
              'Wrong PIN. Try again.',
              style: TextStyle(
                color: AppColors.sosRed,
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() {
              _showPin = false;
              _pinError = false;
              _pinCtrl.clear();
            }),
            child: Text(
              '← Back',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.50),
                fontFamily: 'Poppins',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// RESOLVED VIEW
// ═══════════════════════════════════════════════════════════════════════

class _ResolvedView extends StatefulWidget {
  final SosProvider provider;
  const _ResolvedView({required this.provider});

  @override
  State<_ResolvedView> createState() => _ResolvedViewState();
}

class _ResolvedViewState extends State<_ResolvedView>
    with SingleTickerProviderStateMixin {
  late AnimationController _checkCtrl;
  late Animation<double> _checkAnim;

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _checkAnim = CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut);
    _checkCtrl.forward();
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bundle = widget.provider.activeBundle;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF004D20), AppColors.safeGreen],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _checkAnim,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.20),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                    child: Center(
                      child: CustomPaint(
                        size: const Size(52, 52),
                        painter: _CheckLargePainter(color: AppColors.safeGreen),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'You Are Safe',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w900,
                    fontSize: 28,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'All contacts have been notified.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.80),
                    fontFamily: 'Poppins',
                    fontSize: 14,
                  ),
                ),
                if (bundle != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Evidence Secured',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _EvidStat(
                              painter: _AudioIconPainter(),
                              label:
                              bundle.audioUrl != null ? 'Audio ✓' : 'Audio',
                            ),
                            _EvidStat(
                              painter: _PhotoBurstPainter(),
                              label: '${bundle.photoUrls.length} Photos',
                            ),
                            _EvidStat(
                              painter: _VideoIconPainter(),
                              label: '${bundle.videoUrls.length} Videos',
                            ),
                            _EvidStat(
                              painter: _PdfIconPainter(color: Colors.white),
                              label: 'PDF Report',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Returning to SOS screen...',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontFamily: 'Poppins',
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SETTINGS PANEL
// ═══════════════════════════════════════════════════════════════════════

class _SettingsPanel extends StatelessWidget {
  final SosProvider provider;
  const _SettingsPanel({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CustomPaint(
                size: const Size(16, 16),
                painter: _SettingsGearPainter(color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              const Text(
                'SOS Settings',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SettingRow(
            painter: _VibrateIconPainter(color: AppColors.primary),
            label: 'Shake to SOS',
            sub: 'Shake phone 3× rapidly',
            value: provider.shakeEnabled,
            color: AppColors.primary,
            onChanged: (v) => provider.toggleShake(v),
          ),
          _divider(),
          _SettingRow(
            painter: _SoundWavePainter(color: AppColors.secondary),
            label: 'SOS Alarm Sound',
            sub: 'Loud alarm on trigger',
            value: provider.alarmEnabled,
            color: AppColors.secondary,
            onChanged: (v) => provider.toggleAlarm(v),
          ),
          _divider(),
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.warningAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: CustomPaint(
                    size: const Size(18, 18),
                    painter: _TimerIconPainter(color: AppColors.warningAmber),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Countdown Timer',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Seconds before SOS fires',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [3, 5, 10].map((s) {
                  final selected = provider.countdownTotal == s;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      provider.setCountdownSeconds(s);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: selected ? AppColors.primaryGradient : null,
                        color: selected
                            ? null
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        '${s}s',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: selected ? Colors.white : Colors.grey,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
    margin: const EdgeInsets.symmetric(vertical: 10),
    height: 1,
    color: Colors.white.withValues(alpha: 0.06),
  );
}

class _SettingRow extends StatelessWidget {
  final CustomPainter painter;
  final String label;
  final String sub;
  final bool value;
  final Color color;
  final void Function(bool) onChanged;

  const _SettingRow({
    required this.painter,
    required this.label,
    required this.sub,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: CustomPaint(size: const Size(18, 18), painter: painter),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
              Text(
                sub,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.38),
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(value: value, onChanged: onChanged, activeColor: color),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PIN SETTINGS SHEET
// ═══════════════════════════════════════════════════════════════════════

class _PinSettingsSheet extends StatefulWidget {
  final SosProvider provider;
  const _PinSettingsSheet({required this.provider});

  @override
  State<_PinSettingsSheet> createState() => _PinSettingsSheetState();
}

class _PinSettingsSheetState extends State<_PinSettingsSheet> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  bool _error = false;
  bool _success = false;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Change Safe PIN',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'PIN required to cancel active SOS',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.40),
              ),
            ),
            const SizedBox(height: 18),
            _PinTextField(
              ctrl: _oldCtrl,
              hint: 'Current PIN (default: 1234)',
              painter: _LockIconSmallPainter(color: AppColors.primary),
            ),
            const SizedBox(height: 10),
            _PinTextField(
              ctrl: _newCtrl,
              hint: 'New 4-digit PIN',
              painter: _LockIconSmallPainter(color: AppColors.secondary),
            ),
            if (_error) ...[
              const SizedBox(height: 8),
              const Text(
                'Wrong current PIN. Try again.',
                style: TextStyle(
                  color: AppColors.sosRed,
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (_success) ...[
              const SizedBox(height: 8),
              const Text(
                '✅ PIN updated successfully',
                style: TextStyle(
                  color: AppColors.safeGreen,
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () async {
                if (_newCtrl.text.length != 4) {
                  setState(() => _error = true);
                  return;
                }
                final ok = await widget.provider.changePin(
                  _oldCtrl.text,
                  _newCtrl.text,
                );
                setState(() {
                  _error = !ok;
                  _success = ok;
                });
                if (ok) {
                  await Future.delayed(const Duration(seconds: 1));
                  if (mounted) Navigator.pop(context);
                }
              },
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Update PIN',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinTextField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final CustomPainter painter;

  const _PinTextField({
    required this.ctrl,
    required this.hint,
    required this.painter,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      maxLength: 4,
      obscureText: true,
      style: const TextStyle(
        color: Colors.white,
        fontFamily: 'Poppins',
        fontSize: 18,
        letterSpacing: 8,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.28),
          fontFamily: 'Poppins',
          fontSize: 12,
          letterSpacing: 0,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: CustomPaint(size: const Size(18, 18), painter: painter),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SMALL REUSABLE WIDGETS
// ═══════════════════════════════════════════════════════════════════════

class _DurationDisplay extends StatefulWidget {
  final DateTime? triggeredAt;
  const _DurationDisplay({this.triggeredAt});

  @override
  State<_DurationDisplay> createState() => _DurationDisplayState();
}

class _DurationDisplayState extends State<_DurationDisplay> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _str {
    if (widget.triggeredAt == null) return '0:00';
    final d = DateTime.now().difference(widget.triggeredAt!);
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _str,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _CamBadge extends StatelessWidget {
  final String label;
  const _CamBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'Poppins',
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EvidChip extends StatelessWidget {
  final CustomPainter painter;
  final String label;
  final bool active;
  final bool loading;
  final Color color;

  const _EvidChip({
    required this.painter,
    required this.label,
    required this.active,
    this.loading = false,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 3),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? color.withValues(alpha: 0.35) : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            loading
                ? SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                color: color,
                strokeWidth: 2,
              ),
            )
                : CustomPaint(size: const Size(13, 13), painter: painter),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: active
                    ? color
                    : Colors.white.withValues(alpha: 0.25),
                fontFamily: 'Poppins',
                fontSize: 7,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _EvidStat extends StatelessWidget {
  final CustomPainter painter;
  final String label;
  const _EvidStat({required this.painter, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomPaint(size: const Size(20, 20), painter: painter),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ALL CUSTOM PAINTERS
// ═══════════════════════════════════════════════════════════════════════

class _BackArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
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

class _SosLargePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    canvas.drawCircle(
      Offset(cx, cy),
      s.width * 0.46,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      s.width * 0.46,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
    final tp = TextPainter(
      text: const TextSpan(
        text: 'SOS',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          fontFamily: 'Poppins',
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_SosLargePainter o) => false;
}

class _SosActiveIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    canvas.drawCircle(
      Offset(cx, cy),
      s.width * 0.46,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      s.width * 0.46,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 2.5, cy - s.height * 0.24, 5, s.height * 0.28),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(cx, cy + s.height * 0.14),
      3,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_SosActiveIconPainter o) => false;
}

class _SettingsGearPainter extends CustomPainter {
  final Color color;
  const _SettingsGearPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    canvas.drawCircle(
      Offset(cx, cy),
      s.width * 0.22,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    for (int i = 0; i < 8; i++) {
      final a = (2 * math.pi / 8) * i;
      canvas.drawLine(
        Offset(cx + s.width * 0.30 * math.cos(a),
            cy + s.height * 0.30 * math.sin(a)),
        Offset(cx + s.width * 0.46 * math.cos(a),
            cy + s.height * 0.46 * math.sin(a)),
        Paint()
          ..color = color
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_SettingsGearPainter o) => o.color != color;
}

class _MicOffPainter extends CustomPainter {
  final Color color;
  const _MicOffPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * 0.30, 0, s.width * 0.40, s.height * 0.58),
        Radius.circular(s.width * 0.20),
      ),
      p,
    );
    canvas.drawArc(
      Rect.fromLTWH(
          s.width * 0.12, s.height * 0.30, s.width * 0.76, s.height * 0.50),
      0,
      math.pi,
      false,
      p,
    );
    canvas.drawLine(
      Offset(s.width * 0.50, s.height * 0.80),
      Offset(s.width * 0.50, s.height),
      p,
    );
    canvas.drawLine(
      Offset(s.width * 0.15, s.height * 0.10),
      Offset(s.width * 0.85, s.height * 0.90),
      p,
    );
  }

  @override
  bool shouldRepaint(_MicOffPainter o) => o.color != color;
}

class _PoliceIconPainter extends CustomPainter {
  final Color color;
  const _PoliceIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    final path = Path();
    path.moveTo(cx, 0);
    path.lineTo(s.width, s.height * 0.28);
    path.lineTo(s.width * 0.92, s.height * 0.76);
    path.lineTo(cx, s.height);
    path.lineTo(s.width * 0.08, s.height * 0.76);
    path.lineTo(0, s.height * 0.28);
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(Offset(cx, cy), s.width * 0.14, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PoliceIconPainter o) => o.color != color;
}

class _PeopleIconPainter extends CustomPainter {
  final Color color;
  const _PeopleIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(
        Offset(s.width * 0.36, s.height * 0.28), s.width * 0.16, p);
    final b = Path();
    b.moveTo(0, s.height);
    b.quadraticBezierTo(0, s.height * 0.60, s.width * 0.36, s.height * 0.60);
    b.quadraticBezierTo(
        s.width * 0.68, s.height * 0.60, s.width * 0.68, s.height);
    canvas.drawPath(b, p);
    canvas.drawCircle(
      Offset(s.width * 0.76, s.height * 0.22),
      s.width * 0.12,
      Paint()
        ..color = color.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_PeopleIconPainter o) => o.color != color;
}

class _AudioIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = AppColors.secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * 0.30, 0, s.width * 0.40, s.height * 0.58),
        Radius.circular(s.width * 0.20),
      ),
      p,
    );
    canvas.drawArc(
      Rect.fromLTWH(
          s.width * 0.12, s.height * 0.30, s.width * 0.76, s.height * 0.50),
      0,
      math.pi,
      false,
      p,
    );
    canvas.drawLine(
      Offset(s.width * 0.50, s.height * 0.80),
      Offset(s.width * 0.50, s.height),
      p,
    );
    canvas.drawLine(
      Offset(s.width * 0.30, s.height),
      Offset(s.width * 0.70, s.height),
      p,
    );
  }

  @override
  bool shouldRepaint(_AudioIconPainter o) => false;
}

class _PhotoBurstPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = AppColors.warningAmber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, s.height * 0.20, s.width, s.height * 0.72),
        const Radius.circular(4),
      ),
      p,
    );
    canvas.drawCircle(
        Offset(s.width / 2, s.height * 0.56), s.width * 0.20, p);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            s.width * 0.34, 0, s.width * 0.32, s.height * 0.22),
        const Radius.circular(3),
      ),
      p,
    );
    for (int i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(s.width * (0.08 + i * 0.06), s.height * 0.20),
        Offset(s.width * (0.04 + i * 0.06), 0),
        Paint()
          ..color = AppColors.warningAmber.withValues(alpha: 0.55)
          ..strokeWidth = 1.0
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_PhotoBurstPainter o) => false;
}

class _VideoIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = AppColors.sosRed
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, s.height * 0.18, s.width * 0.65, s.height * 0.64),
        const Radius.circular(4),
      ),
      p,
    );
    final play = Path();
    play.moveTo(s.width * 0.68, s.height * 0.22);
    play.lineTo(s.width, s.height * 0.38);
    play.lineTo(s.width, s.height * 0.62);
    play.lineTo(s.width * 0.68, s.height * 0.78);
    play.close();
    canvas.drawPath(play, p);
    canvas.drawCircle(
      Offset(s.width * 0.16, s.height * 0.38),
      s.width * 0.07,
      Paint()..color = AppColors.sosRed,
    );
  }

  @override
  bool shouldRepaint(_VideoIconPainter o) => false;
}

class _GpsTrailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = AppColors.safeGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final path = Path();
    path.moveTo(s.width * 0.10, s.height * 0.80);
    path.cubicTo(
      s.width * 0.10,
      s.height * 0.40,
      s.width * 0.90,
      s.height * 0.60,
      s.width * 0.90,
      s.height * 0.20,
    );
    canvas.drawPath(path, p);
    for (final pt in [
      Offset(s.width * 0.10, s.height * 0.80),
      Offset(s.width * 0.45, s.height * 0.60),
      Offset(s.width * 0.90, s.height * 0.20),
    ]) {
      canvas.drawCircle(pt, 3.0, Paint()..color = AppColors.safeGreen);
    }
  }

  @override
  bool shouldRepaint(_GpsTrailPainter o) => false;
}

class _SensorIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = AppColors.safeGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final path = Path();
    for (int i = 0; i <= 40; i++) {
      final x = i / 40 * s.width;
      final y =
          s.height / 2 + math.sin(i / 40 * 4 * math.pi) * s.height * 0.35;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_SensorIconPainter o) => false;
}

class _ShieldCheckPainter extends CustomPainter {
  final Color color;
  const _ShieldCheckPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final path = Path();
    path.moveTo(s.width * 0.50, 0);
    path.lineTo(s.width, s.height * 0.22);
    path.cubicTo(s.width, s.height * 0.22, s.width * 0.98, s.height * 0.72,
        s.width * 0.50, s.height);
    path.cubicTo(s.width * 0.02, s.height * 0.72, 0, s.height * 0.22, 0,
        s.height * 0.22);
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round,
    );
    final check = Path();
    check.moveTo(s.width * 0.28, s.height * 0.52);
    check.lineTo(s.width * 0.44, s.height * 0.68);
    check.lineTo(s.width * 0.72, s.height * 0.36);
    canvas.drawPath(
      check,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ShieldCheckPainter o) => o.color != color;
}

class _LockIconSmallPainter extends CustomPainter {
  final Color color;
  const _LockIconSmallPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * 0.10, s.height * 0.44, s.width * 0.80,
            s.height * 0.52),
        const Radius.circular(4),
      ),
      p,
    );
    final arc = Path();
    arc.moveTo(s.width * 0.30, s.height * 0.44);
    arc.lineTo(s.width * 0.30, s.height * 0.26);
    arc.quadraticBezierTo(s.width * 0.30, s.height * 0.08, s.width * 0.50,
        s.height * 0.08);
    arc.quadraticBezierTo(s.width * 0.70, s.height * 0.08, s.width * 0.70,
        s.height * 0.26);
    arc.lineTo(s.width * 0.70, s.height * 0.44);
    canvas.drawPath(arc, p);
  }

  @override
  bool shouldRepaint(_LockIconSmallPainter o) => o.color != color;
}

class _CheckCirclePainter extends CustomPainter {
  final Color color;
  const _CheckCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    final r = s.width * 0.46;
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
    final check = Path();
    check.moveTo(cx - r * 0.42, cy);
    check.lineTo(cx - r * 0.08, cy + r * 0.40);
    check.lineTo(cx + r * 0.42, cy - r * 0.36);
    canvas.drawPath(
      check,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckCirclePainter o) => o.color != color;
}

class _CheckLargePainter extends CustomPainter {
  final Color color;
  const _CheckLargePainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(s.width * 0.16, s.height * 0.52);
    path.lineTo(s.width * 0.42, s.height * 0.74);
    path.lineTo(s.width * 0.84, s.height * 0.28);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_CheckLargePainter o) => o.color != color;
}

class _ArrowRightPainter extends CustomPainter {
  final Color color;
  const _ArrowRightPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawLine(
      Offset(s.width * 0.18, s.height / 2),
      Offset(s.width * 0.82, s.height / 2),
      p,
    );
    final h = Path();
    h.moveTo(s.width * 0.56, s.height * 0.26);
    h.lineTo(s.width * 0.82, s.height * 0.50);
    h.lineTo(s.width * 0.56, s.height * 0.74);
    canvas.drawPath(h, p);
  }

  @override
  bool shouldRepaint(_ArrowRightPainter o) => o.color != color;
}

class _VibrateIconPainter extends CustomPainter {
  final Color color;
  const _VibrateIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * 0.28, s.height * 0.12, s.width * 0.44,
            s.height * 0.76),
        const Radius.circular(4),
      ),
      p,
    );
    for (final x in [s.width * 0.08, s.width * 0.84]) {
      canvas.drawLine(Offset(x, s.height * 0.30), Offset(x, s.height * 0.70), p);
    }
  }

  @override
  bool shouldRepaint(_VibrateIconPainter o) => o.color != color;
}

class _SoundWavePainter extends CustomPainter {
  final Color color;
  const _SoundWavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(0, s.height * 0.32), Offset(0, s.height * 0.68), p);
    canvas.drawLine(Offset(0, s.height * 0.32),
        Offset(s.width * 0.30, s.height * 0.14), p);
    canvas.drawLine(Offset(0, s.height * 0.68),
        Offset(s.width * 0.30, s.height * 0.86), p);
    canvas.drawLine(Offset(s.width * 0.30, s.height * 0.14),
        Offset(s.width * 0.30, s.height * 0.86), p);
    for (int i = 1; i <= 3; i++) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(s.width * 0.30, s.height / 2),
          width: i * s.width * 0.25,
          height: i * s.height * 0.40,
        ),
        -math.pi * 0.35,
        math.pi * 0.70,
        false,
        Paint()
          ..color = color.withValues(alpha: 0.8 - i * 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_SoundWavePainter o) => o.color != color;
}

class _TimerIconPainter extends CustomPainter {
  final Color color;
  const _TimerIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), s.width * 0.44, p);
    canvas.drawLine(Offset(cx, cy * 0.40), Offset(cx, cy), p);
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + s.width * 0.22, cy + s.height * 0.14),
      p,
    );
    canvas.drawLine(
      Offset(cx - s.width * 0.18, 0),
      Offset(cx + s.width * 0.18, 0),
      Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_TimerIconPainter o) => o.color != color;
}

class _PdfIconPainter extends CustomPainter {
  final Color color;
  const _PdfIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(s.width * 0.20, 0);
    path.lineTo(s.width * 0.70, 0);
    path.lineTo(s.width, s.height * 0.30);
    path.lineTo(s.width, s.height);
    path.lineTo(s.width * 0.20, s.height);
    path.close();
    canvas.drawPath(path, p);
    for (int i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(s.width * 0.34, s.height * (0.44 + i * 0.16)),
        Offset(s.width * 0.82, s.height * (0.44 + i * 0.16)),
        Paint()
          ..color = color
          ..strokeWidth = 1.0
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_PdfIconPainter o) => o.color != color;
}

class _EmergencySmallPainter extends CustomPainter {
  final Color color;
  const _EmergencySmallPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    canvas.drawCircle(
      Offset(cx, cy),
      s.width * 0.44,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 2.5, cy - s.height * 0.22, 5, s.height * 0.28),
        const Radius.circular(2),
      ),
      Paint()..color = color,
    );
    canvas.drawCircle(
      Offset(cx, cy + s.height * 0.14),
      2.5,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_EmergencySmallPainter o) => o.color != color;
}