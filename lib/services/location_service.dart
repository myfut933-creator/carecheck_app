import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../utils/app_exception.dart';

/// GPS sensor access. All failure cases produce a friendly [AppException].
class LocationService {
  Future<Position> currentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw AppException(
          'Location services are turned off. Please enable them and try again.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw AppException(
          'Location permission is needed to verify your visit. Please allow it and try again.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw AppException(
          'Location permission is blocked. Open phone Settings > Apps > CareCheck > Permissions and allow Location.');
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } on TimeoutException {
      throw AppException(
          'Could not get a GPS fix. Move near a window or outdoors and try again.');
    }
  }

  /// Straight-line distance in metres between a position and a point.
  double distanceMetres(Position p, double lat, double lng) =>
      Geolocator.distanceBetween(p.latitude, p.longitude, lat, lng);
}
