
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const FingerprintApp());

class FingerprintApp extends StatelessWidget {
  const FingerprintApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fingerprint Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const FingerprintHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class FingerprintHomePage extends StatefulWidget {
  const FingerprintHomePage({super.key});
  @override
  State<FingerprintHomePage> createState() => _FingerprintHomePageState();
}

class _FingerprintHomePageState extends State<FingerprintHomePage> {
  static const platform = MethodChannel('com.zk.fingerprint/channel');

  final TextEditingController _userIdController = TextEditingController();
  String _statusMessage = 'Idle';
  Uint8List? _fingerprintImage;
  String? _scannedTemplate;

  @override
  void initState() {
    super.initState();
    platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case "onResultUpdate":
          setState(() => _statusMessage = call.arguments as String);
          break;
        case "onFingerprintImage":
          setState(() => _fingerprintImage = base64Decode(call.arguments as String));
          break;
        case "onTemplateScanned":
          final template = call.arguments as String;
          setState(() => _scannedTemplate = template);
          showModalBottomSheet(
            context: context,
            builder: (_) => Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(template),
            ),
          );
          break;
        case "onError":
          final msg = call.arguments as String? ?? "Unknown error";
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
          break;
      }
    });
  }

  void _callNative(String method, [Map<String, dynamic>? args]) {
    platform.invokeMethod(method, args).then((res) {
      setState(() => _statusMessage = res as String);
    }).catchError((e) {
      setState(() => _statusMessage = "Error: ${e.message}");
    });
  }

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fingerprint Demo')),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status: $_statusMessage', style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 20),
                  Wrap(spacing: 10, children: [
                    ElevatedButton(onPressed: () => _callNative('startFingerprint'), child: const Text('Start')),
                    ElevatedButton(onPressed: () => _callNative('stopFingerprint'), child: const Text('Stop')),
                    ElevatedButton(
                      onPressed: () {
                        final id = _userIdController.text.trim();
                        if (id.isNotEmpty) _callNative('registerFingerprint', {'userId': id});
                      },
                      child: const Text('Register'),
                    ),
                    ElevatedButton(onPressed: () => _callNative('scanTemplate'), child: const Text('Scan Template')),
                  ]),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _userIdController,
                    decoration: const InputDecoration(labelText: 'User ID', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  if (_scannedTemplate != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Scanned Template:', style: TextStyle(fontWeight: FontWeight.bold)),
                        SelectableText(_scannedTemplate!),
                      ],
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: _fingerprintImage != null
                  ? Image.memory(_fingerprintImage!, width: 200, height: 200)
                  : Container(
                      width: 200,
                      height: 200,
                      color: Colors.grey[300],
                      alignment: Alignment.center,
                      child: const Text('Fingerprint image'),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
