// lib/core/services/permission_service.dart

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

enum PermissionType {
  location,
  locationAlways,
  microphone,
  contacts,
  camera,
  storage,
  notification,
  activityRecognition,
  phone,
}

class PermissionResult {
  final bool granted;
  final String message;
  const PermissionResult({required this.granted, required this.message});
}

class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  // ─── Request All Safety Permissions at once ───────────────────────────────
  Future<Map<PermissionType, bool>> requestAllSafetyPermissions() async {
    final results = await [
      Permission.locationWhenInUse,
      Permission.locationAlways,
      Permission.microphone,
      Permission.contacts,
      Permission.camera,
      Permission.storage,
      Permission.notification,
      Permission.activityRecognition,
      Permission.phone,
    ].request();

    return {
      PermissionType.location: results[Permission.locationWhenInUse]?.isGranted ?? false,
      PermissionType.locationAlways: results[Permission.locationAlways]?.isGranted ?? false,
      PermissionType.microphone: results[Permission.microphone]?.isGranted ?? false,
      PermissionType.contacts: results[Permission.contacts]?.isGranted ?? false,
      PermissionType.camera: results[Permission.camera]?.isGranted ?? false,
      PermissionType.storage: results[Permission.storage]?.isGranted ?? false,
      PermissionType.notification: results[Permission.notification]?.isGranted ?? false,
      PermissionType.activityRecognition: results[Permission.activityRecognition]?.isGranted ?? false,
      PermissionType.phone: results[Permission.phone]?.isGranted ?? false,
    };
  }

  // ─── Check individual permission ──────────────────────────────────────────
  Future<bool> isGranted(PermissionType type) async {
    final permission = _mapPermission(type);
    return await permission.isGranted;
  }

  // ─── Request single permission ────────────────────────────────────────────
  Future<PermissionResult> request(PermissionType type) async {
    final permission = _mapPermission(type);
    final status = await permission.request();

    if (status.isGranted) {
      return const PermissionResult(granted: true, message: 'Permission granted');
    } else if (status.isPermanentlyDenied) {
      return PermissionResult(
        granted: false,
        message: '${_permissionName(type)} permission is permanently denied. Please enable it in Settings.',
      );
    } else {
      return PermissionResult(
        granted: false,
        message: '${_permissionName(type)} permission is required for this feature.',
      );
    }
  }

  // ─── Critical permissions check (location + mic) ─────────────────────────
  Future<bool> areCriticalPermissionsGranted() async {
    final location = await Permission.locationWhenInUse.isGranted;
    final mic = await Permission.microphone.isGranted;
    return location && mic;
  }

  // ─── Check all safety permissions status ─────────────────────────────────
  Future<Map<PermissionType, bool>> checkAllPermissions() async {
    return {
      PermissionType.location: await Permission.locationWhenInUse.isGranted,
      PermissionType.locationAlways: await Permission.locationAlways.isGranted,
      PermissionType.microphone: await Permission.microphone.isGranted,
      PermissionType.contacts: await Permission.contacts.isGranted,
      PermissionType.camera: await Permission.camera.isGranted,
      PermissionType.storage: await Permission.storage.isGranted,
      PermissionType.notification: await Permission.notification.isGranted,
      PermissionType.activityRecognition: await Permission.activityRecognition.isGranted,
      PermissionType.phone: await Permission.phone.isGranted,
    };
  }

  // ─── Open app settings if permanently denied ──────────────────────────────
  Future<void> openSettings() => openAppSettings();

  // ─── Show permission rationale dialog ────────────────────────────────────
  Future<bool> showPermissionDialog(BuildContext context, PermissionType type) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(_permissionIcon(type), color: const Color(0xFFE91E8C)),
            const SizedBox(width: 10),
            Text(_permissionName(type), style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          _permissionRationale(type),
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Deny', style: TextStyle(color: Colors.grey, fontFamily: 'Poppins')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E8C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Allow', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  Permission _mapPermission(PermissionType type) => switch (type) {
    PermissionType.location => Permission.locationWhenInUse,
    PermissionType.locationAlways => Permission.locationAlways,
    PermissionType.microphone => Permission.microphone,
    PermissionType.contacts => Permission.contacts,
    PermissionType.camera => Permission.camera,
    PermissionType.storage => Permission.storage,
    PermissionType.notification => Permission.notification,
    PermissionType.activityRecognition => Permission.activityRecognition,
    PermissionType.phone => Permission.phone,
  };

  String _permissionName(PermissionType type) => switch (type) {
    PermissionType.location => 'Location',
    PermissionType.locationAlways => 'Background Location',
    PermissionType.microphone => 'Microphone',
    PermissionType.contacts => 'Contacts',
    PermissionType.camera => 'Camera',
    PermissionType.storage => 'Storage',
    PermissionType.notification => 'Notifications',
    PermissionType.activityRecognition => 'Activity Recognition',
    PermissionType.phone => 'Phone',
  };

  IconData _permissionIcon(PermissionType type) => switch (type) {
    PermissionType.location || PermissionType.locationAlways => Icons.location_on_rounded,
    PermissionType.microphone => Icons.mic_rounded,
    PermissionType.contacts => Icons.contacts_rounded,
    PermissionType.camera => Icons.camera_alt_rounded,
    PermissionType.storage => Icons.folder_rounded,
    PermissionType.notification => Icons.notifications_rounded,
    PermissionType.activityRecognition => Icons.directions_run_rounded,
    PermissionType.phone => Icons.phone_rounded,
  };

  String _permissionRationale(PermissionType type) => switch (type) {
    PermissionType.location => 'SafeHer needs your location to share with emergency contacts and detect unsafe areas in real-time.',
    PermissionType.locationAlways => 'Background location allows SafeHer to monitor your safety even when the app is minimized.',
    PermissionType.microphone => 'SafeHer uses your microphone to detect distress sounds like screaming for automated SOS triggering.',
    PermissionType.contacts => 'SafeHer needs access to your contacts to let you select emergency contacts easily.',
    PermissionType.camera => 'SafeHer uses the camera to automatically record video evidence during an SOS event.',
    PermissionType.storage => 'Storage access is needed to save evidence recordings securely on your device.',
    PermissionType.notification => 'Notifications alert you and your contacts during SOS events.',
    PermissionType.activityRecognition => 'Activity recognition helps detect abnormal movements like falls or attacks.',
    PermissionType.phone => 'Phone access allows SafeHer to make emergency calls on your behalf.',
  };
}