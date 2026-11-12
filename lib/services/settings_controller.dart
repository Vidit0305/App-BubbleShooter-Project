import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'audio_service.dart';
import 'storage_service.dart';

enum Haptic { light, medium, heavy, selection }

/// App-wide preferences and best score, persisted through [StorageService]
/// and applied to the [AudioService].
class SettingsController extends ChangeNotifier {
  SettingsController({required StorageService storage, required this.audio})
      : _storage = storage; // ignore: prefer_initializing_formals

  final StorageService _storage;
  final AudioService audio;

  bool _sfxEnabled = true;
  bool _musicEnabled = true;
  bool _vibrationEnabled = true;
  int _bestScore = 0;

  bool get sfxEnabled => _sfxEnabled;
  bool get musicEnabled => _musicEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  int get bestScore => _bestScore;

  /// Master sound switch: on if any sound is enabled.
  bool get soundOn => _sfxEnabled || _musicEnabled;

  void load() {
    _sfxEnabled = _storage.sfxEnabled;
    _musicEnabled = _storage.musicEnabled;
    _vibrationEnabled = _storage.vibrationEnabled;
    _bestScore = _storage.bestScore;
    audio
      ..sfxEnabled = _sfxEnabled
      ..musicEnabled = _musicEnabled;
    notifyListeners();
  }

  Future<void> setSfxEnabled(bool value) async {
    if (value == _sfxEnabled) return;
    _sfxEnabled = value;
    audio.sfxEnabled = value;
    notifyListeners();
    await _storage.setSfxEnabled(value);
  }

  Future<void> setMusicEnabled(bool value) async {
    if (value == _musicEnabled) return;
    _musicEnabled = value;
    audio.musicEnabled = value;
    notifyListeners();
    await _storage.setMusicEnabled(value);
  }

  Future<void> setVibrationEnabled(bool value) async {
    if (value == _vibrationEnabled) return;
    _vibrationEnabled = value;
    notifyListeners();
    await _storage.setVibrationEnabled(value);
    if (value) haptic(Haptic.medium);
  }

  /// Turns all sound (effects and music) on or off.
  Future<void> setSoundOn(bool value) async {
    await setSfxEnabled(value);
    await setMusicEnabled(value);
  }

  /// Records [score]; returns true if it is a new best score.
  bool submitScore(int score) {
    if (score <= _bestScore) return false;
    _bestScore = score;
    notifyListeners();
    _storage.setBestScore(score);
    return true;
  }

  /// Plays the button click (respects the effects setting).
  void click() {
    audio.play(Sfx.click);
    haptic(Haptic.selection);
  }

  /// Vibration feedback (respects the vibration setting).
  void haptic(Haptic kind) {
    if (!_vibrationEnabled) return;
    switch (kind) {
      case Haptic.light:
        HapticFeedback.lightImpact();
      case Haptic.medium:
        HapticFeedback.mediumImpact();
      case Haptic.heavy:
        HapticFeedback.heavyImpact();
      case Haptic.selection:
        HapticFeedback.selectionClick();
    }
  }
}

/// Shared services passed down the widget tree.
class AppServices {
  const AppServices({required this.settings});

  final SettingsController settings;

  AudioService get audio => settings.audio;
}
