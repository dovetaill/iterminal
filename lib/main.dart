import 'package:flutter/widgets.dart';
import 'package:iterminal/app.dart';
import 'package:iterminal/state/session_controller.dart';
import 'package:iterminal/state/settings_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ITerminalApp(
      settingsController: SettingsController(),
      sessionController: SessionController(),
    ),
  );
}
