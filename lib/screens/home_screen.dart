import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:navic_ss/services/location_service.dart';
import 'package:navic_ss/screens/emergency.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final EnhancedLocationService _locationService = EnhancedLocationService();
  final MapController _mapController = MapController();
  final ScrollController _scrollController = ScrollController();

  EnhancedPosition? _currentPosition;
  String _locationQuality = "Acquiring Location...";
  String _locationSource = "GPS";
  bool _isLoading = true;
  bool _isHardwareChecked = false;
  bool _isNavicSupported = false;
  bool _isNavicActive = false;
  bool _hasL5Band = false;
  double _l5Confidence = 0.0;
  String _hardwareMessage = "Checking hardware...";
  String _hardwareStatus = "Checking...";
  bool _showLayerSelection = false;
  bool _showSatelliteList = false;
  bool _locationAcquired = false;
  LatLng? _lastValidMapCenter;
  String _chipsetType = "Unknown";
  String _chipsetVendor = "Unknown";
  String _chipsetModel = "Unknown";
  double _chipsetConfidence = 0.0;
  double _confidenceLevel = 0.0;
  double _signalStrength = 0.0;
  int _navicSatelliteCount = 0;
  int _totalSatelliteCount = 0;
  int _navicUsedInFix = 0;
  String _positioningMethod = "GPS";
  String _primarySystem = "GPS";
  Map<String, dynamic> _l5BandInfo = {};
  List<dynamic> _allSatellites = [];
  List<dynamic> _visibleSystems = [];
  List<dynamic> _satelliteDetails = [];
  Map<String, dynamic> _systemStats = {};
  
  List<Map<String, dynamic>> _visibleSatellites = [];
  Map<String, dynamic> _satelliteSystemStats = {};

  Map<String, bool> _selectedLayers = {
    'OpenStreetMap Standard': true,
    'ESRI Satellite View': false,
  };

  final Map<String, TileLayer> _tileLayers = {
    'OpenStreetMap Standard': TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.example.navic',
    ),
    'ESRI Satellite View': TileLayer(
      urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      userAgentPackageName: 'com.example.navic',
    ),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    try {
      await _locationService.initializeService();
      
      final hasPermission = await _checkAndRequestPermission();
      
      if (hasPermission) {
        await _checkNavicHardwareSupport();
        await _acquireCurrentLocation();
        await _startRealTimeMonitoring();
      } else {
        print("⚠️ No location permission granted");
        _showPermissionDeniedDialog();
      }
    } catch (e) {
      print("Initialization error: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _checkAndRequestPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print("⚠️ Location services disabled");
        
        bool? shouldEnable = await _showEnableLocationDialog();
        if (shouldEnable ?? false) {
          await Geolocator.openLocationSettings();
        }
        return false;
      }

      PermissionStatus permissionStatus = await Permission.location.status;

      if (permissionStatus.isDenied) {
        permissionStatus = await Permission.location.request();
        
        if (permissionStatus.isDenied) {
          print("❌ Location permission denied");
          return false;
        }
      }

      if (permissionStatus.isPermanentlyDenied) {
        print("❌ Location permission permanently denied");
        await _showOpenSettingsDialog();
        return false;
      }

      if (await Permission.locationAlways.isDenied) {
        final backgroundStatus = await Permission.locationAlways.request();
        if (backgroundStatus.isDenied) {
          print("⚠️ Background location permission not granted");
        }
      }

      print("📍 Permission status: $permissionStatus");
      return permissionStatus.isGranted || permissionStatus.isLimited;
    } catch (e) {
      print("Permission error: $e");
      return false;
    }
  }

  Future<bool?> _showEnableLocationDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Services Disabled'),
          content: const Text(
            'Location services are required for this app to work properly. '
            'Please enable location services in your device settings.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Enable'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showOpenSettingsDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Required'),
          content: const Text(
            'Location permission is required for this app to work. '
            'Please enable it in the app settings.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Open Settings'),
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showPermissionDeniedDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Permission Required'),
            content: const Text(
              'Location permission is required to use this app. '
              'Please grant location permission in settings.',
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('Open Settings'),
                onPressed: () {
                  openAppSettings();
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    });
  }

  Future<void> _checkNavicHardwareSupport() async {
    try {
      final serviceStats = _locationService.getServiceStats();

      setState(() {
        _isNavicSupported = serviceStats['navicSupported'] as bool? ?? false;
        _isNavicActive = serviceStats['navicActive'] as bool? ?? false;
        _hasL5Band = serviceStats['hasL5Band'] as bool? ?? false;
        _l5Confidence = (serviceStats['l5Confidence'] as num?)?.toDouble() ?? 0.0;
        _chipsetType = serviceStats['chipsetType'] as String? ?? "Unknown";
        _chipsetVendor = serviceStats['chipsetVendor'] as String? ?? "Unknown";
        _chipsetModel = serviceStats['chipsetModel'] as String? ?? "Unknown";
        _chipsetConfidence = (serviceStats['chipsetConfidence'] as num?)?.toDouble() ?? 0.0;
        _confidenceLevel = (serviceStats['confidenceLevel'] as num?)?.toDouble() ?? 0.0;
        _signalStrength = (serviceStats['signalStrength'] as num?)?.toDouble() ?? 0.0;
        _navicSatelliteCount = serviceStats['navicSatellites'] as int? ?? 0;
        _totalSatelliteCount = serviceStats['totalSatellites'] as int? ?? 0;
        _navicUsedInFix = serviceStats['navicUsedInFix'] as int? ?? 0;
        _positioningMethod = serviceStats['positioningMethod'] as String? ?? "GPS";
        _primarySystem = serviceStats['primarySystem'] as String? ?? "GPS";
        _l5BandInfo = serviceStats['l5BandInfo'] as Map<String, dynamic>? ?? {};
        _visibleSystems = (serviceStats['visibleSystems'] as List<dynamic>?) ?? [];
        _satelliteDetails = _locationService.satelliteDetails;
        _systemStats = _locationService.systemStats;
        _allSatellites = _locationService.allSatellites;

        _updateHardwareMessage();
        _isHardwareChecked = true;
        
        _processSatelliteData();
      });

    } catch (e) {
      _setHardwareErrorState();
    }
  }

  void _processSatelliteData() {
    final List<Map<String, dynamic>> satellites = [];
    
    for (final sat in _satelliteDetails) {
      if (sat is Map<String, dynamic>) {
        final system = sat['system'] as String? ?? 'UNKNOWN';
        final svid = sat['svid'] as int? ?? 0;
        final cn0 = (sat['cn0DbHz'] as num?)?.toDouble() ?? 0.0;
        final used = sat['usedInFix'] as bool? ?? false;
        final elevation = (sat['elevation'] as num?)?.toDouble() ?? 0.0;
        final azimuth = (sat['azimuth'] as num?)?.toDouble() ?? 0.0;
        final hasEphemeris = sat['hasEphemeris'] as bool? ?? false;
        final hasAlmanac = sat['hasAlmanac'] as bool? ?? false;
        final carrierFrequency = (sat['carrierFrequencyHz'] as num?)?.toDouble();
        final signalStrength = sat['signalStrength'] as String? ?? 'UNKNOWN';
        
        satellites.add({
          'system': system,
          'svid': svid,
          'cn0DbHz': cn0,
          'usedInFix': used,
          'elevation': elevation,
          'azimuth': azimuth,
          'hasEphemeris': hasEphemeris,
          'hasAlmanac': hasAlmanac,
          'carrierFrequencyHz': carrierFrequency,
          'signalStrength': signalStrength,
        });
      }
    }
    
    setState(() {
      _visibleSatellites = satellites;
      _satelliteSystemStats = _systemStats;
    });
  }

  Future<void> _updateSatelliteData() async {
    try {
      final serviceStats = _locationService.getServiceStats();
      final satellites = _locationService.satelliteDetails;
      final systems = _locationService.visibleSystems;
      final systemStats = _locationService.systemStats;

      setState(() {
        _allSatellites = _locationService.allSatellites;
        _satelliteDetails = satellites;
        _visibleSystems = systems;
        _systemStats = systemStats;
        _navicSatelliteCount = serviceStats['navicSatellites'] as int? ?? 0;
        _totalSatelliteCount = serviceStats['totalSatellites'] as int? ?? 0;
        _navicUsedInFix = serviceStats['navicUsedInFix'] as int? ?? 0;
        _hasL5Band = serviceStats['hasL5Band'] as bool? ?? false;
        _l5Confidence = (serviceStats['l5Confidence'] as num?)?.toDouble() ?? 0.0;
        _positioningMethod = serviceStats['positioningMethod'] as String? ?? "GPS";
        _primarySystem = serviceStats['primarySystem'] as String? ?? "GPS";
        
        _processSatelliteData();
      });
    } catch (e) {
      print("Error updating satellite data: $e");
    }
  }

  void _updateHardwareMessage() {
    if (!_isNavicSupported && !_hasL5Band) {
      _hardwareMessage = "Chipset does not support NavIC and no L5 band";
      _hardwareStatus = "Limited Hardware";
    } else if (_isNavicSupported && !_hasL5Band) {
      _hardwareMessage = "Device supports NavIC but no L5 band";
      _hardwareStatus = "NavIC Ready";
    } else if (_isNavicSupported && _hasL5Band) {
      _hardwareMessage = "Device supports NavIC with L5 band";
      _hardwareStatus = "NavIC with L5";
    } else if (_hasL5Band) {
      _hardwareMessage = "Device has L5 band support";
      _hardwareStatus = "GPS with L5";
    } else {
      _hardwareMessage = "Using standard GPS";
      _hardwareStatus = "GPS Only";
    }

    _updateLocationSource();
  }

  void _setHardwareErrorState() {
    setState(() {
      _isHardwareChecked = true;
      _isNavicSupported = false;
      _isNavicActive = false;
      _hasL5Band = false;
      _l5Confidence = 0.0;
      _hardwareMessage = "Hardware detection failed";
      _hardwareStatus = "Error";
      _locationSource = "GPS";
      _chipsetType = "Unknown";
      _chipsetVendor = "Unknown";
      _chipsetModel = "Unknown";
      _chipsetConfidence = 0.0;
      _confidenceLevel = 0.0;
      _signalStrength = 0.0;
      _navicSatelliteCount = 0;
      _totalSatelliteCount = 0;
      _navicUsedInFix = 0;
      _positioningMethod = "GPS";
      _primarySystem = "GPS";
      _l5BandInfo = {};
      _allSatellites = [];
      _visibleSystems = [];
      _satelliteDetails = [];
      _systemStats = {};
      _visibleSatellites = [];
      _satelliteSystemStats = {};
    });
  }

  Future<void> _acquireCurrentLocation() async {
    try {
      print("🔍 Attempting to acquire current location...");
      final position = await _locationService.getCurrentLocation();
      
      if (position != null && _isValidCoordinate(position.latitude, position.longitude)) {
        print("✅ Location acquired successfully");
        _updateLocationState(position);
        _centerMapOnPosition(position);
        _logLocationDetails(position);
      } else {
        print("❌ Location service returned null or invalid coordinates");
        
        // Try fallback method
        await _tryFallbackLocationAcquisition();
      }
    } catch (e) {
      print("❌ Error acquiring location: $e");
      
      // Show error to user
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to get location: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _tryFallbackLocationAcquisition() async {
    try {
      print("🔄 Trying fallback location acquisition...");
      
      // Check permission again
      final hasPermission = await _checkAndRequestPermission();
      if (!hasPermission) {
        print("❌ No location permission for fallback");
        return;
      }
      
      // Try with lower accuracy if high accuracy fails
      print("📍 Trying with lower accuracy...");
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      if (_isValidCoordinate(position.latitude, position.longitude)) {
        print("✅ Fallback location acquired");
        final enhancedPosition = EnhancedPosition(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          altitude: position.altitude,
          speed: position.speed,
          heading: position.heading,
          timestamp: position.timestamp,
          isNavicEnhanced: false,
          confidenceScore: 0.7,
          locationSource: "GPS",
          detectionReason: "Fallback GPS positioning",
          navicSatellites: 0,
          totalSatellites: 0,
          navicUsedInFix: 0,
          hasL5Band: false,
          positioningMethod: "GPS_FALLBACK",
          primarySystem: "GPS",
          chipsetType: "Unknown",
          chipsetVendor: "Unknown",
          chipsetModel: "Unknown",
          chipsetConfidence: 0.0,
          l5Confidence: 0.0,
        );
        
        _updateLocationState(enhancedPosition);
        _centerMapOnPosition(enhancedPosition);
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Using fallback GPS positioning"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print("❌ Fallback location acquisition also failed: $e");
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Location unavailable: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _updateLocationState(EnhancedPosition position) {
    setState(() {
      _currentPosition = position;
      _updateLocationSource();
      _updateLocationQuality(position);
      _locationAcquired = true;
      _lastValidMapCenter = LatLng(position.latitude, position.longitude);

      if (position.satelliteInfo.isNotEmpty) {
        _navicSatelliteCount = position.navicSatellites ?? 0;
        _totalSatelliteCount = position.totalSatellites ?? 0;
        _navicUsedInFix = position.navicUsedInFix ?? 0;
        _hasL5Band = position.hasL5Band;
        _l5Confidence = position.l5Confidence;
        _positioningMethod = position.positioningMethod;
        _primarySystem = position.primarySystem;
        _chipsetType = position.chipsetType;
        _chipsetVendor = position.chipsetVendor;
        _chipsetModel = position.chipsetModel;
        _chipsetConfidence = position.chipsetConfidence;
        
        _processSatelliteData();
      }
    });
  }

  void _centerMapOnPosition(EnhancedPosition position) {
    _mapController.move(
      LatLng(position.latitude, position.longitude),
      18.0,
    );
  }

  void _logLocationDetails(EnhancedPosition position) {
    print("📍 Map centered at: ${position.latitude}, ${position.longitude}");
    print("🎯 Accuracy: ${position.accuracy.toStringAsFixed(2)} meters");
    print("🛰️ Source: $_locationSource");
    print("🎯 Primary System: $_primarySystem");
    print("💪 Confidence: ${(position.confidenceScore * 100).toStringAsFixed(1)}%");
    print("🏭 Vendor: $_chipsetVendor");
    print("📋 Model: $_chipsetModel");
    print("🎯 Chipset Confidence: ${(_chipsetConfidence * 100).toStringAsFixed(1)}%");
    print("📊 Hardware Confidence: ${(_confidenceLevel * 100).toStringAsFixed(1)}%");
    print("📡 NavIC Satellites: $_navicSatelliteCount ($_navicUsedInFix in fix)");
    print("📶 L5 Band: ${_hasL5Band ? 'Available' : 'Not Available'}");
    print("🔍 L5 Confidence: ${(_l5Confidence * 100).toStringAsFixed(1)}%");
    print("🎯 Positioning Method: $_positioningMethod");
  }

  Future<void> _startRealTimeMonitoring() async {
    try {
      await _locationService.startRealTimeMonitoring();
      await _updateSatelliteData();
    } catch (e) {
      print("Real-time monitoring failed: $e");
    }
  }

  void _updateLocationSource() {
    _locationSource = (_isNavicSupported && _isNavicActive) ? "NAVIC" : _primarySystem;
  }

  void _updateLocationQuality(EnhancedPosition pos) {
    final isUsingNavic = _isNavicSupported && _isNavicActive;
    final isUsingL5 = _hasL5Band;

    if (pos.accuracy < 1.0) {
      _locationQuality = isUsingNavic ? 
        (isUsingL5 ? "NavIC+L5 Excellent" : "NavIC Excellent") : 
        (isUsingL5 ? "L5 Excellent" : "Excellent");
    } else if (pos.accuracy < 2.0) {
      _locationQuality = isUsingNavic ? 
        (isUsingL5 ? "NavIC+L5 High" : "NavIC High") : 
        (isUsingL5 ? "L5 High" : "High");
    } else if (pos.accuracy < 5.0) {
      _locationQuality = isUsingNavic ? 
        (isUsingL5 ? "NavIC+L5 Good" : "NavIC Good") : 
        (isUsingL5 ? "L5 Good" : "Good");
    } else if (pos.accuracy < 10.0) {
      _locationQuality = isUsingNavic ? 
        (isUsingL5 ? "NavIC+L5 Basic" : "NavIC Basic") : 
        (isUsingL5 ? "L5 Basic" : "Basic");
    } else {
      _locationQuality = isUsingNavic ? 
        (isUsingL5 ? "NavIC+L5 Low" : "NavIC Low") : 
        (isUsingL5 ? "L5 Low" : "Low");
    }
  }

  Future<void> _refreshLocation() async {
    final hasPermission = await _checkAndRequestPermission();
    if (!hasPermission) {
      print("❌ No location permission for refresh");
      return;
    }

    setState(() => _isLoading = true);
    await Future.wait([
      _checkNavicHardwareSupport(),
      _acquireCurrentLocation(),
      _updateSatelliteData(),
    ]);
    setState(() => _isLoading = false);
  }

  void _toggleLayerSelection() => setState(() => _showLayerSelection = !_showLayerSelection);
  void _toggleSatelliteList() => setState(() => _showSatelliteList = !_showSatelliteList);
  void _toggleLayer(String layerName) => setState(() => _selectedLayers[layerName] = !_selectedLayers[layerName]!);

  Color _getQualityColor() {
    if (_locationQuality.contains("Excellent")) return Colors.green;
    if (_locationQuality.contains("High")) return Colors.blue;
    if (_locationQuality.contains("Good")) return Colors.orange;
    if (_locationQuality.contains("Basic")) return Colors.amber;
    return Colors.red;
  }

  bool _isValidCoordinate(double lat, double lng) {
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  LatLng _getMapCenter() {
    if (_currentPosition != null &&
        _isValidCoordinate(_currentPosition!.latitude, _currentPosition!.longitude)) {
      return LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    } else if (_lastValidMapCenter != null) {
      return _lastValidMapCenter!;
    } else {
      return const LatLng(28.6139, 77.2090);
    }
  }

  Widget _buildMap() {
    final selectedTileLayers = _selectedLayers.entries
        .where((e) => e.value)
        .map((e) => _tileLayers[e.key]!)
        .toList();

    final mapCenter = _getMapCenter();

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        center: mapCenter,
        zoom: _locationAcquired ? 18.0 : 5.0,
        maxZoom: 20.0,
        minZoom: 3.0,
        interactiveFlags: InteractiveFlag.all,
        keepAlive: true,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.navic',
          subdomains: const ['a', 'b', 'c'],
          maxNativeZoom: 19,
        ),
        ...selectedTileLayers,
        if (_currentPosition != null && _locationAcquired)
          MarkerLayer(
            markers: [
              Marker(
                point: mapCenter,
                width: 80,
                height: 80,
                builder: (ctx) => _buildLocationMarker(),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildLocationMarker() {
    final isNavic = _locationSource == "NAVIC";
    final isL5 = _hasL5Band;
    final accuracy = _currentPosition?.accuracy ?? 10.0;

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: (accuracy * 3.0).clamp(40.0, 250.0),
          height: (accuracy * 3.0).clamp(40.0, 250.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isNavic
                ? (isL5 ? Colors.green.withOpacity(0.15) : Colors.green.withOpacity(0.1))
                : (isL5 ? Colors.blue.withOpacity(0.15) : Colors.blue.withOpacity(0.1)),
            border: Border.all(
              color: isNavic
                  ? (isL5 ? Colors.green : Colors.green.withOpacity(0.4))
                  : (isL5 ? Colors.blue : Colors.blue.withOpacity(0.4)),
              width: isL5 ? 2.0 : 1.5,
            ),
          ),
        ),
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isNavic
                ? (isL5 ? Colors.green.withOpacity(0.25) : Colors.green.withOpacity(0.2))
                : (isL5 ? Colors.blue.withOpacity(0.25) : Colors.blue.withOpacity(0.2)),
            border: Border.all(
              color: isNavic
                  ? (isL5 ? Colors.green : Colors.green.withOpacity(0.6))
                  : (isL5 ? Colors.blue : Colors.blue.withOpacity(0.6)),
              width: isL5 ? 2.5 : 2.0,
            ),
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isNavic
                ? (isL5 ? Colors.green.withOpacity(0.4) : Colors.green.withOpacity(0.3))
                : (isL5 ? Colors.blue.withOpacity(0.4) : Colors.blue.withOpacity(0.3)),
            border: Border.all(
              color: isNavic
                  ? (isL5 ? Colors.green : Colors.green.withOpacity(0.8))
                  : (isL5 ? Colors.blue : Colors.blue.withOpacity(0.8)),
              width: isL5 ? 3.0 : 2.0,
            ),
          ),
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.location_pin,
              color: isNavic ? 
                (isL5 ? Colors.green.shade900 : Colors.green.shade800) : 
                (isL5 ? Colors.blue.shade900 : Colors.blue.shade800),
              size: 28,
            ),
            if (isL5)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.speed,
                    color: Colors.green,
                    size: 12,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSatelliteListPanel() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.satellite_alt, color: Colors.purple.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "SATELLITE VIEW",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    "${_visibleSatellites.length} sats",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _toggleSatelliteList,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          if (_visibleSatellites.isNotEmpty)
            SizedBox(
              height: 300,
              child: ListView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: _visibleSatellites.length,
                itemBuilder: (context, index) {
                  final sat = _visibleSatellites[index];
                  return _buildSatelliteListItem(sat);
                },
              ),
            )
          else
            _buildNoSatellitesView(),
          
          const SizedBox(height: 12),
          
          if (_primarySystem.isNotEmpty)
            _buildPrimarySystemInfo(),
        ],
      ),
    );
  }

  Widget _buildSatelliteListItem(Map<String, dynamic> satellite) {
    final system = satellite['system'] ?? 'UNKNOWN';
    final svid = satellite['svid'] ?? 0;
    final cn0 = (satellite['cn0DbHz'] as num?)?.toDouble() ?? 0.0;
    final used = satellite['usedInFix'] as bool? ?? false;
    final elevation = (satellite['elevation'] as num?)?.toDouble() ?? 0.0;
    final azimuth = (satellite['azimuth'] as num?)?.toDouble() ?? 0.0;
    final carrierFrequency = (satellite['carrierFrequencyHz'] as num?)?.toDouble();
    final signalStrength = satellite['signalStrength'] ?? 'UNKNOWN';
    
    final systemColor = _getSystemColor(system);
    final signalColor = _getSignalColor(cn0);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: systemColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  system,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: systemColor,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "SVID-$svid",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: signalColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: signalColor),
                      ),
                      child: Text(
                        signalStrength,
                        style: TextStyle(
                          fontSize: 10,
                          color: signalColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (used)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.green),
                        ),
                        child: const Text(
                          "IN FIX",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 6),
                
                Row(
                  children: [
                    Icon(Icons.signal_cellular_alt, size: 14, color: signalColor),
                    const SizedBox(width: 4),
                    Text(
                      "${cn0.toStringAsFixed(1)} dB-Hz",
                      style: TextStyle(
                        fontSize: 12,
                        color: signalColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 4),
                
                Row(
                  children: [
                    Icon(Icons.vertical_align_top, size: 14, color: Colors.orange.shade600),
                    const SizedBox(width: 4),
                    Text(
                      "${elevation.toStringAsFixed(0)}°",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.compass_calibration, size: 14, color: Colors.purple.shade600),
                    const SizedBox(width: 4),
                    Text(
                      "${azimuth.toStringAsFixed(0)}°",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.purple.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: used ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
            ),
            child: Icon(
              used ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: used ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSatellitesView() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.satellite, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            "No satellites detected",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Make sure you're outdoors with clear sky view",
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPrimarySystemInfo() {
    Color primaryColor = _getSystemColor(_primarySystem);
    bool isNavicPrimary = _primarySystem.contains("NAVIC");
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isNavicPrimary ? Icons.satellite_alt : Icons.gps_fixed,
                color: primaryColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "PRIMARY POSITIONING SYSTEM",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _primarySystem,
                      style: TextStyle(
                        fontSize: 14,
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (_hasL5Band)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.speed, size: 12, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        "L5 ${(_l5Confidence * 100).toStringAsFixed(0)}%",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          if (_chipsetVendor != "Unknown")
            Row(
              children: [
                Icon(Icons.memory, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "$_chipsetVendor $_chipsetModel",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_chipsetConfidence > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "${(_chipsetConfidence * 100).toStringAsFixed(0)}%",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Color _getSignalColor(double cn0) {
    if (cn0 >= 35) return Colors.green;
    if (cn0 >= 25) return Colors.blue;
    if (cn0 >= 18) return Colors.orange;
    if (cn0 >= 10) return Colors.amber;
    return Colors.red;
  }

  Color _getSystemColor(String system) {
    switch (system.toUpperCase()) {
      case 'IRNSS': return Colors.green;
      case 'GPS': return Colors.blue;
      case 'GLONASS': return Colors.red;
      case 'GALILEO': return Colors.purple;
      case 'BEIDOU': return Colors.orange;
      case 'QZSS': return Colors.pink;
      case 'SBAS': return Colors.teal;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NAVIC',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.green.shade700,
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(_isLoading ? Icons.refresh : Icons.refresh_outlined),
            onPressed: _isLoading ? null : _refreshLocation,
            tooltip: 'Refresh Location',
          ),
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: _toggleLayerSelection,
            tooltip: 'Map Layers',
          ),
          IconButton(
            icon: const Icon(Icons.satellite_alt),
            onPressed: _updateSatelliteData,
            tooltip: 'Update Satellites',
          ),
          if (_currentPosition != null)
            IconButton(
              icon: const Icon(Icons.emergency_share_sharp),
              iconSize: 24,
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EmergencyPage())),
              tooltip: 'Emergency',
            ),
        ],
      ),
      body: Stack(
        children: [
          _buildMap(),
          if (_isLoading) _buildLoadingOverlay(),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildInfoPanel()),
          if (_showLayerSelection) Positioned(top: 80, right: 16, child: _buildLayerSelectionPanel()),
          if (_showSatelliteList) Positioned(top: 80, left: 16, right: 16, child: _buildSatelliteListPanel()),
          if (_isHardwareChecked && !_isLoading)
            Positioned(top: 16, left: 16, right: 16, child: _buildHardwareSupportBanner()),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            onPressed: _toggleSatelliteList,
            backgroundColor: Colors.purple,
            child: Icon(
              _showSatelliteList ? Icons.close : Icons.satellite_alt,
              color: Colors.white,
            ),
            tooltip: 'Satellites',
          ),
          const SizedBox(width: 8),
          if (_currentPosition != null)
            FloatingActionButton(
              onPressed: _refreshLocation,
              backgroundColor: Colors.green,
              child: const Icon(Icons.my_location, color: Colors.white),
              tooltip: 'My Location',
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.4),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              strokeWidth: 3,
            ),
            const SizedBox(height: 20),
            Text(
              "Acquiring Location...",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _locationSource == "NAVIC" ? 
                (_hasL5Band ? "Using NavIC with L5" : "Using NavIC") : 
                (_hasL5Band ? "Using GPS with L5" : "Using GPS"),
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            if (_chipsetVendor != "Unknown") ...[
              const SizedBox(height: 4),
              Text(
                "Chipset: $_chipsetVendor $_chipsetModel | L5: ${_hasL5Band ? 'Yes' : 'No'}",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLayerSelectionPanel() {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "MAP LAYERS",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ..._selectedLayers.keys.map((name) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _toggleLayer(name),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _selectedLayers[name],
                        onChanged: (_) => _toggleLayer(name),
                        activeColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    if (_currentPosition == null) {
      return _buildLocationAcquiringPanel();
    }

    return Container(
      height: 450,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSystemStatusHeader(),
                  const SizedBox(height: 16),
                  _buildCoordinatesSection(),
                  const SizedBox(height: 16),
                  _buildAccuracyMetricsSection(),
                  const SizedBox(height: 16),
                  _buildHardwareInfoSection(),
                  const SizedBox(height: 16),
                  _buildSatelliteSummaryCard(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationAcquiringPanel() {
    return Container(
      height: 160,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _hasL5Band ? Icons.speed : Icons.location_searching, 
            color: Colors.grey.shade400, 
            size: 48
          ),
          const SizedBox(height: 12),
          Text(
            "Acquiring Location",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Using $_locationSource for positioning",
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatusHeader() {
    final pos = _currentPosition!;
    final isNavic = _locationSource == "NAVIC";
    final isL5 = _hasL5Band;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isNavic
            ? (isL5 ? Colors.green.withOpacity(0.15) : Colors.green.withOpacity(0.1))
            : (isL5 ? Colors.blue.withOpacity(0.15) : Colors.blue.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNavic
              ? (isL5 ? Colors.green : Colors.green.withOpacity(0.3))
              : (isL5 ? Colors.blue : Colors.blue.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isNavic ? Colors.green : Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isNavic ? Icons.satellite_alt : Icons.gps_fixed,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isNavic ? "NAVIC POSITIONING" : "GPS POSITIONING",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isNavic ? Colors.green.shade800 : Colors.blue.shade800,
                      ),
                    ),
                    if (isL5) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "L5",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _locationQuality,
                  style: TextStyle(
                    fontSize: 12,
                    color: isNavic ? Colors.green.shade600 : Colors.blue.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_chipsetVendor != "Unknown") ...[
                  const SizedBox(height: 2),
                  Text(
                    "$_chipsetVendor $_chipsetModel | L5: ${_hasL5Band ? 'Yes' : 'No'}",
                    style: TextStyle(
                      fontSize: 10,
                      color: isNavic ? Colors.green.shade500 : Colors.blue.shade500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getQualityColor().withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "${(pos.confidenceScore * 100).toStringAsFixed(0)}%",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _getQualityColor(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoordinatesSection() {
    final pos = _currentPosition!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "COORDINATES",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                icon: Icons.explore,
                title: "LATITUDE",
                value: pos.latitude.toStringAsFixed(6),
                color: Colors.blue.shade50,
                iconColor: Colors.blue.shade700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoCard(
                icon: Icons.explore_outlined,
                title: "LONGITUDE",
                value: pos.longitude.toStringAsFixed(6),
                color: Colors.green.shade50,
                iconColor: Colors.green.shade700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccuracyMetricsSection() {
    final pos = _currentPosition!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "ACCURACY METRICS",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                icon: Icons.location_on_sharp,
                title: "ACCURACY",
                value: "${pos.accuracy.toStringAsFixed(1)} meters",
                color: Colors.orange.shade50,
                iconColor: Colors.orange.shade700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoCard(
                icon: Icons.analytics,
                title: "QUALITY",
                value: _locationQuality,
                color: _getQualityColor().withOpacity(0.1),
                iconColor: _getQualityColor(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHardwareInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "HARDWARE INFO",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                icon: Icons.memory,
                title: "CHIPSET",
                value: "$_chipsetVendor $_chipsetModel",
                color: Colors.purple.shade50,
                iconColor: Colors.purple.shade700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoCard(
                icon: Icons.speed,
                title: "L5 BAND",
                value: _hasL5Band ? "Available" : "Not Available",
                color: _hasL5Band ? Colors.green.shade50 : Colors.orange.shade50,
                iconColor: _hasL5Band ? Colors.green.shade700 : Colors.orange.shade700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSatelliteSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.satellite, color: Colors.purple.shade600, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "SATELLITE SUMMARY",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.list, size: 20),
                onPressed: _toggleSatelliteList,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              _buildSatelliteStat("Total", "$_totalSatelliteCount", Colors.blue),
              const SizedBox(width: 12),
              _buildSatelliteStat("NavIC", "$_navicSatelliteCount", Colors.green),
              const SizedBox(width: 12),
              _buildSatelliteStat("In Fix", "$_navicUsedInFix", Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({required IconData icon, required String title, required String value, required Color color, required Color iconColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSatelliteStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHardwareSupportBanner() {
    Color bannerColor;
    Color bannerIconColor;
    IconData bannerIcon;
    String bannerStatus;

    if (_isNavicActive && _hasL5Band) {
      bannerColor = Colors.green.shade50;
      bannerIconColor = Colors.green;
      bannerIcon = Icons.satellite_alt;
      bannerStatus = "NavIC + L5";
    } else if (_isNavicActive) {
      bannerColor = Colors.green.shade50;
      bannerIconColor = Colors.green;
      bannerIcon = Icons.satellite_alt;
      bannerStatus = "NavIC Active";
    } else if (_isNavicSupported && _hasL5Band) {
      bannerColor = Colors.blue.shade50;
      bannerIconColor = Colors.blue;
      bannerIcon = Icons.check_circle;
      bannerStatus = "NavIC + L5 Ready";
    } else if (_isNavicSupported && !_hasL5Band) {
      bannerColor = Colors.amber.shade50;
      bannerIconColor = Colors.orange;
      bannerIcon = Icons.info;
      bannerStatus = "NavIC Ready";
    } else if (_hasL5Band) {
      bannerColor = Colors.blue.shade50;
      bannerIconColor = Colors.blue;
      bannerIcon = Icons.speed;
      bannerStatus = "L5 GPS";
    } else {
      bannerColor = Colors.orange.shade50;
      bannerIconColor = Colors.orange;
      bannerIcon = Icons.warning;
      bannerStatus = "GPS Only";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bannerIconColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(bannerIcon, color: bannerIconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bannerStatus,
                  style: TextStyle(
                    color: bannerIconColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _hardwareMessage,
                  style: TextStyle(
                    color: bannerIconColor,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (_confidenceLevel > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: bannerIconColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "${(_confidenceLevel * 100).toStringAsFixed(0)}%",
                style: TextStyle(
                  color: bannerIconColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _locationService.dispose();
    super.dispose();
  }
}