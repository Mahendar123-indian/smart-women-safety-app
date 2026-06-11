// lib/core/services/location/police_station_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// INDUSTRIAL SENTINEL — POLICE STATION LOCATOR v5.0 (2026 PRODUCTION)
// ─────────────────────────────────────────────────────────────────────────────
// ✅ [FIXED] Expected an identifier: Escaped the \$ sign in the debugPrint string.
// ✅ [OPTIMIZATION] Spatial-Temporal Caching: Prevents Google API billing spam.
// ✅ [PERFORMANCE] Native Haversine Sorting: Guarantees strict nearest-first order.
// ✅ [RESILIENCE] Dead-Drop Guards: Gracefully handles offline/subway scenarios.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ─── Data Model ──────────────────────────────────────────────────────────────

class PoliceStation {
  final String placeId;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final double distanceKm;
  final bool isOpenNow;

  const PoliceStation({
    required this.placeId,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.distanceKm,
    this.isOpenNow = true,
  });

  factory PoliceStation.fromPlacesApi(Map<String, dynamic> map, double userLat, double userLng) {
    final loc = map['geometry']?['location'] ?? {};
    final statLat = (loc['lat'] as num?)?.toDouble() ?? 0.0;
    final statLng = (loc['lng'] as num?)?.toDouble() ?? 0.0;

    return PoliceStation(
      placeId: map['place_id'] as String? ?? '',
      name: map['name'] as String? ?? 'Police Station',
      address: map['vicinity'] as String? ?? 'Address unavailable',
      lat: statLat,
      lng: statLng,
      distanceKm: _PoliceMath.haversineDistance(userLat, userLng, statLat, statLng),
      isOpenNow: map['opening_hours']?['open_now'] as bool? ?? true,
    );
  }
}

// ─── Service ─────────────────────────────────────────────────────────────────

class PoliceStationService {
  PoliceStationService._();
  static final PoliceStationService instance = PoliceStationService._();

  // ── Configuration ──
  static const String _apiKey = 'AIzaSyDB1FkgbJbGI-ttCUlVdENdy_hoXGdjU7Q';
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json';
  static const int _searchRadiusMeters = 5000; // 5km search radius
  static const int _timeoutSeconds = 8;

  // ── Smart Cache (To prevent Google API Billing Spam) ──
  List<PoliceStation> _cachedStations = [];
  DateTime? _lastFetchTime;
  double? _lastFetchLat;
  double? _lastFetchLng;

  // Cache Validity Rules
  static const int _cacheTtlMinutes = 10;
  static const double _cacheRadiusThresholdKm = 0.5; // 500 meters

  // ═══════════════════════════════════════════════════════════════
  // PRIMARY FETCH ENGINE
  // ═══════════════════════════════════════════════════════════════

  /// Fetches nearby police stations.
  /// Utilizes Spatial-Temporal caching to return instantly if the user hasn't moved much.
  Future<List<PoliceStation>> getNearbyStations({
    required double lat,
    required double lng,
    bool forceRefresh = false,
  }) async {
    // 1. Check Cache Validity
    if (!forceRefresh && _isCacheValid(lat, lng)) {
      // ✅ FIXED: Escaped \$0 to prevent Dart syntax identifier error
      debugPrint('🛡️ [POLICE LOCATOR] Returning cached stations (0ms latency, \$0 API cost)');

      // Re-sort the cached list based on the user's *exact* current micro-movement
      _cachedStations.sort((a, b) =>
          _PoliceMath.haversineDistance(lat, lng, a.lat, a.lng)
              .compareTo(_PoliceMath.haversineDistance(lat, lng, b.lat, b.lng))
      );
      return _cachedStations;
    }

    // 2. Build API Request
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'location': '$lat,$lng',
      'radius': '$_searchRadiusMeters',
      'type': 'police',
      'key': _apiKey,
    });

    try {
      debugPrint('📡 [POLICE LOCATOR] Querying Google Places API...');
      final response = await http.get(uri).timeout(const Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List<dynamic>? ?? [];

        // 3. Map, Parse, and Filter
        List<PoliceStation> stations = results
            .map((p) => PoliceStation.fromPlacesApi(p as Map<String, dynamic>, lat, lng))
            .where((s) => s.placeId.isNotEmpty)
            .toList();

        // 4. Strict Proximity Sorting
        stations.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

        // 5. Update Cache
        _cachedStations = stations;
        _lastFetchLat = lat;
        _lastFetchLng = lng;
        _lastFetchTime = DateTime.now();

        return _cachedStations;
      } else {
        debugPrint('❌ [POLICE LOCATOR] API Error: ${response.statusCode}');
        return _cachedStations; // Return stale cache gracefully on 500 errors
      }

    } on SocketException catch (_) {
      debugPrint('🚨 [POLICE LOCATOR] Network completely offline. Returning cached/empty list.');
      return _cachedStations;
    } on TimeoutException catch (_) {
      debugPrint('⚠️ [POLICE LOCATOR] API Timeout. Poor connection.');
      return _cachedStations;
    } catch (e) {
      debugPrint('❌ [POLICE LOCATOR] Unexpected Error: $e');
      return _cachedStations;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // CACHE & UTILS
  // ═══════════════════════════════════════════════════════════════

  /// Determines if we can reuse the last API payload
  bool _isCacheValid(double currentLat, double currentLng) {
    if (_cachedStations.isEmpty || _lastFetchTime == null || _lastFetchLat == null || _lastFetchLng == null) {
      return false;
    }

    // Rule 1: Time Expired? (Data older than 10 minutes)
    final timeDiff = DateTime.now().difference(_lastFetchTime!);
    if (timeDiff.inMinutes >= _cacheTtlMinutes) return false;

    // Rule 2: Spatial Shift? (User moved more than 500 meters)
    final distanceMoved = _PoliceMath.haversineDistance(currentLat, currentLng, _lastFetchLat!, _lastFetchLng!);
    if (distanceMoved > _cacheRadiusThresholdKm) return false;

    return true;
  }

  /// Manually wipe the cache (e.g., on user logout or manual pull-to-refresh)
  void clearCache() {
    _cachedStations.clear();
    _lastFetchTime = null;
    _lastFetchLat = null;
    _lastFetchLng = null;
  }
}

// ─── Hardware Math Utility ───────────────────────────────────────────────────

class _PoliceMath {
  /// Calculates the straight-line distance between two coordinates in Kilometers
  static double haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // Earth radius in kilometers
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);

    final c = 2 * asin(sqrt(a));
    return R * c;
  }

  static double _toRadians(double degree) {
    return degree * pi / 180;
  }
}