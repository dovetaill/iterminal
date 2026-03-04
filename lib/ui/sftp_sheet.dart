import 'package:flutter/material.dart';
import 'package:iterminal/models/command_snippet.dart';
import 'package:iterminal/models/sftp_entry.dart';
import 'package:iterminal/state/profile_controller.dart';
import 'package:iterminal/state/session_controller.dart';

class SftpSheet extends StatefulWidget {
  const SftpSheet({
    super.key,
    required this.sessions,
    required this.profiles,
    this.initialPath = '/',
  });

  final SessionController sessions;
  final ProfileController profiles;
  final String initialPath;

  static Future<void> show(
    BuildContext context, {
    required SessionController sessions,
    required ProfileController profiles,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: SftpSheet(
          sessions: sessions,
          profiles: profiles,
        ),
      ),
    );
  }

  @override
  State<SftpSheet> createState() => _SftpSheetState();
}

class _SftpSheetState extends State<SftpSheet> {
  late String _currentPath;
  bool _loading = true;
  String? _error;
  List<SftpEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final entries = await widget.sessions.listDirectory(_currentPath);
      if (!mounted) {
        return;
      }
      setState(() {
        _entries = entries;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '$error';
        _entries = const [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _goParent() async {
    if (_currentPath == '/' || _currentPath.isEmpty) {
      return;
    }
    final normalized = _currentPath.endsWith('/')
        ? _currentPath.substring(0, _currentPath.length - 1)
        : _currentPath;
    final index = normalized.lastIndexOf('/');
    final parent = index <= 0 ? '/' : normalized.substring(0, index);
    setState(() {
      _currentPath = parent;
    });
    await _load();
  }

  Future<void> _openEntry(SftpEntry entry) async {
    if (entry.isDirectory) {
      setState(() {
        _currentPath = entry.path;
      });
      await _load();
      return;
    }
    await _previewFile(entry);
  }

  Future<void> _previewFile(SftpEntry entry) async {
    String content;
    try {
      content = await widget.sessions.readRemoteTextFile(
        entry.path,
        maxBytes: 16384,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Read file failed: $error')),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Preview: ${entry.name}'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: SelectableText(
              content.isEmpty ? '[empty file]' : content,
              style: const TextStyle(fontFamily: 'JetBrains Mono'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openUploadSnippetDialog() async {
    final snippets = widget.profiles.snippets;
    if (snippets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No snippet in vault. Add snippets first.')),
      );
      return;
    }

    final filenameController = TextEditingController(text: 'snippet.sh');
    String selectedId = snippets.first.id;
    bool appendNewline = true;
    bool uploading = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setStateDialog) {
          final selected = snippets.firstWhere(
            (snippet) => snippet.id == selectedId,
          );
          return AlertDialog(
            title: const Text('Upload Snippet'),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedId,
                    decoration: const InputDecoration(labelText: 'Snippet'),
                    items: snippets
                        .map(
                          (snippet) => DropdownMenuItem(
                            value: snippet.id,
                            child: Text(snippet.name),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: uploading
                        ? null
                        : (value) {
                            if (value == null) {
                              return;
                            }
                            final selectedSnippet = snippets.firstWhere(
                              (snippet) => snippet.id == value,
                            );
                            setStateDialog(() {
                              selectedId = value;
                              filenameController.text =
                                  _suggestSnippetFilename(selectedSnippet);
                            });
                          },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: filenameController,
                    enabled: !uploading,
                    decoration: const InputDecoration(
                      labelText: 'Remote file name',
                      hintText: 'deploy.sh',
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: appendNewline,
                    contentPadding: EdgeInsets.zero,
                    onChanged: uploading
                        ? null
                        : (value) {
                            setStateDialog(() {
                              appendNewline = value ?? true;
                            });
                          },
                    title: const Text('Append trailing newline'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    uploading ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: uploading
                    ? null
                    : () async {
                        final fileName = filenameController.text.trim();
                        if (fileName.isEmpty) {
                          return;
                        }

                        final target = _joinPath(_currentPath, fileName);
                        var content = selected.command;
                        if (appendNewline && !content.endsWith('\n')) {
                          content = '$content\n';
                        }
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(dialogContext);

                        setStateDialog(() {
                          uploading = true;
                        });
                        try {
                          await widget.sessions.writeRemoteTextFile(
                            target,
                            content,
                            truncate: true,
                          );
                          if (navigator.mounted) {
                            navigator.pop();
                          }
                          if (!mounted) {
                            return;
                          }
                          messenger.showSnackBar(
                            SnackBar(content: Text('Uploaded to $target')),
                          );
                          await _load();
                        } catch (error) {
                          if (!mounted) {
                            return;
                          }
                          messenger.showSnackBar(
                            SnackBar(content: Text('Upload failed: $error')),
                          );
                        } finally {
                          if (dialogContext.mounted) {
                            setStateDialog(() {
                              uploading = false;
                            });
                          }
                        }
                      },
                child: Text(uploading ? 'Uploading...' : 'Upload'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _suggestSnippetFilename(CommandSnippet snippet) {
    final raw = snippet.name.trim().toLowerCase();
    final normalized = raw.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final collapsed = normalized.replaceAll(RegExp(r'-+'), '-');
    return '${collapsed.isEmpty ? 'snippet' : collapsed}.sh';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SFTP Browser'),
        actions: [
          IconButton(
            tooltip: 'Up',
            onPressed: _goParent,
            icon: const Icon(Icons.arrow_upward),
          ),
          IconButton(
            tooltip: 'Upload snippet',
            onPressed: _openUploadSnippetDialog,
            icon: const Icon(Icons.upload_file),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                _currentPath,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'JetBrains Mono'),
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Load failed: $_error',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_entries.isEmpty) {
      return const Center(child: Text('Directory is empty'));
    }

    return ListView.separated(
      itemCount: _entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return ListTile(
          leading: Icon(
            entry.isDirectory ? Icons.folder : Icons.insert_drive_file,
          ),
          title: Text(
            entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            entry.longname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: entry.isDirectory
              ? const Icon(Icons.chevron_right)
              : entry.size == null
                  ? null
                  : Text(_formatSize(entry.size!)),
          onTap: () => _openEntry(entry),
        );
      },
    );
  }

  String _joinPath(String base, String name) {
    if (base.isEmpty || base == '/') {
      return '/$name';
    }
    if (base.endsWith('/')) {
      return '$base$name';
    }
    return '$base/$name';
  }

  String _formatSize(int size) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = size.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex += 1;
    }
    return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unitIndex]}';
  }
}
