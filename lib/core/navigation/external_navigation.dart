import 'package:url_launcher/url_launcher.dart';

abstract interface class ExternalNavigation {
  Future<bool> toCoordinates(double latitude, double longitude);
  Future<bool> toAddress(String address);
}

class UrlExternalNavigation implements ExternalNavigation {
  const UrlExternalNavigation();
  @override
  Future<bool> toCoordinates(double latitude, double longitude) => launchUrl(
    Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$latitude,$longitude',
    }),
    mode: LaunchMode.externalApplication,
  );
  @override
  Future<bool> toAddress(String address) => launchUrl(
    Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': address,
    }),
    mode: LaunchMode.externalApplication,
  );
}
