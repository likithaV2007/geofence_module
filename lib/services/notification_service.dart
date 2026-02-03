import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  DateTime? _lastNotificationTime;

  Future<void> initialize() async {
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      await _requestPermissions();
      await _setupFirebaseMessaging();
      await _createNotificationChannel();
      
      print('✅ NotificationService initialized successfully');
    } catch (e) {
      print('❌ NotificationService initialization failed: $e');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      // Request FCM permissions
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      
      print('✅ FCM permission status: ${settings.authorizationStatus}');

      // Request local notification permissions for Android 13+
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
          
      print('✅ Local notification permissions requested');
    } catch (e) {
      print('❌ Permission request failed: $e');
    }
  }

  Future<void> _setupFirebaseMessaging() async {
    try {
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      
      // Get and log FCM token
      final token = await _firebaseMessaging.getToken();
      print('✅ FCM Token: $token');
      
    } catch (e) {
      print('❌ Firebase Messaging setup failed: $e');
    }
  }

  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      'geofence_channel',
      'Geofence Notifications',
      description: 'Notifications when entering geofence areas',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
        
    print('✅ Notification channel created');
  }

  Future<String?> getFCMToken() async {
    try {
      // Ensure Firebase is initialized
      await _firebaseMessaging.requestPermission();
      
      // Get the token
      final token = await _firebaseMessaging.getToken();
      print('✅ FCM Token retrieved: ${token?.substring(0, 20)}...');
      return token;
    } catch (e) {
      print('❌ Error getting FCM token: $e');
      return null;
    }
  }

  Future<bool> showGeofenceNotification() async {
    // Prevent duplicate notifications within 30 seconds
    final now = DateTime.now();
    if (_lastNotificationTime != null && 
        now.difference(_lastNotificationTime!).inSeconds < 30) {
      return false;
    }
    
    _lastNotificationTime = now;
    
    const androidDetails = AndroidNotificationDetails(
      'geofence_channel',
      'Geofence Notifications',
      channelDescription: 'Notifications when entering geofence areas',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _localNotifications.show(
        1,
        'Location Reached 🎯',
        'You have arrived at your target location!',
        notificationDetails,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    // Handle local notification tap
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('📱 Foreground FCM received: ${message.notification?.title}');
    // Show local notification for foreground messages
    showGeofenceNotification();
  }

  void _handleNotificationTap(RemoteMessage message) {
    print('📱 FCM notification tapped: ${message.notification?.title}');
    // Handle FCM notification tap - could navigate to specific screen
  }
}

@pragma('vm:entry-point')
Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  print('📱 Background FCM received: ${message.notification?.title}');
  // Handle FCM message when app is in background
  // Note: You cannot show local notifications from background handler
}