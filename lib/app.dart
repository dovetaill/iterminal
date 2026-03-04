import 'package:flutter/material.dart';
import 'package:iterminal/state/profile_controller.dart';
import 'package:iterminal/state/session_controller.dart';
import 'package:iterminal/state/settings_controller.dart';
import 'package:iterminal/ui/terminal_page.dart';

class ITerminalApp extends StatelessWidget {
  const ITerminalApp({
    super.key,
    required this.settingsController,
    required this.sessionController,
    required this.profileController,
  });

  final SettingsController settingsController;
  final SessionController sessionController;
  final ProfileController profileController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        settingsController,
        sessionController,
        profileController,
      ]),
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'iTerminal',
          themeMode: settingsController.themeMode,
          theme: _lightTheme,
          darkTheme: _darkTheme,
          home: TerminalPage(
            sessions: sessionController,
            settings: settingsController,
            profiles: profileController,
          ),
        );
      },
    );
  }
}

final _lightTheme = ThemeData(
  brightness: Brightness.light,
  useMaterial3: true,
  fontFamily: 'Space Grotesk',
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF145A8B),
    brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: const Color(0xFFF4F6FA),
);

final _darkTheme = ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,
  fontFamily: 'Space Grotesk',
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF15A39A),
    brightness: Brightness.dark,
  ),
  scaffoldBackgroundColor: const Color(0xFF0B1118),
);
