import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iterminal/models/terminal_session.dart';
import 'package:iterminal/state/session_controller.dart';
import 'package:iterminal/state/settings_controller.dart';
import 'package:iterminal/ui/connect_dialog.dart';
import 'package:iterminal/ui/session_list_drawer.dart';
import 'package:iterminal/ui/settings_page.dart';
import 'package:xterm/xterm.dart';

class TerminalPage extends StatefulWidget {
  const TerminalPage({
    super.key,
    required this.sessions,
    required this.settings,
  });

  final SessionController sessions;
  final SettingsController settings;

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _showSearchBar = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _openConnectDialog() async {
    final profile = await ConnectDialog.show(context);
    if (profile == null) {
      return;
    }

    final session = await widget.sessions.connect(profile);
    if (!mounted) {
      return;
    }

    if (session.status == SessionStatus.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed: ${session.lastError ?? ''}')),
      );
    }
  }

  void _openSettingsPage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(settings: widget.settings),
      ),
    );
  }

  void _toggleSearchBar({bool forceOpen = false}) {
    setState(() {
      if (forceOpen) {
        _showSearchBar = true;
      } else {
        _showSearchBar = !_showSearchBar;
      }

      if (!_showSearchBar) {
        _searchController.clear();
        widget.sessions.searchInActiveSession('');
      }
    });

    if (_showSearchBar) {
      _searchFocusNode.requestFocus();
    }
  }

  Future<void> _onTerminalSecondaryTap(TerminalSession session) async {
    final selection = session.controller.selection;
    if (selection != null) {
      await widget.sessions.copySelectionFromSession(session);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied selection')),
      );
      return;
    }

    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (text == null || text.isEmpty) {
      return;
    }

    widget.sessions.pasteToSession(session, text);
  }

  @override
  Widget build(BuildContext context) {
    final sessions = widget.sessions;
    final settings = widget.settings;

    return AnimatedBuilder(
      animation: Listenable.merge([sessions, settings]),
      builder: (context, _) {
        return Shortcuts(
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(
              LogicalKeyboardKey.keyT,
              control: true,
              shift: true,
            ): _NewSessionIntent(),
            SingleActivator(
              LogicalKeyboardKey.keyW,
              control: true,
              shift: true,
            ): _CloseSessionIntent(),
            SingleActivator(LogicalKeyboardKey.tab, control: true):
                _NextTabIntent(),
            SingleActivator(
              LogicalKeyboardKey.tab,
              control: true,
              shift: true,
            ): _PreviousTabIntent(),
            SingleActivator(
              LogicalKeyboardKey.keyC,
              control: true,
              shift: true,
            ): _CopyIntent(),
            SingleActivator(
              LogicalKeyboardKey.keyV,
              control: true,
              shift: true,
            ): _PasteIntent(),
            SingleActivator(LogicalKeyboardKey.keyF, control: true):
                _SearchIntent(),
            SingleActivator(
              LogicalKeyboardKey.backslash,
              control: true,
              shift: true,
            ): _SplitIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _NewSessionIntent: CallbackAction<_NewSessionIntent>(
                onInvoke: (_) {
                  unawaited(_openConnectDialog());
                  return null;
                },
              ),
              _CloseSessionIntent: CallbackAction<_CloseSessionIntent>(
                onInvoke: (_) {
                  unawaited(sessions.closeActiveSession());
                  return null;
                },
              ),
              _NextTabIntent: CallbackAction<_NextTabIntent>(
                onInvoke: (_) {
                  sessions.activateNextTab();
                  return null;
                },
              ),
              _PreviousTabIntent: CallbackAction<_PreviousTabIntent>(
                onInvoke: (_) {
                  sessions.activatePreviousTab();
                  return null;
                },
              ),
              _CopyIntent: CallbackAction<_CopyIntent>(
                onInvoke: (_) {
                  unawaited(sessions.copyActiveSelection());
                  return null;
                },
              ),
              _PasteIntent: CallbackAction<_PasteIntent>(
                onInvoke: (_) {
                  unawaited(sessions.pasteFromClipboard());
                  return null;
                },
              ),
              _SearchIntent: CallbackAction<_SearchIntent>(
                onInvoke: (_) {
                  _toggleSearchBar(forceOpen: true);
                  return null;
                },
              ),
              _SplitIntent: CallbackAction<_SplitIntent>(
                onInvoke: (_) {
                  sessions.toggleSplitView();
                  return null;
                },
              ),
            },
            child: Focus(
              autofocus: true,
              child: Scaffold(
                drawer: SessionListDrawer(
                  sessions: sessions,
                  onCreateSession: _openConnectDialog,
                ),
                appBar: AppBar(
                  title: const Text('iTerminal'),
                  actions: [
                    IconButton(
                      tooltip: 'New Session (Ctrl+Shift+T)',
                      onPressed: () => unawaited(_openConnectDialog()),
                      icon: const Icon(Icons.add_link),
                    ),
                    IconButton(
                      tooltip: 'Toggle Split (Ctrl+Shift+\\)',
                      onPressed: sessions.toggleSplitView,
                      icon: Icon(
                        sessions.splitView
                            ? Icons.splitscreen_outlined
                            : Icons.splitscreen,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Search (Ctrl+F)',
                      onPressed: _toggleSearchBar,
                      icon: Icon(
                        _showSearchBar ? Icons.search_off : Icons.search,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Settings',
                      onPressed: _openSettingsPage,
                      icon: const Icon(Icons.tune),
                    ),
                  ],
                ),
                body: Column(
                  children: [
                    _buildTabStrip(context),
                    if (_showSearchBar) _buildSearchBar(),
                    Expanded(child: _buildBody()),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabStrip(BuildContext context) {
    final sessions = widget.sessions;
    final all = sessions.sessions;

    if (all.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: all.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final session = all[index];
                final selected = index == sessions.activeIndex;

                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => sessions.setActiveIndex(index),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 140),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                                .colorScheme
                                .outlineVariant
                                .withOpacity(0.5),
                      ),
                      gradient: selected
                          ? const LinearGradient(
                              colors: [Color(0xFF17384D), Color(0xFF214A47)],
                            )
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: _statusColor(session.status),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            session.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => unawaited(
                            widget.sessions.closeSession(session.id),
                          ),
                          child: const Icon(Icons.close, size: 16),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (sessions.splitView && all.length > 1)
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<int>(
                value: sessions.secondaryIndex,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                hint: const Text('Secondary'),
                items: [
                  for (var i = 0; i < all.length; i++)
                    if (i != sessions.activeIndex)
                      DropdownMenuItem<int>(
                        value: i,
                        child: Text(
                          all[i].title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    sessions.setSecondaryIndex(value);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final active = widget.sessions.activeSession;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              focusNode: _searchFocusNode,
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
                hintText: 'Search in scrollback...',
              ),
              onChanged: widget.sessions.searchInActiveSession,
              onSubmitted: (_) {
                widget.sessions.moveSearchCursor(forward: true);
              },
            ),
          ),
          const SizedBox(width: 10),
          Text(
            active == null
                ? '0'
                : '${active.searchCursor}/${active.searchHits}',
          ),
          IconButton(
            tooltip: 'Previous match',
            onPressed: () => widget.sessions.moveSearchCursor(forward: false),
            icon: const Icon(Icons.keyboard_arrow_up),
          ),
          IconButton(
            tooltip: 'Next match',
            onPressed: () => widget.sessions.moveSearchCursor(forward: true),
            icon: const Icon(Icons.keyboard_arrow_down),
          ),
          IconButton(
            tooltip: 'Close search',
            onPressed: _toggleSearchBar,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final sessions = widget.sessions;

    if (!sessions.hasSessions) {
      return DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A1118), Color(0xFF152836)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No active session',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create a SSH session to start terminal interaction. '
                      'MVP supports password login, multi-tab, split view and shortcuts.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => unawaited(_openConnectDialog()),
                      icon: const Icon(Icons.terminal),
                      label: const Text('Open SSH Session'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final primary = sessions.activeSession;
    if (primary == null) {
      return const SizedBox.shrink();
    }

    final secondary = sessions.secondarySession;

    if (sessions.splitView && secondary != null) {
      return Row(
        children: [
          Expanded(child: _buildTerminalPane(primary, autofocus: true)),
          const VerticalDivider(width: 1),
          Expanded(child: _buildTerminalPane(secondary)),
        ],
      );
    }

    return _buildTerminalPane(primary, autofocus: true);
  }

  Widget _buildTerminalPane(
    TerminalSession session, {
    bool autofocus = false,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surfaceContainerLow,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: TerminalView(
            session.terminal,
            controller: session.controller,
            autofocus: autofocus,
            theme: widget.settings.terminalTheme,
            textStyle: widget.settings.terminalTextStyle,
            onSecondaryTapDown: (_, __) {
              unawaited(_onTerminalSecondaryTap(session));
            },
          ),
        ),
      ),
    );
  }

  Color _statusColor(SessionStatus status) {
    switch (status) {
      case SessionStatus.connecting:
        return Colors.amber;
      case SessionStatus.connected:
        return Colors.greenAccent;
      case SessionStatus.disconnected:
        return Colors.blueGrey;
      case SessionStatus.error:
        return Colors.redAccent;
    }
  }
}

class _NewSessionIntent extends Intent {
  const _NewSessionIntent();
}

class _CloseSessionIntent extends Intent {
  const _CloseSessionIntent();
}

class _NextTabIntent extends Intent {
  const _NextTabIntent();
}

class _PreviousTabIntent extends Intent {
  const _PreviousTabIntent();
}

class _CopyIntent extends Intent {
  const _CopyIntent();
}

class _PasteIntent extends Intent {
  const _PasteIntent();
}

class _SearchIntent extends Intent {
  const _SearchIntent();
}

class _SplitIntent extends Intent {
  const _SplitIntent();
}
