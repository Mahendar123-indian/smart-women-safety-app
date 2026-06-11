// lib/core/services/places_service.dart
// Google Places API — Auto-fetch & cache real safe places into Firestore

import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_service.dart';

class PlacesService {
  PlacesService._();
  static final PlacesService instance = PlacesService._();

  final _firestore = FirebaseFirestore.instance;

  // ── Replace with your key — same key as AndroidManifest ────
  // Enable "Places API" in Google Cloud Console → APIs & Services
  static const String _apiKey = 'AIzaSyDB1FkgbJbGI-ttCUlVdENdy_hoXGdjU7Q';

  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json';
  static const String _detailsUrl =
      'https://maps.googleapis.com/maps/api/place/details/json';

  static const String _cachePrefix = 'safe_places_';
  static const Duration _cacheDuration = Duration(hours: 24);
  static const int _radiusMeters = 3000;

  // Google place types mapped to our app types
  static const Map<String, String> _typeMap = {
    'police':   'police',
    'hospital': 'hospital',
    'shelter':  'local_government_office',
  };

  // ─── PUBLIC: fetch real places, auto-cache ───────────────────
  Future<List<SafePlace>> fetchRealPlaces({
    required double lat,
    required double lng,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final local = await _fromLocalCache(lat, lng);
      if (local != null) return local;
      final remote = await _fromFirestore(lat, lng);
      if (remote.isNotEmpty) {
        await _toLocalCache(lat, lng, remote);
        return remote;
      }
    }
    final fresh = await _fromGooglePlaces(lat, lng);
    if (fresh.isNotEmpty) {
      await _toFirestore(fresh, lat, lng);
      await _toLocalCache(lat, lng, fresh);
    }
    return fresh;
  }

  // ─── GOOGLE PLACES NEARBY SEARCH ────────────────────────────
  Future<List<SafePlace>> _fromGooglePlaces(double lat, double lng) async {
    final all = <SafePlace>[];

    for (final entry in _typeMap.entries) {
      try {
        final uri = Uri.parse(_baseUrl).replace(queryParameters: {
          'location': '$lat,$lng',
          'radius': '$_radiusMeters',
          'type': entry.value,
          'key': _apiKey,
          'language': 'en',
        });

        final res = await http.get(uri).timeout(const Duration(seconds: 10));
        if (res.statusCode != 200) continue;

        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final status = data['status'] as String? ?? '';
        if (status != 'OK' && status != 'ZERO_RESULTS') continue;

        final results = (data['results'] as List?) ?? [];

        for (final r in results.take(5)) {
          final result = r as Map<String, dynamic>;
          final geo = result['geometry']?['location'] as Map<String, dynamic>?;
          if (geo == null) continue;

          final pLat = (geo['lat'] as num).toDouble();
          final pLng = (geo['lng'] as num).toDouble();
          final placeId = result['place_id'] as String? ?? '${entry.key}_${all.length}';

          // Fetch phone number from Place Details
          final phone = await _fetchPhone(placeId) ?? _defaultPhone(entry.key);

          all.add(SafePlace(
            id: placeId,
            name: result['name'] as String? ?? _defaultName(entry.key),
            type: entry.key,
            lat: pLat,
            lng: pLng,
            distanceKm: _dist(lat, lng, pLat, pLng),
            address: result['vicinity'] as String? ?? '',
            phone: phone,
          ));
        }
      } catch (_) {
        continue;
      }
    }

    all.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return all;
  }

  // ─── GET PHONE FROM PLACE DETAILS ───────────────────────────
  Future<String?> _fetchPhone(String placeId) async {
    try {
      final uri = Uri.parse(_detailsUrl).replace(queryParameters: {
        'place_id': placeId,
        'fields': 'formatted_phone_number',
        'key': _apiKey,
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data['result'] as Map?)?.entries
          .firstWhere((e) => e.key == 'formatted_phone_number',
          orElse: () => const MapEntry('', null))
          .value as String?;
    } catch (_) {
      return null;
    }
  }

  // ─── FIRESTORE CACHE ─────────────────────────────────────────
  Future<List<SafePlace>> _fromFirestore(double lat, double lng) async {
    try {
      final gLat = (lat * 100).round() / 100;
      final gLng = (lng * 100).round() / 100;
      final cutoff = Timestamp.fromDate(DateTime.now().subtract(_cacheDuration));

      final snap = await _firestore
          .collection('safePlaces')
          .where('gridLat', isEqualTo: gLat)
          .where('gridLng', isEqualTo: gLng)
          .where('cachedAt', isGreaterThan: cutoff)
          .limit(30)
          .get();

      if (snap.docs.isEmpty) return [];

      return snap.docs.map((doc) {
        final d = doc.data();
        return SafePlace(
          id: doc.id,
          name: d['name'] as String,
          type: d['type'] as String,
          lat: (d['lat'] as num).toDouble(),
          lng: (d['lng'] as num).toDouble(),
          distanceKm: _dist(lat, lng,
              (d['lat'] as num).toDouble(), (d['lng'] as num).toDouble()),
          address: d['address'] as String? ?? '',
          phone: d['phone'] as String?,
        );
      }).toList()
        ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    } catch (_) {
      return [];
    }
  }

  Future<void> _toFirestore(List<SafePlace> places, double lat, double lng) async {
    final gLat = (lat * 100).round() / 100;
    final gLng = (lng * 100).round() / 100;
    final batch = _firestore.batch();
    for (final p in places) {
      final ref = _firestore.collection('safePlaces').doc(p.id);
      batch.set(ref, {
        'name': p.name, 'type': p.type,
        'lat': p.lat, 'lng': p.lng,
        'address': p.address, 'phone': p.phone,
        'gridLat': gLat, 'gridLng': gLng,
        'cachedAt': FieldValue.serverTimestamp(),
        'source': 'google_places_api',
      }, SetOptions(merge: true));
    }
    try { await batch.commit(); } catch (_) {}
  }

  // ─── LOCAL CACHE (SharedPreferences) ────────────────────────
  Future<List<SafePlace>?> _fromLocalCache(double lat, double lng) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _cachePrefix + _gridKey(lat, lng);
      final ts = prefs.getInt('${key}_ts');
      if (ts == null) return null;
      if (DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(ts)) > _cacheDuration) {
        return null;
      }
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final list = jsonDecode(raw) as List;
      return list.map((e) {
        final m = e as Map<String, dynamic>;
        return SafePlace(
          id: m['id'] as String,
          name: m['name'] as String,
          type: m['type'] as String,
          lat: (m['lat'] as num).toDouble(),
          lng: (m['lng'] as num).toDouble(),
          distanceKm: _dist(lat, lng,
              (m['lat'] as num).toDouble(), (m['lng'] as num).toDouble()),
          address: m['address'] as String? ?? '',
          phone: m['phone'] as String?,
        );
      }).toList()
        ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    } catch (_) {
      return null;
    }
  }

  Future<void> _toLocalCache(
      double lat, double lng, List<SafePlace> places) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _cachePrefix + _gridKey(lat, lng);
      await prefs.setString(key, jsonEncode(places.map((p) => {
        'id': p.id, 'name': p.name, 'type': p.type,
        'lat': p.lat, 'lng': p.lng,
        'address': p.address, 'phone': p.phone,
      }).toList()));
      await prefs.setInt('${key}_ts', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  // ─── HELPERS ─────────────────────────────────────────────────
  String _gridKey(double lat, double lng) =>
      '${(lat * 100).round()}_${(lng * 100).round()}';

  double _dist(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return 2 * R * asin(sqrt(a));
  }

  double _rad(double d) => d * pi / 180;

  String _defaultName(String type) {
    switch (type) {
      case 'police':   return 'Police Station';
      case 'hospital': return 'Hospital';
      default:         return 'Women Safety Shelter';
    }
  }

  String _defaultPhone(String type) {
    switch (type) {
      case 'police':   return '100';
      case 'hospital': return '108';
      default:         return '1091';
    }
  }
}