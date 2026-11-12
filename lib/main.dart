import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'services/audio_service.dart';
import 'services/settings_controller.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

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

class BubbleShooterApp extends StatefulWidget {
  const BubbleShooterApp({super.key, required this.services});

  final AppServices services;

  @override
  State<BubbleShooterApp> createState() => _BubbleShooterAppState();
}

class _BubbleShooterAppState extends State<BubbleShooterApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Silence music while the app is in the background.
    _lifecycle = AppLifecycleListener(
      onHide: widget.services.audio.suspend,
      onShow: widget.services.audio.resumeFromSuspend,
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    widget.services.audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bubble Shooter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: HomeScreen(services: widget.services),
    );
  }
}
