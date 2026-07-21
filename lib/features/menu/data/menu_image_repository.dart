import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const maxMenuImageBytes = 5 * 1024 * 1024;
String menuImageObjectPath({
  required String ownerId,
  required String kitchenId,
  required String menuItemId,
  required String generatedFileName,
}) => '$ownerId/$kitchenId/$menuItemId/$generatedFileName';

class PickedMenuImage {
  const PickedMenuImage({
    required this.bytes,
    required this.fileName,
    required this.contentType,
    required this.extension,
  });

  final Uint8List bytes;
  final String fileName;
  final String contentType;
  final String extension;
}

class MenuImageValidator {
  const MenuImageValidator._();

  static PickedMenuImage validate({
    required Uint8List bytes,
    required String fileName,
    String? contentType,
    int maximumBytes = maxMenuImageBytes,
  }) {
    if (bytes.isEmpty) {
      throw const MenuImageValidationException('The selected image is empty.');
    }
    if (bytes.length > maximumBytes) {
      throw MenuImageValidationException(
        'Image must be ${_formatMegabytes(maximumBytes)} MB or smaller.',
      );
    }

    final extension = _extension(fileName);
    final expectedType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => throw const MenuImageValidationException(
        'Choose a JPEG, PNG, or WebP image.',
      ),
    };
    final normalizedType = contentType?.toLowerCase().trim();
    if (normalizedType != null &&
        normalizedType.isNotEmpty &&
        normalizedType != expectedType) {
      throw const MenuImageValidationException(
        'The image file type does not match its extension.',
      );
    }
    if (!_hasExpectedSignature(bytes, expectedType)) {
      throw const MenuImageValidationException(
        'The selected file is not a valid JPEG, PNG, or WebP image.',
      );
    }
    return PickedMenuImage(
      bytes: bytes,
      fileName: fileName,
      contentType: expectedType,
      extension: extension == 'jpeg' ? 'jpg' : extension,
    );
  }

  static String _extension(String fileName) {
    final index = fileName.lastIndexOf('.');
    return index < 0 ? '' : fileName.substring(index + 1).toLowerCase();
  }

  static bool _hasExpectedSignature(Uint8List bytes, String contentType) {
    if (contentType == 'image/jpeg') {
      return bytes.length >= 3 &&
          bytes[0] == 0xff &&
          bytes[1] == 0xd8 &&
          bytes[2] == 0xff;
    }
    if (contentType == 'image/png') {
      const signature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
      return bytes.length >= signature.length && _matches(bytes, 0, signature);
    }
    const riff = [0x52, 0x49, 0x46, 0x46];
    const webp = [0x57, 0x45, 0x42, 0x50];
    return bytes.length >= 12 &&
        _matches(bytes, 0, riff) &&
        _matches(bytes, 8, webp);
  }

  static bool _matches(Uint8List bytes, int offset, List<int> expected) {
    for (var index = 0; index < expected.length; index++) {
      if (bytes[offset + index] != expected[index]) return false;
    }
    return true;
  }

  static String _formatMegabytes(int bytes) {
    final megabytes = bytes / (1024 * 1024);
    return megabytes == megabytes.roundToDouble()
        ? megabytes.toStringAsFixed(0)
        : megabytes.toStringAsFixed(1);
  }
}

abstract interface class MenuImagePicker {
  Future<PickedMenuImage?> pick();
}

class PlatformMenuImagePicker implements MenuImagePicker {
  PlatformMenuImagePicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<PickedMenuImage?> pick() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return null;
    return MenuImageValidator.validate(
      bytes: await file.readAsBytes(),
      fileName: file.name,
      contentType: file.mimeType,
    );
  }
}

abstract interface class MenuImageRepository {
  Future<String> upload({
    required String ownerId,
    required String kitchenId,
    required String menuItemId,
    required PickedMenuImage image,
  });

  Future<void> delete(String path);

  String publicUrl(String path);
}

class SupabaseMenuImageRepository implements MenuImageRepository {
  SupabaseMenuImageRepository(this._client);

  static const bucket = 'menu-images';
  final SupabaseClient _client;

  @override
  Future<String> upload({
    required String ownerId,
    required String kitchenId,
    required String menuItemId,
    required PickedMenuImage image,
  }) async {
    final generatedName =
        '${DateTime.now().microsecondsSinceEpoch}.${image.extension}';
    final path = menuImageObjectPath(
      ownerId: ownerId,
      kitchenId: kitchenId,
      menuItemId: menuItemId,
      generatedFileName: generatedName,
    );
    try {
      await _client.storage
          .from(bucket)
          .uploadBinary(
            path,
            image.bytes,
            fileOptions: FileOptions(contentType: image.contentType),
          );
      return path;
    } on StorageException catch (error) {
      throw MenuImageRepositoryException(error.message);
    }
  }

  @override
  Future<void> delete(String path) async {
    try {
      await _client.storage.from(bucket).remove([path]);
    } on StorageException catch (error) {
      throw MenuImageRepositoryException(error.message);
    }
  }

  @override
  String publicUrl(String path) =>
      _client.storage.from(bucket).getPublicUrl(path);
}

class MenuImageValidationException implements Exception {
  const MenuImageValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MenuImageRepositoryException implements Exception {
  const MenuImageRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
