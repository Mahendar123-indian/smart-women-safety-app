// lib/features/police/screens/police_live_evidence_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// INDUSTRIAL SENTINEL — POLICE LIVE EVIDENCE TACTICAL VIEW
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/theme/app_colors.dart';

class PoliceLiveEvidenceScreen extends StatefulWidget {
  final Map<String, dynamic> dispatchData;

  const PoliceLiveEvidenceScreen({super.key, required this.dispatchData});

  @override
  State<PoliceLiveEvidenceScreen> createState() => _PoliceLiveEvidenceScreenState();
}

class _PoliceLiveEvidenceScreenState extends State<PoliceLiveEvidenceScreen> {
  GoogleMapController? _mapController;

  late String incidentId;
  late String victimUid;

  @override
  void initState() {
    super.initState();
    incidentId = widget.dispatchData['incidentId'];
    victimUid = widget.dispatchData['victimUid'];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05050C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A1A),
        title: const Text(
          'TACTICAL INTERCEPT',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.sosRed.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.sosRed),
            ),
            child: const Center(
              child: Text('LIVE RECORD', style: TextStyle(color: AppColors.sosRed, fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        // Streaming directly from the Victim's live incident record!
        stream: FirebaseFirestore.instance.collection('users').doc(victimUid).collection('incidents').doc(incidentId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Secure Link Failed.', style: TextStyle(color: AppColors.sosRed)));
          if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: CircularProgressIndicator(color: Color(0xFF1976D2)));

          final liveData = snapshot.data!.data() as Map<String, dynamic>;
          final lat = (liveData['lat'] as num).toDouble();
          final lng = (liveData['lng'] as num).toDouble();

          List<dynamic> photos = liveData['photoUrls'] ?? [];
          List<dynamic> videos = liveData['videoUrls'] ?? [];
          String? audioUrl = liveData['audioUrl'];

          if (_mapController != null) {
            _mapController!.animateCamera(CameraUpdate.newLatLng(LatLng(lat, lng)));
          }

          return Column(
            children: [
              _buildTargetInfo(liveData),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.35,
                child: _buildMap(lat, lng),
              ),
              _buildEvidenceVaultTitle(photos.length, videos.length, audioUrl != null),
              Expanded(
                child: _buildEvidenceGrid(photos, videos, audioUrl),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('DISPATCH PATROL UNIT', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white, letterSpacing: 1)),
          ),
        ),
      ),
    );
  }

  Widget _buildTargetInfo(Map<String, dynamic> liveData) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF0A0A1A),
      child: Row(
        children: [
          const Icon(Icons.person_pin, color: Colors.white, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.dispatchData['victimName'].toString().toUpperCase(),
                  style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white),
                ),
                Text(
                  'TRIGGER: ${liveData['triggerType'].toString().toUpperCase()}',
                  style: const TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.warningAmber),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('DANGER', style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: Colors.white54)),
              Text(
                '${(liveData['dangerScore'] * 100).toInt()}%',
                style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w900, fontSize: 24, color: AppColors.sosRed),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMap(double lat, double lng) {
    final pos = LatLng(lat, lng);
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: pos, zoom: 16.5),
      onMapCreated: (c) => _mapController = c,
      markers: {
        Marker(markerId: const MarkerId('target'), position: pos, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)),
      },
      circles: {
        Circle(circleId: const CircleId('radius'), center: pos, radius: 100, fillColor: AppColors.sosRed.withValues(alpha: 0.2), strokeColor: AppColors.sosRed, strokeWidth: 1),
      },
      myLocationEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
    );
  }

  Widget _buildEvidenceVaultTitle(int pCount, int vCount, bool hasAudio) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0A0A1A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('INCOMING FORENSICS', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white54, letterSpacing: 1.2)),
          Text('📷 $pCount  🎥 $vCount  🎙️ ${hasAudio ? 1 : 0}', style: const TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.safeGreen)),
        ],
      ),
    );
  }

  Widget _buildEvidenceGrid(List<dynamic> photos, List<dynamic> videos, String? audioUrl) {
    List<Widget> items = [];

    if (audioUrl != null) {
      items.add(_EvidenceTile(icon: Icons.mic, type: 'AUDIO SECURED', color: AppColors.secondary));
    }
    for (int i = 0; i < videos.length; i++) {
      items.add(_EvidenceTile(icon: Icons.videocam, type: 'VIDEO CHUNK ${i+1}', color: const Color(0xFF7C4DFF)));
    }
    for (int i = 0; i < photos.length; i++) {
      items.add(_EvidenceTile(icon: Icons.camera_alt, type: 'PHOTO FRAME ${i+1}', color: AppColors.warningAmber, isImage: true, url: photos[i]));
    }

    if (items.isEmpty) {
      return const Center(
        child: Text('Awaiting secure uplink from device...', style: TextStyle(fontFamily: 'Courier', color: Colors.white54)),
      );
    }

    return GridView.count(
      crossAxisCount: 3,
      padding: const EdgeInsets.all(12),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      physics: const BouncingScrollPhysics(),
      children: items,
    );
  }
}

class _EvidenceTile extends StatelessWidget {
  final IconData icon;
  final String type;
  final Color color;
  final bool isImage;
  final String? url;

  const _EvidenceTile({required this.icon, required this.type, required this.color, this.isImage = false, this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: isImage && url != null
          ? ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(url!, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Center(child: Icon(Icons.broken_image, color: Colors.white24))),
      )
          : Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(type, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Courier', fontSize: 9, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}