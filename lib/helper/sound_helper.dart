import 'package:flutter_soloud/flutter_soloud.dart';

class SoundHelper {
  static final SoundHelper _instance = SoundHelper._internal();
  factory SoundHelper() => _instance;

  SoundHelper._internal();

  final SoLoud _soLoud = SoLoud.instance;
  bool _initialized = false;

  Future<void> init() async {
    if (!_initialized) {
      await _soLoud.init();
      _initialized = true;
    }
  }

  Future<void> playSuccess() async {
    await _play('assets/sounds/success.mp3');
  }

  Future<void> playError() async {
    await _play('assets/sounds/error.mp3');
  }

  Future<void> playAlert() async {
    await _play('assets/sounds/alert.mp3');
  }

  Future<void> _play(String assetPath) async {
    if (!_initialized) await init();
    final sound = await _soLoud.loadAsset(assetPath);
    _soLoud.play(sound);
  }

  Future<void> dispose() async {
    if (_initialized) {
      _soLoud.deinit();
      _initialized = false;
    }
  }
}
