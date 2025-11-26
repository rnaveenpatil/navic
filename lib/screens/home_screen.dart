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
  EnhancedPosition? _currentEnhancedPosition;
  String _locationQuality = "Acquiring Location...";
  String _locationSource = "GPS";
  bool _isLoading = true;
  bool _isHardwareChecked = false;
  bool _isNavicSupported = false;
  bool _isNavicActive = false;
  String _hardwareMessage = "Checking hardware...";
  bool _showLayerSelection = false;

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
      urlTemplate: 'https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
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
        EnhancedPosition? pos = await _locationService.getCurrentLocation();
        if (pos != null) {
          setState(() {
            _currentEnhancedPosition = pos;
            _updateLocationSource();
            _updateLocationQuality(pos);
          });
          _mapController.move(
            LatLng(pos.position.latitude, pos.position.longitude),
            16.0,
          );
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

    if (pos.position.accuracy == null) {
      _locationQuality = "Location Acquired";
    } else if (pos.position.accuracy! < 5.0) {
      _locationQuality = isUsingNavic ? "NavIC High Precision" : "High Precision";
    } else if (pos.position.accuracy! < 15.0) {
      _locationQuality = isUsingNavic ? "NavIC Good Quality" : "Good Quality";
    } else {
      _locationQuality = isUsingNavic ? "NavIC Basic" : "Basic Location";
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
    if (_locationQuality.contains("High")) return Colors.green;
    if (_locationQuality.contains("Good")) return Colors.blue;
    return Colors.orange;
  }

  Widget _buildMap() {
    final selectedTileLayers = _selectedLayers.entries
        .where((e) => e.value)
        .map((e) => _tileLayers[e.key]!)
        .toList();

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        center: _currentEnhancedPosition != null
            ? LatLng(_currentEnhancedPosition!.position.latitude, _currentEnhancedPosition!.position.longitude)
            : const LatLng(20.5937, 78.9629),
        zoom: 16.0,
      ),
      children: [
        ...selectedTileLayers,
        if (_currentEnhancedPosition != null)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(_currentEnhancedPosition!.position.latitude, _currentEnhancedPosition!.position.longitude),
                width: 50,
                height: 50,
                child: Icon(
                  Icons.location_pin,
                  color: _locationSource == "NAVIC" ? Colors.green.shade600 : Colors.blue.shade600,
                  size: 50,
                ),
              ),
            ],
          ),
        if (_currentEnhancedPosition != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: LatLng(_currentEnhancedPosition!.position.latitude, _currentEnhancedPosition!.position.longitude),
                color: _locationSource == "NAVIC" ? Colors.green.withOpacity(0.15) : Colors.blue.withOpacity(0.15),
                borderColor: _locationSource == "NAVIC" ? Colors.green.withOpacity(0.6) : Colors.blue.withOpacity(0.6),
                borderStrokeWidth: 2,
                radius: _currentEnhancedPosition!.position.accuracy ?? 25,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildInfoCard({required IconData icon, required String title, required String value, required Color color, required Color iconColor}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Text(value, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedInfoPanel() {
    if (_currentEnhancedPosition == null) {
      return Container(
        height: 120,
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: const Center(child: Text("Location not available")),
      );
    }

    final pos = _currentEnhancedPosition!;

    return Container(
      height: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_locationSource == "NAVIC" ? Icons.satellite_alt : Icons.gps_fixed,
                    color: _locationSource == "NAVIC" ? Colors.green : Colors.blue),
                const SizedBox(width: 8),
                Text(_locationSource == "NAVIC" ? "NAVIC System" : "GPS System",
                    style: TextStyle(fontWeight: FontWeight.bold, color: _locationSource == "NAVIC" ? Colors.green : Colors.blue)),
                const SizedBox(width: 12),
                Text("Confidence: ${(pos.confidenceScore * 100).toStringAsFixed(0)}%", style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildInfoCard(icon: Icons.explore, title: "Latitude", value: pos.position.latitude.toStringAsFixed(6), color: Colors.blue.shade50, iconColor: Colors.blue.shade700)),
                const SizedBox(width: 12),
                Expanded(child: _buildInfoCard(icon: Icons.explore_outlined, title: "Longitude", value: pos.position.longitude.toStringAsFixed(6), color: Colors.green.shade50, iconColor: Colors.green.shade700)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildInfoCard(icon: Icons.location_on, title: "Accuracy", value: "${pos.position.accuracy?.toStringAsFixed(1) ?? 'N/A'} m", color: Colors.orange.shade50, iconColor: Colors.orange.shade700)),
                const SizedBox(width: 12),
                Expanded(child: _buildInfoCard(icon: Icons.analytics, title: "Quality", value: _locationQuality, color: _getQualityColor().withOpacity(0.1), iconColor: _getQualityColor())),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_isNavicActive ? "NavIC Active" : _isNavicSupported ? "NavIC Ready" : "GPS Only",
                      style: TextStyle(fontWeight: FontWeight.bold, color: _isNavicActive ? Colors.green : _isNavicSupported ? Colors.blue : Colors.orange)),
                  const SizedBox(height: 6),
                  Text(_hardwareMessage, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 3),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHardwareSupportBanner() {
    Color bannerColor = Colors.orange.shade50;
    Color iconColor = Colors.orange;
    IconData icon = Icons.warning;

    if (_isNavicActive) {
      bannerColor = Colors.green.shade50;
      iconColor = Colors.green;
      icon = Icons.satellite_alt;
    } else if (_isNavicSupported) {
      bannerColor = Colors.blue.shade50;
      iconColor = Colors.blue;
      icon = Icons.search;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: bannerColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(_hardwareMessage, style: TextStyle(color: iconColor, fontSize: 12, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NAVIC'),
        backgroundColor: Colors.greenAccent.shade700,
        actions: [
          IconButton(icon: Icon(_isLoading ? Icons.refresh : Icons.refresh_outlined), onPressed: _refreshLocation),
          IconButton(icon: const Icon(Icons.layers), onPressed: _toggleLayerSelection),
          if (_currentEnhancedPosition != null)
            IconButton(
              icon: const Icon(Icons.emergency_share_sharp),
              iconSize: 30,
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => EmergencyPage())),
            ),
        ],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : Stack(
        children: [
          _buildMap(),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildEnhancedInfoPanel()),
          if (_showLayerSelection) Positioned(top: 16, right: 16, child: _buildLayerSelectionPanel()),
          if (_isHardwareChecked) Positioned(top: 16, left: 16, right: 16, child: _buildHardwareSupportBanner()),
        ],
      ),
    );
  }

  Widget _buildLayerSelectionPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _selectedLayers.keys.map((name) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(value: _selectedLayers[name], onChanged: (_) => _toggleLayer(name)),
            Text(name),
          ],
        )).toList(),
      ),
    );
  }

  @override
  void dispose() {
    _locationService.dispose();
    super.dispose();
  }
}