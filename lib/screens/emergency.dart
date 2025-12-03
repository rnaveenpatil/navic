import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import '../services/location_service.dart';
import 'package:geolocator/geolocator.dart';

class EmergencyPage extends StatefulWidget {
  const EmergencyPage({super.key});

  @override
  State<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> {
  final LocationService _locationService = LocationService();
  bool _isLoading = false;
  String _currentStatus = "Ready";
  bool _isLiveTracking = false;
  Timer? _locationUpdateTimer;
  EnhancedPosition? _lastPosition;
  int _navicSatelliteCount = 0;
  String _locationSource = "GPS";
  bool _isNavicHardwareSupported = false;
  bool _isNavicActive = false;
  Map<String, dynamic> _satelliteInfo = {};

  @override
  void initState() {
    super.initState();
    _initializeLocationService();
  }

  void _initializeLocationService() async {
    // Initialize location service which includes hardware detection
    await _locationService.startRealTimeMonitoring();

    // Get initial hardware status
    final serviceStats = _locationService.getServiceStats();
    setState(() {
      _isNavicHardwareSupported = serviceStats['navicSupported'] as bool? ?? false;
      _isNavicActive = serviceStats['navicActive'] as bool? ?? false;
    });
  }

  // ---------------- Permission Helper ----------------
  Future<bool> _checkAndRequestLocationPermission() async {
    try {
      // Check location services
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError("Location services are disabled. Please enable location services.");
        return false;
      }

      // Check current permission
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.deniedForever) {
        _showError("Location permission denied forever. Please enable in app settings.");
        return false;
      }

      if (permission == LocationPermission.denied) {
        // Request permission
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          _showError("Location permission denied. Emergency features require location access.");
          return false;
        }
      }

      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      _showError("Permission error: $e");
      return false;
    }
  }

  // ---------------- Helper: Get location safely ----------------
  Future<EnhancedPosition?> _getEnhancedLocation() async {
    // Check permissions first
    final hasPermission = await _checkAndRequestLocationPermission();
    if (!hasPermission) {
      return null;
    }

    setState(() {
      _isLoading = true;
      _currentStatus = "Acquiring Location...";
    });

    try {
      EnhancedPosition? enhancedPos = await _locationService.getCurrentLocation();

      if (enhancedPos == null) {
        _showError("Unable to fetch current location!");
        return null;
      }

      // Update hardware status from new position
      final serviceStats = _locationService.getServiceStats();

      setState(() {
        _currentStatus = "Location Acquired";
        _lastPosition = enhancedPos;
        _locationSource = enhancedPos.locationSource;
        _navicSatelliteCount = enhancedPos.navicSatellites ?? 0;
        _satelliteInfo = enhancedPos.satelliteInfo;
        _isNavicActive = enhancedPos.isNavicEnhanced;
        _isNavicHardwareSupported = serviceStats['navicSupported'] as bool? ?? false;
      });

      return enhancedPos;
    } catch (e) {
      _showError("Location error: $e");
      return null;
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
    setState(() {
      _currentStatus = "Error: $message";
    });
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ---------------- 1️⃣ Call Emergency Number ----------------
  Future<void> callEmergencyNumber() async {
    const number = "tel:112"; // India emergency number

    try {
      if (await canLaunchUrl(Uri.parse(number))) {
        await launchUrl(Uri.parse(number));
      } else {
        _showError("Failed to make call");
      }
    } catch (e) {
      _showError("Call error: $e");
    }
  }

  // ---------------- 2️⃣ Share Current Location ----------------
  Future<void> shareLocation() async {
    EnhancedPosition? enhancedPos = await _getEnhancedLocation();
    if (enhancedPos == null) return;

    _shareLocationMessage(enhancedPos, "CURRENT LOCATION");
    _showSuccess("Location shared successfully!");
  }

  // ---------------- 3️⃣ Live Location Tracking ----------------
  Future<void> startLiveLocationSharing() async {
    if (_isLiveTracking) {
      _stopLiveTracking();
      setState(() {
        _currentStatus = "Live Tracking Stopped";
      });
      _showSuccess("Live tracking stopped");
      return;
    }

    // Check permissions first
    final hasPermission = await _checkAndRequestLocationPermission();
    if (!hasPermission) return;

    setState(() {
      _isLoading = true;
      _currentStatus = "Starting Live Location Sharing...";
    });

    try {
      // Get initial position
      EnhancedPosition? initialPos = await _locationService.getCurrentLocation();
      if (initialPos == null) return;

      _lastPosition = initialPos;

      // Start real-time satellite monitoring
      await _locationService.startRealTimeMonitoring();

      // Start periodic location updates
      _startPeriodicLocationUpdates();

      // Update hardware status
      final serviceStats = _locationService.getServiceStats();

      setState(() {
        _isLiveTracking = true;
        _isLoading = false;
        _currentStatus = "Live Sharing Active - Share the link!";
        _locationSource = initialPos.locationSource;
        _navicSatelliteCount = initialPos.navicSatellites ?? 0;
        _isNavicActive = initialPos.isNavicEnhanced;
        _isNavicHardwareSupported = serviceStats['navicSupported'] as bool? ?? false;
      });

      // Create and share the live tracking message
      String liveShareMessage = _createLiveShareMessage(initialPos);
      Share.share(liveShareMessage);

      _showSuccess("Live tracking started!");

    } catch (e) {
      setState(() {
        _isLoading = false;
        _currentStatus = "Failed to start live tracking";
      });
      _showError("Live tracking error: $e");
    }
  }

  void _startPeriodicLocationUpdates() {
    // Update location every 30 seconds
    _locationUpdateTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
      if (!_isLiveTracking) {
        timer.cancel();
        return;
      }

      try {
        EnhancedPosition? newPos = await _locationService.getCurrentLocation();
        if (newPos != null) {
          // Update hardware status
          final serviceStats = _locationService.getServiceStats();

          setState(() {
            _lastPosition = newPos;
            _locationSource = newPos.locationSource;
            _navicSatelliteCount = newPos.navicSatellites ?? 0;
            _satelliteInfo = newPos.satelliteInfo;
            _isNavicActive = newPos.isNavicEnhanced;
            _isNavicHardwareSupported = serviceStats['navicSupported'] as bool? ?? false;
            _currentStatus = "Live Tracking - ${DateTime.now().toString().split('.').first}";
          });
        }
      } catch (e) {
        print("Periodic update error: $e");
      }
    });
  }

  void _stopLiveTracking() {
    _locationUpdateTimer?.cancel();
    _locationService.stopRealTimeMonitoring();
    setState(() {
      _isLiveTracking = false;
    });
  }

  // ---------------- 4️⃣ Send Location Update ----------------
  Future<void> sendLocationUpdate() async {
    if (_lastPosition == null) {
      EnhancedPosition? currentPos = await _getEnhancedLocation();
      if (currentPos == null) return;
      _lastPosition = currentPos;
    }

    _shareLocationMessage(_lastPosition!, "LOCATION UPDATE");

    setState(() {
      _currentStatus = "Location Update Sent - ${DateTime.now().toString().split('.').first}";
    });

    _showSuccess("Location update sent!");
  }

  // ---------------- 5️⃣ Send Emergency SMS ----------------
  Future<void> sendEmergencySMS() async {
    EnhancedPosition? enhancedPos = await _getEnhancedLocation();
    if (enhancedPos == null) return;

    String message = _createEmergencyMessage(enhancedPos, "EMERGENCY");
    final smsUrl = Uri.parse("sms:?body=${Uri.encodeComponent(message)}");

    try {
      if (await canLaunchUrl(smsUrl)) {
        await launchUrl(smsUrl);
      } else {
        _showError("Failed to open SMS app");
      }
    } catch (e) {
      _showError("SMS error: $e");
    }
  }

  // ---------------- Shared Message Creation Methods ----------------
  void _shareLocationMessage(EnhancedPosition enhancedPos, String type) {
    String message = _createLocationMessage(enhancedPos, type);
    Share.share(message);
  }

  String _createLocationMessage(EnhancedPosition enhancedPos, String type) {
    String googleMaps = "https://www.google.com/maps?q=${enhancedPos.latitude},${enhancedPos.longitude}";
    String openStreetMap = "https://www.openstreetmap.org/?mlat=${enhancedPos.latitude}&mlon=${enhancedPos.longitude}#map=18/${enhancedPos.latitude}/${enhancedPos.longitude}";

    String navicStatus = enhancedPos.isNavicEnhanced
        ? "🛰️ **NAVIC ENHANCED POSITIONING**\n"
        : "📍 **STANDARD GPS POSITIONING**\n";

    String satelliteInfo = _navicSatelliteCount > 0
        ? "• Active NavIC Satellites: $_navicSatelliteCount\n"
        : "• Using GPS Constellation\n";

    String hardwareStatus = _isNavicHardwareSupported
        ? "• Device: NavIC Hardware Supported\n"
        : "• Device: Standard GPS\n";

    String activeStatus = _isNavicActive
        ? "• Status: NavIC Active\n"
        : "• Status: GPS Active\n";

    return """🚨 $type 🚨

$navicStatus
📡 Location Source: ${enhancedPos.locationSource}
🎯 Accuracy: ${enhancedPos.accuracy.toStringAsFixed(1)} meters
🕒 Timestamp: ${DateTime.now().toString().split('.').first}
$hardwareStatus$activeStatus$satelliteInfo
📍 Coordinates:
   • Latitude: ${enhancedPos.latitude.toStringAsFixed(6)}
   • Longitude: ${enhancedPos.longitude.toStringAsFixed(6)}

🔗 **Google Maps:**
$googleMaps

🗺️ **OpenStreetMap:**
$openStreetMap

${type == "LIVE LOCATION TRACKING" ? "🔄 Live tracking active - location updates every 30 seconds\n" : ""}
⚠️ This is an emergency location share""";
  }

  String _createLiveShareMessage(EnhancedPosition enhancedPos) {
    return _createLocationMessage(enhancedPos, "LIVE LOCATION TRACKING");
  }

  String _createEmergencyMessage(EnhancedPosition enhancedPos, String type) {
    String googleMaps = "https://www.google.com/maps?q=${enhancedPos.latitude},${enhancedPos.longitude}";
    String openStreetMap = "https://www.openstreetmap.org/?mlat=${enhancedPos.latitude}&mlon=${enhancedPos.longitude}#map=18/${enhancedPos.latitude}/${enhancedPos.longitude}";

    String navicInfo = enhancedPos.isNavicEnhanced
        ? "• Positioning: NavIC Enhanced (${_navicSatelliteCount} satellites)\n"
        : "• Positioning: Standard GPS\n";

    String confidence = "• Confidence: ${(enhancedPos.confidenceScore * 100).toStringAsFixed(0)}%\n";

    return """EMERGENCY! Need assistance immediately!

My current location:
• Latitude: ${enhancedPos.latitude.toStringAsFixed(6)}
• Longitude: ${enhancedPos.longitude.toStringAsFixed(6)}
• Accuracy: ${enhancedPos.accuracy.toStringAsFixed(1)} meters
$navicInfo$confidence
Google Maps: $googleMaps
OpenStreetMap: $openStreetMap

Timestamp: ${DateTime.now().toString().split('.').first}

This is an automated emergency message.""";
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Emergency Assistance",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.red.shade50,
              Colors.orange.shade50,
            ],
          ),
        ),
        child: Column(
          children: [
            // Hardware & Location Status Card
            _buildStatusCard(),

            const SizedBox(height: 16),

            // Status Indicator
            _buildStatusIndicator(),

            const SizedBox(height: 24),

            // Emergency Buttons
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // 1️⃣ Call Emergency Number
                    _buildEmergencyButton(
                      icon: Icons.emergency,
                      title: "CALL EMERGENCY NUMBER",
                      subtitle: "Direct call to emergency services",
                      color: Colors.red.shade700,
                      onPressed: callEmergencyNumber,
                    ),

                    const SizedBox(height: 16),

                    // 2️⃣ Share Current Location
                    _buildEmergencyButton(
                      icon: Icons.share_location,
                      title: "SHARE CURRENT LOCATION",
                      subtitle: "Share your precise location instantly",
                      color: Colors.blue.shade700,
                      onPressed: shareLocation,
                    ),

                    const SizedBox(height: 16),

                    // 3️⃣ Live Location Tracking
                    _buildEmergencyButton(
                      icon: _isLiveTracking ? Icons.location_off : Icons.location_searching,
                      title: _isLiveTracking ? "STOP LIVE TRACKING" : "START LIVE TRACKING",
                      subtitle: _isLiveTracking ? "Stop sharing live location" : "Share live location updates",
                      color: _isLiveTracking ? Colors.orange.shade700 : Colors.green.shade700,
                      onPressed: startLiveLocationSharing,
                    ),

                    const SizedBox(height: 16),

                    // 4️⃣ Send Location Update (only when live tracking)
                    if (_isLiveTracking)
                      Column(
                        children: [
                          _buildEmergencyButton(
                            icon: Icons.update,
                            title: "SEND LOCATION UPDATE",
                            subtitle: "Send immediate location update",
                            color: Colors.purple.shade700,
                            onPressed: sendLocationUpdate,
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),

                    // 5️⃣ Send Emergency SMS
                    _buildEmergencyButton(
                      icon: Icons.sms,
                      title: "SEND EMERGENCY SMS",
                      subtitle: "Send location via SMS to contacts",
                      color: Colors.orange.shade700,
                      onPressed: sendEmergencySMS,
                    ),

                    const SizedBox(height: 20),

                    // Satellite Information
                    if (_lastPosition != null && _satelliteInfo.isNotEmpty)
                      _buildSatelliteInfoCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Hardware Status
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isNavicHardwareSupported ? Icons.satellite_alt : Icons.gps_fixed,
                color: _isNavicHardwareSupported ? Colors.green : Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _isNavicHardwareSupported ? 'NavIC Hardware Supported' : 'Standard GPS Device',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _isNavicHardwareSupported ? Colors.green : Colors.blue,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Location Source
          if (_lastPosition != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _locationSource == "NAVIC" ? Colors.green.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _locationSource == "NAVIC" ? Colors.green.shade300 : Colors.blue.shade300,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _locationSource == "NAVIC" ? Icons.satellite_alt : Icons.gps_fixed,
                    color: _locationSource == "NAVIC" ? Colors.green.shade700 : Colors.blue.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _locationSource == "NAVIC" ? 'Using NavIC Positioning' : 'Using GPS Positioning',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _locationSource == "NAVIC" ? Colors.green.shade700 : Colors.blue.shade700,
                    ),
                  ),
                  if (_locationSource == "NAVIC" && _navicSatelliteCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        '($_navicSatelliteCount sats)',
                        style: TextStyle(
                          color: Colors.green.shade600,
                          fontSize: 12,
                        ),
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
    // Extract constellations from satellite info
    final systemStats = _satelliteInfo['systemStats'] as Map<String, dynamic>? ?? {};
    final constellations = <String, int>{};

    for (final entry in systemStats.entries) {
      if (entry.value is Map<String, dynamic>) {
        final systemData = entry.value as Map<String, dynamic>;
        final used = systemData['used'] as int? ?? 0;
        final total = systemData['total'] as int? ?? 0;
        if (total > 0) {
          constellations[entry.key] = used;
        }
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Satellite Information',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: constellations.entries.map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getConstellationColor(entry.key),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${entry.key}: ${entry.value}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color _getConstellationColor(String constellation) {
    switch (constellation) {
      case 'IRNSS':
        return Colors.green.shade600;
      case 'GPS':
        return Colors.blue.shade600;
      case 'GLONASS':
        return Colors.orange.shade600;
      case 'GALILEO':
        return Colors.purple.shade600;
      case 'BEIDOU':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getStatusColor()),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isLoading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor()),
              ),
            )
          else if (_isLiveTracking)
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            )
          else
            Icon(
              Icons.info,
              color: _getStatusColor(),
              size: 20,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _currentStatus,
              style: TextStyle(
                color: _getStatusColor(),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Row(
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    if (_isLoading) return Colors.orange;
    if (_isLiveTracking) return Colors.green;
    if (_currentStatus.contains("Error") || _currentStatus.contains("Failed")) {
      return Colors.red;
    }
    return Colors.blue;
  }

  @override
  void dispose() {
    _stopLiveTracking();
    _locationUpdateTimer?.cancel();
    super.dispose();
  }
}