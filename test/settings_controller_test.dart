import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iterminal/state/settings_controller.dart';

void main() {
  group('SettingsController', () {
    test('has expected defaults', () {
      final controller = SettingsController();

      expect(controller.themeMode, ThemeMode.dark);
      expect(controller.palette, TerminalPalette.midnight);
      expect(controller.fontSize, 13);
    });

    test('updates theme mode', () {
      final controller = SettingsController();

      controller.setThemeMode(ThemeMode.light);

      expect(controller.themeMode, ThemeMode.light);
    });

    test('clamps font size range', () {
      final controller = SettingsController();

      controller.setFontSize(99);
      expect(controller.fontSize, 20);

      controller.setFontSize(3);
      expect(controller.fontSize, 11);
    });
  });
}
