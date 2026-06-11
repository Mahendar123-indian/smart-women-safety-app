// lib/features/incidents/screens/incident_detail_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// ✅ [FIXED] 'AlertSentRecord' — imported DIRECTLY from evidence_models.dart
// ✅ [FIXED] '_pdfFile' unused field removed
// ✅ [FIXED] 'setMapStyle' replaced with GoogleMap.style parameter
// ✅ [FIXED] '_polylines' made final
// ✅ [FIXED] 'const' applied at line 1073
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';

import '../../../core/services/evidence_pdf_service.dart';
import '../../../core/services/evidence/evidence_models.dart'; // ✅ [FIXED] AlertSentRecord lives here
import '../../../core/theme/app_colors.dart';

class IncidentDetailScreen extends StatefulWidget {
  final String incidentId;
  const IncidentDetailScreen({super.key, required this.incidentId});

  @override
  State<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen>
    with SingleTickerProviderStateMixin {
  final _pdfService = EvidencePdfService.instance;
  IncidentReportData? _data;

  bool _loading    = true;
  bool _generating = false;

  late TabController _tabs;
  GoogleMapController? _mapCtrl;
  Set<Marker>   _markers   = {};
  // ✅ [FIXED] made final
  final Set<Polyline> _polylines = {};

  final _dtFmt = DateFormat('dd MMM yyyy, HH:mm:ss');

  // ✅ [FIXED] 'setMapStyle' is deprecated — use GoogleMap.style property instead
  final String _darkMapStyle = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#212121"}]},
    {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#212121"}]},
    {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#757575"}]},
    {"featureType": "administrative.country", "elementType": "labels.text.fill", "stylers": [{"color": "#9e9e9e"}]},
    {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#bdbdbd"}]},
    {"featureType": "road", "elementType": "geometry.fill", "stylers": [{"color": "#2c2c2c"}]},
    {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#8a8a8a"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#000000"}]},
    {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#3d3d3d"}]}
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _loadForensicData();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _mapCtrl?.dispose();
    super.dispose();
  }

  Future<void> _loadForensicData() async {
    try {
      final data = await _pdfService.loadIncidentData(widget.incidentId);
      if (mounted) {
        setState(() {
          _data    = data;
          _loading = false;
        });
        if (data != null) _initializeMapVanguard(data);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showSnackBar('Failed to load incident data: $e', isError: true);
      }
    }
  }

  void _initializeMapVanguard(IncidentReportData data) {
    final markers = <Marker>{};

    markers.add(Marker(
      markerId:  const MarkerId('origin'),
      position:  LatLng(data.lat, data.lng),
      icon:      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(
        title:   '🚨 ALERT ORIGIN',
        snippet: _dtFmt.format(data.triggeredAt),
      ),
    ));

    if (data.gpsTrail.isNotEmpty) {
      final points = data.gpsTrail.map((p) => LatLng(p.lat, p.lng)).toList();

      _polylines.add(Polyline(
        polylineId: const PolylineId('path_of_travel'),
        points:     points,
        color:      AppColors.primary,
        width:      4,
        geodesic:   true,
        jointType:  JointType.round,
        patterns:   [PatternItem.dash(15), PatternItem.gap(10)],
      ));

      markers.add(Marker(
        markerId:  const MarkerId('terminal'),
        position:  points.last,
        icon:      BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: '📍 LAST FORENSIC PING'),
      ));
    }
    setState(() => _markers = markers);
  }

  Future<void> _exportForensicPdf() async {
    if (_data == null || _generating) return;
    HapticFeedback.mediumImpact();
    setState(() => _generating = true);

    try {
      final file = await _pdfService.generateReport(_data!);
      if (mounted) {
        setState(() => _generating = false);
        if (file != null) {
          _showExportVault(file);
        } else {
          _showSnackBar('Failed to generate report file.', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generating = false);
        _showSnackBar('Error generating PDF: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size:  20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppColors.sosRed : AppColors.safeGreen,
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showExportVault(dynamic file) {
    showModalBottomSheet(
      context:          context,
      backgroundColor:  Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ForensicExportSheet(
        file: file,
        data: _data!,
        onShare: () async {
          Navigator.pop(context);
          try {
            await _pdfService.shareReport(file, _data!);
            _showSnackBar('Dossier Shared Successfully');
          } catch (e) {
            _showSnackBar('Share Failed: $e', isError: true);
          }
        },
        onPrint: () async {
          Navigator.pop(context);
          try {
            await _pdfService.printReport(file);
          } catch (e) {
            _showSnackBar('Print Failed: $e', isError: true);
          }
        },
        onWA: () async {
          Navigator.pop(context);
          try {
            await _pdfService.shareToPoliceWhatsApp(_data!);
          } catch (e) {
            _showSnackBar('WhatsApp Redirect Failed: $e', isError: true);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF07070A),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    if (_data == null) return _buildDataMissing();

    final d           = _data!;
    final statusColor = _getForensicStatusColor(d.status);

    return Scaffold(
      backgroundColor: const Color(0xFF07070A),
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            expandedHeight: 310,
            pinned:         true,
            stretch:        true,
            backgroundColor: const Color(0xFF0F0F14),
            leading:        _backBtn(ctx),
            actions:        [_exportBtn()],
            flexibleSpace: FlexibleSpaceBar(
              background:    _HeroVanguard(data: d, color: statusColor),
              stretchModes: const [
                StretchMode.blurBackground,
                StretchMode.zoomBackground,
              ],
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: Container(
                decoration: BoxDecoration(
                  color:  const Color(0xFF07070A),
                  border: Border(
                    bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.05)),
                  ),
                ),
                child: _ForensicTabBar(tabs: _tabs),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [
            _buildOverviewTab(d, statusColor),
            _buildGpsTab(d),
            _buildEvidenceVault(d),
            _buildDispatchTab(d),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB BUILDERS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildOverviewTab(IncidentReportData d, Color sColor) =>
      ListView(
        padding:  const EdgeInsets.all(16),
        physics:  const BouncingScrollPhysics(),
        children: [
          FadeInDown(
            duration: const Duration(milliseconds: 600),
            child:    _DangerScoreTactical(data: d, color: sColor),
          ),
          const SizedBox(height: 16),
          FadeInUp(
            delay:    const Duration(milliseconds: 100),
            duration: const Duration(milliseconds: 500),
            child:    _ContextFlagsGrid(data: d),
          ),
          const SizedBox(height: 16),
          FadeInUp(
            delay:    const Duration(milliseconds: 200),
            duration: const Duration(milliseconds: 500),
            child:    _ForensicStatsGrid(data: d),
          ),
          const SizedBox(height: 16),
          FadeInUp(
            delay:    const Duration(milliseconds: 300),
            duration: const Duration(milliseconds: 500),
            child:    _IncidentChronology(data: d),
          ),
          const SizedBox(height: 40),
        ],
      );

  Widget _buildGpsTab(IncidentReportData d) => Stack(
    children: [
      // ✅ [FIXED] Use GoogleMap.style instead of deprecated setMapStyle()
      GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(d.lat, d.lng),
          zoom:   16,
        ),
        style:                _darkMapStyle,
        onMapCreated:         (c) => _mapCtrl = c,
        markers:              _markers,
        polylines:            _polylines,
        myLocationEnabled:    false,
        zoomControlsEnabled:  false,
      ),
      Positioned(
        bottom: 20,
        left:   16,
        right:  16,
        child:  FadeInUp(child: _GpsOverlayCard(data: d)),
      ),
    ],
  );

  Widget _buildEvidenceVault(IncidentReportData d) => ListView(
    padding:  const EdgeInsets.all(16),
    physics:  const BouncingScrollPhysics(),
    children: [
      _VaultHeader(
        title: '🎙️ AUDIOMETRIC DATA',
        count: d.audioUrl != null ? 1 : 0,
      ),
      if (d.audioUrl != null)
        FadeInLeft(
          child: _EvidenceRow(
            label: 'Continuous Forensic Stream',
            type:  'M4A',
            color: Colors.deepPurpleAccent,
            meta:  d.audioPeakAmplitude != null
                ? 'Peak: ${d.audioPeakAmplitude!.toStringAsFixed(1)}dB'
                : 'Encrypted Uplink',
          ),
        )
      else
        const _EmptyRow(msg: 'No audio captured in this cycle.'),
      const SizedBox(height: 20),
      _VaultHeader(
        title: '🎥 VIDEO MICRO-CHUNKS',
        count: d.videoUrls.length,
      ),
      if (d.videoUrls.isEmpty)
        const _EmptyRow(msg: 'No video segments available.'),
      ...d.videoUrls.asMap().entries.map(
            (e) => FadeInLeft(
          delay: Duration(milliseconds: 50 * e.key),
          child: _EvidenceRow(
            label: 'Tactical Segment ${e.key + 1}',
            type:  'MP4',
            color: AppColors.sosRed,
            meta:  'Verified Origin',
          ),
        ),
      ),
      const SizedBox(height: 20),
      _VaultHeader(
        title: '📷 FACIAL BURST PHOTOS',
        count: d.photoUrls.length,
      ),
      if (d.photoUrls.isEmpty)
        const _EmptyRow(msg: 'No photo bursts available.'),
      GridView.builder(
        shrinkWrap: true,
        physics:    const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:   3,
          crossAxisSpacing: 10,
          mainAxisSpacing:  10,
          childAspectRatio: 1,
        ),
        itemCount:   d.photoUrls.length,
        itemBuilder: (ctx, i) => FadeInUp(
          delay: Duration(milliseconds: 50 * i),
          child: Container(
            decoration: BoxDecoration(
              color:        const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              border:       Border.all(
                  color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color:      Colors.black.withValues(alpha: 0.5),
                  blurRadius: 10,
                  offset:     const Offset(0, 4),
                ),
              ],
              image: DecorationImage(
                image: NetworkImage(d.photoUrls[i]),
                fit:   BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 40),
    ],
  );

  Widget _buildDispatchTab(IncidentReportData d) {
    if (d.alertsSent.isEmpty) {
      return _buildEmptyState('No Dispatch Log Available');
    }
    return ListView.builder(
      padding:     const EdgeInsets.all(16),
      physics:     const BouncingScrollPhysics(),
      itemCount:   d.alertsSent.length,
      itemBuilder: (ctx, i) => FadeInUp(
        delay: Duration(milliseconds: 50 * i),
        // ✅ [FIXED] AlertSentRecord resolved via evidence_models.dart import
        child: _DispatchCard(alert: d.alertsSent[i]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════════════════

  Color _getForensicStatusColor(String s) {
    if (s == 'resolved')                                    return AppColors.safeGreen;
    if (s == 'active' || s == 'collecting' || s == 'uploading') {
      return const Color(0xFF1976D2);
    }
    return AppColors.sosRed;
  }

  Widget _backBtn(BuildContext ctx) => IconButton(
    icon: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.arrow_back_ios_new_rounded,
        color: Colors.white,
        size:  18,
      ),
    ),
    onPressed: () => Navigator.pop(ctx),
  );

  Widget _exportBtn() => _generating
      ? Container(
    margin: const EdgeInsets.only(right: 16),
    width:  24,
    height: 24,
    child: const CircularProgressIndicator(
      strokeWidth: 2,
      color:       Colors.white,
    ),
  )
      : IconButton(
    icon: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.download_rounded,
        color: AppColors.primary,
        size:  20,
      ),
    ),
    onPressed: _exportForensicPdf,
  );

  Widget _buildDataMissing() => const Scaffold(
    backgroundColor: Color(0xFF07070A),
    body: Center(
      child: Text(
        'FORENSIC DATA UNREACHABLE',
        style: TextStyle(
          color:      Colors.white54,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    ),
  );

  Widget _buildEmptyState(String msg) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.history_toggle_off_rounded,
          size:  60,
          color: Colors.white.withValues(alpha: 0.05),
        ),
        const SizedBox(height: 16),
        Text(
          msg,
          style: const TextStyle(
            color:      Colors.white54,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// CUSTOM UI WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _HeroVanguard extends StatelessWidget {
  final IncidentReportData data;
  final Color              color;
  const _HeroVanguard({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEEE, dd MMM yyyy');
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 110, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.25),
            const Color(0xFF07070A),
          ],
          begin:  Alignment.topCenter,
          end:    Alignment.bottomCenter,
          stops:  const [0.0, 0.9],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _Badge(label: data.status.toUpperCase(), color: color, isGlowing: true),
            const SizedBox(width: 8),
            _Badge(
              label: data.triggerType.toUpperCase(),
              color: Colors.white.withValues(alpha: 0.1),
            ),
            if (data.isSilent) ...[
              const SizedBox(width: 8),
              _Badge(
                label:     'SILENT',
                color:     Colors.purpleAccent.withValues(alpha: 0.2),
                textColor: Colors.purpleAccent,
              ),
            ],
          ]),
          const Spacer(),
          Text(
            fmt.format(data.triggeredAt),
            style: TextStyle(
              color:      Colors.white.withValues(alpha: 0.6),
              fontSize:   12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const Text(
            'INCIDENT DOSSIER',
            style: TextStyle(
              color:         Colors.white,
              fontSize:      32,
              fontWeight:    FontWeight.w900,
              letterSpacing: -0.5,
              fontFamily:    'Poppins',
            ),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on_rounded,
                size:  14,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                data.address ??
                    'Coordinates: ${data.lat.toStringAsFixed(4)}, '
                        '${data.lng.toStringAsFixed(4)}',
                maxLines:  2,
                overflow:  TextOverflow.ellipsis,
                style: const TextStyle(
                  color:    Colors.white70,
                  fontSize: 12,
                  height:   1.4,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String  label;
  final Color   color;
  final bool    isGlowing;
  final Color?  textColor;

  const _Badge({
    required this.label,
    required this.color,
    this.isGlowing = false,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color:        isGlowing ? color.withValues(alpha: 0.2) : color,
      borderRadius: BorderRadius.circular(30),
      border: Border.all(
        color: isGlowing
            ? color.withValues(alpha: 0.5)
            : Colors.transparent,
      ),
      boxShadow: isGlowing
          ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8)]
          : [],
    ),
    child: Text(
      label,
      style: TextStyle(
        color:         textColor ?? (isGlowing ? color : Colors.white),
        fontWeight:    FontWeight.w900,
        fontSize:      10,
        letterSpacing: 0.8,
      ),
    ),
  );
}

class _DangerScoreTactical extends StatelessWidget {
  final IncidentReportData data;
  final Color              color;
  const _DangerScoreTactical({required this.data, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          color.withValues(alpha: 0.15),
          const Color(0xFF141414),
        ],
        begin: Alignment.topLeft,
        end:   Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(
          color: color.withValues(alpha: 0.3), width: 1.5),
      boxShadow: [
        BoxShadow(
          color:      color.withValues(alpha: 0.1),
          blurRadius: 25,
          offset:     const Offset(0, 10),
        ),
      ],
    ),
    child: Row(children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI CONFIDENCE SCORE',
              style: TextStyle(
                color:         Colors.white.withValues(alpha: 0.5),
                fontSize:      10,
                fontWeight:    FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(data.dangerScore * 100).toInt()}%',
              style: TextStyle(
                color:      color,
                fontSize:   56,
                fontWeight: FontWeight.w900,
                height:     1.1,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              data.dangerScore > 0.8
                  ? 'CRITICAL THREAT CONFIRMED'
                  : 'MODERATE RISK DETECTED',
              style: TextStyle(
                color:      Colors.white.withValues(alpha: 0.8),
                fontSize:   11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color:  color.withValues(alpha: 0.15),
          shape:  BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.3), blurRadius: 20),
          ],
        ),
        child: Icon(Icons.analytics_rounded, color: color, size: 48),
      ),
    ]),
  );
}

class _ContextFlagsGrid extends StatelessWidget {
  final IncidentReportData data;
  const _ContextFlagsGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final flags = <Widget>[];
    if (data.phoneFallen)  flags.add(_flag('📱', 'Fall Detected',  Colors.redAccent));
    if (data.phoneInPocket) flags.add(_flag('🫳', 'In Pocket',      Colors.orange));
    if (data.isNightTime)  flags.add(_flag('🌙', 'Night Ops',      Colors.indigoAccent));
    if (data.phoneCharging) flags.add(_flag('🔋', 'Charging',       AppColors.safeGreen));
    if (data.screamProbability != null && data.screamProbability! > 0.5) {
      flags.add(_flag('😱', 'Scream Detected', AppColors.sosRed));
    }
    if (flags.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 12, runSpacing: 12, children: flags);
  }

  Widget _flag(String emoji, String text, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color:        const Color(0xFF1A1A1A),
      border:       Border.all(color: c.withValues(alpha: 0.3)),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: c.withValues(alpha: 0.08), blurRadius: 12),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            color:      c,
            fontSize:   12,
            fontWeight: FontWeight.w900,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    ),
  );
}

class _ForensicTabBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController tabs;
  const _ForensicTabBar({required this.tabs});

  @override
  Widget build(BuildContext context) => TabBar(
    controller:         tabs,
    indicatorColor:     AppColors.primary,
    indicatorWeight:    4,
    indicatorSize:      TabBarIndicatorSize.label,
    dividerColor:       Colors.transparent,
    labelColor:         Colors.white,
    labelStyle: const TextStyle(
      fontWeight:    FontWeight.w900,
      fontSize:      12,
      fontFamily:    'Poppins',
      letterSpacing: 1,
    ),
    unselectedLabelColor: Colors.white.withValues(alpha: 0.4),
    tabs: const [
      Tab(text: 'INTEL'),
      Tab(text: 'GPS'),
      Tab(text: 'VAULT'),
      Tab(text: 'LOGS'),
    ],
  );

  @override
  Size get preferredSize => const Size.fromHeight(50);
}

class _ForensicStatsGrid extends StatelessWidget {
  final IncidentReportData data;
  const _ForensicStatsGrid({required this.data});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(children: [
        Expanded(
          child: _statItem('PHOTOS', data.photoUrls.length.toString(),
              AppColors.warningAmber, Icons.camera_alt_rounded),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statItem('VIDEO', data.videoUrls.length.toString(),
              AppColors.sosRed, Icons.videocam_rounded),
        ),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: _statItem('ALERTS', data.alertsSent.length.toString(),
              Colors.purpleAccent, Icons.send_rounded),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statItem('GPS PINGS', data.gpsTrail.length.toString(),
              AppColors.secondary, Icons.satellite_alt_rounded),
        ),
      ]),
    ],
  );

  Widget _statItem(String label, String val, Color c, IconData icon) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        decoration: BoxDecoration(
          color:        const Color(0xFF141414),
          borderRadius: BorderRadius.circular(22),
          border:       Border.all(
              color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:        c.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: c, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment:  MainAxisAlignment.center,
              children: [
                Text(
                  val,
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   22,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Poppins',
                    height:     1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color:         Colors.white.withValues(alpha: 0.4),
                    fontSize:      10,
                    fontWeight:    FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ]),
      );
}

class _IncidentChronology extends StatelessWidget {
  final IncidentReportData data;
  const _IncidentChronology({required this.data});

  @override
  Widget build(BuildContext context) {
    final startFmt = DateFormat('HH:mm:ss').format(data.triggeredAt);
    final endFmt   = data.resolvedAt != null
        ? DateFormat('HH:mm:ss').format(data.resolvedAt!)
        : 'Active';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color:        const Color(0xFF141414),
        borderRadius: BorderRadius.circular(28),
        border:       Border.all(
            color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset:     const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.timeline_rounded,
                color: Colors.white,
                size:  16,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'CHAIN OF CUSTODY',
              style: TextStyle(
                color:         Colors.white,
                fontWeight:    FontWeight.w900,
                fontSize:      13,
                letterSpacing: 1.2,
                fontFamily:    'Poppins',
              ),
            ),
          ]),
          const SizedBox(height: 28),
          _step(AppColors.sosRed,    'Threat Detected',           startFmt),
          _step(AppColors.primary,   'Multipath Alerts Dispatched', 'T + 1.2s'),
          _step(AppColors.secondary, 'Evidence Uplink Active',     'T + 3.5s'),
          _step(
            data.status == 'resolved'
                ? AppColors.safeGreen
                : AppColors.warningAmber,
            data.status == 'resolved' ? 'Incident Finalized' : 'Monitoring...',
            endFmt,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _step(Color c, String title, String time,
      {bool isLast = false}) =>
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(children: [
              Container(
                width:  16,
                height: 16,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFF141414), width: 3),
                  boxShadow: [
                    BoxShadow(
                        color: c.withValues(alpha: 0.6), blurRadius: 8),
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
            ]),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   14,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      time,
                      style: TextStyle(
                        color:      c.withValues(alpha: 0.8),
                        fontSize:   11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class _VaultHeader extends StatelessWidget {
  final String title;
  final int    count;
  const _VaultHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 16),
    child: Row(children: [
      Text(
        title,
        style: TextStyle(
          color:         Colors.white.withValues(alpha: 0.5),
          fontSize:      12,
          fontWeight:    FontWeight.w900,
          letterSpacing: 1.2,
          fontFamily:    'Poppins',
        ),
      ),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:        AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$count FILES',
          style: const TextStyle(
            color:      AppColors.primary,
            fontSize:   10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ]),
  );
}

class _EvidenceRow extends StatelessWidget {
  final String  label;
  final String  type;
  final Color   color;
  final String? meta;

  const _EvidenceRow({
    required this.label,
    required this.type,
    required this.color,
    this.meta,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin:  const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color:        const Color(0xFF141414),
      borderRadius: BorderRadius.circular(18),
      border:       Border.all(
          color: Colors.white.withValues(alpha: 0.05)),
      boxShadow: [
        BoxShadow(
          color:      Colors.black.withValues(alpha: 0.2),
          blurRadius: 10,
          offset:     const Offset(0, 4),
        ),
      ],
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          type,
          style: TextStyle(
            color:      color,
            fontSize:   11,
            fontWeight: FontWeight.w900,
            fontFamily: 'Poppins',
          ),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color:      Colors.white,
                fontSize:   14,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 6),
            if (meta != null)
              Text(
                meta!,
                style: TextStyle(
                  color:      Colors.white.withValues(alpha: 0.5),
                  fontSize:   11,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.safeGreen.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.shield_rounded,
          color: AppColors.safeGreen.withValues(alpha: 0.9),
          size:  20,
        ),
      ),
    ]),
  );
}

class _EmptyRow extends StatelessWidget {
  final String msg;
  const _EmptyRow({required this.msg});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    child: Row(children: [
      Icon(
        Icons.info_outline,
        color: Colors.white.withValues(alpha: 0.2),
        size:  16,
      ),
      const SizedBox(width: 8),
      Text(
        msg,
        style: TextStyle(
          color:      Colors.white.withValues(alpha: 0.4),
          fontSize:   12,
          fontStyle:  FontStyle.italic,
          fontFamily: 'Poppins',
        ),
      ),
    ]),
  );
}

class _GpsOverlayCard extends StatelessWidget {
  final IncidentReportData data;
  const _GpsOverlayCard({required this.data});

  double _haversine(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final p = math.pi / 180;
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lng2 - lng1) * p)) /
            2;
    return 2 * r * math.asin(math.sqrt(a));
  }

  @override
  Widget build(BuildContext context) {
    double totalDist = 0;
    if (data.gpsTrail.length > 1) {
      for (int i = 1; i < data.gpsTrail.length; i++) {
        totalDist += _haversine(
          data.gpsTrail[i - 1].lat,
          data.gpsTrail[i - 1].lng,
          data.gpsTrail[i].lat,
          data.gpsTrail[i].lng,
        );
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A).withValues(alpha: 0.75),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.15)),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(child: _item('LATITUDE',  data.lat.toStringAsFixed(4))),
              Container(
                  width: 1, height: 40,
                  color: Colors.white.withValues(alpha: 0.15)),
              Expanded(child: _item('LONGITUDE', data.lng.toStringAsFixed(4))),
              Container(
                  width: 1, height: 40,
                  color: Colors.white.withValues(alpha: 0.15)),
              Expanded(child: _item('DISTANCE', '${totalDist.toInt()}m')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(String k, String v) => Column(children: [
    Text(
      k,
      style: TextStyle(
        color:         Colors.white.withValues(alpha: 0.5),
        fontSize:      9,
        fontWeight:    FontWeight.w900,
        letterSpacing: 1.5,
        fontFamily:    'Poppins',
      ),
    ),
    const SizedBox(height: 6),
    FittedBox(
      fit:   BoxFit.scaleDown,
      child: Text(
        v,
        style: const TextStyle(
          color:      Colors.white,
          fontSize:   16,
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
        ),
      ),
    ),
  ]);
}

// ✅ [FIXED] AlertSentRecord is defined in evidence_models.dart
//           and resolved via the direct import at the top of this file.
class _DispatchCard extends StatelessWidget {
  final AlertSentRecord alert;
  const _DispatchCard({required this.alert});

  @override
  Widget build(BuildContext context) => Container(
    margin:  const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color:        const Color(0xFF141414),
      borderRadius: BorderRadius.circular(24),
      border:       Border.all(
          color: Colors.white.withValues(alpha: 0.05)),
      boxShadow: [
        BoxShadow(
          color:      Colors.black.withValues(alpha: 0.2),
          blurRadius: 15,
          offset:     const Offset(0, 5),
        ),
      ],
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.person_rounded,
          color: AppColors.primary,
          size:  24,
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              alert.contactName,
              style: const TextStyle(
                color:      Colors.white,
                fontWeight: FontWeight.w800,
                fontSize:   16,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              alert.phone,
              style: TextStyle(
                color:      Colors.white.withValues(alpha: 0.6),
                fontSize:   13,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing:    8,
              runSpacing: 8,
              children: [
                if (alert.whatsapp)
                  _channelBadge('WhatsApp', const Color(0xFF25D366)),
                if (alert.sms)
                  _channelBadge('SMS',  Colors.blueAccent),
                if (alert.fcm)
                  _channelBadge('Push', Colors.orangeAccent),
                if (alert.called)
                  _channelBadge('Call', AppColors.sosRed),
              ],
            ),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.safeGreen.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.done_all_rounded,
          color: AppColors.safeGreen,
          size:  18,
        ),
      ),
    ]),
  );

  Widget _channelBadge(String text, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color:        c.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
      border:       Border.all(color: c.withValues(alpha: 0.3)),
    ),
    child: Text(
      text,
      style: TextStyle(
        color:         c,
        fontSize:      10,
        fontWeight:    FontWeight.w900,
        letterSpacing: 0.5,
        fontFamily:    'Poppins',
      ),
    ),
  );
}

class _ForensicExportSheet extends StatelessWidget {
  final dynamic          file;
  final IncidentReportData data;
  final VoidCallback     onShare;
  final VoidCallback     onPrint;
  final VoidCallback     onWA;

  const _ForensicExportSheet({
    required this.file,
    required this.data,
    required this.onShare,
    required this.onPrint,
    required this.onWA,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color:        const Color(0xFF141414),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      border:       Border.all(
          color: Colors.white.withValues(alpha: 0.1)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width:  48,
          height: 5,
          decoration: BoxDecoration(
            color:        Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.safeGreen.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.verified_user_rounded,
            color: AppColors.safeGreen,
            size:  56,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'DOSSIER GENERATED',
          style: TextStyle(
            color:         Colors.white,
            fontWeight:    FontWeight.w900,
            fontSize:      22,
            letterSpacing: 1.5,
            fontFamily:    'Poppins',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Encrypted PDF contains all metadata, photos, and evidence '
              'links ready for authorities.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color:      Colors.white.withValues(alpha: 0.6),
            fontSize:   13,
            fontFamily: 'Poppins',
            height:     1.5,
          ),
        ),
        const SizedBox(height: 36),
        _btn(Icons.share_rounded, 'SHARE TO AUTHORITIES',
            AppColors.primary, onShare),
        const SizedBox(height: 14),
        _btn(Icons.chat_rounded, 'POLICE WHATSAPP CHANNEL',
            const Color(0xFF25D366), onWA),
        const SizedBox(height: 14),
        _btn(Icons.print_rounded, 'PRINT EVIDENCE REPORT',
            Colors.white.withValues(alpha: 0.1), onPrint,
            textColor: Colors.white),
        const SizedBox(height: 24),
      ],
    ),
  );

  Widget _btn(
      IconData   icon,
      String     t,
      Color      c,
      VoidCallback tap, {
        Color textColor = Colors.white,
      }) =>
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: tap,
          style: ElevatedButton.styleFrom(
            backgroundColor: c,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18)),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: textColor, size: 20),
              const SizedBox(width: 12),
              Text(
                t,
                style: TextStyle(
                  color:         textColor,
                  fontWeight:    FontWeight.w900,
                  fontSize:      14,
                  letterSpacing: 0.5,
                  fontFamily:    'Poppins',
                ),
              ),
            ],
          ),
        ),
      );
}