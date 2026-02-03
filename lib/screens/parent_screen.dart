import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/notification_service.dart';

class ParentScreen extends StatefulWidget {
  const ParentScreen({super.key});

  @override
  State<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen> {
  final NotificationService _notificationService = NotificationService();
  String? _fcmToken;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    await _notificationService.initialize();
    
    // Get FCM token
    _fcmToken = await _notificationService.getFCMToken();
    setState(() {});

    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📱 Foreground notification received');
      _addNotification(message);
    });

    // Listen for background message taps
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📱 Background notification tapped');
      _addNotification(message);
    });

    // Check for initial message (app opened from killed state)
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('📱 App opened from killed state');
        _addNotification(message);
      }
    });
  }

  void _addNotification(RemoteMessage message) {
    setState(() {
      _notifications.insert(0, {
        'title': message.notification?.title ?? 'No Title',
        'body': message.notification?.body ?? 'No Body',
        'data': message.data,
        'timestamp': DateTime.now(),
      });
    });

    // Show local notification for foreground messages
    _notificationService.showGeofenceNotification();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('👨‍👩‍👧‍👦 Parent App'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // FCM Token Display
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🔑 Your FCM Token:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  _fcmToken ?? 'Loading...',
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 8),
                const Text(
                  '📋 Copy this token and paste it in the Driver App',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),

          // Notifications List
          Expanded(
            child: _notifications.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No notifications yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Waiting for driver to reach destination...',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.notifications, color: Colors.green),
                          title: Text(
                            notification['title'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(notification['body']),
                              const SizedBox(height: 4),
                              Text(
                                'Received: ${_formatTime(notification['timestamp'])}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              if (notification['data'].isNotEmpty)
                                Text(
                                  'Trip ID: ${notification['data']['tripId'] ?? 'N/A'}',
                                  style: const TextStyle(fontSize: 12, color: Colors.blue),
                                ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
          ),

          // Status Bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border(top: BorderSide(color: Colors.green.shade200)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      _notifications.isEmpty ? Icons.radio_button_unchecked : Icons.check_circle,
                      color: _notifications.isEmpty ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _notifications.isEmpty 
                          ? 'Waiting for notifications...' 
                          : '${_notifications.length} notification(s) received',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '✅ App works in foreground, background, and killed state',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }
}