import 'package:flutter/material.dart';
import 'package:iterminal/state/settings_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.settings,
  });

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Appearance',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ThemeMode>(
                value: settings.themeMode,
                decoration: const InputDecoration(
                  labelText: 'App Theme Mode',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text('System'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text('Dark'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text('Light'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    settings.setThemeMode(value);
                  }
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TerminalPalette>(
                value: settings.palette,
                decoration: const InputDecoration(
                  labelText: 'Terminal Palette',
                  border: OutlineInputBorder(),
                ),
                items: TerminalPalette.values
                    .map(
                      (palette) => DropdownMenuItem(
                        value: palette,
                        child: Text(
                          SettingsController.paletteLabels[palette] ??
                              palette.name,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) {
                    settings.setPalette(value);
                  }
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Terminal Font Size: ${settings.fontSize.toStringAsFixed(1)}',
              ),
              Slider(
                value: settings.fontSize,
                min: 11,
                max: 20,
                divisions: 18,
                label: settings.fontSize.toStringAsFixed(1),
                onChanged: settings.setFontSize,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: const Text(
                  'MVP 范围内设置仅保存在内存。\n后续 Android 阶段会接入本地加密存储与账户体系。',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
