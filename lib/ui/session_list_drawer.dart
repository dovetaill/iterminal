import 'package:flutter/material.dart';
import 'package:iterminal/models/terminal_session.dart';
import 'package:iterminal/state/session_controller.dart';

class SessionListDrawer extends StatelessWidget {
  const SessionListDrawer({
    super.key,
    required this.sessions,
    required this.onCreateSession,
  });

  final SessionController sessions;
  final Future<void> Function() onCreateSession;

  @override
  Widget build(BuildContext context) {
    final all = sessions.sessions;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              title: const Text(
                'Sessions',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('${all.length} active'),
              trailing: IconButton(
                tooltip: 'New session',
                onPressed: () async {
                  Navigator.of(context).pop();
                  await onCreateSession();
                },
                icon: const Icon(Icons.add),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: all.isEmpty
                  ? const Center(child: Text('No active sessions'))
                  : ListView.builder(
                      itemCount: all.length,
                      itemBuilder: (context, index) {
                        final session = all[index];
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
                      },
                    ),
            ),
            if (all.isNotEmpty)
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

  Color _statusColor(SessionStatus status) {
    switch (status) {
      case SessionStatus.connecting:
        return Colors.amber;
      case SessionStatus.connected:
        return Colors.green;
      case SessionStatus.disconnected:
        return Colors.blueGrey;
      case SessionStatus.error:
        return Colors.redAccent;
    }
  }
}
