import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

enum TerminalPalette {
  midnight,
  daylight,
  matrix,
}

class SettingsController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  TerminalPalette _palette = TerminalPalette.midnight;
  double _fontSize = 13;

  ThemeMode get themeMode => _themeMode;
  TerminalPalette get palette => _palette;
  double get fontSize => _fontSize;

  void setThemeMode(ThemeMode value) {
    if (_themeMode == value) {
      return;
    }
    _themeMode = value;
    notifyListeners();
  }

  void setPalette(TerminalPalette value) {
    if (_palette == value) {
      return;
    }
    _palette = value;
    notifyListeners();
  }

  void setFontSize(double value) {
    final normalized = value.clamp(11, 20).toDouble();
    if (_fontSize == normalized) {
      return;
    }
    _fontSize = normalized;
    notifyListeners();
  }

  TerminalTheme get terminalTheme {
    switch (_palette) {
      case TerminalPalette.midnight:
        return _midnightTheme;
      case TerminalPalette.daylight:
        return _daylightTheme;
      case TerminalPalette.matrix:
        return _matrixTheme;
    }
  }

  TerminalStyle get terminalTextStyle => TerminalStyle(
        fontSize: _fontSize,
        height: 1.26,
        fontFamily: 'JetBrains Mono',
        fontFamilyFallback: const [
          'Cascadia Code',
          'Consolas',
          'Fira Code',
          'Noto Sans Mono CJK SC',
          'monospace',
        ],
      );

  static const Map<TerminalPalette, String> paletteLabels = {
    TerminalPalette.midnight: 'Midnight Teal',
    TerminalPalette.daylight: 'Daylight Paper',
    TerminalPalette.matrix: 'Matrix Green',
  };
}

const _midnightTheme = TerminalTheme(
  cursor: Color(0xFF7EE4E1),
  selection: Color(0x663B9EA2),
  foreground: Color(0xFFDCE7E7),
  background: Color(0xFF0E1B21),
  black: Color(0xFF10171B),
  red: Color(0xFFEF6B73),
  green: Color(0xFF39CF8E),
  yellow: Color(0xFFF8C555),
  blue: Color(0xFF66A3FF),
  magenta: Color(0xFFBC89FF),
  cyan: Color(0xFF53D8C9),
  white: Color(0xFFC5D4D6),
  brightBlack: Color(0xFF5E7982),
  brightRed: Color(0xFFFF8C95),
  brightGreen: Color(0xFF5DFFC6),
  brightYellow: Color(0xFFFFDE86),
  brightBlue: Color(0xFF8FC2FF),
  brightMagenta: Color(0xFFD8B7FF),
  brightCyan: Color(0xFF8DF1E9),
  brightWhite: Color(0xFFFFFFFF),
  searchHitBackground: Color(0xFF2F5E72),
  searchHitBackgroundCurrent: Color(0xFF45A8D5),
  searchHitForeground: Color(0xFFFFFFFF),
);

const _daylightTheme = TerminalTheme(
  cursor: Color(0xFF0D3E5B),
  selection: Color(0x553B7AB8),
  foreground: Color(0xFF1F2430),
  background: Color(0xFFF6F3EA),
  black: Color(0xFF232734),
  red: Color(0xFFB02A37),
  green: Color(0xFF1A7A4E),
  yellow: Color(0xFF9C6A00),
  blue: Color(0xFF2356B0),
  magenta: Color(0xFF87419E),
  cyan: Color(0xFF0A6A74),
  white: Color(0xFFECE9E1),
  brightBlack: Color(0xFF5C6773),
  brightRed: Color(0xFFCA4B5C),
  brightGreen: Color(0xFF2F9A67),
  brightYellow: Color(0xFFBC8708),
  brightBlue: Color(0xFF3E72CB),
  brightMagenta: Color(0xFF9E62B7),
  brightCyan: Color(0xFF238B97),
  brightWhite: Color(0xFFFFFFFF),
  searchHitBackground: Color(0xFF9EB8D1),
  searchHitBackgroundCurrent: Color(0xFF5C8FC1),
  searchHitForeground: Color(0xFF102038),
);

const _matrixTheme = TerminalTheme(
  cursor: Color(0xFF00FF80),
  selection: Color(0x5500AA44),
  foreground: Color(0xFF8BFF9C),
  background: Color(0xFF07110A),
  black: Color(0xFF050905),
  red: Color(0xFF0FA15D),
  green: Color(0xFF2BCF70),
  yellow: Color(0xFF3CD98A),
  blue: Color(0xFF2AA875),
  magenta: Color(0xFF29BB68),
  cyan: Color(0xFF4EE3A0),
  white: Color(0xFF6CF0B3),
  brightBlack: Color(0xFF0E4F2A),
  brightRed: Color(0xFF36F08A),
  brightGreen: Color(0xFF61FFAA),
  brightYellow: Color(0xFF8EFFBF),
  brightBlue: Color(0xFF7BE8B2),
  brightMagenta: Color(0xFF7BFFBA),
  brightCyan: Color(0xFFA1FFD0),
  brightWhite: Color(0xFFD5FFE9),
  searchHitBackground: Color(0xFF0F703A),
  searchHitBackgroundCurrent: Color(0xFF15AF57),
  searchHitForeground: Color(0xFFFFFFFF),
);
