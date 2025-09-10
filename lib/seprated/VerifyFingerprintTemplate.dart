// import 'dart:convert';
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import '../helper/alert.dart';
// import '../fingerprint_channel_helper.dart';

// class VerifyFingerprintTemplate extends StatefulWidget {
//   final String fingerprintTemplate;
//   final String? userName; // Optional user name for display

//   const VerifyFingerprintTemplate({
//     super.key,
//     required this.fingerprintTemplate,
//     this.userName,
//   });

//   @override
//   State<VerifyFingerprintTemplate> createState() => _VerifyFingerprintTemplateState();
// }

// class _VerifyFingerprintTemplateState extends State<VerifyFingerprintTemplate> {
//   final FingerprintChannelHelper _fingerprintHelper = FingerprintChannelHelper();
  
//   String _status = '{"color": "gray", "message": "جاهز للبدء"}';
//   Uint8List? _fpImage;
//   bool? _verificationResult;
//   bool _isProcessing = false;
//   bool _scannerActive = false;
//   bool _verificationStarted = false;

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

//         case 'onVerifyResult':
//           final matched = args as bool;
//           setState(() {
//             _verificationResult = matched;
//             _isProcessing = false;
//             _verificationStarted = false;
//             _status = matched 
//                 ? '{"color": "green", "message": "✅ البصمة صحيحة"}'
//                 : '{"color": "red", "message": "❌ فشل التحقق"}';
//           });
//           break;

//         case 'onVerifyTimeout':
//           setState(() {
//             _verificationResult = false;
//             _isProcessing = false;
//             _verificationStarted = false;
//             _status = '{"color": "orange", "message": "انتهت مهلة التحقق (20 ثانية)"}';
//           });
//           break;

//         case 'onError':
//           final msg = args as String? ?? 'خطأ غير معروف';
//           setState(() {
//             _isProcessing = false;
//             _verificationStarted = false;
//             _status = '{"color": "red", "message": "$msg"}';
//           });
//           break;
//       }
//     });
//   }

//   Future<void> _startVerification() async {
//     setState(() {
//       _isProcessing = true;
//       _verificationResult = null;
//       _fpImage = null;
//       _verificationStarted = true;
//       _status = '{"color": "blue", "message": "بدء التحقق..."}';
//     });

//     try {
//       // Start the fingerprint scanner if not active
//       if (!_scannerActive) {
//         await _fingerprintHelper.startFingerprint();
//         setState(() => _scannerActive = true);
//         // Wait for scanner to initialize
//         await Future.delayed(const Duration(milliseconds: 1000));
//       }
      
//       // Begin verification process with 20-second timeout
//       await _fingerprintHelper.beginVerify(widget.fingerprintTemplate);
//     } catch (e) {
//       setState(() {
//         _isProcessing = false;
//         _verificationStarted = false;
//         _status = '{"color": "red", "message": "فشل في بدء التحقق: $e"}';
//       });
//     }
//   }

//   Future<void> _retry() async {
//     setState(() {
//       _verificationResult = null;
//       _fpImage = null;
//       _status = '{"color": "gray", "message": "جاهز للمحاولة مرة أخرى"}';
//     });
//     await _startVerification();
//   }

//   Future<void> _stopVerification() async {
//     if (_verificationStarted) {
//       try {
//         await _fingerprintHelper.stopVerify();
//         setState(() {
//           _isProcessing = false;
//           _verificationStarted = false;
//           _status = '{"color": "gray", "message": "تم إيقاف التحقق"}';
//         });
//       } catch (e) {
//         debugPrint('Error stopping verification: $e');
//       }
//     }
//   }

//   Future<void> _stopScanner() async {
//     if (_scannerActive) {
//       try {
//         await _fingerprintHelper.stopFingerprint();

//           _scannerActive = false;
//           _fpImage = null;
      
//       } catch (e) {
//         debugPrint('Error stopping scanner: $e');
//       }
//     }
//   }

//   void _confirmAndReturn() {
//     Navigator.of(context).pop(_verificationResult ?? false);
//   }

//   @override
//   void dispose() {
//     _stopVerification();
//     _stopScanner();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('التحقق من البصمة${widget.userName != null ? ' - ${widget.userName}' : ''}'),
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
//                     const Icon(Icons.verified_user, size: 24),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: StatusIndicator(statusObj: jsonDecode(_status)),
//                     ),
//                   ],
//                 ),
//               ),
//             ),

//             const SizedBox(height: 20),

         


//             // Result Display
//             if (_verificationResult != null)
//               Card(
//                 elevation: 2,
//                 color: _verificationResult == true 
//                     ? Colors.green.withOpacity(0.1) 
//                     : Colors.red.withOpacity(0.1),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Padding(
//                   padding: const EdgeInsets.all(16.0),
//                   child: Row(
//                     children: [
//                       Icon(
//                         _verificationResult == true ? Icons.check_circle : Icons.cancel,
//                         color: _verificationResult == true ? Colors.green : Colors.red,
//                         size: 32,
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: Text(
//                           _verificationResult == true 
//                               ? 'تم التحقق بنجاح! البصمة متطابقة.' 
//                               : 'فشل التحقق! البصمة غير متطابقة.',
//                           style: TextStyle(
//                             fontSize: 16,
//                             fontWeight: FontWeight.bold,
//                             color: _verificationResult == true ? Colors.green : Colors.red,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),

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
//                         'معاينة البصمة المسحوبة',
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
//                         : (_verificationResult == null ? _startVerification : _retry),
//                     icon: _isProcessing 
//                         ? const SizedBox(
//                             width: 20,
//                             height: 20,
//                             child: CircularProgressIndicator(strokeWidth: 2),
//                           )
//                         : Icon(_verificationResult == null ? Icons.fingerprint : Icons.refresh),
//                     label: Text(
//                       _isProcessing 
//                           ? 'جاري التحقق...' 
//                           : (_verificationResult == null ? 'بدء التحقق' : 'إعادة المحاولة')
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

//                 // Stop Verification Button (only show during processing)
//                 if (_isProcessing && _verificationStarted)
//                   Expanded(
//                     child: OutlinedButton.icon(
//                       onPressed: _stopVerification,
//                       icon: const Icon(Icons.stop, color: Colors.orange),
//                       label: const Text(
//                         'إيقاف',
//                         style: TextStyle(color: Colors.orange),
//                       ),
//                       style: OutlinedButton.styleFrom(
//                         padding: const EdgeInsets.symmetric(vertical: 16),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         side: const BorderSide(color: Colors.orange),
//                       ),
//                     ),
//                   ),

//                 // OK Button (only show when verification is complete)
//                 if (_verificationResult != null)
//                   Expanded(
//                     child: ElevatedButton.icon(
//                       onPressed: _confirmAndReturn,
//                       icon: const Icon(Icons.check),
//                       label: const Text('تأكيد'),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: _verificationResult == true ? Colors.green : Colors.blue,
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
//                 onPressed: () => Navigator.of(context).pop(false),
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

class VerifyFingerprintTemplate extends StatefulWidget {
  final String fingerprintTemplate;
  final String? userName; // Optional user name for display

  const VerifyFingerprintTemplate({
    super.key,
    required this.fingerprintTemplate,
    this.userName,
  });

  @override
  State<VerifyFingerprintTemplate> createState() => _VerifyFingerprintTemplateState();
}

class _VerifyFingerprintTemplateState extends State<VerifyFingerprintTemplate> {
  final FingerprintChannelHelper _fingerprintHelper = FingerprintChannelHelper();

  String _status = '{"color": "gray", "message": "جاهز للبدء"}';
  Uint8List? _fpImage;
  bool? _verificationResult;
  bool _isProcessing = false;
  bool _scannerActive = false;
  bool _verificationStarted = false;

  @override
  void initState() {
    super.initState();
    _setupEventHandler();
  }

  void _setupEventHandler() {
    // Register event handler from native side.
    // Handler checks mounted before any setState calls.
    _fingerprintHelper.setEventHandler((method, args) async {
      if (!mounted) return; // extra safety

      switch (method) {
        case 'onResultUpdate':
          if (!mounted) return;
          setState(() => _status = args as String);
          break;

        case 'onFingerprintImage':
          if (!mounted) return;
          setState(() => _fpImage = _fingerprintHelper.decodeImage(args as String));
          break;

        case 'onVerifyResult':
          final matched = args as bool;
          if (!mounted) return;
          setState(() {
            _verificationResult = matched;
            _isProcessing = false;
            _verificationStarted = false;
            _status = matched
                ? '{"color": "green", "message": "✅ البصمة صحيحة"}'
                : '{"color": "red", "message": "❌ فشل التحقق"}';
          });
          break;

        case 'onVerifyTimeout':
          if (!mounted) return;
          setState(() {
            _verificationResult = false;
            _isProcessing = false;
            _verificationStarted = false;
            _status = '{"color": "orange", "message": "انتهت مهلة التحقق (20 ثانية)"}';
          });
          break;

        case 'onError':
          final msg = args as String? ?? 'خطأ غير معروف';
          if (!mounted) return;
          setState(() {
            _isProcessing = false;
            _verificationStarted = false;
            _status = '{"color": "red", "message": "$msg"}';
          });
          break;

        default:
          // optional: debug print for unknown events
          // debugPrint('Native event: $method -> $args');
          break;
      }
    });
  }

  Future<void> _startVerification() async {
    if (!mounted) return;
    setState(() {
      _isProcessing = true;
      _verificationResult = null;
      _fpImage = null;
      _verificationStarted = true;
      _status = '{"color": "blue", "message": "بدء التحقق..."}';
    });

    try {
      // Start the fingerprint scanner if not active
      if (!_scannerActive) {
        await _fingerprintHelper.startFingerprint();
        if (!mounted) return;
        setState(() => _scannerActive = true);
        // Wait for scanner to initialize (small delay)
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Begin verification process with 20-second timeout
      await _fingerprintHelper.beginVerify(widget.fingerprintTemplate);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _verificationStarted = false;
        _status = '{"color": "red", "message": "فشل في بدء التحقق: $e"}';
      });
    }
  }

  Future<void> _retry() async {
    if (!mounted) return;
    setState(() {
      _verificationResult = null;
      _fpImage = null;
      _status = '{"color": "gray", "message": "جاهز للمحاولة مرة أخرى"}';
    });
    await _startVerification();
  }

  /// Called by user action to stop verification while the widget is still mounted.
  Future<void> _stopVerification() async {
    if (_verificationStarted) {
      try {
        await _fingerprintHelper.stopVerify();
        if (!mounted) return; // IMPORTANT: avoid setState after dispose
        setState(() {
          _isProcessing = false;
          _verificationStarted = false;
          _status = '{"color": "gray", "message": "تم إيقاف التحقق"}';
        });
      } catch (e) {
        debugPrint('Error stopping verification: $e');
      }
    }
  }

  /// Called by user action to stop scanner while the widget is still mounted.
  Future<void> _stopScanner() async {
    if (_scannerActive) {
      try {
        await _fingerprintHelper.stopFingerprint();
        if (!mounted) return; // IMPORTANT: avoid setState after dispose
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
    Navigator.of(context).pop(_verificationResult ?? false);
  }

  @override
  void dispose() {
    // 1) Clear native event handler to avoid callbacks after dispose.
    //    (Set a no-op handler)
    _fingerprintHelper.setEventHandler((_, __) async {
      // no-op
    });

    // 2) Ask native to stop verification & scanner (fire-and-forget).
    //    Do NOT await and DO NOT call setState here.
    try {
      if (_verificationStarted) {
        _fingerprintHelper.stopVerify().catchError((e) {
          debugPrint('Error stopping verification in dispose: $e');
        });
      }
    } catch (e) {
      // just in case
      debugPrint('dispose stopVerify error: $e');
    }

    try {
      if (_scannerActive) {
        _fingerprintHelper.stopFingerprint().catchError((e) {
          debugPrint('Error stopping scanner in dispose: $e');
        });
      }
    } catch (e) {
      debugPrint('dispose stopFingerprint error: $e');
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('التحقق من البصمة${widget.userName != null ? ' - ${widget.userName}' : ''}'),
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
                    const Icon(Icons.verified_user, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatusIndicator(statusObj: jsonDecode(_status)),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Result Display
            if (_verificationResult != null)
              Card(
                elevation: 2,
                color: _verificationResult == true
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        _verificationResult == true ? Icons.check_circle : Icons.cancel,
                        color: _verificationResult == true ? Colors.green : Colors.red,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _verificationResult == true
                              ? 'تم التحقق بنجاح! البصمة متطابقة.'
                              : 'فشل التحقق! البصمة غير متطابقة.',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _verificationResult == true ? Colors.green : Colors.red,
                          ),
                        ),
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
                      const Text(
                        'معاينة البصمة المسحوبة',
                        style: TextStyle(
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
                    onPressed: _isProcessing ? null : (_verificationResult == null ? _startVerification : _retry),
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_verificationResult == null ? Icons.fingerprint : Icons.refresh),
                    label: Text(
                      _isProcessing ? 'جاري التحقق...' : (_verificationResult == null ? 'بدء التحقق' : 'إعادة المحاولة'),
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

                // Stop Verification Button (only show during processing)
                if (_isProcessing && _verificationStarted)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _stopVerification,
                      icon: const Icon(Icons.stop, color: Colors.orange),
                      label: const Text(
                        'إيقاف',
                        style: TextStyle(color: Colors.orange),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: Colors.orange),
                      ),
                    ),
                  ),

                // OK Button (only show when verification is complete)
                if (_verificationResult != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _confirmAndReturn,
                      icon: const Icon(Icons.check),
                      label: const Text('تأكيد'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _verificationResult == true ? Colors.green : Colors.blue,
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
                onPressed: () => Navigator.of(context).pop(false),
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
