import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';

typedef FingerprintEventHandler = Future<void> Function(
  String method,
  dynamic arguments,
);

class FingerprintChannelHelper {
  static const String _channelName = 'com.zk.fingerprint/channel';
  final MethodChannel _channel = const MethodChannel(_channelName);

  /// تسجيل الهاندلر للأحداث القادمة من native
  void setEventHandler(FingerprintEventHandler handler) {
    _channel.setMethodCallHandler((call) async {
      await handler(call.method, call.arguments);
    });
  }

  /// استدعاء عام
  Future<T?> _invoke<T>(String method, [Map<String, dynamic>? args]) async {
    try {
      final result = await _channel.invokeMethod<T>(method, args);
      return result;
    } on PlatformException catch (e) {
      throw 'FingerprintChannel Error: ${e.message}';
    }
  }

  /// تشغيل الماسح
  Future<void> startFingerprint() async {
    await _invoke('startFingerprint');
  }

  /// إيقاف الماسح
  Future<void> stopFingerprint() async {
    await _invoke('stopFingerprint');
  }

  /// تسجيل بصمة جديدة
  Future<void> registerFingerprint(String userId) async {
    await _invoke('registerFingerprint', {'userId': userId});
  }

  /// التحقق من البصمة
  Future<void> beginVerify(String storedTemplate) async {
    await _invoke('beginVerify', {'storedTemplate': storedTemplate});
  }

  /// تحويل صورة بصمة Base64 إلى Uint8List
  Uint8List decodeImage(String base64Str) {
    return base64Decode(base64Str);
  }
}
