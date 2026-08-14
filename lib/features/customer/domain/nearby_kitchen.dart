import '../../kitchen/domain/kitchen.dart';

class NearbyKitchen {
  const NearbyKitchen({
    required this.kitchen,
    required this.distanceKm,
    this.representativeImagePath,
    this.representativeImageUrl,
    this.representativeImageBucket = KitchenImageBucket.menu,
    this.averageRating = 0,
    this.ratingCount = 0,
  });

  final Kitchen kitchen;
  final double distanceKm;
  final String? representativeImagePath;
  final String? representativeImageUrl;
  final KitchenImageBucket representativeImageBucket;
  final double averageRating;
  final int ratingCount;

  NearbyKitchen copyWithRating({required double average, required int count}) =>
      NearbyKitchen(
        kitchen: kitchen,
        distanceKm: distanceKm,
        representativeImagePath: representativeImagePath,
        representativeImageUrl: representativeImageUrl,
        representativeImageBucket: representativeImageBucket,
        averageRating: average,
        ratingCount: count,
      );
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
