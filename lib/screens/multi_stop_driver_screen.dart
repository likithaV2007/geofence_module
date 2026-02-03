import 'package:flutter/material.dart';
import 'package:location/location.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

class MultiStopDriverScreen extends StatefulWidget {
  @override
  _MultiStopDriverScreenState createState() => _MultiStopDriverScreenState();
}

class _MultiStopDriverScreenState extends State<MultiStopDriverScreen> {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  final TextEditingController _tripIdController = TextEditingController();
  final List<Map<String, dynamic>> _stops = [];
  
  bool _isTracking = false;
  String _status = 'Ready to start';
  LocationData? _currentLocation;
  String? _currentTripId;
  int _currentStopIndex = 0;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _tripIdController.text = 'trip_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _getCurrentLocation() async {
    try {
      _currentLocation = await _locationService.getCurrentLocation();
      setState(() {});
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  void _addStop(double lat, double lng, String fcmToken) {
    setState(() {
      _stops.add({
        'lat': lat,
        'lng': lng,
        'fcmToken': fcmToken,
      });
    });
  }

  void _showAddStopDialog() {
    final latController = TextEditingController();
    final lngController = TextEditingController();
    final fcmController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Stop ${_stops.length + 1}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latController,
              decoration: InputDecoration(labelText: 'Latitude'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: lngController,
              decoration: InputDecoration(labelText: 'Longitude'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: fcmController,
              decoration: InputDecoration(labelText: 'FCM Token'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (latController.text.isNotEmpty && 
                  lngController.text.isNotEmpty && 
                  fcmController.text.isNotEmpty) {
                _addStop(
                  double.parse(latController.text),
                  double.parse(lngController.text),
                  fcmController.text,
                );
                Navigator.pop(context);
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _startTracking() async {
    if (_tripIdController.text.isEmpty || _stops.isEmpty || _currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Add trip ID, stops, and ensure location is available')),
      );
      return;
    }

    setState(() {
      _isTracking = true;
      _status = 'Starting tracking...';
      _currentTripId = _tripIdController.text;
      _currentStopIndex = 0;
    });

    final success = await _apiService.startMultiStopTracking(
      tripId: _currentTripId!,
      stops: _stops,
      currentLat: _currentLocation!.latitude!,
      currentLng: _currentLocation!.longitude!,
    );

    if (success) {
      setState(() {
        _status = 'Tracking active - Stop 1 notified in 5 min';
      });
      _startLocationTracking();
    } else {
      setState(() {
        _isTracking = false;
        _status = 'Failed to start tracking';
      });
    }
  }

  void _startLocationTracking() {
    _locationService.startLocationUpdates((location) async {
      if (_isTracking && _currentTripId != null) {
        final success = await _apiService.trackMultiStopLocation(
          tripId: _currentTripId!,
          currentLat: location.latitude!,
          currentLng: location.longitude!,
        );
        
        setState(() {
          _currentLocation = location;
          if (success) {
            _status = 'Tracking - Stop ${_currentStopIndex + 1}/${_stops.length}';
          }
        });
      }
    });
  }

  void _stopTracking() {
    setState(() {
      _isTracking = false;
      _status = 'Tracking stopped';
      _currentTripId = null;
      _currentStopIndex = 0;
    });
    _locationService.stopLocationUpdates();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Multi-Stop Tracking'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Trip ID
            TextField(
              controller: _tripIdController,
              decoration: InputDecoration(
                labelText: 'Trip ID',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.trip_origin),
              ),
            ),
            SizedBox(height: 16),
            
            // Stops Section
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Stops (${_stops.length})', 
                             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ElevatedButton.icon(
                          onPressed: _isTracking ? null : _showAddStopDialog,
                          icon: Icon(Icons.add),
                          label: Text('Add Stop'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    if (_stops.isEmpty)
                      Container(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text('No stops added yet\nTap "Add Stop" to begin',
                                     textAlign: TextAlign.center,
                                     style: TextStyle(color: Colors.grey)),
                        ),
                      )
                    else
                      Container(
                        height: 150,
                        child: ListView.builder(
                          itemCount: _stops.length,
                          itemBuilder: (context, index) {
                            final stop = _stops[index];
                            final isActive = _isTracking && index == _currentStopIndex;
                            return Card(
                              color: isActive ? Colors.orange.shade100 : null,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isActive ? Colors.orange : Colors.grey,
                                  child: Text('${index + 1}'),
                                ),
                                title: Text('Stop ${index + 1}'),
                                subtitle: Text('${stop['lat']}, ${stop['lng']}'),
                                trailing: _isTracking ? null : IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => setState(() => _stops.removeAt(index)),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Status Card
            Card(
              color: _isTracking ? Colors.green.shade50 : Colors.grey.shade50,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(_isTracking ? Icons.gps_fixed : Icons.gps_off,
                             color: _isTracking ? Colors.green : Colors.grey),
                        SizedBox(width: 8),
                        Text('Status: $_status', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                    if (_currentLocation != null) ...[
                      SizedBox(height: 8),
                      Text('Location: ${_currentLocation!.latitude!.toStringAsFixed(6)}, ${_currentLocation!.longitude!.toStringAsFixed(6)}',
                           style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ],
                ),
              ),
            ),
            
            Spacer(),
            
            // Control Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isTracking ? null : (_stops.isNotEmpty ? _startTracking : null),
                    icon: Icon(Icons.play_arrow),
                    label: Text('Start Tracking'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isTracking ? _stopTracking : null,
                    icon: Icon(Icons.stop),
                    label: Text('Stop Tracking'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _locationService.stopLocationUpdates();
    super.dispose();
  }
}