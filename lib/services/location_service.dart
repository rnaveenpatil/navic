import 'package:geolocator/geolocator.dart';
import 'package:navic/services/hardware_services.dart';

class EnhancedPosition {
  final Position position;
  final bool isNavicEnhanced;
  final double confidenceScore;
  final String locationSource;
  final String detectionReason;
  final int? navicSatellites;
  final Map<String, dynamic>? satelliteInfo;

  EnhancedPosition({
    required this.position,
    required this.isNavicEnhanced,
    required this.confidenceScore,
    required this.locationSource,
    required this.detectionReason,
    this.navicSatellites,
    this.satelliteInfo,
  });
}

class LocationService {
  List<EnhancedPosition> locationHistory = [];
  bool _isNavicSupported = false;
  bool _isNavicActive = false;
  int _navicSatelliteCount = 0;
  String _detectionMethod = "UNKNOWN";
  Map<String, dynamic> _lastSatelliteInfo = {};
  bool _isRealTimeMonitoring = false;

  /// Check hardware + satellite availability
  Future<Map<String, dynamic>> checkNavicHardwareSupport() async {
    try {
      final hardwareResult = await NavicHardwareService.checkNavicHardware();

      // Update internal state from native detection
      _isNavicSupported = hardwareResult['isSupported'] ?? false;
      _isNavicActive = hardwareResult['isActive'] ?? false;
      _navicSatelliteCount = hardwareResult['satelliteCount'] ?? 0;
      _detectionMethod = hardwareResult['detectionMethod'] ?? 'UNKNOWN';

      return {
        'isSupported': _isNavicSupported,
        'isActive': _isNavicActive,
        'detectionMethod': _detectionMethod,
        'message': _generateStatusMessage(),
        'satelliteCount': _navicSatelliteCount,
        'totalSatellites': hardwareResult['totalSatellites'] ?? 0,
      };
    } catch (e) {
      return {
        'isSupported': false,
        'isActive': false,
        'detectionMethod': 'ERROR',
        'message': 'Hardware detection failed: $e',
        'satelliteCount': 0,
        'totalSatellites': 0,
      };
    }
  }

  String _generateStatusMessage() {
    if (!_isNavicSupported) {
      return "Device does not support NavIC. Using standard GPS.";
    } else if (!_isNavicActive) {
      return "Device hardware supports NavIC, but satellites are not available. Using standard GPS.";
    } else {
      return "Device supports NavIC and NavIC satellites available. Using NavIC now.";
    }
  }

  Future<bool> checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<bool> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.requestPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Get current location with NavIC/GPS detection
  Future<EnhancedPosition?> getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      bool isNavicEnhanced = _isNavicSupported && _isNavicActive;
      String locationSource = isNavicEnhanced ? "NAVIC" : "GPS";

      double confidenceScore = isNavicEnhanced ? 0.95 : 0.75;

      final enhancedPosition = EnhancedPosition(
        position: position,
        isNavicEnhanced: isNavicEnhanced,
        confidenceScore: confidenceScore,
        locationSource: locationSource,
        detectionReason: _generateStatusMessage(),
        navicSatellites: _navicSatelliteCount,
        satelliteInfo: _lastSatelliteInfo,
      );

      locationHistory.add(enhancedPosition);
      if (locationHistory.length > 100) locationHistory.removeAt(0);

      return enhancedPosition;
    } catch (e) {
      print("❌ Error getting location: $e");
      return null;
    }
  }

  void _onSatelliteUpdate(Map<String, dynamic> data) {
    _lastSatelliteInfo = data;
    _isNavicActive = data['isNavicAvailable'] ?? false;
    _navicSatelliteCount = data['navicSatellites'] ?? 0;
  }

  Future<void> startRealTimeMonitoring() async {
    if (!_isRealTimeMonitoring) {
      NavicHardwareService.setSatelliteUpdateCallback(_onSatelliteUpdate);
      await NavicHardwareService.startRealTimeDetection();
      _isRealTimeMonitoring = true;
    }
  }

  Future<void> stopRealTimeMonitoring() async {
    if (_isRealTimeMonitoring) {
      await NavicHardwareService.stopRealTimeDetection();
      NavicHardwareService.removeSatelliteUpdateCallback();
      _isRealTimeMonitoring = false;
    }
  }

  void dispose() {
    stopRealTimeMonitoring();
  }
}