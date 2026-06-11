// lib/main.dart
// ─────────────────────────────────────────────────────────────────────────────
// INDUSTRIAL SENTINEL — SAFEHER MAIN ENTRY POINT (2026 PRODUCTION)
// ─────────────────────────────────────────────────────────────────────────────
// ✅ [ADVANCED] Autonomous Matrix: Added Background Service event listener.
// ✅ [FIXED] Provider Injection: ContactProvider properly injected.
// ✅ [FIXED] 'unawaited' collision resolved via import hiding.
// ✅ [FIXED] SafeHerApp constructor error resolved.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// App Core
import 'app.dart';
import 'core/theme/theme_provider.dart';
import 'core/services/permission_service.dart';
import 'core/services/background_service.dart';
import 'core/services/offline_sos_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/ml_api_service.dart';
import 'core/services/decoy_service.dart';
import 'core/constants/app_constants.dart';

// Zero-Click Triggers
import 'core/services/hardware_sos_service.dart';
import 'core/services/voice_sos_service.dart';

// State Providers (✅ FIXED: Hid 'unawaited' to prevent collision)
import 'features/auth/providers/auth_provider.dart';
import 'features/contacts/providers/contact_provider.dart' hide unawaited;
import 'features/location/providers/location_provider.dart' hide unawaited;
import 'features/sos/providers/sos_provider.dart' hide unawaited;
import 'features/settings/providers/biometric_provider.dart';
import 'features/notifications/providers/notification_provider.dart';

final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();

// Global Navigator Key for accessing Context outside the widget tree
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ═════════════════════════════════════════════════════════════════════════════
// BACKGROUND HANDLERS
// ═════════════════════════════════════════════════════════════════════════════


@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await _showLocalNotification(
    title: message.notification?.title ?? 'SafeHer Alert',
    body:  message.notification?.body  ?? '',
  );
}

Future<void> _showLocalNotification({
  required String title,
  required String body,
  String? payload,
}) async {
  const androidDetails = AndroidNotificationDetails(
    AppConstants.sosChannelId,
    AppConstants.sosChannelName,
    channelDescription: 'SOS and safety alerts',
    importance:         Importance.max,
    priority:           Priority.high,
    fullScreenIntent:   true,
    playSound:          true,
    enableVibration:    true,
    color:              Color(0xFFFF1744),
    icon:               '@drawable/ic_notification',
  );

  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  await localNotifications.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    const NotificationDetails(android: androidDetails, iOS: iosDetails),
    payload: payload,
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// INITIALIZATION SERVICES
// ═════════════════════════════════════════════════════════════════════════════

Future<void> _initLocalNotifications() async {
  const androidInit = AndroidInitializationSettings('@drawable/ic_notification');
  const iosInit = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  await localNotifications.initialize(
    const InitializationSettings(android: androidInit, iOS: iosInit),
    onDidReceiveNotificationResponse: (details) {},
  );

  final androidPlugin = localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  if (androidPlugin != null) {
    await Future.wait([
      androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          AppConstants.sosChannelId,
          AppConstants.sosChannelName,
          description:        'Critical SOS and danger alerts',
          importance:         Importance.max,
          enableVibration:    true,
          playSound:          true,
        ),
      ),
      androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          AppConstants.locationChannelId,
          AppConstants.locationChannelName,
          description: 'Live location tracking',
          importance:  Importance.low,
        ),
      ),
      androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          AppConstants.generalChannelId,
          AppConstants.generalChannelName,
          description: 'General notifications',
          importance:  Importance.defaultImportance,
        ),
      ),
    ]);
  }
}

Future<String?> _getFcmTokenWithRetry({int maxRetries = 3}) async {
  for (int attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        debugPrint('✅ [MAIN] FCM token obtained on attempt $attempt');
        return token;
      }
    } catch (e) {
      if (attempt < maxRetries) {
        await Future.delayed(Duration(seconds: 5 * attempt));
      }
    }
  }
  return null;
}

Future<void> _initFCM() async {
  final messaging = FirebaseMessaging.instance;

  await messaging.requestPermission(
    alert:       true,
    badge:       true,
    sound:       true,
    provisional: false,
  );

  try {
    final token = await _getFcmTokenWithRetry(maxRetries: 3);
    if (token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.fcmTokenKey, token);
    }
  } catch (e) {}

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FirebaseMessaging.onMessage.listen((message) async {
    await _showLocalNotification(
      title: message.notification?.title ?? 'SafeHer Alert',
      body:  message.notification?.body  ?? '',
    );
  });

  messaging.onTokenRefresh.listen((newToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.fcmTokenKey, newToken);
  });
}

Future<void> _warmUpCloudRun() async {
  try {
    debugPrint('🔥 [MAIN] Warming up Cloud Run backend...');
    final response = await http.get(
      Uri.parse('${AppConstants.apiBaseUrl}/health'),
    ).timeout(const Duration(seconds: 90));

    if (response.statusCode == 200) {
      debugPrint('✅ [MAIN] Cloud Run warmed up and healthy');
    }
  } catch (e) {}
}

// ═════════════════════════════════════════════════════════════════════════════
// POST-FRAME DEFERRED INITIALIZATION (THE AUTONOMOUS MATRIX)
// ═════════════════════════════════════════════════════════════════════════════

void _deferredInit() {
  WidgetsBinding.instance.addPostFrameCallback((_) async {

    try {
      await BackgroundSafetyService.instance.initialize();

      BackgroundSafetyService.instance.on('auto_sos_trigger').listen((event) {
        if (event == null) return;

        final reason = event['reason'] ?? 'Autonomous AI Trigger';
        debugPrint('🚨 [MATRIX] Caught Autonomous Trigger: $reason');

        final context = navigatorKey.currentContext;
        if (context != null) {
          final sosProvider = Provider.of<SosProvider>(context, listen: false);

          if (!sosProvider.isSosActive) {
            Navigator.of(context).pushNamed('/sos');
            sosProvider.triggerManualSOS();
          }
        }
      });
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current, reason: 'BackgroundSafetyService init failed', fatal: false);
    }

    try { await PermissionService.instance.requestAllSafetyPermissions(); } catch (e) {}
    try { await HardwareSosService.instance.initialize(); } catch (e) {}
    try { await VoiceSosService.instance.initialize(); } catch (e) {}

    // Run without awaiting to prevent UI blocking
    _warmUpCloudRun();

    try { await MLApiService.instance.initialize(); } catch (e) {}
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// MAIN EXECUTION THREAD
// ═════════════════════════════════════════════════════════════════════════════

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp();

  FlutterError.onError = (FlutterErrorDetails details) {
    final description = details.exceptionAsString();
    final isLayoutError =
        description.contains('RenderFlex')     ||
            description.contains('overflowed')     ||
            description.contains('RenderBox')      ||
            description.contains('A RenderViewport') ||
            (description.contains('Failed assertion') && description.contains('!_needsLayout'));

    if (isLayoutError) {
      FirebaseCrashlytics.instance.recordError(details.exception, details.stack ?? StackTrace.empty, reason: 'Flutter layout error (non-fatal)', fatal: false);
      FlutterError.dumpErrorToConsole(details, forceReport: true);
    } else {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: false, reason: 'PlatformDispatcher uncaught error');
    return true;
  };

  await ThemeProvider.instance.init();
  await _initLocalNotifications();

  try { await NotificationService.instance.init(); } catch (e) {}
  try { await _initFCM(); } catch (e) {}
  try { await OfflineSosService.instance.init(); } catch (e) {}
  try { await DecoyService.instance.initialize(); } catch (e) {}

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ContactProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => BiometricProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()..init()),

        ChangeNotifierProxyProvider<ContactProvider, SosProvider>(
          create: (_) => SosProvider()..init(),
          update: (_, contactProvider, sosProvider) =>
          sosProvider!..setContactProvider(contactProvider),
        ),
      ],
      // ✅ FIXED: Removed constructor parameter to clear the compile error.
      child: const SafeHerApp(),
    ),
  );

  _deferredInit();
}