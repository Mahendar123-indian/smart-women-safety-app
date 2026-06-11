// lib/features/police/screens/police_dashboard_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// INDUSTRIAL SENTINEL — POLICE COMMAND DASHBOARD v5.0
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
// ✅ FIXED: Imported the Live Evidence Screen so the navigation works perfectly
import 'police_live_evidence_screen.dart';

class PoliceDashboardScreen extends StatefulWidget {
  const PoliceDashboardScreen({super.key});

  @override
  State<PoliceDashboardScreen> createState() => _PoliceDashboardScreenState();
}

class _PoliceDashboardScreenState extends State<PoliceDashboardScreen> with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  late AnimationController _flashCtrl;
  DateTime _now = DateTime.now();
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // Creates the flashing red effect for active emergencies
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _flashCtrl.dispose();
    _clock?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05050C), // Deep tactical black
      appBar: _buildTacticalAppBar(),
      body: Column(
        children: [
          _buildLiveMapStream(),
          _buildDispatchFeedTitle(),
          Expanded(child: _buildLiveDispatchFeed()),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TACTICAL APP BAR
  // ═══════════════════════════════════════════════════════════════════════
  PreferredSizeWidget _buildTacticalAppBar() {
    final timeStr = "${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}:${_now.second.toString().padLeft(2, '0')}";

    return AppBar(
      backgroundColor: const Color(0xFF0A0A1A),
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF1976D2).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.local_police_rounded, color: Color(0xFF1976D2), size: 20),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CENTRAL COMMAND',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5, color: Colors.white),
              ),
              Text(
                'STATE POLICE DISPATCH',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 9, color: Colors.white54, letterSpacing: 2),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              timeStr,
              style: const TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.safeGreen),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // LIVE GOOGLE MAP STREAM (Top Half)
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildLiveMapStream() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.35,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('policeDispatches')
            .where('status', whereIn: ['CRITICAL_DISPATCH', 'ACTIVE_DISPATCH', 'FALLBACK_ROUTED'])
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1976D2)));
          }

          final docs = snapshot.data!.docs;
          Set<Marker> markers = {};
          Set<Circle> circles = {};

          if (docs.isNotEmpty) {
            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              final lat = (data['lat'] as num).toDouble();
              final lng = (data['lng'] as num).toDouble();
              final pos = LatLng(lat, lng);
              final id = doc.id;

              markers.add(
                Marker(
                  markerId: MarkerId(id),
                  position: pos,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                  infoWindow: InfoWindow(title: '🚨 SOS: ${data['victimName']}', snippet: 'Danger: ${(data['dangerScore'] * 100).toInt()}%'),
                ),
              );

              circles.add(
                Circle(
                  circleId: CircleId('${id}_radius'),
                  center: pos,
                  radius: 200,
                  fillColor: AppColors.sosRed.withValues(alpha: 0.15),
                  strokeColor: AppColors.sosRed,
                  strokeWidth: 2,
                ),
              );
            }

            // Move camera to latest dispatch
            if (_mapController != null) {
              final latest = docs.first.data() as Map<String, dynamic>;
              _mapController!.animateCamera(CameraUpdate.newLatLngZoom(
                LatLng((latest['lat'] as num).toDouble(), (latest['lng'] as num).toDouble()), 13.5,
              ));
            }
          }

          return Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF1976D2), width: 3)),
            ),
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(target: LatLng(17.3850, 78.4867), zoom: 11), // Default Hyderabad
              onMapCreated: (c) {
                _mapController = c;
                // Optional: Apply dark map style here if you have a json map style
              },
              markers: markers,
              circles: circles,
              myLocationEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildDispatchFeedTitle() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0A0A1A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.warningAmber, size: 16),
          SizedBox(width: 8),
          Text(
            'LIVE EMERGENCY FEED',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white54, letterSpacing: 1.2),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // INCOMING SOS FEED (Bottom Half)
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildLiveDispatchFeed() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('policeDispatches')
          .orderBy('dispatchedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.sosRed)));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF1976D2)));

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, size: 64, color: Colors.white.withValues(alpha: 0.1)),
                const SizedBox(height: 16),
                const Text('NO ACTIVE EMERGENCIES', style: TextStyle(fontFamily: 'Poppins', color: Colors.white54, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          physics: const BouncingScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final isActive = data['status'] != 'RESOLVED';

            return _DispatchCard(
              data: data,
              isActive: isActive,
              flashCtrl: _flashCtrl,
              onTap: () {
                HapticFeedback.selectionClick();
                // ✅ FIXED: Safely navigates to the detailed tactical view
                Navigator.push(context, MaterialPageRoute(builder: (_) => PoliceLiveEvidenceScreen(dispatchData: data)));
              },
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// INDIVIDUAL DISPATCH CARD
// ═══════════════════════════════════════════════════════════════════════
class _DispatchCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isActive;
  final AnimationController flashCtrl;
  final VoidCallback onTap;

  const _DispatchCard({required this.data, required this.isActive, required this.flashCtrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dangerScore = (data['dangerScore'] * 100).toInt();
    final isCritical = dangerScore > 85;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: flashCtrl,
        builder: (context, child) {
          final flashAlpha = isActive && isCritical ? 0.15 + (0.15 * flashCtrl.value) : 0.05;
          final borderColor = isActive
              ? (isCritical ? AppColors.sosRed : AppColors.warningAmber)
              : Colors.white.withValues(alpha: 0.1);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: borderColor.withValues(alpha: flashAlpha),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: isActive ? 1.5 : 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (isActive)
                            Icon(Icons.emergency_share_rounded, color: isCritical ? AppColors.sosRed : AppColors.warningAmber, size: 18)
                          else
                            const Icon(Icons.check_circle_outline, color: AppColors.safeGreen, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            data['incidentId'].toString().toUpperCase().substring(0, 8),
                            style: const TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.sosRed : AppColors.safeGreen,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isActive ? 'PRIORITY OMEGA' : 'RESOLVED',
                          style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w900, fontSize: 10, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'VICTIM: ${data['victimName'].toString().toUpperCase()}',
                    style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'TRIGGER: ${data['triggerType'].toString().toUpperCase()}  |  AI CONFIDENCE: $dangerScore%',
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 11, color: Colors.white.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFF1976D2), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${(data['lat'] as num).toStringAsFixed(5)}, ${(data['lng'] as num).toStringAsFixed(5)}',
                        style: const TextStyle(fontFamily: 'Courier', fontSize: 12, color: Color(0xFF1976D2), fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      const Text(
                        'TAP TO INTERCEPT ❯',
                        style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white54),
                      )
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}