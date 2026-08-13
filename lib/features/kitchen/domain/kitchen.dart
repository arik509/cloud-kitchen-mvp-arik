class Kitchen {
  const Kitchen({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
    this.imagePath,
    this.isActive = true,
  });

  final String id;
  final String ownerId;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? imagePath;
  final bool isActive;

  factory Kitchen.fromMap(Map<String, dynamic> map) => Kitchen(
    id: map['id'] as String,
    ownerId: map['owner_id'] as String,
    name: map['name'] as String,
    address: map['address'] as String,
    latitude: (map['latitude'] as num?)?.toDouble(),
    longitude: (map['longitude'] as num?)?.toDouble(),
    imagePath: _optionalText(map['image_path']),
    isActive: map['is_active'] as bool? ?? true,
  );

  Kitchen copyWith({
    String? name,
    String? address,
    Object? latitude = _notProvided,
    Object? longitude = _notProvided,
    Object? imagePath = _notProvided,
    bool? isActive,
  }) => Kitchen(
    id: id,
    ownerId: ownerId,
    name: name ?? this.name,
    address: address ?? this.address,
    latitude: identical(latitude, _notProvided)
        ? this.latitude
        : latitude as double?,
    longitude: identical(longitude, _notProvided)
        ? this.longitude
        : longitude as double?,
    imagePath: identical(imagePath, _notProvided)
        ? this.imagePath
        : imagePath as String?,
    isActive: isActive ?? this.isActive,
  );

  Map<String, dynamic> toUpdateMap() => {
    'name': name.trim(),
    'address': address.trim(),
    'latitude': latitude,
    'longitude': longitude,
    'image_path': imagePath,
    'is_active': isActive,
  };
}

class KitchenDraft {
  const KitchenDraft({
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
    this.isActive = true,
  });

  final String name;
  final String address;
  final double? latitude;
  final double? longitude;
  final bool isActive;

  Map<String, dynamic> toInsertMap(String ownerId) => {
    'owner_id': ownerId,
    'name': name.trim(),
    'address': address.trim(),
    'latitude': latitude,
    'longitude': longitude,
    'is_active': isActive,
  };

  Kitchen applyTo(Kitchen kitchen, {Object? imagePath = _notProvided}) =>
      Kitchen(
        id: kitchen.id,
        ownerId: kitchen.ownerId,
        name: name.trim(),
        address: address.trim(),
        latitude: latitude,
        longitude: longitude,
        imagePath: identical(imagePath, _notProvided)
            ? kitchen.imagePath
            : imagePath as String?,
        isActive: isActive,
      );
}

const _notProvided = Object();

String? _optionalText(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
