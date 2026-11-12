import 'package:bubble_shooter/game/game_engine.dart';
import 'package:bubble_shooter/services/audio_service.dart';
import 'package:bubble_shooter/services/game_feedback.dart';
import 'package:bubble_shooter/services/settings_controller.dart';
import 'package:bubble_shooter/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every game event maps to a sound effect', () {
    for (final sound in GameSound.values) {
      final (sfx, variant, _) = GameFeedback.mappingFor(sound, 2);
      expect(Sfx.values, contains(sfx));
      expect(variant, greaterThanOrEqualTo(0), reason: '$sound');
    }
  });

  test('pop variants follow the cascade step and combo starts at x2', () {
    expect(GameFeedback.mappingFor(GameSound.pop, 3).$2, 3);
    expect(GameFeedback.mappingFor(GameSound.combo, 2).$2, 0);
    expect(GameFeedback.mappingFor(GameSound.combo, 5).$2, 3);
  });

  test('plays through the audio service and respects the effects setting', () async {
    SharedPreferences.setMockInitialValues({StorageService.vibrationEnabledKey: false});
    final audio = SilentAudioService();
    final settings = SettingsController(storage: await StorageService.create(), audio: audio)
      ..load();
    final feedback = GameFeedback(settings);

    feedback.onGameSound(GameSound.shoot, 0);
    feedback.onGameSound(GameSound.pop, 1);
    expect(audio.played, [Sfx.shoot, Sfx.pop]);

    await settings.setSfxEnabled(false);
    feedback.onGameSound(GameSound.hit, 0);
    expect(audio.played, [Sfx.shoot, Sfx.pop]);
  });
}
