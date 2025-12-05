// lib/services/location_service.dart
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'hardware_services.dart';

class EnhancedPosition {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double? altitude;
  final double? speed;
  final double? heading;
  final DateTime timestamp;
  final bool isNavicEnhanced;
  final double confidenceScore;
  final String locationSource;
  final String detectionReason;
  final int? navicSatellites;
  final int? totalSatellites;
  final int? navicUsedInFix;
  final Map<String, dynamic> satelliteInfo;
  final bool hasL5Band;
  final String positioningMethod;
  final Map<String, dynamic> systemStats;
  final String primarySystem;
  final String chipsetType;
  final String chipsetVendor;
  final String chipsetModel;
  final double chipsetConfidence;
  final double l5Confidence;

  const EnhancedPosition({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
    required this.timestamp,
    required this.isNavicEnhanced,
    required this.confidenceScore,
    required this.locationSource,
    required this.detectionReason,
    this.navicSatellites,
    this.totalSatellites,
    this.navicUsedInFix,
    required this.hasL5Band,
    required this.positioningMethod,
    Map<String, dynamic>? satelliteInfo,
    Map<String, dynamic>? systemStats,
    required this.primarySystem,
    required this.chipsetType,
    required this.chipsetVendor,
    required this.chipsetModel,
    required this.chipsetConfidence,
    required this.l5Confidence,
  }) : satelliteInfo = satelliteInfo ?? const {},
        systemStats = systemStats ?? const {};

  factory EnhancedPosition.fromPosition(
      Position position, {
        required bool isNavicEnhanced,
        required double confidenceScore,
        required String locationSource,
        required String detectionReason,
        int? navicSatellites,
        int? totalSatellites,
        int? navicUsedInFix,
        required bool hasL5Band,
        required String positioningMethod,
        Map<String, dynamic>? satelliteInfo,
        Map<String, dynamic>? systemStats,
        required String primarySystem,
        required String chipsetType,
        required String chipsetVendor,
        required String chipsetModel,
        required double chipsetConfidence,
        required double l5Confidence,
      }) {
    return EnhancedPosition(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      altitude: position.altitude,
      speed: position.speed,
      heading: position.heading,
      timestamp: position.timestamp,
      isNavicEnhanced: isNavicEnhanced,
      confidenceScore: confidenceScore,
      locationSource: locationSource,
      detectionReason: detectionReason,
      navicSatellites: navicSatellites,
      totalSatellites: totalSatellites,
      navicUsedInFix: navicUsedInFix,
      hasL5Band: hasL5Band,
      positioningMethod: positioningMethod,
      satelliteInfo: satelliteInfo,
      systemStats: systemStats,
      primarySystem: primarySystem,
      chipsetType: chipsetType,
      chipsetVendor: chipsetVendor,
      chipsetModel: chipsetModel,
      chipsetConfidence: chipsetConfidence,
      l5Confidence: l5Confidence,
    );
  }

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'altitude': altitude,
    'speed': speed,
    'heading': heading,
    'timestamp': timestamp.toIso8601String(),
    'isNavicEnhanced': isNavicEnhanced,
    'confidenceScore': confidenceScore,
    'locationSource': locationSource,
    'detectionReason': detectionReason,
    'navicSatellites': navicSatellites,
    'totalSatellites': totalSatellites,
    'navicUsedInFix': navicUsedInFix,
    'hasL5Band': hasL5Band,
    'positioningMethod': positioningMethod,
    'satelliteInfo': satelliteInfo,
    'systemStats': systemStats,
    'primarySystem': primarySystem,
    'chipsetType': chipsetType,
    'chipsetVendor': chipsetVendor,
    'chipsetModel': chipsetModel,
    'chipsetConfidence': chipsetConfidence,
    'l5Confidence': l5Confidence,
  };

  @override
  String toString() {
    return 'EnhancedPosition(lat: ${latitude.toStringAsFixed(6)}, lng: ${longitude.toStringAsFixed(6)}, '
        'acc: ${accuracy.toStringAsFixed(2)}m, navic: $isNavicEnhanced, '
        'conf: ${(confidenceScore * 100).toStringAsFixed(1)}%, '
        'primary: $primarySystem, '
        'chipset: $chipsetVendor $chipsetModel, '
        'L5: ${hasL5Band ? "Yes" : "No"}, '
        'Method: $positioningMethod)';
  }
}

class EnhancedLocationService {
  final List<EnhancedPosition> _locationHistory = [];
  final List<double> _recentAccuracies = [];
  final List<Position> _rawPositions = [];

  // Hardware state
  bool _isNavicSupported = false;
  bool _isNavicActive = false;
  int _navicSatelliteCount = 0;
  int _totalSatelliteCount = 0;
  int _navicUsedInFix = 0;
  String _detectionMethod = "UNKNOWN";
  String _primarySystem = "GPS";
  bool _isRealTimeMonitoring = false;
  double _averageSignalStrength = 0.0;
  String _chipsetType = "UNKNOWN";
  String _chipsetVendor = "UNKNOWN";
  String _chipsetModel = "UNKNOWN";
  double _chipsetConfidence = 0.0;
  double _confidenceLevel = 0.0;
  bool _hasL5Band = false;
  double _l5Confidence = 0.0;
  String _positioningMethod = "GPS_PRIMARY";
  Map<String, dynamic> _l5BandInfo = {};
  Map<String, dynamic> _systemStats = {};

  // Performance tracking
  double _bestAccuracy = double.infinity;
  int _highAccuracyReadings = 0;
  int _totalReadings = 0;
  DateTime? _lastHardwareCheck;

  // Satellite tracking
  List<dynamic> _allSatellites = [];
  List<dynamic> _visibleSystems = [];
  List<dynamic> _satelliteDetails = [];

  static final EnhancedLocationService _instance = EnhancedLocationService._internal();
  factory EnhancedLocationService() => _instance;

  EnhancedLocationService._internal() {
    print("✅ LocationService created");
  }

  /// Initialize service
  Future<void> initializeService() async {
    print("🚀 Initializing Location Service...");
    
    try {
      NavicHardwareService.initialize();
      print("✅ NavicHardwareService initialized");
    } catch (e) {
      print("❌ Failed to initialize NavicHardwareService: $e");
    }
  }

  /// Check location permission
  Future<bool> checkLocationPermission() async {
    try {
      print("📍 Checking location services...");
      
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print("⚠️ Location services disabled");
        return false;
      }

      print("📍 Checking location permission...");
      LocationPermission permission = await Geolocator.checkPermission();

      print("📍 Current permission status: $permission");

      switch (permission) {
        case LocationPermission.deniedForever:
          print("❌ Location permission denied forever");
          return false;
        case LocationPermission.denied:
          print("📍 Location permission denied, requesting...");
          return false;
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          print("✅ Location permission granted");
          return true;
        case LocationPermission.unableToDetermine:
          print("⚠️ Unable to determine location permission");
          return false;
      }
    } catch (e) {
      print("❌ Error checking location permission: $e");
      return false;
    }
  }

  /// Request location permission
  Future<bool> requestLocationPermission() async {
    try {
      print("📍 Requesting location permission...");
      
      LocationPermission permission = await Geolocator.requestPermission();
      print("📍 Permission request result: $permission");

      switch (permission) {
        case LocationPermission.deniedForever:
          print("❌ Location permission denied forever");
          return false;
        case LocationPermission.denied:
          print("❌ Location permission denied");
          return false;
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          print("✅ Location permission granted");
          
          await _performHardwareDetection();
          
          return true;
        case LocationPermission.unableToDetermine:
          print("⚠️ Unable to determine location permission");
          return false;
      }
    } catch (e) {
      print("❌ Error requesting location permission: $e");
      return false;
    }
  }

  /// Get current location
  Future<EnhancedPosition?> getCurrentLocation() async {
    try {
      print("📍 Getting current location...");
      
      final hasPermission = await checkLocationPermission();
      if (!hasPermission) {
        print("📍 No permission, requesting...");
        final permissionGranted = await requestLocationPermission();
        if (!permissionGranted) {
          print("❌ Location permission not granted");
          return null;
        }
      }

      await _performHardwareDetection();

      print("📍 Acquiring position...");
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 15),
      );

      print("📍 Position acquired: ${position.latitude}, ${position.longitude}");
      
      _totalReadings++;
      _updatePerformanceTracking(position.accuracy, position);

      final enhancedPosition = _createEnhancedPosition(position);
      _addToHistory(enhancedPosition);

      return enhancedPosition;

    } catch (e) {
      print("❌ Location acquisition failed: $e");
      
      if (e.toString().contains('PERMISSION_DENIED') || 
          e.toString().contains('Location services disabled')) {
        print("⚠️ Permission or location services issue detected");
      }
      
      return null;
    }
  }

  /// Perform hardware detection
  Future<void> _performHardwareDetection() async {
    try {
      if (_lastHardwareCheck != null &&
          DateTime.now().difference(_lastHardwareCheck!) < const Duration(minutes: 5)) {
        print("ℹ️ Using cached hardware detection results");
        return;
      }

      print("🔍 Performing hardware detection...");
      final hardwareResult = await NavicHardwareService.checkNavicHardware();

      _isNavicSupported = hardwareResult.isSupported;
      _isNavicActive = hardwareResult.isActive;
      _navicSatelliteCount = hardwareResult.satelliteCount;
      _totalSatelliteCount = hardwareResult.totalSatellites;
      _navicUsedInFix = hardwareResult.usedInFixCount;
      _detectionMethod = hardwareResult.detectionMethod;
      _confidenceLevel = hardwareResult.confidenceLevel;
      _chipsetType = hardwareResult.chipsetType;
      _chipsetVendor = hardwareResult.chipsetVendor;
      _chipsetModel = hardwareResult.chipsetModel;
      _averageSignalStrength = hardwareResult.averageSignalStrength;
      _hasL5Band = hardwareResult.hasL5Band;
      _positioningMethod = hardwareResult.positioningMethod;
      _primarySystem = hardwareResult.primarySystem;
      _l5BandInfo = hardwareResult.l5BandInfo;
      _allSatellites = hardwareResult.allSatellites;
      _lastHardwareCheck = DateTime.now();

      _l5Confidence = (_l5BandInfo['confidence'] as num?)?.toDouble() ?? 0.0;
      _chipsetConfidence = _confidenceLevel;

      _updateSystemStats();

      _logHardwareDetectionResult(hardwareResult);

    } catch (e) {
      print("❌ Hardware detection failed: $e");
      _resetToDefaultState();
    }
  }

  /// Update system statistics
  void _updateSystemStats() {
    final systemCounts = <String, int>{};
    final systemUsed = <String, int>{};
    final systemSignalTotals = <String, double>{};
    final systemSignalCounts = <String, int>{};

    for (final sat in _allSatellites) {
      if (sat is Map<String, dynamic>) {
        final system = sat['system'] as String? ?? 'UNKNOWN';
        final used = sat['usedInFix'] as bool? ?? false;
        final cn0 = (sat['cn0DbHz'] as num?)?.toDouble() ?? 0.0;

        systemCounts[system] = (systemCounts[system] ?? 0) + 1;
        if (used) {
          systemUsed[system] = (systemUsed[system] ?? 0) + 1;
        }
        if (cn0 > 0) {
          systemSignalTotals[system] = (systemSignalTotals[system] ?? 0.0) + cn0;
          systemSignalCounts[system] = (systemSignalCounts[system] ?? 0) + 1;
        }
      }
    }

    _systemStats.clear();
    for (final entry in systemCounts.entries) {
      final system = entry.key;
      final total = entry.value;
      final used = systemUsed[system] ?? 0;
      final signalTotal = systemSignalTotals[system] ?? 0.0;
      final signalCount = systemSignalCounts[system] ?? 0;
      final avgSignal = signalCount > 0 ? signalTotal / signalCount : 0.0;
      final utilization = total > 0 ? (used * 100.0 / total) : 0.0;

      _systemStats[system] = {
        'name': system,
        'total': total,
        'used': used,
        'available': total - used,
        'averageSignal': avgSignal,
        'utilization': utilization,
        'signalCount': signalCount,
      };
    }

    _visibleSystems = _systemStats.values.toList();
    
    _satelliteDetails = _allSatellites.where((sat) {
      if (sat is Map<String, dynamic>) {
        final cn0 = (sat['cn0DbHz'] as num?)?.toDouble() ?? 0.0;
        return cn0 > 10.0;
      }
      return false;
    }).toList();
  }

  /// Log hardware detection results
  void _logHardwareDetectionResult(NavicDetectionResult result) {
    print("\n🎯 Hardware Detection:");
    print("  ✅ NavIC Supported: $_isNavicSupported");
    print("  📡 NavIC Active: $_isNavicActive");
    print("  🛰️ NavIC Sats: $_navicSatelliteCount ($_navicUsedInFix in fix)");
    print("  📊 Total Sats: $_totalSatelliteCount");
    print("  🔧 Method: $_detectionMethod");
    print("  🏭 Vendor: $_chipsetVendor");
    print("  📋 Model: $_chipsetModel");
    print("  🎯 Confidence: ${(_confidenceLevel * 100).toStringAsFixed(1)}%");
    print("  📶 Signal: ${_averageSignalStrength.toStringAsFixed(1)} dB-Hz");
    print("  🎯 Positioning: $_positioningMethod");
    print("  🎯 Primary System: $_primarySystem");
    print("  📡 L5 Band: ${_hasL5Band ? 'Yes' : 'No'}");
    print("  🔍 L5 Confidence: ${(_l5Confidence * 100).toStringAsFixed(1)}%");
  }

  void _resetToDefaultState() {
    _isNavicSupported = false;
    _isNavicActive = false;
    _navicSatelliteCount = 0;
    _totalSatelliteCount = 0;
    _navicUsedInFix = 0;
    _detectionMethod = "ERROR";
    _confidenceLevel = 0.0;
    _chipsetType = "UNKNOWN";
    _chipsetVendor = "UNKNOWN";
    _chipsetModel = "UNKNOWN";
    _chipsetConfidence = 0.0;
    _averageSignalStrength = 0.0;
    _hasL5Band = false;
    _l5Confidence = 0.0;
    _positioningMethod = "ERROR";
    _primarySystem = "GPS";
    _l5BandInfo = {};
    _systemStats = {};
    _allSatellites = [];
    _visibleSystems = [];
    _satelliteDetails = [];
  }

  /// Create enhanced position
  EnhancedPosition _createEnhancedPosition(Position position) {
    final isNavicEnhanced = _isNavicSupported && _isNavicActive && _navicUsedInFix > 0;
    final locationSource = isNavicEnhanced ? "NAVIC" : _primarySystem;

    final enhancedAccuracy = _calculateAccuracy(
      position.accuracy,
      isNavicEnhanced,
    );

    final confidenceScore = _calculateConfidenceScore(
      enhancedAccuracy,
      isNavicEnhanced,
    );

    final satelliteInfo = _createSatelliteInfo(
      position.accuracy,
      enhancedAccuracy,
      isNavicEnhanced,
    );

    return EnhancedPosition.fromPosition(
      position,
      isNavicEnhanced: isNavicEnhanced,
      confidenceScore: confidenceScore,
      locationSource: locationSource,
      detectionReason: _generateStatusMessage(),
      navicSatellites: _navicSatelliteCount,
      totalSatellites: _totalSatelliteCount,
      navicUsedInFix: _navicUsedInFix,
      hasL5Band: _hasL5Band,
      positioningMethod: _positioningMethod,
      satelliteInfo: satelliteInfo,
      systemStats: _systemStats,
      primarySystem: _primarySystem,
      chipsetType: _chipsetType,
      chipsetVendor: _chipsetVendor,
      chipsetModel: _chipsetModel,
      chipsetConfidence: _chipsetConfidence,
      l5Confidence: _l5Confidence,
    );
  }

  /// Accuracy calculation
  double _calculateAccuracy(double baseAccuracy, bool isNavicEnhanced) {
    double enhancedAccuracy = baseAccuracy;

    if (_hasL5Band) {
      final l5Boost = _l5Confidence * 0.30;
      enhancedAccuracy *= (1.0 - l5Boost);
    }

    if (isNavicEnhanced) {
      if (_navicUsedInFix >= 3) {
        enhancedAccuracy *= 0.65;
      } else if (_navicUsedInFix >= 2) {
        enhancedAccuracy *= 0.78;
      } else if (_navicUsedInFix >= 1) {
        enhancedAccuracy *= 0.88;
      }
    }

    final chipsetBoost = _chipsetConfidence * 0.10;
    enhancedAccuracy *= (1.0 - chipsetBoost);

    if (_totalSatelliteCount >= 20) {
      enhancedAccuracy *= 0.70;
    } else if (_totalSatelliteCount >= 15) {
      enhancedAccuracy *= 0.80;
    } else if (_totalSatelliteCount >= 10) {
      enhancedAccuracy *= 0.85;
    }

    if (_averageSignalStrength > 30.0) {
      enhancedAccuracy *= 0.85;
    } else if (_averageSignalStrength > 25.0) {
      enhancedAccuracy *= 0.90;
    }

    return enhancedAccuracy.clamp(0.5, 50.0);
  }

  /// Calculate confidence score
  double _calculateConfidenceScore(double accuracy, bool isNavicEnhanced) {
    double score = 0.5 + (_confidenceLevel * 0.3);

    if (_hasL5Band) {
      score += 0.25;
      score += _l5Confidence * 0.15;
    }

    if (isNavicEnhanced) {
      score += 0.20;
      if (_navicUsedInFix >= 3) score += 0.15;
      else if (_navicUsedInFix >= 2) score += 0.10;
      else if (_navicUsedInFix >= 1) score += 0.05;
    }

    score += _chipsetConfidence * 0.10;

    if (accuracy < 1.0) score += 0.25;
    else if (accuracy < 2.0) score += 0.20;
    else if (accuracy < 5.0) score += 0.15;
    else if (accuracy < 8.0) score += 0.10;

    if (_totalSatelliteCount >= 15) score += 0.12;
    else if (_totalSatelliteCount >= 10) score += 0.08;

    if (_averageSignalStrength > 30.0) score += 0.10;
    else if (_averageSignalStrength > 25.0) score += 0.07;

    return score.clamp(0.0, 1.0);
  }

  /// Create satellite information
  Map<String, dynamic> _createSatelliteInfo(
      double rawAccuracy,
      double enhancedAccuracy,
      bool isNavicEnhanced,
      ) {
    final improvement = ((rawAccuracy - enhancedAccuracy) / rawAccuracy * 100);

    return {
      'navicSatellites': _navicSatelliteCount,
      'totalSatellites': _totalSatelliteCount,
      'navicUsedInFix': _navicUsedInFix,
      'isNavicActive': _isNavicActive,
      'isNavicSupported': _isNavicSupported,
      'primarySystem': _primarySystem,
      'detectionMethod': _detectionMethod,
      'chipsetType': _chipsetType,
      'chipsetVendor': _chipsetVendor,
      'chipsetModel': _chipsetModel,
      'chipsetConfidence': _chipsetConfidence,
      'confidenceLevel': _confidenceLevel,
      'averageSignalStrength': _averageSignalStrength,
      'hasL5Band': _hasL5Band,
      'l5Confidence': _l5Confidence,
      'l5BandInfo': _l5BandInfo,
      'positioningMethod': _positioningMethod,
      'rawAccuracy': rawAccuracy,
      'enhancedAccuracy': enhancedAccuracy,
      'enhancementBoost': improvement.toStringAsFixed(1),
      'hardwareConfidence': (_confidenceLevel * 100).toStringAsFixed(1),
      'chipsetConfidencePercent': (_chipsetConfidence * 100).toStringAsFixed(1),
      'l5ConfidencePercent': (_l5Confidence * 100).toStringAsFixed(1),
      'acquisitionTime': DateTime.now().toIso8601String(),
      'visibleSystems': _visibleSystems,
      'satelliteDetails': _satelliteDetails,
      'satelliteCount': _allSatellites.length,
      'isRealTimeMonitoring': _isRealTimeMonitoring,
      'systemStats': _systemStats,
    };
  }

  /// Satellite update handler
  void _onSatelliteUpdate(Map<String, dynamic> data) {
    try {
      _navicSatelliteCount = data['navicSatellitesCount'] as int? ?? 0;
      _totalSatelliteCount = data['totalSatellites'] as int? ?? 0;
      _navicUsedInFix = data['navicUsedInFix'] as int? ?? 0;
      _isNavicActive = _navicSatelliteCount > 0;
      _hasL5Band = data['hasL5Band'] as bool? ?? false;
      _primarySystem = data['primarySystem'] as String? ?? 'GPS';

      if (data['satellites'] is List) {
        _allSatellites = data['satellites'] as List<dynamic>;
        _updateSystemStats();
      }

      if (data['systemStats'] is Map) {
        _systemStats = (data['systemStats'] as Map).cast<String, dynamic>();
        _visibleSystems = _systemStats.values.toList();
      }

      _updatePositioningMethod();

    } catch (e) {
      print("❌ Error processing satellite update: $e");
    }
  }

  /// Update positioning method
  void _updatePositioningMethod() {
    if (_isNavicActive && _navicUsedInFix >= 4) {
      _positioningMethod = _hasL5Band ? "NAVIC_PRIMARY_L5" : "NAVIC_PRIMARY";
    } else if (_isNavicActive && _navicUsedInFix >= 2) {
      _positioningMethod = _hasL5Band ? "NAVIC_HYBRID_L5" : "NAVIC_HYBRID";
    } else if (_isNavicActive && _navicUsedInFix >= 1) {
      _positioningMethod = "NAVIC_ASSISTED";
    } else if (_totalSatelliteCount >= 4) {
      if (_systemStats.isNotEmpty) {
        final gpsUsed = (_systemStats['GPS'] as Map<String, dynamic>?)?['used'] as int? ?? 0;
        final glonassUsed = (_systemStats['GLONASS'] as Map<String, dynamic>?)?['used'] as int? ?? 0;
        final galileoUsed = (_systemStats['GALILEO'] as Map<String, dynamic>?)?['used'] as int? ?? 0;
        final beidouUsed = (_systemStats['BEIDOU'] as Map<String, dynamic>?)?['used'] as int? ?? 0;

        if (gpsUsed >= 4) {
          _positioningMethod = _hasL5Band ? "GPS_PRIMARY_L5" : "GPS_PRIMARY";
        } else if (glonassUsed >= 4) {
          _positioningMethod = "GLONASS_PRIMARY";
        } else if (galileoUsed >= 4) {
          _positioningMethod = _hasL5Band ? "GALILEO_PRIMARY_L5" : "GALILEO_PRIMARY";
        } else if (beidouUsed >= 4) {
          _positioningMethod = _hasL5Band ? "BEIDOU_PRIMARY_L5" : "BEIDOU_PRIMARY";
        } else {
          _positioningMethod = _hasL5Band ? "MULTI_GNSS_HYBRID_L5" : "MULTI_GNSS_HYBRID";
        }
      } else {
        _positioningMethod = _hasL5Band ? "GPS_PRIMARY_L5" : "GPS_PRIMARY";
      }
    } else {
      _positioningMethod = "INSUFFICIENT_SATELLITES";
    }
  }

  /// Start real-time monitoring
  Future<void> startRealTimeMonitoring() async {
    if (_isRealTimeMonitoring) {
      print("ℹ️ Real-time monitoring already active");
      return;
    }

    try {
      NavicHardwareService.setSatelliteUpdateCallback(_onSatelliteUpdate);

      final result = await NavicHardwareService.startRealTimeDetection();

      if (result.success) {
        _isRealTimeMonitoring = true;
        _hasL5Band = result.hasL5Band;
        print("🎯 Real-time monitoring started");
        print("  📡 L5 Band: ${_hasL5Band ? 'Yes' : 'No'}");
        if (result.chipset != null) {
          print("  💾 Chipset: ${result.chipset}");
        }
      }
    } catch (e) {
      print("❌ Failed to start real-time monitoring: $e");
    }
  }

  /// Stop real-time monitoring
  Future<void> stopRealTimeMonitoring() async {
    if (!_isRealTimeMonitoring) {
      print("ℹ️ Real-time monitoring not active");
      return;
    }

    try {
      final result = await NavicHardwareService.stopRealTimeDetection();
      if (result.success) {
        NavicHardwareService.removeSatelliteUpdateCallback();
        _isRealTimeMonitoring = false;
        print("⏹️ Real-time monitoring stopped");
      }
    } catch (e) {
      print("❌ Error stopping real-time monitoring: $e");
    }
  }

  /// Performance tracking
  void _updatePerformanceTracking(double accuracy, Position position) {
    _recentAccuracies.add(accuracy);
    if (_recentAccuracies.length > 10) {
      _recentAccuracies.removeAt(0);
    }

    _rawPositions.add(position);
    if (_rawPositions.length > 5) {
      _rawPositions.removeAt(0);
    }

    if (accuracy < 5.0) {
      _highAccuracyReadings++;
    }

    if (accuracy < _bestAccuracy) {
      _bestAccuracy = accuracy;
      print("🏆 New best accuracy: ${_bestAccuracy.toStringAsFixed(2)}m");
    }
  }

  void _addToHistory(EnhancedPosition position) {
    _locationHistory.add(position);
    if (_locationHistory.length > 50) {
      _locationHistory.removeAt(0);
    }
  }

  String _generateStatusMessage() {
    if (!_isNavicSupported && !_hasL5Band) {
      return "Device chipset does not support NavIC and also does not have L5 band. Using standard GPS.";
    } else if (_isNavicSupported && !_hasL5Band) {
      return "Device chipset supports NavIC but does not have L5 band. NavIC positioning available.";
    } else if (_isNavicSupported && _hasL5Band) {
      return "Device chipset supports NavIC and contains L5 band. NavIC positioning ready!";
    } else if (_hasL5Band) {
      return "Device has L5 band support. GPS positioning available.";
    } else {
      return "Using standard GPS positioning.";
    }
  }

  /// Get service statistics
  Map<String, dynamic> getServiceStats() {
    final avgAccuracy = _recentAccuracies.isNotEmpty
        ? _recentAccuracies.reduce((a, b) => a + b) / _recentAccuracies.length
        : 0.0;

    return {
      'totalReadings': _totalReadings,
      'highAccuracyReadings': _highAccuracyReadings,
      'bestAccuracy': _bestAccuracy,
      'averageAccuracy': avgAccuracy,
      'navicSupported': _isNavicSupported,
      'navicActive': _isNavicActive,
      'navicSatellites': _navicSatelliteCount,
      'navicUsedInFix': _navicUsedInFix,
      'totalSatellites': _totalSatelliteCount,
      'primarySystem': _primarySystem,
      'chipsetType': _chipsetType,
      'chipsetVendor': _chipsetVendor,
      'chipsetModel': _chipsetModel,
      'chipsetConfidence': _chipsetConfidence,
      'confidenceLevel': _confidenceLevel,
      'signalStrength': _averageSignalStrength,
      'hasL5Band': _hasL5Band,
      'l5Confidence': _l5Confidence,
      'positioningMethod': _positioningMethod,
      'l5BandInfo': _l5BandInfo,
      'systemStats': _systemStats,
      'realTimeMonitoring': _isRealTimeMonitoring,
      'visibleSatellites': _allSatellites.length,
      'visibleSystems': _visibleSystems.length,
      'satelliteDetails': _satelliteDetails.length,
      'lastHardwareCheck': _lastHardwareCheck?.toIso8601String(),
      'detectionMethod': _detectionMethod,
      'locationHistorySize': _locationHistory.length,
    };
  }

  /// Get all visible satellites
  List<dynamic> get allSatellites => List.unmodifiable(_allSatellites);

  /// Get satellite details
  List<dynamic> get satelliteDetails => List.unmodifiable(_satelliteDetails);

  /// Get visible GNSS systems
  List<dynamic> get visibleSystems => List.unmodifiable(_visibleSystems);

  /// Get system statistics
  Map<String, dynamic> get systemStats => Map.unmodifiable(_systemStats);

  /// Utility methods
  List<EnhancedPosition> get locationHistory => List.unmodifiable(_locationHistory);

  void clearHistory() {
    _locationHistory.clear();
    _recentAccuracies.clear();
    _rawPositions.clear();
    _highAccuracyReadings = 0;
    _bestAccuracy = double.infinity;
    print("🗑️ Location history cleared");
  }

  void dispose() {
    stopRealTimeMonitoring();
    NavicHardwareService.removePermissionResultCallback();
    _locationHistory.clear();
    _recentAccuracies.clear();
    _rawPositions.clear();
    print("🧹 Location service disposed");
  }

  // Getters for external access
  double get bestAccuracy => _bestAccuracy;
  bool get isNavicSupported => _isNavicSupported;
  bool get isNavicActive => _isNavicActive;
  String get chipsetType => _chipsetType;
  String get chipsetVendor => _chipsetVendor;
  String get chipsetModel => _chipsetModel;
  double get chipsetConfidence => _chipsetConfidence;
  double get confidenceLevel => _confidenceLevel;
  bool get hasL5Band => _hasL5Band;
  double get l5Confidence => _l5Confidence;
  String get positioningMethod => _positioningMethod;
  String get primarySystem => _primarySystem;
  bool get isRealTimeMonitoring => _isRealTimeMonitoring;
  Map<String, dynamic> get l5BandInfo => Map.unmodifiable(_l5BandInfo);
  int get navicSatelliteCount => _navicSatelliteCount;
  int get totalSatelliteCount => _totalSatelliteCount;
  int get navicUsedInFix => _navicUsedInFix;
}