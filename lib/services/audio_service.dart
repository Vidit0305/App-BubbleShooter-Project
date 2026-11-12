import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

enum Sfx {
  shoot,
  hit,
  bounce,
  swap,
  pop,
  fall,
  click,
  combo,
  praise,
  rainbow,
  newRow,
  danger,
  newBest,
  gameOver,
  levelClear,
}

/// Sound effects and background music.
abstract class AudioService {
  Future<void> init();

  bool get sfxEnabled;
  set sfxEnabled(bool value);

  bool get musicEnabled;
  set musicEnabled(bool value);

  /// Plays an effect. [variant] picks a pitch/version for effects that have
  /// several (pop cascade steps, combo levels); it is clamped to what exists.
  void play(Sfx sfx, {int variant = 0});

  /// Called when the app goes to the background.
  void suspend();

  /// Called when the app returns to the foreground.
  void resumeFromSuspend();

  Future<void> dispose();
}

/// No-op implementation (tests, or platforms without audio).
class SilentAudioService implements AudioService {
  @override
  bool sfxEnabled = true;
  @override
  bool musicEnabled = true;

  /// Every effect requested, for tests.
  final List<Sfx> played = <Sfx>[];

  @override
  Future<void> init() async {}
  @override
  void play(Sfx sfx, {int variant = 0}) {
    if (sfxEnabled) played.add(sfx);
  }

  @override
  void suspend() {}
  @override
  void resumeFromSuspend() {}
  @override
  Future<void> dispose() async {}
}

class _SfxSpec {
  const _SfxSpec(this.files, this.volume, {this.voices = 2});

  final List<String> files;
  final double volume;

  /// Players per file, so rapid repeats can overlap.
  final int voices;
}

class _Channel {
  _Channel(this.players);

  final List<AudioPlayer> players;
  int next = 0;
}

/// Plays the bundled WAV assets with audioplayers.
///
/// Effects use low-latency players (SoundPool on Android), several per file
/// so rapid repeats overlap. Missing or unplayable assets are skipped
/// silently: the game keeps working without them.
class AssetAudioService implements AudioService {
  static const Map<Sfx, _SfxSpec> _specs = <Sfx, _SfxSpec>{
    Sfx.shoot: _SfxSpec(['sounds/shoot.wav'], 0.55),
    Sfx.hit: _SfxSpec(['sounds/hit.wav'], 0.5),
    Sfx.bounce: _SfxSpec(['sounds/bounce.wav'], 0.4),
    Sfx.swap: _SfxSpec(['sounds/swap.wav'], 0.5, voices: 1),
    Sfx.pop: _SfxSpec([
      'sounds/pop_1.wav',
      'sounds/pop_2.wav',
      'sounds/pop_3.wav',
      'sounds/pop_4.wav',
      'sounds/pop_5.wav',
    ], 0.65),
    Sfx.fall: _SfxSpec(['sounds/fall.wav'], 0.55),
    Sfx.click: _SfxSpec(['sounds/click.wav'], 0.45),
    Sfx.combo: _SfxSpec([
      'sounds/combo_2.wav',
      'sounds/combo_3.wav',
      'sounds/combo_4.wav',
      'sounds/combo_5.wav',
    ], 0.6, voices: 1),
    Sfx.praise: _SfxSpec(['sounds/praise.wav'], 0.6, voices: 1),
    Sfx.rainbow: _SfxSpec(['sounds/rainbow.wav'], 0.6, voices: 1),
    Sfx.newRow: _SfxSpec(['sounds/new_row.wav'], 0.6, voices: 1),
    Sfx.danger: _SfxSpec(['sounds/danger.wav'], 0.45, voices: 1),
    Sfx.newBest: _SfxSpec(['sounds/new_best.wav'], 0.7, voices: 1),
    Sfx.gameOver: _SfxSpec(['sounds/game_over.wav'], 0.75, voices: 1),
    Sfx.levelClear: _SfxSpec(['sounds/level_clear.wav'], 0.75, voices: 1),
  };
  static const String _musicFile = 'sounds/music.wav';
  static const double _musicVolume = 0.35;

  /// Channels per effect, one per variant file (null if it failed to load).
  final Map<Sfx, List<_Channel?>> _channels = <Sfx, List<_Channel?>>{};
  AudioPlayer? _music;
  bool _initialized = false;
  bool _suspended = false;
  bool _musicPlaying = false;
  bool _sfxEnabled = true;
  bool _musicEnabled = true;

  @override
  bool get sfxEnabled => _sfxEnabled;
  @override
  set sfxEnabled(bool value) => _sfxEnabled = value;

  @override
  bool get musicEnabled => _musicEnabled;
  @override
  set musicEnabled(bool value) {
    _musicEnabled = value;
    _updateMusic();
  }

  static Future<bool> _assetExists(String path) async {
    try {
      await rootBundle.load('assets/$path');
      return true;
    } catch (_) {
      debugPrint('AudioService: missing asset assets/$path');
      return false;
    }
  }

  Future<_Channel?> _loadChannel(String file, double volume, int voices) async {
    if (!await _assetExists(file)) return null;
    try {
      final players = <AudioPlayer>[];
      for (var i = 0; i < voices; i++) {
        final p = AudioPlayer();
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setVolume(volume);
        await p.setSource(AssetSource(file));
        players.add(p);
      }
      return _Channel(players);
    } catch (e) {
      debugPrint('AudioService: could not load $file: $e');
      return null;
    }
  }

  @override
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
      );
    } catch (e) {
      debugPrint('AudioService: could not set audio context: $e');
    }

    // Music first, so it starts as soon as possible.
    if (await _assetExists(_musicFile)) {
      try {
        final music = AudioPlayer();
        await music.setReleaseMode(ReleaseMode.loop);
        await music.setVolume(_musicVolume);
        await music.setSource(AssetSource(_musicFile));
        _music = music;
      } catch (e) {
        debugPrint('AudioService: could not load music: $e');
      }
    }
    _updateMusic();

    await Future.wait(_specs.entries.map((entry) async {
      final spec = entry.value;
      _channels[entry.key] = await Future.wait(
          spec.files.map((f) => _loadChannel(f, spec.volume, spec.voices)));
    }));
  }

  @override
  void play(Sfx sfx, {int variant = 0}) {
    if (!_sfxEnabled || _suspended) return;
    final channels = _channels[sfx];
    if (channels == null || channels.isEmpty) return;
    final channel = channels[variant.clamp(0, channels.length - 1)];
    if (channel == null) return;
    final player = channel.players[channel.next++ % channel.players.length];
    // stop() resets the player so resume() replays from the start.
    unawaited(player
        .stop()
        .then((_) => player.resume())
        .catchError((Object e) => debugPrint('AudioService: play failed: $e')));
  }

  void _updateMusic() {
    final music = _music;
    if (music == null) return;
    final shouldPlay = _musicEnabled && !_suspended;
    if (shouldPlay && !_musicPlaying) {
      _musicPlaying = true;
      unawaited(music.resume().catchError((Object e) {
        debugPrint('AudioService: music failed: $e');
      }));
    } else if (!shouldPlay && _musicPlaying) {
      _musicPlaying = false;
      unawaited(music.pause().catchError((Object e) {
        debugPrint('AudioService: music pause failed: $e');
      }));
    }
  }

  @override
  void suspend() {
    _suspended = true;
    _updateMusic();
  }

  @override
  void resumeFromSuspend() {
    _suspended = false;
    _updateMusic();
  }

  @override
  Future<void> dispose() async {
    for (final channels in _channels.values) {
      for (final channel in channels) {
        for (final p in channel?.players ?? const <AudioPlayer>[]) {
          await p.dispose();
        }
      }
    }
    _channels.clear();
    await _music?.dispose();
    _music = null;
  }
}
