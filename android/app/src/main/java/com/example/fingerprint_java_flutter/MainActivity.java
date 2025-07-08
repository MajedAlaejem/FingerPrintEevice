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
import androidx.appcompat.app.AppCompatActivity;

import android.Manifest;
import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
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

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.embedding.android.FlutterActivity;
public class MainActivity extends FlutterActivity  {

    private static final String CHANNEL = "com.zk.fingerprint/channel";

    // USB Device constants
    private static final int ZKTECO_VID = 0x1b55;
    private static final int LIVE20R_PID = 0x0120;
    private static final int LIVE10R_PID = 0x0124;

    private static final String TAG = "MainActivity";
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
    private byte[][] regtemparray = new byte[ENROLL_COUNT][2048];  //register template buffer array
    private boolean bRegister = false;

    private DBManager dbManager = new DBManager();
    private String dbFileName;

    // Flutter MethodChannel
    private MethodChannel methodChannel;

    // --- Fingerprint logic ---

    void doRegister(byte[] template) {
        byte[] bufids = new byte[256];
        int ret = ZKFingerService.identify(template, bufids, 70, 1);
        if (ret > 0) {
            String strRes[] = new String(bufids).split("\t");
            setResult("the finger already enroll by " + strRes[0] + ", cancel enroll");
            bRegister = false;
            enroll_index = 0;
            return;
        }
        if (enroll_index > 0 && (ret = ZKFingerService.verify(regtemparray[enroll_index - 1], template)) <= 0) {
            setResult("please press the same finger 3 times for the enrollment, cancel enroll, score=" + ret);
            bRegister = false;
            enroll_index = 0;
            return;
        }
        System.arraycopy(template, 0, regtemparray[enroll_index], 0, 2048);
        enroll_index++;
        if (enroll_index == ENROLL_COUNT) {
            bRegister = false;
            enroll_index = 0;
            byte[] regTemp = new byte[2048];
            if (0 < (ret = ZKFingerService.merge(regtemparray[0], regtemparray[1], regtemparray[2], regTemp))) {
                int retVal = 0;
                retVal = ZKFingerService.save(regTemp, strUid);
                if (0 == retVal) {
                    String strFeature = Base64.encodeToString(regTemp, 0, ret, Base64.NO_WRAP);
                    dbManager.insertUser(strUid, strFeature);
                    setResult("enroll succ");
                } else {
                    setResult("enroll fail, add template fail, ret=" + retVal);
                }
            } else {
                setResult("enroll fail");
            }
            bRegister = false;
        } else {
            setResult("You need to press the " + (3 - enroll_index) + " times fingerprint");
        }
    }

    void doIdentify(byte[] template) {
        byte[] bufids = new byte[256];
        int ret = ZKFingerService.identify(template, bufids, 70, 1);
        if (ret > 0) {
            String strRes[] = new String(bufids).split("\t");
            setResult("identify succ, userid:" + strRes[0].trim() + ", score:" + strRes[1].trim());
        } else {
            setResult("identify fail, ret=" + ret);
        }
    }

    private FingerprintCaptureListener fingerprintCaptureListener = new FingerprintCaptureListener() {
@Override
public void captureOK(byte[] fpImage) {
    Bitmap bitmap = ToolUtils.renderCroppedGreyScaleBitmap(fpImage, fingerprintSensor.getImageWidth(), fingerprintSensor.getImageHeight());
    ByteArrayOutputStream stream = new ByteArrayOutputStream();
    bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream);
    byte[] byteArray = stream.toByteArray();
    String base64Image = Base64.encodeToString(byteArray, Base64.NO_WRAP);

    if (methodChannel != null) {
        runOnUiThread(() -> {
            methodChannel.invokeMethod("onFingerprintImage", base64Image);
        });
    }
}


        @Override
        public void captureError(FingerprintException e) {
            // Nothing to do
        }

        @Override
        public void extractOK(byte[] fpTemplate) {
            if (bRegister) {
                doRegister(fpTemplate);
            } else {
                doIdentify(fpTemplate);
            }
        }

        @Override
        public void extractError(int i) {
            // Nothing to do
        }
    };

    private FingerprintExceptionListener fingerprintExceptionListener = new FingerprintExceptionListener() {
        @Override
        public void onDeviceException() {
            LogHelper.e("usb exception!!!");
            if (!isReseted) {
                try {
                    fingerprintSensor.openAndReboot(deviceIndex);
                } catch (FingerprintException e) {
                    e.printStackTrace();
                }
                isReseted = true;
            }
        }
    };

    private ZKUSBManagerListener zkusbManagerListener = new ZKUSBManagerListener() {
        @Override
        public void onCheckPermission(int result) {
            afterGetUsbPermission();
        }

        @Override
        public void onUSBArrived(UsbDevice device) {
            if (bStarted) {
                closeDevice();
                tryGetUSBPermission();
            }
        }

        @Override
        public void onUSBRemoved(UsbDevice device) {
            LogHelper.d("usb removed!");
        }
    };

    private void initUI() {
        // No UI elements if not using XML - skip or implement as needed
    }

    private void checkStoragePermission() {
        String[] permission = new String[]{
                Manifest.permission.READ_EXTERNAL_STORAGE,
                Manifest.permission.WRITE_EXTERNAL_STORAGE
        };
        ArrayList<String> deniedPermissions = PermissionUtils.checkPermissions(this, permission);
        if (deniedPermissions.isEmpty()) {
            Log.i(TAG, "[checkStoragePermission]: all granted");
        } else {
            int size = deniedPermissions.size();
            String[] deniedPermissionArray = deniedPermissions.toArray(new String[size]);
            PermissionUtils.requestPermission(this, deniedPermissionArray, REQUEST_PERMISSION_CODE);
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions,
                                           @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        switch (requestCode) {
            case REQUEST_PERMISSION_CODE:
                boolean granted = true;
                for (int result : grantResults) {
                    if (result != PackageManager.PERMISSION_GRANTED) {
                        granted = false;
                    }
                }
                if (granted) {
                    Toast.makeText(this, "Permission granted", Toast.LENGTH_SHORT).show();
                } else {
                    Toast.makeText(this, "Permission Denied, The application can't run on this device", Toast.LENGTH_SHORT).show();
                }
            default:
                break;
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // No setContentView if no XML layout
        dbFileName = getFilesDir().getAbsolutePath() + "/zkfinger10.db";
        initUI();
        checkStoragePermission();
        zkusbManager = new ZKUSBManager(this.getApplicationContext(), zkusbManagerListener);
        zkusbManager.registerUSBPermissionReceiver();
    }

    private void createFingerprintSensor() {
        if (fingerprintSensor != null) {
            FingprintFactory.destroy(fingerprintSensor);
            fingerprintSensor = null;
        }
        LogHelper.setLevel(Log.VERBOSE);
        LogHelper.setNDKLogLevel(Log.ASSERT);

        Map deviceParams = new HashMap();
        deviceParams.put(ParameterHelper.PARAM_KEY_VID, usb_vid);
        deviceParams.put(ParameterHelper.PARAM_KEY_PID, usb_pid);
        fingerprintSensor = FingprintFactory.createFingerprintSensor(getApplicationContext(), TransportType.USB, deviceParams);
    }

    private boolean enumSensor() {
        UsbManager usbManager = (UsbManager) this.getSystemService(Context.USB_SERVICE);
        for (UsbDevice device : usbManager.getDeviceList().values()) {
            int device_vid = device.getVendorId();
            int device_pid = device.getProductId();
            if (device_vid == ZKTECO_VID && (device_pid == LIVE20R_PID || device_pid == LIVE10R_PID)) {
                usb_pid = device_pid;
                return true;
            }
        }
        return false;
    }

    private void tryGetUSBPermission() {
        zkusbManager.initUSBPermission(usb_vid, usb_pid);
    }

    private void afterGetUsbPermission() {
        openDevice();
    }

    private void openDevice() {
        createFingerprintSensor();
        bRegister = false;
        enroll_index = 0;
        isReseted = false;
        try {
            fingerprintSensor.open(deviceIndex);

            if (dbManager.opendb(dbFileName) && dbManager.getCount() > 0) {
                HashMap<String, String> vUserList = dbManager.queryUserList();
                int ret;
                if (vUserList.size() > 0) {
                    for (Map.Entry<String, String> entry : vUserList.entrySet()) {
                        String strID = entry.getKey();
                        String strFeature = entry.getValue();
                        byte[] blobFeature = Base64.decode(strFeature, Base64.NO_WRAP);
                        ret = ZKFingerService.save(blobFeature, strID);
                        if (0 != ret) {
                            LogHelper.e("add [" + strID + "] template failed, ret=" + ret);
                        }
                    }
                }
            }

            LogHelper.d("sdk version" + fingerprintSensor.getSDK_Version());
            LogHelper.d("firmware version" + fingerprintSensor.getFirmwareVersion());
            LogHelper.d("serial:" + fingerprintSensor.getStrSerialNumber());
            LogHelper.d("width=" + fingerprintSensor.getImageWidth() + ", height=" + fingerprintSensor.getImageHeight());

            fingerprintSensor.setFingerprintCaptureListener(deviceIndex, fingerprintCaptureListener);
            fingerprintSensor.SetFingerprintExceptionListener(fingerprintExceptionListener);
            fingerprintSensor.startCapture(deviceIndex);
            bStarted = true;
            setResult("connect success!");
        } catch (FingerprintException e) {
            e.printStackTrace();
            try {
                fingerprintSensor.openAndReboot(deviceIndex);
            } catch (FingerprintException ex) {
                ex.printStackTrace();
            }
            setResult("connect failed!");
        }
    }

    private void closeDevice() {
        if (bStarted) {
            try {
                fingerprintSensor.stopCapture(deviceIndex);
                fingerprintSensor.close(deviceIndex);
            } catch (FingerprintException e) {
                e.printStackTrace();
            }
            bStarted = false;
        }
    }

public void onBnStart(View view) {
    try {
        if (bStarted) {
            setResult("Device already connected!");
            return;
        }
        if (!enumSensor()) {
            setResult("Device not found!");
            return;
        }
        tryGetUSBPermission();
    } catch (Exception e) {
        e.printStackTrace();
        if (methodChannel != null) {
            methodChannel.invokeMethod("onError", e.getMessage());
        }
    }
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
        if (bStarted) {
            strUid = "";  // default empty
            if (editText != null) {
                strUid = editText.getText().toString();
            }
            if (strUid == null || strUid.isEmpty()) {
                setResult("Please input your user id");
                bRegister = false;
                return;
            }
            if (dbManager.isUserExited(strUid)) {
                bRegister = false;
                setResult("The user[" + strUid + "] had registered!");
                return;
            }
            bRegister = true;
            enroll_index = 0;
            setResult("Please press your finger 3 times.");
        } else {
            setResult("Please start capture first");
        }
    }

    public void onBnIdentify(View view) {
        if (bStarted) {
            bRegister = false;
            enroll_index = 0;
        } else {
            setResult("Please start capture first");
        }
    }

    private void setResult(String result) {
        runOnUiThread(() -> {
            if (textView != null) {
                textView.setText(result);
            }
            // Also send result to Flutter
            if (methodChannel != null) {
                methodChannel.invokeMethod("onResultUpdate", result);
            }
        });
    }

    public void onBnDelete(View view) {
        if (bStarted) {
            strUid = "";
            if (editText != null) {
                strUid = editText.getText().toString();
            }
            if (strUid == null || strUid.isEmpty()) {
                setResult("Please input your user id");
                return;
            }
            if (!dbManager.isUserExited(strUid)) {
                setResult("The user not registered");
                return;
            }
            new AlertDialog.Builder(this)
                    .setTitle("Do you want to delete the user?")
                    .setIcon(android.R.drawable.ic_dialog_info)
                    .setPositiveButton("Yes", (dialog, which) -> {
                        if (dbManager.deleteUser(strUid)) {
                            ZKFingerService.del(strUid);
                            setResult("Delete success!");
                        } else {
                            setResult("Open db fail!");
                        }
                    })
                    .setNegativeButton("No", (dialog, which) -> {
                    })
                    .show();
        }
    }

    public void onBnClear(View view) {
        if (bStarted) {
            new AlertDialog.Builder(this)
                    .setTitle("Do you want to delete all the users?")
                    .setIcon(android.R.drawable.ic_dialog_info)
                    .setPositiveButton("Yes", (dialog, which) -> {
                        if (dbManager.clear()) {
                            ZKFingerService.clear();
                            setResult("Clear success！");
                        } else {
                            setResult("Open db fail！");
                        }
                    })
                    .setNegativeButton("No", (dialog, which) -> {
                    })
                    .show();
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (bStarted) {
            closeDevice();
        }
        if (zkusbManager != null) {
            zkusbManager.unRegisterUSBPermissionReceiver();
        }
    }



    // --- Flutter MethodChannel Integration ---@Override
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

            default:
                result.notImplemented();
                break;
        }
    });
}



}


