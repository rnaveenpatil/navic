// lib/services/hardware_services.dart
import 'dart:async';
import 'package:flutter/services.dart';

class NavicDetectionResult {
  final bool isSupported;
  final bool isActive;
  final int satelliteCount;
  final int totalSatellites;
  final int usedInFixCount;
  final String detectionMethod;
  final double confidenceLevel;
  final double averageSignalStrength;
  final String chipsetType;
  final String chipsetVendor;
  final String chipsetModel;
  final bool hasL5Band;
  final String positioningMethod;
  final String primarySystem;
  final Map<String, dynamic> l5BandInfo;
  final List<dynamic> allSatellites;

  const NavicDetectionResult({
    required this.isSupported,
    required this.isActive,
    required this.satelliteCount,
    required this.totalSatellites,
    required this.usedInFixCount,
    required this.detectionMethod,
    required this.confidenceLevel,
    required this.averageSignalStrength,
    required this.chipsetType,
    required this.chipsetVendor,
    required this.chipsetModel,
    required this.hasL5Band,
    required this.positioningMethod,
    required this.primarySystem,
    required this.l5BandInfo,
    required this.allSatellites,
  });

  factory NavicDetectionResult.fromMap(Map<String, dynamic> map) {
    return NavicDetectionResult(
      isSupported: map['isSupported'] as bool? ?? false,
      isActive: map['isActive'] as bool? ?? false,
      satelliteCount: map['satelliteCount'] as int? ?? 0,
      totalSatellites: map['totalSatellites'] as int? ?? 0,
      usedInFixCount: map['usedInFixCount'] as int? ?? 0,
      detectionMethod: map['detectionMethod'] as String? ?? 'UNKNOWN',
      confidenceLevel: (map['confidenceLevel'] as num?)?.toDouble() ?? 0.0,
      averageSignalStrength: (map['averageSignalStrength'] as num?)?.toDouble() ?? 0.0,
      chipsetType: map['chipsetType'] as String? ?? 'UNKNOWN',
      chipsetVendor: map['chipsetVendor'] as String? ?? 'UNKNOWN',
      chipsetModel: map['chipsetModel'] as String? ?? 'UNKNOWN',
      hasL5Band: map['hasL5Band'] as bool? ?? false,
      positioningMethod: map['positioningMethod'] as String? ?? 'GPS',
      primarySystem: map['primarySystem'] as String? ?? 'GPS',
      l5BandInfo: (map['l5BandInfo'] as Map<String, dynamic>?) ?? {},
      allSatellites: (map['allSatellites'] as List<dynamic>?) ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isSupported': isSupported,
      'isActive': isActive,
      'satelliteCount': satelliteCount,
      'totalSatellites': totalSatellites,
      'usedInFixCount': usedInFixCount,
      'detectionMethod': detectionMethod,
      'confidenceLevel': confidenceLevel,
      'averageSignalStrength': averageSignalStrength,
      'chipsetType': chipsetType,
      'chipsetVendor': chipsetVendor,
      'chipsetModel': chipsetModel,
      'hasL5Band': hasL5Band,
      'positioningMethod': positioningMethod,
      'primarySystem': primarySystem,
      'l5BandInfo': l5BandInfo,
      'allSatellites': allSatellites,
    };
  }

  @override
  String toString() {
    return 'NavicDetectionResult('
        'isSupported: $isSupported, '
        'isActive: $isActive, '
        'satellites: $satelliteCount/$totalSatellites ($usedInFixCount used), '
        'method: $detectionMethod, '
        'confidence: ${(confidenceLevel * 100).toStringAsFixed(1)}%, '
        'chipset: $chipsetVendor $chipsetModel, '
        'L5: $hasL5Band, '
        'primary: $primarySystem)';
  }
}

class RealTimeDetectionResult {
  final bool success;
  final bool hasL5Band;
  final String? chipset;
  final String? message;

  const RealTimeDetectionResult({
    required this.success,
    required this.hasL5Band,
    this.chipset,
    this.message,
  });
}

class PermissionResult {
  final bool granted;
  final String message;
  final Map<String, bool>? permissions;

  const PermissionResult({
    required this.granted,
    required this.message,
    this.permissions,
  });
}

class NavicHardwareService {
  static const MethodChannel _channel = MethodChannel('navic_support');
  
  static Function(Map<String, dynamic>)? _permissionResultCallback;
  static Function(Map<String, dynamic>)? _satelliteUpdateCallback;
  static Function(Map<String, dynamic>)? _locationUpdateCallback;

  static void initialize() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onPermissionResult':
        final result = call.arguments as Map<String, dynamic>;
        _permissionResultCallback?.call(result);
        break;
      case 'onSatelliteUpdate':
        final data = call.arguments as Map<String, dynamic>;
        _satelliteUpdateCallback?.call(data);
        break;
      case 'onLocationUpdate':
        final data = call.arguments as Map<String, dynamic>;
        _locationUpdateCallback?.call(data);
        break;
      default:
        print('Unknown method call: ${call.method}');
    }
    return null;
  }

  static Future<NavicDetectionResult> checkNavicHardware() async {
    try {
      final result = await _channel.invokeMethod('checkNavicHardware');
      return NavicDetectionResult.fromMap(Map<String, dynamic>.from(result as Map));
    } on PlatformException catch (e) {
      print('Error checking NavIC hardware: ${e.message}');
      return NavicDetectionResult(
        isSupported: false,
        isActive: false,
        satelliteCount: 0,
        totalSatellites: 0,
        usedInFixCount: 0,
        detectionMethod: 'ERROR',
        confidenceLevel: 0.0,
        averageSignalStrength: 0.0,
        chipsetType: 'ERROR',
        chipsetVendor: 'ERROR',
        chipsetModel: 'ERROR',
        hasL5Band: false,
        positioningMethod: 'ERROR',
        primarySystem: 'GPS',
        l5BandInfo: {},
        allSatellites: [],
      );
    }
  }

  static Future<Map<String, dynamic>> getGnssCapabilities() async {
    try {
      final result = await _channel.invokeMethod('getGnssCapabilities');
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      print('Error getting GNSS capabilities: ${e.message}');
      return {};
    }
  }

  static Future<RealTimeDetectionResult> startRealTimeDetection() async {
    try {
      final result = await _channel.invokeMethod('startRealTimeDetection');
      final Map<String, dynamic> data = Map<String, dynamic>.from(result as Map);
      return RealTimeDetectionResult(
        success: data['success'] as bool? ?? false,
        hasL5Band: data['hasL5Band'] as bool? ?? false,
        chipset: data['chipset'] as String?,
        message: data['message'] as String?,
      );
    } on PlatformException catch (e) {
      print('Error starting real-time detection: ${e.message}');
      return RealTimeDetectionResult(
        success: false,
        hasL5Band: false,
        message: e.message,
      );
    }
  }

  static Future<RealTimeDetectionResult> stopRealTimeDetection() async {
    try {
      final result = await _channel.invokeMethod('stopRealTimeDetection');
      final Map<String, dynamic> data = Map<String, dynamic>.from(result as Map);
      return RealTimeDetectionResult(
        success: data['success'] as bool? ?? false,
        hasL5Band: false,
        message: data['message'] as String?,
      );
    } on PlatformException catch (e) {
      print('Error stopping real-time detection: ${e.message}');
      return RealTimeDetectionResult(
        success: false,
        hasL5Band: false,
        message: e.message,
      );
    }
  }

  static Future<PermissionResult> checkLocationPermissions() async {
    try {
      final result = await _channel.invokeMethod('checkLocationPermissions');
      final Map<String, dynamic> data = Map<String, dynamic>.from(result as Map);
      return PermissionResult(
        granted: data['allPermissionsGranted'] as bool? ?? false,
        message: 'Permissions checked',
        permissions: data.cast<String, bool>(),
      );
    } on PlatformException catch (e) {
      print('Error checking permissions: ${e.message}');
      return PermissionResult(
        granted: false,
        message: e.message ?? 'Permission check failed',
      );
    }
  }

  static Future<PermissionResult> requestLocationPermissions() async {
    try {
      final result = await _channel.invokeMethod('requestLocationPermissions');
      final Map<String, dynamic> data = Map<String, dynamic>.from(result as Map);
      return PermissionResult(
        granted: true,
        message: data['message'] as String? ?? 'Permissions requested',
      );
    } on PlatformException catch (e) {
      print('Error requesting permissions: ${e.message}');
      return PermissionResult(
        granted: false,
        message: e.message ?? 'Permission request failed',
      );
    }
  }

  static Future<Map<String, dynamic>> getAllSatellites() async {
    try {
      final result = await _channel.invokeMethod('getAllSatellites');
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      print('Error getting satellites: ${e.message}');
      return {};
    }
  }

  static Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      final result = await _channel.invokeMethod('getDeviceInfo');
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      print('Error getting device info: ${e.message}');
      return {};
    }
  }

  static void setPermissionResultCallback(Function(Map<String, dynamic>) callback) {
    _permissionResultCallback = callback;
  }

  static void removePermissionResultCallback() {
    _permissionResultCallback = null;
  }

  static void setSatelliteUpdateCallback(Function(Map<String, dynamic>) callback) {
    _satelliteUpdateCallback = callback;
  }

  static void removeSatelliteUpdateCallback() {
    _satelliteUpdateCallback = null;
  }

  static void setLocationUpdateCallback(Function(Map<String, dynamic>) callback) {
    _locationUpdateCallback = callback;
  }

  static void removeLocationUpdateCallback() {
    _locationUpdateCallback = null;
  }

  static Future<bool> startLocationUpdates() async {
    try {
      final result = await _channel.invokeMethod('startLocationUpdates');
      final Map<String, dynamic> data = Map<String, dynamic>.from(result as Map);
      return data['success'] as bool? ?? false;
    } on PlatformException catch (e) {
      print('Error starting location updates: ${e.message}');
      return false;
    }
  }

  static Future<bool> stopLocationUpdates() async {
    try {
      final result = await _channel.invokeMethod('stopLocationUpdates');
      final Map<String, dynamic> data = Map<String, dynamic>.from(result as Map);
      return data['success'] as bool? ?? false;
    } on PlatformException catch (e) {
      print('Error stopping location updates: ${e.message}');
      return false;
    }
  }

  static Future<bool> openLocationSettings() async {
    try {
      final result = await _channel.invokeMethod('openLocationSettings');
      final Map<String, dynamic> data = Map<String, dynamic>.from(result as Map);
      return data['success'] as bool? ?? false;
    } on PlatformException catch (e) {
      print('Error opening location settings: ${e.message}');
      return false;
    }
  }

  static Future<Map<String, dynamic>> isLocationEnabled() async {
    try {
      final result = await _channel.invokeMethod('isLocationEnabled');
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      print('Error checking location status: ${e.message}');
      return {};
    }
  }
}