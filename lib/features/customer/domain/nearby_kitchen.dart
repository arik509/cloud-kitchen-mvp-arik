import '../../kitchen/domain/kitchen.dart';

class NearbyKitchen {
  const NearbyKitchen({
    required this.kitchen,
    required this.distanceKm,
    this.representativeImagePath,
    this.representativeImageUrl,
  });

  final Kitchen kitchen;
  final double distanceKm;
  final String? representativeImagePath;
  final String? representativeImageUrl;
}

class KitchenImageReference {
  const KitchenImageReference({this.path, this.url});

  final String? path;
  final String? url;
}
