// lib/features/contacts/providers/contact_provider.dart
// ─────────────────────────────────────────────────────────────────────────────
// INDUSTRIAL SENTINEL — CONTACT PROVIDER v5.0 (2026 PRODUCTION)
// ─────────────────────────────────────────────────────────────────────────────
// ✅ [FIXED] Memory Leaks: Added strict '_initCalled' singleton lock.
// ✅ [FIXED] Mutation Resilience: Added try/catch to all Firebase write operations.
// ✅ [FIXED] Type Safety: Upgraded 'unawaited' to handle dynamic Futures securely.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../models/emergency_contact_model.dart';
import '../services/contact_service.dart';
import '../services/contact_alert_service.dart';
import '../../../core/services/notification_service.dart';

export '../services/contact_alert_service.dart' show AlertPayload, AlertType, AlertResult;

enum ContactStatus { initial, loading, loaded, error }

class ContactProvider extends ChangeNotifier {
  final _service = ContactService.instance;
  final _alerts  = ContactAlertService.instance;
  final _notif   = NotificationService.instance;

  ContactStatus          _status        = ContactStatus.initial;
  List<EmergencyContact> _contacts      = [];
  List<Contact>          _phoneContacts = [];
  List<Contact>          _filteredPhone = [];

  String?  _error;
  bool     _loading         = false;
  bool     _scanning        = false;
  bool     _sosLoading      = false;
  AlertResult? _lastResult;
  int      _newAppUsersFound = 0;

  // Singleton Lock
  bool     _initCalled      = false;

  StreamSubscription? _contactSub;
  StreamSubscription? _fcmSub;

  // ── Getters ────────────────────────────────────────────────
  ContactStatus          get status          => _status;
  List<EmergencyContact> get contacts        => _contacts;
  List<Contact>          get phoneContacts   => _filteredPhone;
  String?                get error           => _error;
  bool                   get isLoading       => _loading;
  bool                   get isScanning      => _scanning;
  bool                   get isSosLoading    => _sosLoading;
  AlertResult?           get lastResult      => _lastResult;
  int                    get newAppUsersFound => _newAppUsersFound;
  int                    get activeCount     => _contacts.where((c) => c.isActive).length;
  int                    get appUserCount    => _contacts.where((c) => c.isAppUser).length;

  EmergencyContact?      get primary        =>
      _contacts.where((c) => c.isPrimary).firstOrNull
          ?? (_contacts.isNotEmpty ? _contacts.first : null);

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION (LOCKED)
  // ═══════════════════════════════════════════════════════════════════════════

  void init() {
    if (_initCalled) return;
    _initCalled = true;

    _status  = ContactStatus.loading;
    _loading = true;
    notifyListeners();

    _service.saveMyFcmToken();

    _fcmSub?.cancel();
    _fcmSub = _service.listenFcmTokenRefresh();

    _contactSub?.cancel();
    _contactSub = _service.streamContacts().listen(
          (list) {
        _contacts = list;
        _status   = ContactStatus.loaded;
        _loading  = false;
        notifyListeners();
      },
      onError: (e) {
        _error  = e.toString();
        _status = ContactStatus.error;
        _loading = false;
        notifyListeners();
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHONE BOOK INTEGRATION
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> loadPhoneContacts() async {
    _loading = true;
    notifyListeners();

    try {
      final list = await _service.fetchPhoneContacts();
      _phoneContacts = list;
      _filteredPhone = list;
      return list.isNotEmpty;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void filterPhoneContacts(String query) {
    if (query.trim().isEmpty) {
      _filteredPhone = _phoneContacts;
    } else {
      final q = query.toLowerCase();
      _filteredPhone = _phoneContacts.where((c) =>
      c.displayName.toLowerCase().contains(q) ||
          c.phones.any((p) => p.number.contains(q)),
      ).toList();
    }
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONTACT MUTATIONS (FIREBASE)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<EmergencyContact?> addContact({
    required String name,
    required String phone,
    required String relation,
    bool isPrimary = false,
    String? photoUrl,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final c = await _service.addContact(
        name: name, phone: phone, relation: relation,
        isPrimary: isPrimary, photoUrl: photoUrl,
      );

      if (c != null) {
        unawaited(_notif.showContactAdded(
          name: c.name, relation: c.relation,
          isAppUser: c.isAppUser, isPrimary: c.isPrimary,
        ));
      }
      return c;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<EmergencyContact?> addFromPhoneContact(
      Contact phoneContact, {
        required String relation,
        bool isPrimary = false,
      }) async {
    final phone = phoneContact.phones.isNotEmpty
        ? phoneContact.phones.first.number : '';
    if (phone.isEmpty) {
      _error = "Selected contact has no phone number.";
      notifyListeners();
      return null;
    }

    return addContact(
      name: phoneContact.displayName, phone: phone,
      relation: relation, isPrimary: isPrimary,
    );
  }

  Future<void> updateContact(EmergencyContact contact) async {
    try {
      await _service.updateContact(contact);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteContact(String id) async {
    try {
      final c = _contacts.where((x) => x.id == id).firstOrNull;
      await _service.deleteContact(id);
      if (c != null) unawaited(_notif.showContactDeleted(name: c.name));
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> setPrimary(String id) async {
    try {
      final c = _contacts.where((x) => x.id == id).firstOrNull;
      await _service.setPrimary(id);
      if (c != null) unawaited(_notif.showContactSetPrimary(name: c.name));
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> toggleActive(String id, bool active) async {
    try {
      final c = _contacts.where((x) => x.id == id).firstOrNull;
      await _service.toggleActive(id, active);
      if (c != null) {
        unawaited(_notif.showContactToggled(name: c.name, isNowActive: active));
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SOS ALERT — ALL CHANNELS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<AlertResult?> sendSosAlert({
    required double lat,
    required double lng,
    required String address,
    String? incidentId,
    double? dangerScore,
    String? triggerType,
  }) async {
    _sosLoading = true;
    _lastResult = null;
    _error = null;
    notifyListeners();

    try {
      final result = await _alerts.dispatch(
        payload: AlertPayload(
          type:        AlertType.sos,
          lat:         lat,
          lng:         lng,
          address:     address,
          incidentId:  incidentId,
          dangerScore: dangerScore,
          triggerType: triggerType,
        ),
        contacts:    _contacts,
        callPrimary: true, // Auto-call primary on SOS
      );

      _lastResult = result;

      unawaited(_notif.showSosSentToContacts(
        contactsReached: result.fcmSent,
        totalContacts:   activeCount,
        address:         address,
      ));

      return result;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _sosLoading = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // JOURNEY & INTELLIGENCE ALERTS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<AlertResult?> sendJourneyStart({
    required String destination,
    required int estimatedMinutes,
    required double lat,
    required double lng,
  }) async {
    final result = await _alerts.dispatch(
      payload: AlertPayload(
        type:             AlertType.journeyStart,
        lat:              lat, lng: lng,
        destination:      destination,
        estimatedMinutes: estimatedMinutes,
      ),
      contacts: _contacts,
    );
    _lastResult = result;
    notifyListeners();
    return result;
  }

  Future<AlertResult?> sendJourneyOverdue({
    required String destination,
    required double lat,
    required double lng,
  }) async {
    final result = await _alerts.dispatch(
      payload: AlertPayload(
        type: AlertType.journeyOverdue,
        lat: lat, lng: lng, destination: destination,
      ),
      contacts: _contacts,
    );
    _lastResult = result;
    notifyListeners();
    return result;
  }

  Future<void> sendSafeArrival({required String destination}) async {
    await _alerts.dispatch(
      payload: AlertPayload(type: AlertType.safeArrival, destination: destination),
      contacts: _contacts,
    );
  }

  // ─── AUTO-SAFETY ALERTS ──────────────────────────────────

  Future<void> sendBatteryAlert({required int level, required double lat, required double lng}) async {
    await _alerts.dispatch(
      payload: AlertPayload(type: AlertType.batteryLow, batteryLevel: level, lat: lat, lng: lng),
      contacts: _contacts,
    );
  }

  Future<void> sendSignalLostAlert({required double lat, required double lng, String? address}) async {
    await _alerts.dispatch(
      payload: AlertPayload(type: AlertType.signalLost, lat: lat, lng: lng, address: address),
      contacts: _contacts,
    );
  }

  Future<void> sendDangerZoneAlert({required double lat, required double lng, required String address}) async {
    await _alerts.dispatch(
      payload: AlertPayload(type: AlertType.dangerZone, lat: lat, lng: lng, address: address),
      contacts: _contacts,
    );
  }

  Future<void> sendDeadManSwitchAlert({required double lat, required double lng, String? address}) async {
    await _alerts.dispatch(
      payload: AlertPayload(type: AlertType.deadManSwitch, lat: lat, lng: lng, address: address),
      contacts:    _contacts,
      callPrimary: true,
    );
  }

  Future<void> sendNightDepartureAlert({required double lat, required double lng}) async {
    await _alerts.dispatch(
      payload: AlertPayload(type: AlertType.nightDeparture, lat: lat, lng: lng),
      contacts: _contacts,
    );
  }

  Future<void> sendSpeedAnomalyAlert({required double lat, required double lng, required String speedInfo, String? address}) async {
    await _alerts.dispatch(
      payload: AlertPayload(
        type: AlertType.speedAnomaly,
        lat: lat, lng: lng,
        address: address,
        customMessage: speedInfo,
      ),
      contacts:    _contacts,
      callPrimary: true,
    );
  }

  Future<void> sendGeofenceExit({required String zoneName, required double lat, required double lng}) async {
    await _alerts.dispatch(
      payload: AlertPayload(
        type: AlertType.geofenceExit,
        lat: lat, lng: lng, destination: zoneName,
      ),
      contacts: _contacts,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MANUAL LOCATION SHARE & CALLING
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> shareLocationNow({required double lat, required double lng, String? address}) async {
    await _alerts.dispatch(
      payload: AlertPayload(
        type: AlertType.locationShare,
        lat: lat, lng: lng, address: address,
      ),
      contacts: _contacts,
    );
  }

  Future<void> shareViaWhatsApp({required double lat, required double lng, String? address}) async {
    await _alerts.shareLiveLocationLink(lat: lat, lng: lng, address: address);
  }

  Future<void> shareViaAnyApp({required double lat, required double lng, String? address}) async {
    await _alerts.shareViaAnyApp(lat: lat, lng: lng, address: address);
  }

  Future<void> callContact(String phone) => _service.callContact(phone);

  Future<void> callPrimary() async {
    if (primary != null) await _service.callContact(primary!.phone);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILITIES & CLEANUP
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> scanForAppUsers() async {
    _scanning         = true;
    _newAppUsersFound = 0;
    notifyListeners();

    try {
      _newAppUsersFound = await _service.scanAndUpdateAppUsers();
      if (_newAppUsersFound > 0) {
        unawaited(_notif.showNewAppUsersFound(count: _newAppUsersFound));
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _scanning = false;
      notifyListeners();
    }
  }

  Future<List<String>> getActiveContactUids() => _service.getActiveContactUids();

  void clearError()  { _error = null; notifyListeners(); }
  void clearResult() { _lastResult = null; notifyListeners(); }

  @override
  void dispose() {
    _contactSub?.cancel();
    _fcmSub?.cancel();
    super.dispose();
  }
}

/// Industrial Async Utility ensuring unawaited futures log errors safely
void unawaited(Future<dynamic> future) =>
    future.catchError((Object e) => debugPrint('⚠️ [CONTACT UNAWAITED ERROR]: $e'));