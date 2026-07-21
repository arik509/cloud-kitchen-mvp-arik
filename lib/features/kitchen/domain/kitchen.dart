class Kitchen {
  const Kitchen({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String ownerId;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;

  factory Kitchen.fromMap(Map<String, dynamic> map) => Kitchen(
    id: map['id'] as String,
    ownerId: map['owner_id'] as String,
    name: map['name'] as String,
    address: map['address'] as String,
    latitude: (map['latitude'] as num?)?.toDouble(),
    longitude: (map['longitude'] as num?)?.toDouble(),
  );
}

class KitchenDraft {
  const KitchenDraft({
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
  });

  final String name;
  final String address;
  final double? latitude;
  final double? longitude;

  Map<String, dynamic> toInsertMap(String ownerId) => {
    'owner_id': ownerId,
    'name': name.trim(),
    'address': address.trim(),
    'latitude': latitude,
    'longitude': longitude,
  };
}
