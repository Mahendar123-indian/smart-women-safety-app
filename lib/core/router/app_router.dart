// lib/core/router/app_router.dart
// ─────────────────────────────────────────────────────────────────────────────
// SAFEHER — APP ROUTER v8.0 (COMPLETE + ALL ROUTES)
// ─────────────────────────────────────────────────────────────────────────────
// ✅ All screens imported with package imports (prevents "not a class" errors)
// ✅ policeStations route passes args (lat, lng, incidentId, isEmergencyMode)
// ✅ incidentDetail route passes incidentId arg
// ✅ PoliceDashboardScreen safely imported
// ✅ All settings sub-screens routed
// ✅ fullscreen flag for biometric + decoy screens
// ✅ Smooth slide transition on all routes
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import 'package:smart_safety_app/features/auth/screens/splash_screen.dart';
import 'package:smart_safety_app/features/auth/screens/onboarding_screen.dart';
import 'package:smart_safety_app/features/auth/screens/login_screen.dart';
import 'package:smart_safety_app/features/auth/screens/register_screen.dart';
import 'package:smart_safety_app/features/auth/screens/phone_auth_screen.dart';
import 'package:smart_safety_app/features/auth/screens/otp_screen.dart';
import 'package:smart_safety_app/features/auth/screens/forgot_password_screen.dart';
import 'package:smart_safety_app/features/auth/screens/decoy_app_screen.dart';
import 'package:smart_safety_app/features/auth/screens/biometric_lock_screen.dart';

import 'package:smart_safety_app/features/home/screens/home_screen.dart';

import 'package:smart_safety_app/features/sos/screens/sos_screen.dart';

import 'package:smart_safety_app/features/location/screens/location_screen.dart';

import 'package:smart_safety_app/features/contacts/screens/contacts_screen.dart';

import 'package:smart_safety_app/features/settings/screens/settings_screen.dart';
import 'package:smart_safety_app/features/settings/screens/profile_screen.dart';
import 'package:smart_safety_app/features/settings/screens/sos_settings_screen.dart';
import 'package:smart_safety_app/features/settings/screens/voice_sos_settings_screen.dart';
import 'package:smart_safety_app/features/settings/screens/ai_settings_screen.dart';
import 'package:smart_safety_app/features/settings/screens/location_settings_screen.dart';
import 'package:smart_safety_app/features/settings/screens/notification_settings_screen.dart';
import 'package:smart_safety_app/features/settings/screens/decoy_settings_screen.dart';
import 'package:smart_safety_app/features/settings/screens/app_security_screen.dart';

import 'package:smart_safety_app/features/incidents/screens/incidents_screen.dart';
import 'package:smart_safety_app/features/incidents/screens/incident_detail_screen.dart';

import 'package:smart_safety_app/features/safety_places/screens/nearest_safety_places_screen.dart';
import 'package:smart_safety_app/features/safety_places/screens/police_stations_screen.dart';

import 'package:smart_safety_app/features/fake_call/screens/fake_call_screen.dart';

import 'package:smart_safety_app/features/community/screens/community_map_screen.dart';
import 'package:smart_safety_app/features/community/screens/report_danger_screen.dart';

import 'package:smart_safety_app/features/police/screens/police_dashboard_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────

class AppRouter {
  AppRouter._();

  // ── Route name constants ──────────────────────────────────────────────────
  static const String splash              = '/';
  static const String onboarding          = '/onboarding';
  static const String login               = '/login';
  static const String register            = '/register';
  static const String phoneAuth           = '/phone-auth';
  static const String otp                 = '/otp';
  static const String forgotPassword      = '/forgot-password';
  static const String decoyApp            = '/decoy';
  static const String biometricLock       = '/biometric-lock';

  static const String home                = '/home';

  static const String sos                 = '/sos';

  static const String location            = '/location';

  static const String contacts            = '/contacts';

  static const String settings            = '/settings';
  static const String profile             = '/settings/profile';
  static const String sosSettings         = '/settings/sos';
  static const String voiceSosSettings    = '/settings/voice-sos';
  static const String aiSettings          = '/settings/ai';
  static const String locationSettings    = '/settings/location';
  static const String notificationSettings = '/settings/notifications';
  static const String decoySettings       = '/settings/decoy';
  static const String appSecurity         = '/settings/security';

  static const String incidents           = '/incidents';
  static const String incidentDetail      = '/incident-detail';

  static const String nearestSafetyPlaces = '/nearest-safety-places';
  static const String policeStations      = '/police-stations';

  static const String fakeCall            = '/fake-call';

  static const String communityMap        = '/community-map';
  static const String reportDanger        = '/report-danger';

  static const String policeDashboard     = '/police-dashboard';

  // ═══════════════════════════════════════════════════════════════════════════
  // ROUTE GENERATOR
  // ═══════════════════════════════════════════════════════════════════════════

  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {

    // ── Auth ───────────────────────────────────────────────────────────────
      case splash:
        return _buildRoute(const SplashScreen(), routeSettings);

      case onboarding:
        return _buildRoute(const OnboardingScreen(), routeSettings);

      case login:
        return _buildRoute(const LoginScreen(), routeSettings);

      case register:
        return _buildRoute(const RegisterScreen(), routeSettings);

      case phoneAuth:
        return _buildRoute(const PhoneAuthScreen(), routeSettings);

      case otp: {
        final args = routeSettings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          OtpScreen(phone: args?['phone'] as String? ?? ''),
          routeSettings,
        );
      }

      case forgotPassword:
        return _buildRoute(const ForgotPasswordScreen(), routeSettings);

      case decoyApp:
        return _buildRoute(
          const DecoyAppScreen(),
          routeSettings,
          fullscreen: true,
        );

      case biometricLock:
        return _buildRoute(
          const BiometricLockScreen(),
          routeSettings,
          fullscreen: true,
        );

    // ── Home ───────────────────────────────────────────────────────────────
      case home:
        return _buildRoute(const HomeScreen(), routeSettings);

    // ── SOS ────────────────────────────────────────────────────────────────
      case sos:
        return _buildRoute(const SosScreen(), routeSettings);

    // ── Location ───────────────────────────────────────────────────────────
      case location:
        return _buildRoute(const LocationScreen(), routeSettings);

    // ── Contacts ───────────────────────────────────────────────────────────
      case contacts:
        return _buildRoute(const ContactsScreen(), routeSettings);

    // ── Settings ───────────────────────────────────────────────────────────
      case settings:
        return _buildRoute(const SettingsScreen(), routeSettings);

      case profile:
        return _buildRoute(const ProfileScreen(), routeSettings);

      case sosSettings:
        return _buildRoute(const SosSettingsScreen(), routeSettings);

      case voiceSosSettings:
        return _buildRoute(const VoiceSosSettingsScreen(), routeSettings);

      case aiSettings:
        return _buildRoute(const AiSettingsScreen(), routeSettings);

      case locationSettings:
        return _buildRoute(const LocationSettingsScreen(), routeSettings);

      case notificationSettings:
        return _buildRoute(const NotificationSettingsScreen(), routeSettings);

      case decoySettings:
        return _buildRoute(const DecoySettingsScreen(), routeSettings);

      case appSecurity:
        return _buildRoute(const AppSecurityScreen(), routeSettings);

    // ── Incidents ──────────────────────────────────────────────────────────
      case incidents:
        return _buildRoute(const IncidentsScreen(), routeSettings);

      case incidentDetail: {
        final args = routeSettings.arguments as Map<String, dynamic>?;
        final incidentId = args?['incidentId'] as String? ?? '';
        return _buildRoute(
          IncidentDetailScreen(incidentId: incidentId),
          routeSettings,
        );
      }

    // ── Safety Places ──────────────────────────────────────────────────────
      case nearestSafetyPlaces:
        return _buildRoute(
          const NearestSafetyPlacesScreen(),
          routeSettings,
        );

      case policeStations: {
        // Supports optional args: lat, lng, incidentId, isEmergencyMode
        final args = routeSettings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          PoliceStationsScreen(
            lat:             args?['lat']             as double?,
            lng:             args?['lng']             as double?,
            incidentId:      args?['incidentId']      as String?,
            isEmergencyMode: args?['isEmergencyMode'] as bool? ?? false,
          ),
          routeSettings,
        );
      }

    // ── Fake Call ──────────────────────────────────────────────────────────
      case fakeCall:
        return _buildRoute(const FakeCallScreen(), routeSettings);

    // ── Community ──────────────────────────────────────────────────────────
      case communityMap:
        return _buildRoute(const CommunityMapScreen(), routeSettings);

      case reportDanger:
        return _buildRoute(const ReportDangerScreen(), routeSettings);

    // ── Police Dashboard ───────────────────────────────────────────────────
      case policeDashboard:
        return _buildRoute(const PoliceDashboardScreen(), routeSettings);

    // ── 404 Fallback ───────────────────────────────────────────────────────
      default:
        return _buildRoute(
          Scaffold(
            backgroundColor: const Color(0xFF0A000A),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.route_outlined,
                    color: Colors.white24,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Route not found:\n${routeSettings.name}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontFamily: 'Poppins',
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          routeSettings,
        );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TRANSITION BUILDER
  // ═══════════════════════════════════════════════════════════════════════════

  static PageRouteBuilder<dynamic> _buildRoute(
      Widget page,
      RouteSettings routeSettings, {
        bool fullscreen = false,
      }) {
    return PageRouteBuilder(
      settings:         routeSettings,
      fullscreenDialog: fullscreen,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Fullscreen routes use fade+scale (modal feel)
        if (fullscreen) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          );
        }

        // Standard routes use horizontal slide
        const begin = Offset(1.0, 0.0);
        const end   = Offset.zero;
        const curve = Curves.easeInOutCubic;

        final tween = Tween(begin: begin, end: end)
            .chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }
}