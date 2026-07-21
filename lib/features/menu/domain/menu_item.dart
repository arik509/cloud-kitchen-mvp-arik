const _notProvided = Object();

class MenuItem {
  const MenuItem({
    required this.id,
    required this.kitchenId,
    required this.name,
    required this.price,
    required this.isAvailable,
    this.description,
    this.imagePath,
    this.imageUrl,
  });

  final String id;
  final String kitchenId;
  final String name;
  final String? description;
  final double price;
  final bool isAvailable;
  final String? imagePath;
  final String? imageUrl;

  factory MenuItem.fromMap(Map<String, dynamic> map) => MenuItem(
    id: map['id'] as String,
    kitchenId: map['kitchen_id'] as String,
    name: map['name'] as String,
    description: _optionalText(map['description']),
    price: (map['price'] as num).toDouble(),
    isAvailable: map['is_available'] as bool? ?? true,
    imagePath: _optionalText(map['image_path']),
    imageUrl: _optionalText(map['image_url']),
  );

  MenuItem copyWith({
    String? name,
    Object? description = _notProvided,
    double? price,
    bool? isAvailable,
    Object? imagePath = _notProvided,
    Object? imageUrl = _notProvided,
  }) => MenuItem(
    id: id,
    kitchenId: kitchenId,
    name: name ?? this.name,
    description: identical(description, _notProvided)
        ? this.description
        : description as String?,
    price: price ?? this.price,
    isAvailable: isAvailable ?? this.isAvailable,
    imagePath: identical(imagePath, _notProvided)
        ? this.imagePath
        : imagePath as String?,
    imageUrl: identical(imageUrl, _notProvided)
        ? this.imageUrl
        : imageUrl as String?,
  );

  Map<String, dynamic> toUpdateMap() => {
    'name': name.trim(),
    'description': _optionalText(description),
    'price': price,
    'is_available': isAvailable,
    if (imagePath != null) 'image_path': imagePath,
    if (imageUrl != null) 'image_url': imageUrl,
  };

  static String? _optionalText(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

class MenuItemDraft {
  const MenuItemDraft({
    required this.name,
    required this.price,
    required this.isAvailable,
    this.description,
  });

  final String name;
  final String? description;
  final double price;
  final bool isAvailable;

  Map<String, dynamic> toInsertMap(String kitchenId) => {
    'kitchen_id': kitchenId,
    'name': name.trim(),
    'description': _optionalDescription,
    'price': price,
    'is_available': isAvailable,
  };

  MenuItem applyTo(MenuItem item, {String? imagePath, String? imageUrl}) =>
      MenuItem(
        id: item.id,
        kitchenId: item.kitchenId,
        name: name.trim(),
        description: _optionalDescription,
        price: price,
        isAvailable: isAvailable,
        imagePath: imagePath ?? item.imagePath,
        imageUrl: imageUrl ?? item.imageUrl,
      );

  String? get _optionalDescription {
    final text = description?.trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
