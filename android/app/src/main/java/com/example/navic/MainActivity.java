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
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "navic_support";
    private static final long SATELLITE_DETECTION_TIMEOUT_MS = 25000L;
    private static final long LOCATION_UPDATE_INTERVAL_MS = 1000L;
    private static final float LOCATION_UPDATE_DISTANCE_M = 0.5f;

    private LocationManager locationManager;
    private GnssStatus.Callback realtimeCallback;
    private LocationListener locationListener;
    private Handler handler;
    private boolean isTrackingLocation = false;
    private MethodChannel methodChannel;

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

            Map<String, Object> permissions = new HashMap<>();
            permissions.put("hasFineLocation", hasFineLocation);
            permissions.put("allPermissionsGranted", hasFineLocation);

            Log.d("NavIC", "Permission check - Fine Location: " + hasFineLocation);
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
        Log.d("NavIC", "Starting NavIC hardware support check");

        if (!hasLocationPermissions()) {
            result.error("PERMISSION_DENIED", "Location permissions required", null);
            return;
        }

        handler.post(() -> {
            final boolean hardwareSupportsNavic = detectNavicHardware();
            final String detectionMethod = "CHIPSET_BASED_DETECTION";

            detectNavicSatellitesWithTimeout(hardwareSupportsNavic, (navicDetected, navicCount, totalSatellites, usedInFixCount) -> {
                Map<String, Object> response = new HashMap<>();
                response.put("isSupported", hardwareSupportsNavic);
                response.put("isActive", navicDetected);
                response.put("detectionMethod", detectionMethod);
                response.put("satelliteCount", navicCount);
                response.put("totalSatellites", totalSatellites);
                response.put("usedInFixCount", usedInFixCount);

                String message;
                if (!hardwareSupportsNavic) {
                    message = "Device chipset does not support NavIC. Using standard GPS.";
                } else {
                    if (navicDetected) {
                        message = "Device chipset supports NavIC and " + navicCount + " NavIC satellites available (" + usedInFixCount + " used in fix).";
                    } else {
                        message = "Device chipset supports NavIC, but no NavIC satellites in view. Using GPS.";
                    }
                }
                response.put("message", message);

                Log.d("NavIC", "Hardware check completed: " + message);
                result.success(response);
            });
        });
    }

    /**
     * CHIPSET-BASED Hardware Detection - Only uses chipset information
     */
    private boolean detectNavicHardware() {
        Log.d("NavIC", "Starting chipset-based NavIC hardware detection");

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
                                Log.d("NavIC", "✅ Hardware supports NavIC via GnssCapabilities.hasIrnss()");
                                return true;
                            } else {
                                Log.d("NavIC", "❌ GnssCapabilities reports no NavIC support");
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

        // Method 2: Enhanced Qualcomm chipset detection
        if (detectQualcommNavicChipset()) {
            return true;
        }

        // Method 3: Enhanced MediaTek chipset detection
        if (detectMediatekNavicChipset()) {
            return true;
        }

        // Method 4: Check system properties for NavIC support
        if (checkSystemPropertiesForNavic()) {
            return true;
        }

        Log.d("NavIC", "❌ No chipset evidence of NavIC hardware support");
        return false;
    }

    private boolean detectQualcommNavicChipset() {
        try {
            String boardPlatform = Build.BOARD.toLowerCase();
            String hardware = Build.HARDWARE.toLowerCase();
            String socModel = getSoCModel();

            Log.d("NavIC", "Qualcomm detection - Board: " + boardPlatform + ", Hardware: " + hardware + ", SoC: " + socModel);

            // Check for Qualcomm SoC patterns
            boolean isQualcomm = boardPlatform.contains("msm") ||
                    boardPlatform.contains("sdm") ||
                    boardPlatform.contains("sm") ||
                    boardPlatform.contains("qcs") ||
                    hardware.contains("qcom") ||
                    hardware.contains("qualcomm") ||
                    (socModel != null && socModel.contains("qcom"));

            if (!isQualcomm) {
                return false;
            }

            Log.d("NavIC", "Qualcomm device detected, checking NavIC-supported chipsets...");

            // Enhanced Qualcomm NavIC-supported chipsets list
            String[] navicChipsets = {
                    // Snapdragon 800 series (flagship)
                    "sm8550", "sm8475", "sm8350", "sm8250", "sm8150",
                    "sm8650", "sm8750",

                    // Snapdragon 700 series (premium)
                    "sm7325", "sm7250", "sm7150", "sm7125", "sm7350",
                    "sm7550", "sm7475",

                    // Snapdragon 600 series (mid-range)
                    "sm6375", "sm6225", "sm6125", "sm6115", "sm6250",
                    "sm6350", "sm6450", "sm6650",

                    // Snapdragon 400 series (budget with NavIC)
                    "sm4350", "sm4250", "sm4150", "sm4050"
            };

            // Check exact chipset matches
            for (String chipset : navicChipsets) {
                if (boardPlatform.contains(chipset) ||
                        hardware.contains(chipset) ||
                        (socModel != null && socModel.contains(chipset))) {
                    Log.d("NavIC", "✅ Found NavIC-supported Qualcomm chipset: " + chipset);
                    return true;
                }
            }

            // Check chipset family patterns
            if (boardPlatform.matches(".*sm[8][0-9]{3}.*") ||  // 800 series
                    boardPlatform.matches(".*sm[7][0-9]{3}.*") ||  // 700 series
                    boardPlatform.matches(".*sm[6][0-9]{3}.*") ||  // 600 series
                    boardPlatform.matches(".*sm[4][0-9]{3}.*")) {  // 400 series
                Log.d("NavIC", "✅ Qualcomm Snapdragon series detected with potential NavIC support");
                return true;
            }

        } catch (Exception e) {
            Log.e("NavIC", "Error detecting Qualcomm chipset", e);
        }
        return false;
    }

    private boolean detectMediatekNavicChipset() {
        try {
            String hardware = Build.HARDWARE.toLowerCase();
            String boardPlatform = Build.BOARD.toLowerCase();
            String socModel = getSoCModel();

            Log.d("NavIC", "MediaTek detection - Hardware: " + hardware + ", Board: " + boardPlatform + ", SoC: " + socModel);

            boolean isMediatek = hardware.contains("mt") ||
                    boardPlatform.contains("mt") ||
                    Build.MANUFACTURER.toLowerCase().contains("mediatek") ||
                    (socModel != null && socModel.contains("mt"));

            if (!isMediatek) {
                return false;
            }

            Log.d("NavIC", "MediaTek device detected, checking NavIC-supported chipsets...");

            // MediaTek chipsets with confirmed NavIC support (Dimensity series mostly)
            String[] navicChipsets = {
                    // Dimensity 9000/8000/7000 series
                    "mt6983", "mt6985", "mt6895", "mt6896", "mt6897",
                    "mt6877", "mt6879", "mt6855", "mt6857", "mt6833",
                    "mt6885", "mt6889", "mt6891", "mt6893",

                    // Dimensity 1000/800/700 series
                    "mt6889", "mt6875", "mt6873", "mt6853", "mt6785",
                    "mt6768", "mt6765"
            };

            // Check exact chipset matches
            for (String chipset : navicChipsets) {
                if (hardware.contains(chipset) ||
                        boardPlatform.contains(chipset) ||
                        (socModel != null && socModel.contains(chipset))) {
                    Log.d("NavIC", "✅ Found NavIC-supported MediaTek chipset: " + chipset);
                    return true;
                }
            }

            // Check for Dimensity series pattern
            if (hardware.matches(".*mt6[8-9][0-9]{2}.*") ||  // Dimensity series
                    boardPlatform.matches(".*mt6[8-9][0-9]{2}.*")) {
                Log.d("NavIC", "✅ MediaTek Dimensity series detected with NavIC support");
                return true;
            }

        } catch (Exception e) {
            Log.e("NavIC", "Error detecting MediaTek chipset", e);
        }
        return false;
    }

    private boolean checkSystemPropertiesForNavic() {
        try {
            // Check system properties for NavIC support indicators
            Class<?> systemPropsClass = Class.forName("android.os.SystemProperties");
            Method getMethod = systemPropsClass.getMethod("get", String.class, String.class);

            // Check various GNSS-related system properties
            String[] gnssProperties = {
                    "ro.gnss.sv_status",
                    "persist.vendor.radio.aosp_gnss",
                    "persist.vendor.gnss.hardware",
                    "ro.board.gnss",
                    "ro.hardware.gnss"
            };

            for (String prop : gnssProperties) {
                String value = (String) getMethod.invoke(null, prop, "");
                if (value.toLowerCase().contains("irnss") || value.toLowerCase().contains("navic")) {
                    Log.d("NavIC", "✅ NavIC support found in system property: " + prop + " = " + value);
                    return true;
                }
            }

            // Check for GNSS feature list
            String gnssFeatures = (String) getMethod.invoke(null, "ro.hardware.gnss.features", "");
            if (gnssFeatures.toLowerCase().contains("irnss")) {
                Log.d("NavIC", "✅ NavIC support found in GNSS features: " + gnssFeatures);
                return true;
            }

        } catch (Exception e) {
            Log.d("NavIC", "System properties check failed (normal for non-root devices)");
        }
        return false;
    }

    private String getSoCModel() {
        try {
            // Try to get SoC model from system properties
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

    private void detectNavicSatellitesWithTimeout(boolean hardwareSupportsNavic, EnhancedSatelliteDetectionCallback cb) {
        final boolean[] navicDetected = {false};
        final int[] irnssCount = {0};
        final int[] totalSatCount = {0};
        final int[] usedInFixCount = {0};
        final long startTime = System.currentTimeMillis();
        final List<Integer> foundNavicSvid = new ArrayList<>();

        GnssStatus.Callback callback = new GnssStatus.Callback() {
            @Override
            public void onSatelliteStatusChanged(GnssStatus status) {
                try {
                    irnssCount[0] = 0;
                    usedInFixCount[0] = 0;
                    totalSatCount[0] = status.getSatelliteCount();
                    boolean foundNewNavic = false;

                    for (int i = 0; i < status.getSatelliteCount(); i++) {
                        if (status.getConstellationType(i) == GnssStatus.CONSTELLATION_IRNSS) {
                            int svid = status.getSvid(i);
                            boolean usedInFix = status.usedInFix(i);

                            // NavIC SVIDs are in range 1-14 for IRNSS
                            if (svid >= 1 && svid <= 14) {
                                irnssCount[0]++;
                                if (usedInFix) {
                                    usedInFixCount[0]++;
                                }

                                // Track unique SVIDs
                                if (!foundNavicSvid.contains(svid)) {
                                    foundNavicSvid.add(svid);
                                    foundNewNavic = true;
                                    Log.d("NavIC", "✅ Found NavIC satellite - SVID: " + svid +
                                            ", CN0: " + status.getCn0DbHz(i) +
                                            "dB-Hz, UsedInFix: " + usedInFix +
                                            ", Elevation: " + status.getElevationDegrees(i) + "°");
                                }

                                navicDetected[0] = true;
                            }
                        }
                    }

                    // Log satellite status periodically
                    if (System.currentTimeMillis() - startTime > 5000 && (System.currentTimeMillis() - startTime) % 5000 < 100) {
                        Log.d("NavIC", "Satellite search - Elapsed: " + (System.currentTimeMillis() - startTime) + "ms, " +
                                "NavIC: " + irnssCount[0] + " (" + usedInFixCount[0] + " in fix), " +
                                "Total: " + totalSatCount[0] + " satellites");
                    }

                    // If we found NavIC satellites and they're being used in fix, return immediately
                    if (navicDetected[0] && usedInFixCount[0] > 0) {
                        Log.d("NavIC", "🎯 NavIC satellites actively used in position fix: " + usedInFixCount[0]);
                        try {
                            locationManager.unregisterGnssStatusCallback(this);
                        } catch (Exception ignored) {}
                        cb.onResult(true, irnssCount[0], totalSatCount[0], usedInFixCount[0]);
                    }
                    // If timeout reached with any NavIC satellites
                    else if (System.currentTimeMillis() - startTime > SATELLITE_DETECTION_TIMEOUT_MS) {
                        Log.d("NavIC", "⏰ Satellite detection timeout reached");
                        try {
                            locationManager.unregisterGnssStatusCallback(this);
                        } catch (Exception ignored) {}
                        cb.onResult(navicDetected[0], irnssCount[0], totalSatCount[0], usedInFixCount[0]);
                    }
                    // If found new NavIC satellites but not in fix yet, continue monitoring
                    else if (foundNewNavic) {
                        Log.d("NavIC", "📡 Found NavIC satellites, monitoring for position fix usage...");
                    }
                } catch (Exception e) {
                    Log.e("NavIC", "Error in satellite detection", e);
                }
            }

            @Override
            public void onStarted() {
                Log.d("NavIC", "🛰️ GNSS satellite monitoring started");
            }

            @Override
            public void onStopped() {
                Log.d("NavIC", "🛰️ GNSS satellite monitoring stopped");
            }
        };

        try {
            locationManager.registerGnssStatusCallback(callback, handler);
            Log.d("NavIC", "Registered GNSS callback for satellite detection");

            // Set timeout
            handler.postDelayed(() -> {
                try {
                    locationManager.unregisterGnssStatusCallback(callback);
                    if (!navicDetected[0]) {
                        Log.d("NavIC", "❌ No NavIC satellites detected within timeout period");
                        cb.onResult(false, 0, totalSatCount[0], 0);
                    }
                } catch (Exception ignored) {}
            }, SATELLITE_DETECTION_TIMEOUT_MS);

        } catch (SecurityException se) {
            Log.e("NavIC", "🔒 Location permission denied for satellite detection");
            cb.onResult(false, 0, 0, 0);
        } catch (Exception e) {
            Log.e("NavIC", "❌ Failed to register GNSS callback", e);
            cb.onResult(false, 0, 0, 0);
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
            // Request location updates from both GPS and NETWORK providers for better accuracy
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

            // Track NavIC satellites separately
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

        // Determine primary positioning system
        String primarySystem = "GPS"; // Default
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

            // Enhanced capabilities detection
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

    private interface EnhancedSatelliteDetectionCallback {
        void onResult(boolean navicDetected, int navicCount, int totalSatellites, int usedInFixCount);
    }
}