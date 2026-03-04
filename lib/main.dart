import 'package:flutter/widgets.dart';
import 'package:iterminal/app.dart';
import 'package:iterminal/services/secure_store.dart';
import 'package:iterminal/services/secure_vault.dart';
import 'package:iterminal/services/settings_persistence.dart';
import 'package:iterminal/state/profile_controller.dart';
import 'package:iterminal/state/session_controller.dart';
import 'package:iterminal/state/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsPersistence =
      await SharedPreferencesSettingsPersistence.create();
  final settingsController =
      SettingsController(persistence: settingsPersistence);
  await settingsController.load();

  final profileController = ProfileController(
    vault: SecureVaultService(store: FlutterSecureStore()),
  );
  await profileController.load();

  runApp(
    ITerminalApp(
      settingsController: settingsController,
      sessionController: SessionController(),
      profileController: profileController,
    ),
  );
}
