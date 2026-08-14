import 'package:url_launcher/url_launcher.dart';

abstract interface class ExternalNavigation {
  Future<bool> toCoordinates(double latitude, double longitude);
  Future<bool> toAddress(String address);
}

class UrlExternalNavigation implements ExternalNavigation {
  const UrlExternalNavigation();
  @override
  Future<bool> toCoordinates(double latitude, double longitude) => _open(
    Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$latitude,$longitude',
    }),
  );
  @override
  Future<bool> toAddress(String address) => _open(
    Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': address,
    }),
  );

  Future<bool> _open(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return true;
      }
      return launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {
      try {
        return launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {
        return false;
      }
    }
  }
}
