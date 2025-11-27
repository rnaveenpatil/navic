import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
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
  String _hardwareMessage = "Checking hardware...";
  bool _showLayerSelection = false;
  bool _locationAcquired = false;
  LatLng? _lastValidMapCenter;

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
      final hardwareSupport = await _locationService.checkNavicHardwareSupport();
      setState(() {
        _isHardwareChecked = true;
        _isNavicSupported = hardwareSupport['isSupported'] ?? false;
        _isNavicActive = hardwareSupport['isActive'] ?? false;
        _hardwareMessage = hardwareSupport['message'] ?? 'Hardware check completed';
        _updateLocationSource();
      });
    } catch (e) {
      setState(() {
        _isHardwareChecked = true;
        _isNavicSupported = false;
        _isNavicActive = false;
        _hardwareMessage = "Hardware detection failed";
        _locationSource = "GPS";
      });
    }
  }

  Future<void> _initializeLocation() async {
    try {
      bool hasPermission = await _locationService.checkLocationPermission();
      if (!hasPermission) {
        hasPermission = await _locationService.requestLocationPermission();
      }
      
      if (hasPermission) {
        // Use the maximum accuracy location service
        EnhancedPosition? pos = await _locationService.getCurrentLocation();
        if (pos != null && _isValidCoordinate(pos.latitude, pos.longitude)) {
          setState(() {
            _currentEnhancedPosition = pos;
            _updateLocationSource();
            _updateLocationQuality(pos);
            _locationAcquired = true;
            _lastValidMapCenter = LatLng(pos.latitude, pos.longitude);
          });
          
          _mapController.move(
            LatLng(pos.latitude, pos.longitude),
            18.0,
          );
          
          print("📍 Map centered at: ${pos.latitude}, ${pos.longitude}");
          print("🎯 Enhanced Accuracy: ${pos.accuracy?.toStringAsFixed(2)} meters");
          print("🛰️ Source: $_locationSource");
          print("💪 Confidence: ${(pos.confidenceScore * 100).toStringAsFixed(1)}%");
        }
      }
    } catch (e) {
      print("Location initialization error: $e");
    }
  }

  void _updateLocationSource() {
    if (_isNavicSupported && _isNavicActive) {
      _locationSource = "NAVIC";
    } else {
      _locationSource = "GPS";
    }
  }

  void _updateLocationQuality(EnhancedPosition pos) {
    bool isUsingNavic = _isNavicSupported && _isNavicActive;

    if (pos.accuracy == null) {
      _locationQuality = "Location Acquired";
    } else if (pos.accuracy! < 2.0) {
      _locationQuality = isUsingNavic ? "NavIC Excellent" : "Excellent Precision";
    } else if (pos.accuracy! < 5.0) {
      _locationQuality = isUsingNavic ? "NavIC High Precision" : "High Precision";
    } else if (pos.accuracy! < 10.0) {
      _locationQuality = isUsingNavic ? "NavIC Good Quality" : "Good Quality";
    } else if (pos.accuracy! < 20.0) {
      _locationQuality = isUsingNavic ? "NavIC Basic" : "Basic Location";
    } else {
      _locationQuality = isUsingNavic ? "NavIC Low Accuracy" : "Low Accuracy";
    }
  }

  Future<void> _refreshLocation() async {
    setState(() => _isLoading = true);
    await _checkNavicHardwareSupport();
    await _initializeLocation();
    setState(() => _isLoading = false);
  }

  void _toggleLayerSelection() => setState(() => _showLayerSelection = !_showLayerSelection);
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
      ),
      children: [
        ...selectedTileLayers,
        if (_currentEnhancedPosition != null && _locationAcquired)
          MarkerLayer(
            markers: [
              Marker(
                point: mapCenter,
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer accuracy circle
                    if (_currentEnhancedPosition!.accuracy != null)
                      Container(
                        width: (_currentEnhancedPosition!.accuracy! * 3.0).clamp(40.0, 250.0),
                        height: (_currentEnhancedPosition!.accuracy! * 3.0).clamp(40.0, 250.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _locationSource == "NAVIC" 
                              ? Colors.green.withOpacity(0.1)
                              : Colors.blue.withOpacity(0.1),
                          border: Border.all(
                            color: _locationSource == "NAVIC" 
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
                        color: _locationSource == "NAVIC" 
                            ? Colors.green.withOpacity(0.3)
                            : Colors.blue.withOpacity(0.3),
                        border: Border.all(
                          color: _locationSource == "NAVIC" 
                              ? Colors.green
                              : Colors.blue,
                          width: 2,
                        ),
                      ),
                    ),
                    // Center pin
                    Icon(
                      Icons.location_pin,
                      color: _locationSource == "NAVIC" ? Colors.green.shade800 : Colors.blue.shade800,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ],
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

  Widget _buildSatelliteInfoCard() {
    if (_currentEnhancedPosition?.satelliteInfo == null) {
      return Container();
    }

    final satelliteInfo = _currentEnhancedPosition!.satelliteInfo;
    
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
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSatelliteStat("Total", "${satelliteInfo['totalSatellites'] ?? '0'}", Colors.blue),
              const SizedBox(width: 12),
              _buildSatelliteStat("NavIC", "${satelliteInfo['navicSatellites'] ?? '0'}", Colors.green),
              const SizedBox(width: 12),
              _buildSatelliteStat("In Fix", "${satelliteInfo['navicUsedInFix'] ?? '0'}", Colors.orange),
            ],
          ),
          if (satelliteInfo['hdop'] != null) ...[
            const SizedBox(height: 8),
            Text(
              "HDOP: ${satelliteInfo['hdop']}",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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

  Widget _buildEnhancedInfoPanel() {
    if (_currentEnhancedPosition == null) {
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

    final pos = _currentEnhancedPosition!;

    return Container(
      height: 320,
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
          // Header with drag handle
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
                  // System status header
                  Container(
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
                  ),
                  const SizedBox(height: 16),

                  // Coordinates section
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
                  const SizedBox(height: 16),

                  // Accuracy and quality section
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
                          value: "${pos.accuracy?.toStringAsFixed(1) ?? 'N/A'} meters",
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
                  const SizedBox(height: 16),

                  // Satellite information
                  _buildSatelliteInfoCard(),
                  const SizedBox(height: 16),

                  // Hardware status
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isNavicActive ? Icons.check_circle :
                          _isNavicSupported ? Icons.info : Icons.warning,
                          color: _isNavicActive ? Colors.green :
                                _isNavicSupported ? Colors.blue : Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isNavicActive ? "NAVIC HARDWARE ACTIVE" :
                                _isNavicSupported ? "NAVIC HARDWARE READY" : "GPS ONLY MODE",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: _isNavicActive ? Colors.green :
                                        _isNavicSupported ? Colors.blue : Colors.orange,
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
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareSupportBanner() {
    Color bannerColor = Colors.orange.shade50;
    Color iconColor = Colors.orange;
    IconData icon = Icons.warning;
    String status = "GPS Only";

    if (_isNavicActive) {
      bannerColor = Colors.green.shade50;
      iconColor = Colors.green;
      icon = Icons.satellite_alt;
      status = "NavIC Active";
    } else if (_isNavicSupported) {
      bannerColor = Colors.blue.shade50;
      iconColor = Colors.blue;
      icon = Icons.search;
      status = "NavIC Ready";
    }

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
          Text(status, style: TextStyle(color: iconColor, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _hardwareMessage,
              style: TextStyle(color: iconColor, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NAVIC ',
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
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.4), // Transparent overlay like before
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
                      "locating ....",
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
                  ],
                ),
              ),
            ),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildEnhancedInfoPanel()),
          if (_showLayerSelection) Positioned(top: 80, right: 16, child: _buildLayerSelectionPanel()),
          if (_isHardwareChecked && !_isLoading)
            Positioned(top: 16, left: 16, right: 16, child: _buildHardwareSupportBanner()),
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