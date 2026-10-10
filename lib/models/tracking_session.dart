class LocationData {
  final double lat;
  final double lng;
  final double heading;
  final int timestamp;

  LocationData({
    required this.lat,
    required this.lng,
    required this.heading,
    required this.timestamp,
  });

  factory LocationData.fromMap(Map<dynamic, dynamic> map) {
    return LocationData(
      lat: (map['lat'] ?? 0).toDouble(),
      lng: (map['lng'] ?? 0).toDouble(),
      heading: (map['heading'] ?? 0).toDouble(),
      timestamp: map['timestamp'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lat': lat,
      'lng': lng,
      'heading': heading,
      'timestamp': timestamp,
    };
  }
}

class TrackingSession {
  final String id;
  final String deviceAId;
  final String deviceBId;
  final bool active;
  final LocationData? locationA;
  final LocationData? locationB;

  TrackingSession({
    required this.id,
    required this.deviceAId,
    required this.deviceBId,
    required this.active,
    this.locationA,
    this.locationB,
  });
}