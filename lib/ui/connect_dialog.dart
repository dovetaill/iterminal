import 'package:flutter/material.dart';
import 'package:iterminal/models/saved_ssh_profile.dart';
import 'package:iterminal/models/ssh_profile.dart';
import 'package:iterminal/state/profile_controller.dart';

class ConnectDialogResult {
  const ConnectDialogResult({
    required this.profile,
    this.savedProfileId,
  });

  final SSHProfile profile;
  final String? savedProfileId;
}

class ConnectDialog extends StatefulWidget {
  const ConnectDialog({
    super.key,
    required this.profiles,
  });

  final ProfileController profiles;

  static Future<ConnectDialogResult?> show(
    BuildContext context, {
    required ProfileController profiles,
  }) {
    return showDialog<ConnectDialogResult>(
      context: context,
      builder: (_) => ConnectDialog(profiles: profiles),
    );
  }

  @override
  State<ConnectDialog> createState() => _ConnectDialogState();
}

class _ConnectDialogState extends State<ConnectDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  bool _obscurePassword = true;
  bool _saveProfile = false;
  bool _favoriteProfile = false;
  bool _submitting = false;
  String? _selectedProfileId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _hostController = TextEditingController(text: '127.0.0.1');
    _portController = TextEditingController(text: '22');
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final port = int.parse(_portController.text.trim());
      final profile = SSHProfile(
        host: _hostController.text.trim(),
        port: port,
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
      );

      String? savedProfileId = _selectedProfileId;
      if (_saveProfile) {
        final saved = await widget.profiles.upsertProfile(
          profile,
          existingId: _selectedProfileId,
          favorite: _favoriteProfile,
        );
        savedProfileId = saved.id;
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(
        ConnectDialogResult(
          profile: profile,
          savedProfileId: savedProfileId,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _selectProfile(SavedSshProfile? profile) {
    if (profile == null) {
      return;
    }

    _nameController.text = profile.displayName ?? '';
    _hostController.text = profile.host;
    _portController.text = profile.port.toString();
    _usernameController.text = profile.username;
    _passwordController.text = profile.password;
    _saveProfile = true;
    _favoriteProfile = profile.favorite;
    _selectedProfileId = profile.id;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.profiles,
      builder: (context, _) {
        final savedProfiles = widget.profiles.profiles;
        final selectedSaved = savedProfiles
            .where((profile) => profile.id == _selectedProfileId)
            .firstOrNull;

        return AlertDialog(
          title: const Text('New SSH Session'),
          content: SizedBox(
            width: 480,
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (savedProfiles.isNotEmpty)
                      DropdownButtonFormField<String>(
                        key: ValueKey<String?>(_selectedProfileId),
                        initialValue: _selectedProfileId,
                        decoration: const InputDecoration(
                          labelText: 'Saved Profile',
                        ),
                        hint: const Text('Select saved profile to autofill'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Use manual input'),
                          ),
                          ...savedProfiles.map(
                            (profile) => DropdownMenuItem<String>(
                              value: profile.id,
                              child: Row(
                                children: [
                                  Icon(
                                    profile.favorite
                                        ? Icons.star
                                        : Icons.bookmark_border,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      profile.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        onChanged: _submitting
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedProfileId = value;
                                });
                                final profile = savedProfiles
                                    .where((item) => item.id == value)
                                    .firstOrNull;
                                _selectProfile(profile);
                              },
                      ),
                    if (savedProfiles.isNotEmpty) const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      enabled: !_submitting,
                      decoration: const InputDecoration(
                        labelText: 'Display Name (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _hostController,
                      enabled: !_submitting,
                      decoration: const InputDecoration(labelText: 'Host'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Host is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _portController,
                      enabled: !_submitting,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Port'),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        final port = int.tryParse(text);
                        if (port == null || port <= 0 || port > 65535) {
                          return 'Port must be 1..65535';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _usernameController,
                      enabled: !_submitting,
                      decoration: const InputDecoration(labelText: 'Username'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Username is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !_submitting,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required for current stage';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Save to encrypted vault'),
                      subtitle: const Text(
                          'Store connection locally for quick reuse'),
                      value: _saveProfile,
                      onChanged: _submitting
                          ? null
                          : (value) {
                              setState(() {
                                _saveProfile = value;
                              });
                            },
                    ),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Mark as favorite'),
                      value: _favoriteProfile,
                      onChanged: !_saveProfile || _submitting
                          ? null
                          : (value) {
                              setState(() {
                                _favoriteProfile = value;
                              });
                            },
                    ),
                    if (widget.profiles.accountName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Vault Account: ${widget.profiles.accountName}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (selectedSaved != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Editing saved profile: ${selectedSaved.title}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _submitting ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? 'Connecting...' : 'Connect'),
            ),
          ],
        );
      },
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
