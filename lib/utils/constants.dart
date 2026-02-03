class AppConstants {
  // Backend Configuration - Choose based on your setup
  
  // For local development (same network)
  static const String _localUrl = 'http://localhost:3000';
  
  // For Android emulator
  static const String _emulatorUrl = 'http://10.0.2.2:3000';
  
  // For remote access - UPDATE WITH YOUR NGROK URL
  static const String _remoteUrl = 'https://your-ngrok-url.ngrok-free.dev';
  
  // For production deployment
  static const String _productionUrl = 'https://your-production-url.com';
  
  // Current active URL - CHANGE THIS BASED ON YOUR SETUP
  static const String baseUrl = _productionUrl; // Ready for production hosting
  
  static const String trackLocationEndpoint = '/track-location';
  static const String sendFcmEndpoint = '/send-fcm';
  static const String healthEndpoint = '/health';
  
  // Performance Requirements
  static const int maxAppLaunchTimeMs = 2500;
  static const int maxMapRenderTimeMs = 3000;
  static const int maxApiResponseTimeMs = 500;
  static const int maxNotificationDelayMs = 5000;
  
  // Geofence Configuration
  static const double minGeofenceRadius = 30.0;
  static const double maxGeofenceRadius = 500.0;
  static const double defaultGeofenceRadius = 50.0;
  static const double geofenceAccuracyTolerance = 10.0;
  
  // Location Tracking
  static const int locationUpdateIntervalSeconds = 5;
  static const double minDistanceFilterMeters = 10.0;
  static const double maxAcceptableAccuracy = 50.0;
  
  // Retry Configuration
  static const int maxRetryAttempts = 3;
  static const int baseRetryDelayMs = 1000;
  
  // Resource Limits
  static const int maxMemoryUsageMB = 100;
  static const double maxBatteryDrainPerHour = 5.0;
  static const double maxCpuUsagePercent = 10.0;
  
  // Success Thresholds
  static const double minGeofenceSuccessRate = 0.98;
  static const double minBackgroundUptimeRate = 0.95;
  static const double minNotificationDeliveryRate = 0.99;
}