import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
  String _chipsetType = "Unknown";
  double _confidenceLevel = 0.0;
  double _signalStrength = 0.0;
  int _navicSatelliteCount = 0;
  int _totalSatelliteCount = 0;
  int _navicUsedInFix = 0;

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
      // and real-time monitoring, so we just ensure the state is updated
      await _locationService.startRealTimeMonitoring();
      _updateLocationSource();
    } catch (e) {
      _setHardwareErrorState();
    }
  }

  void _setHardwareErrorState() {
    setState(() {
      _isHardwareChecked = true;
      _isNavicSupported = false;
      _isNavicActive = false;
      _hardwareMessage = "Hardware detection failed";
      _locationSource = "GPS";
      _chipsetType = "Unknown";
      _confidenceLevel = 0.0;
      _signalStrength = 0.0;
      _navicSatelliteCount = 0;
      _totalSatelliteCount = 0;
      _navicUsedInFix = 0;
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
    ]);
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
                child: _buildLocationMarker(),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildLocationMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer accuracy circle
        Container(
          width: (_currentEnhancedPosition!.accuracy * 3.0).clamp(40.0, 250.0),
          height: (_currentEnhancedPosition!.accuracy * 3.0).clamp(40.0, 250.0),
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

  Widget _buildEnhancedSatelliteInfoCard() {
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
                "ENHANCED SATELLITE INFORMATION",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
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

          // Hardware information
          Row(
            children: [
              _buildHardwareStat("Chipset", _chipsetType, Colors.purple),
              const SizedBox(width: 12),
              _buildHardwareStat("HW Confidence", "${(_confidenceLevel * 100).toStringAsFixed(0)}%",
                  _confidenceLevel > 0.7 ? Colors.green : Colors.orange),
            ],
          ),
          const SizedBox(height: 8),

          // Technical details
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (_signalStrength > 0)
                _buildTechDetail("Signal: ${_signalStrength.toStringAsFixed(1)} dB-Hz", Icons.signal_cellular_alt),
              if (satelliteInfo['stability'] != null)
                _buildTechDetail("Stability: ${satelliteInfo['stability']}", Icons.trending_up),
              if (satelliteInfo['optimizationLevel'] != null)
                _buildTechDetail(satelliteInfo['optimizationLevel'], Icons.bolt),
            ],
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

  Widget _buildTechDetail(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedInfoPanel() {
    if (_currentEnhancedPosition == null) {
      return _buildLocationAcquiringPanel();
    }

    return Container(
      height: 380,
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
                    "Chipset: $_chipsetType",
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
    return Container(
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
    } else if (_isNavicSupported) {
      return (
      Colors.blue.shade50,
      Colors.blue,
      Icons.search,
      "NavIC Ready",
      "Hardware supported"
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
                "Chipset: $_chipsetType",
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