import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

enum GpsAccessStatus {
  granted,
  serviceDisabled,
  denied,
  deniedForever,
  error,
}

class GpsPermissionCheckResult {
  final GpsAccessStatus status;
  final String? message;

  const GpsPermissionCheckResult({
    required this.status,
    this.message,
  });

  bool get isGranted => status == GpsAccessStatus.granted;
}

class LocationResult {
  final double? lat;
  final double? lng;
  final String addressText;
  final bool isAccurateGps;
  final GpsAccessStatus accessStatus;
  final String? warningMessage;

  const LocationResult({
    this.lat,
    this.lng,
    required this.addressText,
    required this.isAccurateGps,
    this.accessStatus = GpsAccessStatus.granted,
    this.warningMessage,
  });
}

class LocationService {
  /// Checks location service availability and requests runtime permission if needed.
  static Future<GpsPermissionCheckResult> checkAndRequestGpsPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const GpsPermissionCheckResult(
          status: GpsAccessStatus.serviceDisabled,
          message:
              'Device GPS location services are turned off. Please enable Location in your device settings.',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const GpsPermissionCheckResult(
            status: GpsAccessStatus.denied,
            message:
                'Location permission was denied. Please grant location access to share or use live GPS coordinates.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return const GpsPermissionCheckResult(
          status: GpsAccessStatus.deniedForever,
          message:
              'Location permission is permanently denied in device settings. Open App Settings to allow Location.',
        );
      }

      return const GpsPermissionCheckResult(status: GpsAccessStatus.granted);
    } catch (e) {
      return GpsPermissionCheckResult(
        status: GpsAccessStatus.error,
        message: 'Could not verify location permissions: $e',
      );
    }
  }

  /// Acquires a real GPS fix from the device hardware without inventing fallback coordinates.
  static Future<Position> acquireRealGpsPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeLimit = const Duration(seconds: 10),
  }) async {
    return Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        timeLimit: timeLimit,
      ),
    );
  }

  /// Opens device location settings or app permission settings.
  static Future<bool> openDeviceLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openAppPermissionSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  /// Requests permission and gets current GPS position. Does not fabricate coordinates when GPS fails.
  static Future<LocationResult> getCurrentLocation({
    String fallbackAddress = 'Delivery address',
  }) async {
    final perm = await checkAndRequestGpsPermission();
    if (!perm.isGranted) {
      return LocationResult(
        lat: null,
        lng: null,
        addressText: fallbackAddress,
        isAccurateGps: false,
        accessStatus: perm.status,
        warningMessage: perm.message,
      );
    }

    try {
      final position = await acquireRealGpsPosition(
        accuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return LocationResult(
        lat: position.latitude,
        lng: position.longitude,
        addressText:
            'GPS (${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)})',
        isAccurateGps: true,
        accessStatus: GpsAccessStatus.granted,
      );
    } catch (_) {
      return LocationResult(
        lat: null,
        lng: null,
        addressText: fallbackAddress,
        isAccurateGps: false,
        accessStatus: GpsAccessStatus.error,
        warningMessage:
            'Could not acquire live GPS fix in time. Please check your GPS signal or select your delivery location.',
      );
    }
  }

  /// Calculates great-circle distance in kilometers using the Haversine formula.
  static double calculateDistanceKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final meters = calculateDistanceMeters(lat1, lng1, lat2, lng2);
    return ((meters / 1000.0) * 10).roundToDouble() / 10.0;
  }

  /// Calculates great-circle distance in meters using the Haversine formula.
  static double calculateDistanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadiusMeters = 6371000.0;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double _toRadians(double degree) {
    return degree * (math.pi / 180.0);
  }
}
