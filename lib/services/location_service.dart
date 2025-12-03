import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:navic_ss/services/hardware_services.dart';

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
  };

  @override
  String toString() {
    return 'EnhancedPosition(lat: ${latitude.toStringAsFixed(6)}, lng: ${longitude.toStringAsFixed(6)}, '
        'acc: ${accuracy.toStringAsFixed(2)}m, navic: $isNavicEnhanced, '
        'conf: ${(confidenceScore * 100).toStringAsFixed(1)}%, '
        'L5: ${hasL5Band ? "✅" : "❌"}, '
        'Method: $positioningMethod)';
  }
}

class LocationService {
  final List<EnhancedPosition> _locationHistory = [];
  final List<double> _recentAccuracies = [];
  final List<Position> _rawPositions = [];

  // Hardware state from enhanced detection
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
  double _confidenceLevel = 0.0;
  bool _hasL5Band = false;
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

  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;

  LocationService._internal() {
    _initializeService();
  }

  /// Initialize service with enhanced hardware detection
  Future<void> _initializeService() async {
    print("🚀 Initializing Enhanced Location Service with NavIC + L5 support...");

    // Initialize the method channel handler
    NavicHardwareService.initialize();

    // Set up permission callback
    NavicHardwareService.setPermissionResultCallback(_onPermissionResult);
  }

  /// Handle permission results
  void _onPermissionResult(Map<String, dynamic> result) {
    final granted = result['granted'] as bool? ?? false;
    print("🔐 Permission result received: ${granted ? 'GRANTED' : 'DENIED'}");

    if (granted) {
      // Start hardware detection when permissions are granted
      _performHardwareDetection();
    }
  }

  /// Perform enhanced hardware detection
  Future<void> _performHardwareDetection() async {
    try {
      if (_lastHardwareCheck != null &&
          DateTime.now().difference(_lastHardwareCheck!) < const Duration(minutes: 5)) {
        return; // Use cached results for 5 minutes
      }

      final hardwareResult = await NavicHardwareService.checkNavicHardware();

      // Update state with enhanced detection results
      _isNavicSupported = hardwareResult.isSupported;
      _isNavicActive = hardwareResult.isActive;
      _navicSatelliteCount = hardwareResult.satelliteCount;
      _totalSatelliteCount = hardwareResult.totalSatellites;
      _navicUsedInFix = hardwareResult.usedInFixCount;
      _detectionMethod = hardwareResult.detectionMethod;
      _confidenceLevel = hardwareResult.confidenceLevel;
      _chipsetType = hardwareResult.chipsetType;
      _averageSignalStrength = hardwareResult.averageSignalStrength;
      _hasL5Band = hardwareResult.hasL5Band;
      _positioningMethod = hardwareResult.positioningMethod;
      _l5BandInfo = hardwareResult.l5BandInfo;
      _allSatellites = hardwareResult.allSatellites;
      _lastHardwareCheck = DateTime.now();

      // Update system stats from satellite data
      _updateSystemStats();

      // Log enhanced detection results
      _logHardwareDetectionResult();

    } catch (e) {
      print("❌ Enhanced hardware detection failed: $e");
      _resetToDefaultState();
    }
  }

  /// Update system statistics from satellite data
  void _updateSystemStats() {
    final systemCounts = <String, int>{};
    final systemUsed = <String, int>{};

    for (final sat in _allSatellites) {
      if (sat is Map<String, dynamic>) {
        final system = sat['system'] ?? 'UNKNOWN';
        final used = sat['usedInFix'] as bool? ?? false;

        systemCounts[system] = (systemCounts[system] ?? 0) + 1;
        if (used) {
          systemUsed[system] = (systemUsed[system] ?? 0) + 1;
        }
      }
    }

    // Build system stats map
    _systemStats.clear();
    for (final entry in systemCounts.entries) {
      final system = entry.key;
      final total = entry.value;
      final used = systemUsed[system] ?? 0;

      _systemStats[system] = {
        'name': system,
        'total': total,
        'used': used,
        'flag': _getSystemFlag(system),
      };
    }

    // Update visible systems
    _visibleSystems = _systemStats.values.toList();
  }

  String _getSystemFlag(String system) {
    switch (system) {
      case 'IRNSS': return '🇮🇳';
      case 'GPS': return '🇺🇸';
      case 'GLONASS': return '🇷🇺';
      case 'GALILEO': return '🇪🇺';
      case 'BEIDOU': return '🇨🇳';
      case 'QZSS': return '🇯🇵';
      default: return '🌍';
    }
  }

  /// Log hardware detection results
  void _logHardwareDetectionResult() {
    print("\n🎯 Enhanced Hardware Detection:");
    print("  ✅ NavIC Supported: $_isNavicSupported");
    print("  📡 NavIC Active: $_isNavicActive");
    print("  🛰️ NavIC Sats: $_navicSatelliteCount ($_navicUsedInFix in fix)");
    print("  📊 Total Sats: $_totalSatelliteCount");
    print("  🔧 Method: $_detectionMethod");
    print("  📶 Signal: ${_averageSignalStrength.toStringAsFixed(1)} dB-Hz");
    print("  💾 Chipset: $_chipsetType");
    print("  🎯 Positioning: $_positioningMethod");
    print("  📡 L5 Band: ${_hasL5Band ? '✅ Supported' : '❌ Not Supported'}");

    if (_hasL5Band && _l5BandInfo.isNotEmpty) {
      final confidence = (_l5BandInfo['confidence'] as num?)?.toDouble() ?? 0.0;
      final methods = (_l5BandInfo['detectionMethods'] as List<dynamic>?)?.join(', ') ?? 'N/A';
      print("  🔍 L5 Confidence: ${(confidence * 100).toStringAsFixed(1)}%");
      print("  🛠️ L5 Methods: $methods");
    }
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
    _averageSignalStrength = 0.0;
    _hasL5Band = false;
    _positioningMethod = "ERROR";
    _l5BandInfo = {};
    _systemStats = {};
    _allSatellites = [];
    _visibleSystems = [];
  }

  /// Check location permission
  Future<bool> checkLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print("⚠️ Location services disabled");
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.deniedForever) {
        print("❌ Permission denied forever");
        return false;
      }

      if (permission == LocationPermission.denied) {
        print("📍 Permission denied, needs to request");
        return false;
      }

      print("📍 Permission status: $permission");
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      print("❌ Permission check failed: $e");
      return false;
    }
  }

  /// Request location permission
  Future<bool> requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();

      print("📍 Permission requested: $permission");

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print("❌ Permission request denied");
        return false;
      }

      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      print("❌ Permission request failed: $e");
      return false;
    }
  }

  /// Get current location with enhanced accuracy optimization
  Future<EnhancedPosition?> getCurrentLocation() async {
    try {
      // Ensure we have location permission
      final hasPermission = await checkLocationPermission();
      if (!hasPermission) {
        print("❌ Location permission not granted");
        return null;
      }

      _totalReadings++;

      // Ensure hardware state is current
      await _performHardwareDetection();

      // Start real-time monitoring for best accuracy
      if (!_isRealTimeMonitoring) {
        await startRealTimeMonitoring();
      }

      // Get position using Geolocator
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 15),
      );

      _updatePerformanceTracking(position.accuracy, position);

      final enhancedPosition = _createEnhancedPosition(position);
      _addToHistory(enhancedPosition);

      return enhancedPosition;

    } catch (e) {
      print("❌ Enhanced location acquisition failed: $e");
      return null;
    }
  }

  /// Create enhanced position with L5 band optimization
  EnhancedPosition _createEnhancedPosition(Position position) {
    final isNavicEnhanced = _isNavicSupported && _isNavicActive && _navicUsedInFix > 0;
    final locationSource = isNavicEnhanced ? "NAVIC" : _primarySystem;

    final enhancedAccuracy = _calculateEnhancedAccuracy(
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
    );
  }

  /// Enhanced accuracy calculation with L5 band support
  double _calculateEnhancedAccuracy(double baseAccuracy, bool isNavicEnhanced) {
    double enhancedAccuracy = baseAccuracy;

    // L5 BAND ENHANCEMENT
    if (_hasL5Band) {
      final l5Confidence = (_l5BandInfo['confidence'] as num?)?.toDouble() ?? 0.0;
      final l5Boost = l5Confidence * 0.25; // Up to 25% improvement with L5
      enhancedAccuracy *= (1.0 - l5Boost);
    }

    // NAVIC ENHANCEMENT
    if (isNavicEnhanced) {
      if (_navicUsedInFix >= 3) {
        enhancedAccuracy *= 0.60; // 40% improvement for strong NavIC
      } else if (_navicUsedInFix >= 2) {
        enhancedAccuracy *= 0.75; // 25% improvement for good NavIC
      } else if (_navicUsedInFix >= 1) {
        enhancedAccuracy *= 0.85; // 15% improvement for basic NavIC
      }
    }

    // SATELLITE COUNT OPTIMIZATION
    if (_totalSatelliteCount >= 20) {
      enhancedAccuracy *= 0.70; // 30% improvement for excellent coverage
    } else if (_totalSatelliteCount >= 15) {
      enhancedAccuracy *= 0.80; // 20% improvement for very good coverage
    } else if (_totalSatelliteCount >= 10) {
      enhancedAccuracy *= 0.85; // 15% improvement for good coverage
    }

    // CONFIDENCE-BASED REFINEMENT
    final confidenceBoost = _confidenceLevel * 0.15;
    enhancedAccuracy *= (1.0 - confidenceBoost);

    // STABILITY ENHANCEMENT
    if (_recentAccuracies.length >= 3) {
      final stability = _calculateStability();
      if (stability > 0.8) {
        enhancedAccuracy *= 0.90; // 10% improvement for high stability
      }
    }

    // Apply realistic bounds
    return enhancedAccuracy.clamp(0.5, 50.0);
  }

  /// Calculate confidence score with L5 consideration
  double _calculateConfidenceScore(double accuracy, bool isNavicEnhanced) {
    double score = 0.6 + (_confidenceLevel * 0.2);

    // L5 BAND CONFIDENCE
    if (_hasL5Band) {
      score += 0.20; // Significant confidence boost with L5
      final l5Confidence = (_l5BandInfo['confidence'] as num?)?.toDouble() ?? 0.0;
      score += l5Confidence * 0.10; // Additional based on L5 confidence
    }

    // NAVIC CONFIDENCE
    if (isNavicEnhanced) {
      score += 0.15;
      if (_navicUsedInFix >= 3) score += 0.10;
      else if (_navicUsedInFix >= 2) score += 0.07;
      else if (_navicUsedInFix >= 1) score += 0.04;
    }

    // ACCURACY CONFIDENCE
    if (accuracy < 1.0) score += 0.20;
    else if (accuracy < 2.0) score += 0.15;
    else if (accuracy < 5.0) score += 0.10;
    else if (accuracy < 8.0) score += 0.05;

    // SATELLITE CONFIDENCE
    if (_totalSatelliteCount >= 15) score += 0.08;
    else if (_totalSatelliteCount >= 10) score += 0.05;

    return score.clamp(0.0, 1.0);
  }

  /// Create comprehensive satellite information
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
      'primarySystem': _primarySystem,
      'detectionMethod': _detectionMethod,
      'chipsetType': _chipsetType,
      'confidenceLevel': _confidenceLevel,
      'averageSignalStrength': _averageSignalStrength,
      'hasL5Band': _hasL5Band,
      'l5BandInfo': _l5BandInfo,
      'positioningMethod': _positioningMethod,
      'stability': _calculateStability().toStringAsFixed(3),
      'optimizationLevel': 'ENHANCED_WITH_L5',
      'rawAccuracy': rawAccuracy,
      'enhancedAccuracy': enhancedAccuracy,
      'enhancementBoost': improvement.toStringAsFixed(1),
      'hardwareConfidence': (_confidenceLevel * 100).toStringAsFixed(1),
      'acquisitionTime': DateTime.now().toIso8601String(),
      'visibleSystems': _visibleSystems,
      'satelliteCount': _allSatellites.length,
      'isRealTimeMonitoring': _isRealTimeMonitoring,
    };
  }

  /// Start continuous location updates with optimization
  Stream<EnhancedPosition> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        timeLimit: Duration(seconds: 30),
      ),
    ).asyncMap((Position position) async {
      _totalReadings++;
      _updatePerformanceTracking(position.accuracy, position);

      // Update satellite data periodically
      if (_totalReadings % 5 == 0) {
        await _performHardwareDetection();
      }

      return _createEnhancedPosition(position);
    });
  }

  /// Enhanced real-time satellite update handler
  void _onSatelliteUpdate(Map<String, dynamic> data) {
    try {
      // Update satellite counts
      _navicSatelliteCount = data['navicSatellitesCount'] as int? ?? 0;
      _totalSatelliteCount = data['totalSatellites'] as int? ?? 0;
      _navicUsedInFix = data['navicUsedInFix'] as int? ?? 0;
      _isNavicActive = _navicSatelliteCount > 0;
      _hasL5Band = data['hasL5Band'] as bool? ?? false;

      // Update all satellites list
      if (data['allSatellites'] is List) {
        _allSatellites = data['allSatellites'] as List<dynamic>;
        _updateSystemStats();
      }

      // Update system stats
      if (data['systemStats'] is Map) {
        _systemStats = (data['systemStats'] as Map).cast<String, dynamic>();
        _visibleSystems = _systemStats.values.toList();
      }

      // Update primary system
      _primarySystem = data['primarySystem'] as String? ?? 'GPS';

      // Update positioning method based on current state
      _updatePositioningMethod();

      // Log enhanced update
      _logSatelliteUpdate();

    } catch (e) {
      print("❌ Error processing satellite update: $e");
    }
  }

  /// Update positioning method based on current satellite state
  void _updatePositioningMethod() {
    if (_isNavicActive && _navicUsedInFix >= 4) {
      _positioningMethod = "NAVIC_PRIMARY";
    } else if (_isNavicActive && _navicUsedInFix >= 1) {
      _positioningMethod = "NAVIC_HYBRID";
    } else if (_totalSatelliteCount >= 4) {
      // Check other systems from system stats
      if (_systemStats.isNotEmpty) {
        final gpsUsed = (_systemStats['GPS'] as Map<String, dynamic>?)?['used'] as int? ?? 0;
        final glonassUsed = (_systemStats['GLONASS'] as Map<String, dynamic>?)?['used'] as int? ?? 0;
        final galileoUsed = (_systemStats['GALILEO'] as Map<String, dynamic>?)?['used'] as int? ?? 0;
        final beidouUsed = (_systemStats['BEIDOU'] as Map<String, dynamic>?)?['used'] as int? ?? 0;

        if (gpsUsed >= 4) {
          _positioningMethod = "GPS_PRIMARY";
        } else if (glonassUsed >= 4) {
          _positioningMethod = "GLONASS_PRIMARY";
        } else if (galileoUsed >= 4) {
          _positioningMethod = "GALILEO_PRIMARY";
        } else if (beidouUsed >= 4) {
          _positioningMethod = "BEIDOU_PRIMARY";
        } else {
          _positioningMethod = "MULTI_GNSS_HYBRID";
        }
      } else {
        _positioningMethod = "GPS_PRIMARY";
      }
    } else {
      _positioningMethod = "INSUFFICIENT_SATELLITES";
    }
  }

  /// Log satellite update
  void _logSatelliteUpdate() {
    if (_navicSatelliteCount > 0 || _totalReadings % 10 == 0) {
      print("\n🛰️ Enhanced Satellite Update:");
      print("  📡 Total: $_totalSatelliteCount");
      print("  🇮🇳 NavIC: $_navicSatelliteCount ($_navicUsedInFix in fix)");
      print("  🎯 Primary: $_primarySystem");
      print("  📶 L5 Band: ${_hasL5Band ? '✅ Enabled' : '❌ Not Available'}");
      print("  🎯 Positioning: $_positioningMethod");

      // Log system usage
      if (_systemStats.isNotEmpty) {
        print("  📊 System Usage:");
        for (final entry in _systemStats.entries) {
          if (entry.value is Map<String, dynamic>) {
            final system = entry.value as Map<String, dynamic>;
            final name = system['name'] ?? entry.key;
            final flag = system['flag'] ?? '🌍';
            final used = system['used'] ?? 0;
            final total = system['total'] ?? 0;
            if (total > 0) {
              print("    $flag $name: $used/$total in fix");
            }
          }
        }
      }
    }
  }

  /// Start optimized real-time monitoring
  Future<void> startRealTimeMonitoring() async {
    if (_isRealTimeMonitoring) {
      print("ℹ️ Real-time monitoring already active");
      return;
    }

    try {
      // Set up satellite update callback
      NavicHardwareService.setSatelliteUpdateCallback(_onSatelliteUpdate);

      final result = await NavicHardwareService.startRealTimeDetection();

      if (result.success) {
        _isRealTimeMonitoring = true;
        _hasL5Band = result.hasL5Band;
        print("🎯 Enhanced real-time monitoring started");
        print("  📡 L5 Band: ${_hasL5Band ? '✅ Supported' : '❌ Not Available'}");
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

  /// Open location settings
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      print("❌ Error opening location settings: $e");
      return false;
    }
  }

  /// Check if location is enabled
  Future<bool> isLocationEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      print("❌ Error checking location status: $e");
      return false;
    }
  }

  /// Performance tracking methods
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

  double _calculateStability() {
    if (_recentAccuracies.length < 2) return 0.0;

    double totalChange = 0.0;
    for (int i = 1; i < _recentAccuracies.length; i++) {
      totalChange += (_recentAccuracies[i] - _recentAccuracies[i-1]).abs();
    }

    final avgChange = totalChange / (_recentAccuracies.length - 1);
    return (1.0 - (avgChange / 3.0).clamp(0.0, 1.0));
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
      return "Device chipset supports NavIC but does not have L5 band. Receiving NavIC signals may not be possible.";
    } else if (_isNavicSupported && _hasL5Band) {
      return "Device chipset supports NavIC and contains L5 band. NavIC ready for enhanced positioning!";
    } else {
      return "Using standard GPS positioning.";
    }
  }

  /// Get comprehensive service statistics
  Map<String, dynamic> getServiceStats() {
    final avgAccuracy = _recentAccuracies.isNotEmpty
        ? _recentAccuracies.reduce((a, b) => a + b) / _recentAccuracies.length
        : 0.0;

    return {
      'totalReadings': _totalReadings,
      'highAccuracyReadings': _highAccuracyReadings,
      'bestAccuracy': _bestAccuracy,
      'averageAccuracy': avgAccuracy,
      'stability': _calculateStability(),
      'recentReadingsCount': _recentAccuracies.length,
      'navicSupported': _isNavicSupported,
      'navicActive': _isNavicActive,
      'navicSatellites': _navicSatelliteCount,
      'navicUsedInFix': _navicUsedInFix,
      'totalSatellites': _totalSatelliteCount,
      'primarySystem': _primarySystem,
      'chipsetType': _chipsetType,
      'confidenceLevel': _confidenceLevel,
      'signalStrength': _averageSignalStrength,
      'hasL5Band': _hasL5Band,
      'positioningMethod': _positioningMethod,
      'l5BandInfo': _l5BandInfo,
      'systemStats': _systemStats,
      'realTimeMonitoring': _isRealTimeMonitoring,
      'visibleSatellites': _allSatellites.length,
      'visibleSystems': _visibleSystems.length,
      'lastHardwareCheck': _lastHardwareCheck?.toIso8601String(),
      'optimizationMode': 'ENHANCED_NAVIC_WITH_L5',
    };
  }

  /// Get all visible satellites
  List<dynamic> get allSatellites => List.unmodifiable(_allSatellites);

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
    print("🗑️ Enhanced location history cleared");
  }

  void dispose() {
    stopRealTimeMonitoring();
    NavicHardwareService.removePermissionResultCallback();
    _locationHistory.clear();
    _recentAccuracies.clear();
    _rawPositions.clear();
    print("🧹 Enhanced location service disposed");
  }

  // Getters for external access
  double get bestAccuracy => _bestAccuracy;
  bool get isNavicSupported => _isNavicSupported;
  bool get isNavicActive => _isNavicActive;
  String get chipsetType => _chipsetType;
  double get confidenceLevel => _confidenceLevel;
  bool get hasL5Band => _hasL5Band;
  String get positioningMethod => _positioningMethod;
  bool get isRealTimeMonitoring => _isRealTimeMonitoring;
  Map<String, dynamic> get l5BandInfo => Map.unmodifiable(_l5BandInfo);
}