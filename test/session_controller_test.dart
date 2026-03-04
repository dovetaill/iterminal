import 'package:flutter_test/flutter_test.dart';
import 'package:iterminal/models/ssh_profile.dart';
import 'package:iterminal/models/terminal_session.dart';
import 'package:iterminal/services/ssh_connection.dart';
import 'package:iterminal/state/session_controller.dart';
import 'package:xterm/xterm.dart';

void main() {
  group('SessionController', () {
    test('creates connected session from factory', () async {
      final connections = <_FakeConnection>[];
      final controller = SessionController(
        connectionFactory: (profile) {
          final conn = _FakeConnection(profile: profile);
          connections.add(conn);
          return conn;
        },
        terminalFactory: () => Terminal(maxLines: 200),
        terminalControllerFactory: TerminalController.new,
      );

      await controller.connect(
        SSHProfile(
          host: '127.0.0.1',
          port: 22,
          username: 'root',
          password: 'pwd',
        ),
      );

      expect(controller.sessions.length, 1);
      expect(controller.activeSession?.status, SessionStatus.connected);
      expect(controller.activeSession?.outputText, contains('Connected'));
      expect(connections.length, 1);
      expect(connections.first.connected, isTrue);
    });

    test('toggle split mode requires at least 2 sessions', () async {
      final controller = SessionController(
        connectionFactory: (profile) => _FakeConnection(profile: profile),
        terminalFactory: () => Terminal(maxLines: 200),
        terminalControllerFactory: TerminalController.new,
      );

      await controller.connect(_profile('host-a'));
      controller.toggleSplitView();
      expect(controller.splitView, isFalse);

      await controller.connect(_profile('host-b'));
      controller.toggleSplitView();

      expect(controller.splitView, isTrue);
      expect(controller.secondarySession, isNotNull);
    });

    test('search counts active session hits', () async {
      final controller = SessionController(
        connectionFactory: (profile) => _FakeConnection(
          profile: profile,
          sampleStdout: 'alpha beta alpha gamma',
        ),
        terminalFactory: () => Terminal(maxLines: 200),
        terminalControllerFactory: TerminalController.new,
      );

      await controller.connect(_profile('host-a'));

      final hits = controller.searchInActiveSession('alpha');

      expect(hits, 2);
      expect(controller.activeSession?.searchHits, 2);
      expect(controller.activeSession?.searchCursor, 1);
    });

    test('close session disconnects connection', () async {
      final connections = <_FakeConnection>[];
      final controller = SessionController(
        connectionFactory: (profile) {
          final conn = _FakeConnection(profile: profile);
          connections.add(conn);
          return conn;
        },
        terminalFactory: () => Terminal(maxLines: 200),
        terminalControllerFactory: TerminalController.new,
      );

      await controller.connect(_profile('host-a'));
      final id = controller.activeSession!.id;

      await controller.closeSession(id);

      expect(controller.sessions, isEmpty);
      expect(connections.first.disconnected, isTrue);
    });
  });
}

SSHProfile _profile(String host) {
  return SSHProfile(
    host: host,
    port: 22,
    username: 'root',
    password: 'pwd',
  );
}

class _FakeConnection implements SshConnectionAdapter {
  _FakeConnection({required this.profile, this.sampleStdout = 'hello from fake'});

  final SSHProfile profile;
  final String sampleStdout;

  bool connected = false;
  bool disconnected = false;

  @override
  Future<void> connect({
    required OnStdout onStdout,
    required OnStderr onStderr,
    required OnDone onDone,
    required OnError onError,
    OnTitleChange? onTitleChange,
  }) async {
    connected = true;
    onTitleChange?.call('fake-${profile.host}');
    onStdout(sampleStdout);
  }

  @override
  Future<void> disconnect() async {
    disconnected = true;
  }

  @override
  void resize(
    int width,
    int height, {
    int pixelWidth = 0,
    int pixelHeight = 0,
  }) {
    // no-op
  }

  @override
  void write(String data) {
    // no-op
  }
}
