import 'dart:async';

class BgLocationData {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime timestamp;

  BgLocationData({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.timestamp,
  });
}

class BgGeofenceData {
  final String id;
  final BgLocationData startLocation;
  final BgLocationData targetLocation;
  final double radius;
  final bool isActive;
  final bool isNotified;
  final DateTime createdAt;

  BgGeofenceData({
    required this.id,
    required this.startLocation,
    required this.targetLocation,
    required this.radius,
    this.isActive = true,
    this.isNotified = false,
    required this.createdAt,
  });

  factory BgGeofenceData.fromJson(Map<String, dynamic> json) => BgGeofenceData(
    id: json['id'],
    startLocation: BgLocationData(
      latitude: json['startLocation']['latitude'],
      longitude: json['startLocation']['longitude'],
      accuracy: json['startLocation']['accuracy'],
      timestamp: DateTime.parse(json['startLocation']['timestamp']),
    ),
    targetLocation: BgLocationData(
      latitude: json['targetLocation']['latitude'],
      longitude: json['targetLocation']['longitude'],
      accuracy: json['targetLocation']['accuracy'],
      timestamp: DateTime.parse(json['targetLocation']['timestamp']),
    ),
    radius: json['radius'],
    isActive: json['isActive'] ?? true,
    isNotified: json['isNotified'] ?? false,
    createdAt: DateTime.parse(json['createdAt']),
  );

  BgGeofenceData copyWith({bool? isNotified}) => BgGeofenceData(
    id: id,
    startLocation: startLocation,
    targetLocation: targetLocation,
    radius: radius,
    isActive: isActive,
    isNotified: isNotified ?? this.isNotified,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'startLocation': {
      'latitude': startLocation.latitude,
      'longitude': startLocation.longitude,
      'accuracy': startLocation.accuracy,
      'timestamp': startLocation.timestamp.toIso8601String(),
    },
    'targetLocation': {
      'latitude': targetLocation.latitude,
      'longitude': targetLocation.longitude,
      'accuracy': targetLocation.accuracy,
      'timestamp': targetLocation.timestamp.toIso8601String(),
    },
    'radius': radius,
    'isActive': isActive,
    'isNotified': isNotified,
    'createdAt': createdAt.toIso8601String(),
  };
}

class BackgroundLocationService {
  Timer? _timer;
  bool _isRunning = false;

  Future<bool> start() async {
    if (_isRunning) return true;

    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkGeofence();
    });

    return true;
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
  }

  Future<bool> isRunning() async {
    return _isRunning;
  }

  void _checkGeofence() {
    // Simplified geofence check - would integrate with location service
    // For now, just a placeholder
  }
}
