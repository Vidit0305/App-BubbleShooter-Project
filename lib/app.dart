import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/settings_controller.dart';
import 'theme/app_theme.dart';

/// Root widget: theme, home screen and app-wide lifecycle handling.
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
