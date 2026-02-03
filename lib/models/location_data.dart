class LocationData {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime timestamp;

  LocationData({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'timestamp': timestamp.toIso8601String(),
  };

  factory LocationData.fromJson(Map<String, dynamic> json) => LocationData(
    latitude: json['latitude'],
    longitude: json['longitude'],
    accuracy: json['accuracy'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}

class GeofenceData {
  final String id;
  final LocationData startLocation;
  final LocationData targetLocation;
  final double radius;
  final bool isActive;
  final bool isNotified;
  final DateTime createdAt;

  GeofenceData({
    required this.id,
    required this.startLocation,
    required this.targetLocation,
    required this.radius,
    this.isActive = true,
    this.isNotified = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'startLocation': startLocation.toJson(),
    'targetLocation': targetLocation.toJson(),
    'radius': radius,
    'isActive': isActive,
    'isNotified': isNotified,
    'createdAt': createdAt.toIso8601String(),
  };

  factory GeofenceData.fromJson(Map<String, dynamic> json) => GeofenceData(
    id: json['id'],
    startLocation: LocationData.fromJson(json['startLocation']),
    targetLocation: LocationData.fromJson(json['targetLocation']),
    radius: json['radius'],
    isActive: json['isActive'] ?? true,
    isNotified: json['isNotified'] ?? false,
    createdAt: DateTime.parse(json['createdAt']),
  );

  GeofenceData copyWith({
    String? id,
    LocationData? startLocation,
    LocationData? targetLocation,
    double? radius,
    bool? isActive,
    bool? isNotified,
    DateTime? createdAt,
  }) => GeofenceData(
    id: id ?? this.id,
    startLocation: startLocation ?? this.startLocation,
    targetLocation: targetLocation ?? this.targetLocation,
    radius: radius ?? this.radius,
    isActive: isActive ?? this.isActive,
    isNotified: isNotified ?? this.isNotified,
    createdAt: createdAt ?? this.createdAt,
  );
}