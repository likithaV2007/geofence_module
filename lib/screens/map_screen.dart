import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/geofence_provider.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  final LocationService _locationService = LocationService();
  LatLng? _currentLocation;
  LatLng? _targetLocation;
  final TextEditingController _fcmTokenController = TextEditingController();
  bool _isTracking = false;
  Timer? _trackingTimer;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _startLocationUpdates();
  }

  void _startLocationUpdates() {
    Timer.periodic(const Duration(seconds: 3), (timer) {
      _getCurrentLocation();
    });
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

  void _checkLocationsMatch() async {
    if (_currentLocation == null || _targetLocation == null) return;
    
    final distance = _calculateDistance(
      _currentLocation!.latitude, _currentLocation!.longitude,
      _targetLocation!.latitude, _targetLocation!.longitude,
    );
    
    print('Distance: $distance meters'); // Debug log
    
    if (distance <= 50) {
      print('Locations match! Sending notification...'); // Debug log
      await _sendNotification();
      _stopTracking(); // Stop to prevent multiple notifications
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Earth radius in meters
    final double dLat = (lat2 - lat1) * (pi / 180);
    final double dLon = (lon2 - lon1) * (pi / 180);
    
    final double a = 
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) * cos(lat2 * (pi / 180)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    final double c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  void _useCurrentLocation() async {
    if (_currentLocation == null) {
      await _getCurrentLocation();
    }
    
    if (_currentLocation != null) {
      setState(() {
        _targetLocation = _currentLocation;
      });
    }
  }

  void _startTracking() {
    if (_targetLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set target location')),
      );
      return;
    }

    if (_fcmTokenController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter FCM token')),
      );
      return;
    }

    setState(() {
      _isTracking = true;
    });

    _trackingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkLocationsMatch();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tracking started')),
    );
  }

  void _stopTracking() {
    _trackingTimer?.cancel();
    setState(() {
      _isTracking = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tracking stopped')),
    );
  }

  void _getMyFCMToken() async {
    final notificationService = NotificationService();
    final token = await notificationService.getFCMToken();
    if (token != null) {
      setState(() {
        _fcmTokenController.text = token;
      });
      print('FCM Token: $token');
    }
  }

  Future<void> _sendNotification() async {
    if (_fcmTokenController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter FCM token')),
      );
      return;
    }

    final fcmToken = _fcmTokenController.text.trim();
    print('Sending notification to FCM token: $fcmToken');

    try {
      // Send direct HTTP request to backend
      final response = await http.post(
        Uri.parse('http://192.168.1.40:3000/api/geofence/trigger'), 
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'geofenceId': 'LOCATION_MATCH_${DateTime.now().millisecondsSinceEpoch}',
          'fcmToken': fcmToken,
          'event': 'TARGET_REACHED',
        }),
      );

      print('Backend response: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Notification sent successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed: ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('❌ Error sending notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Picker'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // FCM Token Input
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _fcmTokenController,
                  decoration: const InputDecoration(
                    labelText: 'FCM Token',
                    border: OutlineInputBorder(),
                    hintText: 'Enter your FCM token',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _getMyFCMToken,
                  child: const Text('Get My FCM Token'),
                ),
              ],
            ),
          ),
          
          // Location Selection Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _useCurrentLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Set Target to Current'),
                  ),
                ),
              ],
            ),
          ),
          
          // Location Display
          Padding(
            padding: const EdgeInsets.all(16.0),
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
                        const Text('Current Location:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        const Text('Target Location:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    onMapCreated: (GoogleMapController controller) {
                      _controller = controller;
                    },
                    onTap: _onMapTap,
                    markers: {
                      if (_currentLocation != null)
                        Marker(
                          markerId: const MarkerId('current'),
                          position: _currentLocation!,
                          infoWindow: const InfoWindow(title: 'Current Location'),
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                        ),
                      if (_targetLocation != null)
                        Marker(
                          markerId: const MarkerId('target'),
                          position: _targetLocation!,
                          infoWindow: const InfoWindow(title: 'Target Location'),
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                        ),
                    },
                  ),
          ),
          
          // Start Tracking Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isTracking ? _stopTracking : _startTracking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isTracking ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                ),
                child: Text(
                  _isTracking ? 'Stop Tracking' : 'Start Tracking',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fcmTokenController.dispose();
    _trackingTimer?.cancel();
    super.dispose();
  }
}