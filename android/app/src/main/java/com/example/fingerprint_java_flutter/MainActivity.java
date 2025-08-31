
package com.example.fingerprint_java_flutter;

import androidx.annotation.NonNull;
import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Base64;
import android.util.Log;

import com.example.fingerprint_java_flutter.ZKUSBManager.ZKUSBManager;
import com.example.fingerprint_java_flutter.ZKUSBManager.ZKUSBManagerListener;
import com.example.fingerprint_java_flutter.util.PermissionUtils;
import com.zkteco.android.biometric.FingerprintExceptionListener;
import com.zkteco.android.biometric.core.device.ParameterHelper;
import com.zkteco.android.biometric.core.device.TransportType;
import com.zkteco.android.biometric.core.utils.LogHelper;
import com.zkteco.android.biometric.core.utils.ToolUtils;
import com.zkteco.android.biometric.module.fingerprintreader.FingerprintCaptureListener;
import com.zkteco.android.biometric.module.fingerprintreader.FingerprintSensor;
import com.zkteco.android.biometric.module.fingerprintreader.FingprintFactory;
import com.zkteco.android.biometric.module.fingerprintreader.ZKFingerService;
import com.zkteco.android.biometric.module.fingerprintreader.exception.FingerprintException;

import java.io.ByteArrayOutputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {

    private static final String CHANNEL = "com.zk.fingerprint/channel";
    private static final String TAG = "MainActivity";

    private static final int ZKTECO_VID = 0x1b55;
    private static final int LIVE20R_PID = 0x0120;
    private static final int LIVE10R_PID = 0x0124;

    private final int REQUEST_PERMISSION_CODE = 9;

    private ZKUSBManager zkusbManager = null;
    private FingerprintSensor fingerprintSensor = null;

    private int usb_vid = ZKTECO_VID;
    private int usb_pid = 0;
    private boolean bStarted = false;
    private int deviceIndex = 0;
    private boolean isReseted = false;

    private final static int ENROLL_COUNT = 3;
    private int enroll_index = 0;
    private byte[][] regtemparray = new byte[ENROLL_COUNT][2048];
    private boolean bRegister = false;

    private MethodChannel methodChannel;

    // Verification timeout system - 20 seconds
    private static final long VERIFICATION_TIMEOUT_MS = 20000; // 20 seconds
    private byte[] targetTemplateForVerification = null;
    private Handler verificationTimeoutHandler = new Handler(Looper.getMainLooper());
    private Runnable verificationTimeoutRunnable = null;
    private long verificationStartTime = 0;
    private Handler countdownHandler = new Handler(Looper.getMainLooper());

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Log.d(TAG, "onCreate: Initializing fingerprint application");
        //checkStoragePermission();
        zkusbManager = new ZKUSBManager(this.getApplicationContext(), zkusbManagerListener);
        zkusbManager.registerUSBPermissionReceiver();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        Log.d(TAG, "onDestroy: Cleaning up resources");
        if (bStarted) closeDevice();
        if (zkusbManager != null) zkusbManager.unRegisterUSBPermissionReceiver();
        // Clear any pending verification timeout
        clearVerificationTimeout();
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        methodChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL);

        methodChannel.setMethodCallHandler((call, result) -> {
            Log.d(TAG, "Method called: " + call.method);
            switch (call.method) {
                case "startFingerprint":
                    runOnUiThread(() -> onBnStart(null));
                    result.success("Fingerprint: starting...");
                    break;
                case "stopFingerprint":
                    runOnUiThread(() -> onBnStop(null));
                    result.success("Fingerprint: stopped");
                    break;
                case "registerFingerprint": {
                    // Clear any ongoing verification when starting registration
                    clearVerificationTimeout();
                    runOnUiThread(() -> onBnRegister(null));
                    result.success("تسجيل بصمة جديدة : في انتظار الضغط على البصمة");
                    break;
                }
                case "scanTemplate":
                    bRegister = false;
                    clearVerificationTimeout();
                    runOnUiThread(() -> {
                        if (!bStarted) {
                            onBnStart(null);
                            // Wait a bit for device to initialize
                            new Handler(Looper.getMainLooper()).postDelayed(() -> {
                                setResult("{\"color\": \"blue\", \"message\": \"ضع إصبعك على المستشعر\"}");
                            }, 1000);
                        } else {
                            setResult("{\"color\": \"blue\", \"message\": \"ضع إصبعك على المستشعر\"}");
                        }
                    });
                    result.success("Scan: started");
                    break;

                case "beginVerify": {
                    String storedBase64 = call.argument("storedTemplate");
                    if (storedBase64 == null || storedBase64.isEmpty()) {
                        result.error("ARG_ERROR", "storedTemplate is empty", null);
                        return;
                    }
                    
                    runOnUiThread(() -> {
                        // Ensure device is started before verification
                        if (!bStarted) {
                            onBnStart(null);
                            // Wait for device to initialize then start verification
                            new Handler(Looper.getMainLooper()).postDelayed(() -> {
                                if (bStarted) {
                                    startVerificationWithTimeout(storedBase64);
                                } else {
                                    setResult("{\"color\": \"red\", \"message\": \"فشل في تشغيل الجهاز\"}");
                                    if (methodChannel != null) {
                                        methodChannel.invokeMethod("onError", "Device failed to start");
                                    }
                                }
                            }, 1500);
                        } else {
                            startVerificationWithTimeout(storedBase64);
                        }
                    });
                    result.success("Verify: waiting for live capture (20 seconds timeout)");
                    break;
                }

                case "stopVerify": {
                    clearVerificationTimeout();
                    setResult("{\"color\": \"gray\", \"message\": \"تم إيقاف التحقق\"}");
                    result.success("Verification stopped");
                    break;
                }

                default:
                    result.notImplemented();
                    break;
            }
        });
    }

    private void startVerificationWithTimeout(String storedBase64) {
        Log.d(TAG, "Starting verification with timeout");
        
        // Clear any existing verification timeout
        clearVerificationTimeout();
        
        // Set up the new verification
        try {
            targetTemplateForVerification = Base64.decode(storedBase64, Base64.NO_WRAP);
            bRegister = false;
            verificationStartTime = System.currentTimeMillis();
            
            // Set up timeout handler
            verificationTimeoutRunnable = new Runnable() {
                @Override
                public void run() {
                    Log.d(TAG, "Verification timeout reached");
                    // Timeout reached
                    targetTemplateForVerification = null;
                    setResult("{\"color\": \"orange\", \"message\": \"انتهت مهلة التحقق (20 ثانية)\"}");
                    if (methodChannel != null) {
                        methodChannel.invokeMethod("onVerifyTimeout", "Verification timeout after 20 seconds");
                    }
                }
            };
            
            verificationTimeoutHandler.postDelayed(verificationTimeoutRunnable, VERIFICATION_TIMEOUT_MS);
            
            runOnUiThread(() -> {
                long remainingSeconds = VERIFICATION_TIMEOUT_MS / 1000;
                setResult("{\"color\": \"blue\", \"message\": \"ضع إصبعك على المستشعر (" + remainingSeconds + " ثانية متبقية)\"}");
            });
            
            // Start a countdown updater
            startCountdownUpdater();
            
        } catch (Exception e) {
            Log.e(TAG, "Error starting verification", e);
            setResult("{\"color\": \"red\", \"message\": \"خطأ في بدء التحقق\"}");
            if (methodChannel != null) {
                methodChannel.invokeMethod("onError", "Error starting verification: " + e.getMessage());
            }
        }
    }

    private void startCountdownUpdater() {
        Runnable countdownRunnable = new Runnable() {
            @Override
            public void run() {
                if (targetTemplateForVerification != null && verificationStartTime > 0) {
                    long elapsedTime = System.currentTimeMillis() - verificationStartTime;
                    long remainingTime = VERIFICATION_TIMEOUT_MS - elapsedTime;
                    
                    if (remainingTime > 1000) { // Only update if more than 1 second remaining
                        long remainingSeconds = remainingTime / 1000;
                        setResult("{\"color\": \"blue\", \"message\": \"ضع إصبعك على المستشعر (" + remainingSeconds + " ثانية متبقية)\"}");
                        
                        // Schedule next update in 1 second
                        countdownHandler.postDelayed(this, 1000);
                    }
                }
            }
        };
        countdownHandler.postDelayed(countdownRunnable, 1000);
    }

    private void clearVerificationTimeout() {
        Log.d(TAG, "Clearing verification timeout");
        if (verificationTimeoutRunnable != null && verificationTimeoutHandler != null) {
            verificationTimeoutHandler.removeCallbacks(verificationTimeoutRunnable);
            verificationTimeoutRunnable = null;
        }
        if (countdownHandler != null) {
            countdownHandler.removeCallbacksAndMessages(null);
        }
        targetTemplateForVerification = null;
        verificationStartTime = 0;
    }

    // private void checkStoragePermission() {
    //     ArrayList<String> deniedPermissions = PermissionUtils.checkPermissions(this, permission);
    //     if (!deniedPermissions.isEmpty()) {
    //         PermissionUtils.requestPermission(this, deniedPermissions.toArray(new String[0]), REQUEST_PERMISSION_CODE);
    //     }
    // }

    public void onBnStart(android.view.View view) {
        Log.d(TAG, "onBnStart called, bStarted: " + bStarted);
        if (bStarted) {
            setResult("{\"color\": \"green\", \"message\": \"الجهاز متصل بالفعل\"}");
            return;
        }
        if (!enumSensor()) {
            setResult("{\"color\": \"red\", \"message\": \"الجهاز غير موجود\"}");
            Log.w(TAG, "No fingerprint sensor found");
            return;
        }
        tryGetUSBPermission();
    }

    public void onBnStop(android.view.View view) {
        Log.d(TAG, "onBnStop called");
        if (!bStarted) {
            setResult("{\"color\": \"red\", \"message\": \"الجهاز غير متصل\"}");
            return;
        }
        clearVerificationTimeout();
        closeDevice();
        setResult("{\"color\": \"gray\", \"message\": \"الجهاز مغلق\"}");
    }

    public void onBnRegister(android.view.View view) {
        Log.d(TAG, "onBnRegister called");
        if (!bStarted) {
            setResult("{\"color\": \"orange\", \"message\": \"يرجى بدء الالتقاط أولاً\"}");
            return;
        }
        clearVerificationTimeout(); // Clear any ongoing verification
        bRegister = true;
        enroll_index = 0;
        setResult("{\"color\": \"orange\", \"message\": \"ضع إصبعك على المستشعر 3 مرات\"}");
    }

    private boolean enumSensor() {
        UsbManager usbManager = (UsbManager) getSystemService(Context.USB_SERVICE);
        if (usbManager == null) {
            Log.e(TAG, "UsbManager is null");
            return false;
        }
        
        for (UsbDevice device : usbManager.getDeviceList().values()) {
            Log.d(TAG, "Found USB device - VID: " + Integer.toHexString(device.getVendorId()) + 
                  ", PID: " + Integer.toHexString(device.getProductId()));
            
            if (device.getVendorId() == ZKTECO_VID &&
                (device.getProductId() == LIVE20R_PID || device.getProductId() == LIVE10R_PID)) {
                usb_pid = device.getProductId();
                Log.d(TAG, "Found ZKTeco fingerprint device, PID: " + Integer.toHexString(usb_pid));
                return true;
            }
        }
        Log.w(TAG, "ZKTeco fingerprint device not found");
        return false;
    }

    private void tryGetUSBPermission() {
        Log.d(TAG, "Requesting USB permission");
        zkusbManager.initUSBPermission(usb_vid, usb_pid);
    }

    private void openDevice() {
        Log.d(TAG, "Opening fingerprint device");
        createFingerprintSensor();
        try {
            fingerprintSensor.open(deviceIndex);
            fingerprintSensor.setFingerprintCaptureListener(deviceIndex, fingerprintCaptureListener);
            fingerprintSensor.SetFingerprintExceptionListener(fingerprintExceptionListener);
            fingerprintSensor.startCapture(deviceIndex);
            bStarted = true;
            setResult("{\"color\": \"green\", \"message\": \"جهاز البصمة متصل\"}");
            Log.i(TAG, "Fingerprint device opened successfully");
        } catch (FingerprintException e) {
            Log.e(TAG, "Failed to open fingerprint device", e);
            setResult("{\"color\": \"red\", \"message\": \"فشل الاتصال\"}");
        }
    }

    private void closeDevice() {
        Log.d(TAG, "Closing fingerprint device");
        try {
            if (fingerprintSensor != null) {
                fingerprintSensor.stopCapture(deviceIndex);
                fingerprintSensor.close(deviceIndex);
            }
        } catch (Exception e) {
            Log.e(TAG, "Error closing device", e);
        }
        bStarted = false;
    }

    private void createFingerprintSensor() {
        if (fingerprintSensor != null) {
            FingprintFactory.destroy(fingerprintSensor);
            fingerprintSensor = null;
        }
        Map<String, Object> deviceParams = new HashMap<>();
        deviceParams.put(ParameterHelper.PARAM_KEY_VID, usb_vid);
        deviceParams.put(ParameterHelper.PARAM_KEY_PID, usb_pid);
        fingerprintSensor = FingprintFactory.createFingerprintSensor(getApplicationContext(), TransportType.USB, deviceParams);
        Log.d(TAG, "Fingerprint sensor created");
    }

    private final FingerprintCaptureListener fingerprintCaptureListener = new FingerprintCaptureListener() {
        @Override
        public void captureOK(byte[] fpImage) {
            try {
                Bitmap bitmap = ToolUtils.renderCroppedGreyScaleBitmap(fpImage,
                        fingerprintSensor.getImageWidth(),
                        fingerprintSensor.getImageHeight());
                ByteArrayOutputStream stream = new ByteArrayOutputStream();
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream);
                String base64Image = Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP);
                if (methodChannel != null) {
                    runOnUiThread(() -> methodChannel.invokeMethod("onFingerprintImage", base64Image));
                }
                Log.d(TAG, "Fingerprint image captured and sent to Flutter");
            } catch (Exception e) {
                Log.e(TAG, "Error processing fingerprint image", e);
            }
        }

        @Override 
        public void captureError(FingerprintException e) { 
            Log.e(TAG, "Fingerprint capture error", e);
        }

        @Override
        public void extractOK(byte[] fpTemplate) {
            Log.d(TAG, "Fingerprint template extracted, length: " + fpTemplate.length);
            
            try {
                if (methodChannel != null) {
                    String base64Template = Base64.encodeToString(fpTemplate, Base64.NO_WRAP);
                    runOnUiThread(() -> methodChannel.invokeMethod("onTemplateScanned", base64Template));
                }

                if (bRegister) {
                    Log.d(TAG, "Processing registration template");
                    doRegister(fpTemplate);
                } else {
                    // Check if we're in verification mode and within timeout
                    if (targetTemplateForVerification != null) {
                        long currentTime = System.currentTimeMillis();
                        long elapsedTime = currentTime - verificationStartTime;
                        
                        Log.d(TAG, "Processing verification, elapsed time: " + elapsedTime + "ms");
                        
                        // Only verify if we're still within the timeout period
                        if (elapsedTime <= VERIFICATION_TIMEOUT_MS) {

                            /// THRESHOLD
                            // 30 – 40 👉 حد أدنى، يعني ممكن يقبل بصمات قريبة جدًا لكن احتمال الخطأ أعلى.
                            // 50 – 60 👉 الأكثر شيوعًا في الأنظمة التجارية (موازنة بين رفض البصمات الصحيحة وقبول البصمات الخاطئة).
                            // 70 – 80 👉 مستوى أمان عالي (يقلل قبول البصمات الخاطئة، لكن ممكن يرفض بصمات صحيحة أكثر).
                            ///

                            //      if (elapsedTime <= VERIFICATION_TIMEOUT_MS) {
                            //     int vr = ZKFingerService.verify(targetTemplateForVerification, fpTemplate);
                            //     int THRESHOLD = 50; // العتبة
                            //     boolean matched = vr >= THRESHOLD;

                            int vr = ZKFingerService.verify(targetTemplateForVerification, fpTemplate);
                            boolean matched = vr > 0;
                            
                            Log.i(TAG, "Verification result: " + (matched ? "MATCHED" : "NOT MATCHED") + ", score: " + vr);
                            
                            if (methodChannel != null) {
                                runOnUiThread(() -> methodChannel.invokeMethod("onVerifyResult", matched));
                            }
                            
                            // Clear verification after successful attempt (whether matched or not)
                            clearVerificationTimeout();
                            
                            if (matched) {
                                setResult("{\"color\": \"green\", \"message\": \"تم التحقق بنجاح\"}");
                            } else {
                                setResult("{\"color\": \"red\", \"message\": \"البصمة غير متطابقة\"}");
                            }
                        } else {
                            // Timeout already exceeded
                            Log.w(TAG, "Verification attempt after timeout");
                            clearVerificationTimeout();
                            setResult("{\"color\": \"orange\", \"message\": \"انتهت مهلة التحقق\"}");
                        }


                    } else {
                        Log.d(TAG, "Template extracted but not in verification mode");
                    }
                }
            } catch (Exception e) {
                Log.e(TAG, "Error processing extracted template", e);
                if (methodChannel != null) {
                    runOnUiThread(() -> methodChannel.invokeMethod("onError", "Error processing fingerprint: " + e.getMessage()));
                }
            }
        }

        @Override 
        public void extractError(int errorCode) { 
            Log.e(TAG, "Fingerprint extract error, code: " + errorCode);
        }
    };

    private final FingerprintExceptionListener fingerprintExceptionListener = () -> {
        Log.w(TAG, "Fingerprint exception occurred");
        if (!isReseted) {
            try {
                fingerprintSensor.openAndReboot(deviceIndex);
                Log.i(TAG, "Device rebooted successfully");
            } catch (FingerprintException e) {
                Log.e(TAG, "Failed to reboot device", e);
            }
            isReseted = true;
        }
    };

    private final ZKUSBManagerListener zkusbManagerListener = new ZKUSBManagerListener() {
        @Override 
        public void onCheckPermission(int result) { 
            Log.d(TAG, "USB permission check result: " + result);
            afterGetUsbPermission(); 
        }
        @Override 
        public void onUSBArrived(UsbDevice device) { 
            Log.d(TAG, "USB device arrived");
            if (bStarted) { 
                closeDevice(); 
                tryGetUSBPermission(); 
            } 
        }
        @Override 
        public void onUSBRemoved(UsbDevice device) { 
           Log.d(TAG, "USB device removed");
    if (bStarted) {
        clearVerificationTimeout();
        closeDevice();
        setResult("{\"color\": \"red\", \"message\": \"تم فصل جهاز البصمة\"}");
    }
        }
    };

    private void afterGetUsbPermission() {
        Log.d(TAG, "USB permission granted, opening device");
        openDevice();
    }

    private void setResult(String result) {
        runOnUiThread(() -> {
            if (methodChannel != null) {
                methodChannel.invokeMethod("onResultUpdate", result);
            }
        });
    }

    private void doRegister(byte[] template) {
        Log.d(TAG, "Processing registration, step: " + (enroll_index + 1) + "/" + ENROLL_COUNT);
        
        if (enroll_index > 0 &&
            ZKFingerService.verify(regtemparray[enroll_index - 1], template) <= 0) {
            bRegister = false; 
            enroll_index = 0;
            setResult("{\"color\": \"orange\", \"message\": \"ضع نفس الإصبع السابق\"}");
            Log.w(TAG, "Registration failed - different finger detected");
            return;
        }
        
        System.arraycopy(template, 0, regtemparray[enroll_index], 0, 2048);
        enroll_index++;
        
        if (enroll_index == ENROLL_COUNT) {
            bRegister = false; 
            enroll_index = 0;
            byte[] regTemp = new byte[2048];
            int res = ZKFingerService.merge(regtemparray[0], regtemparray[1], regtemparray[2], regTemp);
            
            if (res > 0) {
                setResult("{\"color\": \"green\", \"message\": \"تم تسجيل البصمة بنجاح\"}");
                if (methodChannel != null) {
                    String base64Merged = Base64.encodeToString(regTemp, 0, res, Base64.NO_WRAP);
                    runOnUiThread(() -> methodChannel.invokeMethod("onEnrollSuccess", base64Merged));
                }
                Log.i(TAG, "Fingerprint registration successful");
            } else {
                setResult("{\"color\": \"red\", \"message\": \"فشل تسجيل البصمة\"}");
                Log.e(TAG, "Fingerprint registration failed during merge");
            }
        } else {
            setResult("{\"color\": \"orange\", \"message\": \"اضغط مرة أخرى " + (ENROLL_COUNT - enroll_index) + " مرات\"}");
            Log.d(TAG, "Registration step completed, " + (ENROLL_COUNT - enroll_index) + " more needed");
        }
    }       
    
}