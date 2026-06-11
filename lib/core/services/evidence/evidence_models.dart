// lib/core/services/evidence/evidence_models.dart
// ─────────────────────────────────────────────────────────────────────────────
// SAFEHER — EVIDENCE MODELS v8.0 (COMPLETE FOUNDATION)
// ─────────────────────────────────────────────────────────────────────────────
// ✅ All fields used by Orchestrator, PDF Service, SOS Service, Repository
// ✅ EvidenceBundle.copyWith() — null-safe spread operators on all lists
// ✅ screamProbability + audioAnalyzedForScream added (SOS resolve fix)
// ✅ evidenceFolderName added (Repository path resolution fix)
// ✅ Full toMap() / fromMap() on every model for Firestore + SharedPreferences
// ✅ EvidenceType enum matches upload queue priority order
// ✅ GpsPoint + SensorSnapshot serialization complete
// ✅ AlertSentRecord moved here (single source of truth for PDF + dispatch)
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';

// ═══════════════════════════════════════════════════════════════════════════
// ENUMS
// ═══════════════════════════════════════════════════════════════════════════

/// Priority order matters — upload queue sorts by index (lower = higher priority)
enum EvidenceType {
  audio,        // 0 — smallest, upload first for quick court access
  photo,        // 1 — medium size
  video,        // 2 — largest
  sensorLog,    // 3 — JSON, small
  gpsTrail,     // 4 — JSON, small
  pdfReport,    // 5 — generated after resolve
  misc,         // 6 — anything else
}

enum EvidenceSessionStatus {
  idle,
  starting,
  collecting,
  uploading,
  complete,
  failed,
}

enum EvidenceUploadStatus {
  pending,
  uploading,
  complete,
  failed,
  cancelled,
}

// ═══════════════════════════════════════════════════════════════════════════
// GPS POINT
// ═══════════════════════════════════════════════════════════════════════════

class GpsPoint {
  final double   lat;
  final double   lng;
  final double   accuracy;
  final double   speed;       // km/h
  final double   heading;     // degrees
  final double   altitude;    // metres
  final DateTime timestamp;
  final double?  dangerScore; // ML danger score at this moment

  const GpsPoint({
    required this.lat,
    required this.lng,
    required this.accuracy,
    required this.speed,
    required this.heading,
    required this.altitude,
    required this.timestamp,
    this.dangerScore,
  });

  /// Distance in metres between two GPS points (Haversine formula)
  static double distanceMetres(GpsPoint a, GpsPoint b) {
    const r = 6371000.0;
    final p = pi / 180;
    final dLat = (b.lat - a.lat) * p;
    final dLng = (b.lng - a.lng) * p;
    final h = 0.5 -
        cos(dLat) / 2 +
        cos(a.lat * p) * cos(b.lat * p) * (1 - cos(dLng)) / 2;
    return 2 * r * asin(sqrt(h));
  }

  Map<String, dynamic> toMap() => {
    'lat':         lat,
    'lng':         lng,
    'accuracy':    accuracy,
    'speed':       speed,
    'heading':     heading,
    'altitude':    altitude,
    'timestamp':   timestamp.millisecondsSinceEpoch,
    'dangerScore': dangerScore,
  };

  factory GpsPoint.fromMap(Map<String, dynamic> m) => GpsPoint(
    lat:         (m['lat']         as num).toDouble(),
    lng:         (m['lng']         as num).toDouble(),
    accuracy:    (m['accuracy']    as num?)?.toDouble() ?? 0.0,
    speed:       (m['speed']       as num?)?.toDouble() ?? 0.0,
    heading:     (m['heading']     as num?)?.toDouble() ?? 0.0,
    altitude:    (m['altitude']    as num?)?.toDouble() ?? 0.0,
    timestamp:   _parseTimestamp(m['timestamp']),
    dangerScore: (m['dangerScore'] as num?)?.toDouble(),
  );

  static DateTime _parseTimestamp(dynamic v) {
    if (v is int) {
      return v > 1000000000000
          ? DateTime.fromMillisecondsSinceEpoch(v)
          : DateTime.fromMillisecondsSinceEpoch(v * 1000);
    }
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SENSOR SNAPSHOT
// ═══════════════════════════════════════════════════════════════════════════

class SensorSnapshot {
  final double   accelX;
  final double   accelY;
  final double   accelZ;
  final double   gyroX;
  final double   gyroY;
  final double   gyroZ;
  final double   magnitude;           // √(x²+y²+z²) of accelerometer
  final bool     isSignificantMovement; // magnitude > 15 m/s²
  final DateTime timestamp;

  const SensorSnapshot({
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.magnitude,
    required this.isSignificantMovement,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'ax':   accelX,
    'ay':   accelY,
    'az':   accelZ,
    'gx':   gyroX,
    'gy':   gyroY,
    'gz':   gyroZ,
    'mag':  magnitude,
    'sig':  isSignificantMovement,
    'ts':   timestamp.millisecondsSinceEpoch,
  };

  factory SensorSnapshot.fromMap(Map<String, dynamic> m) => SensorSnapshot(
    accelX:               (m['ax']  as num?)?.toDouble() ?? 0.0,
    accelY:               (m['ay']  as num?)?.toDouble() ?? 0.0,
    accelZ:               (m['az']  as num?)?.toDouble() ?? 0.0,
    gyroX:                (m['gx']  as num?)?.toDouble() ?? 0.0,
    gyroY:                (m['gy']  as num?)?.toDouble() ?? 0.0,
    gyroZ:                (m['gz']  as num?)?.toDouble() ?? 0.0,
    magnitude:            (m['mag'] as num?)?.toDouble() ?? 0.0,
    isSignificantMovement: m['sig'] as bool? ?? false,
    timestamp:            DateTime.fromMillisecondsSinceEpoch(m['ts'] as int? ?? 0),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// ALERT SENT RECORD  (single source of truth — used by PDF + dispatch)
// ═══════════════════════════════════════════════════════════════════════════

class AlertSentRecord {
  final String   contactName;
  final String   phone;
  final DateTime sentAt;
  final bool     whatsapp;
  final bool     sms;
  final bool     fcm;
  final bool     called;

  const AlertSentRecord({
    required this.contactName,
    required this.phone,
    required this.sentAt,
    required this.whatsapp,
    required this.sms,
    required this.fcm,
    required this.called,
  });

  Map<String, dynamic> toMap() => {
    'contactName': contactName,
    'phone':       phone,
    'sentAt':      sentAt.millisecondsSinceEpoch,
    'whatsapp':    whatsapp,
    'sms':         sms,
    'fcm':         fcm,
    'called':      called,
  };

  factory AlertSentRecord.fromMap(Map<String, dynamic> m) => AlertSentRecord(
    contactName: m['contactName'] as String? ?? '',
    phone:       m['phone']       as String? ?? '',
    sentAt:      DateTime.fromMillisecondsSinceEpoch(m['sentAt'] as int? ?? 0),
    whatsapp:    m['whatsapp']    as bool? ?? false,
    sms:         m['sms']         as bool? ?? false,
    fcm:         m['fcm']         as bool? ?? false,
    called:      m['called']      as bool? ?? false,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// EVIDENCE BUNDLE — Master evidence object for one SOS incident
// ═══════════════════════════════════════════════════════════════════════════

class EvidenceBundle {
  // ── Identity ──────────────────────────────────────────────────────────
  final String   incidentId;
  final String   uid;
  final DateTime collectedAt;

  // ── Context ───────────────────────────────────────────────────────────
  final double  dangerScore;
  final String  triggerType;
  final String? address;
  final bool    isNightTime;

  // ── Storage folder (date-based: YYYYMMDD_HHmmss_shortId) ─────────────
  // Written by orchestrator to Firestore so repository can find evidence
  final String? evidenceFolderName;

  // ── Audio ─────────────────────────────────────────────────────────────
  final String?   audioUrl;             // Firebase Storage download URL
  final Duration? audioDuration;
  final double?   audioPeakAmplitude;
  final bool      audioAnalyzedForScream; // ✅ FIX: was missing
  final double?   screamProbability;      // ✅ FIX: was missing

  // ── Photos ────────────────────────────────────────────────────────────
  final List<String>  photoUrls;        // Firebase Storage download URLs
  final List<String>  photoLocalPaths;  // Local device paths (pre-upload)
  final int           frontPhotoCount;
  final int           backPhotoCount;

  // ── Videos ────────────────────────────────────────────────────────────
  final List<String>  videoUrls;        // Firebase Storage download URLs
  final List<String>  videoLocalPaths;  // Local device paths (pre-upload)
  final int           videoClipCount;
  final Duration?     totalVideoDuration;

  // ── Sensors ───────────────────────────────────────────────────────────
  final bool   phoneFallen;    // accelerometer spike > 35 m/s²
  final bool   phoneInPocket;  // proximity sensor covered
  final String? sensorLogUrl;  // Firebase Storage URL for sensor JSON

  // ── GPS ───────────────────────────────────────────────────────────────
  final String? gpsTrailFirestorePath; // Firestore path to breadcrumbs sub-collection

  const EvidenceBundle({
    required this.incidentId,
    required this.uid,
    required this.collectedAt,
    required this.dangerScore,
    required this.triggerType,
    this.address,
    required this.isNightTime,
    this.evidenceFolderName,
    // Audio
    this.audioUrl,
    this.audioDuration,
    this.audioPeakAmplitude,
    this.audioAnalyzedForScream = false,
    this.screamProbability,
    // Photos
    this.photoUrls          = const [],
    this.photoLocalPaths    = const [],
    this.frontPhotoCount    = 0,
    this.backPhotoCount     = 0,
    // Videos
    this.videoUrls          = const [],
    this.videoLocalPaths    = const [],
    this.videoClipCount     = 0,
    this.totalVideoDuration,
    // Sensors
    this.phoneFallen        = false,
    this.phoneInPocket      = false,
    this.sensorLogUrl,
    // GPS
    this.gpsTrailFirestorePath,
  });

  // ── Total piece count ─────────────────────────────────────────────────
  int get totalPieces =>
      (audioUrl != null ? 1 : 0) +
          photoUrls.length +
          videoUrls.length +
          (sensorLogUrl != null ? 1 : 0);

  // ── CopyWith — ✅ FIX: null-safe spreads on all lists ─────────────────
  EvidenceBundle copyWith({
    String?   incidentId,
    String?   uid,
    DateTime? collectedAt,
    double?   dangerScore,
    String?   triggerType,
    String?   address,
    bool?     isNightTime,
    String?   evidenceFolderName,
    // Audio
    String?   audioUrl,
    Duration? audioDuration,
    double?   audioPeakAmplitude,
    bool?     audioAnalyzedForScream,
    double?   screamProbability,
    // Photos
    List<String>? photoUrls,
    List<String>? photoLocalPaths,
    int?          frontPhotoCount,
    int?          backPhotoCount,
    // Videos
    List<String>? videoUrls,
    List<String>? videoLocalPaths,
    int?          videoClipCount,
    Duration?     totalVideoDuration,
    // Sensors
    bool?    phoneFallen,
    bool?    phoneInPocket,
    String?  sensorLogUrl,
    // GPS
    String?  gpsTrailFirestorePath,
  }) {
    return EvidenceBundle(
      incidentId:              incidentId              ?? this.incidentId,
      uid:                     uid                     ?? this.uid,
      collectedAt:             collectedAt             ?? this.collectedAt,
      dangerScore:             dangerScore             ?? this.dangerScore,
      triggerType:             triggerType             ?? this.triggerType,
      address:                 address                 ?? this.address,
      isNightTime:             isNightTime             ?? this.isNightTime,
      evidenceFolderName:      evidenceFolderName      ?? this.evidenceFolderName,
      // Audio
      audioUrl:                audioUrl                ?? this.audioUrl,
      audioDuration:           audioDuration           ?? this.audioDuration,
      audioPeakAmplitude:      audioPeakAmplitude      ?? this.audioPeakAmplitude,
      audioAnalyzedForScream:  audioAnalyzedForScream  ?? this.audioAnalyzedForScream,
      screamProbability:       screamProbability       ?? this.screamProbability,
      // Photos — ✅ null-safe spread
      photoUrls:      photoUrls      ?? List<String>.from(this.photoUrls),
      photoLocalPaths: photoLocalPaths ?? List<String>.from(this.photoLocalPaths),
      frontPhotoCount: frontPhotoCount ?? this.frontPhotoCount,
      backPhotoCount:  backPhotoCount  ?? this.backPhotoCount,
      // Videos — ✅ null-safe spread
      videoUrls:         videoUrls         ?? List<String>.from(this.videoUrls),
      videoLocalPaths:   videoLocalPaths   ?? List<String>.from(this.videoLocalPaths),
      videoClipCount:    videoClipCount    ?? this.videoClipCount,
      totalVideoDuration: totalVideoDuration ?? this.totalVideoDuration,
      // Sensors
      phoneFallen:  phoneFallen  ?? this.phoneFallen,
      phoneInPocket: phoneInPocket ?? this.phoneInPocket,
      sensorLogUrl: sensorLogUrl  ?? this.sensorLogUrl,
      // GPS
      gpsTrailFirestorePath: gpsTrailFirestorePath ?? this.gpsTrailFirestorePath,
    );
  }

  // ── Firestore serialization ───────────────────────────────────────────
  Map<String, dynamic> toFirestoreMap() => {
    'incidentId':             incidentId,
    'uid':                    uid,
    'collectedAt':            collectedAt.millisecondsSinceEpoch,
    'dangerScore':            dangerScore,
    'triggerType':            triggerType,
    'address':                address,
    'isNightTime':            isNightTime,
    'evidenceFolderName':     evidenceFolderName,
    // Audio — write both field names for legacy readers
    'audioEvidenceUrl':       audioUrl,
    'audioUrl':               audioUrl,
    'audioDurationSec':       audioDuration?.inSeconds,
    'audioPeakAmplitude':     audioPeakAmplitude,
    'audioAnalyzedForScream': audioAnalyzedForScream,
    'screamProbability':      screamProbability,
    // Photos — write both field names (PDF reads photoBurstUrls, UI reads photoUrls)
    'photoUrls':              photoUrls,
    'photoBurstUrls':         photoUrls,
    'photoLocalPaths':        photoLocalPaths,
    'frontPhotoCount':        frontPhotoCount,
    'backPhotoCount':         backPhotoCount,
    // Videos
    'videoUrls':              videoUrls,
    'videoLocalPaths':        videoLocalPaths,
    'videoClipCount':         videoClipCount,
    'totalVideoDurationSec':  totalVideoDuration?.inSeconds,
    // Sensors
    'phoneFallen':            phoneFallen,
    'phoneInPocket':          phoneInPocket,
    'sensorLogUrl':           sensorLogUrl,
    // GPS
    'gpsTrailFirestorePath':  gpsTrailFirestorePath,
    // Summary
    'totalEvidence':          totalPieces,
  };

  /// Build from Firestore document data
  factory EvidenceBundle.fromFirestoreMap(
      String incidentId,
      String uid,
      Map<String, dynamic> data,
      ) {
    final photoUrlsRaw = <String>[];
    // Read from both field names — whichever has data
    final burstUrls = data['photoBurstUrls'] as List?;
    final photoUrls = data['photoUrls']      as List?;
    if (burstUrls != null) {
      photoUrlsRaw.addAll(burstUrls.map((e) => e.toString()));
    } else if (photoUrls != null) {
      photoUrlsRaw.addAll(photoUrls.map((e) => e.toString()));
    }

    final videoUrlsRaw = <String>[];
    final videoUrls = data['videoUrls'] as List?;
    if (videoUrls != null) {
      videoUrlsRaw.addAll(videoUrls.map((e) => e.toString()));
    }

    return EvidenceBundle(
      incidentId:             incidentId,
      uid:                    uid,
      collectedAt:            _parseDate(data['collectedAt'] ?? data['createdAt']),
      dangerScore:            (data['dangerScore'] as num?)?.toDouble()    ?? 0.0,
      triggerType:             data['triggerType'] as String?              ?? 'manual',
      address:                 data['address']     as String?,
      isNightTime:             data['isNightTime'] as bool?                ?? false,
      evidenceFolderName:      data['evidenceFolderName'] as String?,
      // Audio — read both field names
      audioUrl:                data['audioEvidenceUrl'] as String?
          ?? data['audioUrl']         as String?,
      audioDuration:           data['audioDurationSec'] != null
          ? Duration(seconds: (data['audioDurationSec'] as num).toInt())
          : null,
      audioPeakAmplitude:     (data['audioPeakAmplitude']     as num?)?.toDouble(),
      audioAnalyzedForScream:  data['audioAnalyzedForScream'] as bool? ?? false,
      screamProbability:      (data['screamProbability']       as num?)?.toDouble(),
      photoUrls:               photoUrlsRaw,
      photoLocalPaths:        (data['photoLocalPaths'] as List?)
          ?.map((e) => e.toString()).toList() ?? [],
      frontPhotoCount:        (data['frontPhotoCount'] as num?)?.toInt() ?? 0,
      backPhotoCount:         (data['backPhotoCount']  as num?)?.toInt() ?? 0,
      videoUrls:               videoUrlsRaw,
      videoLocalPaths:        (data['videoLocalPaths'] as List?)
          ?.map((e) => e.toString()).toList() ?? [],
      videoClipCount:         (data['videoClipCount']          as num?)?.toInt() ?? 0,
      totalVideoDuration:      data['totalVideoDurationSec'] != null
          ? Duration(seconds: (data['totalVideoDurationSec'] as num).toInt())
          : null,
      phoneFallen:             data['phoneFallen']  as bool? ?? false,
      phoneInPocket:           data['phoneInPocket'] as bool? ?? false,
      sensorLogUrl:            data['sensorLogUrl'] as String?,
      gpsTrailFirestorePath:   data['gpsTrailFirestorePath'] as String?,
    );
  }

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is int) {
      return v > 1000000000000
          ? DateTime.fromMillisecondsSinceEpoch(v)
          : DateTime.fromMillisecondsSinceEpoch(v * 1000);
    }
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    // Firestore Timestamp
    try {
      return (v as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.now();
    }
  }

  @override
  String toString() =>
      'EvidenceBundle('
          'incident=$incidentId, '
          'audio=${audioUrl != null}, '
          'photos=${photoUrls.length}, '
          'videos=${videoUrls.length}, '
          'total=$totalPieces'
          ')';
}

// ═══════════════════════════════════════════════════════════════════════════
// EVIDENCE SESSION RESULT  (returned by EvidenceService.collectAll())
// ═══════════════════════════════════════════════════════════════════════════

class EvidenceSessionResult {
  final String             incidentId;
  final DateTime           collectedAt;
  final EvidenceBundle?    bundle;
  final bool               success;
  final String?            errorMessage;

  const EvidenceSessionResult({
    required this.incidentId,
    required this.collectedAt,
    this.bundle,
    this.success     = true,
    this.errorMessage,
  });

  factory EvidenceSessionResult.failure({
    required String incidentId,
    required String error,
  }) => EvidenceSessionResult(
    incidentId:   incidentId,
    collectedAt:  DateTime.now(),
    success:      false,
    errorMessage: error,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// STORAGE PATH BUILDER — single source of truth for all storage paths
// ═══════════════════════════════════════════════════════════════════════════

class EvidenceStoragePaths {
  /// Date-based folder:  YYYYMMDD_HHmmss_shortIncidentId
  /// Example:            20260427_143022_ab12cd34
  static String buildFolderName(DateTime dt, String incidentId) {
    final y  = dt.year .toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d  = dt.day  .toString().padLeft(2, '0');
    final h  = dt.hour .toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    final s  = dt.second.toString().padLeft(2, '0');
    final id = incidentId.length >= 8
        ? incidentId.substring(0, 8)
        : incidentId;
    return '${y}${mo}${d}_${h}${mi}${s}_$id';
  }

  /// evidence/{uid}/{folder}/audio/{fileName}
  static String audio(String uid, String folder, String fileName) =>
      'evidence/$uid/$folder/audio/$fileName';

  /// evidence/{uid}/{folder}/photos/{fileName}
  static String photo(String uid, String folder, String fileName) =>
      'evidence/$uid/$folder/photos/$fileName';

  /// evidence/{uid}/{folder}/video/{fileName}
  static String video(String uid, String folder, String fileName) =>
      'evidence/$uid/$folder/video/$fileName';

  /// evidence/{uid}/{folder}/logs/{fileName}
  static String log(String uid, String folder, String fileName) =>
      'evidence/$uid/$folder/logs/$fileName';

  /// reports/{uid}/{incidentId}/{fileName}
  static String report(String uid, String incidentId, String fileName) =>
      'reports/$uid/$incidentId/$fileName';
}

// ═══════════════════════════════════════════════════════════════════════════
// FIRESTORE FIELD CONSTANTS — prevent typos across all services
// ═══════════════════════════════════════════════════════════════════════════

class EvidenceFields {
  // Core
  static const uid           = 'uid';
  static const incidentId    = 'incidentId';
  static const triggeredAt   = 'triggeredAt';
  static const createdAt     = 'createdAt';
  static const resolvedAt    = 'resolvedAt';
  static const status        = 'status';
  static const triggerType   = 'triggerType';
  static const dangerScore   = 'dangerScore';
  static const isSilent      = 'isSilent';
  static const lat           = 'lat';
  static const lng           = 'lng';
  static const address       = 'address';
  static const isNightTime   = 'isNightTime';

  // Evidence folder
  static const evidenceFolderName = 'evidenceFolderName';
  static const evidenceStatus     = 'evidenceStatus';
  static const totalEvidence      = 'totalEvidence';

  // Audio — dual field names for reader compatibility
  static const audioEvidenceUrl       = 'audioEvidenceUrl';
  static const audioUrl               = 'audioUrl';
  static const audioDurationSec       = 'audioDurationSec';
  static const audioPeakAmplitude     = 'audioPeakAmplitude';
  static const audioAnalyzedForScream = 'audioAnalyzedForScream';
  static const screamProbability      = 'screamProbability';

  // Photos — dual field names for reader compatibility
  static const photoUrls       = 'photoUrls';
  static const photoBurstUrls  = 'photoBurstUrls';
  static const frontPhotoCount = 'frontPhotoCount';
  static const backPhotoCount  = 'backPhotoCount';

  // Videos
  static const videoUrls            = 'videoUrls';
  static const videoClipCount       = 'videoClipCount';
  static const totalVideoDurationSec = 'totalVideoDurationSec';

  // Sensors
  static const phoneFallen   = 'phoneFallen';
  static const phoneInPocket = 'phoneInPocket';
  static const sensorLogUrl  = 'sensorLogUrl';

  // GPS
  static const gpsPointCount         = 'gpsPointCount';
  static const gpsTrailFirestorePath = 'gpsTrailFirestorePath';

  // PDF
  static const pdfReportUrl   = 'pdfReportUrl';
  static const pdfGeneratedAt = 'pdfGeneratedAt';
  static const pdfStoragePath = 'pdfStoragePath';

  // Sync
  static const updatedAt       = 'updatedAt';
  static const lastForensicSync = 'lastForensicSync';
}

// ═══════════════════════════════════════════════════════════════════════════
// EVIDENCE STATUS CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════

class EvidenceStatus {
  static const securing  = 'securing';   // Collection in progress
  static const collected = 'collected';  // All pipelines finished
  static const uploading = 'uploading';  // Upload queue processing
  static const sealed    = 'sealed';     // All uploads complete, PDF generated
  static const deleted   = 'deleted';    // GDPR wipe
}

class IncidentStatus {
  static const active     = 'active';
  static const resolved   = 'resolved';
  static const falseAlarm = 'false_alarm';
  static const collecting = 'collecting';
  static const uploading  = 'uploading';
}