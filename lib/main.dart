
// import 'dart:convert';
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'db_helper.dart';

// void main() => runApp(const FingerprintApp());

// class FingerprintApp extends StatelessWidget {
//   const FingerprintApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Fingerprint Demo',
//       theme: ThemeData(
//         useMaterial3: true,
//         colorSchemeSeed: Colors.blue,
//       ),
//       home: const FingerprintHomePage(),
//       debugShowCheckedModeBanner: false,
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

//   final TextEditingController _nameController = TextEditingController();

//   String _status = 'Idle';
//   Uint8List? _fpImage;

//   int? _selectedId;
//   String? _selectedName;
//   String? _selectedTemplate;

//   // Panels state
//   bool _showRegister = false;
//   bool _showVerify = false;
//   bool _scannerActive = false; // لتفادي تكرار start/stop

//   @override
//   void initState() {
//     super.initState();

//     platform.setMethodCallHandler((call) async {
//       switch (call.method) {
//         case 'onResultUpdate':
//           setState(() => _status = call.arguments as String);
//           break;

//         case 'onFingerprintImage':
//           setState(() => _fpImage = base64Decode(call.arguments as String));
//           break;

//         case 'onEnrollSuccess':
//           // Java يرسل الـ merged template بعد اكتمال الثلاث ضغطات
//           final base64Merged = call.arguments as String;
//           final name = _nameController.text.trim();
//           if (name.isNotEmpty) {
//             await DBHelper.insertFingerprint(name, base64Merged);
//             if (mounted) {
//               ScaffoldMessenger.of(context)
//                   .showSnackBar(SnackBar(content: Text('✅ Saved $name')));
//               setState(() {
//                 _nameController.clear();
//                 _showRegister = false; // سلوك مماثل لإغلاق الـ sheet
//                 _fpImage = null;
//               });
//               _recomputeScanner();
//             }
//           }
//           break;

//         case 'onTemplateScanned':
//           // (اختياري/للعرض) استلام قالب مباشر من الالتقاط
//           break;

//         case 'onVerifyResult':
//           final bool matched = call.arguments as bool;
//           final text = matched
//               ? '✅ Same person: ${_selectedName ?? ""}'
//               : '❌ Access denied';
//           ScaffoldMessenger.of(context)
//               .showSnackBar(SnackBar(content: Text(text)));
//           break;

//         case 'onError':
//           final msg = call.arguments as String? ?? 'Unknown error';
//           ScaffoldMessenger.of(context)
//               .showSnackBar(SnackBar(content: Text(msg)));
//           break;
//       }
//     });
//   }

//   Future<void> _invoke(String method, [Map<String, dynamic>? args]) async {
//     try {
//       final res = await platform.invokeMethod(method, args);
//       if (res is String) setState(() => _status = res);
//     } catch (e) {
//       setState(() => _status = 'Error: $e');
//     }
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     super.dispose();
//   }

//   // تشغيل/إيقاف الماسح حسب حالة Panels المفتوحة
//   void _recomputeScanner() {
//     final shouldBeActive = _showRegister || _showVerify;
//     if (shouldBeActive != _scannerActive) {
//       _scannerActive = shouldBeActive;
//       if (_scannerActive) {
//         _invoke('startFingerprint');
//       } else {
//         _invoke('stopFingerprint');
//         setState(() {
//           _fpImage = null; // تنظيف المعاينة عند الإيقاف
//         });
//       }
//     }
//   }

//   void _toggleRegisterPanel() {
//     setState(() => _showRegister = !_showRegister);
//     if (_showRegister) {
//       // فتح تسجيل => تشغيل الماسح
//       _recomputeScanner();
//     } else {
//       _recomputeScanner();
//     }
//   }

//   void _toggleVerifyPanel() {
//     if (_selectedTemplate == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Select a fingerprint first')),
//       );
//       return;
//     }
//     setState(() => _showVerify = !_showVerify);
//     _recomputeScanner();
//   }

//   Future<void> _beginRegister() async {
//     final name = _nameController.text.trim();
//     if (name.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Enter a name first')),
//       );
//       return;
//     }
//     // في الـ sheet كنا نشغل الماسح قبل النداء. هنا الماسح شغال لأن البانل مفتوح.
//     await _invoke('registerFingerprint', {'userId': name});
//   }

//   Future<void> _beginVerify() async {
//     if (_selectedTemplate == null) return;
//     await _invoke('beginVerify', {'storedTemplate': _selectedTemplate});
//     // لا نغلق تلقائيًا للحفاظ على سلوك مشابه للـ sheet (يبقى حتى يغلقه المستخدم)
//   }

//   Widget _buildRegisterPanel() {
//     return AnimatedSwitcher(
//       duration: const Duration(milliseconds: 250),
//       child: !_showRegister
//           ? const SizedBox.shrink()
//           : Card(
//               key: const ValueKey('registerPanel'),
//               margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(16),
//               ),
//               elevation: 0,
//               child: Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: Column(
//                   children: [
//                     Row(
//                       children: [
//                         const Icon(Icons.fingerprint),
//                         const SizedBox(width: 8),
//                         const Text(
//                           'Register Fingerprint',
//                           style: TextStyle(
//                               fontSize: 18, fontWeight: FontWeight.w600),
//                         ),
//                         const Spacer(),
//                         IconButton(
//                           tooltip: 'Close',
//                           onPressed: () {
//                             setState(() => _showRegister = false);
//                             _recomputeScanner();
//                           },
//                           icon: const Icon(Icons.close),
//                         )
//                       ],
//                     ),
//                     const SizedBox(height: 8),
//                     TextField(
//                       controller: _nameController,
//                       decoration: const InputDecoration(
//                         labelText: 'Name',
//                         border: OutlineInputBorder(),
//                         prefixIcon: Icon(Icons.person),
//                       ),
//                     ),
//                     const SizedBox(height: 10),
//                     Row(
//                       children: [
//                         const Icon(Icons.info_outline, size: 18),
//                         const SizedBox(width: 6),
//                         Expanded(
//                           child: Text(
//                             'Press the same finger 3 times when prompted.',
//                             style: TextStyle(color: Colors.grey[700]),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 12),
//                     Row(
//                       children: [
//                         ElevatedButton.icon(
//                           onPressed: _beginRegister,
//                           icon: const Icon(Icons.add),
//                           label: const Text('Add'),
//                         ),
//                         const SizedBox(width: 12),
//                         OutlinedButton.icon(
//                           onPressed: () {
//                             _nameController.clear();
//                             setState(() => _fpImage = null);
//                           },
//                           icon: const Icon(Icons.refresh),
//                           label: const Text('Reset'),
//                         ),
//                       ],
//                     ),
//                     if (_fpImage != null) ...[
//                       const SizedBox(height: 12),
//                       ClipRRect(
//                         borderRadius: BorderRadius.circular(12),
//                         child: Image.memory(
//                           _fpImage!,
//                           width: 220,
//                           height: 220,
//                           fit: BoxFit.cover,
//                         ),
//                       ),
//                     ],
//                   ],
//                 ),
//               ),
//             ),
//     );
//   }

//   Widget _buildVerifyPanel() {
//     return AnimatedSwitcher(
//       duration: const Duration(milliseconds: 250),
//       child: !_showVerify
//           ? const SizedBox.shrink()
//           : Card(
//               key: const ValueKey('verifyPanel'),
//               margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(16),
//               ),
//               elevation: 0,
//               child: Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: Column(
//                   children: [
//                     Row(
//                       children: [
//                         const Icon(Icons.verified),
//                         const SizedBox(width: 8),
//                         Text(
//                           'Verify ${_selectedName ?? ""}',
//                           style: const TextStyle(
//                               fontSize: 18, fontWeight: FontWeight.w600),
//                         ),
//                         const Spacer(),
//                         IconButton(
//                           tooltip: 'Close',
//                           onPressed: () {
//                             setState(() => _showVerify = false);
//                             _recomputeScanner();
//                           },
//                           icon: const Icon(Icons.close),
//                         )
//                       ],
//                     ),
//                     const SizedBox(height: 8),
//                     const Align(
//                       alignment: Alignment.centerLeft,
//                       child: Text('Place finger on the scanner to verify.'),
//                     ),
//                     const SizedBox(height: 12),
//                     Row(
//                       children: [
//                         ElevatedButton.icon(
//                           onPressed: _beginVerify,
//                           icon: const Icon(Icons.fingerprint),
//                           label: const Text('Scan & Verify'),
//                         ),
//                         const SizedBox(width: 12),
//                         OutlinedButton.icon(
//                           onPressed: () {
//                             setState(() => _fpImage = null);
//                           },
//                           icon: const Icon(Icons.clear),
//                           label: const Text('Clear preview'),
//                         ),
//                       ],
//                     ),
//                     if (_fpImage != null) ...[
//                       const SizedBox(height: 12),
//                       ClipRRect(
//                         borderRadius: BorderRadius.circular(12),
//                         child: Image.memory(
//                           _fpImage!,
//                           width: 220,
//                           height: 220,
//                           fit: BoxFit.cover,
//                         ),
//                       ),
//                     ],
//                   ],
//                 ),
//               ),
//             ),
//     );
//   }

//   Widget _buildList() {
//     return FutureBuilder(
//       future: DBHelper.getFingerprints(),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData) {
//           return const Center(child: CircularProgressIndicator());
//         }
//         final data = snapshot.data as List<Map<String, dynamic>>;
//         if (data.isEmpty) {
//           return const Center(child: Text('No fingerprints saved'));
//         }
//         return ListView.separated(
//           itemCount: data.length,
//           separatorBuilder: (_, __) => const Divider(height: 0),
//           itemBuilder: (context, i) {
//             final item = data[i];
//             final selected = _selectedId == item['id'];
//             return ListTile(
//               selected: selected,
//               selectedTileColor:
//                   Theme.of(context).colorScheme.primary.withOpacity(0.06),
//               leading: CircleAvatar(
//                 child: Text(item['name'].toString().characters.first),
//               ),
//               title: Text(item['name']),
//               subtitle: selected ? const Text('Selected') : null,
//               trailing: IconButton(
//                 icon: const Icon(Icons.delete_outline),
//                 onPressed: () async {
//                   await DBHelper.deleteFingerprint(item['id']);
//                   if (_selectedId == item['id']) {
//                     _selectedId = null;
//                     _selectedName = null;
//                     _selectedTemplate = null;
//                     // إغلاق بانل التحقق إذا العنصر المحذوف هو المحدد
//                     if (_showVerify) {
//                       setState(() => _showVerify = false);
//                       _recomputeScanner();
//                     }
//                   }
//                   setState(() {});
//                 },
//               ),
//               onTap: () {
//                 setState(() {
//                   if (selected) {
//                     _selectedId = null;
//                     _selectedName = null;
//                     _selectedTemplate = null;
//                   } else {
//                     _selectedId = item['id'] as int;
//                     _selectedName = item['name'] as String;
//                     _selectedTemplate = item['template'] as String;
//                   }
//                 });
//               },
//             );
//           },
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final canVerify = _selectedId != null;

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Fingerprint Demo'),
//       ),
//       floatingActionButton: canVerify
//           ? FloatingActionButton.extended(
//               onPressed: _toggleVerifyPanel,
//               icon: const Icon(Icons.verified),
//               label: Text(_showVerify ? 'Close Verify' : 'Verify'),
//             )
//           : null,
//       body: Column(
//         children: [
//           // Header actions + status
//           Padding(
//             padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
//             child: Row(
//               children: [
//                 ElevatedButton.icon(
//                   onPressed: _toggleRegisterPanel,
//                   icon: Icon(_showRegister ? Icons.close : Icons.add),
//                   label:
//                       Text(_showRegister ? 'Close Register' : 'Add Fingerprint'),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: Row(
//                     children: [
//                       const Icon(Icons.circle, size: 10),
//                       const SizedBox(width: 6),
//                       Expanded(
//                         child: Text(
//                           'Status: $_status',
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           // Register Panel
//           _buildRegisterPanel(),

//           // List
//           Expanded(
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 8),
//               child: Card(
//                 margin: const EdgeInsets.only(top: 6, bottom: 6),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(16),
//                 ),
//                 elevation: 0,
//                 child: _buildList(),
//               ),
//             ),
//           ),

//           // Verify Panel
//           _buildVerifyPanel(),

//           // Preview at bottom if no panel wants to show it
//           if (_fpImage != null && !_showRegister && !_showVerify)
//             Padding(
//               padding: const EdgeInsets.only(bottom: 10),
//               child: ClipRRect(
//                 borderRadius: BorderRadius.circular(12),
//                 child: Image.memory(
//                   _fpImage!,
//                   width: 200,
//                   height: 200,
//                   fit: BoxFit.cover,
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }



import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'db_helper.dart';

void main() => runApp(const FingerprintApp());

class FingerprintApp extends StatelessWidget {
  const FingerprintApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fingerprint Demo',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
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

  final TextEditingController _nameController = TextEditingController();

  String _status = 'Idle';
  Uint8List? _fpImage;

  int? _selectedId;
  String? _selectedName;
  String? _selectedTemplate;

  // Panels state
  bool _showRegister = false;
  bool _showVerify = false;
  bool _scannerActive = false;
  bool _firstVerifyScan = true;

  @override
  void initState() {
    super.initState();

    platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onResultUpdate':
          setState(() => _status = call.arguments as String);
          break;

        case 'onFingerprintImage':
          setState(() => _fpImage = base64Decode(call.arguments as String));
          break;

        case 'onEnrollSuccess':
          final base64Merged = call.arguments as String;
          final name = _nameController.text.trim();
          if (name.isNotEmpty) {
            await DBHelper.insertFingerprint(name, base64Merged);
            if (mounted) {
              _showMessageDialog('تم الحفظ', '✅ تم حفظ $name بنجاح');
              setState(() {
                _nameController.clear();
                _showRegister = false;
                _fpImage = null;
              });
              _recomputeScanner();
            }
          }
          break;

        case 'onVerifyResult':
          final bool matched = call.arguments as bool;
          final text = matched
              ? '✅ البصمة صحيحة - ${_selectedName ?? ""}'
              : '❌ فشل التحقق';
          _showMessageDialog('نتيجة التحقق', text);
          break;

        case 'onError':
          final msg = call.arguments as String? ?? 'خطأ غير معروف';
          _showMessageDialog('خطأ', msg);
          break;
      }
    });
  }

  Future<void> _invoke(String method, [Map<String, dynamic>? args]) async {
    try {
      final res = await platform.invokeMethod(method, args);
      if (res is String) setState(() => _status = res);
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _recomputeScanner() {
    final shouldBeActive = _showRegister || _showVerify;
    if (shouldBeActive != _scannerActive) {
      _scannerActive = shouldBeActive;
      if (_scannerActive) {
        _invoke('startFingerprint');
      } else {
        _invoke('stopFingerprint');
        setState(() {
          _fpImage = null;
        });
      }
    }
  }

  void _toggleRegisterPanel() {
    setState(() => _showRegister = !_showRegister);
    _recomputeScanner();
  }

  void _toggleVerifyPanel() {
    if (_selectedTemplate == null) {
      _showMessageDialog('تنبيه', 'اختر بصمة أولاً من القائمة');
      return;
    }
    setState(() {
      _showVerify = !_showVerify;
      if (_showVerify) _firstVerifyScan = true;
    });
    _recomputeScanner();

    if (_showVerify && _firstVerifyScan) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _beginVerify();
        _firstVerifyScan = false;
      });
    }
  }

  Future<void> _beginRegister() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessageDialog('تنبيه', 'أدخل اسم أولاً');
      return;
    }
    await _invoke('registerFingerprint', {'userId': name});
  }

  Future<void> _beginVerify() async {
    if (_selectedTemplate == null) return;
    await _invoke('beginVerify', {'storedTemplate': _selectedTemplate});
  }

  void _showMessageDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  Color _statusColor() {
    if (_status.toLowerCase().contains('success') ||
        _status.contains('✅')) return Colors.green;
    if (_status.toLowerCase().contains('error') ||
        _status.toLowerCase().contains('fail')) return Colors.red;
    if (_status.toLowerCase().contains('scanning')) return Colors.orange;
    return Colors.grey;
  }

  Widget _buildRegisterPanel() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: !_showRegister
          ? const SizedBox.shrink()
          : Card(
              key: const ValueKey('registerPanel'),
              margin: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.fingerprint, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'تسجيل بصمة جديدة',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'إغلاق',
                          onPressed: () {
                            setState(() => _showRegister = false);
                            _recomputeScanner();
                          },
                          icon: const Icon(Icons.close),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'الاسم',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'اضغط نفس الإصبع 3 مرات عند الطلب.',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _beginRegister,
                          icon: const Icon(Icons.add),
                          label: const Text('حفظ'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            _nameController.clear();
                            setState(() => _fpImage = null);
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة ضبط'),
                        ),
                      ],
                    ),
                    if (_fpImage != null) ...[
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
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildVerifyPanel() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: !_showVerify
          ? const SizedBox.shrink()
          : Card(
              key: const ValueKey('verifyPanel'),
              margin: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'التحقق من ${_selectedName ?? ""}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'إغلاق',
                          onPressed: () {
                            setState(() => _showVerify = false);
                            _recomputeScanner();
                          },
                          icon: const Icon(Icons.close),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('ضع إصبعك على الماسح للتحقق'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (!_firstVerifyScan)
                          ElevatedButton.icon(
                            onPressed: _beginVerify,
                            icon: const Icon(Icons.refresh),
                            label: const Text('إعادة المسح'),
                          ),
                        if (!_firstVerifyScan) const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() => _fpImage = null);
                          },
                          icon: const Icon(Icons.clear),
                          label: const Text('مسح المعاينة'),
                        ),
                      ],
                    ),
                    if (_fpImage != null) ...[
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
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildList() {
    return FutureBuilder(
      future: DBHelper.getFingerprints(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data as List<Map<String, dynamic>>;
        if (data.isEmpty) {
          return const Center(child: Text('لا توجد بصمات محفوظة'));
        }
        return ListView.separated(
          itemCount: data.length,
          separatorBuilder: (_, __) => const Divider(height: 0),
          itemBuilder: (context, i) {
            final item = data[i];
            final selected = _selectedId == item['id'];
            return ListTile(
              selected: selected,
              selectedTileColor:
                  Theme.of(context).colorScheme.primary.withOpacity(0.08),
              leading: CircleAvatar(
                child: Text(item['name'].toString().characters.first),
              ),
              title: Text(item['name']),
              subtitle: selected ? const Text('محدد') : null,
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () async {
                  await DBHelper.deleteFingerprint(item['id']);
                  if (_selectedId == item['id']) {
                    _selectedId = null;
                    _selectedName = null;
                    _selectedTemplate = null;
                    if (_showVerify) {
                      setState(() => _showVerify = false);
                      _recomputeScanner();
                    }
                  }
                  setState(() {});
                },
              ),
              onTap: () {
                setState(() {
                  if (selected) {
                    _selectedId = null;
                    _selectedName = null;
                    _selectedTemplate = null;
                  } else {
                    _selectedId = item['id'] as int;
                    _selectedName = item['name'] as String;
                    _selectedTemplate = item['template'] as String;
                  }
                });
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final canVerify = _selectedId != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fingerprint Demo'),
      ),
      floatingActionButton: canVerify
          ? FloatingActionButton.extended(
              onPressed: _toggleVerifyPanel,
              icon: const Icon(Icons.verified),
              label: Text(_showVerify ? 'إغلاق التحقق' : 'تحقق'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _toggleRegisterPanel,
                  icon: Icon(_showRegister ? Icons.close : Icons.add),
                  label:
                      Text(_showRegister ? 'إغلاق التسجيل' : 'تسجيل بصمة جديدة'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 12, color: _statusColor()),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Status: $_status',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _statusColor()),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          _buildRegisterPanel(),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 1,
                child: _buildList(),
              ),
            ),
          ),

          _buildVerifyPanel(),

          if (_fpImage != null && _scannerActive && !_showRegister && !_showVerify)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  _fpImage!,
                  width: 160,
                  height: 160,
                  fit: BoxFit.cover,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
