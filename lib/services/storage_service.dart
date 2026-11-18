import 'package:shared_preferences/shared_preferences.dart';

/// Persists the best score and sound / vibration preferences with
/// SharedPreferences.
class StorageService {
  StorageService(this._prefs);

  static Future<StorageService> create() async =>
      StorageService(await SharedPreferences.getInstance());

  static const String bestScoreKey = 'best_score';
  static const String sfxEnabledKey = 'sfx_enabled';
  static const String musicEnabledKey = 'music_enabled';
  static const String vibrationEnabledKey = 'vibration_enabled';

  final SharedPreferences _prefs;

  int get bestScore => _prefs.getInt(bestScoreKey) ?? 0;
  bool get sfxEnabled => _prefs.getBool(sfxEnabledKey) ?? true;
  bool get musicEnabled => _prefs.getBool(musicEnabledKey) ?? true;
  bool get vibrationEnabled => _prefs.getBool(vibrationEnabledKey) ?? true;

  Future<void> setBestScore(int value) => _prefs.setInt(bestScoreKey, value);
  Future<void> setSfxEnabled(bool value) => _prefs.setBool(sfxEnabledKey, value);
  Future<void> setMusicEnabled(bool value) => _prefs.setBool(musicEnabledKey, value);
  Future<void> setVibrationEnabled(bool value) => _prefs.setBool(vibrationEnabledKey, value);
}
