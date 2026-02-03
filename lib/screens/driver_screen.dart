import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class DriverScreen extends StatefulWidget {
  final String? fcmToken;
  
  const DriverScreen({super.key, this.fcmToken});

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  final LocationService _locationService = LocationService();
  final TextEditingController _parentTokenController = TextEditingController();
  
  LatLng? _currentLocation;
  LatLng? _targetLocation;
  bool _isTracking = false;
  Timer? _trackingTimer;
  String? _tripId;
  String _trackingStatus = 'Ready to track';
  int _lastDistance = 0;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    // Pre-fill with the FCM token from home screen if available
    if (widget.fcmToken != null) {
      _parentTokenController.text = widget.fcmToken!;
    }
  }

  Future<void> _getCurrentLocation() async {
    final position = await _locationService.getCurrentLocation();
    if (position != null) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
    }
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _targetLocation = position;
    });
  }

  void _setCurrentAsTarget() async {
    await _getCurrentLocation();
    if (_currentLocation != null) {
      setState(() {
        _targetLocation = _currentLocation;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎯 Target set to current location')),
      );
    }
  }

  Future<void> _startTracking() async {
    if (_targetLocation == null || _parentTokenController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set target location and enter parent FCM token')),
      );
      return;
    }

    // Check server health first
    final apiService = ApiService();
    final isServerHealthy = await apiService.checkServerHealth();
    
    if (!isServerHealthy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Server is not reachable. Please start the backend server first.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    // Auto-create trip when starting tracking
    final autoTripId = 'TRIP_${DateTime.now().millisecondsSinceEpoch}';
    
    try {
      // No need to create trip - simplified approach
      _tripId = autoTripId;
      
      setState(() {
        _isTracking = true;
      });

      _trackingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        _sendLocationUpdate();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🚌 Driver tracking started - $autoTripId'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    }
  }

  Future<void> _sendLocationUpdate() async {
    final position = await _locationService.getCurrentLocation();
    if (position == null || _tripId == null || _targetLocation == null) return;

    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
    });

    // Check if locations are identical first
    final distance = _calculateDistance(
      position.latitude, position.longitude,
      _targetLocation!.latitude, _targetLocation!.longitude
    );
    
    print('📍 Sending location update:');
    print('   Current: ${position.latitude}, ${position.longitude}');
    print('   Target: ${_targetLocation!.latitude}, ${_targetLocation!.longitude}');
    print('   Distance: ${distance.toStringAsFixed(2)}m');
    
    // If locations are identical or very close, show target reached immediately
    if (distance < 10.0) {
      print('🎯 TARGET REACHED! Locations are identical!');
      setState(() {
        _trackingStatus = '🎯 TARGET REACHED! Distance: ${distance.toStringAsFixed(1)}m';
      });
      
      // Send local notification immediately
      _showLocalNotification();
      
      _stopTracking();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎯 Target reached! Locations are identical! Notification sent!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
      return; // Don't make API call if locations are identical
    }

    try {
      print('   URL: ${AppConstants.baseUrl}${AppConstants.trackLocationEndpoint}');
      print('   FCM Token: ${_parentTokenController.text.substring(0, 20)}...');
      
      final requestBody = {
        'tripId': _tripId,
        'currentLat': position.latitude,
        'currentLng': position.longitude,
        'targetLat': _targetLocation!.latitude,
        'targetLng': _targetLocation!.longitude,
        'parentFcmToken': _parentTokenController.text,
      };
      
      print('📤 Request body: $requestBody');
      
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.trackLocationEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 10));

      print('📡 API Response: ${response.statusCode}');
      print('📋 Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final serverDistance = data['distance'] ?? 0;
        final withinGeofence = data['withinGeofence'] == true;
        
        setState(() {
          _lastDistance = serverDistance;
          if (withinGeofence) {
            _trackingStatus = '🎯 TARGET REACHED! Distance: ${serverDistance}m';
          } else {
            _trackingStatus = '🔍 Tracking... Distance: ${serverDistance}m';
          }
        });
        
        print('📍 $_trackingStatus');
        
        if (withinGeofence || data['status']?.contains('Notification sent') == true) {
          _stopTracking();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎯 Target reached! Distance: ${serverDistance}m - Parent notified!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode} - ${response.body}');
        setState(() {
          _trackingStatus = '❌ Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      print('❌ Location update failed: $e');
      setState(() {
        _trackingStatus = '❌ Connection failed: $e';
      });
    }
  }
  
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters
    final double dLat = (lat2 - lat1) * (3.14159265359 / 180);
    final double dLon = (lon2 - lon1) * (3.14159265359 / 180);
    final double a = (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(lat1 * (3.14159265359 / 180)) * cos(lat2 * (3.14159265359 / 180)) * sin(dLon / 2) * sin(dLon / 2));
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  void _stopTracking() {
    _trackingTimer?.cancel();
    setState(() {
      _isTracking = false;
      _trackingStatus = 'Tracking stopped';
    });
  }
  
  void _showLocalNotification() async {
    print('📢 Showing local notification for target reached');
    
    // Send FCM notification using the notification service
    await _sendFCMNotification();
    
    // Show local feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.notifications, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text('🎯 Target Reached! FCM notification sent!'),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }
  
  Future<void> _sendFCMNotification() async {
    try {
      print('📤 Sending FCM notification to: ${_parentTokenController.text.substring(0, 20)}...');
      
      // Create a simple HTTP request to our server to send FCM
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.sendFcmEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': _parentTokenController.text,
          'title': 'Target Reached! 🎯',
          'body': 'Driver has arrived at the destination',
          'data': {
            'type': 'geofence_entered',
            'timestamp': DateTime.now().toIso8601String(),
          },
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('✅ FCM notification sent successfully!');
        print('📋 Response: $responseData');
      } else {
        print('❌ FCM failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ FCM notification failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚌 Driver App'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Trip Setup
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _parentTokenController,
                  decoration: const InputDecoration(
                    labelText: 'Parent FCM Token',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _setCurrentAsTarget,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Use Current as Target'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isTracking ? _stopTracking : _startTracking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isTracking ? Colors.red : Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(_isTracking ? 'Stop Tracking' : 'Start Tracking'),
                      ),
                    ),
                  ],
                ),
                
                // Tracking Status Display
                if (_isTracking)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12.0),
                    margin: const EdgeInsets.only(top: 8.0),
                    decoration: BoxDecoration(
                      color: _trackingStatus.contains('EXACT MATCH') 
                          ? Colors.green.shade100
                          : _trackingStatus.contains('Within geofence')
                              ? Colors.orange.shade100
                              : Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: _trackingStatus.contains('EXACT MATCH') 
                            ? Colors.green
                            : _trackingStatus.contains('Within geofence')
                                ? Colors.orange
                                : Colors.blue,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('📊 Tracking Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(_trackingStatus),
                        if (_tripId != null)
                          Text('Trip ID: $_tripId', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Location Display
          if (_currentLocation != null || _targetLocation != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  if (_currentLocation != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12.0),
                      margin: const EdgeInsets.only(bottom: 8.0),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('📍 Current Location:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('${_currentLocation!.latitude.toStringAsFixed(6)}, ${_currentLocation!.longitude.toStringAsFixed(6)}'),
                        ],
                      ),
                    ),
                  if (_targetLocation != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🎯 Target Location:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('${_targetLocation!.latitude.toStringAsFixed(6)}, ${_targetLocation!.longitude.toStringAsFixed(6)}'),
                        ],
                      ),
                    ),
                ],
              ),
            ),

          // Map
          Expanded(
            child: _currentLocation == null
                ? const Center(child: CircularProgressIndicator())
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _currentLocation!,
                      zoom: 15.0,
                    ),
                    onTap: _onMapTap,
                    markers: {
                      if (_currentLocation != null)
                        Marker(
                          markerId: const MarkerId('current'),
                          position: _currentLocation!,
                          infoWindow: const InfoWindow(title: '🚌 Driver Location'),
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                        ),
                      if (_targetLocation != null)
                        Marker(
                          markerId: const MarkerId('target'),
                          position: _targetLocation!,
                          infoWindow: const InfoWindow(title: '🎯 Target Location'),
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                        ),
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _parentTokenController.dispose();
    _trackingTimer?.cancel();
    super.dispose();
  }
}