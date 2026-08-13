import '../../kitchen/domain/kitchen.dart';

class NearbyKitchen {
  const NearbyKitchen({
    required this.kitchen,
    required this.distanceKm,
    this.representativeImagePath,
    this.representativeImageUrl,
    this.representativeImageBucket = KitchenImageBucket.menu,
  });

  final Kitchen kitchen;
  final double distanceKm;
  final String? representativeImagePath;
  final String? representativeImageUrl;
  final KitchenImageBucket representativeImageBucket;
}

enum KitchenImageBucket { kitchen, menu }

class KitchenImageReference {
  const KitchenImageReference({
    this.path,
    this.url,
    this.bucket = KitchenImageBucket.menu,
  });

  final String? path;
  final String? url;
  final KitchenImageBucket bucket;
}
