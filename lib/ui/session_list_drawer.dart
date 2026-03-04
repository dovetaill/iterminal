import 'package:flutter/material.dart';
import 'package:iterminal/models/saved_ssh_profile.dart';
import 'package:iterminal/models/terminal_session.dart';
import 'package:iterminal/state/profile_controller.dart';
import 'package:iterminal/state/session_controller.dart';

class SessionListDrawer extends StatelessWidget {
  const SessionListDrawer({
    super.key,
    required this.sessions,
    required this.profiles,
    required this.onCreateSession,
    required this.onConnectSavedProfile,
  });

  final SessionController sessions;
  final ProfileController profiles;
  final Future<void> Function() onCreateSession;
  final Future<void> Function(SavedSshProfile profile) onConnectSavedProfile;

  @override
  Widget build(BuildContext context) {
    final allSessions = sessions.sessions;
    final favorites = profiles.favoriteProfiles;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              title: const Text(
                'Sessions',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('${allSessions.length} active'),
              trailing: IconButton(
                tooltip: 'New session',
                onPressed: () async {
                  Navigator.of(context).pop();
                  await onCreateSession();
                },
                icon: const Icon(Icons.add),
              ),
            ),
            if (profiles.accountName != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Vault: ${profiles.accountName}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: [
                  _sectionHeader(context, 'Active Sessions'),
                  if (allSessions.isEmpty)
                    const ListTile(
                      dense: true,
                      title: Text('No active sessions'),
                    ),
                  for (var i = 0; i < allSessions.length; i++)
                    _sessionTile(context, allSessions[i], i),
                  _sectionHeader(context, 'Favorite Connections'),
                  if (favorites.isEmpty)
                    const ListTile(
                      dense: true,
                      title: Text('No favorite connection yet'),
                    ),
                  for (final profile in favorites)
                    _favoriteTile(context, profile),
                ],
              ),
            ),
            if (allSessions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.tonal(
                  onPressed: () async {
                    await sessions.closeAllSessions();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Close all sessions'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 0.5,
            color: Theme.of(context).colorScheme.outline,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _sessionTile(
      BuildContext context, TerminalSession session, int index) {
    return ListTile(
      selected: index == sessions.activeIndex,
      leading: Icon(
        Icons.circle,
        size: 10,
        color: _statusColor(session.status),
      ),
      title: Text(
        session.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(session.profile.host),
      trailing: IconButton(
        tooltip: 'Close',
        onPressed: () {
          sessions.closeSession(session.id);
        },
        icon: const Icon(Icons.close, size: 18),
      ),
      onTap: () {
        sessions.setActiveIndex(index);
        Navigator.of(context).pop();
      },
    );
  }

  Widget _favoriteTile(BuildContext context, SavedSshProfile profile) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.star, size: 18),
      title: Text(
        profile.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text('${profile.username}@${profile.host}:${profile.port}'),
      trailing: IconButton(
        tooltip: 'Remove favorite',
        onPressed: () {
          profiles.setProfileFavorite(profile.id, false);
        },
        icon: const Icon(Icons.star_border),
      ),
      onTap: () async {
        Navigator.of(context).pop();
        await onConnectSavedProfile(profile);
      },
    );
  }

  Color _statusColor(SessionStatus status) {
    switch (status) {
      case SessionStatus.connecting:
        return Colors.amber;
      case SessionStatus.reconnecting:
        return Colors.orangeAccent;
      case SessionStatus.connected:
        return Colors.green;
      case SessionStatus.disconnected:
        return Colors.blueGrey;
      case SessionStatus.error:
        return Colors.redAccent;
    }
  }
}
