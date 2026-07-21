import 'package:flutter/material.dart';

import '../data/menu_image_repository.dart';

class MenuImageView extends StatelessWidget {
  const MenuImageView({
    required this.imageRepository,
    this.imagePath,
    this.imageUrl,
    this.size = 64,
    super.key,
  });

  final MenuImageRepository imageRepository;
  final String? imagePath;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    final url = path != null && path.isNotEmpty
        ? imageRepository.publicUrl(path)
        : imageUrl;
    if (url == null || url.isEmpty) return _fallback(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(context),
      ),
    );
  }

  Widget _fallback(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(Icons.no_food_outlined),
  );
}
