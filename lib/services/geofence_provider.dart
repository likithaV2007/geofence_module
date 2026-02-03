import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/location_data.dart';
import '../services/location_service.dart';
import '../services/background_location_service.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';

class GeofenceProvider extends ChangeNotifier {
  GeofenceData? _activeGeofence;
  LocationData? _currentLocation;
  LocationData? _startLocation;
  LocationData? _targetLocation;
  bool _isTracking = false;
  bool _hasPermissions = false;
  String? _targetAddress;
  DateTime? _lastLocationUpdate;
  String? _customFcmToken;

  GeofenceData? get activeGeofence => _activeGeofence;
  LocationData? get currentLocation => _currentLocation;
  LocationData? get startLocation => _startLocation;
  LocationData? get targetLocation => _targetLocation;
  String? get targetAddress => _targetAddress;
  bool get isTracking => _isTracking;
  bool get hasPermissions => _hasPermissions;
  bool get canCreateGeofence =>
      _startLocation != null && _targetLocation != null;
  String? get customFcmToken => _customFcmToken;

  void setCustomFcmToken(String token) {
    _customFcmToken = token;
    notifyListeners();
  }

  final LocationService _locationService = LocationService();
  final BackgroundLocationService _backgroundService =
      BackgroundLocationService();
  final ApiService _apiService = ApiService();

  Future<void> initialize() async {
    await _loadStoredGeofence();
    await _checkPermissions();
    await _getCurrentLocation();

    if (_activeGeofence != null && !_activeGeofence!.isNotified) {
      await startTracking();
    }
  }

  Future<void> _checkPermissions() async {
    _hasPermissions =
        await _locationService.requestPermissions() &&
        await _locationService.isLocationServiceEnabled();
    notifyListeners();
  }

  Future<void> _getCurrentLocation() async {
    _currentLocation = await _locationService.getCurrentLocation();
    _lastLocationUpdate = DateTime.now();
    notifyListeners();
  }

  Future<void> setStartLocation(LocationData location) async {
    if (!_locationService.isAccuracyAcceptable(location)) return;

    _startLocation = location;
    notifyListeners();
  }

  Future<void> setTargetLocation(LocationData location) async {
    if (!_locationService.isAccuracyAcceptable(location)) return;

    _targetLocation = location;

    // Get address for target location
    _targetAddress = await _locationService.getAddressFromCoordinates(
      location.latitude,
      location.longitude,
    );

    notifyListeners();
  }

  Future<void> useCurrentLocation() async {
    await _getCurrentLocation();
    if (_currentLocation != null) {
      if (_startLocation == null) {
        await setStartLocation(_currentLocation!);
      } else if (_targetLocation == null) {
        await setTargetLocation(_currentLocation!);
      }
    }
  }

  Future<bool> createGeofence({double? radius}) async {
    if (!canCreateGeofence) return false;

    final geofenceRadius = radius ?? AppConstants.defaultGeofenceRadius;

    // Validate radius constraints
    if (geofenceRadius < AppConstants.minGeofenceRadius ||
        geofenceRadius > AppConstants.maxGeofenceRadius) {
      return false;
    }

    final geofence = GeofenceData(
      id: const Uuid().v4(),
      startLocation: _startLocation!,
      targetLocation: _targetLocation!,
      radius: geofenceRadius,
      createdAt: DateTime.now(),
    );

    _activeGeofence = geofence;
    await _saveGeofence();

    // Register with backend
    await _apiService.registerGeofence(geofence.toJson());

    notifyListeners();
    return true;
  }

  Future<void> startTracking() async {
    if (!_hasPermissions || _activeGeofence == null) return;

    _isTracking = await _backgroundService.start();

    if (_isTracking) {
      _locationService.startLocationTracking();
      _locationService.locationStream.listen(_onLocationUpdate);

      // Check immediately if start and target are already equal
      _checkAndTriggerIfEqual();
    }

    notifyListeners();
  }

  Future<void> stopTracking() async {
    await _backgroundService.stop();
    _locationService.stopLocationTracking();
    _isTracking = false;
    notifyListeners();
  }

  void _onLocationUpdate(LocationData location) {
    _currentLocation = location;
    _lastLocationUpdate = DateTime.now();

    if (_activeGeofence != null && !_activeGeofence!.isNotified) {
      final isInside = _locationService.isWithinGeofence(
        location,
        _activeGeofence!.targetLocation,
        _activeGeofence!.radius,
      );

      if (isInside) {
        _markGeofenceAsNotified();
      }
    }

    notifyListeners();
  }

  Future<void> _markGeofenceAsNotified() async {
    if (_activeGeofence != null) {
      _activeGeofence = _activeGeofence!.copyWith(isNotified: true);
      await _saveGeofence();

      // Trigger API call
      await _apiService.triggerGeofenceEvent(
        _activeGeofence!.id,
        customFcmToken: _customFcmToken,
      );

      // Show local notification as feedback
      await NotificationService().showGeofenceNotification();

      notifyListeners();
    }
  }

  void _checkAndTriggerIfEqual() {
    if (_startLocation != null && _targetLocation != null) {
      final distance = _locationService.calculateDistance(
        _startLocation!,
        _targetLocation!,
      );
      
      print('🔍 Checking if start and target are equal:');
      print('   Start: ${_startLocation!.latitude}, ${_startLocation!.longitude}');
      print('   Target: ${_targetLocation!.latitude}, ${_targetLocation!.longitude}');
      print('   Distance: ${distance.toStringAsFixed(2)}m');
      
      // If distance is less than 1 meter, consider them equal
      if (distance < 1.0) {
        print('✅ Locations are equal! Triggering instant notification...');
        _triggerInstantNotification();
      } else {
        print('📍 Locations are different, normal tracking will proceed');
      }
    }
  }

  Future<void> _triggerInstantNotification() async {
    print('📢 Triggering instant notification for equal locations...');
    
    // If we have an active geofence, mark it notified
    if (_activeGeofence != null) {
      print('📍 Using active geofence: ${_activeGeofence!.id}');
      await _markGeofenceAsNotified();
    } else {
      print('📍 No active geofence, sending direct API call');
      // If no geofence yet, just send the API event with a temporary ID
      await _apiService.triggerGeofenceEvent(
        'INSTANT_EQUALITY_TRIGGER',
        customFcmToken: _customFcmToken,
      );
      await NotificationService().showGeofenceNotification();
    }
  }

  Future<void> resetGeofence() async {
    _activeGeofence = null;
    _startLocation = null;
    _targetLocation = null;
    _targetAddress = null;

    await stopTracking();
    await _clearStoredGeofence();
    _apiService.clearProcessedGeofences();

    notifyListeners();
  }

  bool get isLocationStale {
    if (_lastLocationUpdate == null) return true;
    return DateTime.now().difference(_lastLocationUpdate!).inMinutes > 5;
  }

  double? get distanceToTarget {
    if (_currentLocation == null || _targetLocation == null) return null;
    return _locationService.calculateDistance(
      _currentLocation!,
      _targetLocation!,
    );
  }

  Future<void> _saveGeofence() async {
    if (_activeGeofence != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'active_geofence',
        jsonEncode(_activeGeofence!.toJson()),
      );
    }
  }

  Future<void> _loadStoredGeofence() async {
    final prefs = await SharedPreferences.getInstance();
    final geofenceJson = prefs.getString('active_geofence');

    if (geofenceJson != null) {
      try {
        _activeGeofence = GeofenceData.fromJson(jsonDecode(geofenceJson));
        _startLocation = _activeGeofence!.startLocation;
        _targetLocation = _activeGeofence!.targetLocation;

        // Reload target address
        if (_targetLocation != null) {
          _targetAddress = await _locationService.getAddressFromCoordinates(
            _targetLocation!.latitude,
            _targetLocation!.longitude,
          );
        }
      } catch (e) {
        await _clearStoredGeofence();
      }
    }
  }

  Future<void> sendLocationMatchNotification(String fcmToken) async {
    await _apiService.triggerGeofenceEvent(
      'LOCATION_MATCH',
      customFcmToken: fcmToken,
    );
    
    await NotificationService().showGeofenceNotification();
  }

  Future<void> _clearStoredGeofence() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_geofence');
  }
}
