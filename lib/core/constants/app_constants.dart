// lib/core/constants/app_constants.dart

class AppConstants {
  AppConstants._();

  // --- App Info ---
  static const String appName = 'SafeHer';
  static const String appVersion = '1.0.0';
  static const String packageName = 'com.vjit.womensafety';

  // --- API Gateway & Base URLs (✅ FIXED: Updated to live Cloud Run URL) ---
  static const String mlServiceUrl = 'https://safeher-backend-1006130066125.asia-south1.run.app';
  static const String apiBaseUrl   = 'https://safeher-backend-1006130066125.asia-south1.run.app';
  static const String wsBaseUrl    = 'wss://safeher-backend-1006130066125.asia-south1.run.app';

  // --- ML API Endpoints ---
  static const String mlAnalyzeEndpoint      = '/analyze_danger';
  static const String mlAnalyzeAudioEndpoint = '/predict/audio_file';
  static const String mlHealthCheckEndpoint  = '/health';
  static const String areaRiskEndpoint       = '/ml/area-risk';

  // --- Auth & User Endpoints ---
  static const String loginEndpoint        = '/auth/login';
  static const String registerEndpoint     = '/auth/register';
  static const String refreshTokenEndpoint = '/auth/refresh';
  static const String apiKeyEndpoint       = '/auth/api-key';

  // --- Functional Endpoints ---
  static const String locationUpdateEndpoint = '/location/update';
  static const String sosTriggerEndpoint     = '/sos/trigger';
  static const String sosResolveEndpoint     = '/sos/resolve';
  static const String sosHistoryEndpoint     = '/sos/history';
  static const String contactsEndpoint       = '/contacts';
  static const String evidenceUploadEndpoint = '/evidence/upload';

  // --- Local Storage Keys ---
  static const String jwtTokenKey          = 'jwt_token';
  static const String refreshTokenKey      = 'refresh_token';
  static const String apiKeyStorageKey     = 'api_key';
  static const String userIdKey            = 'user_id';
  static const String userDataKey          = 'user_data';
  static const String themeKey             = 'app_theme';
  static const String onboardingCompleteKey = 'onboarding_complete';
  static const String biometricEnabledKey  = 'biometric_enabled';
  static const String dangerThresholdKey   = 'danger_threshold';
  static const String fcmTokenKey          = 'fcm_token';
  static const String languageKey          = 'app_language';

  // --- ML & Sensor Thresholds ---
  static const double dangerScoreThreshold = 0.75;
  static const int sensorBufferSize       = 50;
  static const int sensorIntervalMs       = 20;
  static const int audioIntervalSeconds   = 3;
  static const int sosCountdownSeconds     = 10;

  // --- Networking & Timeouts ---
  static const int connectTimeoutSeconds = 15;
  static const int receiveTimeoutSeconds = 30;
  static const int sendTimeoutSeconds    = 30;
  static const int pageSize              = 20;

  // --- Notification Channels ---
  static const String sosChannelId      = 'safeher_sos';
  static const String sosChannelName    = 'SOS Alerts';
  static const String locationChannelId = 'safeher_location';
  static const String locationChannelName = 'Location Tracking';
  static const String generalChannelId  = 'safeher_system';
  static const String generalChannelName = 'SafeHer System';

  // --- Validation Regex Patterns ---
  static const String emailRegex = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
  static const String phoneRegex = r'^\+?[1-9]\d{9,14}$';
  static const String passwordRegex = r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$';

  // --- User-Facing Messages ---
  static const String networkError = 'No internet connection. Please check your network.';
  static const String serverError  = 'SafeHer AI is warming up. Please wait...';
  static const String authError    = 'Session expired. Please login again.';
  static const String unknownError = 'AI Sentinel encountered a glitch. Retrying...';
}