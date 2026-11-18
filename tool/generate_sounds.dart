// Generates the game's sound effects and background music as 16-bit mono
// WAV files. Everything is synthesized, so the project has no third-party
// audio assets.
//
// Usage (from the project root):
//   dart run tool/generate_sounds.dart [output_dir]
//
// Default output directory: assets/sounds
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int sampleRate = 22050;
final math.Random _noise = math.Random(7);

void main(List<String> args) {
  final outDir = Directory(args.isNotEmpty ? args.first : 'assets/sounds')
    ..createSync(recursive: true);

  final sounds = <String, Float64List>{
    'shoot.wav': _shoot(),
    'hit.wav': _hit(),
    'bounce.wav': _bounce(),
    'swap.wav': _swap(),
    for (var i = 1; i <= 5; i++) 'pop_$i.wav': _pop(i - 1),
    'fall.wav': _fall(),
    'click.wav': _click(),
    for (var i = 2; i <= 5; i++) 'combo_$i.wav': _combo(i),
    'praise.wav': _praise(),
    'rainbow.wav': _rainbow(),
    'new_row.wav': _newRow(),
    'danger.wav': _danger(),
    'new_best.wav': _newBest(),
    'game_over.wav': _gameOver(),
    'level_clear.wav': _levelClear(),
    'music.wav': _music(),
  };

  sounds.forEach((name, samples) {
    final file = File('${outDir.path}/$name');
    file.writeAsBytesSync(_encodeWav(samples, peakTarget: name == 'music.wav' ? 0.8 : 0.95));
    stdout.writeln('wrote ${file.path} (${(samples.length / sampleRate).toStringAsFixed(2)}s)');
  });
}

// ---------------------------------------------------------------------------
// Waveforms and helpers
// ---------------------------------------------------------------------------

double _sine(double phase) => math.sin(2 * math.pi * phase);
double _triangle(double phase) {
  final p = phase % 1.0;
  return p < 0.5 ? 4 * p - 1 : 3 - 4 * p;
}

double _white() => _noise.nextDouble() * 2 - 1;

double midi(num n) => 440.0 * math.pow(2, (n - 69) / 12).toDouble();

/// Renders [seconds] of audio. [frequency] and [voice] are evaluated per
/// sample; the phase is integrated so frequency sweeps stay smooth.
Float64List _render(
  double seconds, {
  required double Function(double t) frequency,
  required double Function(double phase, double t) voice,
  required double Function(double t) envelope,
}) {
  final count = (seconds * sampleRate).round();
  final out = Float64List(count);
  var phase = 0.0;
  for (var i = 0; i < count; i++) {
    final t = i / sampleRate;
    phase += frequency(t) / sampleRate;
    out[i] = voice(phase, t) * envelope(t);
  }
  return out;
}

double _expSweep(double from, double to, double t, double duration) =>
    from * math.pow(to / from, (t / duration).clamp(0.0, 1.0));

double _decay(double t, double duration, {double attack = 0.004, double power = 2}) {
  if (t < attack) return t / attack;
  final x = 1 - ((t - attack) / (duration - attack)).clamp(0.0, 1.0);
  return math.pow(x, power).toDouble();
}

Float64List _mix(double seconds, List<(double offset, Float64List samples, double gain)> parts) {
  final out = Float64List((seconds * sampleRate).round());
  for (final (offset, samples, gain) in parts) {
    final start = (offset * sampleRate).round();
    for (var i = 0; i < samples.length && start + i < out.length; i++) {
      out[start + i] += samples[i] * gain;
    }
  }
  return out;
}

/// A soft bell: a few decaying sine partials.
Float64List _bell(double freq, double seconds, {double brightness = 0.35}) {
  final count = (seconds * sampleRate).round();
  final out = Float64List(count);
  const partials = [1.0, 2.0, 3.0, 4.2];
  const gains = [1.0, 0.5, 0.25, 0.12];
  for (var i = 0; i < count; i++) {
    final t = i / sampleRate;
    final attack = math.min(1.0, t / 0.003);
    var v = 0.0;
    for (var p = 0; p < partials.length; p++) {
      final decay = math.exp(-t * (4 + p * 6) / seconds);
      v += _sine(freq * partials[p] * t) * gains[p] * (p == 0 ? 1 : brightness * 2) * decay;
    }
    out[i] = v * attack * 0.5;
  }
  return out;
}

// ---------------------------------------------------------------------------
// Sound effects
// ---------------------------------------------------------------------------

Float64List _shoot() {
  const d = 0.18;
  return _render(
    d,
    frequency: (t) => _expSweep(280, 980, t, d * 0.8),
    voice: (p, t) => 0.7 * _sine(p) + 0.2 * _triangle(p * 2) + 0.1 * _white() * (1 - t / d),
    envelope: (t) => 0.55 * _decay(t, d, power: 1.8),
  );
}

Float64List _hit() {
  const d = 0.09;
  return _render(
    d,
    frequency: (t) => _expSweep(240, 130, t, d),
    voice: (p, t) => 0.8 * _sine(p) + 0.2 * _white() * (1 - t / d),
    envelope: (t) => 0.6 * _decay(t, d, attack: 0.002, power: 3),
  );
}

Float64List _bounce() {
  const d = 0.05;
  return _render(
    d,
    frequency: (t) => 1500,
    voice: (p, t) => _sine(p),
    envelope: (t) => 0.35 * _decay(t, d, attack: 0.001, power: 3),
  );
}

Float64List _swap() {
  const d = 0.16;
  return _render(
    d,
    frequency: (t) => t < d / 2 ? 520 : 780,
    voice: (p, t) => 0.8 * _sine(p) + 0.2 * _triangle(p),
    envelope: (t) => 0.45 * _decay(t % (d / 2), d / 2, attack: 0.003, power: 1.5),
  );
}

/// Bubbly pops whose pitch rises with [step] (0..4) so a cascade climbs.
Float64List _pop(int step) {
  const d = 0.12;
  final base = 520 * math.pow(2, step * 2 / 12).toDouble();
  return _render(
    d,
    frequency: (t) => _expSweep(base, base * 3, t, d * 0.5),
    voice: (p, t) => 0.85 * _sine(p) + 0.15 * _sine(p * 2),
    envelope: (t) => 0.65 * _decay(t, d, attack: 0.002, power: 2.6),
  );
}

Float64List _fall() {
  const d = 0.55;
  return _render(
    d,
    frequency: (t) => _expSweep(880, 200, t, d) * (1 + 0.03 * math.sin(2 * math.pi * 16 * t)),
    voice: (p, t) => 0.7 * _sine(p) + 0.3 * _triangle(p),
    envelope: (t) => 0.45 * _decay(t, d, attack: 0.01, power: 1.4),
  );
}

Float64List _click() {
  const d = 0.05;
  return _render(
    d,
    frequency: (t) => 1100,
    voice: (p, t) => 0.8 * _sine(p) + 0.2 * _triangle(p),
    envelope: (t) => 0.4 * _decay(t, d, attack: 0.001, power: 3),
  );
}

/// Two-note chime, higher for longer combo streaks.
Float64List _combo(int level) {
  final root = 84 + (level - 2) * 2; // C6, D6, E6, F#6
  return _mix(0.55, [
    (0.0, _bell(midi(root), 0.45), 0.8),
    (0.08, _bell(midi(root + 4), 0.45), 0.8),
    (0.16, _bell(midi(root + 7), 0.4), 0.7),
  ]);
}

/// Glittering upward arpeggio for "GREAT!" / "AMAZING!".
Float64List _praise() {
  const notes = [72, 76, 79, 84, 88, 91];
  final parts = <(double, Float64List, double)>[
    for (var i = 0; i < notes.length; i++) (i * 0.055, _bell(midi(notes[i]), 0.6), 0.6),
  ];
  final shimmer = _render(
    0.8,
    frequency: (t) => 4000,
    voice: (p, t) => _white() * (0.5 + 0.5 * _sine(t * 30)),
    envelope: (t) => 0.05 * _decay(t, 0.8, attack: 0.1, power: 2),
  );
  return _mix(0.9, [...parts, (0.0, shimmer, 1.0)]);
}

/// Magical sweep for receiving the rainbow bubble.
Float64List _rainbow() {
  const d = 0.9;
  final sweep = _render(
    d,
    frequency: (t) => _expSweep(400, 1600, t, d * 0.7),
    voice: (p, t) => _sine(p) * (0.6 + 0.4 * _sine(t * 14)),
    envelope: (t) => 0.3 * _decay(t, d, attack: 0.05, power: 1.5),
  );
  const notes = [79, 83, 86, 91];
  return _mix(1.0, [
    (0.0, sweep, 1.0),
    for (var i = 0; i < notes.length; i++) (0.12 + i * 0.09, _bell(midi(notes[i]), 0.5), 0.45),
  ]);
}

Float64List _newRow() {
  const d = 0.4;
  return _render(
    d,
    frequency: (t) => _expSweep(140, 55, t, d),
    voice: (p, t) => 0.8 * _sine(p) + 0.2 * _white() * math.max(0, 1 - t / 0.08),
    envelope: (t) => 0.75 * _decay(t, d, attack: 0.005, power: 1.6),
  );
}

Float64List _danger() {
  Float64List beep() => _render(
    0.16,
    frequency: (t) => 330,
    voice: (p, t) => 0.7 * _triangle(p) + 0.3 * _sine(p * 0.5),
    envelope: (t) => 0.45 * _decay(t, 0.16, attack: 0.01, power: 1.2),
  );
  return _mix(0.45, [(0.0, beep(), 1.0), (0.22, beep(), 1.0)]);
}

Float64List _newBest() {
  const melody = [(72, 0.0), (76, 0.12), (79, 0.24), (84, 0.38)];
  const chord = [72, 76, 79, 84];
  return _mix(1.4, [
    for (final (n, at) in melody) (at, _bell(midi(n), 0.5), 0.6),
    for (final n in chord) (0.55, _bell(midi(n), 0.85, brightness: 0.25), 0.35),
  ]);
}

Float64List _gameOver() {
  const notes = [(67, 0.0), (64, 0.25), (60, 0.5), (55, 0.75)];
  return _mix(1.6, [
    for (final (n, at) in notes)
      (
        at,
        _render(
          at == 0.75 ? 0.85 : 0.3,
          frequency: (t) => midi(n) * (1 + 0.012 * math.sin(2 * math.pi * 5 * t)),
          voice: (p, t) => 0.7 * _sine(p) + 0.3 * _triangle(p),
          envelope: (t) => 0.5 * _decay(t, at == 0.75 ? 0.85 : 0.3, attack: 0.01, power: 1.2),
        ),
        1.0,
      ),
  ]);
}

Float64List _levelClear() {
  const notes = [72, 76, 79, 84, 88];
  return _mix(1.5, [
    for (var i = 0; i < notes.length; i++) (i * 0.09, _bell(midi(notes[i]), 0.7), 0.55),
    for (final n in [72, 79, 84, 88]) (0.5, _bell(midi(n), 0.95, brightness: 0.2), 0.3),
  ]);
}

// ---------------------------------------------------------------------------
// Background music: a calm 16-bar loop at 70 BPM in C major.
//
//   A: Cmaj7 | Am7 | Dm7 | G7sus4 -> G      (2 bars each)
//   B: Fmaj7 | Em7 | Dm7 | Gsus4  -> G
//
// Layers: chorused pad, soft sine bass, kalimba-like arpeggio with echo and
// a breathy flute-like melody. Reverb is applied circularly so the tail of
// the last bar flows into the first: the loop has no seam.
// ---------------------------------------------------------------------------

Float64List _music() {
  const bpm = 70.0;
  const beat = 60 / bpm;
  const bars = 16;
  final total = (bars * 4 * beat * sampleRate).round();
  final dry = Float64List(total);
  final wetSend = Float64List(total); // extra send into the reverb
  final echoSend = Float64List(total); // arpeggio echo

  int at(double beats) => (beats * beat * sampleRate).round();

  // Each chord: MIDI notes (low to high), two bars long.
  const chords = <List<int>>[
    [48, 55, 59, 64], // Cmaj7  (C G B E)
    [45, 52, 55, 60], // Am7    (A E G C)
    [50, 57, 60, 65], // Dm7    (D A C F)
    [43, 50, 53, 60], // G7sus4 (G D F C)
    [41, 48, 52, 57], // Fmaj7  (F C E A)
    [40, 47, 50, 55], // Em7    (E B D G)
    [50, 57, 60, 65], // Dm7
    [43, 50, 55, 60], // Gsus4  (G D G C)
  ];
  // Second half of the G chords resolves the suspension.
  const resolved = <int, List<int>>{
    3: [43, 50, 53, 59], // G7
    7: [43, 50, 55, 59], // G
  };

  void addVoice(
    Float64List target,
    int start,
    int length,
    double Function(double t) wave,
    double gain, {
    double attack = 0.01,
    double release = 0.2,
  }) {
    final a = (attack * sampleRate).round();
    final r = (release * sampleRate).round();
    for (var i = 0; i < length + r; i++) {
      final idx = (start + i) % total; // wrap so tails continue at the loop start
      var env = 1.0;
      if (i < a) env = i / a;
      if (i >= length) env *= 1 - (i - length) / r;
      final t = i / sampleRate;
      target[idx] += wave(t) * gain * env;
    }
  }

  // Pad: chorused sines, long swells.
  for (var c = 0; c < chords.length; c++) {
    for (var half = 0; half < 2; half++) {
      final notes = (half == 1 && resolved.containsKey(c)) ? resolved[c]! : chords[c];
      final start = at(c * 8.0 + half * 4);
      final len = at(4);
      for (final n in notes.skip(1)) {
        final f = midi(n + 12);
        addVoice(
          dry,
          start,
          len,
          (t) {
            final lfo = 1 + 0.002 * _sine(t * 0.3);
            return 0.5 * _sine(f * t * lfo) + 0.5 * _sine(f * 1.003 * t) + 0.12 * _sine(f * 2 * t);
          },
          0.045,
          attack: half == 0 ? 0.9 : 0.4,
          release: 1.4,
        );
      }
    }
  }

  // Bass: root on beat 1, fifth on beat 3.
  for (var c = 0; c < chords.length; c++) {
    final root = chords[c][0];
    for (var bar = 0; bar < 2; bar++) {
      for (var half = 0; half < 2; half++) {
        final n = half == 0 ? root - 12 : root - 5;
        final f = midi(n);
        addVoice(
          dry,
          at(c * 8.0 + bar * 4 + half * 2),
          at(1.8),
          (t) => _sine(f * t) + 0.25 * _sine(2 * f * t) * math.exp(-t * 3),
          0.16,
          attack: 0.03,
          release: 0.5,
        );
      }
    }
  }

  // Arpeggio: kalimba-like plucks on eighth notes, flowing up and down.
  const pattern = [0, 1, 2, 3, 4, 3, 2, 1];
  for (var c = 0; c < chords.length; c++) {
    for (var bar = 0; bar < 2; bar++) {
      final notes = (bar == 1 && resolved.containsKey(c)) ? resolved[c]! : chords[c];
      final tones = [for (final n in notes.skip(1)) n + 12, notes[1] + 24];
      for (var e = 0; e < 8; e++) {
        final n = tones[pattern[e] % tones.length];
        final f = midi(n);
        // Slightly softer on the off-beats for a breathing feel.
        final gain = e.isEven ? 0.07 : 0.05;
        final start = at(c * 8.0 + bar * 4 + e * 0.5);
        final len = at(1.2);
        addVoice(
          dry,
          start,
          len,
          (t) {
            final d1 = math.exp(-t * 4.5);
            final d2 = math.exp(-t * 14);
            return _sine(f * t) * d1 +
                0.3 * _sine(f * 2.76 * t) * d2 +
                0.12 * _sine(f * 5.4 * t) * d2;
          },
          gain,
          attack: 0.004,
          release: 0.1,
        );
        addVoice(
          echoSend,
          start,
          len,
          (t) => _sine(f * t) * math.exp(-t * 4.5),
          gain * 0.6,
          attack: 0.004,
          release: 0.1,
        );
      }
    }
  }

  // Melody: (MIDI, start beat, length in beats). Question / answer phrases
  // with room to breathe between them.
  const melody = <(int, double, double)>[
    // A section
    (76, 0, 1.5), (74, 1.5, 0.5), (76, 2, 1), (79, 3, 1), (79, 4, 2), (76, 6, 1.5),
    (76, 8, 1.5), (74, 9.5, 0.5), (72, 10, 1), (76, 11, 1), (74, 12, 3),
    (77, 16, 1.5), (76, 17.5, 0.5), (74, 18, 1), (81, 19, 1), (79, 20, 2), (77, 22, 1.5),
    (76, 24, 1), (74, 25, 1), (72, 26, 1), (74, 27, 1), (74, 28, 2.5), (71, 31, 1),
    // B section
    (72, 32, 1), (77, 33, 1), (81, 34, 1.5), (79, 35.5, 0.5), (76, 36, 3),
    (79, 40, 1.5), (76, 41.5, 0.5), (74, 42, 1), (76, 43, 1), (71, 44, 2), (74, 46, 1.5),
    (77, 48, 1.5), (76, 49.5, 0.5), (74, 50, 1), (72, 51, 1), (69, 52, 2), (72, 54, 1), (74, 55, 1),
    (79, 56, 2), (77, 58, 1), (74, 59, 1), (74, 60, 3),
  ];
  for (final (n, start, len) in melody) {
    final f = midi(n);
    final s = at(start);
    final l = at(len * 0.95);
    addVoice(
      dry,
      s,
      l,
      (t) {
        final vib = 1 + 0.004 * _sine(t * 5) * math.min(1, t / 0.4);
        return 0.8 * _sine(f * t * vib) + 0.15 * _sine(2 * f * t * vib) + 0.03 * _white();
      },
      0.085,
      attack: 0.08,
      release: 0.45,
    );
    addVoice(wetSend, s, l, (t) => _sine(f * t), 0.05, attack: 0.08, release: 0.45);
  }

  // Echo for the arpeggio: dotted-eighth delay, circular.
  final echoDelay = at(0.75);
  final echo = Float64List(total);
  for (var pass = 0; pass < 2; pass++) {
    for (var i = 0; i < total; i++) {
      final prev = echo[(i - echoDelay) % total];
      echo[i] = echoSend[(i - echoDelay) % total] + prev * 0.38;
    }
  }

  final mix = Float64List(total);
  for (var i = 0; i < total; i++) {
    mix[i] = dry[i] + echo[i] * 0.35;
  }

  // Reverb (Schroeder: parallel combs + series allpasses), run over the loop
  // twice so the tail wraps around to the beginning.
  final send = Float64List(total);
  for (var i = 0; i < total; i++) {
    send[i] = mix[i] * 0.5 + wetSend[i];
  }
  final reverb = _circularReverb(send);
  final out = Float64List(total);
  for (var i = 0; i < total; i++) {
    // Gentle saturation keeps peaks soft.
    out[i] = _softClip(mix[i] * 0.8 + reverb[i] * 0.55);
  }
  return out;
}

Float64List _circularReverb(Float64List input) {
  final n = input.length;
  const combDelays = [1557, 1617, 1491, 1422];
  const feedback = 0.82;
  const damp = 0.35;
  final out = Float64List(n);
  for (final delay in combDelays) {
    final buf = Float64List(delay);
    var idx = 0;
    var filter = 0.0;
    for (var pass = 0; pass < 2; pass++) {
      for (var i = 0; i < n; i++) {
        final y = buf[idx];
        filter = y * (1 - damp) + filter * damp;
        buf[idx] = input[i] + filter * feedback;
        idx = (idx + 1) % delay;
        if (pass == 1) out[i] += y * 0.25;
      }
    }
  }
  var signal = out;
  for (final delay in const [225, 556]) {
    final buf = Float64List(delay);
    var idx = 0;
    final next = Float64List(n);
    for (var pass = 0; pass < 2; pass++) {
      for (var i = 0; i < n; i++) {
        final b = buf[idx];
        final y = -signal[i] * 0.5 + b;
        buf[idx] = signal[i] + b * 0.5;
        idx = (idx + 1) % delay;
        if (pass == 1) next[i] = y;
      }
    }
    signal = next;
  }
  return signal;
}

double _softClip(double x) => x / (1 + x.abs() * 0.6);

// ---------------------------------------------------------------------------
// WAV encoding
// ---------------------------------------------------------------------------

Uint8List _encodeWav(Float64List samples, {double peakTarget = 0.95}) {
  var peak = 0.0;
  for (final s in samples) {
    peak = math.max(peak, s.abs());
  }
  final gain = peak > 0 ? peakTarget / peak : 1.0;

  final dataLength = samples.length * 2;
  final bytes = ByteData(44 + dataLength);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      bytes.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + dataLength, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little); // PCM chunk size
  bytes.setUint16(20, 1, Endian.little); // PCM format
  bytes.setUint16(22, 1, Endian.little); // mono
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  bytes.setUint16(32, 2, Endian.little); // block align
  bytes.setUint16(34, 16, Endian.little); // bits per sample
  ascii(36, 'data');
  bytes.setUint32(40, dataLength, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i] * gain * 32767).round().clamp(-32768, 32767);
    bytes.setInt16(44 + i * 2, v, Endian.little);
  }
  return bytes.buffer.asUint8List();
}
