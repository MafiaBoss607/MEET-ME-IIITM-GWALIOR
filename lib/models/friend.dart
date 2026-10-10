class Friend {
  final String id;
  final String name;
  final int addedAt;

  Friend({
    required this.id,
    required this.name,
    required this.addedAt,
  });

  factory Friend.fromMap(String id, Map<dynamic, dynamic> map) {
    return Friend(
      id: id,
      name: map['name'] ?? 'Unknown',
      addedAt: map['addedAt'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'addedAt': addedAt,
    };
  }
}