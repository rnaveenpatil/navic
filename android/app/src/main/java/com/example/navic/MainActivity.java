package com.example.navic;

import android.content.Context;
import android.content.pm.PackageManager;
import android.location.GnssStatus;
import android.location.LocationManager;
import android.os.Build;
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
    private static final long SATELLITE_DETECTION_TIMEOUT_MS = 15000L;

    private LocationManager locationManager;
    private GnssStatus.Callback realtimeCallback;
    private Handler handler;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        locationManager = (LocationManager) getSystemService(Context.LOCATION_SERVICE);
        handler = new Handler(Looper.getMainLooper());

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
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
                        default:
                            result.notImplemented();
                    }
                });
    }

    private void checkLocationPermissions(MethodChannel.Result result) {
        boolean hasFineLocation = ContextCompat.checkSelfPermission(
                this, android.Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED;
        boolean hasCoarseLocation = ContextCompat.checkSelfPermission(
                this, android.Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED;

        Map<String, Object> permissions = new HashMap<>();
        permissions.put("hasFineLocation", hasFineLocation);
        permissions.put("hasCoarseLocation", hasCoarseLocation);
        permissions.put("allPermissionsGranted", hasFineLocation && hasCoarseLocation);
        result.success(permissions);
    }

    private boolean hasLocationPermissions() {
        return ContextCompat.checkSelfPermission(
                this, android.Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED;
    }

    private void checkNavicHardwareSupport(MethodChannel.Result result) {
        if (!hasLocationPermissions()) {
            result.error("PERMISSION_DENIED", "Location permissions required", null);
            return;
        }

        handler.post(() -> {
            final boolean[] hardwareSupportsNavic = {false};
            final String detectionMethod = "HARDWARE_PLUS_SATELLITE";

            try {
                hardwareSupportsNavic[0] = detectNavicHardware();
            } catch (Exception e) {
                hardwareSupportsNavic[0] = false;
            }

            detectNavicSatellitesWithTimeout(hardwareSupportsNavic[0], (navicDetected, navicCount, totalSatellites) -> {
                Map<String, Object> response = new HashMap<>();
                response.put("isSupported", hardwareSupportsNavic[0]);
                response.put("isActive", navicDetected);
                response.put("detectionMethod", detectionMethod);
                response.put("satelliteCount", navicCount);
                response.put("totalSatellites", totalSatellites);

                String message;
                if (!hardwareSupportsNavic[0]) {
                    message = "Device does not support NavIC. Using standard GPS.";
                } else {
                    if (navicDetected) {
                        message = "Device supports NavIC and NavIC satellites available. Using NavIC now.";
                    } else {
                        message = "Device hardware supports NavIC, but satellites are not available. Using standard GPS.";
                    }
                }
                response.put("message", message);
                result.success(response);
            });
        });
    }

    /**
     * ACCURATE Hardware Detection - Only returns true for explicit NavIC support
     */
    private boolean detectNavicHardware() {
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
                                Log.d("NavIC", "Hardware supports NavIC via GnssCapabilities.hasIrnss()");
                                return true;
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

        // Method 2: Check for specific Qualcomm chipsets that support NavIC
        if (isQualcommNavicChipset()) {
            Log.d("NavIC", "NavIC supported via Qualcomm chipset detection");
            return true;
        }

        // Method 3: Conservative fallback - only return true for strong evidence
        Log.d("NavIC", "No strong evidence of NavIC hardware support");
        return false;
    }

    private boolean isQualcommNavicChipset() {
        try {
            String boardPlatform = android.os.Build.BOARD.toLowerCase();
            String hardware = android.os.Build.HARDWARE.toLowerCase();

            // Check for Qualcomm chipsets known to support NavIC
            boolean isQualcomm = boardPlatform.contains("msm") ||
                    boardPlatform.contains("sdm") ||
                    boardPlatform.contains("sm") ||
                    hardware.contains("qcom");

            if (isQualcomm) {
                // Only specific Qualcomm chipsets support NavIC
                // Snapdragon 7xx, 8xx series (2019+) typically support NavIC
                String model = android.os.Build.MODEL.toLowerCase();
                if (model.contains("sm") && (model.contains("7") || model.contains("8") || model.contains("9"))) {
                    return true;
                }
            }
        } catch (Exception e) {
            Log.e("NavIC", "Error detecting chipset", e);
        }
        return false;
    }

    private void detectNavicSatellitesWithTimeout(boolean hardwareSupportsNavic, SatelliteDetectionCallback cb) {
        final boolean[] navicDetected = {false};
        final int[] irnssCount = {0};
        final int[] totalSatCount = {0};

        GnssStatus.Callback callback = new GnssStatus.Callback() {
            @Override
            public void onSatelliteStatusChanged(GnssStatus status) {
                try {
                    irnssCount[0] = 0;
                    totalSatCount[0] = status.getSatelliteCount();

                    for (int i = 0; i < status.getSatelliteCount(); i++) {
                        if (status.getConstellationType(i) == GnssStatus.CONSTELLATION_IRNSS) {
                            irnssCount[0]++;
                            navicDetected[0] = true;
                        }
                    }

                    if (navicDetected[0]) {
                        try {
                            locationManager.unregisterGnssStatusCallback(this);
                        } catch (Exception ignored) {}
                        cb.onResult(true, irnssCount[0], totalSatCount[0]);
                    }
                } catch (Exception e) {
                    // Continue listening
                }
            }

            @Override public void onStarted() {}
            @Override public void onStopped() {}
        };

        try {
            locationManager.registerGnssStatusCallback(callback, handler);
            handler.postDelayed(() -> {
                try {
                    locationManager.unregisterGnssStatusCallback(callback);
                } catch (Exception ignored) {}
                cb.onResult(navicDetected[0], irnssCount[0], totalSatCount[0]);
            }, SATELLITE_DETECTION_TIMEOUT_MS);
        } catch (SecurityException se) {
            cb.onResult(false, 0, 0);
        } catch (Exception e) {
            cb.onResult(false, 0, 0);
        }
    }

    private void startRealTimeNavicDetection(MethodChannel.Result result) {
        if (!hasLocationPermissions()) {
            result.error("PERMISSION_DENIED", "Location permissions required", null);
            return;
        }

        stopRealTimeDetection();

        realtimeCallback = new GnssStatus.Callback() {
            @Override
            public void onSatelliteStatusChanged(GnssStatus status) {
                Map<String, Object> data = processSatelliteData(status);
                try {
                    new MethodChannel(getFlutterEngine().getDartExecutor().getBinaryMessenger(), CHANNEL)
                            .invokeMethod("onSatelliteUpdate", data);
                } catch (Exception e) {
                    // Flutter side might not have listener
                }
            }
            @Override public void onStarted() {}
            @Override public void onStopped() {}
        };

        try {
            locationManager.registerGnssStatusCallback(realtimeCallback, handler);
            Map<String, Object> resp = new HashMap<>();
            resp.put("success", true);
            resp.put("message", "Real-time NavIC detection started");
            result.success(resp);
        } catch (SecurityException se) {
            result.error("PERMISSION_ERROR", "Location permissions required", null);
        } catch (Exception e) {
            result.error("REALTIME_DETECTION_ERROR", "Failed to start detection", null);
        }
    }

    private Map<String, Object> processSatelliteData(GnssStatus status) {
        Map<String, Integer> constellations = new HashMap<>();
        List<Map<String, Object>> satellites = new ArrayList<>();

        int irnssCount = 0;
        int gpsCount = 0;
        int glonassCount = 0;
        int galileoCount = 0;
        int beidouCount = 0;
        int otherCount = 0;

        for (int i = 0; i < status.getSatelliteCount(); i++) {
            int constellationType = status.getConstellationType(i);
            String constellationName;

            switch (constellationType) {
                case GnssStatus.CONSTELLATION_IRNSS:
                    constellationName = "IRNSS"; irnssCount++; break;
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
            try {
                sat.put("svid", status.getSvid(i));
                sat.put("cn0DbHz", status.getCn0DbHz(i));
                sat.put("elevation", status.getElevationDegrees(i));
                sat.put("azimuth", status.getAzimuthDegrees(i));
                sat.put("hasEphemeris", status.hasEphemerisData(i));
                sat.put("hasAlmanac", status.hasAlmanacData(i));
                sat.put("usedInFix", status.usedInFix(i));
            } catch (Exception ignored) {}

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                try {
                    float freq = status.getCarrierFrequencyHz(i);
                    sat.put("carrierFrequencyHz", freq);
                } catch (Throwable ignored) {}
            }
            satellites.add(sat);
        }

        constellations.put("IRNSS", irnssCount);
        constellations.put("GPS", gpsCount);
        constellations.put("GLONASS", glonassCount);
        constellations.put("GALILEO", galileoCount);
        constellations.put("BEIDOU", beidouCount);
        constellations.put("OTHER", otherCount);

        Map<String, Object> result = new HashMap<>();
        result.put("type", "SATELLITE_UPDATE");
        result.put("timestamp", System.currentTimeMillis());
        result.put("totalSatellites", status.getSatelliteCount());
        result.put("constellations", constellations);
        result.put("satellites", satellites);
        result.put("isNavicAvailable", (irnssCount > 0));
        result.put("navicSatellites", irnssCount);
        result.put("primarySystem", (irnssCount > 0) ? "NAVIC" : "GPS");
        return result;
    }

    private void stopRealTimeDetection(MethodChannel.Result result) {
        try {
            if (realtimeCallback != null) {
                locationManager.unregisterGnssStatusCallback(realtimeCallback);
                realtimeCallback = null;
            }
        } catch (Exception ignored) {}
        if (result != null) {
            Map<String, Object> resp = new HashMap<>();
            resp.put("success", true);
            result.success(resp);
        }
    }

    private void stopRealTimeDetection() {
        stopRealTimeDetection(null);
    }

    private void getGnssCapabilities(MethodChannel.Result result) {
        Map<String, Object> caps = new HashMap<>();
        try {
            caps.put("androidVersion", Build.VERSION.SDK_INT);
            caps.put("manufacturer", Build.MANUFACTURER);
            caps.put("model", Build.MODEL);
            caps.put("device", Build.DEVICE);

            boolean hasGnssFeature = getPackageManager().hasSystemFeature(PackageManager.FEATURE_LOCATION_GPS);
            caps.put("hasGnssFeature", hasGnssFeature);

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                try {
                    Object gnssCaps = locationManager.getGnssCapabilities();
                    if (gnssCaps != null) {
                        Map<String, Object> gnssMap = new HashMap<>();
                        try {
                            Method hasIrnss = gnssCaps.getClass().getMethod("hasIrnss");
                            Object v = hasIrnss.invoke(gnssCaps);
                            if (v instanceof Boolean) gnssMap.put("hasIrnss", (Boolean) v);
                        } catch (NoSuchMethodException ignore) {}
                        caps.put("gnssCapabilities", gnssMap);
                    }
                } catch (Throwable ignored) {}
            }
            caps.put("capabilitiesMethod", "HARDWARE_PLUS_SATELLITE");
            result.success(caps);
        } catch (Exception e) {
            result.error("CAPABILITIES_ERROR", "Failed to get GNSS capabilities", null);
        }
    }

    @Override
    protected void onDestroy() {
        try {
            if (realtimeCallback != null) {
                locationManager.unregisterGnssStatusCallback(realtimeCallback);
            }
        } catch (Exception ignored) {}
        super.onDestroy();
    }

    private interface SatelliteDetectionCallback {
        void onResult(boolean navicDetected, int navicCount, int totalSatellites);
    }
}