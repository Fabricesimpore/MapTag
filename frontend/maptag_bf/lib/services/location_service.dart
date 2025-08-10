import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
  );

  /// Get current GPS position with proper error handling
  static Future<Position> getCurrentPosition() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw LocationException(
          'Services de géolocalisation désactivés',
          'Veuillez activer la géolocalisation dans les paramètres de votre appareil.',
        );
      }

      // Check and request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw LocationException(
            'Permission de géolocalisation refusée',
            'L\'application a besoin de votre position pour créer des adresses.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw LocationException(
          'Permission de géolocalisation refusée définitivement',
          'Veuillez autoriser la géolocalisation dans les paramètres de l\'application.',
        );
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return position;
    } on LocationServiceDisabledException {
      throw LocationException(
        'Services de géolocalisation désactivés',
        'Veuillez activer la géolocalisation dans les paramètres.',
      );
    } on PermissionDeniedException {
      throw LocationException(
        'Permission refusée',
        'L\'accès à la géolocalisation est nécessaire.',
      );
    } on TimeoutException {
      throw LocationException(
        'Délai d\'attente dépassé',
        'Impossible d\'obtenir votre position. Réessayez.',
      );
    } catch (e) {
      throw LocationException(
        'Erreur de géolocalisation',
        'Une erreur inattendue s\'est produite: ${e.toString()}',
      );
    }
  }

  /// Get location stream for continuous tracking
  static Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: _locationSettings,
    );
  }

  /// Check if the device location is within Burkina Faso boundaries
  static bool isInBurkinaFaso(double latitude, double longitude) {
    // Burkina Faso boundaries (approximate)
    const double minLat = 9.4;
    const double maxLat = 15.1;
    const double minLon = -5.5;
    const double maxLon = 2.4;

    return latitude >= minLat && 
           latitude <= maxLat && 
           longitude >= minLon && 
           longitude <= maxLon;
  }

  /// Calculate distance between two coordinates in meters
  static double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Get location accuracy description
  static String getAccuracyDescription(double accuracy) {
    if (accuracy <= 5) {
      return 'Très précise (${accuracy.toStringAsFixed(1)}m)';
    } else if (accuracy <= 10) {
      return 'Précise (${accuracy.toStringAsFixed(1)}m)';
    } else if (accuracy <= 20) {
      return 'Moyennement précise (${accuracy.toStringAsFixed(1)}m)';
    } else {
      return 'Peu précise (${accuracy.toStringAsFixed(1)}m)';
    }
  }

  /// Check location permissions status
  static Future<LocationPermissionStatus> checkPermissionStatus() async {
    LocationPermission permission = await Geolocator.checkPermission();
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return LocationPermissionStatus.serviceDisabled;
    }

    switch (permission) {
      case LocationPermission.denied:
        return LocationPermissionStatus.denied;
      case LocationPermission.deniedForever:
        return LocationPermissionStatus.deniedForever;
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return LocationPermissionStatus.granted;
      case LocationPermission.unableToDetermine:
        return LocationPermissionStatus.unknown;
    }
  }

  /// Request location permissions with detailed handling
  static Future<bool> requestLocationPermission() async {
    try {
      // First check if services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      return permission == LocationPermission.whileInUse || 
             permission == LocationPermission.always;
    } catch (e) {
      return false;
    }
  }

  /// Open location settings
  static Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  /// Open app settings
  static Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  /// Get readable coordinates format
  static String formatCoordinates(double latitude, double longitude) {
    String latDirection = latitude >= 0 ? 'N' : 'S';
    String lonDirection = longitude >= 0 ? 'E' : 'W';
    
    return '${latitude.abs().toStringAsFixed(6)}°$latDirection, '
           '${longitude.abs().toStringAsFixed(6)}°$lonDirection';
  }

  /// Validate coordinates for Burkina Faso
  static LocationValidationResult validateCoordinates(double latitude, double longitude) {
    if (latitude < -90 || latitude > 90) {
      return LocationValidationResult(
        isValid: false,
        error: 'Latitude invalide (doit être entre -90 et 90)',
      );
    }

    if (longitude < -180 || longitude > 180) {
      return LocationValidationResult(
        isValid: false,
        error: 'Longitude invalide (doit être entre -180 et 180)',
      );
    }

    if (!isInBurkinaFaso(latitude, longitude)) {
      return LocationValidationResult(
        isValid: false,
        error: 'Cette position semble être en dehors du Burkina Faso',
        warning: 'MapTag BF est conçu pour les adresses au Burkina Faso',
      );
    }

    return LocationValidationResult(isValid: true);
  }
}

class LocationException implements Exception {
  final String title;
  final String message;

  LocationException(this.title, this.message);

  @override
  String toString() => '$title: $message';
}

enum LocationPermissionStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
  unknown,
}

class LocationValidationResult {
  final bool isValid;
  final String? error;
  final String? warning;

  LocationValidationResult({
    required this.isValid,
    this.error,
    this.warning,
  });
}