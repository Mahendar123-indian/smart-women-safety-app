// lib/features/incidents/screens/incidents_screen.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import 'incident_detail_screen.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FORENSIC DATA PARSERS
// ─────────────────────────────────────────────────────────────────────────────

DateTime? _toDateTime(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is int) {
    return value > 1000000000000
        ? DateTime.fromMillisecondsSinceEpoch(value)
        : DateTime.fromMillisecondsSinceEpoch(value * 1000);
  }
  if (value is String) return DateTime.tryParse(value);
  return null;
}

double _normScore(dynamic raw) {
  final v = (raw as num?)?.toDouble() ?? 0.0;
  return v > 1.0 ? (v / 100.0).clamp(0.0, 1.0) : v.clamp(0.0, 1.0);
}

Color _severityColor(double norm) {
  if (norm >= 0.85) return AppColors.sosRed;
  if (norm >= 0.60) return AppColors.warningAmber;
  return AppColors.safeGreen;
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN INCIDENTS SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class IncidentsScreen extends StatefulWidget {
  const IncidentsScreen({super.key});

  @override
  State<IncidentsScreen> createState() => _IncidentsScreenState();
}

class _IncidentsScreenState extends State<IncidentsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  String get _uid => _auth.currentUser?.uid ?? '';

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _incidents = [];
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _startForensicStream();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _startForensicStream() {
    if (_uid.isEmpty) {
      if (mounted) setState(() { _loading = false; _error = 'AUTH_SESSION_EXPIRED'; });
      return;
    }

    _sub?.cancel();
    _sub = _firestore
        .collection('users')
        .doc(_uid)
        .collection('incidents')
        .orderBy('triggeredAt', descending: true)
        .limit(40)
        .snapshots()
        .listen(
          (snap) {
        final list = snap.docs.map((doc) {
          final d = Map<String, dynamic>.from(doc.data());
          d['id'] = doc.id;
          return d;
        }).toList();

        if (mounted) {
          setState(() {
            _incidents = list;
            _loading = false;
            _error = null;
          });
        }
      },
      onError: (e) {
        if (mounted) setState(() { _loading = false; _error = e.toString(); });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), // Deep tactical black
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A).withValues(alpha: 0.6),
                border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
              ),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('FORENSIC ARCHIVE',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5, fontFamily: 'Poppins')),
            if (!_loading)
              Text('${_incidents.length} SECURE RECORDS',
                  style: TextStyle(fontSize: 10, color: AppColors.primary.withValues(alpha: 0.8), fontWeight: FontWeight.w700, letterSpacing: 1)),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sync_rounded, color: Colors.white, size: 20),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() => _loading = true);
              _startForensicStream();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3));
    if (_error != null) return _buildErrorState();
    if (_incidents.isEmpty) return const _EmptyArchiveState();

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: const Color(0xFF1A1A1A),
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        _startForensicStream();
      },
      child: ListView.builder(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 20, left: 16, right: 16, bottom: 40),
        physics: const BouncingScrollPhysics(),
        itemCount: _incidents.length,
        itemBuilder: (ctx, i) => _IncidentRecordCard(
          incident: _incidents[i],
          uid: _uid,
          delayIndex: i, // For staggered animation
        ),
      ),
    );
  }

  Widget _buildErrorState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.sosRed.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: const Icon(Icons.gpp_bad_rounded, size: 50, color: AppColors.sosRed),
        ),
        const SizedBox(height: 24),
        const Text('VAULT ACCESS DENIED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
          child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TACTICAL RECORD CARD
// ─────────────────────────────────────────────────────────────────────────────

class _IncidentRecordCard extends StatelessWidget {
  final Map<String, dynamic> incident;
  final String uid;
  final int delayIndex;

  const _IncidentRecordCard({required this.incident, required this.uid, required this.delayIndex});

  @override
  Widget build(BuildContext context) {
    final String incidentId = incident['id'] as String? ?? '';
    final double norm = _normScore(incident['dangerScore']);
    final Color sColor = _severityColor(norm);
    final DateTime? dt = _toDateTime(incident['triggeredAt'] ?? incident['createdAt']);

    final int photos = (incident['photoBurstUrls'] as List?)?.length ??
        ((incident['backPhotoCount'] as int? ?? 0) + (incident['frontPhotoCount'] as int? ?? 0));
    final int videos = (incident['videoUrls'] as List?)?.length ?? 0;
    final bool hasAudio = incident['audioUrl'] != null || incident['audioEvidenceUrl'] != null;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => IncidentDetailScreen(incidentId: incidentId)),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
            boxShadow: [
              BoxShadow(
                color: sColor.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              children: [
                // ── Glowing Header ─────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [sColor.withValues(alpha: 0.15), Colors.transparent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                  ),
                  child: Row(
                    children: [
                      _RiskBadge(norm: norm, color: sColor),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (incident['triggerType'] as String? ?? 'MANUAL').toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dt != null ? DateFormat('dd MMM yyyy · HH:mm:ss').format(dt) : 'DATE_UNKNOWN',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                      _StatusChip(status: incident['status'] as String? ?? 'active'),
                    ],
                  ),
                ),

                // ── Card Body ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.my_location_rounded, size: 16, color: AppColors.secondary.withValues(alpha: 0.8)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              incident['address'] ?? '${(incident['lat'] as num?)?.toStringAsFixed(4) ?? '0.0'}, ${(incident['lng'] as num?)?.toStringAsFixed(4) ?? '0.0'}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12, height: 1.4, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // ✅ FIXED: Changed Row to Wrap to prevent overflow on small screens
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ForensicPill(icon: Icons.graphic_eq_rounded, label: hasAudio ? 'AUDIO' : 'NO AUDIO', active: hasAudio),
                          _ForensicPill(icon: Icons.camera_alt_rounded, label: '$photos PHOTOS', active: photos > 0),
                          _ForensicPill(icon: Icons.videocam_rounded, label: '$videos CLIPS', active: videos > 0),
                        ],
                      ),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// TACTICAL UI ATOMS
// ─────────────────────────────────────────────────────────────────────────────

class _RiskBadge extends StatelessWidget {
  final double norm;
  final Color color;
  const _RiskBadge({required this.norm, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 1),
        ],
      ),
      child: Center(
        child: Text('${(norm * 100).toInt()}%',
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13, fontFamily: 'Poppins')),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final bool isResolved = status == 'resolved';
    // Apply the same blue color for active statuses as we did on the home screen
    final Color c = isResolved ? AppColors.safeGreen : (status == 'active' || status == 'collecting' || status == 'uploading' ? const Color(0xFF1976D2) : AppColors.sosRed);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle, boxShadow: [BoxShadow(color: c, blurRadius: 4)]),
          ),
          const SizedBox(width: 6),
          Text(status.toUpperCase(),
              style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

class _ForensicPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  const _ForensicPill({required this.icon, required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? color.withValues(alpha: 0.2) : Colors.transparent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // ✅ FIXED: Constrain width
        children: [
          Icon(icon, size: 14, color: active ? color : Colors.white.withValues(alpha: 0.3)),
          const SizedBox(width: 4), // Saved a little space here too
          Flexible( // ✅ FIXED: Wrap text in Flexible to prevent inner overflow
            child: Text(
              label,
              style: TextStyle(color: active ? color : Colors.white.withValues(alpha: 0.3), fontSize: 10, fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyArchiveState extends StatelessWidget {
  const _EmptyArchiveState();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.02), shape: BoxShape.circle),
          child: Icon(Icons.shield_outlined, size: 60, color: Colors.white.withValues(alpha: 0.1)),
        ),
        const SizedBox(height: 24),
        const Text('ARCHIVE EMPTY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16)),
        const SizedBox(height: 8),
        Text('No incident records detected in the secure vault.', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
      ],
    ),
  );
}