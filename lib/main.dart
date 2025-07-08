// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:fluttertoast/fluttertoast.dart';

// void main() {
//   runApp(const FingerprintApp());
// }

// class FingerprintApp extends StatelessWidget {
//   const FingerprintApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Fingerprint Demo',
//       theme: ThemeData(primarySwatch: Colors.blue),
//       home: const FingerprintHomePage(),
//     );
//   }
// }

// class FingerprintHomePage extends StatefulWidget {
//   const FingerprintHomePage({super.key});

//   @override
//   State<FingerprintHomePage> createState() => _FingerprintHomePageState();
// }

// class _FingerprintHomePageState extends State<FingerprintHomePage> {
//   static const platform = MethodChannel('com.zk.fingerprint/channel');

//   final TextEditingController _userIdController = TextEditingController();
//   String _statusMessage = 'Idle';
//   Uint8List? _fingerprintImageBytes;

//   @override
//   void initState() {
//     super.initState();

//     platform.setMethodCallHandler((call) async {
//       if (call.method == "onResultUpdate") {
//         final String message = call.arguments as String;
//         if (mounted) {
//           setState(() {
//             _statusMessage = message;
//           });
//         }
//       } else if (call.method == "onFingerprintImage") {
//         final String base64Image = call.arguments as String;
//         final imageBytes = base64Decode(base64Image);
//         if (mounted) {
//           setState(() {
//             _fingerprintImageBytes = imageBytes;
//           });
//         }
//       } else if (call.method == "onError") {
//         final String errorMsg = call.arguments as String? ?? "Unknown error";
//         if (mounted) {
//           Fluttertoast.showToast(
//             msg: errorMsg,
//             toastLength: Toast.LENGTH_LONG,
//             gravity: ToastGravity.BOTTOM,
//           );
//         }
//       }
//     });
//   }

//   Future<void> _startFingerprint() async {
//     try {
//       final String result = await platform.invokeMethod('startFingerprint');
//       if (mounted) {
//         setState(() {
//           _statusMessage = result;
//         });
//       }
//     } on PlatformException catch (e) {
//       if (mounted) {
//         setState(() {
//           _statusMessage = "Failed to start fingerprint: '${e.message}'.";
//         });
//       }
//     }
//   }

//   Future<void> _stopFingerprint() async {
//     try {
//       final String result = await platform.invokeMethod('stopFingerprint');
//       if (mounted) {
//         setState(() {
//           _statusMessage = result;
//           _fingerprintImageBytes = null;
//         });
//       }
//     } on PlatformException catch (e) {
//       if (mounted) {
//         setState(() {
//           _statusMessage = "Failed to stop fingerprint: '${e.message}'.";
//         });
//       }
//     }
//   }

//   Future<void> _registerFingerprint() async {
//     final String userId = _userIdController.text.trim();
//     if (userId.isEmpty) {
//       if (mounted) {
//         setState(() {
//           _statusMessage = "Please enter a User ID to register.";
//         });
//       }
//       return;
//     }

//     try {
//       final String result = await platform.invokeMethod('registerFingerprint', {
//         "userId": userId,
//       });
//       if (mounted) {
//         setState(() {
//           _statusMessage = result;
//         });
//       }
//     } on PlatformException catch (e) {
//       if (mounted) {
//         setState(() {
//           _statusMessage = "Failed to register fingerprint: '${e.message}'.";
//         });
//       }
//     }
//   }

//   @override
//   void dispose() {
//     _userIdController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Fingerprint Demo')),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             TextField(
//               controller: _userIdController,
//               decoration: const InputDecoration(
//                 labelText: 'User ID',
//                 border: OutlineInputBorder(),
//               ),
//             ),
//             const SizedBox(height: 20),
//             Text(
//               'Status: $_statusMessage',
//               style: const TextStyle(fontSize: 16),
//             ),
//             const SizedBox(height: 20),
//             if (_fingerprintImageBytes != null)
//               Image.memory(
//                 _fingerprintImageBytes!,
//                 width: 200,
//                 height: 200,
//                 fit: BoxFit.contain,
//               )
//             else
//               Container(
//                 width: 200,
//                 height: 200,
//                 color: Colors.grey[300],
//                 alignment: Alignment.center,
//                 child: const Text(
//                   'Fingerprint image will appear here',
//                   textAlign: TextAlign.center,
//                   style: TextStyle(color: Colors.black54),
//                 ),
//               ),
//             const SizedBox(height: 20),
//             Wrap(
//               spacing: 12,
//               children: [
//                 ElevatedButton(
//                   onPressed: _startFingerprint,
//                   child: const Text('Start Capture'),
//                 ),
//                 ElevatedButton(
//                   onPressed: _stopFingerprint,
//                   child: const Text('Stop Capture'),
//                 ),
//                 ElevatedButton(
//                   onPressed: _registerFingerprint,
//                   child: const Text('Register Fingerprint'),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 20),
//             Expanded(
//               child: Center(
//                 child: Text(
//                   'Use native UI for fingerprint prompts.\nFlutter displays status and image.',
//                   style: TextStyle(color: Colors.grey[600]),
//                   textAlign: TextAlign.center,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'dart:convert';
import 'dart:typed_data';
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
