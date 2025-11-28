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
    private static final long SATELLITE_DETECTION_TIMEOUT_MS = 25000L; // Reduced from 60s to 25s
    private static final long LOCATION_UPDATE_INTERVAL_MS = 1000L;
    private static final float LOCATION_UPDATE_DISTANCE_M = 0.5f;
    
    // Optimized satellite detection parameters
    private static final float MIN_NAVIC_SIGNAL_STRENGTH = 18.0f; // Minimum CN0 for valid NavIC signal
    private static final int MIN_NAVIC_SATELLITES_FOR_DETECTION = 1; // Reduced from 2 to 1
    private static final long EARLY_SUCCESS_DELAY_MS = 8000L; // Early detection after 8 seconds
    private static final int REQUIRED_CONSECUTIVE_DETECTIONS = 2; // Confirm detection across multiple updates

    // Complete list of NavIC-supported processors (unchanged from previous version)
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
            // All L1+L5 GNSS chipsets
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

    // Optimized satellite detection tracking
    private final Map<Integer, NavicSatellite> detectedNavicSatellites = new ConcurrentHashMap<>();
    private final AtomicInteger consecutiveNavicDetections = new AtomicInteger(0);
    private final AtomicBoolean navicDetectionCompleted = new AtomicBoolean(false);

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
        Log.d("NavIC", "Starting optimized NavIC hardware and satellite detection");

        if (!hasLocationPermissions()) {
            result.error("PERMISSION_DENIED", "Location permissions required", null);
            return;
        }

        handler.post(() -> {
            HardwareDetectionResult hardwareResult = detectNavicHardwareChipsetOnly();

            detectNavicSatellitesOptimized(hardwareResult, (navicDetected, navicCount, totalSatellites,
                                                           usedInFixCount, signalStrength, satelliteDetails, acquisitionTime) -> {

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

                String message;
                if (!hardwareResult.isSupported) {
                    message = "Device chipset does not support NavIC. Using standard GPS.";
                } else {
                    if (navicDetected) {
                        message = String.format(
                                "✅ Chipset supports NavIC and %d NavIC satellites detected (%d used in fix). " +
                                        "Signal: %.1f dB-Hz, Acquisition: %d ms",
                                navicCount, usedInFixCount, signalStrength, acquisitionTime
                        );
                    } else {
                        message = String.format(
                                "⚠️ Chipset supports NavIC, but no NavIC satellites acquired in %d seconds.",
                                acquisitionTime / 1000
                        );
                    }
                }
                response.put("message", message);

                Log.d("NavIC", "Optimized detection completed: " + message);
                result.success(response);
            });
        });
    }

    /**
     * OPTIMIZED SATELLITE DETECTION - Faster and more reliable NavIC detection
     */
    private void detectNavicSatellitesOptimized(HardwareDetectionResult hardwareResult,
                                               EnhancedSatelliteDetectionCallback cb) {
        // Reset detection state
        detectedNavicSatellites.clear();
        consecutiveNavicDetections.set(0);
        navicDetectionCompleted.set(false);
        
        final long startTime = System.currentTimeMillis();
        final AtomicInteger detectionAttempts = new AtomicInteger(0);

        Log.d("NavIC", "🚀 Starting optimized NavIC satellite detection (Timeout: " + 
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

                    // Process satellite data with optimized logic
                    SatelliteScanResult scanResult = processSatellitesOptimized(status, elapsedTime);
                    
                    // Early success conditions
                    if (scanResult.navicCount >= MIN_NAVIC_SATELLITES_FOR_DETECTION) {
                        consecutiveNavicDetections.incrementAndGet();
                        
                        // Quick success for strong signals
                        if (scanResult.navicCount >= 2 && scanResult.averageSignalStrength > 25.0f) {
                            completeDetection(true, scanResult, elapsedTime, cb, callbackRef[0]);
                            return;
                        }
                        
                        // Success with consecutive detections
                        if (consecutiveNavicDetections.get() >= REQUIRED_CONSECUTIVE_DETECTIONS) {
                            completeDetection(true, scanResult, elapsedTime, cb, callbackRef[0]);
                            return;
                        }
                    } else {
                        consecutiveNavicDetections.set(0); // Reset if no NavIC detected
                    }

                    // Log progress periodically (less frequent to reduce overhead)
                    if (detectionAttempts.get() % 5 == 0) {
                        Log.d("NavIC", String.format(
                                "📡 Scan %d - Time: %d/%d ms, NavIC: %d (%d in fix), Signal: %.1f dB-Hz",
                                detectionAttempts.get(), elapsedTime, SATELLITE_DETECTION_TIMEOUT_MS,
                                scanResult.navicCount, scanResult.usedInFix, scanResult.averageSignalStrength
                        ));
                    }
                }

                @Override
                public void onStarted() {
                    Log.d("NavIC", "🛰️ Optimized GNSS monitoring started");
                }

                @Override
                public void onStopped() {
                    Log.d("NavIC", "🛰️ Optimized GNSS monitoring stopped");
                }
            };

            locationManager.registerGnssStatusCallback(callbackRef[0], handler);

            // Early success timer - check quickly if NavIC is available
            handler.postDelayed(() -> {
                if (!navicDetectionCompleted.get() && !detectedNavicSatellites.isEmpty()) {
                    SatelliteScanResult earlyResult = getCurrentScanResult();
                    if (earlyResult.navicCount > 0) {
                        Log.d("NavIC", "🎯 Early detection - NavIC satellites found quickly");
                        completeDetection(true, earlyResult, EARLY_SUCCESS_DELAY_MS, cb, callbackRef[0]);
                        return;
                    }
                }
            }, EARLY_SUCCESS_DELAY_MS);

            // Final timeout
            handler.postDelayed(() -> {
                if (!navicDetectionCompleted.get()) {
                    Log.d("NavIC", "⏰ Detection timeout reached");
                    SatelliteScanResult finalResult = getCurrentScanResult();
                    completeDetection(finalResult.navicCount > 0, finalResult, 
                                    SATELLITE_DETECTION_TIMEOUT_MS, cb, callbackRef[0]);
                }
            }, SATELLITE_DETECTION_TIMEOUT_MS);

        } catch (SecurityException se) {
            Log.e("NavIC", "🔒 Location permission denied for satellite detection");
            cb.onResult(false, 0, 0, 0, 0.0, new ArrayList<>(), 0);
        } catch (Exception e) {
            Log.e("NavIC", "❌ Failed to register GNSS callback", e);
            cb.onResult(false, 0, 0, 0, 0.0, new ArrayList<>(), 0);
        }
    }

    /**
     * Optimized satellite processing - focused on NavIC detection
     */
    private SatelliteScanResult processSatellitesOptimized(GnssStatus status, long elapsedTime) {
        int navicCount = 0;
        int usedInFix = 0;
        double totalSignalStrength = 0.0;
        int satellitesWithSignal = 0;
        List<Map<String, Object>> satelliteDetails = new ArrayList<>();

        for (int i = 0; i < status.getSatelliteCount(); i++) {
            int constellation = status.getConstellationType(i);
            
            // Focus primarily on IRNSS constellation
            if (constellation == GnssStatus.CONSTELLATION_IRNSS) {
                int svid = status.getSvid(i);
                float cn0 = status.getCn0DbHz(i);
                boolean used = status.usedInFix(i);
                
                // Validate NavIC satellite (SVID 1-14)
                if (svid >= 1 && svid <= 14 && cn0 >= MIN_NAVIC_SIGNAL_STRENGTH) {
                    navicCount++;
                    if (used) usedInFix++;
                    
                    if (cn0 > 0) {
                        totalSignalStrength += cn0;
                        satellitesWithSignal++;
                    }

                    // Track satellite for better detection consistency
                    trackNavicSatellite(svid, cn0, used, elapsedTime);

                    // Create satellite details
                    Map<String, Object> satInfo = createSatelliteInfo(status, i, constellation);
                    satelliteDetails.add(satInfo);

                    // Log new satellite detection
                    if (!detectedNavicSatellites.containsKey(svid)) {
                        Log.d("NavIC", String.format(
                                "✅ NavIC SVID-%d - CN0: %.1f dB-Hz, Used: %s",
                                svid, cn0, used
                        ));
                    }
                }
            }
        }

        double averageSignal = satellitesWithSignal > 0 ? totalSignalStrength / satellitesWithSignal : 0.0;
        
        return new SatelliteScanResult(navicCount, usedInFix, status.getSatelliteCount(), 
                                     averageSignal, satelliteDetails);
    }

    /**
     * Track NavIC satellites for consistent detection
     */
    private void trackNavicSatellite(int svid, float cn0, boolean usedInFix, long timestamp) {
        NavicSatellite sat = detectedNavicSatellites.get(svid);
        if (sat == null) {
            sat = new NavicSatellite(svid);
            detectedNavicSatellites.put(svid, sat);
        }
        sat.update(cn0, usedInFix, timestamp);
    }

    private SatelliteScanResult getCurrentScanResult() {
        int navicCount = detectedNavicSatellites.size();
        int usedInFix = 0;
        double totalSignal = 0.0;
        int satsWithSignal = 0;
        List<Map<String, Object>> details = new ArrayList<>();

        for (NavicSatellite sat : detectedNavicSatellites.values()) {
            if (sat.usedInFix) usedInFix++;
            if (sat.lastCn0 > 0) {
                totalSignal += sat.lastCn0;
                satsWithSignal++;
            }
            details.add(sat.toMap());
        }

        double avgSignal = satsWithSignal > 0 ? totalSignal / satsWithSignal : 0.0;
        return new SatelliteScanResult(navicCount, usedInFix, 0, avgSignal, details);
    }

    private void completeDetection(boolean detected, SatelliteScanResult result, 
                                 long elapsedTime, EnhancedSatelliteDetectionCallback cb,
                                 GnssStatus.Callback callback) {
        if (navicDetectionCompleted.compareAndSet(false, true)) {
            cleanupCallback(callback);
            
            Log.d("NavIC", String.format(
                    "🎯 Detection %s - NavIC: %d satellites (%d in fix), Signal: %.1f dB-Hz, Time: %d ms",
                    detected ? "SUCCESS" : "FAILED", 
                    result.navicCount, result.usedInFix, result.averageSignalStrength, elapsedTime
            ));
            
            cb.onResult(detected, result.navicCount, result.totalSatellites, 
                       result.usedInFix, result.averageSignalStrength, 
                       result.satelliteDetails, elapsedTime);
        }
    }

    private Map<String, Object> createSatelliteInfo(GnssStatus status, int index, int constellation) {
        Map<String, Object> satInfo = new HashMap<>();
        satInfo.put("constellation", getConstellationName(constellation));
        satInfo.put("svid", status.getSvid(index));
        satInfo.put("cn0DbHz", status.getCn0DbHz(index));
        satInfo.put("elevation", status.getElevationDegrees(index));
        satInfo.put("azimuth", status.getAzimuthDegrees(index));
        satInfo.put("usedInFix", status.usedInFix(index));
        satInfo.put("hasEphemeris", status.hasEphemerisData(index));
        satInfo.put("hasAlmanac", status.hasAlmanacData(index));

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                float carrierFreq = status.getCarrierFrequencyHz(index);
                satInfo.put("carrierFrequencyHz", carrierFreq);
            } catch (Throwable ignored) {}
        }

        return satInfo;
    }

    // Hardware detection methods remain unchanged from previous version
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

    // Rest of the methods remain unchanged (getGnssCapabilities, startRealTimeNavicDetection, etc.)
    // ... [Previous implementation of other methods]

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
        Map<String, Integer> constellations = new HashMap<>();
        List<Map<String, Object>> satellites = new ArrayList<>();
        List<Map<String, Object>> navicSatellites = new ArrayList<>();

        int irnssCount = 0;
        int gpsCount = 0;
        int glonassCount = 0;
        int galileoCount = 0;
        int beidouCount = 0;
        int otherCount = 0;
        int irnssUsedInFix = 0;

        for (int i = 0; i < status.getSatelliteCount(); i++) {
            int constellationType = status.getConstellationType(i);
            String constellationName;

            switch (constellationType) {
                case GnssStatus.CONSTELLATION_IRNSS:
                    constellationName = "IRNSS";
                    irnssCount++;
                    if (status.usedInFix(i)) irnssUsedInFix++;
                    break;
                case GnssStatus.CONSTELLATION_GPS:
                    constellationName = "GPS"; gpsCount++; break;
                case GnssStatus.CONSTELLATION_GLONASS:
                    constellationName = "GLONASS"; glonassCount++; break;
                case GnssStatus.CONSTELLATION_GALILEO:
                    constellationName = "GALILEO"; galileoCount++; break;
                case GnssStatus.CONSTELLATION_BEIDOU:
                    constellationName = "BEIDOU"; beidouCount++; break;
                default:
                    constellationName = "OTHER"; otherCount++; break;
            }

            Map<String, Object> sat = new HashMap<>();
            sat.put("constellation", constellationName);
            sat.put("svid", status.getSvid(i));
            sat.put("cn0DbHz", status.getCn0DbHz(i));
            sat.put("elevation", status.getElevationDegrees(i));
            sat.put("azimuth", status.getAzimuthDegrees(i));
            sat.put("hasEphemeris", status.hasEphemerisData(i));
            sat.put("hasAlmanac", status.hasAlmanacData(i));
            sat.put("usedInFix", status.usedInFix(i));

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
        constellations.put("OTHER", otherCount);

        String primarySystem = "GPS";
        if (irnssUsedInFix > 0) {
            primarySystem = "NAVIC";
        } else if (gpsCount > 0) {
            primarySystem = "GPS";
        } else if (glonassCount > 0) {
            primarySystem = "GLONASS";
        } else if (beidouCount > 0) {
            primarySystem = "BEIDOU";
        } else if (galileoCount > 0) {
            primarySystem = "GALILEO";
        }

        Map<String, Object> result = new HashMap<>();
        result.put("type", "SATELLITE_UPDATE");
        result.put("timestamp", System.currentTimeMillis());
        result.put("totalSatellites", status.getSatelliteCount());
        result.put("constellations", constellations);
        result.put("satellites", satellites);
        result.put("navicSatellites", navicSatellites);
        result.put("isNavicAvailable", (irnssCount > 0));
        result.put("navicSatellites", irnssCount);
        result.put("navicUsedInFix", irnssUsedInFix);
        result.put("primarySystem", primarySystem);
        result.put("locationProvider", primarySystem);

        Log.d("NavIC", "Satellite Update - Primary: " + primarySystem +
                ", NavIC: " + irnssCount + "(" + irnssUsedInFix + " in fix), " +
                "Total: " + status.getSatelliteCount());

        return result;
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
    private static class NavicSatellite {
        int svid;
        float lastCn0;
        boolean usedInFix;
        long firstDetected;
        long lastUpdated;
        int detectionCount;

        NavicSatellite(int svid) {
            this.svid = svid;
            this.firstDetected = System.currentTimeMillis();
        }

        void update(float cn0, boolean usedInFix, long timestamp) {
            this.lastCn0 = cn0;
            this.usedInFix = usedInFix;
            this.lastUpdated = timestamp;
            this.detectionCount++;
        }

        Map<String, Object> toMap() {
            Map<String, Object> map = new HashMap<>();
            map.put("svid", svid);
            map.put("cn0DbHz", lastCn0);
            map.put("usedInFix", usedInFix);
            map.put("firstDetected", firstDetected);
            map.put("lastUpdated", lastUpdated);
            map.put("detectionCount", detectionCount);
            return map;
        }
    }

    private static class SatelliteScanResult {
        int navicCount;
        int usedInFix;
        int totalSatellites;
        double averageSignalStrength;
        List<Map<String, Object>> satelliteDetails;

        SatelliteScanResult(int navicCount, int usedInFix, int totalSatellites,
                          double averageSignalStrength, List<Map<String, Object>> satelliteDetails) {
            this.navicCount = navicCount;
            this.usedInFix = usedInFix;
            this.totalSatellites = totalSatellites;
            this.averageSignalStrength = averageSignalStrength;
            this.satelliteDetails = satelliteDetails;
        }
    }

    // Data classes for detection results (unchanged)
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
                      List<Map<String, Object>> satelliteDetails, long acquisitionTime);
    }
}