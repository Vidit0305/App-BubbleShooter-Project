import 'package:bubble_shooter/services/audio_service.dart';
import 'package:bubble_shooter/services/settings_controller.dart';
import 'package:bubble_shooter/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(SettingsController, SilentAudioService)> create(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    final audio = SilentAudioService();
    final settings = SettingsController(storage: await StorageService.create(), audio: audio)
      ..load();
    return (settings, audio);
  }

  group('StorageService defaults', () {
    test('sound, music and vibration default to on, best score to 0', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.create();
      expect(storage.sfxEnabled, isTrue);
      expect(storage.musicEnabled, isTrue);
      expect(storage.vibrationEnabled, isTrue);
      expect(storage.bestScore, 0);
    });
  });

  group('SettingsController', () {
    test('load applies stored preferences to the audio service', () async {
      final (settings, audio) = await create({
        StorageService.sfxEnabledKey: false,
        StorageService.musicEnabledKey: true,
        StorageService.bestScoreKey: 750,
      });
      expect(settings.sfxEnabled, isFalse);
      expect(audio.sfxEnabled, isFalse);
      expect(audio.musicEnabled, isTrue);
      expect(settings.bestScore, 750);
      expect(settings.soundOn, isTrue, reason: 'music is still on');
    });

    test('the master sound switch turns effects and music off together', () async {
      final (settings, audio) = await create({StorageService.vibrationEnabledKey: false});
      await settings.setSoundOn(false);
      expect(settings.soundOn, isFalse);
      expect(audio.sfxEnabled, isFalse);
      expect(audio.musicEnabled, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(StorageService.sfxEnabledKey), isFalse);
      expect(prefs.getBool(StorageService.musicEnabledKey), isFalse);

      await settings.setSoundOn(true);
      expect(audio.sfxEnabled && audio.musicEnabled, isTrue);
    });

    test('submitScore only records improvements', () async {
      final (settings, _) = await create({StorageService.bestScoreKey: 100});
      expect(settings.submitScore(90), isFalse);
      expect(settings.submitScore(100), isFalse);
      expect(settings.submitScore(140), isTrue);
      expect(settings.bestScore, 140);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(StorageService.bestScoreKey), 140);
    });

    test('notifies listeners when a setting changes', () async {
      final (settings, _) = await create({StorageService.vibrationEnabledKey: false});
      var notified = 0;
      settings.addListener(() => notified++);
      await settings.setMusicEnabled(false);
      await settings.setMusicEnabled(false); // unchanged: no notification
      settings.submitScore(10);
      expect(notified, 2);
    });

    test('click plays the click effect', () async {
      final (settings, audio) = await create({StorageService.vibrationEnabledKey: false});
      settings.click();
      expect(audio.played, [Sfx.click]);
    });
  });
}
