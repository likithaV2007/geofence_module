import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart';
import '../models/location_data.dart';
import '../utils/constants.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamController<LocationData>? _locationController;
  StreamSubscription<Position>? _positionSubscription;

  Stream<LocationData> get locationStream => _locationController!.stream;

  Future<bool> requestPermissions() async {
    final locationWhenInUse = await Permission.locationWhenInUse.request();
    if (locationWhenInUse != PermissionStatus.granted) return false;

    final locationAlways = await Permission.locationAlways.request();
    return locationAlways == PermissionStatus.granted;
  }

  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  Future<LocationData?> getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Validate accuracy
      if (position.accuracy > AppConstants.maxAcceptableAccuracy) {
        return null;
      }

      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  Future<String?> getAddressFromCoordinates(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return '${place.street}, ${place.locality}, ${place.country}';
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  void startLocationTracking() {
    _locationController ??= StreamController<LocationData>.broadcast();

    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: AppConstants.minDistanceFilterMeters.toInt(),
    );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (position) {
            if (position.accuracy <= AppConstants.maxAcceptableAccuracy) {
              _locationController?.add(
                LocationData(
                  latitude: position.latitude,
                  longitude: position.longitude,
                  accuracy: position.accuracy,
                  timestamp: DateTime.now(),
                ),
              );
            }
          },
        );
  }

  void stopLocationTracking() {
    _positionSubscription?.cancel();
    _locationController?.close();
    _locationController = null;
  }

  double calculateDistance(LocationData from, LocationData to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  bool isWithinGeofence(
    LocationData current,
    LocationData target,
    double radius,
  ) {
    final distance = calculateDistance(current, target);
    return distance <= radius;
  }

  bool isAccuracyAcceptable(LocationData location) {
    return location.accuracy != null &&
        location.accuracy! <= AppConstants.geofenceAccuracyTolerance;
  }
}
