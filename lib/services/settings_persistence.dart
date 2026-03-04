import 'package:shared_preferences/shared_preferences.dart';

class SettingsSnapshot {
  const SettingsSnapshot({
    required this.themeMode,
    required this.palette,
    required this.fontSize,
  });

  final String themeMode;
  final String palette;
  final double fontSize;
}

abstract class SettingsPersistence {
  Future<SettingsSnapshot?> read();

  Future<void> write(SettingsSnapshot snapshot);
}

class SharedPreferencesSettingsPersistence implements SettingsPersistence {
  SharedPreferencesSettingsPersistence(this._prefs);

  final SharedPreferences _prefs;

  static const String _themeModeKey = 'iterminal.settings.themeMode';
  static const String _paletteKey = 'iterminal.settings.palette';
  static const String _fontSizeKey = 'iterminal.settings.fontSize';

  static Future<SharedPreferencesSettingsPersistence> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SharedPreferencesSettingsPersistence(prefs);
  }

  @override
  Future<SettingsSnapshot?> read() async {
    final themeMode = _prefs.getString(_themeModeKey);
    final palette = _prefs.getString(_paletteKey);
    final fontSize = _prefs.getDouble(_fontSizeKey);

    if (themeMode == null && palette == null && fontSize == null) {
      return null;
    }

    return SettingsSnapshot(
      themeMode: themeMode ?? 'dark',
      palette: palette ?? 'midnight',
      fontSize: fontSize ?? 13,
    );
  }

  @override
  Future<void> write(SettingsSnapshot snapshot) async {
    await _prefs.setString(_themeModeKey, snapshot.themeMode);
    await _prefs.setString(_paletteKey, snapshot.palette);
    await _prefs.setDouble(_fontSizeKey, snapshot.fontSize);
  }
}

class InMemorySettingsPersistence implements SettingsPersistence {
  SettingsSnapshot? _snapshot;

  @override
  Future<SettingsSnapshot?> read() async {
    return _snapshot;
  }

  @override
  Future<void> write(SettingsSnapshot snapshot) async {
    _snapshot = snapshot;
  }
}
