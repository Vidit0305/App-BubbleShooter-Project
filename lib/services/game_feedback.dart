import '../game/game_engine.dart';
import 'audio_service.dart';
import 'settings_controller.dart';

/// Turns gameplay events from the engine into sound effects and haptics.
///
/// Keeps the mapping in one place so the game screen only wires the engine
/// to it.
class GameFeedback {
  const GameFeedback(this.settings);

  final SettingsController settings;

  /// The effect, its variant and the haptic (if any) for a game event.
  static (Sfx sfx, int variant, Haptic? haptic) mappingFor(GameSound sound, int level) =>
      switch (sound) {
        GameSound.shoot => (Sfx.shoot, 0, Haptic.selection),
        GameSound.hit => (Sfx.hit, 0, null),
        GameSound.bounce => (Sfx.bounce, 0, null),
        GameSound.swap => (Sfx.swap, 0, Haptic.selection),
        // Pop variants rise in pitch through a cascade; vibrate once per pop.
        GameSound.pop => (Sfx.pop, level, level == 0 ? Haptic.light : null),
        GameSound.fall => (Sfx.fall, 0, null),
        // Combo files start at x2.
        GameSound.combo => (Sfx.combo, level - 2, null),
        GameSound.praise => (Sfx.praise, 0, Haptic.medium),
        GameSound.rainbow => (Sfx.rainbow, 0, Haptic.medium),
        GameSound.newRow => (Sfx.newRow, 0, Haptic.medium),
        GameSound.danger => (Sfx.danger, 0, Haptic.heavy),
        GameSound.newBest => (Sfx.newBest, 0, null),
        GameSound.levelClear => (Sfx.levelClear, 0, Haptic.heavy),
        GameSound.gameOver => (Sfx.gameOver, 0, Haptic.heavy),
      };

  /// Engine callback: plays the sound and vibrates (respecting settings).
  void onGameSound(GameSound sound, int level) {
    final (sfx, variant, haptic) = mappingFor(sound, level);
    settings.audio.play(sfx, variant: variant);
    if (haptic != null) settings.haptic(haptic);
  }
}
