// package com.example.fingerprint_java_flutter;

// import android.os.Bundle;
// import android.widget.Toast;

// import androidx.annotation.NonNull;

// import java.util.Map;

// import io.flutter.embedding.android.FlutterActivity;
// import io.flutter.embedding.engine.FlutterEngine;
// import io.flutter.plugin.common.MethodChannel;

// public class MainActivity extends FlutterActivity {
//   private static final String CHANNEL = "com.example.hello";

//   @Override
//   public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
//     super.configureFlutterEngine(flutterEngine);

//     new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
//       .setMethodCallHandler((call, result) -> {
//         if (call.method.equals("printHelloWithName")) {
//           // Get arguments as a Map
//           Map<String, Object> args = call.arguments();
//           String name = (String) args.get("name");

//           String message = "Hello, " + name + " from Native Java";
//           Toast.makeText(getApplicationContext(), message, Toast.LENGTH_SHORT).show();
//           System.out.println(message);

//           result.success("Received: " + name);
//         } else {
//           result.notImplemented();
//         }
//       });
//   }
// }
// package com.example.zkfinger10demo;
// package com.example.zkfinger10demo;

package com.example.fingerprint_java_flutter;

import androidx.annotation.NonNull;
import android.Manifest;
import android.app.AlertDialog;
import android.content.Context;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbManager;
import android.os.Bundle;
import android.util.Base64;
import android.util.Log;
import android.view.View;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

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

    private static final int ZKTECO_VID = 0x1b55;
    private static final int LIVE20R_PID = 0x0120;
    private static final int LIVE10R_PID = 0x0124;

    private final int REQUEST_PERMISSION_CODE = 9;

    private ZKUSBManager zkusbManager = null;
    private FingerprintSensor fingerprintSensor = null;
    private TextView textView = null;
    private EditText editText = null;
    private int usb_vid = ZKTECO_VID;
    private int usb_pid = 0;
    private boolean bStarted = false;
    private int deviceIndex = 0;
    private boolean isReseted = false;
    private String strUid = null;
    private final static int ENROLL_COUNT = 3;
    private int enroll_index = 0;
    private byte[][] regtemparray = new byte[ENROLL_COUNT][2048];
    private boolean bRegister = false;
    private DBManager dbManager = new DBManager();
    private String dbFileName;
    private MethodChannel methodChannel;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        dbFileName = getFilesDir().getAbsolutePath() + "/zkfinger10.db";
        checkStoragePermission();
        zkusbManager = new ZKUSBManager(this.getApplicationContext(), zkusbManagerListener);
        zkusbManager.registerUSBPermissionReceiver();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (bStarted) closeDevice();
        if (zkusbManager != null) zkusbManager.unRegisterUSBPermissionReceiver();
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        methodChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL);

        methodChannel.setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "startFingerprint":
                    runOnUiThread(() -> onBnStart(null));
                    result.success("Fingerprint capture started");
                    break;
                case "stopFingerprint":
                    runOnUiThread(() -> onBnStop(null));
                    result.success("Fingerprint capture stopped");
                    break;
                case "registerFingerprint":
                    String userId = call.argument("userId");
                    runOnUiThread(() -> {
                        if (userId != null && !userId.isEmpty()) {
                            if (editText != null) {
                                editText.setText(userId);
                            }
                        }
                        onBnRegister(null);
                    });
                    result.success("Fingerprint registration started");
                    break;
                case "scanTemplate":
                    bRegister = false;
                    runOnUiThread(() -> {
                        if (!bStarted) onBnStart(null);
                        setResult("Place your finger to scan template...");
                    });
                    result.success("Scanning started");
                    break;
                default:
                    result.notImplemented();
                    break;
            }
        });
    }

    private void checkStoragePermission() {
        String[] permission = new String[]{Manifest.permission.READ_EXTERNAL_STORAGE, Manifest.permission.WRITE_EXTERNAL_STORAGE};
        ArrayList<String> deniedPermissions = PermissionUtils.checkPermissions(this, permission);
        if (!deniedPermissions.isEmpty()) {
            PermissionUtils.requestPermission(this, deniedPermissions.toArray(new String[0]), REQUEST_PERMISSION_CODE);
        }
    }

    public void onBnStart(View view) {
        if (bStarted) {
            setResult("Device already connected!");
            return;
        }
        if (!enumSensor()) {
            setResult("Device not found!");
            return;
        }
        tryGetUSBPermission();
    }

    public void onBnStop(View view) {
        if (!bStarted) {
            setResult("Device not connected!");
            return;
        }
        closeDevice();
        setResult("Device closed!");
    }

    public void onBnRegister(View view) {
        if (!bStarted) {
            setResult("Please start capture first");
            return;
        }
        strUid = "";
        if (editText != null) strUid = editText.getText().toString();
        if (strUid == null || strUid.isEmpty()) {
            setResult("Please input your user id");
            bRegister = false;
            return;
        }
        if (dbManager.isUserExited(strUid)) {
            setResult("The user[" + strUid + "] had registered!");
            bRegister = false;
            return;
        }
        bRegister = true;
        enroll_index = 0;
        setResult("Please press your finger 3 times.");
    }

    private boolean enumSensor() {
        UsbManager usbManager = (UsbManager) getSystemService(Context.USB_SERVICE);
        for (UsbDevice device : usbManager.getDeviceList().values()) {
            if (device.getVendorId() == ZKTECO_VID && (device.getProductId() == LIVE20R_PID || device.getProductId() == LIVE10R_PID)) {
                usb_pid = device.getProductId();
                return true;
            }
        }
        return false;
    }

    private void tryGetUSBPermission() {
        zkusbManager.initUSBPermission(usb_vid, usb_pid);
    }

    private void openDevice() {
        createFingerprintSensor();
        try {
            fingerprintSensor.open(deviceIndex);
            fingerprintSensor.setFingerprintCaptureListener(deviceIndex, fingerprintCaptureListener);
            fingerprintSensor.SetFingerprintExceptionListener(fingerprintExceptionListener);
            fingerprintSensor.startCapture(deviceIndex);
            bStarted = true;
            setResult("connect success!");
        } catch (FingerprintException e) {
            e.printStackTrace();
            setResult("connect failed!");
        }
    }

    private void closeDevice() {
        try {
            fingerprintSensor.stopCapture(deviceIndex);
            fingerprintSensor.close(deviceIndex);
        } catch (Exception e) {
            e.printStackTrace();
        }
        bStarted = false;
    }

    private void createFingerprintSensor() {
        if (fingerprintSensor != null) {
            FingprintFactory.destroy(fingerprintSensor);
            fingerprintSensor = null;
        }
        Map deviceParams = new HashMap();
        deviceParams.put(ParameterHelper.PARAM_KEY_VID, usb_vid);
        deviceParams.put(ParameterHelper.PARAM_KEY_PID, usb_pid);
        fingerprintSensor = FingprintFactory.createFingerprintSensor(getApplicationContext(), TransportType.USB, deviceParams);
    }

    private final FingerprintCaptureListener fingerprintCaptureListener = new FingerprintCaptureListener() {
        @Override
        public void captureOK(byte[] fpImage) {
            Bitmap bitmap = ToolUtils.renderCroppedGreyScaleBitmap(fpImage, fingerprintSensor.getImageWidth(), fingerprintSensor.getImageHeight());
            ByteArrayOutputStream stream = new ByteArrayOutputStream();
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream);
            String base64Image = Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP);
            if (methodChannel != null) {
                runOnUiThread(() -> methodChannel.invokeMethod("onFingerprintImage", base64Image));
            }
        }

        @Override
        public void captureError(FingerprintException e) {}

        @Override
        public void extractOK(byte[] fpTemplate) {
            if (methodChannel != null) {
                String base64Template = Base64.encodeToString(fpTemplate, Base64.NO_WRAP);
                runOnUiThread(() -> methodChannel.invokeMethod("onTemplateScanned", base64Template));
            }
            if (bRegister) {
                doRegister(fpTemplate);
            } else {
                doIdentify(fpTemplate);
            }
        }

        @Override
        public void extractError(int i) {}
    };

    private final FingerprintExceptionListener fingerprintExceptionListener = () -> {
        if (!isReseted) {
            try {
                fingerprintSensor.openAndReboot(deviceIndex);
            } catch (FingerprintException e) {
                e.printStackTrace();
            }
            isReseted = true;
        }
    };

    private final ZKUSBManagerListener zkusbManagerListener = new ZKUSBManagerListener() {
        @Override public void onCheckPermission(int result) { afterGetUsbPermission(); }
        @Override public void onUSBArrived(UsbDevice device) { if (bStarted) { closeDevice(); tryGetUSBPermission(); } }
        @Override public void onUSBRemoved(UsbDevice device) { LogHelper.d("usb removed!"); }
    };

    private void afterGetUsbPermission() {
        openDevice();
    }

    private void setResult(String result) {
        runOnUiThread(() -> {
            if (textView != null) textView.setText(result);
            if (methodChannel != null) methodChannel.invokeMethod("onResultUpdate", result);
        });
    }

    private void doRegister(byte[] template) {
        byte[] bufids = new byte[256];
        int ret = ZKFingerService.identify(template, bufids, 70, 1);
        if (ret > 0) {
            bRegister = false; enroll_index = 0;
            setResult("already enrolled");
            return;
        }
        if (enroll_index > 0 && ZKFingerService.verify(regtemparray[enroll_index - 1], template) <= 0) {
            bRegister = false; enroll_index = 0;
            setResult("press the same finger");
            return;
        }
        System.arraycopy(template, 0, regtemparray[enroll_index], 0, 2048);
        enroll_index++;
        if (enroll_index == ENROLL_COUNT) {
            bRegister = false; enroll_index = 0;
            byte[] regTemp = new byte[2048];
            int res = ZKFingerService.merge(regtemparray[0], regtemparray[1], regtemparray[2], regTemp);
            if (res > 0 && ZKFingerService.save(regTemp, strUid) == 0) {
                dbManager.insertUser(strUid, Base64.encodeToString(regTemp, 0, res, Base64.NO_WRAP));
                setResult("enroll success");
            } else {
                setResult("enroll failed");
            }
        } else {
            setResult("Press again " + (ENROLL_COUNT - enroll_index) + " times");
        }
    }

    private void doIdentify(byte[] template) {
        byte[] bufids = new byte[256];
        int ret = ZKFingerService.identify(template, bufids, 70, 1);
        if (ret > 0) {
            String[] res = new String(bufids).split("\t");
            setResult("Identify success: " + res[0]);
        } else {
            setResult("Identify failed");
        }
    }
}