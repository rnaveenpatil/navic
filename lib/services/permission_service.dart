import 'package:flutter/services.dart';

class PermissionService {
  static const MethodChannel _channel = MethodChannel('navic_support');

  static Future<Map<String, dynamic>> checkLocationPermissions() async {
    try {
      final result = await _channel.invokeMethod('checkLocationPermissions');
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      print("Error checking permissions: \${e.message}");
      return {
        'hasFineLocation': false,
        'hasCoarseLocation': false,
        'hasBackgroundLocation': false,
        'allPermissionsGranted': false,
      };
    }
  }

  static Future<bool> requestLocationPermissions() async {
    try {
      final result = await _channel.invokeMethod('requestLocationPermissions');
      return result == true;
    } on PlatformException catch (e) {
      print("Error requesting permissions: \${e.message}");
      return false;
    }
  }

  static Future<Map<String, dynamic>> isLocationEnabled() async {
    try {
      final result = await _channel.invokeMethod('isLocationEnabled');
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      print("Error checking location status: \${e.message}");
      return {
        'gpsEnabled': false,
        'networkEnabled': false,
        'anyEnabled': false,
      };
    }
  }

  static Future<bool> openLocationSettings() async {
    try {
      await _channel.invokeMethod('openLocationSettings');
      return true;
    } on PlatformException catch (e) {
      print("Error opening settings: \${e.message}");
      return false;
    }
  }
}
