import 'package:flutter/material.dart';
import 'package:iterminal/state/profile_controller.dart';
import 'package:iterminal/state/settings_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.settings,
    required this.profiles,
  });

  final SettingsController settings;
  final ProfileController profiles;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _accountController;

  @override
  void initState() {
    super.initState();
    _accountController =
        TextEditingController(text: widget.profiles.accountName ?? '');
  }

  @override
  void dispose() {
    _accountController.dispose();
    super.dispose();
  }

  Future<void> _saveAccountName() async {
    await widget.profiles.setAccountName(_accountController.text);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vault account updated')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.settings, widget.profiles]),
      builder: (context, _) {
        final settings = widget.settings;
        final profiles = widget.profiles;
        final profileCount = profiles.profiles.length;
        final snippetCount = profiles.snippets.length;

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
                key: ValueKey<ThemeMode>(settings.themeMode),
                initialValue: settings.themeMode,
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
                key: ValueKey<TerminalPalette>(settings.palette),
                initialValue: settings.palette,
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
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Android Vault',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _accountController,
                decoration: const InputDecoration(
                  labelText: 'Local Account Name',
                  hintText: 'e.g. dev@mobile',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  FilledButton(
                    onPressed: _saveAccountName,
                    child: const Text('Save Account'),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    profiles.saving ? 'Syncing encrypted vault...' : 'Ready',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: Text(
                  'Connections: $profileCount\n'
                  'Snippets: $snippetCount\n'
                  'Storage: Local encrypted vault (device secure store + AES-GCM payload)',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
