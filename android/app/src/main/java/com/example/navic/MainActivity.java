package com.example.navic;

import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.location.GnssStatus;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "navic_support";
    private static final long SATELLITE_DETECTION_TIMEOUT_MS = 30000L;
    private static final long LOCATION_UPDATE_INTERVAL_MS = 1000L;
    private static final float LOCATION_UPDATE_DISTANCE_M = 0.5f;

    // Enhanced detection parameters
    private static final float MIN_NAVIC_SIGNAL_STRENGTH = 15.0f;
    private static final int MIN_NAVIC_SATELLITES_FOR_DETECTION = 1;
    private static final long EARLY_SUCCESS_DELAY_MS = 10000L;
    private static final int REQUIRED_CONSECUTIVE_DETECTIONS = 3;

    // Enhanced GNSS frequencies with L5 bands
    private static final Map<String, Double[]> GNSS_FREQUENCIES = new HashMap<String, Double[]>() {{
        put("GPS", new Double[]{1575.42, 1227.60, 1176.45}); // L1, L2, L5
        put("GLONASS", new Double[]{1602.00, 1246.00, 1202.025}); // G1, G2, G3
        put("GALILEO", new Double[]{1575.42, 1207.14, 1176.45}); // E1, E5, E5a
        put("BEIDOU", new Double[]{1561.098, 1207.14, 1176.45}); // B1, B2, B2a
        put("IRNSS", new Double[]{1176.45, 2492.028}); // L5, S-band
        put("QZSS", new Double[]{1575.42, 1227.60, 1176.45}); // L1, L2, L5
    }};

    // Enhanced country flags for GNSS systems
    private static final Map<String, String> GNSS_COUNTRIES = new HashMap<String, String>() {{
        put("GPS", "🇺🇸");
        put("GLONASS", "🇷🇺");
        put("GALILEO", "🇪🇺");
        put("BEIDOU", "🇨🇳");
        put("IRNSS", "🇮🇳");
        put("QZSS", "🇯🇵");
        put("SBAS", "🌍");
        put("UNKNOWN", "🌐");
    }};

    // Enhanced Qualcomm chipsets with NavIC + L5 support
    private static final Set<String> QUALCOMM_NAVIC_CHIPSETS = new HashSet<>(Arrays.asList(
            // Snapdragon 8 Gen 3 Series (Flagship)
            "sm8650", "8 gen 3", "sm8635", "8s gen 3",
            // Snapdragon 8 Gen 2 Series
            "sm8550", "8 gen 2", "sm8475", "8+ gen 1",
            // Snapdragon 8 Gen 1 Series
            "sm8450", "8 gen 1", "sm8350", "888", "sm8350", "888+",
            // Snapdragon 7+ Gen 3, 7 Gen 3, 7s Gen 3 (Premium Mid-range)
            "sm7550", "7+ gen 3", "sm7475", "7 gen 2", "sm7435", "7s gen 2",
            // Snapdragon 6 Gen 1 (Mid-range)
            "sm6450", "6 gen 1", "sm6375", "695", "sm6375", "695 5g",
            // Snapdragon 4 Gen 2 (Entry-level with NavIC)
            "sm4450", "4 gen 2", "sm4350", "480", "sm4350", "480+",
            // Older chipsets with confirmed NavIC support
            "sm8250", "865", "sm8250-ac", "870",
            "sm7250", "765", "765g", "768g", "sm7225", "750g", "750g 5g",
            "sm7150", "732g", "sm7125", "720g",
            "sm6115", "662", "sm4250", "460", "sm4250", "460 5g",
            // IoT/Auto
            "sa8775p", "sa8295p", "sa8155p", "qcx216", "qcs6490", "qcs6490 5g"
    ));

    // Enhanced MediaTek chipsets with NavIC + L5 support
    private static final Set<String> MEDIATEK_NAVIC_CHIPSETS = new HashSet<>(Arrays.asList(
            // Dimensity 9000 Series
            "mt6989", "9300+", "mt6989", "9300", "mt6985", "9200+", "mt6985", "9200",
            "mt6983", "9000+", "mt6983", "9000",
            // Dimensity 8000 Series
            "mt6897", "8300", "mt6896", "8200", "mt6895", "8100", "mt6895", "8000",
            "mt6889", "7200", "mt6885", "7050", "mt6883", "7030",
            // Dimensity 7000 Series
            "mt6879", "7020", "mt6877", "1080", "mt6877", "930", "mt6877", "920", "mt6877", "900",
            "mt6857", "6100+", "mt6835", "6020", "mt6833", "700",
            // Helio G Series with NavIC
            "mt6789", "g99", "mt6781", "g96", "mt6779", "g90t", "mt6771", "g90",
            // Older Dimensity
            "mt6893", "1300", "mt6893", "1200", "mt6891", "1100", "mt6875", "1000+",
            "mt6873", "1000l", "mt6853", "800u", "mt6853", "720", "mt6853", "700"
    ));

    // Enhanced Samsung Exynos chipsets
    private static final Set<String> SAMSUNG_NAVIC_CHIPSETS = new HashSet<>(Arrays.asList(
            "s5e9945", "2400", "s5e9845", "2200", "s5e9825", "2100", "s5e9820", "2100",
            "s5e8835", "1380", "s5e8825", "1280", "s5e8500", "1330", "s5e9815", "1080"
    ));

    // Enhanced Unisoc chipsets with NavIC
    private static final Set<String> UNISOC_NAVIC_CHIPSETS = new HashSet<>(Arrays.asList(
            "t820", "t770", "t760", "t750", "t740", "t720", "t710", "t618", "t612", "t610",
            "sc9863a", "sc9832e", "sc7731e", "sc9863a", "sc9832e"
    ));

    private LocationManager locationManager;
    private GnssStatus.Callback realtimeCallback;
    private LocationListener locationListener;
    private Handler handler;
    private boolean isTrackingLocation = false;
    private MethodChannel methodChannel;

    // Enhanced satellite tracking
    private final Map<String, EnhancedSatellite> detectedSatellites = new ConcurrentHashMap<>();
    private final Map<String, List<EnhancedSatellite>> satellitesBySystem = new ConcurrentHashMap<>();
    private final AtomicInteger consecutiveNavicDetections = new AtomicInteger(0);
    private final AtomicBoolean navicDetectionCompleted = new AtomicBoolean(false);
    private boolean hasL5BandSupport = false;
    private String detectedChipset = "UNKNOWN";
    private String chipsetVendor = "UNKNOWN";
    private double chipsetConfidence = 0.0;
    private double l5Confidence = 0.0;
    private String primaryPositioningSystem = "GPS";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        locationManager = (LocationManager) getSystemService(Context.LOCATION_SERVICE);
        handler = new Handler(Looper.getMainLooper());

        methodChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL);
        methodChannel.setMethodCallHandler((call, result) -> {
            Log.d("NavIC", "Method called: " + call.method);
            switch (call.method) {
                case "checkNavicHardware":
                    checkNavicHardwareSupport(result);
                    break;
                case "getGnssCapabilities":
                    getGnssCapabilities(result);
                    break;
                case "startRealTimeDetection":
                    startRealTimeNavicDetection(result);
                    break;
                case "stopRealTimeDetection":
                    stopRealTimeDetection(result);
                    break;
                case "checkLocationPermissions":
                    checkLocationPermissions(result);
                    break;
                case "requestLocationPermissions":
                    requestLocationPermissions(result);
                    break;
                case "startLocationUpdates":
                    startLocationUpdates(result);
                    break;
                case "stopLocationUpdates":
                    stopLocationUpdates(result);
                    break;
                case "getAllSatellites":
                    getAllSatellites(result);
                    break;

                // =============== NEW SATELLITE DETECTION METHODS ===============
                case "getAllSatellitesInRange":
                    getAllSatellitesInRange(result);
                    break;
                case "getGnssRangeStatistics":
                    getGnssRangeStatistics(result);
                    break;
                case "getDetailedSatelliteInfo":
                    getDetailedSatelliteInfo(result);
                    break;
                case "getCompleteSatelliteSummary":
                    getCompleteSatelliteSummary(result);
                    break;
                case "getSatelliteNames":
                    getSatelliteNames(result);
                    break;
                case "getConstellationDetails":
                    getConstellationDetails(result);
                    break;
                case "getSignalStrengthAnalysis":
                    getSignalStrengthAnalysis(result);
                    break;
                case "getElevationAzimuthData":
                    getElevationAzimuthData(result);
                    break;
                case "getCarrierFrequencyInfo":
                    getCarrierFrequencyInfo(result);
                    break;
                case "getEphemerisAlmanacStatus":
                    getEphemerisAlmanacStatus(result);
                    break;
                case "getSatelliteDetectionHistory":
                    getSatelliteDetectionHistory(result);
                    break;
                case "getGnssDiversityReport":
                    getGnssDiversityReport(result);
                    break;
                case "getRealTimeSatelliteStream":
                    getRealTimeSatelliteStream(result);
                    break;
                case "getSatelliteSignalQuality":
                    getSatelliteSignalQuality(result);
                    break;
                // =============== END NEW METHODS ===============

                case "openLocationSettings":
                    openLocationSettings(result);
                    break;
                case "isLocationEnabled":
                    isLocationEnabled(result);
                    break;
                case "getDeviceInfo":
                    getDeviceInfo(result);
                    break;
                default:
                    Log.w("NavIC", "Unknown method: " + call.method);
                    result.notImplemented();
            }
        });
    }

    // =============== NEW METHODS IMPLEMENTATION ===============

    /**
     * Get all satellites in range (real-time)
     */
    private void getAllSatellitesInRange(MethodChannel.Result result) {
        Log.d("NavIC", "📡 Getting all satellites in range");

        if (!hasLocationPermissions()) {
            result.error("PERMISSION_DENIED", "Location permissions required", null);
            return;
        }

        try {
            List<Map<String, Object>> satellitesInRange = new ArrayList<>();

            for (EnhancedSatellite sat : detectedSatellites.values()) {
                if (sat.cn0 > 0) { // Only include satellites with signal
                    satellitesInRange.add(sat.toEnhancedMap());
                }
            }

            Map<String, Object> response = new HashMap<>();
            response.put("satellites", satellitesInRange);
            response.put("count", satellitesInRange.size());
            response.put("timestamp", System.currentTimeMillis());

            result.success(response);

        } catch (Exception e) {
            Log.e("NavIC", "Error getting satellites in range", e);
            result.error("RANGE_ERROR", "Failed to get satellites in range", null);
        }
    }

    /**
     * Get GNSS range statistics
     */
    private void getGnssRangeStatistics(MethodChannel.Result result) {
        Log.d("NavIC", "📊 Getting GNSS range statistics");

        if (!hasLocationPermissions()) {
            result.error("PERMISSION_DENIED", "Location permissions required", null);
            return;
        }

        try {
            Map<String, Object> stats = new HashMap<>();

            int totalSatellites = detectedSatellites.size();
            int satellitesWithSignal = 0;
            int satellitesUsedInFix = 0;
            float totalSignalStrength = 0;

            Map<String, Integer> systemCounts = new HashMap<>();
            Map<String, Integer> systemUsedCounts = new HashMap<>();
            Map<String, Float> systemSignalTotals = new HashMap<>();
            Map<String, Integer> systemSignalCounts = new HashMap<>();

            for (EnhancedSatellite sat : detectedSatellites.values()) {
                String system = sat.systemName;

                // Update system counts
                systemCounts.put(system, systemCounts.getOrDefault(system, 0) + 1);

                if (sat.cn0 > 0) {
                    satellitesWithSignal++;
                    totalSignalStrength += sat.cn0;

                    // Update system signal stats
                    systemSignalTotals.put(system, systemSignalTotals.getOrDefault(system, 0f) + sat.cn0);
                    systemSignalCounts.put(system, systemSignalCounts.getOrDefault(system, 0) + 1);
                }

                if (sat.usedInFix) {
                    satellitesUsedInFix++;
                    systemUsedCounts.put(system, systemUsedCounts.getOrDefault(system, 0) + 1);
                }
            }

            // Calculate averages
            float averageSignal = satellitesWithSignal > 0 ? totalSignalStrength / satellitesWithSignal : 0;

            // Prepare system statistics
            Map<String, Object> systemStats = new HashMap<>();
            for (String system : systemCounts.keySet()) {
                Map<String, Object> sysStat = new HashMap<>();
                sysStat.put("count", systemCounts.get(system));
                sysStat.put("used", systemUsedCounts.getOrDefault(system, 0));
                sysStat.put("hasSignal", systemSignalCounts.getOrDefault(system, 0));

                if (systemSignalCounts.containsKey(system)) {
                    sysStat.put("averageSignal", systemSignalTotals.get(system) / systemSignalCounts.get(system));
                } else {
                    sysStat.put("averageSignal", 0);
                }

                systemStats.put(system, sysStat);
            }

            stats.put("totalSatellites", totalSatellites);
            stats.put("satellitesWithSignal", satellitesWithSignal);
            stats.put("satellitesUsedInFix", satellitesUsedInFix);
            stats.put("averageSignal", averageSignal);
            stats.put("systemStats", systemStats);
            stats.put("hasL5Band", hasL5BandSupport);
            stats.put("primarySystem", primaryPositioningSystem);
            stats.put("timestamp", System.currentTimeMillis());

            result.success(stats);

        } catch (Exception e) {
            Log.e("NavIC", "Error getting GNSS range statistics", e);
            result.error("STATISTICS_ERROR", "Failed to get GNSS range statistics", null);
        }
    }

    /**
     * Get detailed satellite information
     */
    private void getDetailedSatelliteInfo(MethodChannel.Result result) {
        Log.d("NavIC", "🔍 Getting detailed satellite information");

        if (!hasLocationPermissions()) {
            result.error("PERMISSION_DENIED", "Location permissions required", null);
            return;
        }

        try {
            List<Map<String, Object>> detailedInfo = new ArrayList<>();

            for (EnhancedSatellite sat : detectedSatellites.values()) {
                Map<String, Object> info = sat.toEnhancedMap();

                // Add additional detailed information
                info.put("satelliteName", getSatelliteName(sat.systemName, sat.svid));
                info.put("constellationDescription", getConstellationDescription(sat.constellation));
                info.put("frequencyDescription", getFrequencyDescription(sat.frequencyBand));
                info.put("positioningRole", getPositioningRole(sat.usedInFix, sat.cn0));
                info.put("healthStatus", getHealthStatus(sat.cn0, sat.hasEphemeris, sat.hasAlmanac));
                info.put("detectionAge", System.currentTimeMillis() - sat.detectionTime);

                detailedInfo.add(info);
            }

            Map<String, Object> response = new HashMap<>();
            response.put("satellites", detailedInfo);
            response.put("count", detailedInfo.size());
            response.put("timestamp", System.currentTimeMillis());

            result.success(response);

        } catch (Exception e) {
            Log.e("NavIC", "Error getting detailed satellite info", e);
            result.error("DETAILED_INFO_ERROR", "Failed to get detailed satellite info", null);
        }
    }

    // =============== ENHANCED PERMISSION METHODS ===============
    private void checkLocationPermissions(MethodChannel.Result result) {
        try {
            boolean hasFineLocation = ContextCompat.checkSelfPermission(
                    this, android.Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED;
            boolean hasCoarseLocation = ContextCompat.checkSelfPermission(
                    this, android.Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED;
            boolean hasBackgroundLocation = true;

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                hasBackgroundLocation = ContextCompat.checkSelfPermission(
                        this, android.Manifest.permission.ACCESS_BACKGROUND_LOCATION) == PackageManager.PERMISSION_GRANTED;
            }

            Map<String, Object> permissions = new HashMap<>();
            permissions.put("hasFineLocation", hasFineLocation);
            permissions.put("hasCoarseLocation", hasCoarseLocation);
            permissions.put("hasBackgroundLocation", hasBackgroundLocation);
            permissions.put("allPermissionsGranted", hasFineLocation && hasCoarseLocation);
            permissions.put("shouldShowRationale", shouldShowPermissionRationale());

            Log.d("NavIC", "Enhanced Permission check - Fine: " + hasFineLocation +
                    ", Coarse: " + hasCoarseLocation + ", Background: " + hasBackgroundLocation);
            result.success(permissions);
        } catch (Exception e) {
            Log.e("NavIC", "Error checking permissions", e);
            result.error("PERMISSION_ERROR", "Failed to check permissions", null);
        }
    }

    private boolean shouldShowPermissionRationale() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            return ActivityCompat.shouldShowRequestPermissionRationale(
                    this, android.Manifest.permission.ACCESS_FINE_LOCATION);
        }
        return false;
    }

    private void requestLocationPermissions(MethodChannel.Result result) {
        try {
            String[] permissions;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                permissions = new String[]{
                        android.Manifest.permission.ACCESS_FINE_LOCATION,
                        android.Manifest.permission.ACCESS_COARSE_LOCATION,
                        android.Manifest.permission.ACCESS_BACKGROUND_LOCATION
                };
            } else {
                permissions = new String[]{
                        android.Manifest.permission.ACCESS_FINE_LOCATION,
                        android.Manifest.permission.ACCESS_COARSE_LOCATION
                };
            }

            ActivityCompat.requestPermissions(this, permissions, 1001);

            Map<String, Object> response = new HashMap<>();
            response.put("requested", true);
            response.put("message", "Location permissions requested");
            result.success(response);
        } catch (Exception e) {
            Log.e("NavIC", "Error requesting permissions", e);
            result.error("PERMISSION_REQUEST_ERROR", "Failed to request permissions", null);
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions,
                                           @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);

        if (requestCode == 1001) {
            Map<String, Object> permissionResult = new HashMap<>();

            boolean granted = false;
            if (grantResults.length > 0) {
                granted = grantResults[0] == PackageManager.PERMISSION_GRANTED;
            }

            permissionResult.put("granted", granted);
            permissionResult.put("message", granted ? "Location permission granted" : "Location permission denied");

            // Send result back to Flutter
            try {
                handler.post(() -> {
                    methodChannel.invokeMethod("onPermissionResult", permissionResult);
                });
            } catch (Exception e) {
                Log.e("NavIC", "Error sending permission result", e);
            }
        }
    }

    private boolean hasLocationPermissions() {
        return ContextCompat.checkSelfPermission(
                this, android.Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
                ContextCompat.checkSelfPermission(
                        this, android.Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED;
    }

    // =============== ENHANCED HARDWARE DETECTION ===============
    private void checkNavicHardwareSupport(MethodChannel.Result result) {
        Log.d("NavIC", "🚀 Starting ENHANCED NavIC hardware detection with L5 verification");

        if (!hasLocationPermissions()) {
            result.error("PERMISSION_DENIED", "Location permissions required", null);
            return;
        }

        handler.post(() -> {
            // Step 1: ENHANCED Chipset detection with detailed analysis
            EnhancedHardwareDetectionResult hardwareResult = detectEnhancedNavicHardware();

            // Step 2: ADVANCED L5 Band Detection with multiple verification methods
            EnhancedL5BandResult l5Result = detectEnhancedL5BandSupport();

            // Step 3: Enhanced satellite detection with real-time monitoring
            detectEnhancedSatellites(hardwareResult, l5Result, (navicDetected, navicCount, totalSatellites,
                                                                usedInFixCount, signalStrength, satelliteDetails, acquisitionTime,
                                                                allSatellites, l5Enabled, primarySystem) -> {

                Map<String, Object> response = new HashMap<>();
                response.put("isSupported", hardwareResult.isSupported);
                response.put("isActive", navicDetected);
                response.put("detectionMethod", hardwareResult.detectionMethod);
                response.put("satelliteCount", navicCount);
                response.put("totalSatellites", totalSatellites);
                response.put("usedInFixCount", usedInFixCount);
                response.put("confidenceLevel", hardwareResult.confidenceLevel);
                response.put("averageSignalStrength", signalStrength);
                response.put("satelliteDetails", satelliteDetails);
                response.put("acquisitionTimeMs", acquisitionTime);
                response.put("chipsetType", hardwareResult.chipsetType);
                response.put("chipsetVendor", hardwareResult.chipsetVendor);
                response.put("chipsetModel", hardwareResult.chipsetModel);
                response.put("verificationMethods", hardwareResult.verificationMethods);
                response.put("hasL5Band", l5Enabled);
                response.put("l5BandInfo", l5Result.toMap());
                response.put("allSatellites", allSatellites);
                response.put("primarySystem", primarySystem);

                // Calculate enhanced positioning method
                String positioningMethod = determineEnhancedPositioningMethod(navicDetected, usedInFixCount, allSatellites, l5Enabled);
                response.put("positioningMethod", positioningMethod);

                String message = generateEnhancedDetectionMessage(hardwareResult, l5Result, navicDetected,
                        navicCount, usedInFixCount, signalStrength, acquisitionTime);
                response.put("message", message);

                Log.d("NavIC", "🎯 ENHANCED detection completed: " + message);
                result.success(response);
            });
        });
    }

    /**
     * ENHANCED Chipset Detection with detailed analysis
     */
    private EnhancedHardwareDetectionResult detectEnhancedNavicHardware() {
        Log.d("NavIC", "🔧 Starting ENHANCED chipset detection analysis");

        List<String> detectionMethods = new ArrayList<>();
        List<String> verificationMethods = new ArrayList<>();
        double confidenceScore = 0.0;
        int verificationCount = 0;
        String chipsetType = "UNKNOWN";
        String chipsetVendor = "UNKNOWN";
        String chipsetModel = "UNKNOWN";

        // Method 1: GNSS Capabilities API (Most reliable for Android R+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                Object gnssCaps = locationManager.getGnssCapabilities();
                if (gnssCaps != null) {
                    try {
                        Method hasIrnssMethod = gnssCaps.getClass().getMethod("hasIrnss");
                        Object ret = hasIrnssMethod.invoke(gnssCaps);
                        if (ret instanceof Boolean) {
                            boolean hasIrnss = (Boolean) ret;
                            if (hasIrnss) {
                                detectionMethods.add("GNSS_CAPABILITIES_API");
                                verificationMethods.add("API_IRNSS_FLAG_TRUE");
                                confidenceScore += 0.99;
                                verificationCount++;
                                chipsetType = "API_VERIFIED_IRNSS";
                                Log.d("NavIC", "✅ GNSS Capabilities API confirms NavIC support");
                            } else {
                                Log.d("NavIC", "❌ GNSS Capabilities API reports NO NavIC support");
                                confidenceScore -= 0.3;
                            }
                        }
                    } catch (NoSuchMethodException ns) {
                        Log.d("NavIC", "GnssCapabilities.hasIrnss() not available");
                    }

                    // Check for L5 capability
                    try {
                        Method hasL5Method = gnssCaps.getClass().getMethod("hasL5");
                        Object l5Ret = hasL5Method.invoke(gnssCaps);
                        if (l5Ret instanceof Boolean && (Boolean) l5Ret) {
                            verificationMethods.add("API_L5_CAPABLE");
                            Log.d("NavIC", "✅ GNSS Capabilities API confirms L5 support");
                        }
                    } catch (NoSuchMethodException ns) {
                        // L5 method not available
                    }
                }
            } catch (Exception e) {
                Log.e("NavIC", "Error accessing GnssCapabilities", e);
            }
        }

        // Method 2: ADVANCED Qualcomm Detection
        EnhancedChipsetResult qualcommResult = detectAdvancedQualcommChipset();
        if (qualcommResult.isSupported) {
            detectionMethods.add(qualcommResult.detectionMethod);
            verificationMethods.addAll(qualcommResult.verificationMethods);
            confidenceScore += qualcommResult.confidence;
            verificationCount++;
            chipsetType = "QUALCOMM_" + qualcommResult.chipsetSeries;
            chipsetVendor = "QUALCOMM";
            chipsetModel = qualcommResult.chipsetModel;
            Log.d("NavIC", "✅ Advanced Qualcomm detection: " + qualcommResult.detectionMethod);
        }

        // Method 3: ADVANCED MediaTek Detection
        EnhancedChipsetResult mediatekResult = detectAdvancedMediatekChipset();
        if (mediatekResult.isSupported) {
            detectionMethods.add(mediatekResult.detectionMethod);
            verificationMethods.addAll(mediatekResult.verificationMethods);
            confidenceScore += mediatekResult.confidence;
            verificationCount++;
            chipsetType = "MEDIATEK_" + mediatekResult.chipsetSeries;
            chipsetVendor = "MEDIATEK";
            chipsetModel = mediatekResult.chipsetModel;
            Log.d("NavIC", "✅ Advanced MediaTek detection: " + mediatekResult.detectionMethod);
        }

        // Method 4: ADVANCED Samsung Detection
        EnhancedChipsetResult samsungResult = detectAdvancedSamsungChipset();
        if (samsungResult.isSupported) {
            detectionMethods.add(samsungResult.detectionMethod);
            verificationMethods.addAll(samsungResult.verificationMethods);
            confidenceScore += samsungResult.confidence;
            verificationCount++;
            chipsetType = "SAMSUNG_" + samsungResult.chipsetSeries;
            chipsetVendor = "SAMSUNG";
            chipsetModel = samsungResult.chipsetModel;
            Log.d("NavIC", "✅ Advanced Samsung detection: " + samsungResult.detectionMethod);
        }

        // Method 5: ADVANCED Unisoc Detection
        EnhancedChipsetResult unisocResult = detectAdvancedUnisocChipset();
        if (unisocResult.isSupported) {
            detectionMethods.add(unisocResult.detectionMethod);
            verificationMethods.addAll(unisocResult.verificationMethods);
            confidenceScore += unisocResult.confidence;
            verificationCount++;
            chipsetType = "UNISOC_" + unisocResult.chipsetSeries;
            chipsetVendor = "UNISOC";
            chipsetModel = unisocResult.chipsetModel;
            Log.d("NavIC", "✅ Advanced Unisoc detection: " + unisocResult.detectionMethod);
        }

        // Method 6: COMPREHENSIVE System Properties Analysis
        EnhancedSystemPropertiesResult propsResult = checkEnhancedSystemProperties();
        if (propsResult.isSupported) {
            detectionMethods.add(propsResult.detectionMethod);
            verificationMethods.addAll(propsResult.verificationMethods);
            confidenceScore += propsResult.confidence;
            verificationCount++;
            if (chipsetType.equals("UNKNOWN")) {
                chipsetType = "SYSTEM_PROPERTY_INDICATED";
            }
        }

        // Method 7: Hardware Feature Detection
        EnhancedFeaturesResult featuresResult = checkEnhancedHardwareFeatures();
        if (featuresResult.isSupported) {
            detectionMethods.add(featuresResult.detectionMethod);
            verificationMethods.addAll(featuresResult.verificationMethods);
            confidenceScore += featuresResult.confidence;
            verificationCount++;
        }

        // Method 8: CPU Info Detection
        EnhancedCPUInfoResult cpuResult = analyzeCPUInfo();
        if (cpuResult.isSupported) {
            detectionMethods.add(cpuResult.detectionMethod);
            verificationMethods.addAll(cpuResult.verificationMethods);
            confidenceScore += cpuResult.confidence;
            verificationCount++;
            if (chipsetVendor.equals("UNKNOWN")) {
                chipsetVendor = cpuResult.vendor;
            }
            if (chipsetModel.equals("UNKNOWN")) {
                chipsetModel = cpuResult.model;
            }
        }

        // Calculate final confidence with weighted average
        double finalConfidence;
        if (verificationCount > 0) {
            finalConfidence = Math.max(0.0, Math.min(1.0, confidenceScore / verificationCount));
        } else {
            finalConfidence = 0.0;
        }

        // Boost confidence for API verification
        if (detectionMethods.contains("GNSS_CAPABILITIES_API")) {
            finalConfidence = Math.min(1.0, finalConfidence + 0.1);
        }

        boolean isSupported = finalConfidence >= 0.4;

        String methodString = detectionMethods.isEmpty() ? "NO_CHIPSET_EVIDENCE" :
                String.join("+", detectionMethods);

        detectedChipset = chipsetType;
        chipsetVendor = chipsetVendor;
        chipsetConfidence = finalConfidence;

        Log.d("NavIC", String.format(
                "🎯 ENHANCED Chipset Detection Result:\n" +
                        "  Supported: %s\n" +
                        "  Confidence: %.2f%%\n" +
                        "  Vendor: %s\n" +
                        "  Model: %s\n" +
                        "  Type: %s\n" +
                        "  Methods: %s\n" +
                        "  Verifications: %d",
                isSupported, finalConfidence * 100, chipsetVendor, chipsetModel, chipsetType,
                methodString, verificationMethods.size()
        ));

        return new EnhancedHardwareDetectionResult(
                isSupported,
                methodString,
                finalConfidence,
                verificationCount,
                chipsetType,
                chipsetVendor,
                chipsetModel,
                verificationMethods
        );
    }

    private EnhancedChipsetResult detectAdvancedQualcommChipset() {
        try {
            String boardPlatform = Build.BOARD.toLowerCase();
            String hardware = Build.HARDWARE.toLowerCase();
            String socModel = getSoCModel().toLowerCase();
            String device = Build.DEVICE.toLowerCase();

            Log.d("NavIC", "Advanced Qualcomm detection - Board: " + boardPlatform +
                    ", Hardware: " + hardware + ", SoC: " + socModel + ", Device: " + device);

            boolean isQualcomm = boardPlatform.matches(".*(msm|sdm|sm|qcs|qcm|sdw|qmd|qualcomm)[0-9].*") ||
                    hardware.matches(".*(qcom|qualcomm|sdm|sm|msm).*") ||
                    (socModel != null && socModel.matches(".*(msm|sdm|sm|qcs).*")) ||
                    device.matches(".*(qcom|qualcomm).*");

            if (!isQualcomm) {
                return new EnhancedChipsetResult(false, 0.0, "NOT_QUALCOMM", "", "UNKNOWN", new ArrayList<>());
            }

            Log.d("NavIC", "Qualcomm architecture detected, analyzing NavIC capability...");

            List<String> verificationMethods = new ArrayList<>();
            String chipsetModel = "UNKNOWN";
            String chipsetSeries = "GENERIC";

            // Check exact chipset matches
            for (String chipset : QUALCOMM_NAVIC_CHIPSETS) {
                if (boardPlatform.contains(chipset) || hardware.contains(chipset) ||
                        (socModel != null && socModel.contains(chipset)) || device.contains(chipset)) {
                    Log.d("NavIC", "✅ NavIC-supported Qualcomm chipset identified: " + chipset);
                    verificationMethods.add("EXACT_MATCH_" + chipset);
                    chipsetModel = chipset;

                    // Determine series
                    if (chipset.contains("8 gen") || chipset.contains("888") || chipset.contains("865")) {
                        chipsetSeries = "FLAGSHIP";
                    } else if (chipset.contains("7") || chipset.contains("78")) {
                        chipsetSeries = "HIGH_END";
                    } else if (chipset.contains("6") || chipset.contains("69")) {
                        chipsetSeries = "MID_RANGE";
                    } else if (chipset.contains("4")) {
                        chipsetSeries = "ENTRY_LEVEL";
                    }

                    return new EnhancedChipsetResult(true, 0.95, "QUALCOMM_EXACT_MATCH",
                            chipsetSeries, chipsetModel, verificationMethods);
                }
            }

            // Pattern matching for series
            if (boardPlatform.matches(".*sm8[0-9]{3}.*") || hardware.matches(".*sm8[0-9]{3}.*")) {
                verificationMethods.add("PATTERN_8_SERIES");
                chipsetSeries = "FLAGSHIP";
                Log.d("NavIC", "✅ Qualcomm Snapdragon 8 series - High NavIC probability");
                return new EnhancedChipsetResult(true, 0.90, "QUALCOMM_8_SERIES", chipsetSeries, "8_SERIES", verificationMethods);
            }
            if (boardPlatform.matches(".*sm7[0-9]{3}.*") || hardware.matches(".*sm7[0-9]{3}.*")) {
                verificationMethods.add("PATTERN_7_SERIES");
                chipsetSeries = "HIGH_END";
                Log.d("NavIC", "✅ Qualcomm Snapdragon 7 series - Medium NavIC probability");
                return new EnhancedChipsetResult(true, 0.80, "QUALCOMM_7_SERIES", chipsetSeries, "7_SERIES", verificationMethods);
            }
            if (boardPlatform.matches(".*sm6[0-9]{3}.*") || hardware.matches(".*sm6[0-9]{3}.*")) {
                verificationMethods.add("PATTERN_6_SERIES");
                chipsetSeries = "MID_RANGE";
                Log.d("NavIC", "✅ Qualcomm Snapdragon 6 series - Medium NavIC probability");
                return new EnhancedChipsetResult(true, 0.75, "QUALCOMM_6_SERIES", chipsetSeries, "6_SERIES", verificationMethods);
            }
            if (boardPlatform.matches(".*sm4[0-9]{3}.*") || hardware.matches(".*sm4[0-9]{3}.*")) {
                verificationMethods.add("PATTERN_4_SERIES");
                chipsetSeries = "ENTRY_LEVEL";
                Log.d("NavIC", "✅ Qualcomm Snapdragon 4 series - Low NavIC probability");
                return new EnhancedChipsetResult(true, 0.65, "QUALCOMM_4_SERIES", chipsetSeries, "4_SERIES", verificationMethods);
            }

            // Generic Qualcomm detection
            verificationMethods.add("GENERIC_QUALCOMM");
            Log.d("NavIC", "⚠️ Generic Qualcomm detected - Limited NavIC information");
            return new EnhancedChipsetResult(true, 0.45, "QUALCOMM_GENERIC", "GENERIC", "GENERIC", verificationMethods);

        } catch (Exception e) {
            Log.e("NavIC", "Error in advanced Qualcomm detection", e);
        }
        return new EnhancedChipsetResult(false, 0.0, "QUALCOMM_UNDETECTED", "", "UNKNOWN", new ArrayList<>());
    }

    private EnhancedChipsetResult detectAdvancedMediatekChipset() {
        try {
            String hardware = Build.HARDWARE.toLowerCase();
            String boardPlatform = Build.BOARD.toLowerCase();
            String socModel = getSoCModel().toLowerCase();
            String device = Build.DEVICE.toLowerCase();

            Log.d("NavIC", "Advanced MediaTek detection - Hardware: " + hardware +
                    ", Board: " + boardPlatform + ", SoC: " + socModel + ", Device: " + device);

            boolean isMediatek = hardware.matches(".*mt[0-9].*") ||
                    boardPlatform.matches(".*mt[0-9].*") ||
                    (socModel != null && socModel.matches(".*mt[0-9].*")) ||
                    device.matches(".*mt[0-9].*") ||
                    hardware.contains("mediatek") || boardPlatform.contains("mediatek");

            if (!isMediatek) {
                return new EnhancedChipsetResult(false, 0.0, "NOT_MEDIATEK", "", "UNKNOWN", new ArrayList<>());
            }

            Log.d("NavIC", "MediaTek architecture detected, analyzing NavIC capability...");

            List<String> verificationMethods = new ArrayList<>();
            String chipsetModel = "UNKNOWN";
            String chipsetSeries = "GENERIC";

            // Check exact chipset matches
            for (String chipset : MEDIATEK_NAVIC_CHIPSETS) {
                if (hardware.contains(chipset) || boardPlatform.contains(chipset) ||
                        (socModel != null && socModel.contains(chipset)) || device.contains(chipset)) {
                    Log.d("NavIC", "✅ NavIC-supported MediaTek chipset identified: " + chipset);
                    verificationMethods.add("EXACT_MATCH_" + chipset);
                    chipsetModel = chipset;

                    // Determine series
                    if (chipset.contains("9000") || chipset.contains("9200") || chipset.contains("9300")) {
                        chipsetSeries = "FLAGSHIP";
                    } else if (chipset.contains("8000") || chipset.contains("8200") || chipset.contains("8300")) {
                        chipsetSeries = "HIGH_END";
                    } else if (chipset.contains("700") || chipset.contains("720") || chipset.contains("1080")) {
                        chipsetSeries = "MID_RANGE";
                    } else if (chipset.contains("g")) {
                        chipsetSeries = "GAMING";
                    }

                    return new EnhancedChipsetResult(true, 0.92, "MEDIATEK_EXACT_MATCH",
                            chipsetSeries, chipsetModel, verificationMethods);
                }
            }

            // Pattern matching for series
            if (hardware.matches(".*mt69[0-9]{2}.*") || boardPlatform.matches(".*mt69[0-9]{2}.*")) {
                verificationMethods.add("PATTERN_9000_SERIES");
                chipsetSeries = "FLAGSHIP";
                Log.d("NavIC", "✅ MediaTek Dimensity 9000 series - High NavIC probability");
                return new EnhancedChipsetResult(true, 0.95, "MEDIATEK_DIMENSITY_9000", chipsetSeries, "DIMENSITY_9000", verificationMethods);
            }
            if (hardware.matches(".*mt68[0-9]{2}.*") || boardPlatform.matches(".*mt68[0-9]{2}.*")) {
                verificationMethods.add("PATTERN_8000_SERIES");
                chipsetSeries = "HIGH_END";
                Log.d("NavIC", "✅ MediaTek Dimensity 8000/7000 series - High NavIC probability");
                return new EnhancedChipsetResult(true, 0.88, "MEDIATEK_DIMENSITY_8000", chipsetSeries, "DIMENSITY_8000", verificationMethods);
            }
            if (hardware.matches(".*mt67[0-9]{2}.*") || boardPlatform.matches(".*mt67[0-9]{2}.*")) {
                verificationMethods.add("PATTERN_7000_SERIES");
                chipsetSeries = "MID_RANGE";
                Log.d("NavIC", "✅ MediaTek Dimensity/Helio series - Medium NavIC probability");
                return new EnhancedChipsetResult(true, 0.75, "MEDIATEK_DIMENSITY_HELIO", chipsetSeries, "DIMENSITY_HELIO", verificationMethods);
            }

            // Generic MediaTek detection
            verificationMethods.add("GENERIC_MEDIATEK");
            Log.d("NavIC", "⚠️ Generic MediaTek detected - Limited NavIC information");
            return new EnhancedChipsetResult(true, 0.35, "MEDIATEK_GENERIC", "GENERIC", "GENERIC", verificationMethods);

        } catch (Exception e) {
            Log.e("NavIC", "Error in advanced MediaTek detection", e);
        }
        return new EnhancedChipsetResult(false, 0.0, "MEDIATEK_UNDETECTED", "", "UNKNOWN", new ArrayList<>());
    }

    private EnhancedChipsetResult detectAdvancedSamsungChipset() {
        try {
            String hardware = Build.HARDWARE.toLowerCase();
            String boardPlatform = Build.BOARD.toLowerCase();
            String socModel = getSoCModel().toLowerCase();

            Log.d("NavIC", "Advanced Samsung detection - Hardware: " + hardware +
                    ", Board: " + boardPlatform + ", SoC: " + socModel);

            boolean isSamsung = hardware.matches(".*(exynos|s5e)[0-9].*") ||
                    boardPlatform.matches(".*(exynos|s5e)[0-9].*") ||
                    (socModel != null && socModel.matches(".*(exynos|s5e)[0-9].*")) ||
                    Build.MANUFACTURER.equalsIgnoreCase("samsung");

            if (!isSamsung) {
                return new EnhancedChipsetResult(false, 0.0, "NOT_SAMSUNG", "", "UNKNOWN", new ArrayList<>());
            }

            Log.d("NavIC", "Samsung Exynos architecture detected, analyzing NavIC capability...");

            List<String> verificationMethods = new ArrayList<>();
            String chipsetModel = "UNKNOWN";
            String chipsetSeries = "GENERIC";

            // Check exact chipset matches
            for (String chipset : SAMSUNG_NAVIC_CHIPSETS) {
                if (hardware.contains(chipset) || boardPlatform.contains(chipset) ||
                        (socModel != null && socModel.contains(chipset))) {
                    Log.d("NavIC", "✅ NavIC-supported Samsung chipset identified: " + chipset);
                    verificationMethods.add("EXACT_MATCH_" + chipset);
                    chipsetModel = chipset;

                    // Determine series
                    if (chipset.contains("2400") || chipset.contains("2200") || chipset.contains("2100")) {
                        chipsetSeries = "FLAGSHIP";
                    } else if (chipset.contains("1380") || chipset.contains("1280")) {
                        chipsetSeries = "MID_RANGE";
                    }

                    return new EnhancedChipsetResult(true, 0.85, "SAMSUNG_EXACT_MATCH",
                            chipsetSeries, chipsetModel, verificationMethods);
                }
            }

            // Pattern matching
            if (hardware.matches(".*s5e9[0-9]{3}.*") || boardPlatform.matches(".*s5e9[0-9]{3}.*")) {
                verificationMethods.add("PATTERN_FLAGSHIP_SERIES");
                chipsetSeries = "FLAGSHIP";
                Log.d("NavIC", "✅ Samsung Exynos flagship series - High NavIC probability");
                return new EnhancedChipsetResult(true, 0.80, "SAMSUNG_FLAGSHIP", chipsetSeries, "FLAGSHIP", verificationMethods);
            }
            if (hardware.matches(".*s5e8[0-9]{3}.*") || boardPlatform.matches(".*s5e8[0-9]{3}.*")) {
                verificationMethods.add("PATTERN_MID_RANGE_SERIES");
                chipsetSeries = "MID_RANGE";
                Log.d("NavIC", "✅ Samsung Exynos mid-range series - Medium NavIC probability");
                return new EnhancedChipsetResult(true, 0.70, "SAMSUNG_MID_RANGE", chipsetSeries, "MID_RANGE", verificationMethods);
            }

            // Generic Samsung detection
            verificationMethods.add("GENERIC_SAMSUNG");
            Log.d("NavIC", "⚠️ Generic Samsung Exynos detected - Limited NavIC information");
            return new EnhancedChipsetResult(true, 0.40, "SAMSUNG_GENERIC", "GENERIC", "GENERIC", verificationMethods);

        } catch (Exception e) {
            Log.e("NavIC", "Error in advanced Samsung detection", e);
        }
        return new EnhancedChipsetResult(false, 0.0, "SAMSUNG_UNDETECTED", "", "UNKNOWN", new ArrayList<>());
    }

    private EnhancedChipsetResult detectAdvancedUnisocChipset() {
        try {
            String hardware = Build.HARDWARE.toLowerCase();
            String boardPlatform = Build.BOARD.toLowerCase();
            String socModel = getSoCModel().toLowerCase();

            boolean isUnisoc = hardware.matches(".*(t[0-9]|sc[0-9]|unisoc|spreadtrum).*") ||
                    boardPlatform.matches(".*(t[0-9]|sc[0-9]|unisoc|spreadtrum).*") ||
                    (socModel != null && socModel.matches(".*(t[0-9]|sc[0-9]|unisoc|spreadtrum).*"));

            if (!isUnisoc) {
                return new EnhancedChipsetResult(false, 0.0, "NOT_UNISOC", "", "UNKNOWN", new ArrayList<>());
            }

            Log.d("NavIC", "Unisoc architecture detected, analyzing NavIC capability...");

            List<String> verificationMethods = new ArrayList<>();
            String chipsetModel = "UNKNOWN";
            String chipsetSeries = "GENERIC";

            // Check exact chipset matches
            for (String chipset : UNISOC_NAVIC_CHIPSETS) {
                if (hardware.contains(chipset) || boardPlatform.contains(chipset) ||
                        (socModel != null && socModel.contains(chipset))) {
                    Log.d("NavIC", "✅ NavIC-supported Unisoc chipset identified: " + chipset);
                    verificationMethods.add("EXACT_MATCH_" + chipset);
                    chipsetModel = chipset;

                    // Determine series
                    if (chipset.startsWith("t7") || chipset.startsWith("t8")) {
                        chipsetSeries = "MID_RANGE";
                    } else if (chipset.startsWith("t6")) {
                        chipsetSeries = "ENTRY_LEVEL";
                    } else if (chipset.startsWith("sc")) {
                        chipsetSeries = "LEGACY";
                    }

                    return new EnhancedChipsetResult(true, 0.70, "UNISOC_EXACT_MATCH",
                            chipsetSeries, chipsetModel, verificationMethods);
                }
            }

            // Generic Unisoc detection
            verificationMethods.add("GENERIC_UNISOC");
            Log.d("NavIC", "⚠️ Generic Unisoc detected - Limited NavIC information");
            return new EnhancedChipsetResult(true, 0.30, "UNISOC_GENERIC", "GENERIC", "GENERIC", verificationMethods);

        } catch (Exception e) {
            Log.e("NavIC", "Error in advanced Unisoc detection", e);
        }
        return new EnhancedChipsetResult(false, 0.0, "UNISOC_UNDETECTED", "", "UNKNOWN", new ArrayList<>());
    }

    private EnhancedSystemPropertiesResult checkEnhancedSystemProperties() {
        List<String> verificationMethods = new ArrayList<>();
        double confidence = 0.0;
        boolean isSupported = false;

        try {
            Class<?> systemPropsClass = Class.forName("android.os.SystemProperties");
            Method getMethod = systemPropsClass.getMethod("get", String.class, String.class);

            String[][] gnssProperties = {
                    {"ro.gnss.sv_status", "0.85"},
                    {"persist.vendor.radio.aosp_gnss", "0.80"},
                    {"persist.vendor.gnss.hardware", "0.88"},
                    {"ro.board.gnss", "0.75"},
                    {"ro.hardware.gnss", "0.75"},
                    {"ro.vendor.gnss.hardware", "0.82"},
                    {"vendor.gnss.hardware", "0.82"},
                    {"ro.gnss.hardware", "0.78"},
                    {"persist.sys.gps.lpp", "0.65"},
                    {"ro.gps.agps_protocol", "0.60"},
                    {"ro.gnss.irnss", "0.95"},  // Specific NavIC property
                    {"persist.vendor.gnss.irnss", "0.92"},
                    {"ro.hardware.gnss.irnss", "0.90"}
            };

            for (String[] prop : gnssProperties) {
                String value = (String) getMethod.invoke(null, prop[0], "");
                if (!value.isEmpty()) {
                    Log.d("NavIC", "System property " + prop[0] + " = " + value);
                    if (value.toLowerCase().contains("irnss") || value.toLowerCase().contains("navic")) {
                        isSupported = true;
                        confidence = Double.parseDouble(prop[1]);
                        verificationMethods.add("SYS_PROP_IRNSS_" + prop[0]);
                        Log.d("NavIC", "✅ NavIC support confirmed in system property: " + prop[0]);
                        break;
                    }
                }
            }

            // Check for GNSS features
            String[] featureProperties = {
                    "ro.hardware.gnss.features", "vendor.gnss.features",
                    "ro.gnss.features", "persist.vendor.gnss.features"
            };

            for (String prop : featureProperties) {
                String features = (String) getMethod.invoke(null, prop, "");
                if (features.toLowerCase().contains("irnss")) {
                    isSupported = true;
                    confidence = Math.max(confidence, 0.94);
                    verificationMethods.add("GNSS_FEATURES_IRNSS");
                    Log.d("NavIC", "✅ NavIC support in GNSS features: " + prop + " = " + features);
                    break;
                }
            }

            // Check for chipset-specific properties
            String[] chipsetProps = {
                    "ro.board.platform", "ro.chipset", "ro.hardware.chipset",
                    "vendor.chipset", "ro.soc.model"
            };

            for (String prop : chipsetProps) {
                String value = (String) getMethod.invoke(null, prop, "");
                if (!value.isEmpty() && (
                        value.toLowerCase().contains("qualcomm") ||
                                value.toLowerCase().contains("qcom") ||
                                value.toLowerCase().contains("mediatek") ||
                                value.toLowerCase().contains("mt") ||
                                value.toLowerCase().contains("exynos") ||
                                value.toLowerCase().contains("samsung"))) {
                    verificationMethods.add("CHIPSET_ID_" + prop);
                    Log.d("NavIC", "Chipset property found: " + prop + " = " + value);
                }
            }

        } catch (Exception e) {
            Log.d("NavIC", "System properties access limited");
        }

        return new EnhancedSystemPropertiesResult(isSupported, confidence,
                "SYSTEM_PROPERTY_ANALYSIS", verificationMethods);
    }

    private EnhancedFeaturesResult checkEnhancedHardwareFeatures() {
        List<String> verificationMethods = new ArrayList<>();
        double confidence = 0.0;
        boolean isSupported = false;

        try {
            PackageManager pm = getPackageManager();
            boolean hasGnssFeature = pm.hasSystemFeature(PackageManager.FEATURE_LOCATION_GPS);

            if (hasGnssFeature) {
                verificationMethods.add("FEATURE_LOCATION_GPS");
                confidence = 0.5;

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    boolean hasGnssMetadata = locationManager.hasProvider(LocationManager.GPS_PROVIDER);
                    if (hasGnssMetadata) {
                        verificationMethods.add("GPS_PROVIDER_AVAILABLE");
                        confidence = 0.65;

                        // Check for advanced GNSS capabilities
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            try {
                                Object gnssCaps = locationManager.getGnssCapabilities();
                                if (gnssCaps != null) {
                                    verificationMethods.add("GNSS_CAPABILITIES_AVAILABLE");
                                    confidence = 0.75;
                                    Log.d("NavIC", "✅ Advanced GNSS hardware features detected");
                                }
                            } catch (Exception e) {
                                // Ignore
                            }
                        }
                    }
                }
            }

            // Check for other location-related features
            if (pm.hasSystemFeature(PackageManager.FEATURE_LOCATION_NETWORK)) {
                verificationMethods.add("FEATURE_LOCATION_NETWORK");
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                if (pm.hasSystemFeature(PackageManager.FEATURE_LOCATION_GPS)) {
                    verificationMethods.add("FEATURE_GPS_ADVANCED");
                }
            }

            isSupported = confidence > 0.4;

        } catch (Exception e) {
            Log.e("NavIC", "Error checking GNSS features", e);
        }

        return new EnhancedFeaturesResult(isSupported, confidence, "HARDWARE_FEATURE_DETECTION", verificationMethods);
    }

    private EnhancedCPUInfoResult analyzeCPUInfo() {
        try {
            String hardware = Build.HARDWARE.toLowerCase();
            String board = Build.BOARD.toLowerCase();
            String manufacturer = Build.MANUFACTURER.toLowerCase();
            String model = Build.MODEL.toLowerCase();

            List<String> verificationMethods = new ArrayList<>();
            String vendor = "UNKNOWN";
            String cpuModel = "UNKNOWN";
            double confidence = 0.0;
            boolean isSupported = false;

            // Detect vendor
            if (hardware.contains("qcom") || hardware.contains("qualcomm") ||
                    board.contains("qcom") || board.contains("qualcomm")) {
                vendor = "QUALCOMM";
                verificationMethods.add("VENDOR_QUALCOMM");
                confidence = 0.7;
                isSupported = true;
            } else if (hardware.contains("mt") || hardware.contains("mediatek") ||
                    board.contains("mt") || board.contains("mediatek")) {
                vendor = "MEDIATEK";
                verificationMethods.add("VENDOR_MEDIATEK");
                confidence = 0.7;
                isSupported = true;
            } else if (hardware.contains("exynos") || hardware.contains("s5e") ||
                    board.contains("exynos") || board.contains("s5e") ||
                    manufacturer.contains("samsung")) {
                vendor = "SAMSUNG";
                verificationMethods.add("VENDOR_SAMSUNG");
                confidence = 0.6;
                isSupported = true;
            } else if (hardware.contains("t") || hardware.contains("sc") ||
                    hardware.contains("unisoc") || hardware.contains("spreadtrum")) {
                vendor = "UNISOC";
                verificationMethods.add("VENDOR_UNISOC");
                confidence = 0.5;
                isSupported = true;
            } else if (manufacturer.contains("google") && model.contains("pixel")) {
                vendor = "GOOGLE";
                verificationMethods.add("VENDOR_GOOGLE");
                confidence = 0.8;
                isSupported = true;
            }

            // Try to get CPU model from system properties
            try {
                Class<?> systemPropsClass = Class.forName("android.os.SystemProperties");
                Method getMethod = systemPropsClass.getMethod("get", String.class, String.class);

                String cpuProp = (String) getMethod.invoke(null, "ro.board.platform", "");
                if (!cpuProp.isEmpty()) {
                    cpuModel = cpuProp;
                    verificationMethods.add("CPU_MODEL_" + cpuProp);
                }
            } catch (Exception e) {
                // Ignore
            }

            return new EnhancedCPUInfoResult(isSupported, confidence, "CPU_INFO_ANALYSIS",
                    verificationMethods, vendor, cpuModel);

        } catch (Exception e) {
            Log.e("NavIC", "Error analyzing CPU info", e);
        }

        return new EnhancedCPUInfoResult(false, 0.0, "CPU_INFO_ERROR",
                new ArrayList<>(), "UNKNOWN", "UNKNOWN");
    }

    /**
     * ADVANCED L5 Band Detection with multiple verification layers
     */
    private EnhancedL5BandResult detectEnhancedL5BandSupport() {
        Log.d("NavIC", "📡 Starting ADVANCED L5 band detection");
        EnhancedL5BandResult result = new EnhancedL5BandResult();
        List<String> detectionMethods = new ArrayList<>();

        try {
            // Layer 1: GNSS Capabilities API (Android R+) - Most reliable
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                Object gnssCaps = locationManager.getGnssCapabilities();
                if (gnssCaps != null) {
                    try {
                        // Check L5 capability
                        Method hasL5Method = gnssCaps.getClass().getMethod("hasL5");
                        Object ret = hasL5Method.invoke(gnssCaps);
                        if (ret instanceof Boolean) {
                            boolean hasL5 = (Boolean) ret;
                            if (hasL5) {
                                result.hasL5Support = true;
                                detectionMethods.add("GNSS_CAPABILITIES_L5");
                                result.confidence = 0.98;
                                Log.d("NavIC", "✅ Layer 1: GNSS Capabilities API confirms L5 support");
                            } else {
                                Log.d("NavIC", "❌ Layer 1: GNSS Capabilities API reports NO L5 support");
                            }
                        }
                    } catch (NoSuchMethodException e) {
                        Log.d("NavIC", "GNSSCapabilities.hasL5() not available");
                    }

                    // Check for other frequency bands
                    try {
                        Method hasL1Method = gnssCaps.getClass().getMethod("hasL1");
                        Method hasL2Method = gnssCaps.getClass().getMethod("hasL2");
                        Object l1Ret = hasL1Method.invoke(gnssCaps);
                        Object l2Ret = hasL2Method.invoke(gnssCaps);

                        if (l1Ret instanceof Boolean && (Boolean) l1Ret) {
                            detectionMethods.add("GNSS_CAPABILITIES_L1");
                        }
                        if (l2Ret instanceof Boolean && (Boolean) l2Ret) {
                            detectionMethods.add("GNSS_CAPABILITIES_L2");
                        }
                    } catch (NoSuchMethodException e) {
                        // Other frequency methods not available
                    }
                }
            }

            // Layer 2: Advanced Chipset Analysis
            String chipsetInfo = getEnhancedChipsetInfo().toLowerCase();
            boolean chipsetIndicatesL5 = false;

            // Check for L5 indicators in chipset info
            String[] l5Indicators = {"l5", "dual", "multi", "dualband", "multiband", "band5", "e5", "b2a", "dual_freq", "multi_freq"};
            for (String indicator : l5Indicators) {
                if (chipsetInfo.contains(indicator)) {
                    chipsetIndicatesL5 = true;
                    detectionMethods.add("CHIPSET_INDICATOR_" + indicator.toUpperCase());
                    break;
                }
            }

            // Check for premium chipset series (more likely to have L5)
            String[] premiumSeries = {"8 gen", "888", "865", "855", "845", "dimensity 9", "dimensity 8",
                    "exynos 2", "exynos 1", "tiger", "kryo", "snapdragon 8", "snapdragon 7+"};
            for (String series : premiumSeries) {
                if (chipsetInfo.contains(series)) {
                    chipsetIndicatesL5 = true;
                    detectionMethods.add("CHIPSET_PREMIUM_" + series.replace(" ", "_").toUpperCase());
                    break;
                }
            }

            if (chipsetIndicatesL5) {
                result.hasL5Support = true;
                detectionMethods.add("CHIPSET_L5_ANALYSIS");
                result.confidence = Math.max(result.confidence, 0.88);
                Log.d("NavIC", "✅ Layer 2: Chipset analysis indicates L5 capability");
            }

            // Layer 3: Comprehensive System Properties
            try {
                Class<?> systemPropsClass = Class.forName("android.os.SystemProperties");
                Method getMethod = systemPropsClass.getMethod("get", String.class, String.class);

                // Enhanced L5 property checking
                String[][] l5Properties = {
                        {"ro.gnss.l5.support", "0.96"},
                        {"persist.vendor.gnss.l5", "0.94"},
                        {"ro.hardware.gnss.l5", "0.92"},
                        {"vendor.gnss.l5.enabled", "0.90"},
                        {"ro.gnss.dual_frequency", "0.88"},
                        {"persist.vendor.gnss.dual_freq", "0.86"},
                        {"ro.gnss.multi_band", "0.84"},
                        {"vendor.gnss.multi_freq", "0.82"},
                        {"ro.gnss.dualband", "0.80"},
                        {"persist.sys.gps.dual_freq", "0.78"}
                };

                for (String[] prop : l5Properties) {
                    String value = (String) getMethod.invoke(null, prop[0], "");
                    if (!value.isEmpty()) {
                        if (value.equalsIgnoreCase("true") || value.equals("1") ||
                                value.toLowerCase().contains("enable") || value.toLowerCase().contains("yes") ||
                                value.toLowerCase().contains("supported")) {
                            result.hasL5Support = true;
                            detectionMethods.add("SYS_PROP_" + prop[0].replace(".", "_").toUpperCase());
                            double propConfidence = Double.parseDouble(prop[1]);
                            result.confidence = Math.max(result.confidence, propConfidence);
                            Log.d("NavIC", "✅ Layer 3: System property confirms L5: " + prop[0] + "=" + value);
                            break;
                        }
                    }
                }
            } catch (Exception e) {
                Log.d("NavIC", "Could not access system properties for L5 detection");
            }

            // Layer 4: Hardware Feature Detection
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                PackageManager pm = getPackageManager();
                if (pm.hasSystemFeature(PackageManager.FEATURE_LOCATION_GPS)) {
                    // Check for advanced GNSS features using reflection
                    try {
                        // Try to get GNSS hardware features from LocationManager
                        Field[] fields = LocationManager.class.getDeclaredFields();
                        for (Field field : fields) {
                            String fieldName = field.getName().toLowerCase();
                            if (fieldName.contains("feature") || fieldName.contains("capability") ||
                                    fieldName.contains("support") || fieldName.contains("band")) {
                                field.setAccessible(true);
                                try {
                                    Object value = field.get(locationManager);
                                    if (value != null) {
                                        String valueStr = value.toString().toLowerCase();
                                        if (valueStr.contains("l5") || valueStr.contains("dual") ||
                                                valueStr.contains("multi") || valueStr.contains("band5")) {
                                            result.hasL5Support = true;
                                            detectionMethods.add("HARDWARE_FEATURE_" + field.getName().toUpperCase());
                                            result.confidence = Math.max(result.confidence, 0.90);
                                            Log.d("NavIC", "✅ Layer 4: Hardware feature indicates L5: " + field.getName());
                                            break;
                                        }
                                    }
                                } catch (Exception e) {
                                    // Ignore individual field access errors
                                }
                            }
                        }
                    } catch (Exception e) {
                        Log.d("NavIC", "Reflection-based hardware feature detection failed");
                    }
                }
            }

            // Layer 5: Build Properties Analysis
            String[] buildProps = {Build.BOARD, Build.HARDWARE, Build.DEVICE, Build.PRODUCT, Build.MODEL};
            for (String prop : buildProps) {
                if (prop != null) {
                    String propLower = prop.toLowerCase();
                    if (propLower.contains("_l5") || propLower.contains("dual") ||
                            propLower.contains("multi") || propLower.contains("df") ||
                            propLower.contains("dualband") || propLower.contains("multiband")) {
                        result.hasL5Support = true;
                        detectionMethods.add("BUILD_PROP_" + prop.replace(" ", "_").toUpperCase());
                        result.confidence = Math.max(result.confidence, 0.78);
                        Log.d("NavIC", "✅ Layer 5: Build property indicates L5: " + prop);
                        break;
                    }
                }
            }

            // Layer 6: Manufacturer and Model Analysis
            String manufacturer = Build.MANUFACTURER.toLowerCase();
            String model = Build.MODEL.toLowerCase();

            // Known devices with L5 support
            String[] knownL5Devices = {
                    "pixel", "oneplus", "samsung galaxy s2", "samsung galaxy s23",
                    "xiaomi 13", "xiaomi 14", "realme gt", "oppo find", "vivo x",
                    "motorola edge", "nothing phone", "asus rog", "asus zenfone"
            };

            for (String device : knownL5Devices) {
                if (model.contains(device) || manufacturer.contains(device.split(" ")[0])) {
                    result.hasL5Support = true;
                    detectionMethods.add("KNOWN_DEVICE_" + device.replace(" ", "_").toUpperCase());
                    result.confidence = Math.max(result.confidence, 0.85);
                    Log.d("NavIC", "✅ Layer 6: Known device with L5 support: " + device);
                    break;
                }
            }

            // Final confidence calculation with method count weighting
            if (!detectionMethods.isEmpty()) {
                double methodBonus = Math.min(0.20, detectionMethods.size() * 0.03);
                result.confidence = Math.min(1.0, result.confidence + methodBonus);

                // Additional confidence for multiple verification methods
                if (detectionMethods.size() >= 3) {
                    result.confidence = Math.min(1.0, result.confidence + 0.05);
                }
            }

            // Set final result
            hasL5BandSupport = result.hasL5Support;
            l5Confidence = result.confidence;
            result.detectionMethods = detectionMethods;

            Log.d("NavIC", String.format(
                    "📡 ADVANCED L5 Detection Result:\n" +
                            "  Supported: %s\n" +
                            "  Confidence: %.2f%%\n" +
                            "  Methods: %s\n" +
                            "  Method Count: %d",
                    result.hasL5Support, result.confidence * 100,
                    String.join(", ", detectionMethods), detectionMethods.size()
            ));

        } catch (Exception e) {
            Log.e("NavIC", "❌ Error in advanced L5 band detection", e);
        }

        return result;
    }

    private String getEnhancedChipsetInfo() {
        StringBuilder chipsetInfo = new StringBuilder();

        try {
            Class<?> systemPropsClass = Class.forName("android.os.SystemProperties");
            Method getMethod = systemPropsClass.getMethod("get", String.class, String.class);

            String[] chipsetProps = {
                    "ro.board.platform",
                    "ro.hardware",
                    "ro.mediatek.platform",
                    "ro.chipset",
                    "vendor.gnss.chipset",
                    "ro.soc.model",
                    "ro.soc.manufacturer",
                    "ro.product.board",
                    "ro.product.platform"
            };

            for (String prop : chipsetProps) {
                String value = (String) getMethod.invoke(null, prop, "");
                if (!value.isEmpty()) {
                    chipsetInfo.append(value).append(" ");
                }
            }
        } catch (Exception e) {
            Log.d("NavIC", "Could not access enhanced chipset info");
        }

        String result = chipsetInfo.toString().trim();
        if (result.isEmpty()) {
            result = Build.HARDWARE + " " + Build.BOARD + " " + Build.DEVICE;
        }

        return result.toLowerCase();
    }

    /**
     * ENHANCED Satellite Detection with detailed information
     */
    private void detectEnhancedSatellites(EnhancedHardwareDetectionResult hardwareResult,
                                          EnhancedL5BandResult l5Result,
                                          EnhancedSatelliteDetectionCallback cb) {
        // Reset detection state
        detectedSatellites.clear();
        satellitesBySystem.clear();
        consecutiveNavicDetections.set(0);
        navicDetectionCompleted.set(false);

        final long startTime = System.currentTimeMillis();
        final AtomicInteger detectionAttempts = new AtomicInteger(0);
        final AtomicInteger totalSatellitesDetected = new AtomicInteger(0);

        Log.d("NavIC", "🛰️ Starting ENHANCED satellite detection (Timeout: " +
                SATELLITE_DETECTION_TIMEOUT_MS/1000 + "s)");

        try {
            final GnssStatus.Callback[] callbackRef = new GnssStatus.Callback[1];
            callbackRef[0] = new GnssStatus.Callback() {
                @Override
                public void onSatelliteStatusChanged(GnssStatus status) {
                    if (navicDetectionCompleted.get()) return;

                    detectionAttempts.incrementAndGet();
                    long currentTime = System.currentTimeMillis();
                    long elapsedTime = currentTime - startTime;

                    // Process ALL satellites with ENHANCED information
                    EnhancedSatelliteScanResult scanResult = processEnhancedSatellites(status, elapsedTime, l5Result.hasL5Support);

                    // Update global tracking
                    totalSatellitesDetected.set(scanResult.totalSatellites);
                    updateSatelliteTracking(scanResult);

                    // Enhanced NavIC detection logic
                    if (scanResult.navicCount >= MIN_NAVIC_SATELLITES_FOR_DETECTION) {
                        int currentConsecutive = consecutiveNavicDetections.incrementAndGet();

                        // Strong signal quick detection
                        if (scanResult.navicCount >= 3 && scanResult.navicSignalStrength > 28.0f) {
                            Log.d("NavIC", "🎯 STRONG NavIC signal detected - quick success");
                            completeEnhancedDetection(true, scanResult, elapsedTime, cb, callbackRef[0]);
                            return;
                        }

                        // Consecutive detection success
                        if (currentConsecutive >= REQUIRED_CONSECUTIVE_DETECTIONS) {
                            Log.d("NavIC", "✅ Consecutive NavIC detections reached");
                            completeEnhancedDetection(true, scanResult, elapsedTime, cb, callbackRef[0]);
                            return;
                        }
                    } else {
                        consecutiveNavicDetections.set(0); // Reset counter
                    }

                    // Log detailed progress
                    if (detectionAttempts.get() % 3 == 0 || scanResult.navicCount > 0) {
                        logEnhancedSatelliteStatus(scanResult, elapsedTime, detectionAttempts.get());
                    }

                    // Timeout condition
                    if (elapsedTime >= SATELLITE_DETECTION_TIMEOUT_MS) {
                        EnhancedSatelliteScanResult finalResult = getCurrentEnhancedScanResult(l5Result.hasL5Support);
                        boolean detected = finalResult.navicCount > 0;
                        Log.d("NavIC", "⏰ Detection timeout - NavIC detected: " + detected);
                        completeEnhancedDetection(detected, finalResult, elapsedTime, cb, callbackRef[0]);
                    }
                }

                @Override
                public void onStarted() {
                    Log.d("NavIC", "🛰️ ENHANCED GNSS monitoring started");
                }

                @Override
                public void onStopped() {
                    Log.d("NavIC", "🛰️ ENHANCED GNSS monitoring stopped");
                }
            };

            locationManager.registerGnssStatusCallback(callbackRef[0], handler);

            // Early success timer for strong signals
            handler.postDelayed(() -> {
                if (!navicDetectionCompleted.get()) {
                    EnhancedSatelliteScanResult earlyResult = getCurrentEnhancedScanResult(l5Result.hasL5Support);
                    if (earlyResult.navicCount >= 2 && earlyResult.navicSignalStrength > 25.0f) {
                        Log.d("NavIC", "⚡ EARLY detection - Strong NavIC signals found");
                        completeEnhancedDetection(true, earlyResult, EARLY_SUCCESS_DELAY_MS, cb, callbackRef[0]);
                    }
                }
            }, EARLY_SUCCESS_DELAY_MS);

            // Final timeout handler
            handler.postDelayed(() -> {
                if (!navicDetectionCompleted.get()) {
                    EnhancedSatelliteScanResult finalResult = getCurrentEnhancedScanResult(l5Result.hasL5Support);
                    completeEnhancedDetection(finalResult.navicCount > 0, finalResult,
                            SATELLITE_DETECTION_TIMEOUT_MS, cb, callbackRef[0]);
                }
            }, SATELLITE_DETECTION_TIMEOUT_MS);

        } catch (SecurityException se) {
            Log.e("NavIC", "🔒 Location permission denied for satellite detection");
            cb.onResult(false, 0, 0, 0, 0.0, new ArrayList<>(), 0, new ArrayList<>(),
                    l5Result.hasL5Support, "PERMISSION_ERROR");
        } catch (Exception e) {
            Log.e("NavIC", "❌ Failed to register GNSS callback", e);
            cb.onResult(false, 0, 0, 0, 0.0, new ArrayList<>(), 0, new ArrayList<>(),
                    l5Result.hasL5Support, "ERROR");
        }
    }

    private void updateSatelliteTracking(EnhancedSatelliteScanResult scanResult) {
        // Update detected satellites map
        for (Map.Entry<String, EnhancedSatellite> entry : scanResult.allSatellites.entrySet()) {
            String key = entry.getKey();
            EnhancedSatellite newSat = entry.getValue();

            EnhancedSatellite existingSat = detectedSatellites.get(key);
            if (existingSat != null) {
                // Update existing satellite with average values
                existingSat.detectionCount++;
                existingSat.cn0 = (existingSat.cn0 + newSat.cn0) / 2; // Average signal strength
                existingSat.usedInFix = existingSat.usedInFix || newSat.usedInFix;
                existingSat.elevation = (existingSat.elevation + newSat.elevation) / 2;
                existingSat.azimuth = (existingSat.azimuth + newSat.azimuth) / 2;
            } else {
                detectedSatellites.put(key, newSat);
            }
        }

        // Update satellites by system
        satellitesBySystem.clear();
        satellitesBySystem.putAll(scanResult.satellitesBySystem);
    }

    private EnhancedSatelliteScanResult getCurrentEnhancedScanResult(boolean hasL5Support) {
        int navicCount = 0;
        int navicUsedInFix = 0;
        float navicTotalSignal = 0;
        int navicWithSignal = 0;
        List<Map<String, Object>> navicDetails = new ArrayList<>();
        List<Map<String, Object>> allSatellitesList = new ArrayList<>();

        Map<String, List<EnhancedSatellite>> satsBySystem = new HashMap<>();

        // Process all detected satellites
        for (EnhancedSatellite sat : detectedSatellites.values()) {
            String systemName = sat.systemName;

            if (!satsBySystem.containsKey(systemName)) {
                satsBySystem.put(systemName, new ArrayList<>());
            }
            satsBySystem.get(systemName).add(sat);

            // Add to all satellites list
            allSatellitesList.add(sat.toEnhancedMap());

            // Count NavIC satellites
            if ("IRNSS".equals(systemName) && sat.cn0 >= MIN_NAVIC_SIGNAL_STRENGTH) {
                navicCount++;
                if (sat.usedInFix) navicUsedInFix++;
                if (sat.cn0 > 0) {
                    navicTotalSignal += sat.cn0;
                    navicWithSignal++;
                }
                navicDetails.add(sat.toEnhancedMap());
            }
        }

        float navicAvgSignal = navicWithSignal > 0 ? navicTotalSignal / navicWithSignal : 0.0f;
        int totalSatellites = detectedSatellites.size();

        // Determine primary system
        primaryPositioningSystem = determinePrimarySystemFromSatellites(satsBySystem);

        return new EnhancedSatelliteScanResult(
                navicCount, navicUsedInFix, totalSatellites, navicAvgSignal,
                navicDetails, detectedSatellites, satsBySystem, allSatellitesList
        );
    }

    private String determinePrimarySystemFromSatellites(Map<String, List<EnhancedSatellite>> satsBySystem) {
        String primarySystem = "GPS";
        int maxUsedInFix = 0;

        for (Map.Entry<String, List<EnhancedSatellite>> entry : satsBySystem.entrySet()) {
            String system = entry.getKey();
            List<EnhancedSatellite> satellites = entry.getValue();

            int usedInFixCount = 0;
            for (EnhancedSatellite sat : satellites) {
                if (sat.usedInFix) {
                    usedInFixCount++;
                }
            }

            if (usedInFixCount > maxUsedInFix) {
                maxUsedInFix = usedInFixCount;
                primarySystem = system;
            }
        }

        // If NavIC has satellites but not enough for primary, mark as hybrid
        if ("IRNSS".equals(primarySystem) && maxUsedInFix >= 3) {
            return "NAVIC_PRIMARY";
        } else if (satsBySystem.containsKey("IRNSS")) {
            List<EnhancedSatellite> navicSats = satsBySystem.get("IRNSS");
            int navicUsed = 0;
            for (EnhancedSatellite sat : navicSats) {
                if (sat.usedInFix) navicUsed++;
            }
            if (navicUsed > 0) {
                return "NAVIC_HYBRID";
            }
        }

        return primarySystem;
    }

    private void completeEnhancedDetection(boolean detected, EnhancedSatelliteScanResult result,
                                           long elapsedTime, EnhancedSatelliteDetectionCallback cb,
                                           GnssStatus.Callback callback) {
        if (navicDetectionCompleted.compareAndSet(false, true)) {
            cleanupCallback(callback);

            Log.d("NavIC", String.format(
                    "🎯 ENHANCED Detection %s\n" +
                            "  NavIC Satellites: %d (%d in fix)\n" +
                            "  Total Satellites: %d\n" +
                            "  Systems Detected: %d\n" +
                            "  Average Signal: %.1f dB-Hz\n" +
                            "  Detection Time: %d ms\n" +
                            "  Primary System: %s\n" +
                            "  L5 Band: %s",
                    detected ? "✅ SUCCESS" : "❌ FAILED",
                    result.navicCount, result.navicUsedInFix,
                    result.totalSatellites, result.satellitesBySystem.size(),
                    result.navicSignalStrength, elapsedTime,
                    primaryPositioningSystem,
                    hasL5BandSupport ? "✅ Available" : "❌ Not Available"
            ));

            cb.onResult(detected, result.navicCount, result.totalSatellites,
                    result.navicUsedInFix, result.navicSignalStrength,
                    result.navicDetails, elapsedTime, result.allSatellitesList,
                    hasL5BandSupport, primaryPositioningSystem);
        }
    }

    private void logEnhancedSatelliteStatus(EnhancedSatelliteScanResult result, long elapsedTime, int attempt) {
        StringBuilder logMsg = new StringBuilder();
        logMsg.append(String.format("\n📡 Enhanced Scan %d - Time: %d/%d ms\n",
                attempt, elapsedTime, SATELLITE_DETECTION_TIMEOUT_MS));
        logMsg.append(String.format("NavIC: %d satellites (%d in fix), Signal: %.1f dB-Hz\n",
                result.navicCount, result.navicUsedInFix, result.navicSignalStrength));

        // Log each system's status
        for (Map.Entry<String, List<EnhancedSatellite>> entry : result.satellitesBySystem.entrySet()) {
            String system = entry.getKey();
            List<EnhancedSatellite> satellites = entry.getValue();

            int usedCount = 0;
            float avgSignal = 0;
            int signalCount = 0;

            for (EnhancedSatellite sat : satellites) {
                if (sat.usedInFix) usedCount++;
                if (sat.cn0 > 0) {
                    avgSignal += sat.cn0;
                    signalCount++;
                }
            }

            if (signalCount > 0) avgSignal /= signalCount;

            logMsg.append(String.format("%s: %d sats (%d in fix, %.1f dB-Hz avg) ",
                    system, satellites.size(), usedCount, avgSignal));
        }

        Log.d("NavIC", logMsg.toString());
    }

    /**
     * Process satellites with ENHANCED information including carrier frequencies
     */
    private EnhancedSatelliteScanResult processEnhancedSatellites(GnssStatus status, long elapsedTime, boolean hasL5Support) {
        Map<String, EnhancedSatellite> allSats = new ConcurrentHashMap<>();
        Map<String, List<EnhancedSatellite>> satsBySystem = new ConcurrentHashMap<>();

        int navicCount = 0;
        int navicUsedInFix = 0;
        float navicTotalSignal = 0;
        int navicWithSignal = 0;

        int totalSatellites = status.getSatelliteCount();
        List<Map<String, Object>> navicDetails = new ArrayList<>();
        List<Map<String, Object>> allSatellitesList = new ArrayList<>();

        for (int i = 0; i < totalSatellites; i++) {
            int constellation = status.getConstellationType(i);
            String systemName = getEnhancedConstellationName(constellation);
            String countryFlag = GNSS_COUNTRIES.getOrDefault(systemName, "🌐");

            int svid = status.getSvid(i);
            float cn0 = status.getCn0DbHz(i);
            boolean used = status.usedInFix(i);
            float elevation = status.getElevationDegrees(i);
            float azimuth = status.getAzimuthDegrees(i);
            boolean hasEphemeris = status.hasEphemerisData(i);
            boolean hasAlmanac = status.hasAlmanacData(i);

            // Determine carrier frequency and band
            String frequencyBand = "Unknown";
            double carrierFrequency = 0.0;

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                try {
                    carrierFrequency = status.getCarrierFrequencyHz(i);
                    if (carrierFrequency > 0) {
                        frequencyBand = determineFrequencyBandFromHz(carrierFrequency);
                    }
                } catch (Exception e) {
                    frequencyBand = getDefaultBandForConstellation(constellation, hasL5Support);
                }
            } else {
                frequencyBand = getDefaultBandForConstellation(constellation, hasL5Support);
            }

            // Create ENHANCED satellite object
            EnhancedSatellite satellite = new EnhancedSatellite(
                    svid,
                    systemName,
                    constellation,
                    countryFlag,
                    cn0,
                    used,
                    elevation,
                    azimuth,
                    hasEphemeris,
                    hasAlmanac,
                    frequencyBand,
                    carrierFrequency,
                    elapsedTime
            );

            // Use system_svid as key for better tracking
            String satelliteKey = systemName + "_" + svid;
            allSats.put(satelliteKey, satellite);

            // Group by system
            if (!satsBySystem.containsKey(systemName)) {
                satsBySystem.put(systemName, new ArrayList<>());
            }
            satsBySystem.get(systemName).add(satellite);

            // Create detailed map for Flutter
            Map<String, Object> satMap = satellite.toEnhancedMap();
            allSatellitesList.add(satMap);

            // NavIC-specific tracking
            if (systemName.equals("IRNSS") && svid >= 1 && svid <= 14) {
                if (cn0 >= MIN_NAVIC_SIGNAL_STRENGTH) {
                    navicCount++;
                    if (used) navicUsedInFix++;
                    if (cn0 > 0) {
                        navicTotalSignal += cn0;
                        navicWithSignal++;
                    }

                    // Add to NavIC details
                    navicDetails.add(satMap);

                    // Log new NavIC satellite
                    if (!detectedSatellites.containsKey(satelliteKey)) {
                        Log.d("NavIC", String.format(
                                "✅ IRNSS Satellite:\n" +
                                        "  SVID: %d\n" +
                                        "  Signal: %.1f dB-Hz\n" +
                                        "  Band: %s\n" +
                                        "  Used: %s\n" +
                                        "  Elevation: %.1f°\n" +
                                        "  Azimuth: %.1f°",
                                svid, cn0, frequencyBand, used, elevation, azimuth
                        ));
                    }
                }
            } else if (cn0 > 10.0f) {
                // Log other GNSS satellites on first detection
                if (!detectedSatellites.containsKey(satelliteKey)) {
                    Log.v("NavIC", String.format(
                            "📡 %s %s:\n" +
                                    "  SVID: %d\n" +
                                    "  Signal: %.1f dB-Hz\n" +
                                    "  Band: %s\n" +
                                    "  Used: %s",
                            countryFlag, systemName, svid, cn0, frequencyBand, used
                    ));
                }
            }
        }

        float navicAvgSignal = navicWithSignal > 0 ? navicTotalSignal / navicWithSignal : 0.0f;

        return new EnhancedSatelliteScanResult(
                navicCount, navicUsedInFix, totalSatellites, navicAvgSignal,
                navicDetails, allSats, satsBySystem, allSatellitesList
        );
    }

    private String determineFrequencyBandFromHz(double frequencyHz) {
        double freqMHz = frequencyHz / 1e6;

        // L5/E5a/B2a frequency
        if (Math.abs(freqMHz - 1176.45) < 2.0) return "L5";
        // L1/E1/B1 frequency
        if (Math.abs(freqMHz - 1575.42) < 2.0) return "L1";
        // L2 frequency
        if (Math.abs(freqMHz - 1227.60) < 2.0) return "L2";
        // NavIC S-band
        if (Math.abs(freqMHz - 2492.028) < 2.0) return "S";
        // GLONASS G1
        if (Math.abs(freqMHz - 1602.0) < 2.0) return "G1";
        // GLONASS G2
        if (Math.abs(freqMHz - 1246.0) < 2.0) return "G2";
        // Galileo E5
        if (Math.abs(freqMHz - 1207.14) < 2.0) return "E5";
        // BeiDou B2
        if (Math.abs(freqMHz - 1207.14) < 2.0) return "B2";
        // BeiDou B3
        if (Math.abs(freqMHz - 1268.52) < 2.0) return "B3";

        return String.format("%.0f MHz", freqMHz);
    }

    private String getDefaultBandForConstellation(int constellation, boolean hasL5Support) {
        switch (constellation) {
            case GnssStatus.CONSTELLATION_IRNSS:
                return hasL5Support ? "L5/S" : "L5";
            case GnssStatus.CONSTELLATION_GPS:
                return hasL5Support ? "L1/L5" : "L1";
            case GnssStatus.CONSTELLATION_GALILEO:
                return hasL5Support ? "E1/E5a" : "E1";
            case GnssStatus.CONSTELLATION_BEIDOU:
                return hasL5Support ? "B1/B2a" : "B1";
            case GnssStatus.CONSTELLATION_GLONASS:
                return "G1";
            case GnssStatus.CONSTELLATION_QZSS:
                return hasL5Support ? "L1/L5" : "L1";
            default:
                return "L1";
        }
    }

    private String getEnhancedConstellationName(int constellation) {
        switch (constellation) {
            case GnssStatus.CONSTELLATION_IRNSS: return "IRNSS";
            case GnssStatus.CONSTELLATION_GPS: return "GPS";
            case GnssStatus.CONSTELLATION_GLONASS: return "GLONASS";
            case GnssStatus.CONSTELLATION_GALILEO: return "GALILEO";
            case GnssStatus.CONSTELLATION_BEIDOU: return "BEIDOU";
            case GnssStatus.CONSTELLATION_QZSS: return "QZSS";
            case GnssStatus.CONSTELLATION_SBAS: return "SBAS";
            case GnssStatus.CONSTELLATION_UNKNOWN: return "UNKNOWN";
            default: return "UNKNOWN_" + constellation;
        }
    }

    private String determineEnhancedPositioningMethod(boolean navicDetected, int navicUsedInFix,
                                                      List<Map<String, Object>> allSatellites, boolean l5Enabled) {
        if (navicDetected && navicUsedInFix >= 4) {
            return l5Enabled ? "NAVIC_PRIMARY_L5" : "NAVIC_PRIMARY";
        } else if (navicDetected && navicUsedInFix >= 2) {
            return l5Enabled ? "NAVIC_HYBRID_L5" : "NAVIC_HYBRID";
        } else if (navicDetected && navicUsedInFix >= 1) {
            return "NAVIC_ASSISTED";
        }

        // Count satellites from other systems
        Map<String, Integer> systemCounts = new HashMap<>();
        Map<String, Integer> systemUsedCounts = new HashMap<>();

        for (Map<String, Object> sat : allSatellites) {
            String system = (String) sat.get("system");
            boolean used = (Boolean) sat.get("usedInFix");

            systemCounts.put(system, systemCounts.getOrDefault(system, 0) + 1);
            if (used) {
                systemUsedCounts.put(system, systemUsedCounts.getOrDefault(system, 0) + 1);
            }
        }

        // Check which system has enough satellites for positioning
        for (Map.Entry<String, Integer> entry : systemUsedCounts.entrySet()) {
            if (entry.getValue() >= 4) {
                String system = entry.getKey();
                return l5Enabled ? system + "_PRIMARY_L5" : system + "_PRIMARY";
            }
        }

        // Check for hybrid positioning
        int totalUsed = 0;
        for (Integer count : systemUsedCounts.values()) {
            totalUsed += count;
        }

        if (totalUsed >= 4) {
            return l5Enabled ? "MULTI_GNSS_HYBRID_L5" : "MULTI_GNSS_HYBRID";
        }

        return "INSUFFICIENT_SATELLITES";
    }

    private String generateEnhancedDetectionMessage(EnhancedHardwareDetectionResult hardwareResult,
                                                    EnhancedL5BandResult l5Result, boolean navicDetected,
                                                    int navicCount, int usedInFix, double signalStrength,
                                                    long acquisitionTime) {
        StringBuilder message = new StringBuilder();

        if (!hardwareResult.isSupported) {
            message.append("Device chipset does not support NavIC. Using standard GPS positioning.");
        } else {
            if (navicDetected) {
                message.append(String.format(
                        "✅ Device supports NavIC and detected %d NavIC satellites (%d used in fix). ",
                        navicCount, usedInFix
                ));
                if (signalStrength > 0) {
                    message.append(String.format("Average signal strength: %.1f dB-Hz. ", signalStrength));
                }
                message.append(String.format("Acquisition time: %d ms. ", acquisitionTime));

                if (l5Result.hasL5Support) {
                    message.append("L5 band enabled for enhanced accuracy.");
                } else {
                    message.append("L5 band not available.");
                }
            } else {
                message.append(String.format(
                        "⚠️ Device chipset supports NavIC, but no NavIC satellites detected in %d seconds. ",
                        acquisitionTime / 1000
                ));
                if (l5Result.hasL5Support) {
                    message.append("L5 band is available for other GNSS systems.");
                }
            }
        }

        // Add chipset info
        if (!hardwareResult.chipsetVendor.equals("UNKNOWN")) {
            message.append(String.format(" Chipset: %s %s (%.0f%% confidence).",
                    hardwareResult.chipsetVendor, hardwareResult.chipsetModel,
                    hardwareResult.confidenceLevel * 100));
        }

        return message.toString();
    }

    /**
     * Get all satellites in view (real-time)
     */
    private void getAllSatellites(MethodChannel.Result result) {
        if (!hasLocationPermissions()) {
            result.error("PERMISSION_DENIED", "Location permissions required", null);
            return;
        }

        List<Map<String, Object>> allSatellites = new ArrayList<>();
        Map<String, Object> systems = new HashMap<>();

        // Convert EnhancedSatellite objects to maps
        for (EnhancedSatellite sat : detectedSatellites.values()) {
            Map<String, Object> satMap = sat.toEnhancedMap();
            allSatellites.add(satMap);

            String system = sat.systemName;
            if (!systems.containsKey(system)) {
                Map<String, Object> systemInfo = new HashMap<>();
                systemInfo.put("flag", sat.countryFlag);
                systemInfo.put("name", system);
                systemInfo.put("count", 0);
                systemInfo.put("used", 0);
                systemInfo.put("averageSignal", 0.0);
                systems.put(system, systemInfo);
            }

            Map<String, Object> systemInfo = (Map<String, Object>) systems.get(system);
            systemInfo.put("count", (Integer) systemInfo.get("count") + 1);
            if (sat.usedInFix) {
                systemInfo.put("used", (Integer) systemInfo.get("used") + 1);
            }

            // Update average signal
            double currentAvg = (Double) systemInfo.get("averageSignal");
            int count = (Integer) systemInfo.get("count");
            systemInfo.put("averageSignal", (currentAvg * (count - 1) + sat.cn0) / count);
        }

        Map<String, Object> response = new HashMap<>();
        response.put("satellites", allSatellites);
        response.put("systems", new ArrayList<>(systems.values()));
        response.put("totalSatellites", allSatellites.size());
        response.put("hasL5Band", hasL5BandSupport);
        response.put("primarySystem", primaryPositioningSystem);
        response.put("chipset", detectedChipset);
        response.put("chipsetVendor", chipsetVendor);
        response.put("chipsetConfidence", chipsetConfidence);
        response.put("l5Confidence", l5Confidence);
        response.put("timestamp", System.currentTimeMillis());

        Log.d("NavIC", String.format("📊 Returning %d satellites from %d systems",
                allSatellites.size(), systems.size()));

        result.success(response);
    }

    private void getGnssCapabilities(MethodChannel.Result result) {
        Log.d("NavIC", "Getting enhanced GNSS capabilities");
        Map<String, Object> caps = new HashMap<>();
        try {
            caps.put("androidVersion", Build.VERSION.SDK_INT);
            caps.put("manufacturer", Build.MANUFACTURER);
            caps.put("model", Build.MODEL);
            caps.put("device", Build.DEVICE);
            caps.put("hardware", Build.HARDWARE);
            caps.put("board", Build.BOARD);
            caps.put("product", Build.PRODUCT);
            caps.put("brand", Build.BRAND);

            boolean hasGnssFeature = getPackageManager().hasSystemFeature(PackageManager.FEATURE_LOCATION_GPS);
            caps.put("hasGnssFeature", hasGnssFeature);

            Map<String, Object> gnssMap = new HashMap<>();
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                try {
                    Object gnssCaps = locationManager.getGnssCapabilities();
                    if (gnssCaps != null) {
                        Class<?> capsClass = gnssCaps.getClass();

                        // Check for various GNSS capabilities
                        String[] capabilityMethods = {"hasIrnss", "hasL5", "hasL1", "hasL2",
                                "hasGlonass", "hasGalileo", "hasBeidou",
                                "hasQzss", "hasSbas"};

                        for (String methodName : capabilityMethods) {
                            try {
                                Method method = capsClass.getMethod(methodName);
                                Object value = method.invoke(gnssCaps);
                                if (value instanceof Boolean) {
                                    gnssMap.put(methodName, (Boolean) value);
                                    Log.d("NavIC", "GnssCapabilities." + methodName + ": " + value);
                                }
                            } catch (NoSuchMethodException ignore) {
                                // Method not available
                            }
                        }
                    }
                } catch (Throwable t) {
                    Log.e("NavIC", "Error getting GNSS capabilities", t);
                }
            } else {
                gnssMap.put("hasIrnss", false);
                gnssMap.put("hasL5", false);
            }

            caps.put("gnssCapabilities", gnssMap);
            caps.put("capabilitiesMethod", "ENHANCED_HARDWARE_DETECTION_V2");
            caps.put("detectionTime", System.currentTimeMillis());

            Log.d("NavIC", "Enhanced GNSS capabilities retrieved successfully");
            result.success(caps);
        } catch (Exception e) {
            Log.e("NavIC", "Failed to get GNSS capabilities", e);
            result.error("CAPABILITIES_ERROR", "Failed to get GNSS capabilities", null);
        }
    }

    private void startRealTimeNavicDetection(MethodChannel.Result result) {
        Log.d("NavIC", "Starting enhanced real-time NavIC detection");

        if (!hasLocationPermissions()) {
            result.error("PERMISSION_DENIED", "Location permissions required", null);
            return;
        }

        // Stop any existing detection
        if (realtimeCallback != null) {
            locationManager.unregisterGnssStatusCallback(realtimeCallback);
        }

        realtimeCallback = new GnssStatus.Callback() {
            @Override
            public void onSatelliteStatusChanged(GnssStatus status) {
                Map<String, Object> data = processEnhancedSatelliteData(status);
                try {
                    handler.post(() -> {
                        methodChannel.invokeMethod("onSatelliteUpdate", data);
                    });
                } catch (Exception e) {
                    Log.e("NavIC", "Error sending satellite update to Flutter", e);
                }
            }

            @Override
            public void onStarted() {
                Log.d("NavIC", "Enhanced real-time GNSS monitoring started");
            }

            @Override
            public void onStopped() {
                Log.d("NavIC", "Enhanced real-time GNSS monitoring stopped");
            }
        };

        try {
            locationManager.registerGnssStatusCallback(realtimeCallback, handler);
            Map<String, Object> resp = new HashMap<>();
            resp.put("success", true);
            resp.put("message", "Enhanced real-time NavIC detection started");
            resp.put("hasL5Band", hasL5BandSupport);
            resp.put("chipset", detectedChipset);
            resp.put("chipsetVendor", chipsetVendor);
            Log.d("NavIC", "Enhanced real-time detection started successfully");
            result.success(resp);
        } catch (SecurityException se) {
            Log.e("NavIC", "Permission error starting real-time detection", se);
            result.error("PERMISSION_ERROR", "Location permissions required", null);
        } catch (Exception e) {
            Log.e("NavIC", "Error starting real-time detection", e);
            result.error("REALTIME_DETECTION_ERROR", "Failed to start detection: " + e.getMessage(), null);
        }
    }

    private Map<String, Object> processEnhancedSatelliteData(GnssStatus status) {
        Map<String, Object> constellations = new HashMap<>();
        List<Map<String, Object>> satellites = new ArrayList<>();
        List<Map<String, Object>> navicSatellites = new ArrayList<>();

        Map<String, Object> systemStats = new HashMap<>();

        int irnssCount = 0;
        int gpsCount = 0;
        int glonassCount = 0;
        int galileoCount = 0;
        int beidouCount = 0;
        int qzssCount = 0;
        int sbasCount = 0;
        int irnssUsedInFix = 0;
        int gpsUsedInFix = 0;
        int glonassUsedInFix = 0;
        int galileoUsedInFix = 0;
        int beidouUsedInFix = 0;
        int qzssUsedInFix = 0;

        float irnssSignalTotal = 0;
        float gpsSignalTotal = 0;
        int irnssSignalCount = 0;
        int gpsSignalCount = 0;

        for (int i = 0; i < status.getSatelliteCount(); i++) {
            int constellationType = status.getConstellationType(i);
            String constellationName = getEnhancedConstellationName(constellationType);
            String countryFlag = GNSS_COUNTRIES.getOrDefault(constellationName, "🌐");

            int svid = status.getSvid(i);
            float cn0 = status.getCn0DbHz(i);
            boolean used = status.usedInFix(i);
            float elevation = status.getElevationDegrees(i);
            float azimuth = status.getAzimuthDegrees(i);
            boolean hasEphemeris = status.hasEphemerisData(i);
            boolean hasAlmanac = status.hasAlmanacData(i);

            // Determine frequency band
            String frequencyBand = "Unknown";
            double carrierFrequency = 0.0;

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                try {
                    carrierFrequency = status.getCarrierFrequencyHz(i);
                    if (carrierFrequency > 0) {
                        frequencyBand = determineFrequencyBandFromHz(carrierFrequency);
                    }
                } catch (Exception e) {
                    frequencyBand = getDefaultBandForConstellation(constellationType, hasL5BandSupport);
                }
            } else {
                frequencyBand = getDefaultBandForConstellation(constellationType, hasL5BandSupport);
            }

            // Update counts and signal totals
            switch (constellationType) {
                case GnssStatus.CONSTELLATION_IRNSS:
                    irnssCount++;
                    if (used) irnssUsedInFix++;
                    if (cn0 > 0) {
                        irnssSignalTotal += cn0;
                        irnssSignalCount++;
                    }
                    break;
                case GnssStatus.CONSTELLATION_GPS:
                    gpsCount++;
                    if (used) gpsUsedInFix++;
                    if (cn0 > 0) {
                        gpsSignalTotal += cn0;
                        gpsSignalCount++;
                    }
                    break;
                case GnssStatus.CONSTELLATION_GLONASS:
                    glonassCount++; if (used) glonassUsedInFix++; break;
                case GnssStatus.CONSTELLATION_GALILEO:
                    galileoCount++; if (used) galileoUsedInFix++; break;
                case GnssStatus.CONSTELLATION_BEIDOU:
                    beidouCount++; if (used) beidouUsedInFix++; break;
                case GnssStatus.CONSTELLATION_QZSS:
                    qzssCount++; if (used) qzssUsedInFix++; break;
                case GnssStatus.CONSTELLATION_SBAS:
                    sbasCount++; break;
            }

            Map<String, Object> sat = new HashMap<>();
            sat.put("constellation", constellationName);
            sat.put("system", constellationName); // Added for compatibility
            sat.put("countryFlag", countryFlag);
            sat.put("svid", svid);
            sat.put("cn0DbHz", cn0);
            sat.put("elevation", elevation);
            sat.put("azimuth", azimuth);
            sat.put("hasEphemeris", hasEphemeris);
            sat.put("hasAlmanac", hasAlmanac);
            sat.put("usedInFix", used);
            sat.put("frequencyBand", frequencyBand);
            sat.put("carrierFrequencyHz", carrierFrequency);

            // Calculate signal strength level
            String signalStrength = "UNKNOWN";
            if (cn0 >= 35) signalStrength = "EXCELLENT";
            else if (cn0 >= 25) signalStrength = "GOOD";
            else if (cn0 >= 18) signalStrength = "FAIR";
            else if (cn0 >= 10) signalStrength = "WEAK";
            else if (cn0 > 0) signalStrength = "POOR";
            sat.put("signalStrength", signalStrength);

            satellites.add(sat);

            if (constellationType == GnssStatus.CONSTELLATION_IRNSS) {
                navicSatellites.add(sat);
            }
        }

        constellations.put("IRNSS", irnssCount);
        constellations.put("GPS", gpsCount);
        constellations.put("GLONASS", glonassCount);
        constellations.put("GALILEO", galileoCount);
        constellations.put("BEIDOU", beidouCount);
        constellations.put("QZSS", qzssCount);
        constellations.put("SBAS", sbasCount);

        // Calculate average signals
        float irnssAvgSignal = irnssSignalCount > 0 ? irnssSignalTotal / irnssSignalCount : 0;
        float gpsAvgSignal = gpsSignalCount > 0 ? gpsSignalTotal / gpsSignalCount : 0;

        // System statistics with enhanced info
        systemStats.put("IRNSS", createEnhancedSystemStat("IRNSS", "🇮🇳", irnssCount, irnssUsedInFix, irnssAvgSignal));
        systemStats.put("GPS", createEnhancedSystemStat("GPS", "🇺🇸", gpsCount, gpsUsedInFix, gpsAvgSignal));
        systemStats.put("GLONASS", createEnhancedSystemStat("GLONASS", "🇷🇺", glonassCount, glonassUsedInFix, 0));
        systemStats.put("GALILEO", createEnhancedSystemStat("GALILEO", "🇪🇺", galileoCount, galileoUsedInFix, 0));
        systemStats.put("BEIDOU", createEnhancedSystemStat("BEIDOU", "🇨🇳", beidouCount, beidouUsedInFix, 0));

        // Determine primary system
        String primarySystem = determinePrimarySystemFromCounts(irnssUsedInFix, gpsUsedInFix,
                glonassUsedInFix, galileoUsedInFix, beidouUsedInFix);

        Map<String, Object> result = new HashMap<>();
        result.put("type", "ENHANCED_SATELLITE_UPDATE");
        result.put("timestamp", System.currentTimeMillis());
        result.put("totalSatellites", status.getSatelliteCount());
        result.put("constellations", constellations);
        result.put("systemStats", systemStats);
        result.put("satellites", satellites);
        result.put("navicSatellites", navicSatellites);
        result.put("isNavicAvailable", (irnssCount > 0));
        result.put("navicSatellitesCount", irnssCount);
        result.put("navicUsedInFix", irnssUsedInFix);
        result.put("navicAverageSignal", irnssAvgSignal);
        result.put("primarySystem", primarySystem);
        result.put("hasL5Band", hasL5BandSupport);
        result.put("locationProvider", primarySystem + (hasL5BandSupport ? "_L5" : ""));
        result.put("chipsetInfo", detectedChipset);
        result.put("chipsetVendor", chipsetVendor);

        // Log update summary
        Log.d("NavIC", String.format(
                "📡 Enhanced Update - Primary: %s, NavIC: %d(%d), GPS: %d(%d), Total: %d, L5: %s, Chipset: %s",
                primarySystem, irnssCount, irnssUsedInFix, gpsCount, gpsUsedInFix,
                status.getSatelliteCount(), hasL5BandSupport ? "Yes" : "No", detectedChipset
        ));

        return result;
    }

    private Map<String, Object> createEnhancedSystemStat(String name, String flag, int total, int used, float avgSignal) {
        Map<String, Object> stat = new HashMap<>();
        stat.put("name", name);
        stat.put("flag", flag);
        stat.put("total", total);
        stat.put("used", used);
        stat.put("available", total - used);
        stat.put("averageSignal", avgSignal);
        stat.put("utilization", total > 0 ? (used * 100.0 / total) : 0.0);
        return stat;
    }

    private String determinePrimarySystemFromCounts(int irnssUsed, int gpsUsed, int glonassUsed,
                                                    int galileoUsed, int beidouUsed) {
        if (irnssUsed >= 4) return "NAVIC";
        if (gpsUsed >= 4) return "GPS";
        if (glonassUsed >= 4) return "GLONASS";
        if (galileoUsed >= 4) return "GALILEO";
        if (beidouUsed >= 4) return "BEIDOU";

        // Find system with most used satellites
        int maxUsed = Math.max(Math.max(Math.max(irnssUsed, gpsUsed), Math.max(glonassUsed, galileoUsed)), beidouUsed);

        if (maxUsed == 0) return "NO_FIX";

        if (maxUsed == irnssUsed && irnssUsed > 0) return "NAVIC_HYBRID";
        if (maxUsed == gpsUsed) return "GPS_HYBRID";
        if (maxUsed == glonassUsed) return "GLONASS_HYBRID";
        if (maxUsed == galileoUsed) return "GALILEO_HYBRID";

        return "MULTI_GNSS";
    }

    private void stopRealTimeDetection(MethodChannel.Result result) {
        Log.d("NavIC", "Stopping enhanced real-time detection");
        try {
            if (realtimeCallback != null) {
                locationManager.unregisterGnssStatusCallback(realtimeCallback);
                realtimeCallback = null;
                Log.d("NavIC", "Enhanced real-time detection stopped");
            }
        } catch (Exception e) {
            Log.e("NavIC", "Error stopping real-time detection", e);
        }

        if (result != null) {
            Map<String, Object> resp = new HashMap<>();
            resp.put("success", true);
            resp.put("message", "Enhanced real-time detection stopped");
            result.success(resp);
        }
    }

    private void stopRealTimeDetection() {
        stopRealTimeDetection(null);
    }

    private void startLocationUpdates(MethodChannel.Result result) {
        Log.d("NavIC", "Starting enhanced location updates");

        if (!hasLocationPermissions()) {
            result.error("PERMISSION_DENIED", "Location permissions required", null);
            return;
        }

        // Stop any existing updates
        if (locationListener != null) {
            locationManager.removeUpdates(locationListener);
        }

        locationListener = new LocationListener() {
            @Override
            public void onLocationChanged(Location location) {
                try {
                    Map<String, Object> locationData = new HashMap<>();
                    locationData.put("latitude", location.getLatitude());
                    locationData.put("longitude", location.getLongitude());
                    locationData.put("accuracy", location.getAccuracy());
                    locationData.put("altitude", location.getAltitude());
                    locationData.put("speed", location.getSpeed());
                    locationData.put("bearing", location.getBearing());
                    locationData.put("time", location.getTime());
                    locationData.put("provider", location.getProvider());
                    locationData.put("timestamp", System.currentTimeMillis());

                    // Add satellite info if available
                    if (!detectedSatellites.isEmpty()) {
                        locationData.put("satelliteCount", detectedSatellites.size());
                        locationData.put("hasL5Band", hasL5BandSupport);
                        locationData.put("primarySystem", primaryPositioningSystem);
                    }

                    handler.post(() -> {
                        methodChannel.invokeMethod("onLocationUpdate", locationData);
                    });
                } catch (Exception e) {
                    Log.e("NavIC", "Error sending location update to Flutter", e);
                }
            }

            @Override
            public void onStatusChanged(String provider, int status, Bundle extras) {
                Log.d("NavIC", "Location provider status changed: " + provider + " - " + status);
            }

            @Override
            public void onProviderEnabled(String provider) {
                Log.d("NavIC", "Location provider enabled: " + provider);
            }

            @Override
            public void onProviderDisabled(String provider) {
                Log.d("NavIC", "Location provider disabled: " + provider);
            }
        };

        try {
            // Request updates from all available providers
            if (locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                locationManager.requestLocationUpdates(
                        LocationManager.GPS_PROVIDER,
                        LOCATION_UPDATE_INTERVAL_MS,
                        LOCATION_UPDATE_DISTANCE_M,
                        locationListener,
                        handler.getLooper()
                );
                Log.d("NavIC", "GPS provider updates requested");
            }

            if (locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                locationManager.requestLocationUpdates(
                        LocationManager.NETWORK_PROVIDER,
                        LOCATION_UPDATE_INTERVAL_MS * 2, // Less frequent network updates
                        LOCATION_UPDATE_DISTANCE_M * 2,
                        locationListener,
                        handler.getLooper()
                );
                Log.d("NavIC", "Network provider updates requested");
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (locationManager.isProviderEnabled(LocationManager.FUSED_PROVIDER)) {
                    locationManager.requestLocationUpdates(
                            LocationManager.FUSED_PROVIDER,
                            LOCATION_UPDATE_INTERVAL_MS,
                            LOCATION_UPDATE_DISTANCE_M,
                            locationListener,
                            handler.getLooper()
                    );
                    Log.d("NavIC", "Fused provider updates requested");
                }
            }

            isTrackingLocation = true;

            Map<String, Object> resp = new HashMap<>();
            resp.put("success", true);
            resp.put("message", "Enhanced location updates started");
            resp.put("providers", getActiveProviders());
            Log.d("NavIC", "Enhanced location updates started successfully");
            result.success(resp);

        } catch (SecurityException se) {
            Log.e("NavIC", "Permission error starting location updates", se);
            result.error("PERMISSION_ERROR", "Location permissions required", null);
        } catch (Exception e) {
            Log.e("NavIC", "Error starting location updates", e);
            result.error("LOCATION_ERROR", "Failed to start location updates: " + e.getMessage(), null);
        }
    }

    private List<String> getActiveProviders() {
        List<String> activeProviders = new ArrayList<>();
        String[] providers = {LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER};

        for (String provider : providers) {
            if (locationManager.isProviderEnabled(provider)) {
                activeProviders.add(provider);
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (locationManager.isProviderEnabled(LocationManager.FUSED_PROVIDER)) {
                activeProviders.add(LocationManager.FUSED_PROVIDER);
            }
        }

        return activeProviders;
    }

    private void stopLocationUpdates(MethodChannel.Result result) {
        Log.d("NavIC", "Stopping enhanced location updates");
        stopLocationUpdates();
        if (result != null) {
            Map<String, Object> resp = new HashMap<>();
            resp.put("success", true);
            resp.put("message", "Enhanced location updates stopped");
            result.success(resp);
        }
    }

    private void stopLocationUpdates() {
        if (locationListener != null) {
            locationManager.removeUpdates(locationListener);
            locationListener = null;
            isTrackingLocation = false;
            Log.d("NavIC", "Enhanced location updates stopped");
        }
    }

    // =============== UTILITY METHODS ===============
    private void openLocationSettings(MethodChannel.Result result) {
        try {
            Intent intent = new Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS);
            startActivity(intent);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "Location settings opened");
            result.success(response);
        } catch (Exception e) {
            Log.e("NavIC", "Error opening location settings", e);
            result.error("SETTINGS_ERROR", "Failed to open location settings", null);
        }
    }

    private void isLocationEnabled(MethodChannel.Result result) {
        try {
            boolean gpsEnabled = locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER);
            boolean networkEnabled = locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER);
            boolean fusedEnabled = false;

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                fusedEnabled = locationManager.isProviderEnabled(LocationManager.FUSED_PROVIDER);
            }

            Map<String, Object> response = new HashMap<>();
            response.put("gpsEnabled", gpsEnabled);
            response.put("networkEnabled", networkEnabled);
            response.put("fusedEnabled", fusedEnabled);
            response.put("anyEnabled", gpsEnabled || networkEnabled || fusedEnabled);
            response.put("providers", getActiveProviders());

            result.success(response);
        } catch (Exception e) {
            Log.e("NavIC", "Error checking location status", e);
            result.error("LOCATION_STATUS_ERROR", "Failed to check location status", null);
        }
    }

    private void getDeviceInfo(MethodChannel.Result result) {
        try {
            Map<String, Object> deviceInfo = new HashMap<>();
            deviceInfo.put("manufacturer", Build.MANUFACTURER);
            deviceInfo.put("model", Build.MODEL);
            deviceInfo.put("device", Build.DEVICE);
            deviceInfo.put("hardware", Build.HARDWARE);
            deviceInfo.put("board", Build.BOARD);
            deviceInfo.put("product", Build.PRODUCT);
            deviceInfo.put("brand", Build.BRAND);
            deviceInfo.put("androidVersion", Build.VERSION.SDK_INT);
            deviceInfo.put("androidRelease", Build.VERSION.RELEASE);
            deviceInfo.put("fingerprint", Build.FINGERPRINT);

            // Get GNSS capabilities
            Map<String, Object> gnssCapabilities = new HashMap<>();
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                try {
                    Object gnssCaps = locationManager.getGnssCapabilities();
                    if (gnssCaps != null) {
                        Class<?> capsClass = gnssCaps.getClass();

                        // Check for various GNSS capabilities
                        String[] capabilityMethods = {"hasIrnss", "hasL5", "hasL1", "hasL2"};

                        for (String methodName : capabilityMethods) {
                            try {
                                Method method = capsClass.getMethod(methodName);
                                Object value = method.invoke(gnssCaps);
                                if (value instanceof Boolean) {
                                    gnssCapabilities.put(methodName, (Boolean) value);
                                }
                            } catch (NoSuchMethodException ignore) {
                                // Method not available
                            }
                        }
                    }
                } catch (Exception e) {
                    Log.d("NavIC", "Error getting GNSS capabilities for device info");
                }
            }

            deviceInfo.put("gnssCapabilities", gnssCapabilities);
            deviceInfo.put("detectedChipset", detectedChipset);
            deviceInfo.put("chipsetVendor", chipsetVendor);
            deviceInfo.put("hasL5Band", hasL5BandSupport);
            deviceInfo.put("detectionTime", System.currentTimeMillis());

            result.success(deviceInfo);
        } catch (Exception e) {
            Log.e("NavIC", "Error getting device info", e);
            result.error("DEVICE_INFO_ERROR", "Failed to get device info", null);
        }
    }

    @Override
    protected void onDestroy() {
        Log.d("NavIC", "Activity destroying, cleaning up resources");
        try {
            stopRealTimeDetection();
            stopLocationUpdates();
        } catch (Exception e) {
            Log.e("NavIC", "Error in onDestroy", e);
        }
        super.onDestroy();
    }

    // Helper methods
    private String getSoCModel() {
        try {
            Class<?> systemPropsClass = Class.forName("android.os.SystemProperties");
            Method getMethod = systemPropsClass.getMethod("get", String.class, String.class);

            String socModel = (String) getMethod.invoke(null, "ro.board.platform", "");
            if (socModel.isEmpty()) {
                socModel = (String) getMethod.invoke(null, "ro.hardware", "");
            }
            if (socModel.isEmpty()) {
                socModel = (String) getMethod.invoke(null, "ro.mediatek.platform", "");
            }
            if (socModel.isEmpty()) {
                socModel = (String) getMethod.invoke(null, "ro.chipset", "");
            }

            return socModel.toLowerCase();
        } catch (Exception e) {
            return Build.HARDWARE.toLowerCase();
        }
    }

    private void cleanupCallback(GnssStatus.Callback callback) {
        try {
            if (callback != null) {
                locationManager.unregisterGnssStatusCallback(callback);
            }
        } catch (Exception e) {
            // Ignore cleanup errors
        }
    }

    // =============== HELPER METHODS FOR NEW FEATURES ===============

    /**
     * Get complete satellite summary
     */
    private void getCompleteSatelliteSummary(MethodChannel.Result result) {
        Log.d("NavIC", "📊 Getting complete satellite summary");

        if (!hasLocationPermissions()) {
            result.error("PERMISSION_DENIED", "Location permissions required", null);
            return;
        }

        try {
            Map<String, Object> summary = new HashMap<>();
            summary.put("timestamp", System.currentTimeMillis());
            summary.put("totalSatellites", detectedSatellites.size());
            summary.put("hasL5Band", hasL5BandSupport);
            summary.put("primarySystem", primaryPositioningSystem);
            summary.put("chipset", detectedChipset);
            summary.put("chipsetVendor", chipsetVendor);

            // Count satellites by system
            Map<String, Integer> systemCounts = new HashMap<>();
            Map<String, Integer> systemUsedCounts = new HashMap<>();

            for (EnhancedSatellite sat : detectedSatellites.values()) {
                String system = sat.systemName;
                systemCounts.put(system, systemCounts.getOrDefault(system, 0) + 1);
                if (sat.usedInFix) {
                    systemUsedCounts.put(system, systemUsedCounts.getOrDefault(system, 0) + 1);
                }
            }

            summary.put("systemCounts", systemCounts);
            summary.put("systemUsedCounts", systemUsedCounts);

            result.success(summary);

        } catch (Exception e) {
            Log.e("NavIC", "Error getting complete satellite summary", e);
            result.error("SUMMARY_ERROR", "Failed to get satellite summary", null);
        }
    }

    /**
     * Get satellite names
     */
    private void getSatelliteNames(MethodChannel.Result result) {
        Log.d("NavIC", "📡 Getting satellite names");

        if (!hasLocationPermissions()) {
            result.error("PERMISSION_DENIED", "Location permissions required", null);
            return;
        }

        try {
            List<Map<String, Object>> satelliteNames = new ArrayList<>();

            for (EnhancedSatellite sat : detectedSatellites.values()) {
                Map<String, Object> nameInfo = new HashMap<>();
                nameInfo.put("svid", sat.svid);
                nameInfo.put("system", sat.systemName);
                nameInfo.put("name", getSatelliteName(sat.systemName, sat.svid));
                nameInfo.put("countryFlag", sat.countryFlag);
                satelliteNames.add(nameInfo);
            }

            Map<String, Object> response = new HashMap<>();
            response.put("satelliteNames", satelliteNames);
            response.put("timestamp", System.currentTimeMillis());

            result.success(response);

        } catch (Exception e) {
            Log.e("NavIC", "Error getting satellite names", e);
            result.error("NAMES_ERROR", "Failed to get satellite names", null);
        }
    }

    /**
     * Get constellation details
     */
    private void getConstellationDetails(MethodChannel.Result result) {
        Log.d("NavIC", "🌌 Getting constellation details");

        if (!hasLocationPermissions()) {
            result.error("PERMISSION_DENIED", "Location permissions required", null);
            return;
        }

        try {
            Map<String, Object> constellationDetails = new HashMap<>();

            for (Map.Entry<String, List<EnhancedSatellite>> entry : satellitesBySystem.entrySet()) {
                String system = entry.getKey();
                List<EnhancedSatellite> satellites = entry.getValue();

                Map<String, Object> systemDetails = new HashMap<>();
                systemDetails.put("countryFlag", GNSS_COUNTRIES.getOrDefault(system, "🌐"));
                systemDetails.put("satelliteCount", satellites.size());

                // Calculate statistics
                int usedCount = 0;
                float totalSignal = 0;
                int signalCount = 0;

                for (EnhancedSatellite sat : satellites) {
                    if (sat.usedInFix) usedCount++;
                    if (sat.cn0 > 0) {
                        totalSignal += sat.cn0;
                        signalCount++;
                    }
                }

                systemDetails.put("usedCount", usedCount);
                systemDetails.put("averageSignal", signalCount > 0 ? totalSignal / signalCount : 0);
                systemDetails.put("frequencies", GNSS_FREQUENCIES.getOrDefault(system, new Double[]{0.0}));

                constellationDetails.put(system, systemDetails);
            }

            Map<String, Object> response = new HashMap<>();
            response.put("constellationDetails", constellationDetails);
            response.put("timestamp", System.currentTimeMillis());

            result.success(response);

        } catch (Exception e) {
            Log.e("NavIC", "Error getting constellation details", e);
            result.error("CONSTELLATION_ERROR", "Failed to get constellation details", null);
        }
    }

    /**
     * Get signal strength analysis
     */
    private void getSignalStrengthAnalysis(MethodChannel.Result result) {
        Log.d("NavIC", "📶 Getting signal strength analysis");

        if (!hasLocationPermissions()) {
            result.error("PERMISSION_DENIED", "Location permissions required", null);
            return;
        }

        try {
            Map<String, Object> analysis = new HashMap<>();

            // Calculate signal strength distribution
            Map<String, Integer> strengthDistribution = new HashMap<>();
            strengthDistribution.put("EXCELLENT", 0);
            strengthDistribution.put("GOOD", 0);
            strengthDistribution.put("FAIR", 0);
            strengthDistribution.put("WEAK", 0);
            strengthDistribution.put("POOR", 0);

            float totalSignal = 0;
            int signalCount = 0;

            for (EnhancedSatellite sat : detectedSatellites.values()) {
                String strengthLevel = sat.getSignalStrengthLevel();
                strengthDistribution.put(strengthLevel, strengthDistribution.get(strengthLevel) + 1);

                if (sat.cn0 > 0) {
                    totalSignal += sat.cn0;
                    signalCount++;
                }
            }

            analysis.put("strengthDistribution", strengthDistribution);
            analysis.put("averageSignal", signalCount > 0 ? totalSignal / signalCount : 0);
            analysis.put("signalCount", signalCount);
            analysis.put("timestamp", System.currentTimeMillis());

            result.success(analysis);

        } catch (Exception e) {
            Log.e("NavIC", "Error getting signal strength analysis", e);
            result.error("SIGNAL_ANALYSIS_ERROR", "Failed to get signal strength analysis", null);
        }
    }

    /**
     * Get elevation and azimuth data
     */
    private void getElevationAzimuthData(MethodChannel.Result result) {
        Log.d("NavIC", "🎯 Getting elevation and azimuth data");

        if (!hasLocationPermissions()) {
            result.error("PERMISSION_DENIED", "Location permissions required", null);
            return;
        }

        try {
            List<Map<String, Object>> positionData = new ArrayList<>();

            for (EnhancedSatellite sat : detectedSatellites.values()) {
                Map<String, Object> data = new HashMap<>();
                data.put("svid", sat.svid);
                data.put("system", sat.systemName);
                data.put("elevation", sat.elevation);
                data.put("azimuth", sat.azimuth);
                data.put("signalStrength", sat.cn0);
                data.put("usedInFix", sat.usedInFix);
                positionData.add(data);
            }

            Map<String, Object> response = new HashMap<>();
            response.put("positionData", positionData);
            response.put("timestamp", System.currentTimeMillis());

            result.success(response);

        } catch (Exception e) {
            Log.e("NavIC", "Error getting elevation/azimuth data", e);
            result.error("POSITION_DATA_ERROR", "Failed to get elevation/azimuth data", null);
        }
    }

    /**
     * Get carrier frequency information
     */
    private void getCarrierFrequencyInfo(MethodChannel.Result result) {
        Log.d("NavIC", "📻 Getting carrier frequency information");

        if (!hasLocationPermissions()) {
            result.error("PERMISSION_DENIED", "Location permissions required", null);
            return;
        }

        try {
            List<Map<String, Object>> frequencyData = new ArrayList<>();

            for (EnhancedSatellite sat : detectedSatellites.values()) {
                Map<String, Object> data = new HashMap<>();
                data.put("svid", sat.svid);
                data.put("system", sat.systemName);
                data.put("frequencyBand", sat.frequencyBand);
                data.put("carrierFrequencyHz", sat.carrierFrequency > 0 ? sat.carrierFrequency : null);
                data.put("signalStrength", sat.cn0);
                frequencyData.add(data);
            }

            Map<String, Object> response = new HashMap<>();
            response.put("frequencyData", frequencyData);
            response.put("hasL5Band", hasL5BandSupport);
            response.put("timestamp", System.currentTimeMillis());

            result.success(response);

        } catch (Exception e) {
            Log.e("NavIC", "Error getting carrier frequency info", e);
            result.error("FREQUENCY_ERROR", "Failed to get carrier frequency info", null);
        }
    }

    /**
     * Get ephemeris and almanac status
     */
    private void getEphemerisAlmanacStatus(MethodChannel.Result result) {
        Log.d("NavIC", "📡 Getting ephemeris and almanac status");

        if (!hasLocationPermissions()) {
            result.error("PERMISSION_DENIED", "Location permissions required", null);
            return;
        }

        try {
            Map<String, Object> status = new HashMap<>();

            int hasEphemerisCount = 0;
            int hasAlmanacCount = 0;

            for (EnhancedSatellite sat : detectedSatellites.values()) {
                if (sat.hasEphemeris) hasEphemerisCount++;
                if (sat.hasAlmanac) hasAlmanacCount++;
            }

            status.put("totalSatellites", detectedSatellites.size());
            status.put("hasEphemerisCount", hasEphemerisCount);
            status.put("hasAlmanacCount", hasAlmanacCount);
            status.put("ephemerisPercentage", detectedSatellites.size() > 0 ?
                    (hasEphemerisCount * 100.0 / detectedSatellites.size()) : 0);
            status.put("almanacPercentage", detectedSatellites.size() > 0 ?
                    (hasAlmanacCount * 100.0 / detectedSatellites.size()) : 0);
            status.put("timestamp", System.currentTimeMillis());

            result.success(status);

        } catch (Exception e) {
            Log.e("NavIC", "Error getting ephemeris/almanac status", e);
            result.error("EPHEMERIS_ERROR", "Failed to get ephemeris/almanac status", null);
        }
    }

    /**
     * Get satellite detection history
     */
    private void getSatelliteDetectionHistory(MethodChannel.Result result) {
        Log.d("NavIC", "📈 Getting satellite detection history");

        if (!hasLocationPermissions()) {
            result.error("PERMISSION_DENIED", "Location permissions required", null);
            return;
        }

        try {
            List<Map<String, Object>> detectionHistory = new ArrayList<>();

            for (EnhancedSatellite sat : detectedSatellites.values()) {
                Map<String, Object> history = new HashMap<>();
                history.put("svid", sat.svid);
                history.put("system", sat.systemName);
                history.put("detectionCount", sat.detectionCount);
                history.put("firstDetectionTime", sat.detectionTime);
                history.put("lastDetectionTime", System.currentTimeMillis());
                history.put("averageSignal", sat.cn0);
                detectionHistory.add(history);
            }

            Map<String, Object> response = new HashMap<>();
            response.put("detectionHistory", detectionHistory);
            response.put("timestamp", System.currentTimeMillis());

            result.success(response);

        } catch (Exception e) {
            Log.e("NavIC", "Error getting detection history", e);
            result.error("HISTORY_ERROR", "Failed to get detection history", null);
        }
    }

    /**
     * Get GNSS diversity report
     */
    private void getGnssDiversityReport(MethodChannel.Result result) {
        Log.d("NavIC", "🌐 Getting GNSS diversity report");

        if (!hasLocationPermissions()) {
            result.error("PERMISSION_DENIED", "Location permissions required", null);
            return;
        }

        try {
            Map<String, Object> diversityReport = new HashMap<>();

            int totalSystems = satellitesBySystem.size();
            int totalSatellites = detectedSatellites.size();

            diversityReport.put("totalSystems", totalSystems);
            diversityReport.put("totalSatellites", totalSatellites);
            diversityReport.put("systemsDetected", new ArrayList<>(satellitesBySystem.keySet()));

            // Calculate diversity score
            double diversityScore = 0.0;
            if (totalSystems > 0 && totalSatellites > 0) {
                diversityScore = (totalSystems * 100.0) / 7.0; // 7 is max possible systems
            }

            diversityReport.put("diversityScore", diversityScore);
            diversityReport.put("diversityLevel", getDiversityLevel(diversityScore));
            diversityReport.put("hasL5Band", hasL5BandSupport);
            diversityReport.put("primarySystem", primaryPositioningSystem);
            diversityReport.put("timestamp", System.currentTimeMillis());

            result.success(diversityReport);

        } catch (Exception e) {
            Log.e("NavIC", "Error getting GNSS diversity report", e);
            result.error("DIVERSITY_ERROR", "Failed to get GNSS diversity report", null);
        }
    }

    /**
     * Get real-time satellite stream
     */
    private void getRealTimeSatelliteStream(MethodChannel.Result result) {
        Log.d("NavIC", "🔴 Getting real-time satellite stream");

        if (!hasLocationPermissions()) {
            result.error("PERMISSION_DENIED", "Location permissions required", null);
            return;
        }

        try {
            // Start real-time detection if not already started
            if (realtimeCallback == null) {
                startRealTimeNavicDetection(result);
                return;
            }

            Map<String, Object> response = new HashMap<>();
            response.put("status", "REALTIME_STREAM_ACTIVE");
            response.put("message", "Real-time satellite stream is active");
            response.put("hasL5Band", hasL5BandSupport);
            response.put("chipset", detectedChipset);
            response.put("timestamp", System.currentTimeMillis());

            result.success(response);

        } catch (Exception e) {
            Log.e("NavIC", "Error getting real-time satellite stream", e);
            result.error("STREAM_ERROR", "Failed to get real-time satellite stream", null);
        }
    }

    /**
     * Get satellite signal quality
     */
    private void getSatelliteSignalQuality(MethodChannel.Result result) {
        Log.d("NavIC", "📊 Getting satellite signal quality");

        if (!hasLocationPermissions()) {
            result.error("PERMISSION_DENIED", "Location permissions required", null);
            return;
        }

        try {
            Map<String, Object> signalQuality = new HashMap<>();

            // Calculate overall quality metrics
            float totalSignal = 0;
            int signalCount = 0;
            int excellentCount = 0;
            int goodCount = 0;
            int fairCount = 0;
            int weakCount = 0;
            int poorCount = 0;

            for (EnhancedSatellite sat : detectedSatellites.values()) {
                if (sat.cn0 > 0) {
                    totalSignal += sat.cn0;
                    signalCount++;

                    String strength = sat.getSignalStrengthLevel();
                    switch (strength) {
                        case "EXCELLENT": excellentCount++; break;
                        case "GOOD": goodCount++; break;
                        case "FAIR": fairCount++; break;
                        case "WEAK": weakCount++; break;
                        case "POOR": poorCount++; break;
                    }
                }
            }

            signalQuality.put("totalSatellites", detectedSatellites.size());
            signalQuality.put("satellitesWithSignal", signalCount);
            signalQuality.put("averageSignal", signalCount > 0 ? totalSignal / signalCount : 0);
            signalQuality.put("excellentCount", excellentCount);
            signalQuality.put("goodCount", goodCount);
            signalQuality.put("fairCount", fairCount);
            signalQuality.put("weakCount", weakCount);
            signalQuality.put("poorCount", poorCount);
            signalQuality.put("qualityScore", calculateQualityScore(excellentCount, goodCount, fairCount,
                    weakCount, poorCount, signalCount));
            signalQuality.put("timestamp", System.currentTimeMillis());

            result.success(signalQuality);

        } catch (Exception e) {
            Log.e("NavIC", "Error getting satellite signal quality", e);
            result.error("QUALITY_ERROR", "Failed to get satellite signal quality", null);
        }
    }

    // =============== ADDITIONAL HELPER METHODS ===============

    /**
     * Get satellite name based on system and SVID
     */
    private String getSatelliteName(String system, int svid) {
        // IRNSS/NAVIC satellites
        if ("IRNSS".equals(system)) {
            if (svid >= 1 && svid <= 14) {
                return String.format("IRNSS-%02d", svid);
            }
            return String.format("IRNSS-%02d", svid);
        }

        // GPS satellites
        if ("GPS".equals(system)) {
            return String.format("GPS PRN-%02d", svid);
        }

        // GLONASS satellites
        if ("GLONASS".equals(system)) {
            return String.format("GLONASS Slot-%02d", svid);
        }

        // Galileo satellites
        if ("GALILEO".equals(system)) {
            return String.format("Galileo E%02d", svid);
        }

        // BeiDou satellites
        if ("BEIDOU".equals(system)) {
            return String.format("BeiDou C%02d", svid);
        }

        // QZSS satellites
        if ("QZSS".equals(system)) {
            if (svid >= 1 && svid <= 4) {
                return String.format("QZS-%d", svid);
            }
            return String.format("QZSS-%02d", svid);
        }

        // SBAS satellites
        if ("SBAS".equals(system)) {
            return String.format("SBAS-%02d", svid);
        }

        // Default naming
        return String.format("%s-%02d", system, svid);
    }

    /**
     * Get constellation description
     */
    private String getConstellationDescription(int constellation) {
        switch (constellation) {
            case GnssStatus.CONSTELLATION_IRNSS: return "Indian Regional Navigation Satellite System (NavIC)";
            case GnssStatus.CONSTELLATION_GPS: return "Global Positioning System (USA)";
            case GnssStatus.CONSTELLATION_GLONASS: return "Global Navigation Satellite System (Russia)";
            case GnssStatus.CONSTELLATION_GALILEO: return "European Global Navigation Satellite System";
            case GnssStatus.CONSTELLATION_BEIDOU: return "BeiDou Navigation Satellite System (China)";
            case GnssStatus.CONSTELLATION_QZSS: return "Quasi-Zenith Satellite System (Japan)";
            case GnssStatus.CONSTELLATION_SBAS: return "Satellite-Based Augmentation System";
            default: return "Unknown Navigation System";
        }
    }

    /**
     * Get frequency description
     */
    private String getFrequencyDescription(String band) {
        switch (band) {
            case "L1": return "Primary GNSS frequency (1575.42 MHz)";
            case "L2": return "Secondary GNSS frequency (1227.60 MHz)";
            case "L5": return "Enhanced safety-of-life frequency (1176.45 MHz)";
            case "E1": return "Galileo primary frequency";
            case "E5": return "Galileo enhanced frequency";
            case "B1": return "BeiDou primary frequency";
            case "B2": return "BeiDou secondary frequency";
            case "G1": return "GLONASS primary frequency";
            case "G2": return "GLONASS secondary frequency";
            case "S": return "NavIC S-band (2492.028 MHz)";
            default: return "Unknown frequency band";
        }
    }

    /**
     * Get positioning role
     */
    private String getPositioningRole(boolean usedInFix, float cn0) {
        if (usedInFix && cn0 > 25) return "PRIMARY_POSITIONING";
        if (usedInFix) return "POSITIONING";
        if (cn0 > 20) return "SIGNAL_AVAILABLE";
        if (cn0 > 10) return "WEAK_SIGNAL";
        return "NOT_USED";
    }

    /**
     * Get health status
     */
    private String getHealthStatus(float cn0, boolean hasEphemeris, boolean hasAlmanac) {
        if (cn0 <= 0) return "NO_SIGNAL";
        if (cn0 < 10) return "VERY_WEAK";
        if (cn0 < 18) return "WEAK";
        if (!hasEphemeris) return "NO_EPHEMERIS";
        if (!hasAlmanac) return "NO_ALMANAC";
        if (cn0 >= 25) return "EXCELLENT";
        if (cn0 >= 18) return "GOOD";
        return "FAIR";
    }

    /**
     * Get diversity level based on score
     */
    private String getDiversityLevel(double score) {
        if (score >= 80) return "EXCELLENT";
        if (score >= 60) return "GOOD";
        if (score >= 40) return "FAIR";
        if (score >= 20) return "WEAK";
        return "POOR";
    }

    /**
     * Calculate quality score
     */
    private double calculateQualityScore(int excellent, int good, int fair, int weak, int poor, int total) {
        if (total == 0) return 0;

        double score = (excellent * 100 + good * 80 + fair * 60 + weak * 40 + poor * 20) / (double) total;
        return Math.min(100, score);
    }

    // =============== INNER CLASSES ===============

    private static class EnhancedSatellite {
        int svid;
        String systemName;
        int constellation;
        String countryFlag;
        float cn0;
        boolean usedInFix;
        float elevation;
        float azimuth;
        boolean hasEphemeris;
        boolean hasAlmanac;
        String frequencyBand;
        double carrierFrequency;
        long detectionTime;
        int detectionCount;

        EnhancedSatellite(int svid, String systemName, int constellation, String countryFlag,
                          float cn0, boolean usedInFix, float elevation, float azimuth,
                          boolean hasEphemeris, boolean hasAlmanac, String frequencyBand,
                          double carrierFrequency, long detectionTime) {
            this.svid = svid;
            this.systemName = systemName;
            this.constellation = constellation;
            this.countryFlag = countryFlag;
            this.cn0 = cn0;
            this.usedInFix = usedInFix;
            this.elevation = elevation;
            this.azimuth = azimuth;
            this.hasEphemeris = hasEphemeris;
            this.hasAlmanac = hasAlmanac;
            this.frequencyBand = frequencyBand;
            this.carrierFrequency = carrierFrequency;
            this.detectionTime = detectionTime;
            this.detectionCount = 1;
        }

        Map<String, Object> toEnhancedMap() {
            Map<String, Object> map = new HashMap<>();
            map.put("svid", svid);
            map.put("system", systemName);
            map.put("constellation", constellation);
            map.put("countryFlag", countryFlag);
            map.put("cn0DbHz", cn0);
            map.put("usedInFix", usedInFix);
            map.put("elevation", elevation);
            map.put("azimuth", azimuth);
            map.put("hasEphemeris", hasEphemeris);
            map.put("hasAlmanac", hasAlmanac);
            map.put("frequencyBand", frequencyBand);
            map.put("carrierFrequencyHz", carrierFrequency > 0 ? carrierFrequency : null);
            map.put("detectionTime", detectionTime);
            map.put("detectionCount", detectionCount);
            map.put("signalStrength", getSignalStrengthLevel());
            map.put("timestamp", System.currentTimeMillis());
            return map;
        }

        String getSignalStrengthLevel() {
            if (cn0 >= 35) return "EXCELLENT";
            if (cn0 >= 25) return "GOOD";
            if (cn0 >= 18) return "FAIR";
            if (cn0 >= 10) return "WEAK";
            return "POOR";
        }
    }

    private static class EnhancedSatelliteScanResult {
        int navicCount;
        int navicUsedInFix;
        int totalSatellites;
        float navicSignalStrength;
        List<Map<String, Object>> navicDetails;
        Map<String, EnhancedSatellite> allSatellites;
        Map<String, List<EnhancedSatellite>> satellitesBySystem;
        List<Map<String, Object>> allSatellitesList;

        EnhancedSatelliteScanResult(int navicCount, int navicUsedInFix, int totalSatellites,
                                    float navicSignalStrength, List<Map<String, Object>> navicDetails,
                                    Map<String, EnhancedSatellite> allSatellites,
                                    Map<String, List<EnhancedSatellite>> satellitesBySystem,
                                    List<Map<String, Object>> allSatellitesList) {
            this.navicCount = navicCount;
            this.navicUsedInFix = navicUsedInFix;
            this.totalSatellites = totalSatellites;
            this.navicSignalStrength = navicSignalStrength;
            this.navicDetails = navicDetails;
            this.allSatellites = allSatellites;
            this.satellitesBySystem = satellitesBySystem;
            this.allSatellitesList = allSatellitesList;
        }
    }

    private static class EnhancedL5BandResult {
        boolean hasL5Support = false;
        double confidence = 0.0;
        List<String> detectionMethods = new ArrayList<>();

        Map<String, Object> toMap() {
            Map<String, Object> map = new HashMap<>();
            map.put("hasL5Support", hasL5Support);
            map.put("confidence", confidence);
            map.put("detectionMethods", detectionMethods);
            map.put("detectionMethodCount", detectionMethods.size());
            return map;
        }
    }

    private static class EnhancedHardwareDetectionResult {
        boolean isSupported;
        String detectionMethod;
        double confidenceLevel;
        int verificationScore;
        String chipsetType;
        String chipsetVendor;
        String chipsetModel;
        List<String> verificationMethods;

        EnhancedHardwareDetectionResult(boolean isSupported, String detectionMethod, double confidenceLevel,
                                        int verificationScore, String chipsetType, String chipsetVendor,
                                        String chipsetModel, List<String> verificationMethods) {
            this.isSupported = isSupported;
            this.detectionMethod = detectionMethod;
            this.confidenceLevel = confidenceLevel;
            this.verificationScore = verificationScore;
            this.chipsetType = chipsetType;
            this.chipsetVendor = chipsetVendor;
            this.chipsetModel = chipsetModel;
            this.verificationMethods = verificationMethods;
        }
    }

    private static class EnhancedChipsetResult {
        boolean isSupported;
        double confidence;
        String detectionMethod;
        String chipsetSeries;
        String chipsetModel;
        List<String> verificationMethods;

        EnhancedChipsetResult(boolean isSupported, double confidence, String detectionMethod,
                              String chipsetSeries, String chipsetModel, List<String> verificationMethods) {
            this.isSupported = isSupported;
            this.confidence = confidence;
            this.detectionMethod = detectionMethod;
            this.chipsetSeries = chipsetSeries;
            this.chipsetModel = chipsetModel;
            this.verificationMethods = verificationMethods;
        }
    }

    private static class EnhancedSystemPropertiesResult {
        boolean isSupported;
        double confidence;
        String detectionMethod;
        List<String> verificationMethods;

        EnhancedSystemPropertiesResult(boolean isSupported, double confidence, String detectionMethod,
                                       List<String> verificationMethods) {
            this.isSupported = isSupported;
            this.confidence = confidence;
            this.detectionMethod = detectionMethod;
            this.verificationMethods = verificationMethods;
        }
    }

    private static class EnhancedFeaturesResult {
        boolean isSupported;
        double confidence;
        String detectionMethod;
        List<String> verificationMethods;

        EnhancedFeaturesResult(boolean isSupported, double confidence, String detectionMethod,
                               List<String> verificationMethods) {
            this.isSupported = isSupported;
            this.confidence = confidence;
            this.detectionMethod = detectionMethod;
            this.verificationMethods = verificationMethods;
        }
    }

    private static class EnhancedCPUInfoResult {
        boolean isSupported;
        double confidence;
        String detectionMethod;
        List<String> verificationMethods;
        String vendor;
        String model;

        EnhancedCPUInfoResult(boolean isSupported, double confidence, String detectionMethod,
                              List<String> verificationMethods, String vendor, String model) {
            this.isSupported = isSupported;
            this.confidence = confidence;
            this.detectionMethod = detectionMethod;
            this.verificationMethods = verificationMethods;
            this.vendor = vendor;
            this.model = model;
        }
    }

    private interface EnhancedSatelliteDetectionCallback {
        void onResult(boolean navicDetected, int navicCount, int totalSatellites,
                      int usedInFixCount, double signalStrength,
                      List<Map<String, Object>> satelliteDetails, long acquisitionTime,
                      List<Map<String, Object>> allSatellites, boolean hasL5Band, String primarySystem);
    }
}