import 'package:flutter/services.dart';

class NavicHardwareService {
  static const MethodChannel _channel = MethodChannel('navic_support');
  static Function(Map<String, dynamic>)? _onSatelliteUpdate;

  /// Checks if the device hardware supports NavIC and whether satellites are available.
  static Future<Map<String, dynamic>> checkNavicHardware() async {
    try {
      print("🛰️ Calling native hardware detection...");
      final Map<dynamic, dynamic> result =
      await _channel.invokeMethod('checkNavicHardware');
      print("🛰️ Native response: $result");
      return _convertResult(result);
    } on PlatformException catch (e) {
      print("❌ Error checking NavIC hardware: ${e.message}");
      return {
        'isSupported': false,
        'isActive': false,
        'detectionMethod': 'ERROR',
        'message': 'Failed to detect hardware: ${e.message}',
        'satelliteCount': 0,
        'totalSatellites': 0,
      };
    }
  }

  /// Get device GNSS capabilities
  static Future<Map<String, dynamic>> getGnssCapabilities() async {
    try {
      final Map<dynamic, dynamic> capabilities =
      await _channel.invokeMethod('getGnssCapabilities');
      return _convertResult(capabilities);
    } on PlatformException catch (e) {
      return {
        'hasNavic': false,
        'hasGps': true,
        'androidVersion': 0,
        'manufacturer': 'Unknown',
        'model': 'Unknown',
      };
    }
  }

  /// Start real-time satellite monitoring
  static Future<Map<String, dynamic>> startRealTimeDetection() async {
    try {
      _channel.setMethodCallHandler((call) async {
        if (call.method == "onSatelliteUpdate" && _onSatelliteUpdate != null) {
          final Map<dynamic, dynamic> data = call.arguments as Map<dynamic, dynamic>;
          _onSatelliteUpdate!(_convertResult(data));
        }
        return null;
      });

      final Map<dynamic, dynamic> result =
      await _channel.invokeMethod('startRealTimeDetection');
      return _convertResult(result);
    } on PlatformException catch (e) {
      return {
        'success': false,
        'message': 'Failed to start detection: ${e.message}',
      };
    }
  }

  /// Stop real-time satellite monitoring
  static Future<Map<String, dynamic>> stopRealTimeDetection() async {
    try {
      final Map<dynamic, dynamic> result =
      await _channel.invokeMethod('stopRealTimeDetection');
      _channel.setMethodCallHandler(null);
      return _convertResult(result);
    } on PlatformException catch (e) {
      return {
        'success': false,
        'message': 'Failed to stop detection: ${e.message}',
      };
    }
  }

  /// Set callback for satellite updates
  static void setSatelliteUpdateCallback(Function(Map<String, dynamic>) callback) {
    _onSatelliteUpdate = callback;
  }

  /// Remove satellite update callback
  static void removeSatelliteUpdateCallback() {
    _onSatelliteUpdate = null;
  }

  // Helper method to convert dynamic Map to String-keyed Map
  static Map<String, dynamic> _convertResult(Map<dynamic, dynamic> result) {
    return result.cast<String, dynamic>();
  }
}