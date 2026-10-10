class Device {
  final String id;
  final String name;
  final bool online;
  final int lastSeen;

  Device({
    required this.id,
    required this.name,
    required this.online,
    required this.lastSeen,
  });

  factory Device.fromMap(String id, Map<dynamic, dynamic> map) {
    return Device(
      id: id,
      name: map['name'] ?? 'Unknown',
      online: map['online'] ?? false,
      lastSeen: map['lastSeen'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'online': online,
      'lastSeen': lastSeen,
    };
  }
}