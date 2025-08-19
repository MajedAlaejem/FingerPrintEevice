

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

  final TextEditingController _nameController = TextEditingController();

  String _status = 'Idle';
  Uint8List? _fpImage;

  int? _selectedId;
  String? _selectedName;
  String? _selectedTemplate;

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
          // Java يرسل الـ merged template بعد اكتمال الثلاث ضغطات
          final base64Merged = call.arguments as String;
          final name = _nameController.text.trim();
          if (name.isNotEmpty) {
            await DBHelper.insertFingerprint(name, base64Merged);
            if (mounted) {
              Navigator.of(context).maybePop(); // اغلاق الـ sheet
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('✅ Saved $name')));
              setState(() {}); // لتحديث القائمة
              _nameController.clear();
            }
          }
          break;

        case 'onTemplateScanned':
          // (اختياري/للعرض) استلام قالب مباشر من الالتقاط
          break;

        case 'onVerifyResult':
          final bool matched = call.arguments as bool;
          final text = matched
              ? '✅ Same person: $_selectedName'
              : '❌ Access denied';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
          break;

        case 'onError':
          final msg = call.arguments as String? ?? 'Unknown error';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

  Future<void> _openRegisterSheet() async {
    await _invoke('startFingerprint');
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isDismissible: true,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Add Fingerprint', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Press the same finger 3 times when prompted.',
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  final name = _nameController.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter a name first')),
                    );
                    return;
                  }
                  _invoke('registerFingerprint', {'userId': name});
                },
                child: const Text('Add'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    ).whenComplete(() {
      _invoke('stopFingerprint');
    });
  }

  Future<void> _openVerifySheet() async {
    if (_selectedTemplate == null) return;
    await _invoke('startFingerprint');
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isDismissible: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Verify ${_selectedName ?? ""}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('Place finger on the scanner to verify.'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  await _invoke('beginVerify', {'storedTemplate': _selectedTemplate});
                },
                child: const Text('Scan & Verify'),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      _invoke('stopFingerprint');
    });
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
          return const Center(child: Text('No fingerprints saved'));
        }
        return ListView.builder(
          itemCount: data.length,
          itemBuilder: (context, i) {
            final item = data[i];
            final selected = _selectedId == item['id'];
            return ListTile(
              selected: selected,
              title: Text(item['name']),
              subtitle: selected ? const Text('Selected') : null,
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () async {
                  await DBHelper.deleteFingerprint(item['id']);
                  if (_selectedId == item['id']) {
                    _selectedId = null;
                    _selectedName = null;
                    _selectedTemplate = null;
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
    final showVerify = _selectedId != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Fingerprint Demo')),
      floatingActionButton: showVerify
          ? FloatingActionButton.extended(
              onPressed: _openVerifySheet,
              icon: const Icon(Icons.verified),
              label: const Text('Verify'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: _openRegisterSheet,
                  child: const Text('Add Fingerprint'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text('Status: $_status', overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          Expanded(child: _buildList()),
          if (_fpImage != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image.memory(_fpImage!, width: 200, height: 200),
            ),
        ],
      ),
    );
  }
}
