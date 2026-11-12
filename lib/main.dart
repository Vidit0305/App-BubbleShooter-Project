import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'services/audio_service.dart';
import 'services/settings_controller.dart';
import 'services/storage_service.dart';

/// Entry point: locks portrait, loads settings, starts audio, runs the app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

  final storage = await StorageService.create();
  final audio = AssetAudioService();
  final settings = SettingsController(storage: storage, audio: audio)..load();
  // Audio loads in the background; the game works even if it fails.
  audio.init();

  runApp(BubbleShooterApp(services: AppServices(settings: settings)));
}
