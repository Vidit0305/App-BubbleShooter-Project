// Renders the launcher icons for Android and iOS from BrandArt.
//
// Run from the project root:
//   flutter test tool/generate_app_icon_test.dart
//
// Writes:
//   android/app/src/main/res/mipmap-*/ic_launcher*.png  (legacy + adaptive layers)
//   android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml
//   ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-*.png (opaque RGB)
//   branding/app_icon_1024.png, branding/play_store_512.png
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bubble_shooter/painters/brand_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

enum _Kind { full, rounded, foreground, background, monochrome }

ui.Image _render(int size, _Kind kind) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final s = size.toDouble();
  final rect = Offset.zero & Size(s, s);

  switch (kind) {
    case _Kind.full:
      BrandArt.paintBackground(canvas, rect);
      BrandArt.paintEmblem(canvas, _inset(rect, 0.04));
    case _Kind.rounded:
      // Legacy Android icon: rounded square with a little breathing room.
      final inner = _inset(rect, 0.04);
      canvas.clipRRect(RRect.fromRectAndRadius(inner, Radius.circular(inner.width * 0.22)));
      BrandArt.paintBackground(canvas, inner);
      BrandArt.paintEmblem(canvas, _inset(inner, 0.07));
    case _Kind.foreground:
      // Adaptive icons: 108dp canvas, only the central ~66dp is always visible.
      BrandArt.paintEmblem(canvas, _inset(rect, 0.2));
    case _Kind.background:
      BrandArt.paintBackground(canvas, rect);
    case _Kind.monochrome:
      BrandArt.paintEmblem(canvas, _inset(rect, 0.2), monochrome: true);
  }
  return recorder.endRecording().toImageSync(size, size);
}

Rect _inset(Rect r, double fraction) => r.deflate(r.width * fraction);

Future<void> _writePng(ui.Image image, String path, {bool opaque = false}) async {
  final file = File(path)..parent.createSync(recursive: true);
  if (!opaque) {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    file.writeAsBytesSync(data!.buffer.asUint8List());
    return;
  }
  final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  file.writeAsBytesSync(_encodeRgbPng(image.width, image.height, rgba));
}

/// Minimal PNG encoder for opaque RGB images (no alpha channel), as required
/// for iOS app icons.
Uint8List _encodeRgbPng(int w, int h, ByteData rgba) {
  final raw = BytesBuilder();
  for (var y = 0; y < h; y++) {
    raw.addByte(0); // filter: none
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      raw
        ..addByte(rgba.getUint8(i))
        ..addByte(rgba.getUint8(i + 1))
        ..addByte(rgba.getUint8(i + 2));
    }
  }
  final out = BytesBuilder()..add(const [137, 80, 78, 71, 13, 10, 26, 10]);
  void chunk(String type, List<int> data) {
    final typeBytes = type.codeUnits;
    final len = ByteData(4)..setUint32(0, data.length);
    out.add(len.buffer.asUint8List());
    final body = [...typeBytes, ...data];
    out.add(body);
    final crc = ByteData(4)..setUint32(0, _crc32(body));
    out.add(crc.buffer.asUint8List());
  }

  final ihdr = ByteData(13)
    ..setUint32(0, w)
    ..setUint32(4, h)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 2) // color type: RGB
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);
  chunk('IHDR', ihdr.buffer.asUint8List());
  chunk('IDAT', ZLibCodec(level: 9).encode(raw.toBytes()));
  chunk('IEND', const []);
  return out.toBytes();
}

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

void main() {
  test('generate launcher icons', () async {
    const res = 'android/app/src/main/res';
    const densities = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};
    for (final entry in densities.entries) {
      final legacy = (48 * entry.value).round();
      final adaptive = (108 * entry.value).round();
      final dir = '$res/mipmap-${entry.key}';
      await _writePng(_render(legacy, _Kind.rounded), '$dir/ic_launcher.png');
      await _writePng(_render(adaptive, _Kind.foreground), '$dir/ic_launcher_foreground.png');
      await _writePng(_render(adaptive, _Kind.background), '$dir/ic_launcher_background.png');
      await _writePng(_render(adaptive, _Kind.monochrome), '$dir/ic_launcher_monochrome.png');
    }
    File('$res/mipmap-anydpi-v26/ic_launcher.xml')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('''
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
''');

    const ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    const iosIcons = <String, int>{
      'Icon-App-20x20@1x.png': 20,
      'Icon-App-20x20@2x.png': 40,
      'Icon-App-20x20@3x.png': 60,
      'Icon-App-29x29@1x.png': 29,
      'Icon-App-29x29@2x.png': 58,
      'Icon-App-29x29@3x.png': 87,
      'Icon-App-40x40@1x.png': 40,
      'Icon-App-40x40@2x.png': 80,
      'Icon-App-40x40@3x.png': 120,
      'Icon-App-60x60@2x.png': 120,
      'Icon-App-60x60@3x.png': 180,
      'Icon-App-76x76@1x.png': 76,
      'Icon-App-76x76@2x.png': 152,
      'Icon-App-83.5x83.5@2x.png': 167,
      'Icon-App-1024x1024@1x.png': 1024,
    };
    for (final entry in iosIcons.entries) {
      await _writePng(_render(entry.value, _Kind.full), '$ios/${entry.key}', opaque: true);
    }

    await _writePng(_render(1024, _Kind.full), 'branding/app_icon_1024.png', opaque: true);
    await _writePng(_render(512, _Kind.full), 'branding/play_store_512.png', opaque: true);
    await _writePng(_render(432, _Kind.foreground), 'branding/adaptive_foreground_432.png');
    await _writePng(_render(512, _Kind.rounded), 'branding/icon_rounded_512.png');
  });
}
