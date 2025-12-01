import 'package:flutter/services.dart';

class NavicHardwareService {
  static const MethodChannel _channel = MethodChannel('navic_support');
  static Function(Map<String, dynamic>)? _onSatelliteUpdate;
  static Function(Map<String, dynamic>)? _onLocationUpdate;

  // Detection state tracking
  static bool _isRealTimeActive = false;
  static bool _isLocationTracking = false;

  // Cache for hardware detection (5 minute validity)
  static NavicDetectionResult? _cachedResult;
  static DateTime? _lastDetectionTime;
  static const Duration _cacheValidity = Duration(minutes: 5);

  /// Checks if the device hardware supports NavIC with optimized satellite detection
  static Future<NavicDetectionResult> checkNavicHardware() async {
    try {
      // Return cached result if valid
      if (_cachedResult != null && _lastDetectionTime != null) {
        if (DateTime.now().difference(_lastDetectionTime!) < _cacheValidity) {
          return _cachedResult!;
        }
      }

      print("🚀 Starting optimized NavIC hardware detection...");
      final Map<dynamic, dynamic> result = await _channel.invokeMethod('checkNavicHardware');
      final converted = _convertResult(result);
      
      final detectionResult = NavicDetectionResult.fromMap(converted);
      _cachedResult = detectionResult;
      _lastDetectionTime = DateTime.now();

      // Log optimized detection results
      _logDetectionResults(converted);

      return detectionResult;
    } on PlatformException catch (e) {
      print("❌ Error checking NavIC hardware: ${e.message}");
      return NavicDetectionResult.error(e.message ?? 'Unknown error');
    }
  }

  /// Log detection results (kept separate for maintainability)
  static void _logDetectionResults(Map<String, dynamic> data) {
    print("🎯 Optimized Detection Results:");
    print("  ✅ Supported: ${data['isSupported']}");
    print("  📡 Active: ${data['isActive']}");
    print("  🔧 Method: ${data['detectionMethod']}");
    print("  🛰️ NavIC Satellites: ${data['satelliteCount']}");
    print("  📍 Used in Fix: ${data['usedInFixCount']}");
    print("  📊 Total Satellites: ${data['totalSatellites']}");
    final signalStr = data['averageSignalStrength'] as double?;
    print("  📶 Signal Strength: ${signalStr?.toStringAsFixed(1) ?? 'N/A'} dB-Hz");
    print("  ⚡ Acquisition Time: ${data['acquisitionTimeMs']}ms");
    print("  💾 Chipset: ${data['chipsetType']}");
  }

  /// Get device GNSS capabilities with enhanced information
  static Future<GnssCapabilities> getGnssCapabilities() async {
    try {
      final Map<dynamic, dynamic> capabilities = await _channel.invokeMethod('getGnssCapabilities');
      final converted = _convertResult(capabilities);
      return GnssCapabilities.fromMap(converted);
    } on PlatformException catch (e) {
      print("❌ Error getting GNSS capabilities: ${e.message}");
      return GnssCapabilities.error();
    }
  }

  /// Start optimized real-time satellite monitoring
  static Future<DetectionResponse> startRealTimeDetection() async {
    try {
      if (_isRealTimeActive) {
        return DetectionResponse(
            success: false,
            message: 'Real-time detection already active'
        );
      }

      _channel.setMethodCallHandler(_handleMethodCall);

      final Map<dynamic, dynamic> result = await _channel.invokeMethod('startRealTimeDetection');
      final converted = _convertResult(result);

      _isRealTimeActive = converted['success'] == true;

      print(_isRealTimeActive
          ? "🛰️ Real-time NavIC detection started successfully"
          : "❌ Failed to start real-time detection");

      return DetectionResponse.fromMap(converted);
    } on PlatformException catch (e) {
      print("❌ Error starting real-time detection: ${e.message}");
      return DetectionResponse.error('Failed to start detection: ${e.message}');
    }
  }

  /// Stop real-time satellite monitoring
  static Future<DetectionResponse> stopRealTimeDetection() async {
    try {
      if (!_isRealTimeActive) {
        return DetectionResponse(
            success: true,
            message: 'Real-time detection not active'
        );
      }

      final Map<dynamic, dynamic> result = await _channel.invokeMethod('stopRealTimeDetection');
      final converted = _convertResult(result);

      _channel.setMethodCallHandler(null);
      _isRealTimeActive = false;

      print("🛰️ Real-time NavIC detection stopped");
      return DetectionResponse.fromMap(converted);
    } on PlatformException catch (e) {
      print("❌ Error stopping real-time detection: ${e.message}");
      return DetectionResponse.error('Failed to stop detection: ${e.message}');
    }
  }

  /// Start location updates
  static Future<DetectionResponse> startLocationUpdates() async {
    try {
      if (_isLocationTracking) {
        return DetectionResponse(
            success: false,
            message: 'Location updates already active'
        );
      }

      final Map<dynamic, dynamic> result = await _channel.invokeMethod('startLocationUpdates');
      final converted = _convertResult(result);

      _isLocationTracking = converted['success'] == true;

      print(_isLocationTracking
          ? "📍 Location updates started successfully"
          : "❌ Failed to start location updates");

      return DetectionResponse.fromMap(converted);
    } on PlatformException catch (e) {
      print("❌ Error starting location updates: ${e.message}");
      return DetectionResponse.error('Failed to start location updates: ${e.message}');
    }
  }

  /// Stop location updates
  static Future<DetectionResponse> stopLocationUpdates() async {
    try {
      if (!_isLocationTracking) {
        return DetectionResponse(
            success: true,
            message: 'Location updates not active'
        );
      }

      final Map<dynamic, dynamic> result = await _channel.invokeMethod('stopLocationUpdates');
      final converted = _convertResult(result);

      _isLocationTracking = false;

      print("📍 Location updates stopped");
      return DetectionResponse.fromMap(converted);
    } on PlatformException catch (e) {
      print("❌ Error stopping location updates: ${e.message}");
      return DetectionResponse.error('Failed to stop location updates: ${e.message}');
    }
  }

  /// Check location permissions
  static Future<LocationPermissions> checkLocationPermissions() async {
    try {
      final Map<dynamic, dynamic> result = await _channel.invokeMethod('checkLocationPermissions');
      final converted = _convertResult(result);
      return LocationPermissions.fromMap(converted);
    } on PlatformException catch (e) {
      print("❌ Error checking permissions: ${e.message}");
      return LocationPermissions.error();
    }
  }

  /// Handle method calls from native side
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case "onSatelliteUpdate":
          await _handleSatelliteUpdate(call);
          break;
        case "onLocationUpdate":
          await _handleLocationUpdate(call);
          break;
      }
    } catch (e) {
      print("❌ Error in method call handler: $e");
    }
    return null;
  }

  /// Handle satellite update callback
  static Future<void> _handleSatelliteUpdate(MethodCall call) async {
    if (_onSatelliteUpdate == null) return;
    
    final Map<dynamic, dynamic> data = call.arguments as Map<dynamic, dynamic>;
    final satelliteData = SatelliteUpdateData.fromMap(_convertResult(data));
    _onSatelliteUpdate!(satelliteData.toMap());

    // Log satellite update summary if NavIC satellites detected
    if (satelliteData.navicSatellites.isNotEmpty) {
      print("📡 Satellite Update - NavIC: ${satelliteData.navicSatellites.length} "
          "(${satelliteData.navicUsedInFix} in fix), "
          "Total: ${satelliteData.totalSatellites}, "
          "Primary: ${satelliteData.primarySystem}");
    }
  }

  /// Handle location update callback
  static Future<void> _handleLocationUpdate(MethodCall call) async {
    if (_onLocationUpdate == null) return;
    
    final Map<dynamic, dynamic> data = call.arguments as Map<dynamic, dynamic>;
    final locationData = _convertResult(data);
    _onLocationUpdate!(locationData);

    // Log location update
    final lat = (locationData['latitude'] as num?)?.toStringAsFixed(6) ?? 'N/A';
    final lng = (locationData['longitude'] as num?)?.toStringAsFixed(6) ?? 'N/A';
    final acc = (locationData['accuracy'] as num?)?.toStringAsFixed(1) ?? 'N/A';
    final provider = locationData['provider'] ?? 'UNKNOWN';
    
    print("📍 Location Update - Lat: $lat, Lng: $lng, Acc: ${acc}m, Provider: $provider");
  }

  /// Set callback for satellite updates
  static void setSatelliteUpdateCallback(Function(Map<String, dynamic>) callback) {
    _onSatelliteUpdate = callback;
    print("📡 Satellite update callback registered");
  }

  /// Set callback for location updates
  static void setLocationUpdateCallback(Function(Map<String, dynamic>) callback) {
    _onLocationUpdate = callback;
    print("📍 Location update callback registered");
  }

  /// Remove satellite update callback
  static void removeSatelliteUpdateCallback() {
    _onSatelliteUpdate = null;
    print("📡 Satellite update callback removed");
  }

  /// Remove location update callback
  static void removeLocationUpdateCallback() {
    _onLocationUpdate = null;
    print("📍 Location update callback removed");
  }

  /// Check if real-time detection is active
  static bool get isRealTimeActive => _isRealTimeActive;

  /// Check if location tracking is active
  static bool get isLocationTracking => _isLocationTracking;

  // Helper method to convert dynamic Map to String-keyed Map
  static Map<String, dynamic> _convertResult(Map<dynamic, dynamic> result) {
    return result.cast<String, dynamic>();
  }
}

// Data Models for type-safe responses

class NavicDetectionResult {
  final bool isSupported;
  final bool isActive;
  final String detectionMethod;
  final String message;
  final int satelliteCount;
  final int totalSatellites;
  final int usedInFixCount;
  final double confidenceLevel;
  final String chipsetType;
  final double averageSignalStrength;
  final List<dynamic> satelliteDetails;
  final int acquisitionTimeMs;
  final List<dynamic> verificationMethods;
  final bool hasError;

  const NavicDetectionResult({
    required this.isSupported,
    required this.isActive,
    required this.detectionMethod,
    required this.message,
    required this.satelliteCount,
    required this.totalSatellites,
    required this.usedInFixCount,
    required this.confidenceLevel,
    required this.chipsetType,
    required this.averageSignalStrength,
    required this.satelliteDetails,
    required this.acquisitionTimeMs,
    required this.verificationMethods,
    this.hasError = false,
  });

  factory NavicDetectionResult.fromMap(Map<String, dynamic> map) {
    return NavicDetectionResult(
      isSupported: map['isSupported'] as bool? ?? false,
      isActive: map['isActive'] as bool? ?? false,
      detectionMethod: map['detectionMethod'] as String? ?? 'UNKNOWN',
      message: map['message'] as String? ?? 'No detection message',
      satelliteCount: map['satelliteCount'] as int? ?? 0,
      totalSatellites: map['totalSatellites'] as int? ?? 0,
      usedInFixCount: map['usedInFixCount'] as int? ?? 0,
      confidenceLevel: (map['confidenceLevel'] as num? ?? 0.0).toDouble(),
      chipsetType: map['chipsetType'] as String? ?? 'UNKNOWN',
      averageSignalStrength: (map['averageSignalStrength'] as num? ?? 0.0).toDouble(),
      satelliteDetails: map['satelliteDetails'] as List<dynamic>? ?? [],
      acquisitionTimeMs: map['acquisitionTimeMs'] as int? ?? 0,
      verificationMethods: map['verificationMethods'] as List<dynamic>? ?? [],
    );
  }

  factory NavicDetectionResult.error([String? message]) {
    return NavicDetectionResult(
      isSupported: false,
      isActive: false,
      detectionMethod: 'ERROR',
      message: message ?? 'Detection failed',
      satelliteCount: 0,
      totalSatellites: 0,
      usedInFixCount: 0,
      confidenceLevel: 0.0,
      chipsetType: 'UNKNOWN',
      averageSignalStrength: 0.0,
      satelliteDetails: const [],
      acquisitionTimeMs: 0,
      verificationMethods: const [],
      hasError: true,
    );
  }

  Map<String, dynamic> toMap() => {
    'isSupported': isSupported,
    'isActive': isActive,
    'detectionMethod': detectionMethod,
    'message': message,
    'satelliteCount': satelliteCount,
    'totalSatellites': totalSatellites,
    'usedInFixCount': usedInFixCount,
    'confidenceLevel': confidenceLevel,
    'chipsetType': chipsetType,
    'averageSignalStrength': averageSignalStrength,
    'satelliteDetails': satelliteDetails,
    'acquisitionTimeMs': acquisitionTimeMs,
    'verificationMethods': verificationMethods,
    'hasError': hasError,
  };
}

class GnssCapabilities {
  final int androidVersion;
  final String manufacturer;
  final String model;
  final String device;
  final String hardware;
  final String board;
  final bool hasGnssFeature;
  final bool hasNavic;
  final Map<String, dynamic> gnssCapabilities;
  final String capabilitiesMethod;

  const GnssCapabilities({
    required this.androidVersion,
    required this.manufacturer,
    required this.model,
    required this.device,
    required this.hardware,
    required this.board,
    required this.hasGnssFeature,
    required this.hasNavic,
    required this.gnssCapabilities,
    required this.capabilitiesMethod,
  });

  factory GnssCapabilities.fromMap(Map<String, dynamic> map) {
    return GnssCapabilities(
      androidVersion: map['androidVersion'] as int? ?? 0,
      manufacturer: map['manufacturer'] as String? ?? 'Unknown',
      model: map['model'] as String? ?? 'Unknown',
      device: map['device'] as String? ?? 'Unknown',
      hardware: map['hardware'] as String? ?? 'Unknown',
      board: map['board'] as String? ?? 'Unknown',
      hasGnssFeature: map['hasGnssFeature'] as bool? ?? false,
      hasNavic: (map['gnssCapabilities'] as Map?)?['hasIrnss'] as bool? ?? false,
      gnssCapabilities: Map<String, dynamic>.from(map['gnssCapabilities'] as Map? ?? {}),
      capabilitiesMethod: map['capabilitiesMethod'] as String? ?? 'UNKNOWN',
    );
  }

  factory GnssCapabilities.error() => const GnssCapabilities(
    androidVersion: 0,
    manufacturer: 'Unknown',
    model: 'Unknown',
    device: 'Unknown',
    hardware: 'Unknown',
    board: 'Unknown',
    hasGnssFeature: false,
    hasNavic: false,
    gnssCapabilities: {},
    capabilitiesMethod: 'ERROR',
  );
}

class DetectionResponse {
  final bool success;
  final String message;

  const DetectionResponse({
    required this.success,
    required this.message,
  });

  factory DetectionResponse.fromMap(Map<String, dynamic> map) {
    return DetectionResponse(
      success: map['success'] as bool? ?? false,
      message: map['message'] as String? ?? 'No response message',
    );
  }

  factory DetectionResponse.error(String message) {
    return DetectionResponse(
      success: false,
      message: message,
    );
  }
}

class LocationPermissions {
  final bool hasFineLocation;
  final bool hasCoarseLocation;
  final bool allPermissionsGranted;

  const LocationPermissions({
    required this.hasFineLocation,
    required this.hasCoarseLocation,
    required this.allPermissionsGranted,
  });

  factory LocationPermissions.fromMap(Map<String, dynamic> map) {
    return LocationPermissions(
      hasFineLocation: map['hasFineLocation'] as bool? ?? false,
      hasCoarseLocation: map['hasCoarseLocation'] as bool? ?? false,
      allPermissionsGranted: map['allPermissionsGranted'] as bool? ?? false,
    );
  }

  factory LocationPermissions.error() => const LocationPermissions(
    hasFineLocation: false,
    hasCoarseLocation: false,
    allPermissionsGranted: false,
  );
}

class SatelliteUpdateData {
  final String type;
  final int timestamp;
  final int totalSatellites;
  final Map<String, int> constellations;
  final List<dynamic> satellites;
  final List<dynamic> navicSatellites;
  final bool isNavicAvailable;
  final int navicSatellitesCount;
  final int navicUsedInFix;
  final String primarySystem;
  final String locationProvider;

  const SatelliteUpdateData({
    required this.type,
    required this.timestamp,
    required this.totalSatellites,
    required this.constellations,
    required this.satellites,
    required this.navicSatellites,
    required this.isNavicAvailable,
    required this.navicSatellitesCount,
    required this.navicUsedInFix,
    required this.primarySystem,
    required this.locationProvider,
  });

  factory SatelliteUpdateData.fromMap(Map<String, dynamic> map) {
    final navicSatsList = map['navicSatellites'] as List<dynamic>? ?? [];
    return SatelliteUpdateData(
      type: map['type'] as String? ?? 'UNKNOWN',
      timestamp: map['timestamp'] as int? ?? 0,
      totalSatellites: map['totalSatellites'] as int? ?? 0,
      constellations: Map<String, int>.from(map['constellations'] as Map? ?? {}),
      satellites: map['satellites'] as List<dynamic>? ?? [],
      navicSatellites: navicSatsList,
      isNavicAvailable: map['isNavicAvailable'] as bool? ?? false,
      navicSatellitesCount: navicSatsList.length,
      navicUsedInFix: map['navicUsedInFix'] as int? ?? 0,
      primarySystem: map['primarySystem'] as String? ?? 'GPS',
      locationProvider: map['locationProvider'] as String? ?? 'UNKNOWN',
    );
  }

  Map<String, dynamic> toMap() => {
    'type': type,
    'timestamp': timestamp,
    'totalSatellites': totalSatellites,
    'constellations': constellations,
    'satellites': satellites,
    'navicSatellites': navicSatellites,
    'isNavicAvailable': isNavicAvailable,
    'navicSatellitesCount': navicSatellitesCount,
    'navicUsedInFix': navicUsedInFix,
    'primarySystem': primarySystem,
    'locationProvider': locationProvider,
  };
}