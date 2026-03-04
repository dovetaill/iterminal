import 'package:flutter/material.dart';
import 'package:iterminal/models/command_snippet.dart';
import 'package:iterminal/state/profile_controller.dart';
import 'package:iterminal/state/session_controller.dart';

class SnippetSheet extends StatelessWidget {
  const SnippetSheet({
    super.key,
    required this.profiles,
    required this.sessions,
  });

  final ProfileController profiles;
  final SessionController sessions;

  static Future<void> show(
    BuildContext context, {
    required ProfileController profiles,
    required SessionController sessions,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.8,
        child: SnippetSheet(
          profiles: profiles,
          sessions: sessions,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: profiles,
      builder: (context, _) {
        final snippets = profiles.snippets;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Snippets'),
            actions: [
              IconButton(
                tooltip: 'Add snippet',
                onPressed: () => _openEditor(context),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          body: snippets.isEmpty
              ? const Center(child: Text('No snippets. Add your first one.'))
              : ListView.separated(
                  itemCount: snippets.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final snippet = snippets[index];
                    return ListTile(
                      leading: Icon(
                        snippet.favorite
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                      ),
                      title: Text(snippet.name),
                      subtitle: Text(
                        snippet.command,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'JetBrains Mono'),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Favorite',
                            onPressed: () {
                              profiles.setSnippetFavorite(
                                snippet.id,
                                !snippet.favorite,
                              );
                            },
                            icon: Icon(
                              snippet.favorite
                                  ? Icons.star
                                  : Icons.star_border_outlined,
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _openEditor(context, snippet: snippet);
                                return;
                              }
                              if (value == 'delete') {
                                profiles.removeSnippet(snippet.id);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      onTap: () => _executeSnippet(context, snippet),
                    );
                  },
                ),
        );
      },
    );
  }

  Future<void> _executeSnippet(
    BuildContext context,
    CommandSnippet snippet,
  ) async {
    final active = sessions.activeSession;
    if (active == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active terminal session')),
      );
      return;
    }

    var command = snippet.command;
    if (!command.endsWith('\n')) {
      command = '$command\n';
    }
    sessions.pasteToSession(active, command);

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openEditor(
    BuildContext context, {
    CommandSnippet? snippet,
  }) async {
    final nameController = TextEditingController(text: snippet?.name ?? '');
    final commandController =
        TextEditingController(text: snippet?.command ?? '');
    var favorite = snippet?.favorite ?? false;
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(snippet == null ? 'New snippet' : 'Edit snippet'),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    enabled: !saving,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: commandController,
                    enabled: !saving,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Command',
                      alignLabelWithHint: true,
                    ),
                    style: const TextStyle(fontFamily: 'JetBrains Mono'),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: favorite,
                    contentPadding: EdgeInsets.zero,
                    onChanged: saving
                        ? null
                        : (value) {
                            setStateDialog(() {
                              favorite = value ?? false;
                            });
                          },
                    title: const Text('Mark as favorite'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        final command = commandController.text.trim();
                        if (name.isEmpty || command.isEmpty) {
                          return;
                        }

                        setStateDialog(() {
                          saving = true;
                        });
                        await profiles.upsertSnippet(
                          existingId: snippet?.id,
                          name: name,
                          command: command,
                          favorite: favorite,
                        );
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                child: Text(saving ? 'Saving...' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}
