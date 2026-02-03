import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'notification_service.dart';
import '../utils/constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const String baseUrl = 'http://localhost:3000';
  final Set<String> _processedTrips = {};

  Future<bool> checkServerHealth() async {
    try {
      print('🏥 Checking server health...');
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(Duration(milliseconds: 5000));
      
      print('Health check response: ${response.statusCode} - ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Health check failed: $e');
      return false;
    }
  }

  Future<bool> createTrip({
    required String tripId,
    required String driverId,
    required String parentId,
    required double targetLat,
    required double targetLng,
    required String parentFcmToken,
  }) async {
    try {
      final success = await _makeApiCallWithRetry('/trip/create', {
        'tripId': tripId,
        'driverId': driverId,
        'parentId': parentId,
        'targetLat': targetLat,
        'targetLng': targetLng,
        'parentFcmToken': parentFcmToken,
      });

      return success;
    } catch (e) {
      print('Create trip error: $e');
      return false;
    }
  }

  Future<bool> startMultiStopTracking({
    required String tripId,
    required List<Map<String, dynamic>> stops,
    required double currentLat,
    required double currentLng,
  }) async {
    try {
      return await _makeApiCallWithRetry('/start-multi-stop-tracking', {
        'tripId': tripId,
        'stops': stops,
        'currentLat': currentLat,
        'currentLng': currentLng,
      });
    } catch (e) {
      print('Start multi-stop tracking error: $e');
      return false;
    }
  }

  Future<bool> trackMultiStopLocation({
    required String tripId,
    required double currentLat,
    required double currentLng,
  }) async {
    try {
      return await _makeApiCallWithRetry('/track-multi-stop-location', {
        'tripId': tripId,
        'currentLat': currentLat,
        'currentLng': currentLng,
      });
    } catch (e) {
      print('Track multi-stop location error: $e');
      return false;
    }
  }

  Future<bool> updateDriverLocation({
    required String tripId,
    required double currentLat,
    required double currentLng,
    required double targetLat,
    required double targetLng,
    required String parentFcmToken,
  }) async {
    // Prevent duplicate API calls for same location
    final locationKey = '${tripId}_${currentLat.toStringAsFixed(6)}_${currentLng.toStringAsFixed(6)}';
    if (_processedTrips.contains(locationKey)) return true;

    try {
      final success = await _makeApiCallWithRetry('/track-location', {
        'tripId': tripId,
        'currentLat': currentLat,
        'currentLng': currentLng,
        'targetLat': targetLat,
        'targetLng': targetLng,
        'parentFcmToken': parentFcmToken,
      });

      if (success) {
        _processedTrips.add(locationKey);
      }

      return success;
    } catch (e) {
      print('Update location error: $e');
      return false;
    }
  }

  Future<bool> triggerGeofenceEvent(
    String geofenceId, {
    String? customFcmToken,
  }) async {
    print('📡 Triggering geofence event: $geofenceId');
    
    if (customFcmToken == null) {
      print('⚠️ No FCM token provided for geofence event');
      return false;
    }
    
    // For instant equality triggers, send a direct notification
    if (geofenceId == 'INSTANT_EQUALITY_TRIGGER') {
      return await _sendDirectNotification(customFcmToken);
    }
    
    // For other geofence events, this would integrate with the main tracking logic
    return true;
  }
  
  Future<bool> _sendDirectNotification(String fcmToken) async {
    try {
      print('📤 Sending direct FCM notification for location match...');
      
      final success = await _makeApiCallWithRetry('/track-location', {
        'tripId': 'LOCATION_MATCH_${DateTime.now().millisecondsSinceEpoch}',
        'currentLat': 0.0, // Placeholder - exact match scenario
        'currentLng': 0.0, // Placeholder - exact match scenario  
        'targetLat': 0.0,  // Placeholder - exact match scenario
        'targetLng': 0.0,  // Placeholder - exact match scenario
        'parentFcmToken': fcmToken,
      });
      
      if (success) {
        print('✅ Direct notification sent successfully');
      } else {
        print('❌ Direct notification failed');
      }
      
      return success;
    } catch (e) {
      print('❌ Direct notification error: $e');
      return false;
    }
  }

  Future<bool> registerGeofence(Map<String, dynamic> geofenceData) async {
    // Legacy method - redirect to createTrip
    return true;
  }

  Future<bool> _makeApiCallWithRetry(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    for (int attempt = 1; attempt <= AppConstants.maxRetryAttempts; attempt++) {
      try {
        print('API Call: $baseUrl$endpoint with data: $data');
        
        final response = await http
            .post(
              Uri.parse('$baseUrl$endpoint'),
              headers: {
                'Content-Type': 'application/json',
              },
              body: jsonEncode(data),
            )
            .timeout(Duration(milliseconds: AppConstants.maxApiResponseTimeMs));

        print('API Response: ${response.statusCode} - ${response.body}');
        
        if (response.statusCode == 200) return true;

        // Don't retry for client errors (4xx)
        if (response.statusCode >= 400 && response.statusCode < 500) {
          return false;
        }
      } catch (e) {
        print('API Error (attempt $attempt): $e');
        if (attempt == AppConstants.maxRetryAttempts) return false;
      }

      // Exponential backoff
      await Future.delayed(
        Duration(
          milliseconds: AppConstants.baseRetryDelayMs * (1 << (attempt - 1)),
        ),
      );
    }

    return false;
  }

  void clearProcessedTrips() {
    _processedTrips.clear();
  }

  // Legacy method
  void clearProcessedGeofences() {
    clearProcessedTrips();
  }
}
