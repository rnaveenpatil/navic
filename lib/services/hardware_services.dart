import 'dart:async';
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

  /// Checks if the device hardware supports NavIC with enhanced satellite detection
  static Future<NavicDetectionResult> checkNavicHardware() async {
    try {
      // Return cached result if valid
      if (_cachedResult != null && _lastDetectionTime != null) {
        if (DateTime.now().difference(_lastDetectionTime!) < _cacheValidity) {
          print("📦 Returning cached NavIC detection result");
          return _cachedResult!;
        }
      }

      print("🚀 Starting enhanced NavIC hardware detection...");
      final Map<dynamic, dynamic> result = await _channel.invokeMethod('checkNavicHardware');
      final converted = _convertResult(result);
      
      final detectionResult = NavicDetectionResult.fromMap(converted);
      _cachedResult = detectionResult;
      _lastDetectionTime = DateTime.now();

      // Log enhanced detection results
      _logDetectionResults(converted);

      return detectionResult;
    } on PlatformException catch (e) {
      print("❌ Platform error checking NavIC hardware: ${e.message}");
      print("📋 Error details: ${e.details}");
      return NavicDetectionResult.error('Platform error: ${e.message}');
    } catch (e, stackTrace) {
      print("❌ Unexpected error checking NavIC hardware: $e");
      print("📋 Stack trace: $stackTrace");
      return NavicDetectionResult.error('Unexpected error: $e');
    }
  }

  /// Get all visible satellites
  static Future<AllSatellitesResult> getAllSatellites() async {
    try {
      print("🛰️ Getting all visible satellites...");
      final Map<dynamic, dynamic> result = await _channel.invokeMethod('getAllSatellites');
      final converted = _convertResult(result);
      
      return AllSatellitesResult.fromMap(converted);
    } on PlatformException catch (e) {
      print("❌ Platform error getting all satellites: ${e.message}");
      return AllSatellitesResult.error();
    } catch (e, stackTrace) {
      print("❌ Unexpected error getting all satellites: $e");
      print("📋 Stack trace: $stackTrace");
      return AllSatellitesResult.error();
    }
  }

  /// Get device GNSS capabilities with enhanced information
  static Future<GnssCapabilities> getGnssCapabilities() async {
    try {
      final Map<dynamic, dynamic> capabilities = await _channel.invokeMethod('getGnssCapabilities');
      final converted = _convertResult(capabilities);
      return GnssCapabilities.fromMap(converted);
    } on PlatformException catch (e) {
      print("❌ Platform error getting GNSS capabilities: ${e.message}");
      return GnssCapabilities.error();
    } catch (e, stackTrace) {
      print("❌ Unexpected error getting GNSS capabilities: $e");
      print("📋 Stack trace: $stackTrace");
      return GnssCapabilities.error();
    }
  }

  /// Start enhanced real-time satellite monitoring
  static Future<DetectionResponse> startRealTimeDetection() async {
    try {
      if (_isRealTimeActive) {
        print("ℹ️ Real-time detection already active");
        return DetectionResponse(
          success: false,
          message: 'Real-time detection already active'
        );
      }

      _channel.setMethodCallHandler(_handleMethodCall);

      final Map<dynamic, dynamic> result = await _channel.invokeMethod('startRealTimeDetection');
      final converted = _convertResult(result);

      _isRealTimeActive = converted['success'] == true;

      if (_isRealTimeActive) {
        print("🛰️ Enhanced real-time NavIC detection started successfully");
      } else {
        print("❌ Failed to start real-time detection");
      }

      return DetectionResponse.fromMap(converted);
    } on PlatformException catch (e) {
      print("❌ Platform error starting real-time detection: ${e.message}");
      return DetectionResponse.error('Platform error: ${e.message}');
    } catch (e, stackTrace) {
      print("❌ Unexpected error starting real-time detection: $e");
      print("📋 Stack trace: $stackTrace");
      return DetectionResponse.error('Unexpected error: $e');
    }
  }

  /// Stop real-time satellite monitoring
  static Future<DetectionResponse> stopRealTimeDetection() async {
    try {
      if (!_isRealTimeActive) {
        print("ℹ️ Real-time detection not active");
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
      print("❌ Platform error stopping real-time detection: ${e.message}");
      return DetectionResponse.error('Platform error: ${e.message}');
    } catch (e, stackTrace) {
      print("❌ Unexpected error stopping real-time detection: $e");
      print("📋 Stack trace: $stackTrace");
      return DetectionResponse.error('Unexpected error: $e');
    }
  }

  /// Start location updates
  static Future<DetectionResponse> startLocationUpdates() async {
    try {
      if (_isLocationTracking) {
        print("ℹ️ Location updates already active");
        return DetectionResponse(
          success: false,
          message: 'Location updates already active'
        );
      }

      final Map<dynamic, dynamic> result = await _channel.invokeMethod('startLocationUpdates');
      final converted = _convertResult(result);

      _isLocationTracking = converted['success'] == true;

      if (_isLocationTracking) {
        print("📍 Location updates started successfully");
      } else {
        print("❌ Failed to start location updates");
      }

      return DetectionResponse.fromMap(converted);
    } on PlatformException catch (e) {
      print("❌ Platform error starting location updates: ${e.message}");
      return DetectionResponse.error('Platform error: ${e.message}');
    } catch (e, stackTrace) {
      print("❌ Unexpected error starting location updates: $e");
      print("📋 Stack trace: $stackTrace");
      return DetectionResponse.error('Unexpected error: $e');
    }
  }

  /// Stop location updates
  static Future<DetectionResponse> stopLocationUpdates() async {
    try {
      if (!_isLocationTracking) {
        print("ℹ️ Location updates not active");
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
      print("❌ Platform error stopping location updates: ${e.message}");
      return DetectionResponse.error('Platform error: ${e.message}');
    } catch (e, stackTrace) {
      print("❌ Unexpected error stopping location updates: $e");
      print("📋 Stack trace: $stackTrace");
      return DetectionResponse.error('Unexpected error: $e');
    }
  }

  /// Check location permissions
  static Future<LocationPermissions> checkLocationPermissions() async {
    try {
      final Map<dynamic, dynamic> result = await _channel.invokeMethod('checkLocationPermissions');
      final converted = _convertResult(result);
      return LocationPermissions.fromMap(converted);
    } on PlatformException catch (e) {
      print("❌ Platform error checking permissions: ${e.message}");
      return LocationPermissions.error();
    } catch (e, stackTrace) {
      print("❌ Unexpected error checking permissions: $e");
      print("📋 Stack trace: $stackTrace");
      return LocationPermissions.error();
    }
  }

  /// Handle method calls from native side
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    try {
      print("📱 Method call received: ${call.method}");
      
      switch (call.method) {
        case "onSatelliteUpdate":
          await _handleSatelliteUpdate(call);
          break;
        case "onLocationUpdate":
          await _handleLocationUpdate(call);
          break;
        default:
          print("⚠️ Unknown method call: ${call.method}");
      }
    } on PlatformException catch (e) {
      print("❌ Platform error in method call handler: ${e.message}");
    } catch (e, stackTrace) {
      print("❌ Unexpected error in method call handler: $e");
      print("📋 Stack trace: $stackTrace");
    }
    return null;
  }

  /// Handle satellite update callback with enhanced information
  static Future<void> _handleSatelliteUpdate(MethodCall call) async {
    if (_onSatelliteUpdate == null) {
      print("⚠️ No satellite update callback registered");
      return;
    }
    
    try {
      final Map<dynamic, dynamic> data = call.arguments as Map<dynamic, dynamic>;
      final convertedData = _convertResult(data);
      
      // Call the registered callback
      _onSatelliteUpdate!(convertedData);

      // Log enhanced satellite update summary
      _logSatelliteUpdate(convertedData);
      
    } catch (e, stackTrace) {
      print("❌ Error processing satellite update: $e");
      print("📋 Stack trace: $stackTrace");
    }
  }

  /// Handle location update callback
  static Future<void> _handleLocationUpdate(MethodCall call) async {
    if (_onLocationUpdate == null) {
      print("⚠️ No location update callback registered");
      return;
    }
    
    try {
      final Map<dynamic, dynamic> data = call.arguments as Map<dynamic, dynamic>;
      final locationData = _convertResult(data);
      
      // Call the registered callback
      _onLocationUpdate!(locationData);

      // Log location update
      _logLocationUpdate(locationData);
      
    } catch (e, stackTrace) {
      print("❌ Error processing location update: $e");
      print("📋 Stack trace: $stackTrace");
    }
  }

  /// Log detection results with enhanced information
  static void _logDetectionResults(Map<String, dynamic> data) {
    print("\n🎯 Enhanced Detection Results:");
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
    print("  📡 Positioning Method: ${data['positioningMethod'] ?? 'UNKNOWN'}");
    print("  📶 L5 Band: ${data['hasL5Band'] == true ? '✅ Supported' : '❌ Not Supported'}");
    
    if (data['l5BandInfo'] is Map) {
      final l5Info = data['l5BandInfo'] as Map<String, dynamic>;
      final confidence = (l5Info['confidence'] as num?)?.toDouble() ?? 0.0;
      print("  🔍 L5 Confidence: ${(confidence * 100).toStringAsFixed(1)}%");
    }
    
    // Log verification methods
    if (data['verificationMethods'] is List) {
      final methods = data['verificationMethods'] as List<dynamic>;
      if (methods.isNotEmpty) {
        print("  🔐 Verification Methods: ${methods.join(', ')}");
      }
    }
  }

  /// Log satellite update information
  static void _logSatelliteUpdate(Map<String, dynamic> satelliteData) {
    final total = satelliteData['totalSatellites'] ?? 0;
    final navicCount = satelliteData['navicSatellitesCount'] ?? 0;
    final navicUsed = satelliteData['navicUsedInFix'] ?? 0;
    final primary = satelliteData['primarySystem'] ?? 'GPS';
    final hasL5 = satelliteData['hasL5Band'] ?? false;
    
    print("\n📡 Enhanced Satellite Update:");
    print("  📡 Total Satellites: $total");
    if (navicCount > 0) {
      print("  🇮🇳 NavIC: $navicCount ($navicUsed in fix)");
    }
    print("  🎯 Primary System: $primary");
    print("  📶 L5 Band: ${hasL5 ? '✅ Enabled' : '❌ Not Available'}");
    
    // Log system statistics if available
    if (satelliteData['systemStats'] is Map) {
      final systemStats = satelliteData['systemStats'] as Map<String, dynamic>;
      print("  📊 System Usage:");
      for (final entry in systemStats.entries) {
        if (entry.value is Map) {
          final stats = entry.value as Map<String, dynamic>;
          final totalSats = stats['total'] ?? 0;
          final used = stats['used'] ?? 0;
          if (totalSats > 0) {
            final flag = stats['flag'] ?? '🌍';
            print("    $flag ${entry.key}: $used/$totalSats in fix");
          }
        }
      }
    }
  }

  /// Log location update information
  static void _logLocationUpdate(Map<String, dynamic> locationData) {
    final lat = (locationData['latitude'] as num?)?.toStringAsFixed(6) ?? 'N/A';
    final lng = (locationData['longitude'] as num?)?.toStringAsFixed(6) ?? 'N/A';
    final acc = (locationData['accuracy'] as num?)?.toStringAsFixed(1) ?? 'N/A';
    final provider = locationData['provider'] ?? 'UNKNOWN';
    final speed = (locationData['speed'] as num?)?.toStringAsFixed(1) ?? '0.0';
    final bearing = (locationData['bearing'] as num?)?.toStringAsFixed(0) ?? '0';
    final altitude = (locationData['altitude'] as num?)?.toStringAsFixed(1) ?? 'N/A';
    
    print("\n📍 Location Update:");
    print("  🌍 Coordinates: $lat, $lng");
    print("  ⛰️ Altitude: ${altitude}m");
    print("  📏 Accuracy: ${acc}m");
    print("  🚀 Speed: ${speed}m/s");
    print("  🧭 Bearing: ${bearing}°");
    print("  🔧 Provider: $provider");
  }

  /// Set callback for satellite updates
  static void setSatelliteUpdateCallback(Function(Map<String, dynamic>) callback) {
    _onSatelliteUpdate = callback;
    print("📡 Enhanced satellite update callback registered");
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

  /// Clear cached detection results
  static void clearCache() {
    _cachedResult = null;
    _lastDetectionTime = null;
    print("🧹 Detection cache cleared");
  }

  // Helper method to convert dynamic Map to String-keyed Map
  static Map<String, dynamic> _convertResult(Map<dynamic, dynamic> result) {
    return result.cast<String, dynamic>();
  }
}

// Enhanced Data Models for type-safe responses

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
  final bool hasL5Band;
  final Map<String, dynamic> l5BandInfo;
  final List<dynamic> allSatellites;
  final String positioningMethod;
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
    required this.hasL5Band,
    required this.l5BandInfo,
    required this.allSatellites,
    required this.positioningMethod,
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
      hasL5Band: map['hasL5Band'] as bool? ?? false,
      l5BandInfo: Map<String, dynamic>.from(map['l5BandInfo'] as Map? ?? {}),
      allSatellites: map['allSatellites'] as List<dynamic>? ?? [],
      positioningMethod: map['positioningMethod'] as String? ?? 'UNKNOWN',
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
      hasL5Band: false,
      l5BandInfo: const {},
      allSatellites: const [],
      positioningMethod: 'ERROR',
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
    'hasL5Band': hasL5Band,
    'l5BandInfo': l5BandInfo,
    'allSatellites': allSatellites,
    'positioningMethod': positioningMethod,
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
  final bool hasL5Band;

  const DetectionResponse({
    required this.success,
    required this.message,
    this.hasL5Band = false,
  });

  factory DetectionResponse.fromMap(Map<String, dynamic> map) {
    return DetectionResponse(
      success: map['success'] as bool? ?? false,
      message: map['message'] as String? ?? 'No response message',
      hasL5Band: map['hasL5Band'] as bool? ?? false,
    );
  }

  factory DetectionResponse.error(String message) {
    return DetectionResponse(
      success: false,
      message: message,
      hasL5Band: false,
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

class AllSatellitesResult {
  final List<dynamic> satellites;
  final List<dynamic> systems;
  final int totalSatellites;
  final bool hasL5Band;
  final int timestamp;
  final bool hasError;

  const AllSatellitesResult({
    required this.satellites,
    required this.systems,
    required this.totalSatellites,
    required this.hasL5Band,
    required this.timestamp,
    this.hasError = false,
  });

  factory AllSatellitesResult.fromMap(Map<String, dynamic> map) {
    return AllSatellitesResult(
      satellites: map['satellites'] as List<dynamic>? ?? [],
      systems: map['systems'] as List<dynamic>? ?? [],
      totalSatellites: map['totalSatellites'] as int? ?? 0,
      hasL5Band: map['hasL5Band'] as bool? ?? false,
      timestamp: map['timestamp'] as int? ?? 0,
    );
  }

  factory AllSatellitesResult.error() => const AllSatellitesResult(
    satellites: [],
    systems: [],
    totalSatellites: 0,
    hasL5Band: false,
    timestamp: 0,
    hasError: true,
  );
}