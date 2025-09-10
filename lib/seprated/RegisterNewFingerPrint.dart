// import 'dart:convert';
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import '../helper/alert.dart';
// import '../fingerprint_channel_helper.dart';

// class RegisterNewFingerPrint extends StatefulWidget {
//   final int userId;

//   const RegisterNewFingerPrint({
//     super.key,
//     required this.userId,
//   });

//   @override
//   State<RegisterNewFingerPrint> createState() => _RegisterNewFingerPrintState();
// }

// class _RegisterNewFingerPrintState extends State<RegisterNewFingerPrint> {
//   final FingerprintChannelHelper _fingerprintHelper = FingerprintChannelHelper();
  
//   String _status = '{"color": "gray", "message": "جاهز للبدء"}';
//   Uint8List? _fpImage;
//   String? _capturedTemplate;
//   bool _isProcessing = false;
//   bool _scannerActive = false;

//   @override
//   void initState() {
//     super.initState();
//     _setupEventHandler();
//   }

//   void _setupEventHandler() {
//     _fingerprintHelper.setEventHandler((method, args) async {
//       if (!mounted) return;
      
//       switch (method) {
//         case 'onResultUpdate':
//           setState(() => _status = args as String);
//           break;

//         case 'onFingerprintImage':
//           setState(() => _fpImage = _fingerprintHelper.decodeImage(args as String));
//           break;

//         case 'onEnrollSuccess':
//           final base64Template = args as String;
//           setState(() {
//             _capturedTemplate = base64Template;
//             _isProcessing = false;
//             _status = '{"color": "green", "message": "تم تسجيل البصمة بنجاح"}';
//           });
//           break;

//         case 'onError':
//           final msg = args as String? ?? 'خطأ غير معروف';
//           setState(() {
//             _isProcessing = false;
//             _status = '{"color": "red", "message": "$msg"}';
//           });
//           break;
//       }
//     });
//   }

//   Future<void> _startRegistration() async {
//     setState(() {
//       _isProcessing = true;
//       _capturedTemplate = null;
//       _fpImage = null;
//       _status = '{"color": "blue", "message": "بدء التسجيل..."}';
//     });

//     try {
//       // Start the fingerprint scanner if not active
//       if (!_scannerActive) {
//         await _fingerprintHelper.startFingerprint();
//         setState(() => _scannerActive = true);
//         // Wait for scanner to initialize
//         await Future.delayed(const Duration(milliseconds: 1000));
//       }
      
//       // Begin registration process
//       await _fingerprintHelper.registerFingerprint(widget.userId.toString());
//     } catch (e) {
//       setState(() {
//         _isProcessing = false;
//         _status = '{"color": "red", "message": "فشل في بدء التسجيل: $e"}';
//       });
//     }
//   }

//   Future<void> _retry() async {
//     setState(() {
//       _capturedTemplate = null;
//       _fpImage = null;
//       _status = '{"color": "gray", "message": "جاهز للمحاولة مرة أخرى"}';
//     });
//     await _startRegistration();
//   }

//   Future<void> _stopScanner() async {
//     if (_scannerActive) {
//       try {
//         await _fingerprintHelper.stopFingerprint();
//         setState(() {
//           _scannerActive = false;
//           _fpImage = null;
//         });
//       } catch (e) {
//         debugPrint('Error stopping scanner: $e');
//       }
//     }
//   }

//   void _confirmAndReturn() {
//     if (_capturedTemplate != null) {
//       Navigator.of(context).pop(_capturedTemplate);
//     }
//   }

//   @override
//   void dispose() {
//     _stopScanner();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('تسجيل بصمة المستخدم ${widget.userId}'),
//         backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             // Status Indicator
//             Card(
//               elevation: 2,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(16),
//               ),
//               child: Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Row(
//                   children: [
//                     const Icon(Icons.info_outline, size: 24),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: StatusIndicator(statusObj: jsonDecode(_status)),
//                     ),
//                   ],
//                 ),
//               ),
//             ),

//             const SizedBox(height: 20),

//             // Instructions
          
//             const SizedBox(height: 20),

//             // Fingerprint Image Display
//             if (_fpImage != null)
//               Card(
//                 elevation: 2,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Padding(
//                   padding: const EdgeInsets.all(16.0),
//                   child: Column(
//                     children: [
//                       const Text(
//                         'معاينة البصمة',
//                         style: TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                       const SizedBox(height: 12),
//                       ClipRRect(
//                         borderRadius: BorderRadius.circular(12),
//                         child: Image.memory(
//                           _fpImage!,
//                           width: 200,
//                           height: 200,
//                           fit: BoxFit.cover,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),

//             const Spacer(),

//             // Action Buttons
//             Row(
//               children: [
//                 // Start/Retry Button
//                 Expanded(
//                   child: ElevatedButton.icon(
//                     onPressed: _isProcessing 
//                         ? null 
//                         : (_capturedTemplate == null ? _startRegistration : _retry),
//                     icon: _isProcessing 
//                         ? const SizedBox(
//                             width: 20,
//                             height: 20,
//                             child: CircularProgressIndicator(strokeWidth: 2),
//                           )
//                         : Icon(_capturedTemplate == null ? Icons.fingerprint : Icons.refresh),
//                     label: Text(
//                       _isProcessing 
//                           ? 'جاري التسجيل...' 
//                           : (_capturedTemplate == null ? 'بدء التسجيل' : 'إعادة المحاولة')
//                     ),
//                     style: ElevatedButton.styleFrom(
//                       padding: const EdgeInsets.symmetric(vertical: 16),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                     ),
//                   ),
//                 ),

//                 const SizedBox(width: 12),

//                 // OK Button (only show when template is captured)
//                 if (_capturedTemplate != null)
//                   Expanded(
//                     child: ElevatedButton.icon(
//                       onPressed: _confirmAndReturn,
//                       icon: const Icon(Icons.check),
//                       label: const Text('تأكيد'),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.green,
//                         foregroundColor: Colors.white,
//                         padding: const EdgeInsets.symmetric(vertical: 16),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                       ),
//                     ),
//                   ),
//               ],
//             ),

//             const SizedBox(height: 16),

//             // Cancel Button
//             SizedBox(
//               width: double.infinity,
//               child: OutlinedButton(
//                 onPressed: () => Navigator.of(context).pop(null),
//                 style: OutlinedButton.styleFrom(
//                   padding: const EdgeInsets.symmetric(vertical: 16),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                 ),
//                 child: const Text('إلغاء'),
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
import '../helper/alert.dart';
import '../fingerprint_channel_helper.dart';

class RegisterNewFingerPrint extends StatefulWidget {
  final int userId;

  const RegisterNewFingerPrint({
    super.key,
    required this.userId,
  });

  @override
  State<RegisterNewFingerPrint> createState() => _RegisterNewFingerPrintState();
}

class _RegisterNewFingerPrintState extends State<RegisterNewFingerPrint> {
  final FingerprintChannelHelper _fingerprintHelper = FingerprintChannelHelper();
  
  String _status = '{"color": "gray", "message": "جاهز للبدء"}';
  Uint8List? _fpImage;
  String? _capturedTemplate;
  bool _isProcessing = false;
  bool _scannerActive = false;
  int _enrollCount = 0; // عدد المحاولات

  @override
  void initState() {
    super.initState();
    _setupEventHandler();
  }

  void _setupEventHandler() {
    _fingerprintHelper.setEventHandler((method, args) async {
      if (!mounted) return;
      
      switch (method) {
        case 'onResultUpdate':
          setState(() => _status = args as String);
          break;

        case 'onFingerprintImage':
          setState(() => _fpImage = _fingerprintHelper.decodeImage(args as String));
          break;

        case 'onEnrollProgress': // لو جهازك يرسل progress
          setState(() {
            _enrollCount = args as int;
            _status = '{"color": "blue", "message": "أدخل البصمة ($_enrollCount/3)"}';
          });
          break;

        case 'onEnrollSuccess':
          final base64Template = args as String;
          setState(() {
            _capturedTemplate = base64Template;
            _isProcessing = false;
            _status = '{"color": "green", "message": "✅ تم تسجيل البصمة بنجاح"}';
          });
          await _stopScanner();
          break;

        case 'onError':
          final msg = args as String? ?? 'خطأ غير معروف';
          setState(() {
            _isProcessing = false;
            _status = '{"color": "red", "message": "❌ $msg"}';
          });
          break;
      }
    });
  }

  Future<void> _startRegistration() async {
    setState(() {
      _isProcessing = true;
      _capturedTemplate = null;
      _fpImage = null;
      _enrollCount = 0;
      _status = '{"color": "blue", "message": "بدء التسجيل..."}';
    });

    try {
      // Start the fingerprint scanner if not active
      if (!_scannerActive) {
        await _fingerprintHelper.startFingerprint();
        setState(() => _scannerActive = true);
        await Future.delayed(const Duration(milliseconds: 1000));
      }
      
      // Begin registration process
      await _fingerprintHelper.registerFingerprint(widget.userId.toString());
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _status = '{"color": "red", "message": "فشل في بدء التسجيل: $e"}';
      });
    }
  }

  Future<void> _retry() async {
    await _stopScanner();
    await _startRegistration();
  }

  Future<void> _stopScanner() async {
    if (_scannerActive) {
      try {
        await _fingerprintHelper.stopFingerprint();
        setState(() {
          _scannerActive = false;
          _fpImage = null;
        });
      } catch (e) {
        debugPrint('Error stopping scanner: $e');
      }
    }
  }

  void _confirmAndReturn() {
    if (_capturedTemplate != null) {
      Navigator.of(context).pop(_capturedTemplate);
    }
  }

  @override
  void dispose() {
    _stopScanner();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تسجيل بصمة المستخدم ${widget.userId}'),
        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Status Indicator
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.fingerprint, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatusIndicator(statusObj: jsonDecode(_status)),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Fingerprint Image Display
            if (_fpImage != null)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'المحاولة $_enrollCount من 3',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _fpImage!,
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const Spacer(),

            // Action Buttons
            Row(
              children: [
                // Start/Retry Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing 
                        ? null 
                        : (_capturedTemplate == null ? _startRegistration : _retry),
                    icon: _isProcessing 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_capturedTemplate == null ? Icons.fingerprint : Icons.refresh),
                    label: Text(
                      _isProcessing 
                          ? 'جاري التسجيل...' 
                          : (_capturedTemplate == null ? 'بدء التسجيل' : 'إعادة المحاولة')
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // OK Button (only show when template is captured)
                if (_capturedTemplate != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _confirmAndReturn,
                      icon: const Icon(Icons.check),
                      label: const Text('تأكيد'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Cancel Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  await _stopScanner();
                  Navigator.of(context).pop(null);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('إلغاء'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
