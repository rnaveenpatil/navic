package com.example.navic;

import android.content.Context;
import android.content.pm.PackageManager;
import android.location.GnssStatus;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
package com.example.navic;

import android.os.Bundle;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugins.GeneratedPluginRegistrant;



import androidx.annotation.NonNull;
import androidx.core.content.ContextCompat;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

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
    private static final long SATELLITE_DETECTION_TIMEOUT_MS = 25000L;
    private static final long LOCATION_UPDATE_INTERVAL_MS = 1000L;
    private static final float LOCATION_UPDATE_DISTANCE_M = 0.5f;

    // Optimized satellite detection parameters
    private static final float MIN_NAVIC_SIGNAL_STRENGTH = 18.0f;
    private static final int MIN_NAVIC_SATELLITES_FOR_DETECTION = 1;
    private static final long EARLY_SUCCESS_DELAY_MS = 8000L;
    private static final int REQUIRED_CONSECUTIVE_DETECTIONS = 2;

    // L5 Frequency Bands (in MHz)
    private static final Map<String, Double[]> GNSS_FREQUENCIES = new HashMap<String, Double[]>() {{
        put("GPS", new Double[]{1575.42, 1227.60, 1176.45}); // L1, L2, L5
        put("GLONASS", new Double[]{1602.00, 1246.00, 1202.025}); // G1, G2, G3
        put("GALILEO", new Double[]{1575.42, 1207.14, 1176.45}); // E1, E5, E5a
        put("BEIDOU", new Double[]{1561.098, 1207.14, 1176.45}); // B1, B2, B2a
        put("IRNSS", new Double[]{1176.45, 2492.028}); // L5, S-band
        put("QZSS", new Double[]{1575.42, 1227.60, 1176.45}); // L1, L2, L5
    }};

    // Country flags for each GNSS system
    private static final Map<String, String> GNSS_COUNTRIES = new HashMap<String, String>() {{
        put("GPS", "🇺🇸");
        put("GLONASS", "🇷🇺");
        put("GALILEO", "🇪🇺");
        put("BEIDOU", "🇨🇳");
        put("IRNSS", "🇮🇳");
        put("QZSS", "🇯🇵");
        put("SBAS", "🌍");
    }};

    // Complete list of NavIC-supported processors with L5 capability
    private static final Set<String> QUALCOMM_NAVIC_CHIPSETS = new HashSet<>(Arrays.asList(
            "sm7125", "720g",        // Snapdragon 720G
            "sm6115", "662",         // Snapdragon 662
            "sm4250", "sm4350", "460", // Snapdragon 460
            "sm8250", "865",         // Snapdragon 865
            "sm8250-ac", "870",      // Snapdragon 870
            "sm8350", "888",         // Snapdragon 888/888+
            "sm8450", "8 gen 1",     // Snapdragon 8 Gen 1
            "sm8475", "8+ gen 1",    // Snapdragon 8+ Gen 1
            "sm8550", "8 gen 2",     // Snapdragon 8 Gen 2
            "sm8650", "8 gen 3",     // Snapdragon 8 Gen 3
            // Mid-range / upper midrange (L1+L5)
            "sm6225", "680",         // Snapdragon 680
            "sm6350", "690",         // Snapdragon 690
            "sm6375", "695",         // Snapdragon 695
            "sm7150", "732g",        // Snapdragon 732G
            "sm7225", "750g",        // Snapdragon 750G
            "sm7250", "765", "765g", // Snapdragon 765/765G
            "sm7325", "778g", "778g+", // Snapdragon 778G/778G+
            "sm7350", "780g",        // Snapdragon 780G
            "sm7450", "7 gen 1",     // Snapdragon 7 Gen 1
            "sm7475", "7 gen 2",     // Snapdragon 7 Gen 2
            "sm7435", "7s gen 2",    // Snapdragon 7s Gen 2
            "sm6450", "6 gen 1",     // Snapdragon 6 Gen 1
            // IoT / Automotive
            "qcx216", "qcs610", "qcs410", "sa8155p", "820a"
    ));

    private static final Set<String> MEDIATEK_NAVIC_CHIPSETS = new HashSet<>(Arrays.asList(
            "mt6877", "mt6885", "mt6889", "mt6891", "mt6893", "mt6895", "mt6896", "mt6897",
            "mt6983", "mt6985", "mt6875", "mt6873", "mt6855", "mt6857", "mt6833", "mt6785",
            // Dimensity series
            "mt6889", "900", "mt6877", "920", "mt6877", "930", "mt6877", "1080",
            "mt6891", "1100", "mt6893", "1200", "mt6893", "1300", "mt6835", "6100+",
            "mt6835", "7020", "mt6889", "7200", "mt6895", "8000", "mt6895", "8100",
            "mt6896", "8200", "mt6897", "8300", "mt6983", "9000", "mt6983", "9000+",
            "mt6985", "9200", "mt6985", "9200+"
    ));

    private static final Set<String> SAMSUNG_NAVIC_CHIPSETS = new HashSet<>(Arrays.asList(
            "s5e8825", "1280",      // Exynos 1280
            "s5e8835", "1380",      // Exynos 1380
            "s5e8845", "1480",      // Exynos 1480
            "s5e9925", "2200"       // Exynos 2200
    ));

    private LocationManager locationManager;
    private GnssStatus.Callback realtimeCallback;
    private LocationListener locationListener;
    private Handler handler;
    private boolean isTrackingLocation = false;
    private MethodChannel methodChannel;

    // Satellite tracking
    private final Map<Integer, EnhancedSatellite> detectedSatellites = new ConcurrentHashMap<>();
    private final Map<String, List<EnhancedSatellite>> satellitesBySystem = new ConcurrentHashMap<>();
    private final AtomicInteger consecutiveNavicDetections = new AtomicInteger(0);
    private final AtomicBoolean navicDetectionCompleted = new AtomicBoolean(false);
    private boolean hasL5BandSupport = false;

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
                case "startLocationUpdates":
                    startLocationUpdates(result);
                    break;
                case "stopLocationUpdates":
                    stopLocationUpdates(result);
                    break;
                case "getAllSatellites":
                    getAllSatellites(result);
                    break;
                default:
                    Log.w("NavIC", "Unknown method: " + call.method);
                    result.notImplemented();
            }
        });
    }

    private void checkLocationPermissions(MethodChannel.Result result) {
        try {
            boolean hasFineLocation = ContextCompat.checkSelfPermission(
                    this, android.Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED;
            boolean hasCoarseLocation = ContextCompat.checkSelfPermission(
                    this, android.Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED;

            Map<String, Object> permissions = new HashMap<>();
            permissions.put("hasFineLocation", hasFineLocation);
            permissions.put("hasCoarseLocation", hasCoarseLocation);
            permissions.put("allPermissionsGranted", hasFineLocation);

            Log.d("NavIC", "Permission check - Fine Location: " + hasFineLocation + ", Coarse Location: " + hasCoarseLocation);
            result.success(permissions);
        } catch (Exception e) {
            Log.e("NavIC", "Error checking permissions", e);
            result.error("PERMISSION_ERROR", "Failed to check permissions", null);
        }
    }

    private boolean hasLocationPermissions() {
        return ContextCompat.checkSelfPermission(
                this, android.Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED;
    }

    private void checkNavicHardwareSupport(MethodChannel.Result result) {
        Log.d("NavIC", "Starting enhanced NavIC hardware and satellite detection");

        if (!hasLocationPermissions()) {
            result.error("PERMISSION_DENIED", "Location permissions required", null);
            return;
        }

        handler.post(() -> {
            // Step 1: Hardware chipset detection
            HardwareDetectionResult hardwareResult = detectNavicHardwareChipsetOnly();

            // Step 2: L5 Band Detection
            L5BandResult l5Result = detectL5BandSupport();

            // Step 3: Enhanced satellite detection
            detectEnhancedSatellites(hardwareResult, l5Result, (navicDetected, navicCount, totalSatellites,
                                                                usedInFixCount, signalStrength, satelliteDetails, acquisitionTime,
                                                                allSatellites, l5Enabled) -> {

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
                response.put("verificationMethods", hardwareResult.verificationMethods);
                response.put("hasL5Band", l5Enabled);
                response.put("l5BandInfo", l5Result.toMap());
                response.put("allSatellites", allSatellites);

                // Calculate positioning method
                String positioningMethod = determinePositioningMethod(navicDetected, usedInFixCount, allSatellites);
                response.put("positioningMethod", positioningMethod);

                String message = generateDetectionMessage(hardwareResult, navicDetected, navicCount,
                        usedInFixCount, signalStrength, acquisitionTime, l5Enabled);
                response.put("message", message);

                Log.d("NavIC", "Enhanced detection completed: " + message);
                result.success(response);
            });
        });
    }

    /**
     * L5 BAND DETECTION - Check if device supports L5 frequency
     */
    private L5BandResult detectL5BandSupport() {
        Log.d("NavIC", "Starting L5 band detection");
        L5BandResult result = new L5BandResult();

        try {
            // Method 1: Check GNSS capabilities for L5 support
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                Object gnssCaps = locationManager.getGnssCapabilities();
                if (gnssCaps != null) {
                    try {
                        // Check L5 capability
                        Method hasL5Method = gnssCaps.getClass().getMethod("hasL5");
                        Object ret = hasL5Method.invoke(gnssCaps);
                        if (ret instanceof Boolean) {
                            boolean hasL5 = (Boolean) ret;
                            result.hasL5Support = hasL5;
                            result.detectionMethods.add("GNSS_CAPABILITIES_L5");
                            result.confidence = hasL5 ? 0.95 : 0.3;

                            if (hasL5) {
                                Log.d("NavIC", "✅ Device supports L5 band via GNSS Capabilities");
                            } else {
                                Log.d("NavIC", "❌ GNSS Capabilities reports no L5 support");
                            }
                        }
                    } catch (NoSuchMethodException e) {
                        Log.d("NavIC", "GNSSCapabilities.hasL5() not available");
                    }
                }
            }

            // Method 2: Check chipset for L5 capability
            String chipsetInfo = getChipsetInfo().toLowerCase();
            if (chipsetInfo.contains("l5") || chipsetInfo.contains("dual") || chipsetInfo.contains("multi")) {
                result.hasL5Support = true;
                result.detectionMethods.add("CHIPSET_L5_INDICATOR");
                result.confidence = Math.max(result.confidence, 0.85);
                Log.d("NavIC", "✅ Chipset indicates L5 support");
            }

            // Method 3: Check system properties
            try {
                Class<?> systemPropsClass = Class.forName("android.os.SystemProperties");
                Method getMethod = systemPropsClass.getMethod("get", String.class, String.class);

                String[] l5Properties = {
                        "ro.gnss.l5.support",
                        "persist.vendor.gnss.l5",
                        "ro.hardware.gnss.l5",
                        "vendor.gnss.l5.enabled"
                };

                for (String prop : l5Properties) {
                    String value = (String) getMethod.invoke(null, prop, "");
                    if (value.equalsIgnoreCase("true") || value.equalsIgnoreCase("1")) {
                        result.hasL5Support = true;
                        result.detectionMethods.add("SYSTEM_PROPERTY_L5");
                        result.confidence = Math.max(result.confidence, 0.9);
                        Log.d("NavIC", "✅ System property indicates L5 support: " + prop);
                        break;
                    }
                }
            } catch (Exception e) {
                Log.d("NavIC", "Could not access system properties for L5 detection");
            }

            // Set final result
            hasL5BandSupport = result.hasL5Support;
            result.confidence = Math.min(Math.max(result.confidence, 0.0), 1.0);

            Log.d("NavIC", String.format("L5 Detection: Supported=%s, Confidence=%.2f, Methods=%s",
                    result.hasL5Support, result.confidence, result.detectionMethods));

        } catch (Exception e) {
            Log.e("NavIC", "Error in L5 band detection", e);
        }

        return result;
    }

    /**
     * ENHANCED SATELLITE DETECTION - Detect all GNSS satellites with detailed info
     */
    private void detectEnhancedSatellites(HardwareDetectionResult hardwareResult, L5BandResult l5Result,
                                          EnhancedSatelliteDetectionCallback cb) {
        // Reset detection state
        detectedSatellites.clear();
        satellitesBySystem.clear();
        consecutiveNavicDetections.set(0);
        navicDetectionCompleted.set(false);

        final long startTime = System.currentTimeMillis();
        final AtomicInteger detectionAttempts = new AtomicInteger(0);

        Log.d("NavIC", "🚀 Starting enhanced satellite detection (Timeout: " +
                SATELLITE_DETECTION_TIMEOUT_MS/1000 + "s, L5: " + l5Result.hasL5Support + ")");

        try {
            final GnssStatus.Callback[] callbackRef = new GnssStatus.Callback[1];
            callbackRef[0] = new GnssStatus.Callback() {
                @Override
                public void onSatelliteStatusChanged(GnssStatus status) {
                    if (navicDetectionCompleted.get()) return;

                    detectionAttempts.incrementAndGet();
                    long currentTime = System.currentTimeMillis();
                    long elapsedTime = currentTime - startTime;

                    // Process ALL satellites with enhanced information
                    EnhancedSatelliteScanResult scanResult = processAllSatellites(status, elapsedTime, l5Result.hasL5Support);

                    // Update tracking
                    detectedSatellites.putAll(scanResult.allSatellites);
                    satellitesBySystem.putAll(scanResult.satellitesBySystem);

                    // NavIC-specific detection logic
                    if (scanResult.navicCount >= MIN_NAVIC_SATELLITES_FOR_DETECTION) {
                        consecutiveNavicDetections.incrementAndGet();

                        // Quick success for strong signals
                        if (scanResult.navicCount >= 2 && scanResult.navicSignalStrength > 25.0f) {
                            completeEnhancedDetection(true, scanResult, elapsedTime, cb, callbackRef[0]);
                            return;
                        }

                        // Success with consecutive detections
                        if (consecutiveNavicDetections.get() >= REQUIRED_CONSECUTIVE_DETECTIONS) {
                            completeEnhancedDetection(true, scanResult, elapsedTime, cb, callbackRef[0]);
                            return;
                        }
                    } else {
                        consecutiveNavicDetections.set(0); // Reset if no NavIC detected
                    }

                    // Log progress
                    if (detectionAttempts.get() % 5 == 0) {
                        logSatelliteStatus(scanResult, elapsedTime, detectionAttempts.get());
                    }
                }

                @Override
                public void onStarted() {
                    Log.d("NavIC", "🛰️ Enhanced GNSS monitoring started");
                }

                @Override
                public void onStopped() {
                    Log.d("NavIC", "🛰️ Enhanced GNSS monitoring stopped");
                }
            };

            locationManager.registerGnssStatusCallback(callbackRef[0], handler);

            // Early success timer
            handler.postDelayed(() -> {
                if (!navicDetectionCompleted.get()) {
                    EnhancedSatelliteScanResult earlyResult = getCurrentEnhancedScanResult(l5Result.hasL5Support);
                    if (earlyResult.navicCount > 0) {
                        Log.d("NavIC", "🎯 Early detection - NavIC satellites found quickly");
                        completeEnhancedDetection(true, earlyResult, EARLY_SUCCESS_DELAY_MS, cb, callbackRef[0]);
                        return;
                    }
                }
            }, EARLY_SUCCESS_DELAY_MS);

            // Final timeout
            handler.postDelayed(() -> {
                if (!navicDetectionCompleted.get()) {
                    Log.d("NavIC", "⏰ Detection timeout reached");
                    EnhancedSatelliteScanResult finalResult = getCurrentEnhancedScanResult(l5Result.hasL5Support);
                    completeEnhancedDetection(finalResult.navicCount > 0, finalResult,
                            SATELLITE_DETECTION_TIMEOUT_MS, cb, callbackRef[0]);
                }
            }, SATELLITE_DETECTION_TIMEOUT_MS);

        } catch (SecurityException se) {
            Log.e("NavIC", "🔒 Location permission denied for satellite detection");
            cb.onResult(false, 0, 0, 0, 0.0, new ArrayList<>(), 0, new ArrayList<>(), l5Result.hasL5Support);
        } catch (Exception e) {
            Log.e("NavIC", "❌ Failed to register GNSS callback", e);
            cb.onResult(false, 0, 0, 0, 0.0, new ArrayList<>(), 0, new ArrayList<>(), l5Result.hasL5Support);
        }
    }

    /**
     * Process ALL GNSS satellites with enhanced information
     */
    private EnhancedSatelliteScanResult processAllSatellites(GnssStatus status, long elapsedTime, boolean hasL5Support) {
        Map<Integer, EnhancedSatellite> allSats = new ConcurrentHashMap<>();
        Map<String, List<EnhancedSatellite>> satsBySystem = new ConcurrentHashMap<>();

        int navicCount = 0;
        int navicUsedInFix = 0;
        float navicTotalSignal = 0;
        int navicWithSignal = 0;

        int totalSatellites = status.getSatelliteCount();
        List<Map<String, Object>> navicDetails = new ArrayList<>();

        for (int i = 0; i < totalSatellites; i++) {
            int constellation = status.getConstellationType(i);
            String systemName = getConstellationName(constellation);
            String countryFlag = GNSS_COUNTRIES.getOrDefault(systemName, "🌍");

            int svid = status.getSvid(i);
            float cn0 = status.getCn0DbHz(i);
            boolean used = status.usedInFix(i);
            float elevation = status.getElevationDegrees(i);
            float azimuth = status.getAzimuthDegrees(i);
            boolean hasEphemeris = status.hasEphemerisData(i);
            boolean hasAlmanac = status.hasAlmanacData(i);

            // Determine frequency band
            String frequencyBand = determineFrequencyBand(constellation, status, i, hasL5Support);

            // Create enhanced satellite object
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
                    elapsedTime
            );

            // Add to collections - Use satellite.hashCode() as key since getKey() returns String
            allSats.put(satellite.hashCode(), satellite);

            if (!satsBySystem.containsKey(systemName)) {
                satsBySystem.put(systemName, new ArrayList<>());
            }
            satsBySystem.get(systemName).add(satellite);

            // NavIC-specific tracking
            if (constellation == GnssStatus.CONSTELLATION_IRNSS &&
                    svid >= 1 && svid <= 14 && cn0 >= MIN_NAVIC_SIGNAL_STRENGTH) {
                navicCount++;
                if (used) navicUsedInFix++;
                if (cn0 > 0) {
                    navicTotalSignal += cn0;
                    navicWithSignal++;
                }

                Map<String, Object> satInfo = satellite.toDetailedMap();
                navicDetails.add(satInfo);

                if (!detectedSatellites.containsKey(satellite.hashCode())) {
                    Log.d("NavIC", String.format(
                            "✅ NavIC %s SVID-%d - CN0: %.1f dB-Hz, Band: %s, Used: %s",
                            countryFlag, svid, cn0, frequencyBand, used
                    ));
                }
            } else if (cn0 > 0) {
                // Log other strong satellites
                if (!detectedSatellites.containsKey(satellite.hashCode())) {
                    Log.v("NavIC", String.format(
                            "📡 %s %s SVID-%d - CN0: %.1f dB-Hz, Band: %s, Used: %s",
                            countryFlag, systemName, svid, cn0, frequencyBand, used
                    ));
                }
            }
        }

        float navicAvgSignal = navicWithSignal > 0 ? navicTotalSignal / navicWithSignal : 0.0f;

        return new EnhancedSatelliteScanResult(
                navicCount, navicUsedInFix, totalSatellites, navicAvgSignal,
                navicDetails, allSats, satsBySystem
        );
    }

    /**
     * Determine frequency band of satellite
     */
    private String determineFrequencyBand(int constellation, GnssStatus status, int index, boolean hasL5Support) {
        String band = "Unknown";

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                float carrierFreq = status.getCarrierFrequencyHz(index);
                if (carrierFreq > 0) {
                    if (Math.abs(carrierFreq - 1176.45e6) < 5e6) { // L5/E5a/B2a frequency
                        band = "L5";
                    } else if (Math.abs(carrierFreq - 1575.42e6) < 5e6) { // L1/E1/B1 frequency
                        band = "L1";
                    } else if (Math.abs(carrierFreq - 1227.60e6) < 5e6) { // L2 frequency
                        band = "L2";
                    } else if (Math.abs(carrierFreq - 2492.028e6) < 5e6) { // NavIC S-band
                        band = "S";
                    } else {
                        band = String.format("%.0f MHz", carrierFreq / 1e6);
                    }
                }
            } catch (Exception e) {
                // Use default band based on constellation
                band = getDefaultBandForConstellation(constellation, hasL5Support);
            }
        } else {
            band = getDefaultBandForConstellation(constellation, hasL5Support);
        }

        return band;
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

    private EnhancedSatelliteScanResult getCurrentEnhancedScanResult(boolean hasL5Support) {
        int navicCount = 0;
        int navicUsedInFix = 0;
        float navicTotalSignal = 0;
        int navicWithSignal = 0;
        List<Map<String, Object>> navicDetails = new ArrayList<>();

        Map<String, List<EnhancedSatellite>> satsBySystem = new HashMap<>();

        for (EnhancedSatellite sat : detectedSatellites.values()) {
            String systemName = sat.systemName;

            if (!satsBySystem.containsKey(systemName)) {
                satsBySystem.put(systemName, new ArrayList<>());
            }
            satsBySystem.get(systemName).add(sat);

            if ("IRNSS".equals(systemName) && sat.cn0 >= MIN_NAVIC_SIGNAL_STRENGTH) {
                navicCount++;
                if (sat.usedInFix) navicUsedInFix++;
                if (sat.cn0 > 0) {
                    navicTotalSignal += sat.cn0;
                    navicWithSignal++;
                }
                navicDetails.add(sat.toDetailedMap());
            }
        }

        float navicAvgSignal = navicWithSignal > 0 ? navicTotalSignal / navicWithSignal : 0.0f;
        int totalSatellites = detectedSatellites.size();

        return new EnhancedSatelliteScanResult(
                navicCount, navicUsedInFix, totalSatellites, navicAvgSignal,
                navicDetails, detectedSatellites, satsBySystem
        );
    }

    private void completeEnhancedDetection(boolean detected, EnhancedSatelliteScanResult result,
                                           long elapsedTime, EnhancedSatelliteDetectionCallback cb,
                                           GnssStatus.Callback callback) {
        if (navicDetectionCompleted.compareAndSet(false, true)) {
            cleanupCallback(callback);

            // Convert all satellites to map format
            List<Map<String, Object>> allSatellitesList = new ArrayList<>();
            for (EnhancedSatellite sat : result.allSatellites.values()) {
                allSatellitesList.add(sat.toDetailedMap());
            }

            Log.d("NavIC", String.format(
                    "🎯 Enhanced Detection %s - NavIC: %d satellites (%d in fix), " +
                            "Total Systems: %d, Total Sats: %d, Time: %d ms",
                    detected ? "SUCCESS" : "FAILED",
                    result.navicCount, result.navicUsedInFix,
                    result.satellitesBySystem.size(), result.totalSatellites, elapsedTime
            ));

            cb.onResult(detected, result.navicCount, result.totalSatellites,
                    result.navicUsedInFix, result.navicSignalStrength,
                    result.navicDetails, elapsedTime, allSatellitesList, hasL5BandSupport);
        }
    }

    private void logSatelliteStatus(EnhancedSatelliteScanResult result, long elapsedTime, int attempt) {
        StringBuilder logMsg = new StringBuilder();
        logMsg.append(String.format("📡 Scan %d - Time: %d/%d ms\n",
                attempt, elapsedTime, SATELLITE_DETECTION_TIMEOUT_MS));
        logMsg.append(String.format("NavIC: %d (%d in fix), Signal: %.1f dB-Hz\n",
                result.navicCount, result.navicUsedInFix, result.navicSignalStrength));

        for (Map.Entry<String, List<EnhancedSatellite>> entry : result.satellitesBySystem.entrySet()) {
            int systemCount = entry.getValue().size();
            int usedInFix = 0;
            for (EnhancedSatellite sat : entry.getValue()) {
                if (sat.usedInFix) usedInFix++;
            }
            logMsg.append(String.format("%s: %d (%d in fix) ",
                    entry.getKey(), systemCount, usedInFix));
        }

        Log.d("NavIC", logMsg.toString());
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

        for (EnhancedSatellite sat : detectedSatellites.values()) {
            allSatellites.add(sat.toDetailedMap());

            String system = sat.systemName;
            if (!systems.containsKey(system)) {
                Map<String, Object> systemInfo = new HashMap<>();
                systemInfo.put("flag", sat.countryFlag);
                systemInfo.put("name", system);
                systemInfo.put("count", 0);
                systemInfo.put("used", 0);
                systems.put(system, systemInfo);
            }

            Map<String, Object> systemInfo = (Map<String, Object>) systems.get(system);
            systemInfo.put("count", (Integer) systemInfo.get("count") + 1);
            if (sat.usedInFix) {
                systemInfo.put("used", (Integer) systemInfo.get("used") + 1);
            }
        }

        Map<String, Object> response = new HashMap<>();
        response.put("satellites", allSatellites);
        response.put("systems", new ArrayList<>(systems.values()));
        response.put("totalSatellites", allSatellites.size());
        response.put("hasL5Band", hasL5BandSupport);
        response.put("timestamp", System.currentTimeMillis());

        result.success(response);
    }

    /**
     * Determine positioning method based on available satellites
     */
    private String determinePositioningMethod(boolean navicDetected, int navicUsedInFix,
                                              List<Map<String, Object>> allSatellites) {
        if (navicDetected && navicUsedInFix >= 4) {
            return "NAVIC_PRIMARY";
        } else if (navicDetected && navicUsedInFix >= 1) {
            return "NAVIC_HYBRID";
        }

        // Count satellites from other systems
        Map<String, Integer> systemCounts = new HashMap<>();
        for (Map<String, Object> sat : allSatellites) {
            String system = (String) sat.get("system");
            boolean used = (Boolean) sat.get("usedInFix");
            if (used) {
                systemCounts.put(system, systemCounts.getOrDefault(system, 0) + 1);
            }
        }

        // Check which system has enough satellites for positioning
        for (Map.Entry<String, Integer> entry : systemCounts.entrySet()) {
            if (entry.getValue() >= 4) {
                return entry.getKey() + "_PRIMARY";
            }
        }

        // Check for hybrid positioning
        int totalUsed = 0;
        for (Integer count : systemCounts.values()) {
            totalUsed += count;
        }

        if (totalUsed >= 4) {
            return "MULTI_GNSS_HYBRID";
        }

        return "INSUFFICIENT_SATELLITES";
    }

    private String generateDetectionMessage(HardwareDetectionResult hardwareResult, boolean navicDetected,
                                            int navicCount, int usedInFix, double signalStrength,
                                            long acquisitionTime, boolean l5Enabled) {
        StringBuilder message = new StringBuilder();

        if (!hardwareResult.isSupported) {
            message.append("Device chipset does not support NavIC. Using standard GPS.");
        } else {
            if (navicDetected) {
                message.append(String.format(
                        "✅ Chipset supports NavIC and %d NavIC satellites detected (%d used in fix). " +
                                "Signal: %.1f dB-Hz, Acquisition: %d ms",
                        navicCount, usedInFix, signalStrength, acquisitionTime
                ));
                if (l5Enabled) {
                    message.append(" (L5 Band Enabled)");
                }
            } else {
                message.append(String.format(
                        "⚠️ Chipset supports NavIC, but no NavIC satellites acquired in %d seconds.",
                        acquisitionTime / 1000
                ));
            }
        }

        return message.toString();
    }

    // Hardware detection methods
    private HardwareDetectionResult detectNavicHardwareChipsetOnly() {
        Log.d("NavIC", "Starting chipset-only NavIC hardware detection");

        List<String> detectionMethods = new ArrayList<>();
        double confidenceScore = 0.0;
        int verificationCount = 0;
        String chipsetType = "UNKNOWN";

        // Method 1: GnssCapabilities.hasIrnss() - Most reliable (API 30+)
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
                                confidenceScore += 0.98;
                                verificationCount++;
                                chipsetType = "API_VERIFIED";
                                Log.d("NavIC", "✅ Hardware supports NavIC via GnssCapabilities.hasIrnss()");
                            } else {
                                Log.d("NavIC", "❌ GnssCapabilities reports no NavIC support");
                                confidenceScore -= 0.4;
                            }
                        }
                    } catch (NoSuchMethodException ns) {
                        Log.d("NavIC", "GnssCapabilities.hasIrnss() not available");
                    }
                }
            } catch (Exception e) {
                Log.e("NavIC", "Error accessing GnssCapabilities", e);
            }
        }

        // Method 2: Advanced Qualcomm chipset detection
        ChipsetDetectionResult qualcommResult = detectQualcommNavicAdvanced();
        if (qualcommResult.isSupported) {
            detectionMethods.add(qualcommResult.detectionMethod);
            confidenceScore += qualcommResult.confidence;
            verificationCount++;
            chipsetType = "QUALCOMM_" + qualcommResult.chipsetSeries;
        }

        // Method 3: Advanced MediaTek chipset detection
        ChipsetDetectionResult mediatekResult = detectMediatekNavicAdvanced();
        if (mediatekResult.isSupported) {
            detectionMethods.add(mediatekResult.detectionMethod);
            confidenceScore += mediatekResult.confidence;
            verificationCount++;
            chipsetType = "MEDIATEK_" + mediatekResult.chipsetSeries;
        }

        // Method 4: Comprehensive System Properties analysis
        SystemPropertiesResult propsResult = checkSystemPropertiesComprehensive();
        if (propsResult.isSupported) {
            detectionMethods.add(propsResult.detectionMethod);
            confidenceScore += propsResult.confidence;
            verificationCount++;
            if (chipsetType.equals("UNKNOWN")) {
                chipsetType = "SYSTEM_PROPERTY_INDICATED";
            }
        }

        // Method 5: GNSS Hardware Features detection
        GnssFeaturesResult featuresResult = checkGnssHardwareFeatures();
        if (featuresResult.isSupported) {
            detectionMethods.add(featuresResult.detectionMethod);
            confidenceScore += featuresResult.confidence;
            verificationCount++;
        }

        // Calculate final confidence level
        double finalConfidence;
        if (verificationCount > 0) {
            finalConfidence = Math.max(0.0, Math.min(1.0, confidenceScore / verificationCount));
        } else {
            finalConfidence = 0.0;
        }

        boolean isSupported = finalConfidence >= 0.5;

        String methodString = detectionMethods.isEmpty() ? "NO_CHIPSET_EVIDENCE" :
                String.join("+", detectionMethods);

        Log.d("NavIC", String.format(
                "Chipset-only detection: Supported=%s, Confidence=%.2f, Methods=%s, Chipset=%s",
                isSupported, finalConfidence, methodString, chipsetType
        ));

        return new HardwareDetectionResult(
                isSupported,
                methodString,
                finalConfidence,
                verificationCount,
                chipsetType,
                detectionMethods
        );
    }

    private ChipsetDetectionResult detectQualcommNavicAdvanced() {
        try {
            String boardPlatform = Build.BOARD.toLowerCase();
            String hardware = Build.HARDWARE.toLowerCase();
            String socModel = getSoCModel().toLowerCase();

            Log.d("NavIC", "Advanced Qualcomm detection - Board: " + boardPlatform +
                    ", Hardware: " + hardware + ", SoC: " + socModel);

            boolean isQualcomm = boardPlatform.matches(".*(msm|sdm|sm|qcs|qcm|sdw|qmd)[0-9].*") ||
                    hardware.matches(".*(qcom|qualcomm).*") ||
                    (socModel != null && socModel.matches(".*(msm|sdm|sm|qcs).*"));

            if (!isQualcomm) {
                return new ChipsetDetectionResult(false, 0.0, "NOT_QUALCOMM", "");
            }

            Log.d("NavIC", "Qualcomm architecture detected, analyzing NavIC capability...");

            for (String chipset : QUALCOMM_NAVIC_CHIPSETS) {
                if (boardPlatform.contains(chipset) || hardware.contains(chipset) ||
                        (socModel != null && socModel.contains(chipset))) {
                    Log.d("NavIC", "✅ NavIC-supported Qualcomm chipset identified: " + chipset);
                    return new ChipsetDetectionResult(true, 0.9, "QUALCOMM_EXACT_MATCH", getChipsetSeries(chipset));
                }
            }

            if (boardPlatform.matches(".*sm8[0-9]{3}.*")) {
                Log.d("NavIC", "✅ Qualcomm Snapdragon 8 series - High NavIC probability");
                return new ChipsetDetectionResult(true, 0.85, "QUALCOMM_8_SERIES", "8_SERIES");
            }
            if (boardPlatform.matches(".*sm7[0-9]{3}.*")) {
                Log.d("NavIC", "✅ Qualcomm Snapdragon 7 series - Medium NavIC probability");
                return new ChipsetDetectionResult(true, 0.75, "QUALCOMM_7_SERIES", "7_SERIES");
            }
            if (boardPlatform.matches(".*sm6[0-9]{3}.*")) {
                Log.d("NavIC", "✅ Qualcomm Snapdragon 6 series - Medium NavIC probability");
                return new ChipsetDetectionResult(true, 0.7, "QUALCOMM_6_SERIES", "6_SERIES");
            }
            if (boardPlatform.matches(".*sm4[0-9]{3}.*")) {
                Log.d("NavIC", "✅ Qualcomm Snapdragon 4 series - Low NavIC probability");
                return new ChipsetDetectionResult(true, 0.6, "QUALCOMM_4_SERIES", "4_SERIES");
            }

            Log.d("NavIC", "⚠️ Generic Qualcomm detected - Limited NavIC information");
            return new ChipsetDetectionResult(true, 0.4, "QUALCOMM_GENERIC", "GENERIC");

        } catch (Exception e) {
            Log.e("NavIC", "Error in advanced Qualcomm detection", e);
        }
        return new ChipsetDetectionResult(false, 0.0, "QUALCOMM_UNDETECTED", "");
    }

    private ChipsetDetectionResult detectMediatekNavicAdvanced() {
        try {
            String hardware = Build.HARDWARE.toLowerCase();
            String boardPlatform = Build.BOARD.toLowerCase();
            String socModel = getSoCModel().toLowerCase();

            Log.d("NavIC", "Advanced MediaTek detection - Hardware: " + hardware +
                    ", Board: " + boardPlatform + ", SoC: " + socModel);

            boolean isMediatek = hardware.matches(".*mt[0-9].*") ||
                    boardPlatform.matches(".*mt[0-9].*") ||
                    (socModel != null && socModel.matches(".*mt[0-9].*"));

            if (!isMediatek) {
                return new ChipsetDetectionResult(false, 0.0, "NOT_MEDIATEK", "");
            }

            Log.d("NavIC", "MediaTek architecture detected, analyzing NavIC capability...");

            for (String chipset : MEDIATEK_NAVIC_CHIPSETS) {
                if (hardware.contains(chipset) || boardPlatform.contains(chipset) ||
                        (socModel != null && socModel.contains(chipset))) {
                    Log.d("NavIC", "✅ NavIC-supported MediaTek chipset identified: " + chipset);
                    return new ChipsetDetectionResult(true, 0.88, "MEDIATEK_EXACT_MATCH", getChipsetSeries(chipset));
                }
            }

            if (hardware.matches(".*mt69[0-9]{2}.*") || boardPlatform.matches(".*mt69[0-9]{2}.*")) {
                Log.d("NavIC", "✅ MediaTek Dimensity 9000 series - High NavIC probability");
                return new ChipsetDetectionResult(true, 0.9, "MEDIATEK_DIMENSITY_9000", "DIMENSITY_9000");
            }
            if (hardware.matches(".*mt68[0-9]{2}.*") || boardPlatform.matches(".*mt68[0-9]{2}.*")) {
                Log.d("NavIC", "✅ MediaTek Dimensity 8000/7000 series - High NavIC probability");
                return new ChipsetDetectionResult(true, 0.85, "MEDIATEK_DIMENSITY_8000", "DIMENSITY_8000");
            }
            if (hardware.matches(".*mt67[0-9]{2}.*") || boardPlatform.matches(".*mt67[0-9]{2}.*")) {
                Log.d("NavIC", "✅ MediaTek Dimensity/Helio series - Medium NavIC probability");
                return new ChipsetDetectionResult(true, 0.7, "MEDIATEK_DIMENSITY_HELIO", "DIMENSITY_HELIO");
            }

            Log.d("NavIC", "⚠️ Generic MediaTek detected - Limited NavIC information");
            return new ChipsetDetectionResult(true, 0.3, "MEDIATEK_GENERIC", "GENERIC");

        } catch (Exception e) {
            Log.e("NavIC", "Error in advanced MediaTek detection", e);
        }
        return new ChipsetDetectionResult(false, 0.0, "MEDIATEK_UNDETECTED", "");
    }

    private SystemPropertiesResult checkSystemPropertiesComprehensive() {
        try {
            Class<?> systemPropsClass = Class.forName("android.os.SystemProperties");
            Method getMethod = systemPropsClass.getMethod("get", String.class, String.class);

            String[][] gnssProperties = {
                    {"ro.gnss.sv_status", "0.8"},
                    {"persist.vendor.radio.aosp_gnss", "0.75"},
                    {"persist.vendor.gnss.hardware", "0.85"},
                    {"ro.board.gnss", "0.7"},
                    {"ro.hardware.gnss", "0.7"},
                    {"ro.vendor.gnss.hardware", "0.8"},
                    {"vendor.gnss.hardware", "0.8"},
                    {"ro.gnss.hardware", "0.7"},
                    {"persist.sys.gps.lpp", "0.6"},
                    {"ro.gps.agps_protocol", "0.5"}
            };

            for (String[] prop : gnssProperties) {
                String value = (String) getMethod.invoke(null, prop[0], "");
                if (!value.isEmpty()) {
                    Log.d("NavIC", "System property " + prop[0] + " = " + value);
                    if (value.toLowerCase().contains("irnss") || value.toLowerCase().contains("navic")) {
                        double confidence = Double.parseDouble(prop[1]);
                        Log.d("NavIC", "✅ NavIC support confirmed in system property: " + prop[0]);
                        return new SystemPropertiesResult(true, confidence, "SYSTEM_PROPERTY_IRNSS");
                    }
                }
            }

            String[] featureProperties = {
                    "ro.hardware.gnss.features", "vendor.gnss.features",
                    "ro.gnss.features", "persist.vendor.gnss.features"
            };

            for (String prop : featureProperties) {
                String features = (String) getMethod.invoke(null, prop, "");
                if (features.toLowerCase().contains("irnss")) {
                    Log.d("NavIC", "✅ NavIC support in GNSS features: " + prop + " = " + features);
                    return new SystemPropertiesResult(true, 0.9, "GNSS_FEATURES_IRNSS");
                }
            }

        } catch (Exception e) {
            Log.d("NavIC", "System properties access limited (normal behavior)");
        }
        return new SystemPropertiesResult(false, 0.0, "NO_NAVIC_PROPERTIES");
    }

    private GnssFeaturesResult checkGnssHardwareFeatures() {
        try {
            boolean hasGnssFeature = getPackageManager().hasSystemFeature(PackageManager.FEATURE_LOCATION_GPS);

            if (hasGnssFeature) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    boolean hasGnssMetadata = locationManager.hasProvider(LocationManager.GPS_PROVIDER);
                    if (hasGnssMetadata) {
                        Log.d("NavIC", "✅ Advanced GNSS hardware features detected");
                        return new GnssFeaturesResult(true, 0.6, "ADVANCED_GNSS_FEATURES");
                    }
                }
            }

        } catch (Exception e) {
            Log.e("NavIC", "Error checking GNSS features", e);
        }
        return new GnssFeaturesResult(false, 0.0, "BASIC_GNSS_ONLY");
    }

    private void getGnssCapabilities(MethodChannel.Result result) {
        Log.d("NavIC", "Getting GNSS capabilities");
        Map<String, Object> caps = new HashMap<>();
        try {
            caps.put("androidVersion", Build.VERSION.SDK_INT);
            caps.put("manufacturer", Build.MANUFACTURER);
            caps.put("model", Build.MODEL);
            caps.put("device", Build.DEVICE);
            caps.put("hardware", Build.HARDWARE);
            caps.put("board", Build.BOARD);

            boolean hasGnssFeature = getPackageManager().hasSystemFeature(PackageManager.FEATURE_LOCATION_GPS);
            caps.put("hasGnssFeature", hasGnssFeature);

            Map<String, Object> gnssMap = new HashMap<>();
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                try {
                    Object gnssCaps = locationManager.getGnssCapabilities();
                    if (gnssCaps != null) {
                        try {
                            Method hasIrnss = gnssCaps.getClass().getMethod("hasIrnss");
                            Object v = hasIrnss.invoke(gnssCaps);
                            if (v instanceof Boolean) {
                                gnssMap.put("hasIrnss", (Boolean) v);
                                Log.d("NavIC", "GnssCapabilities.hasIrnss: " + v);
                            }
                        } catch (NoSuchMethodException ignore) {
                            gnssMap.put("hasIrnss", false);
                        }
                    }
                } catch (Throwable t) {
                    Log.e("NavIC", "Error getting GNSS capabilities", t);
                    gnssMap.put("hasIrnss", false);
                }
            } else {
                gnssMap.put("hasIrnss", false);
            }

            caps.put("gnssCapabilities", gnssMap);
            caps.put("capabilitiesMethod", "ENHANCED_HARDWARE_DETECTION");

            Log.d("NavIC", "GNSS capabilities retrieved successfully");
            result.success(caps);
        } catch (Exception e) {
            Log.e("NavIC", "Failed to get GNSS capabilities", e);
            result.error("CAPABILITIES_ERROR", "Failed to get GNSS capabilities", null);
        }
    }

    private void startRealTimeNavicDetection(MethodChannel.Result result) {
        Log.d("NavIC", "Starting real-time NavIC detection");

        if (!hasLocationPermissions()) {
            result.error("PERMISSION_DENIED", "Location permissions required", null);
            return;
        }

        stopRealTimeDetection();

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
                Log.d("NavIC", "Real-time GNSS monitoring started");
            }

            @Override
            public void onStopped() {
                Log.d("NavIC", "Real-time GNSS monitoring stopped");
            }
        };

        try {
            locationManager.registerGnssStatusCallback(realtimeCallback, handler);
            Map<String, Object> resp = new HashMap<>();
            resp.put("success", true);
            resp.put("message", "Real-time NavIC detection started");
            resp.put("hasL5Band", hasL5BandSupport);
            Log.d("NavIC", "Real-time detection started successfully");
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

        for (int i = 0; i < status.getSatelliteCount(); i++) {
            int constellationType = status.getConstellationType(i);
            String constellationName = getConstellationName(constellationType);
            String countryFlag = GNSS_COUNTRIES.getOrDefault(constellationName, "🌍");

            int svid = status.getSvid(i);
            float cn0 = status.getCn0DbHz(i);
            boolean used = status.usedInFix(i);
            float elevation = status.getElevationDegrees(i);
            float azimuth = status.getAzimuthDegrees(i);

            // Update counts
            switch (constellationType) {
                case GnssStatus.CONSTELLATION_IRNSS:
                    irnssCount++;
                    if (used) irnssUsedInFix++;
                    break;
                case GnssStatus.CONSTELLATION_GPS:
                    gpsCount++; if (used) gpsUsedInFix++; break;
                case GnssStatus.CONSTELLATION_GLONASS:
                    glonassCount++; if (used) glonassUsedInFix++; break;
                case GnssStatus.CONSTELLATION_GALILEO:
                    galileoCount++; if (used) galileoUsedInFix++; break;
                case GnssStatus.CONSTELLATION_BEIDOU:
                    beidouCount++; if (used) beidouUsedInFix++; break;
                case GnssStatus.CONSTELLATION_QZSS:
                    qzssCount++; break;
                case GnssStatus.CONSTELLATION_SBAS:
                    sbasCount++; break;
            }

            // Determine frequency band
            String frequencyBand = determineFrequencyBand(constellationType, status, i, hasL5BandSupport);

            Map<String, Object> sat = new HashMap<>();
            sat.put("constellation", constellationName);
            sat.put("countryFlag", countryFlag);
            sat.put("svid", svid);
            sat.put("cn0DbHz", cn0);
            sat.put("elevation", elevation);
            sat.put("azimuth", azimuth);
            sat.put("hasEphemeris", status.hasEphemerisData(i));
            sat.put("hasAlmanac", status.hasAlmanacData(i));
            sat.put("usedInFix", used);
            sat.put("frequencyBand", frequencyBand);

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                try {
                    float freq = status.getCarrierFrequencyHz(i);
                    sat.put("carrierFrequencyHz", freq);
                } catch (Throwable ignored) {}
            }

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

        // System statistics
        systemStats.put("IRNSS", createSystemStat("IRNSS", "🇮🇳", irnssCount, irnssUsedInFix));
        systemStats.put("GPS", createSystemStat("GPS", "🇺🇸", gpsCount, gpsUsedInFix));
        systemStats.put("GLONASS", createSystemStat("GLONASS", "🇷🇺", glonassCount, glonassUsedInFix));
        systemStats.put("GALILEO", createSystemStat("GALILEO", "🇪🇺", galileoCount, galileoUsedInFix));
        systemStats.put("BEIDOU", createSystemStat("BEIDOU", "🇨🇳", beidouCount, beidouUsedInFix));

        String primarySystem = determinePrimarySystem(irnssUsedInFix, gpsUsedInFix, glonassUsedInFix,
                galileoUsedInFix, beidouUsedInFix);

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
        result.put("primarySystem", primarySystem);
        result.put("hasL5Band", hasL5BandSupport);
        result.put("locationProvider", primarySystem + (hasL5BandSupport ? "_L5" : ""));

        Log.d("NavIC", String.format(
                "Enhanced Update - Primary: %s, NavIC: %d(%d), GPS: %d(%d), Total: %d, L5: %s",
                primarySystem, irnssCount, irnssUsedInFix, gpsCount, gpsUsedInFix,
                status.getSatelliteCount(), hasL5BandSupport ? "Yes" : "No"
        ));

        return result;
    }

    private Map<String, Object> createSystemStat(String name, String flag, int total, int used) {
        Map<String, Object> stat = new HashMap<>();
        stat.put("name", name);
        stat.put("flag", flag);
        stat.put("total", total);
        stat.put("used", used);
        stat.put("available", total - used);
        return stat;
    }

    private String determinePrimarySystem(int irnssUsed, int gpsUsed, int glonassUsed,
                                          int galileoUsed, int beidouUsed) {
        if (irnssUsed >= 4) return "NAVIC";
        if (gpsUsed >= 4) return "GPS";
        if (glonassUsed >= 4) return "GLONASS";
        if (galileoUsed >= 4) return "GALILEO";
        if (beidouUsed >= 4) return "BEIDOU";

        // Hybrid positioning
        int totalUsed = irnssUsed + gpsUsed + glonassUsed + galileoUsed + beidouUsed;
        if (totalUsed >= 4) {
            if (irnssUsed > 0) return "NAVIC_HYBRID";
            return "MULTI_GNSS";
        }

        return "INSUFFICIENT";
    }

    private void stopRealTimeDetection(MethodChannel.Result result) {
        Log.d("NavIC", "Stopping real-time detection");
        try {
            if (realtimeCallback != null) {
                locationManager.unregisterGnssStatusCallback(realtimeCallback);
                realtimeCallback = null;
                Log.d("NavIC", "Real-time detection stopped");
            }
        } catch (Exception e) {
            Log.e("NavIC", "Error stopping real-time detection", e);
        }

        if (result != null) {
            Map<String, Object> resp = new HashMap<>();
            resp.put("success", true);
            resp.put("message", "Real-time detection stopped");
            result.success(resp);
        }
    }

    private void stopRealTimeDetection() {
        stopRealTimeDetection(null);
    }

    private void startLocationUpdates(MethodChannel.Result result) {
        Log.d("NavIC", "Starting location updates");

        if (!hasLocationPermissions()) {
            result.error("PERMISSION_DENIED", "Location permissions required", null);
            return;
        }

        stopLocationUpdates();

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
            locationManager.requestLocationUpdates(
                    LocationManager.GPS_PROVIDER,
                    LOCATION_UPDATE_INTERVAL_MS,
                    LOCATION_UPDATE_DISTANCE_M,
                    locationListener,
                    handler.getLooper()
            );

            locationManager.requestLocationUpdates(
                    LocationManager.NETWORK_PROVIDER,
                    LOCATION_UPDATE_INTERVAL_MS,
                    LOCATION_UPDATE_DISTANCE_M,
                    locationListener,
                    handler.getLooper()
            );

            isTrackingLocation = true;

            Map<String, Object> resp = new HashMap<>();
            resp.put("success", true);
            resp.put("message", "Location updates started");
            Log.d("NavIC", "Location updates started successfully");
            result.success(resp);

        } catch (SecurityException se) {
            Log.e("NavIC", "Permission error starting location updates", se);
            result.error("PERMISSION_ERROR", "Location permissions required", null);
        } catch (Exception e) {
            Log.e("NavIC", "Error starting location updates", e);
            result.error("LOCATION_ERROR", "Failed to start location updates: " + e.getMessage(), null);
        }
    }

    private void stopLocationUpdates(MethodChannel.Result result) {
        Log.d("NavIC", "Stopping location updates");
        stopLocationUpdates();
        if (result != null) {
            Map<String, Object> resp = new HashMap<>();
            resp.put("success", true);
            resp.put("message", "Location updates stopped");
            result.success(resp);
        }
    }

    private void stopLocationUpdates() {
        if (locationListener != null) {
            locationManager.removeUpdates(locationListener);
            locationListener = null;
            isTrackingLocation = false;
            Log.d("NavIC", "Location updates stopped");
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

            return socModel.toLowerCase();
        } catch (Exception e) {
            return Build.HARDWARE.toLowerCase();
        }
    }

    private String getChipsetSeries(String chipset) {
        if (chipset.startsWith("sm8") || chipset.startsWith("mt69")) return "FLAGSHIP";
        if (chipset.startsWith("sm7") || chipset.startsWith("mt68")) return "HIGH_END";
        if (chipset.startsWith("sm6") || chipset.startsWith("mt67")) return "MID_RANGE";
        if (chipset.startsWith("sm4")) return "ENTRY_LEVEL";
        return "UNKNOWN";
    }

    private String getChipsetInfo() {
        try {
            Class<?> systemPropsClass = Class.forName("android.os.SystemProperties");
            Method getMethod = systemPropsClass.getMethod("get", String.class, String.class);

            String[] chipsetProps = {
                    "ro.board.platform",
                    "ro.hardware",
                    "ro.mediatek.platform",
                    "ro.chipset",
                    "vendor.gnss.chipset"
            };

            for (String prop : chipsetProps) {
                String value = (String) getMethod.invoke(null, prop, "");
                if (!value.isEmpty()) {
                    return value.toLowerCase();
                }
            }
        } catch (Exception e) {
            Log.d("NavIC", "Could not access chipset info");
        }

        return Build.HARDWARE.toLowerCase();
    }

    private String getConstellationName(int constellationType) {
        switch (constellationType) {
            case GnssStatus.CONSTELLATION_IRNSS: return "IRNSS";
            case GnssStatus.CONSTELLATION_GPS: return "GPS";
            case GnssStatus.CONSTELLATION_GLONASS: return "GLONASS";
            case GnssStatus.CONSTELLATION_GALILEO: return "GALILEO";
            case GnssStatus.CONSTELLATION_BEIDOU: return "BEIDOU";
            case GnssStatus.CONSTELLATION_QZSS: return "QZSS";
            case GnssStatus.CONSTELLATION_SBAS: return "SBAS";
            default: return "UNKNOWN";
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

    // Optimized satellite detection data classes
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
        long detectionTime;
        int detectionCount;

        EnhancedSatellite(int svid, String systemName, int constellation, String countryFlag,
                          float cn0, boolean usedInFix, float elevation, float azimuth,
                          boolean hasEphemeris, boolean hasAlmanac, String frequencyBand,
                          long detectionTime) {
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
            this.detectionTime = detectionTime;
            this.detectionCount = 1;
        }

        String getKey() {
            return systemName + "_" + svid;
        }

        Map<String, Object> toDetailedMap() {
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
            map.put("detectionTime", detectionTime);
            map.put("detectionCount", detectionCount);
            map.put("signalStrength", getSignalStrengthLevel());
            return map;
        }

        String getSignalStrengthLevel() {
            if (cn0 >= 35) return "EXCELLENT";
            if (cn0 >= 25) return "GOOD";
            if (cn0 >= 18) return "FAIR";
            return "WEAK";
        }
    }

    private static class EnhancedSatelliteScanResult {
        int navicCount;
        int navicUsedInFix;
        int totalSatellites;
        float navicSignalStrength;
        List<Map<String, Object>> navicDetails;
        Map<Integer, EnhancedSatellite> allSatellites;
        Map<String, List<EnhancedSatellite>> satellitesBySystem;

        EnhancedSatelliteScanResult(int navicCount, int navicUsedInFix, int totalSatellites,
                                    float navicSignalStrength, List<Map<String, Object>> navicDetails,
                                    Map<Integer, EnhancedSatellite> allSatellites,
                                    Map<String, List<EnhancedSatellite>> satellitesBySystem) {
            this.navicCount = navicCount;
            this.navicUsedInFix = navicUsedInFix;
            this.totalSatellites = totalSatellites;
            this.navicSignalStrength = navicSignalStrength;
            this.navicDetails = navicDetails;
            this.allSatellites = allSatellites;
            this.satellitesBySystem = satellitesBySystem;
        }
    }

    private static class L5BandResult {
        boolean hasL5Support = false;
        double confidence = 0.0;
        List<String> detectionMethods = new ArrayList<>();

        Map<String, Object> toMap() {
            Map<String, Object> map = new HashMap<>();
            map.put("hasL5Support", hasL5Support);
            map.put("confidence", confidence);
            map.put("detectionMethods", detectionMethods);
            return map;
        }
    }

    // Data classes for detection results
    private static class HardwareDetectionResult {
        boolean isSupported;
        String detectionMethod;
        double confidenceLevel;
        int verificationScore;
        String chipsetType;
        List<String> verificationMethods;

        HardwareDetectionResult(boolean isSupported, String detectionMethod, double confidenceLevel,
                                int verificationScore, String chipsetType, List<String> verificationMethods) {
            this.isSupported = isSupported;
            this.detectionMethod = detectionMethod;
            this.confidenceLevel = confidenceLevel;
            this.verificationScore = verificationScore;
            this.chipsetType = chipsetType;
            this.verificationMethods = verificationMethods;
        }
    }

    private static class ChipsetDetectionResult {
        boolean isSupported;
        double confidence;
        String detectionMethod;
        String chipsetSeries;

        ChipsetDetectionResult(boolean isSupported, double confidence, String detectionMethod, String chipsetSeries) {
            this.isSupported = isSupported;
            this.confidence = confidence;
            this.detectionMethod = detectionMethod;
            this.chipsetSeries = chipsetSeries;
        }
    }

    private static class SystemPropertiesResult {
        boolean isSupported;
        double confidence;
        String detectionMethod;

        SystemPropertiesResult(boolean isSupported, double confidence, String detectionMethod) {
            this.isSupported = isSupported;
            this.confidence = confidence;
            this.detectionMethod = detectionMethod;
        }
    }

    private static class GnssFeaturesResult {
        boolean isSupported;
        double confidence;
        String detectionMethod;

        GnssFeaturesResult(boolean isSupported, double confidence, String detectionMethod) {
            this.isSupported = isSupported;
            this.confidence = confidence;
            this.detectionMethod = detectionMethod;
        }
    }

    private interface EnhancedSatelliteDetectionCallback {
        void onResult(boolean navicDetected, int navicCount, int totalSatellites,
                      int usedInFixCount, double signalStrength,
                      List<Map<String, Object>> satelliteDetails, long acquisitionTime,
                      List<Map<String, Object>> allSatellites, boolean hasL5Band);
    }
}