import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:navic/services/location_service.dart';
import 'package:navic/screens/emergency.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LocationService _locationService = LocationService();
  final MapController _mapController = MapController();
  final ScrollController _scrollController = ScrollController();

  EnhancedPosition? _currentEnhancedPosition;
  String _locationQuality = "Acquiring Location...";
  String _locationSource = "GPS";
  bool _isLoading = true;
  bool _isHardwareChecked = false;
  bool _isNavicSupported = false;
  bool _isNavicActive = false;
  bool _hasL5Band = false;
  String _hardwareMessage = "Checking hardware...";
  String _hardwareStatus = "Checking...";
  bool _showLayerSelection = false;
  bool _showSatelliteList = false;
  bool _locationAcquired = false;
  LatLng? _lastValidMapCenter;
  String _chipsetType = "Unknown";
  double _confidenceLevel = 0.0;
  double _signalStrength = 0.0;
  int _navicSatelliteCount = 0;
  int _totalSatelliteCount = 0;
  int _navicUsedInFix = 0;
  String _positioningMethod = "GPS";
  Map<String, dynamic> _l5BandInfo = {};
  List<dynamic> _allSatellites = [];
  List<dynamic> _visibleSystems = [];

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
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await _checkNavicHardwareSupport();
      await _initializeLocation();
      await _startRealTimeMonitoring();
    } catch (e) {
      print("Initialization error: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkNavicHardwareSupport() async {
    try {
      // Hardware support is checked during location service initialization
      // Get current hardware status from location service
      final serviceStats = _locationService.getServiceStats();

      setState(() {
        _isNavicSupported = serviceStats['navicSupported'] as bool? ?? false;
        _isNavicActive = serviceStats['navicActive'] as bool? ?? false;
        _hasL5Band = serviceStats['hasL5Band'] as bool? ?? false;
        _chipsetType = serviceStats['chipsetType'] as String? ?? "Unknown";
        _confidenceLevel = (serviceStats['confidenceLevel'] as num?)?.toDouble() ?? 0.0;
        _signalStrength = (serviceStats['signalStrength'] as num?)?.toDouble() ?? 0.0;
        _navicSatelliteCount = serviceStats['navicSatellites'] as int? ?? 0;
        _totalSatelliteCount = serviceStats['totalSatellites'] as int? ?? 0;
        _navicUsedInFix = serviceStats['navicUsedInFix'] as int? ?? 0;
        _positioningMethod = serviceStats['positioningMethod'] as String? ?? "GPS";
        _l5BandInfo = serviceStats['l5BandInfo'] as Map<String, dynamic>? ?? {};
        _visibleSystems = serviceStats['visibleSystems'] as List<dynamic>? ?? [];

        _updateHardwareMessage();
      });

      // Get all satellites
      await _updateSatelliteData();

    } catch (e) {
      _setHardwareErrorState();
    }
  }

  Future<void> _updateSatelliteData() async {
    try {
      final satellites = _locationService.allSatellites;
      final systems = _locationService.visibleSystems;

      setState(() {
        _allSatellites = satellites;
        _visibleSystems = systems;
      });
    } catch (e) {
      print("Error updating satellite data: $e");
    }
  }

  void _updateHardwareMessage() {
    if (!_isNavicSupported && !_hasL5Band) {
      _hardwareMessage = "Chipset does not support NavIC and device does not have L5 band";
      _hardwareStatus = "Limited Hardware";
    } else if (_isNavicSupported && !_hasL5Band) {
      _hardwareMessage = "Device chipset supports NavIC but does not have L5 band. Receiving NavIC signals may not be possible";
      _hardwareStatus = "NavIC Limited";
    } else if (_isNavicSupported && _hasL5Band) {
      _hardwareMessage = "Device chipset supports NavIC and contains L5 band. NavIC ready!";
      _hardwareStatus = "NavIC Ready";
    } else {
      _hardwareMessage = "Using standard GPS positioning";
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
      _hardwareMessage = "Hardware detection failed";
      _hardwareStatus = "Error";
      _locationSource = "GPS";
      _chipsetType = "Unknown";
      _confidenceLevel = 0.0;
      _signalStrength = 0.0;
      _navicSatelliteCount = 0;
      _totalSatelliteCount = 0;
      _navicUsedInFix = 0;
      _positioningMethod = "GPS";
      _l5BandInfo = {};
      _allSatellites = [];
      _visibleSystems = [];
    });
  }

  Future<void> _initializeLocation() async {
    try {
      final hasPermission = await _checkAndRequestPermission();
      if (hasPermission) {
        await _acquireCurrentLocation();
      }
    } catch (e) {
      print("Location initialization error: $e");
    }
  }

  Future<bool> _checkAndRequestPermission() async {
    bool hasPermission = await _locationService.checkLocationPermission();
    if (!hasPermission) {
      hasPermission = await _locationService.requestLocationPermission();
    }
    return hasPermission;
  }

  Future<void> _acquireCurrentLocation() async {
    final position = await _locationService.getCurrentLocation();
    if (position != null && _isValidCoordinate(position.latitude, position.longitude)) {
      _updateLocationState(position);
      _centerMapOnPosition(position);
      _logLocationDetails(position);
    }
  }

  void _updateLocationState(EnhancedPosition position) {
    setState(() {
      _currentEnhancedPosition = position;
      _updateLocationSource();
      _updateLocationQuality(position);
      _locationAcquired = true;
      _lastValidMapCenter = LatLng(position.latitude, position.longitude);

      // Update satellite data from position
      if (position.satelliteInfo.isNotEmpty) {
        _navicSatelliteCount = position.navicSatellites ?? 0;
        _totalSatelliteCount = position.totalSatellites ?? 0;
        _navicUsedInFix = position.navicUsedInFix ?? 0;
        _hasL5Band = position.hasL5Band;
        _positioningMethod = position.positioningMethod;
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
    print("🎯 Enhanced Accuracy: ${position.accuracy.toStringAsFixed(2)} meters");
    print("🛰️ Source: $_locationSource");
    print("💪 Confidence: ${(position.confidenceScore * 100).toStringAsFixed(1)}%");
    print("💾 Chipset: $_chipsetType");
    print("📊 Hardware Confidence: ${(_confidenceLevel * 100).toStringAsFixed(1)}%");
    print("📡 NavIC Satellites: $_navicSatelliteCount ($_navicUsedInFix in fix)");
    print("📶 L5 Band: ${_hasL5Band ? 'Available' : 'Not Available'}");
    print("🎯 Positioning Method: $_positioningMethod");
  }

  Future<void> _startRealTimeMonitoring() async {
    try {
      await _locationService.startRealTimeMonitoring();
    } catch (e) {
      print("Real-time monitoring failed: $e");
    }
  }

  void _updateLocationSource() {
    _locationSource = (_isNavicSupported && _isNavicActive) ? "NAVIC" : "GPS";
  }

  void _updateLocationQuality(EnhancedPosition pos) {
    final isUsingNavic = _isNavicSupported && _isNavicActive;

    if (pos.accuracy < 2.0) {
      _locationQuality = isUsingNavic ? "NavIC Excellent" : "Excellent Precision";
    } else if (pos.accuracy < 5.0) {
      _locationQuality = isUsingNavic ? "NavIC High Precision" : "High Precision";
    } else if (pos.accuracy < 10.0) {
      _locationQuality = isUsingNavic ? "NavIC Good Quality" : "Good Quality";
    } else if (pos.accuracy < 20.0) {
      _locationQuality = isUsingNavic ? "NavIC Basic" : "Basic Location";
    } else {
      _locationQuality = isUsingNavic ? "NavIC Low Accuracy" : "Low Accuracy";
    }
  }

  Future<void> _refreshLocation() async {
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
    if (_currentEnhancedPosition != null &&
        _isValidCoordinate(_currentEnhancedPosition!.latitude, _currentEnhancedPosition!.longitude)) {
      return LatLng(_currentEnhancedPosition!.latitude, _currentEnhancedPosition!.longitude);
    } else if (_lastValidMapCenter != null) {
      return _lastValidMapCenter!;
    } else {
      return const LatLng(28.6139, 77.2090); // Default to New Delhi
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
        // Base tile layer
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.navic',
          subdomains: const ['a', 'b', 'c'],
          maxNativeZoom: 19,
        ),
        ...selectedTileLayers,
        if (_currentEnhancedPosition != null && _locationAcquired)
          MarkerLayer(
            markers: [
              Marker(
                point: mapCenter,
                width: 80,
                height: 80,
                child: _buildLocationMarker(),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildLocationMarker() {
    final isNavic = _locationSource == "NAVIC";
    final accuracy = _currentEnhancedPosition?.accuracy ?? 10.0;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer accuracy circle
        Container(
          width: (accuracy * 3.0).clamp(40.0, 250.0),
          height: (accuracy * 3.0).clamp(40.0, 250.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isNavic
                ? Colors.green.withOpacity(0.1)
                : Colors.blue.withOpacity(0.1),
            border: Border.all(
              color: isNavic
                  ? Colors.green.withOpacity(0.4)
                  : Colors.blue.withOpacity(0.4),
              width: 1.5,
            ),
          ),
        ),
        // Inner pulse circle
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isNavic
                ? Colors.green.withOpacity(0.3)
                : Colors.blue.withOpacity(0.3),
            border: Border.all(
              color: isNavic
                  ? Colors.green
                  : Colors.blue,
              width: 2,
            ),
          ),
        ),
        // Center pin
        Icon(
          Icons.location_pin,
          color: isNavic ? Colors.green.shade800 : Colors.blue.shade800,
          size: 24,
        ),
      ],
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

  Widget _buildSatelliteListPanel() {
    return Container(
      width: 320,
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
              Text(
                "SATELLITES IN VIEW (${_allSatellites.length})",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: _toggleSatelliteList,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_allSatellites.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.satellite, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    "No satellites detected",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 300,
              child: ListView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: _allSatellites.length,
                itemBuilder: (context, index) {
                  final sat = _allSatellites[index];
                  return _buildSatelliteListItem(sat);
                },
              ),
            ),
          const SizedBox(height: 12),
          _buildSystemSummary(),
        ],
      ),
    );
  }

  Widget _buildSatelliteListItem(Map<String, dynamic> satellite) {
    final system = satellite['system'] ?? 'UNKNOWN';
    final svid = satellite['svid'] ?? 0;
    final cn0 = (satellite['cn0DbHz'] as num?)?.toDouble() ?? 0.0;
    final usedInFix = satellite['usedInFix'] as bool? ?? false;
    final countryFlag = satellite['countryFlag'] ?? '🌍';
    final frequencyBand = satellite['frequencyBand'] ?? 'Unknown';
    final elevation = (satellite['elevation'] as num?)?.toDouble() ?? 0.0;

    final (iconColor, statusText) = _getSatelliteStatusInfo(cn0, usedInFix);

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
          // Country flag
          Text(countryFlag, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),

          // System and SVID
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      system,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getSystemColor(system),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "SVID-$svid",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    Text(
                      "${cn0.toStringAsFixed(1)} dB-Hz",
                      style: TextStyle(
                        color: iconColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      frequencyBand,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      "${elevation.toStringAsFixed(0)}°",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: iconColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  usedInFix ? Icons.check_circle : Icons.circle,
                  color: iconColor,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemSummary() {
    final systemCounts = <String, int>{};
    for (final system in _visibleSystems) {
      if (system is Map<String, dynamic>) {
        final name = system['name'] ?? 'UNKNOWN';
        final count = system['count'] ?? 0;
        if (count > 0) {
          systemCounts[name] = count;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "SYSTEMS IN VIEW",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: systemCounts.entries.map((entry) {
            final (systemColor, flag) = _getSystemInfo(entry.key);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: systemColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: systemColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(flag, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  Text(
                    entry.key,
                    style: TextStyle(
                      color: systemColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "(${entry.value})",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  (Color, String) _getSystemInfo(String system) {
    switch (system.toUpperCase()) {
      case 'IRNSS':
        return (Colors.green, '🇮🇳');
      case 'GPS':
        return (Colors.blue, '🇺🇸');
      case 'GLONASS':
        return (Colors.red, '🇷🇺');
      case 'GALILEO':
        return (Colors.purple, '🇪🇺');
      case 'BEIDOU':
        return (Colors.orange, '🇨🇳');
      case 'QZSS':
        return (Colors.pink, '🇯🇵');
      default:
        return (Colors.grey, '🌍');
    }
  }

  Color _getSystemColor(String system) {
    switch (system.toUpperCase()) {
      case 'IRNSS':
        return Colors.green;
      case 'GPS':
        return Colors.blue;
      case 'GLONASS':
        return Colors.red;
      case 'GALILEO':
        return Colors.purple;
      case 'BEIDOU':
        return Colors.orange;
      case 'QZSS':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  (Color, String) _getSatelliteStatusInfo(double cn0, bool usedInFix) {
    if (usedInFix) {
      if (cn0 >= 30) return (Colors.green, 'Strong');
      if (cn0 >= 20) return (Colors.blue, 'Good');
      return (Colors.orange, 'Weak');
    } else {
      if (cn0 >= 20) return (Colors.blue, 'Visible');
      return (Colors.grey, 'Poor');
    }
  }

  Widget _buildEnhancedSatelliteInfoCard() {
    if (_currentEnhancedPosition?.satelliteInfo == null) {
      return Container();
    }

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
                    "SATELLITE INFORMATION",
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

          // Satellite counts
          Row(
            children: [
              _buildSatelliteStat("Total", "$_totalSatelliteCount", Colors.blue),
              const SizedBox(width: 12),
              _buildSatelliteStat("NavIC", "$_navicSatelliteCount", Colors.green),
              const SizedBox(width: 12),
              _buildSatelliteStat("In Fix", "$_navicUsedInFix", Colors.orange),
            ],
          ),
          const SizedBox(height: 12),

          // System summary
          _buildSystemSummaryRow(),
          const SizedBox(height: 12),

          // Hardware information
          Row(
            children: [
              _buildHardwareStat("Chipset", _chipsetType, Colors.purple),
              const SizedBox(width: 12),
              _buildHardwareStat("L5 Band", _hasL5Band ? "✅ Available" : "❌ Not Available",
                  _hasL5Band ? Colors.green : Colors.orange),
            ],
          ),
          const SizedBox(height: 8),

          // Positioning method
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getPositioningMethodColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _getPositioningMethodColor().withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getPositioningMethodIcon(),
                  color: _getPositioningMethodColor(),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _positioningMethod.replaceAll('_', ' '),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getPositioningMethodColor(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemSummaryRow() {
    final systemStats = _locationService.systemStats;
    final systems = ['IRNSS', 'GPS', 'GLONASS', 'GALILEO', 'BEIDOU'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: systems.map((system) {
        final flag = _getSystemInfo(system).$2;
        final color = _getSystemColor(system);
        final total = (systemStats[system] as Map<String, dynamic>?)?['total'] as int? ?? 0;
        final used = (systemStats[system] as Map<String, dynamic>?)?['used'] as int? ?? 0;

        return Column(
          children: [
            Text(flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              system,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              "$used/$total",
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Color _getPositioningMethodColor() {
    if (_positioningMethod.contains('NAVIC')) return Colors.green;
    if (_positioningMethod.contains('GPS')) return Colors.blue;
    if (_positioningMethod.contains('GLONASS')) return Colors.red;
    if (_positioningMethod.contains('GALILEO')) return Colors.purple;
    if (_positioningMethod.contains('BEIDOU')) return Colors.orange;
    if (_positioningMethod.contains('HYBRID')) return Colors.pink;
    return Colors.grey;
  }

  IconData _getPositioningMethodIcon() {
    if (_positioningMethod.contains('NAVIC')) return Icons.satellite_alt;
    if (_positioningMethod.contains('GPS')) return Icons.gps_fixed;
    if (_positioningMethod.contains('HYBRID')) return Icons.merge_type;
    return Icons.gps_not_fixed;
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

  Widget _buildHardwareStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedInfoPanel() {
    if (_currentEnhancedPosition == null) {
      return _buildLocationAcquiringPanel();
    }

    return Container(
      height: 420,
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
          _buildPanelDragHandle(),
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
                  _buildEnhancedSatelliteInfoCard(),
                  const SizedBox(height: 16),
                  _buildHardwareStatusCard(),
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
          Icon(Icons.location_searching, color: Colors.grey.shade400, size: 48),
          const SizedBox(height: 12),
          Text(
            "Acquiring Your Location",
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

  Widget _buildPanelDragHandle() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildSystemStatusHeader() {
    final pos = _currentEnhancedPosition!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _locationSource == "NAVIC"
            ? Colors.green.withOpacity(0.1)
            : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _locationSource == "NAVIC"
              ? Colors.green.withOpacity(0.3)
              : Colors.blue.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _locationSource == "NAVIC" ? Colors.green : Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _locationSource == "NAVIC" ? Icons.satellite_alt : Icons.gps_fixed,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _locationSource == "NAVIC" ? "NAVIC POSITIONING ACTIVE" : "GPS POSITIONING ACTIVE",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _locationSource == "NAVIC" ? Colors.green.shade800 : Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _locationQuality,
                  style: TextStyle(
                    fontSize: 12,
                    color: _locationSource == "NAVIC" ? Colors.green.shade600 : Colors.blue.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_chipsetType != "Unknown") ...[
                  const SizedBox(height: 2),
                  Text(
                    "Chipset: $_chipsetType | L5: ${_hasL5Band ? 'Yes' : 'No'}",
                    style: TextStyle(
                      fontSize: 10,
                      color: _locationSource == "NAVIC" ? Colors.green.shade500 : Colors.blue.shade500,
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
    final pos = _currentEnhancedPosition!;

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
    final pos = _currentEnhancedPosition!;

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

  Widget _buildHardwareStatusCard() {
    final (cardColor, iconColor, icon) = _getHardwareStatusColors();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hardwareStatus,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _hardwareMessage,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 2,
                ),
                if (_confidenceLevel > 0) ...[
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: _confidenceLevel,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _confidenceLevel > 0.7 ? Colors.green :
                      _confidenceLevel > 0.4 ? Colors.orange : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Hardware Confidence: ${(_confidenceLevel * 100).toStringAsFixed(1)}%",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedHardwareSupportBanner() {
    final (bannerColor, iconColor, icon, status, subtitle) = _getHardwareBannerConfig();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withOpacity(0.3)),
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
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(status, style: TextStyle(color: iconColor, fontSize: 14, fontWeight: FontWeight.bold)),
              Text(
                subtitle,
                style: TextStyle(color: iconColor, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _hardwareMessage,
              style: TextStyle(color: iconColor, fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_confidenceLevel > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "${(_confidenceLevel * 100).toStringAsFixed(0)}%",
                style: TextStyle(
                  color: iconColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  (Color, Color, IconData, String, String) _getHardwareBannerConfig() {
    if (_isNavicActive) {
      return (
      Colors.green.shade50,
      Colors.green,
      Icons.satellite_alt,
      "NavIC Active",
      "Using $_navicSatelliteCount satellites"
      );
    } else if (_isNavicSupported && _hasL5Band) {
      return (
      Colors.blue.shade50,
      Colors.blue,
      Icons.check_circle,
      "NavIC Ready",
      "L5 band available"
      );
    } else if (_isNavicSupported && !_hasL5Band) {
      return (
      Colors.amber.shade50,
      Colors.orange,
      Icons.info,
      "NavIC Limited",
      "No L5 band"
      );
    } else {
      return (
      Colors.orange.shade50,
      Colors.orange,
      Icons.warning,
      "GPS Only",
      "No NavIC hardware"
      );
    }
  }

  (Color, Color, IconData) _getHardwareStatusColors() {
    if (!_isNavicSupported && !_hasL5Band) {
      return (Colors.orange.shade50, Colors.orange, Icons.warning);
    } else if (_isNavicSupported && !_hasL5Band) {
      return (Colors.amber.shade50, Colors.orange, Icons.info);
    } else if (_isNavicSupported && _hasL5Band) {
      return (Colors.green.shade50, Colors.green, Icons.check_circle);
    } else {
      return (Colors.blue.shade50, Colors.blue, Icons.gps_fixed);
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
          if (_currentEnhancedPosition != null)
            IconButton(
              icon: const Icon(Icons.emergency_share_sharp),
              iconSize: 24,
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => EmergencyPage())),
              tooltip: 'Emergency',
            ),
        ],
      ),
      body: Stack(
        children: [
          _buildMap(),
          if (_isLoading) _buildLoadingOverlay(),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildEnhancedInfoPanel()),
          if (_showLayerSelection) Positioned(top: 80, right: 16, child: _buildLayerSelectionPanel()),
          if (_showSatelliteList) Positioned(top: 80, left: 16, child: _buildSatelliteListPanel()),
          if (_isHardwareChecked && !_isLoading)
            Positioned(top: 16, left: 16, right: 16, child: _buildEnhancedHardwareSupportBanner()),
        ],
      ),
      floatingActionButton: _currentEnhancedPosition != null
          ? FloatingActionButton(
        onPressed: _refreshLocation,
        backgroundColor: Colors.green,
        child: const Icon(Icons.my_location, color: Colors.white),
        elevation: 4,
      )
          : null,
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
              _locationSource == "NAVIC" ? "Using NavIC for maximum accuracy" : "Using GPS location services",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            if (_chipsetType != "Unknown") ...[
              const SizedBox(height: 4),
              Text(
                "Chipset: $_chipsetType | L5: ${_hasL5Band ? 'Yes' : 'No'}",
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

  @override
  void dispose() {
    _scrollController.dispose();
    _locationService.dispose();
    super.dispose();
  }
}