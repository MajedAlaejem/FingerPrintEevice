import 'dart:convert';
import 'dart:typed_data';
import 'package:fingerprint_java_flutter/helper/alert.dart';
import 'package:fingerprint_java_flutter/helper/sound_helper.dart';
import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'fingerprint_channel_helper.dart';

void main() => runApp(const FingerprintApp());

class FingerprintApp extends StatelessWidget {
  const FingerprintApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'برنامج اختبار البصمة',
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
  final FingerprintChannelHelper _fingerprintHelper = FingerprintChannelHelper();
  final TextEditingController _nameController = TextEditingController();

  String _status = '{"color": "gray", "message": "الجهاز مطفي"}';
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

    _fingerprintHelper.setEventHandler((method, args) async {
      switch (method) {
        case 'onResultUpdate':
          setState(() => _status = args as String);
          break;

        case 'onFingerprintImage':
          setState(() => _fpImage = _fingerprintHelper.decodeImage(args as String));
          break;

        case 'onEnrollSuccess':
          final base64Merged = args as String;
          final name = _nameController.text.trim();
          if (name.isNotEmpty) {
            await DBHelper.insertFingerprint(name, base64Merged);
            if (mounted) {
              SoundHelper().playSuccess();
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
          final matched = args as bool;
          final text = matched
              ? '✅ البصمة صحيحة - ${_selectedName ?? ""}'
              : '❌ فشل التحقق';
          _showMessageDialog('نتيجة التحقق', text);
          
          // Automatically close verify panel after result
          if (mounted) {
            setState(() => _showVerify = false);
            _recomputeScanner();
          }
          break;

        case 'onVerifyTimeout':
          // Handle verification timeout
          final message = args as String? ?? 'انتهت مهلة التحقق (20 ثانية)';
          _showMessageDialog('انتهت المهلة', message);
          
          // Automatically close verify panel after timeout
          if (mounted) {
            setState(() => _showVerify = false);
            _recomputeScanner();
          }
          break;

        case 'onTemplateScanned':
          // Handle scanned template if needed for other purposes
          final template = args as String;
          print('Template scanned: ${template.length} characters');
          break;

        case 'onError':
          final msg = args as String? ?? 'خطأ غير معروف';
          _showMessageDialog('خطأ', msg);
          break;
      }
    });
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
        _fingerprintHelper.startFingerprint();
      } else {
        _fingerprintHelper.stopFingerprint();
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

  void _toggleVerifyPanel() async {
    if (_selectedTemplate == null) {
      _showMessageDialog('تنبيه', 'اختر بصمة أولاً من القائمة');
      return;
    }

    if (_showVerify) {
      // Closing verify panel - stop verification
      await _fingerprintHelper.stopVerify();
      setState(() => _showVerify = false);
      _recomputeScanner();
    } else {
      // Opening verify panel - start verification
      setState(() {
        _showVerify = true;
        _firstVerifyScan = true;
      });
      
      // Ensure scanner is active before starting verification
      _recomputeScanner();
      
      // Wait a moment for scanner to start, then begin verification
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (_showVerify && _selectedTemplate != null) {
        await _beginVerify();
        setState(() => _firstVerifyScan = false);
      }
    }
  }

  Future<void> _beginRegister() async {
    if (!_scannerActive) {
      _showMessageDialog('خطأ', 'يرجى تشغيل الماسح أولاً');
      return;
    }
    await _fingerprintHelper.registerFingerprint(_nameController.text.trim());
  }

  Future<void> _beginVerify() async {
    if (_selectedTemplate == null) {
      _showMessageDialog('خطأ', 'لا يوجد قالب بصمة محدد');
      return;
    }
    
    // Ensure scanner is running
    if (!_scannerActive) {
      await _fingerprintHelper.startFingerprint();
      setState(() => _scannerActive = true);
      // Wait for scanner to fully initialize
      await Future.delayed(const Duration(milliseconds: 1000));
    }
    
    try {
      await _fingerprintHelper.beginVerify(_selectedTemplate!);
    } catch (e) {
      _showMessageDialog('خطأ', 'فشل في بدء التحقق: $e');
    }
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
                          onPressed: () async {
                            // Stop verification on the native side
                            await _fingerprintHelper.stopVerify();
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
                      child: Text('ضع إصبعك على الماسح للتحقق (مهلة: 20 ثانية)'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _beginVerify,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المسح'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() => _fpImage = null);
                          },
                          icon: const Icon(Icons.clear),
                          label: const Text('مسح المعاينة'),
                        ),
                        const Spacer(),
                        // Cancel verification button
                        TextButton.icon(
                          onPressed: () async {
                            await _fingerprintHelper.stopVerify();
                            setState(() => _showVerify = false);
                            _recomputeScanner();
                          },
                          icon: const Icon(Icons.cancel, color: Colors.orange),
                          label: const Text(
                            'إلغاء التحقق',
                            style: TextStyle(color: Colors.orange),
                          ),
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
                      await _fingerprintHelper.stopVerify();
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
        title: const Text('برنامج اختبار البصمة'),
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
                //استعراض حالة البصمة
                StatusIndicator(statusObj: jsonDecode(_status)),
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