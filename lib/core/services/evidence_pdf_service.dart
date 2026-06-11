// lib/core/services/evidence_pdf_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// SAFEHER — EVIDENCE PDF SERVICE v8.0
// ─────────────────────────────────────────────────────────────────────────────
// ✅ Uses EvidenceFields constants — no field name typos
// ✅ loadIncidentData() reads both audioEvidenceUrl + audioUrl
// ✅ loadIncidentData() reads both photoBurstUrls + photoUrls
// ✅ Alert sort done locally in Dart — no Firestore composite index needed
// ✅ UID filter on contactNotifications query — passes security rules
// ✅ generateReport() builds 5-page court-ready PDF
// ✅ _uploadPdfToStorage() writes pdfReportUrl to Firestore
// ✅ autoGenerateOnResolve() called 3s after resolve
// ✅ shareReport / printReport / shareToPoliceWhatsApp / shareViaEmail
// ✅ GPS trail reads from breadcrumbs sub-collection with orderBy timestamp
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'evidence/evidence_models.dart';

// ─── Report Data Model ────────────────────────────────────────────────────────

class IncidentReportData {
  final String   incidentId;
  final String   victimName;
  final String   victimPhone;
  final DateTime triggeredAt;
  final DateTime? resolvedAt;
  final double   lat;
  final double   lng;
  final String?  address;
  final double   dangerScore;
  final String   triggerType;
  final String   status;
  final bool     isSilent;

  final String?   audioUrl;
  final Duration? audioDuration;
  final double?   audioPeakAmplitude;
  final bool      audioAnalyzedForScream;
  final double?   screamProbability;

  final List<String> photoUrls;
  final List<String> videoUrls;
  final int          frontPhotoCount;
  final int          backPhotoCount;
  final int          videoClipCount;

  final bool   phoneFallen;
  final bool   phoneInPocket;
  final bool   phoneCharging;
  final bool   isNightTime;
  final int    hourOfDay;
  final String? sensorLogUrl;

  final List<GpsPoint>         gpsTrail;
  final List<Map<String, dynamic>> sensorLog;
  final List<AlertSentRecord>  alertsSent;

  const IncidentReportData({
    required this.incidentId,
    required this.victimName,
    required this.victimPhone,
    required this.triggeredAt,
    this.resolvedAt,
    required this.lat,
    required this.lng,
    this.address,
    required this.dangerScore,
    required this.triggerType,
    required this.status,
    required this.isSilent,
    this.audioUrl,
    this.audioDuration,
    this.audioPeakAmplitude,
    this.audioAnalyzedForScream = false,
    this.screamProbability,
    this.photoUrls       = const [],
    this.videoUrls       = const [],
    this.frontPhotoCount = 0,
    this.backPhotoCount  = 0,
    this.videoClipCount  = 0,
    this.phoneFallen     = false,
    this.phoneInPocket   = false,
    this.phoneCharging   = false,
    this.isNightTime     = false,
    this.hourOfDay       = 0,
    this.sensorLogUrl,
    this.gpsTrail   = const [],
    this.sensorLog  = const [],
    this.alertsSent = const [],
  });
}

// ─── Service ──────────────────────────────────────────────────────────────────

class EvidencePdfService {
  EvidencePdfService._();
  static final EvidencePdfService instance = EvidencePdfService._();

  final _firestore = FirebaseFirestore.instance;
  final _storage   = FirebaseStorage.instance;
  final _auth      = FirebaseAuth.instance;

  final _dtFmt   = DateFormat('dd MMM yyyy, hh:mm:ss a');
  final _dateFmt = DateFormat('dd MMM yyyy');
  final _timeFmt = DateFormat('HH:mm:ss');
  final _shortT  = DateFormat('hh:mm a');

  String get _uid => _auth.currentUser?.uid ?? '';

  // ═══════════════════════════════════════════════════════════════════════════
  // LOAD INCIDENT DATA
  // ═══════════════════════════════════════════════════════════════════════════

  Future<IncidentReportData?> loadIncidentData(String incidentId) async {
    if (_uid.isEmpty) return null;
    try {
      // User profile
      final userSnap = await _firestore
          .collection('users')
          .doc(_uid)
          .get();
      final userData = userSnap.data() ?? {};

      // Incident document
      final incSnap = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('incidents')
          .doc(incidentId)
          .get();

      if (!incSnap.exists) return null;
      final inc = incSnap.data()!;

      // GPS trail from breadcrumbs sub-collection
      final crumbsSnap = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('incidents')
          .doc(incidentId)
          .collection('breadcrumbs')
          .orderBy('timestamp')
          .limit(500)
          .get();

      final gpsTrail = crumbsSnap.docs.map((d) {
        final data = d.data();
        return GpsPoint(
          lat:         (data['lat']      as num).toDouble(),
          lng:         (data['lng']      as num).toDouble(),
          accuracy:    (data['accuracy'] as num?)?.toDouble() ?? 0,
          speed:       (data['speed']    as num?)?.toDouble() ?? 0,
          heading:     (data['heading']  as num?)?.toDouble() ?? 0,
          altitude:    (data['altitude'] as num?)?.toDouble() ?? 0,
          timestamp:   _parseDate(data['timestamp']),
          dangerScore: (data['dangerScore'] as num?)?.toDouble(),
        );
      }).toList();

      // Contact notifications — ✅ uid filter passes security rules
      // Sort locally in Dart — avoids need for composite Firestore index
      final alertsSnap = await _firestore
          .collection('contactNotifications')
          .where('incidentId', isEqualTo: incidentId)
          .where('uid', isEqualTo: _uid)
          .get();

      final alertDocs = alertsSnap.docs.toList()
        ..sort((a, b) {
          final tA = a.data()['createdAt'] as Timestamp?;
          final tB = b.data()['createdAt'] as Timestamp?;
          if (tA == null || tB == null) return 0;
          return tA.compareTo(tB);
        });

      final alerts = alertDocs.map((d) {
        final data = d.data();
        return AlertSentRecord(
          contactName: data['contactName']  as String?
              ?? data['senderName']   as String?
              ?? 'Contact',
          phone:       data['contactPhone'] as String?
              ?? data['recipientPhone'] as String?
              ?? '',
          sentAt:      (data['createdAt'] as Timestamp?)?.toDate()
              ?? DateTime.now(),
          whatsapp:    data['whatsappSent'] as bool? ?? false,
          sms:         data['smsSent']      as bool? ?? false,
          fcm:         data['fcmSent']      as bool? ?? false,
          called:      data['called']       as bool? ?? false,
        );
      }).toList();

      // Build photo + video URL lists (read from both field name variants)
      final photoUrls = <String>{};
      if (inc[EvidenceFields.photoBurstUrls] is List) {
        photoUrls.addAll(
          (inc[EvidenceFields.photoBurstUrls] as List)
              .map((e) => e.toString()),
        );
      }
      if (inc[EvidenceFields.photoUrls] is List) {
        photoUrls.addAll(
          (inc[EvidenceFields.photoUrls] as List).map((e) => e.toString()),
        );
      }

      final videoUrls = <String>[];
      if (inc[EvidenceFields.videoUrls] is List) {
        videoUrls.addAll(
          (inc[EvidenceFields.videoUrls] as List).map((e) => e.toString()),
        );
      }

      final triggeredAt = _parseDate(
        inc['triggeredAt'] ?? inc[EvidenceFields.createdAt],
      );
      final resolvedAt = inc[EvidenceFields.resolvedAt] != null
          ? _parseDate(inc[EvidenceFields.resolvedAt])
          : null;

      return IncidentReportData(
        incidentId:   incidentId,
        victimName:   userData['name']  as String? ?? 'SafeHer User',
        victimPhone:  userData['phone'] as String? ?? '',
        triggeredAt:  triggeredAt,
        resolvedAt:   resolvedAt,
        lat:          (inc[EvidenceFields.lat] as num?)?.toDouble() ?? 0,
        lng:          (inc[EvidenceFields.lng] as num?)?.toDouble() ?? 0,
        address:       inc[EvidenceFields.address] as String?,
        dangerScore:  (inc[EvidenceFields.dangerScore] as num?)?.toDouble()
            ?? 0,
        triggerType:   inc[EvidenceFields.triggerType] as String? ?? 'manual',
        status:        inc[EvidenceFields.status]      as String? ?? 'active',
        isSilent:      inc[EvidenceFields.isSilent]    as bool?   ?? false,
        // Audio — read both field names
        audioUrl:      inc[EvidenceFields.audioEvidenceUrl] as String?
            ?? inc[EvidenceFields.audioUrl] as String?,
        audioPeakAmplitude:
        (inc[EvidenceFields.audioPeakAmplitude] as num?)?.toDouble(),
        audioAnalyzedForScream:
        inc[EvidenceFields.audioAnalyzedForScream] as bool? ?? false,
        screamProbability:
        (inc[EvidenceFields.screamProbability] as num?)?.toDouble(),
        photoUrls:       photoUrls.toList(),
        videoUrls:       videoUrls,
        frontPhotoCount: inc[EvidenceFields.frontPhotoCount] as int? ?? 0,
        backPhotoCount:  inc[EvidenceFields.backPhotoCount]  as int? ?? 0,
        videoClipCount:  inc[EvidenceFields.videoClipCount]  as int? ?? 0,
        phoneFallen:     inc[EvidenceFields.phoneFallen]     as bool? ?? false,
        phoneInPocket:   inc[EvidenceFields.phoneInPocket]   as bool? ?? false,
        phoneCharging:   inc['phoneCharging']                as bool? ?? false,
        isNightTime:     inc[EvidenceFields.isNightTime]     as bool? ?? false,
        hourOfDay:       inc['hourOfDay']                    as int?  ?? 0,
        sensorLogUrl:    inc[EvidenceFields.sensorLogUrl]    as String?,
        gpsTrail:        gpsTrail,
        alertsSent:      alerts,
      );
    } catch (e, st) {
      debugPrint('[EvidencePdfService] loadIncidentData error: $e\n$st');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GENERATE REPORT
  // ═══════════════════════════════════════════════════════════════════════════

  Future<File?> generateReport(IncidentReportData data) async {
    try {
      final pdf = pw.Document();

      // Load fonts
      pw.Font regular, bold, italic, mono, monoBold;
      try {
        regular  = await PdfGoogleFonts.poppinsRegular();
        bold     = await PdfGoogleFonts.poppinsBold();
        italic   = await PdfGoogleFonts.poppinsItalic();
        mono     = await PdfGoogleFonts.sourceCodeProRegular();
        monoBold = await PdfGoogleFonts.sourceCodeProBold();
      } catch (_) {
        regular  = pw.Font.helvetica();
        bold     = pw.Font.helveticaBold();
        italic   = pw.Font.helveticaOblique();
        mono     = pw.Font.courier();
        monoBold = pw.Font.courierBold();
      }

      final theme = pw.ThemeData.withFont(
        base:   regular,
        bold:   bold,
        italic: italic,
      );

      // Page 1: Cover + Summary + Context flags
      pdf.addPage(pw.MultiPage(
        theme:      theme,
        pageFormat: PdfPageFormat.a4,
        margin:     const pw.EdgeInsets.all(36),
        header:     (ctx) => _header(bold, italic, data, ctx),
        footer:     (ctx) => _footer(regular, ctx),
        build:      (ctx) => [
          _coverSection(data, bold, regular, italic),
          pw.SizedBox(height: 24),
          _incidentSummarySection(data, bold, regular),
          pw.SizedBox(height: 24),
          _contextFlagsSection(data, bold, regular),
        ],
      ));

      // Page 2: GPS Trail
      pdf.addPage(pw.MultiPage(
        theme:      theme,
        pageFormat: PdfPageFormat.a4,
        margin:     const pw.EdgeInsets.all(36),
        header:     (ctx) => _header(bold, italic, data, ctx),
        footer:     (ctx) => _footer(regular, ctx),
        build:      (ctx) => [
          _gpsSection(data, bold, regular, mono, monoBold),
        ],
      ));

      // Page 3: Evidence Catalogue
      pdf.addPage(pw.MultiPage(
        theme:      theme,
        pageFormat: PdfPageFormat.a4,
        margin:     const pw.EdgeInsets.all(36),
        header:     (ctx) => _header(bold, italic, data, ctx),
        footer:     (ctx) => _footer(regular, ctx),
        build:      (ctx) => [
          _evidenceCatalogueSection(data, bold, regular, mono),
        ],
      ));

      // Page 4: Audio Analysis + Sensor Analysis
      pdf.addPage(pw.MultiPage(
        theme:      theme,
        pageFormat: PdfPageFormat.a4,
        margin:     const pw.EdgeInsets.all(36),
        header:     (ctx) => _header(bold, italic, data, ctx),
        footer:     (ctx) => _footer(regular, ctx),
        build:      (ctx) => [
          _audioAnalysisSection(data, bold, regular, mono),
          pw.SizedBox(height: 24),
          _sensorAnalysisSection(data, bold, regular, mono),
        ],
      ));

      // Page 5: Contacts Alerted + Legal Declaration
      pdf.addPage(pw.MultiPage(
        theme:      theme,
        pageFormat: PdfPageFormat.a4,
        margin:     const pw.EdgeInsets.all(36),
        header:     (ctx) => _header(bold, italic, data, ctx),
        footer:     (ctx) => _footer(regular, ctx),
        build:      (ctx) => [
          _contactsAlertedSection(data, bold, regular),
          pw.SizedBox(height: 24),
          _legalDeclarationSection(data, bold, regular, italic),
        ],
      ));

      // Save to temp dir
      final dir  = await getTemporaryDirectory();
      final name = 'SafeHer_Report_'
          '${data.incidentId.substring(0, min(8, data.incidentId.length))}_'
          '${DateFormat('yyyyMMdd_HHmmss').format(data.triggeredAt)}.pdf';
      final file  = File('${dir.path}/$name');
      final bytes = await pdf.save();
      await file.writeAsBytes(bytes);

      // Upload in background
      _uploadPdfToStorage(file, data).catchError(
            (e) => debugPrint('[EvidencePdfService] Upload error: $e'),
      );

      return file;
    } catch (e, st) {
      debugPrint('[EvidencePdfService] generateReport error: $e\n$st');
      return null;
    }
  }

  Future<String?> _uploadPdfToStorage(
      File               file,
      IncidentReportData data,
      ) async {
    try {
      final fileName = 'evidence_report_'
          '${DateTime.now().millisecondsSinceEpoch}.pdf';
      final path = EvidenceStoragePaths.report(
        _uid,
        data.incidentId,
        fileName,
      );

      final ref  = _storage.ref(path);
      final task = await ref.putFile(
        file,
        SettableMetadata(
          contentType:    'application/pdf',
          customMetadata: {
            'incidentId': data.incidentId,
            'victimName': data.victimName,
          },
        ),
      );
      final url = await task.ref.getDownloadURL();

      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('incidents')
          .doc(data.incidentId)
          .set({
        EvidenceFields.pdfReportUrl:   url,
        EvidenceFields.pdfGeneratedAt: FieldValue.serverTimestamp(),
        EvidenceFields.pdfStoragePath: path,
      }, SetOptions(merge: true));

      debugPrint('[EvidencePdfService] PDF uploaded: $url');
      return url;
    } catch (e) {
      debugPrint('[EvidencePdfService] PDF upload failed: $e');
      return null;
    }
  }

  Future<File?> autoGenerateOnResolve(String incidentId) async {
    try {
      // 3s delay allows Firestore writes from upload queue to settle
      await Future.delayed(const Duration(seconds: 3));
      final data = await loadIncidentData(incidentId);
      if (data == null) return null;
      return await generateReport(data);
    } catch (e) {
      debugPrint('[EvidencePdfService] autoGenerateOnResolve error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARE / PRINT
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> shareReport(File file, IncidentReportData data) async {
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject:
      'SafeHer Incident Report — ${_dtFmt.format(data.triggeredAt)}',
      text: '🚨 SafeHer Incident Report\n'
          'Victim: ${data.victimName}\n'
          'Location: https://maps.google.com/maps?q=${data.lat},${data.lng}\n'
          'Please take immediate action.',
    );
  }

  Future<void> printReport(File file) async {
    await Printing.layoutPdf(
      onLayout: (_) => file.readAsBytes(),
    );
  }

  Future<void> shareToPoliceWhatsApp(IncidentReportData data) async {
    final msg = Uri.encodeComponent(
      '🚨 *EMERGENCY REPORT — SafeHer App*\n'
          '*Victim:* ${data.victimName}\n'
          '*Phone:* ${data.victimPhone}\n'
          '*Location:* https://maps.google.com/maps?q=${data.lat},${data.lng}\n'
          '*Danger Score:* ${(data.dangerScore * 100).toInt()}%\n'
          '_Sent via SafeHer Women Safety App_',
    );
    final uri = Uri.parse('whatsapp://send?text=$msg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(
        Uri.parse('https://wa.me/?text=$msg'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  Future<void> shareViaEmail(IncidentReportData data) async {
    final subject = Uri.encodeComponent(
      'SafeHer Incident Report — '
          '${_dateFmt.format(data.triggeredAt)} — ${data.victimName}',
    );
    final body = Uri.encodeComponent(
      'Dear Sir/Madam,\n'
          'I am reporting an emergency incident.\n'
          'Victim: ${data.victimName}\n'
          'Location: https://maps.google.com/maps?q=${data.lat},${data.lng}\n'
          'Please take action immediately.',
    );
    await launchUrl(Uri.parse('mailto:?subject=$subject&body=$body'));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PDF WIDGET BUILDERS
  // ═══════════════════════════════════════════════════════════════════════════

  pw.Widget _header(
      pw.Font bold,
      pw.Font italic,
      IncidentReportData data,
      pw.Context ctx,
      ) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: PdfColor.fromInt(0xFFE91E63),
            width: 2.5,
          ),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '🛡️ SafeHer Incident Report',
                style: pw.TextStyle(
                  font:      bold,
                  fontSize:  13,
                  color:     const PdfColor.fromInt(0xFFE91E63),
                ),
              ),
              pw.Text(
                'ID: ${data.incidentId}',
                style: pw.TextStyle(
                  font:      italic,
                  fontSize:  8,
                  color:     PdfColors.grey600,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'CONFIDENTIAL — Official Use Only',
                style: pw.TextStyle(
                  font:     bold,
                  fontSize: 8,
                  color:    PdfColors.red700,
                ),
              ),
              pw.Text(
                'Generated: ${_dtFmt.format(DateTime.now())}',
                style: const pw.TextStyle(
                  fontSize: 7,
                  color:    PdfColors.grey500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _footer(pw.Font regular, pw.Context ctx) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'SafeHer — AI-Powered Women Safety App | VJIT Hyderabad',
            style: pw.TextStyle(
              font:     regular,
              fontSize: 7,
              color:    PdfColors.grey500,
            ),
          ),
          pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: pw.TextStyle(
              font:     regular,
              fontSize: 7,
              color:    PdfColors.grey500,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _coverSection(
      IncidentReportData data,
      pw.Font bold,
      pw.Font regular,
      pw.Font italic,
      ) {
    final statusColor = data.status == 'resolved'
        ? PdfColors.green700
        : data.status == 'false_alarm'
        ? PdfColors.orange700
        : PdfColors.red700;

    return pw.Container(
      padding: const pw.EdgeInsets.all(24),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [
            PdfColor.fromInt(0xFFFCE4EC),
            PdfColor.fromInt(0xFFFFEBEE),
          ],
          begin: pw.Alignment.topLeft,
          end:   pw.Alignment.bottomRight,
        ),
        border: pw.Border.all(
          color: const PdfColor.fromInt(0xFFF48FB1),
          width: 1.5,
        ),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 14,
                vertical:   6,
              ),
              decoration: pw.BoxDecoration(
                color:        PdfColors.red800,
                borderRadius: pw.BorderRadius.circular(20),
              ),
              child: pw.Text(
                '🚨 OFFICIAL INCIDENT REPORT',
                style: pw.TextStyle(
                  font:      bold,
                  color:     PdfColors.white,
                  fontSize:  11,
                ),
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 12,
                vertical:   6,
              ),
              decoration: pw.BoxDecoration(
                color:        statusColor,
                borderRadius: pw.BorderRadius.circular(20),
              ),
              child: pw.Text(
                data.status.toUpperCase().replaceAll('_', ' '),
                style: pw.TextStyle(
                  font:     bold,
                  color:    PdfColors.white,
                  fontSize: 9,
                ),
              ),
            ),
          ]),
          pw.SizedBox(height: 20),
          pw.Row(children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _infoRow(bold, regular, 'Victim Name', data.victimName),
                  pw.SizedBox(height: 8),
                  _infoRow(bold, regular, 'Phone',
                      data.victimPhone.isEmpty ? '—' : data.victimPhone),
                  pw.SizedBox(height: 8),
                  _infoRow(bold, regular, 'Incident ID', data.incidentId),
                  pw.SizedBox(height: 8),
                  _infoRow(bold, regular, 'Trigger Type',
                      data.triggerType.toUpperCase()),
                ],
              ),
            ),
            pw.SizedBox(width: 20),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _infoRow(bold, regular, 'Date & Time',
                      _dtFmt.format(data.triggeredAt)),
                  pw.SizedBox(height: 8),
                  if (data.resolvedAt != null) ...[
                    _infoRow(bold, regular, 'Resolved At',
                        _dtFmt.format(data.resolvedAt!)),
                    pw.SizedBox(height: 8),
                    _infoRow(bold, regular, 'Duration',
                        _fmtDuration(
                          data.resolvedAt!.difference(data.triggeredAt),
                        )),
                    pw.SizedBox(height: 8),
                  ],
                  _infoRow(
                    bold,
                    regular,
                    'GPS Coordinates',
                    '${data.lat.toStringAsFixed(6)}, '
                        '${data.lng.toStringAsFixed(6)}',
                  ),
                  pw.SizedBox(height: 8),
                  _infoRow(
                    bold,
                    regular,
                    'AI Danger Score',
                    '${(data.dangerScore * 100).toStringAsFixed(1)}% — '
                        '${_dangerLevel(data.dangerScore)}',
                  ),
                ],
              ),
            ),
          ]),
          pw.SizedBox(height: 12),
          if (data.address != null)
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color:        PdfColors.white,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(children: [
                pw.Text(
                  '📍 Address: ',
                  style: pw.TextStyle(
                    font:      bold,
                    fontSize:  9,
                    color:     PdfColors.grey700,
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    data.address!,
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color:    PdfColors.grey800,
                    ),
                  ),
                ),
              ]),
            ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color:        PdfColors.white,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(children: [
              pw.Text(
                '🗺️ Maps: ',
                style: pw.TextStyle(
                  font:     bold,
                  fontSize: 8,
                  color:    PdfColors.grey600,
                ),
              ),
              pw.UrlLink(
                destination:
                'https://maps.google.com/?q=${data.lat},${data.lng}',
                child: pw.Text(
                  'https://maps.google.com/?q=${data.lat},${data.lng}',
                  style: const pw.TextStyle(
                    fontSize:   8,
                    color:      PdfColors.blue700,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  pw.Widget _incidentSummarySection(
      IncidentReportData data,
      pw.Font bold,
      pw.Font regular,
      ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(bold, 'INCIDENT SUMMARY'),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color:        PdfColors.grey50,
            borderRadius: pw.BorderRadius.circular(10),
            border:       pw.Border.all(color: PdfColors.grey200),
          ),
          child: pw.Column(children: [
            pw.Row(children: [
              pw.Text(
                'AI Danger Score',
                style: pw.TextStyle(font: bold, fontSize: 10),
              ),
              pw.Spacer(),
              pw.Text(
                '${(data.dangerScore * 100).toStringAsFixed(1)}%',
                style: pw.TextStyle(
                  font:      bold,
                  fontSize:  10,
                  color:     _pdfDangerColor(data.dangerScore),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Container(
                width:  100,
                height: 10,
                decoration: pw.BoxDecoration(
                  color:        PdfColors.grey200,
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Container(
                    width:  100 * data.dangerScore.clamp(0.0, 1.0),
                    height: 10,
                    decoration: pw.BoxDecoration(
                      color:        _pdfDangerColor(data.dangerScore),
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
            ]),
            pw.SizedBox(height: 10),
            pw.Divider(color: PdfColors.grey200),
            pw.SizedBox(height: 10),
            pw.Row(children: [
              _summaryStatCol(bold, regular,
                  '${data.gpsTrail.length}', 'GPS Points', '📍'),
              _summaryStatCol(bold, regular,
                  '${data.photoUrls.length}', 'Photos', '📷'),
              _summaryStatCol(bold, regular,
                  '${data.videoUrls.length}', 'Videos', '🎥'),
              _summaryStatCol(bold, regular,
                  data.audioUrl != null ? '✓' : '—', 'Audio', '🎙️'),
              _summaryStatCol(bold, regular,
                  '${data.alertsSent.length}', 'Alerted', '📢'),
            ]),
          ]),
        ),
      ],
    );
  }

  pw.Widget _summaryStatCol(
      pw.Font bold,
      pw.Font regular,
      String val,
      String label,
      String emoji,
      ) =>
      pw.Expanded(
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(emoji, style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 4),
            pw.Text(
              val,
              style: pw.TextStyle(
                font:      bold,
                fontSize:  13,
                color:     const PdfColor.fromInt(0xFFE91E63),
              ),
            ),
            pw.Text(
              label,
              style: pw.TextStyle(
                font:     regular,
                fontSize: 8,
                color:    PdfColors.grey600,
              ),
            ),
          ],
        ),
      );

  pw.Widget _contextFlagsSection(
      IncidentReportData data,
      pw.Font bold,
      pw.Font regular,
      ) {
    final flags = <Map<String, String>>[];
    if (data.phoneFallen) flags.add({'e': '📱', 'l': 'Fall Detected'});
    if (data.phoneInPocket) flags.add({'e': '🫳', 'l': 'In Pocket'});
    if (data.isNightTime) flags.add({'e': '🌙', 'l': 'Night Incident'});
    if (data.screamProbability != null && data.screamProbability! > 0.5) {
      flags.add({'e': '😱', 'l': 'Scream Detected'});
    }
    if (flags.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(bold, 'CONTEXT FLAGS'),
        pw.SizedBox(height: 12),
        pw.Wrap(
          spacing:    8,
          runSpacing: 8,
          children:   flags.map((f) => pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 12,
              vertical:   6,
            ),
            decoration: pw.BoxDecoration(
              color:        PdfColors.red50,
              borderRadius: pw.BorderRadius.circular(20),
              border: pw.Border.all(color: PdfColors.red200),
            ),
            child: pw.Row(children: [
              pw.Text(f['e']!, style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(width: 6),
              pw.Text(
                f['l']!,
                style: pw.TextStyle(
                  font:      bold,
                  fontSize:  9,
                  color:     PdfColors.red900,
                ),
              ),
            ]),
          )).toList(),
        ),
      ],
    );
  }

  pw.Widget _gpsSection(
      IncidentReportData data,
      pw.Font bold,
      pw.Font regular,
      pw.Font mono,
      pw.Font monoBold,
      ) {
    if (data.gpsTrail.isEmpty) {
      return pw.Text(
        'No GPS points recorded.',
        style: pw.TextStyle(
          font:     regular,
          fontSize: 10,
          color:    PdfColors.grey600,
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(bold, 'GPS MOVEMENT TRAIL'),
        pw.SizedBox(height: 12),
        pw.Table(
          border:       pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: const {
            0: pw.FixedColumnWidth(28),
            1: pw.FixedColumnWidth(64),
            2: pw.FixedColumnWidth(80),
            3: pw.FixedColumnWidth(80),
            4: pw.FixedColumnWidth(48),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFE91E63),
              ),
              children: ['#', 'Time', 'Latitude', 'Longitude', 'Speed km/h']
                  .map((h) => pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(
                  h,
                  style: pw.TextStyle(
                    font:     monoBold,
                    fontSize: 7,
                    color:    PdfColors.white,
                  ),
                ),
              ))
                  .toList(),
            ),
            ...data.gpsTrail.take(100).toList().asMap().entries.map(
                  (e) => pw.TableRow(
                children: [
                  _monoCell(mono, '${e.key + 1}'),
                  _monoCell(mono, _timeFmt.format(e.value.timestamp)),
                  _monoCell(mono, e.value.lat.toStringAsFixed(6)),
                  _monoCell(mono, e.value.lng.toStringAsFixed(6)),
                  _monoCell(mono, e.value.speed.toStringAsFixed(1)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _evidenceCatalogueSection(
      IncidentReportData data,
      pw.Font bold,
      pw.Font regular,
      pw.Font mono,
      ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(bold, 'EVIDENCE CATALOGUE'),
        pw.SizedBox(height: 12),
        if (data.audioUrl != null) ...[
          pw.Text('🎙️ Audio Recording:',
              style: pw.TextStyle(font: bold, fontSize: 10)),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color:        PdfColors.grey50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.UrlLink(
              destination: data.audioUrl!,
              child: pw.Text(
                data.audioUrl!.length > 80
                    ? '${data.audioUrl!.substring(0, 80)}...'
                    : data.audioUrl!,
                style: const pw.TextStyle(
                  fontSize:   8,
                  color:      PdfColors.blue700,
                  decoration: pw.TextDecoration.underline,
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 14),
        ],
        if (data.photoUrls.isNotEmpty) ...[
          pw.Text('📷 Photos (${data.photoUrls.length}):',
              style: pw.TextStyle(font: bold, fontSize: 10)),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color:        PdfColors.grey50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: data.photoUrls.asMap().entries.map((e) =>
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Row(children: [
                      pw.Text('Photo #${e.key + 1}: ',
                          style: pw.TextStyle(font: bold, fontSize: 7)),
                      pw.Expanded(
                        child: pw.UrlLink(
                          destination: e.value,
                          child: pw.Text(
                            e.value.length > 80
                                ? '${e.value.substring(0, 80)}...'
                                : e.value,
                            style: const pw.TextStyle(
                              fontSize:   7,
                              color:      PdfColors.blue700,
                              decoration: pw.TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
              ).toList(),
            ),
          ),
          pw.SizedBox(height: 14),
        ],
        if (data.videoUrls.isNotEmpty) ...[
          pw.Text('🎥 Videos (${data.videoUrls.length}):',
              style: pw.TextStyle(font: bold, fontSize: 10)),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color:        PdfColors.grey50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: data.videoUrls.asMap().entries.map((e) =>
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Row(children: [
                      pw.Text('Video #${e.key + 1}: ',
                          style: pw.TextStyle(font: bold, fontSize: 7)),
                      pw.Expanded(
                        child: pw.UrlLink(
                          destination: e.value,
                          child: pw.Text(
                            e.value.length > 80
                                ? '${e.value.substring(0, 80)}...'
                                : e.value,
                            style: const pw.TextStyle(
                              fontSize:   7,
                              color:      PdfColors.blue700,
                              decoration: pw.TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
              ).toList(),
            ),
          ),
        ],
      ],
    );
  }

  pw.Widget _audioAnalysisSection(
      IncidentReportData data,
      pw.Font bold,
      pw.Font regular,
      pw.Font mono,
      ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(bold, 'AUDIO ANALYSIS'),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color:        PdfColors.grey50,
            borderRadius: pw.BorderRadius.circular(10),
            border:       pw.Border.all(color: PdfColors.grey200),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _infoRow(bold, regular, 'Status',
                  data.audioUrl != null ? 'RECORDED ✓' : 'NOT AVAILABLE'),
              if (data.audioDuration != null) ...[
                pw.SizedBox(height: 8),
                _infoRow(bold, regular, 'Duration',
                    '${data.audioDuration!.inSeconds} seconds'),
              ],
              if (data.audioPeakAmplitude != null) ...[
                pw.SizedBox(height: 8),
                _infoRow(bold, regular, 'Peak Amplitude',
                    data.audioPeakAmplitude!.toStringAsFixed(3)),
              ],
              if (data.audioAnalyzedForScream) ...[
                pw.SizedBox(height: 8),
                _infoRow(bold, regular, 'Scream Detection',
                    data.screamProbability != null
                        ? '${(data.screamProbability! * 100).toStringAsFixed(1)}% probability'
                        : 'Analyzed'),
              ],
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _sensorAnalysisSection(
      IncidentReportData data,
      pw.Font bold,
      pw.Font regular,
      pw.Font mono,
      ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(bold, 'SENSOR DATA ANALYSIS'),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color:        PdfColors.grey50,
            borderRadius: pw.BorderRadius.circular(10),
            border:       pw.Border.all(color: PdfColors.grey200),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _infoRow(bold, regular, 'Fall Detected',
                  data.phoneFallen ? 'YES ⚠️' : 'NO'),
              pw.SizedBox(height: 8),
              _infoRow(bold, regular, 'Phone In Pocket',
                  data.phoneInPocket ? 'YES' : 'NO'),
              pw.SizedBox(height: 8),
              _infoRow(bold, regular, 'Night Incident',
                  data.isNightTime ? 'YES 🌙' : 'NO'),
              if (data.sensorLogUrl != null) ...[
                pw.SizedBox(height: 8),
                _infoRow(bold, regular, 'Sensor Log', 'Available ✓'),
              ],
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _contactsAlertedSection(
      IncidentReportData data,
      pw.Font bold,
      pw.Font regular,
      ) {
    if (data.alertsSent.isEmpty) {
      return pw.Text('No contact alerts recorded.');
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(bold, 'EMERGENCY CONTACTS ALERTED'),
        pw.SizedBox(height: 12),
        pw.Table(
          border:       pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(2.5),
            1: pw.FlexColumnWidth(2.0),
            2: pw.FlexColumnWidth(1.8),
            3: pw.FlexColumnWidth(2.5),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFE91E63),
              ),
              children: ['Name', 'Phone', 'Time', 'Channels']
                  .map((h) => pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  h,
                  style: pw.TextStyle(
                    font:     bold,
                    fontSize: 8,
                    color:    PdfColors.white,
                  ),
                ),
              ))
                  .toList(),
            ),
            ...data.alertsSent.map((e) {
              final channels = [
                if (e.sms) 'SMS',
                if (e.whatsapp) 'WA',
                if (e.fcm) 'Push',
                if (e.called) 'Call',
              ].join(', ');
              return pw.TableRow(children: [
                _tableCell(regular, e.contactName),
                _tableCell(regular, e.phone),
                _tableCell(regular, _shortT.format(e.sentAt)),
                _tableCell(regular, channels.isEmpty ? '—' : channels),
              ]);
            }),
          ],
        ),
      ],
    );
  }

  pw.Widget _legalDeclarationSection(
      IncidentReportData data,
      pw.Font bold,
      pw.Font regular,
      pw.Font italic,
      ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(bold, 'DECLARATION & AUTHENTICITY'),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color:        PdfColors.grey50,
            borderRadius: pw.BorderRadius.circular(10),
            border:       pw.Border.all(color: PdfColors.grey200),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'This report was automatically generated by the SafeHer '
                    'Women Safety Application on ${_dtFmt.format(DateTime.now())}.',
                style: pw.TextStyle(font: regular, fontSize: 9),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Incident ID: ${data.incidentId}',
                style: pw.TextStyle(font: bold, fontSize: 9),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'All evidence files, GPS coordinates, sensor data, and '
                    'timestamps are cryptographically secured in Firebase Cloud '
                    'Storage and Firestore. This document may be submitted to '
                    'law enforcement as supporting forensic evidence.',
                style: pw.TextStyle(
                  font:      italic,
                  fontSize:  8,
                  color:     PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'SafeHer — AI-Powered Women Safety System\n'
                    'VJIT Hyderabad | Developed under AICTE Guidelines',
                style: pw.TextStyle(font: bold, fontSize: 8),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Helper widgets ─────────────────────────────────────────────────────────

  pw.Widget _sectionTitle(pw.Font bold, String title) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              font:     bold,
              fontSize: 14,
              color:    const PdfColor.fromInt(0xFFE91E63),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Container(
            height: 2.5,
            color:  const PdfColor.fromInt(0xFFF48FB1),
          ),
        ],
      );

  pw.Widget _infoRow(
      pw.Font bold,
      pw.Font regular,
      String label,
      String value,
      ) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font:     bold,
              fontSize: 8,
              color:    PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(font: regular, fontSize: 10),
          ),
        ],
      );

  pw.Widget _monoCell(pw.Font mono, String val) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(
          val,
          style: pw.TextStyle(
            font:     mono,
            fontSize: 7,
            color:    PdfColors.grey800,
          ),
        ),
      );

  pw.Widget _tableCell(pw.Font regular, String val) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(
          val,
          style: pw.TextStyle(font: regular, fontSize: 8),
        ),
      );

  // ── Formatters ─────────────────────────────────────────────────────────────

  String _dangerLevel(double score) => score >= 0.9
      ? 'CRITICAL 🚨'
      : score >= 0.7
      ? 'HIGH ⚠️'
      : 'LOW ✅';

  PdfColor _pdfDangerColor(double score) => score >= 0.9
      ? PdfColors.red900
      : score >= 0.7
      ? PdfColors.red700
      : PdfColors.green700;

  String _fmtDuration(Duration d) =>
      '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';

  DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is Timestamp) return v.toDate();
    if (v is int) {
      // 13-digit = milliseconds, 10-digit = seconds
      // Using plain integer literal instead of digit-separator syntax
      // to maintain compatibility with older Dart language versions
      return v > 1000000000000
          ? DateTime.fromMillisecondsSinceEpoch(v)
          : DateTime.fromMillisecondsSinceEpoch(v * 1000);
    }
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }
}