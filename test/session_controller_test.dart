import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:iterminal/models/sftp_entry.dart';
import 'package:iterminal/models/ssh_profile.dart';
import 'package:iterminal/models/terminal_session.dart';
import 'package:iterminal/services/network_monitor.dart';
import 'package:iterminal/services/ssh_connection.dart';
import 'package:iterminal/state/session_controller.dart';
import 'package:xterm/xterm.dart';

void main() {
  group('SessionController', () {
    test('creates connected session from factory', () async {
      final network = _FakeNetworkMonitor(initialOnline: true);
      final connections = <_FakeConnection>[];
      final controller = SessionController(
        networkMonitor: network,
        connectionFactory: (profile) {
          final conn = _FakeConnection(profile: profile);
          connections.add(conn);
          return conn;
        },
        terminalFactory: () => Terminal(maxLines: 200),
        terminalControllerFactory: TerminalController.new,
      );
      addTearDown(() async {
        controller.dispose();
        await network.dispose();
      });

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

    test('auto reconnects when transport throws error', () async {
      final network = _FakeNetworkMonitor(initialOnline: true);
      final connections = <_FakeConnection>[];
      final controller = SessionController(
        networkMonitor: network,
        reconnectBaseDelay: const Duration(milliseconds: 1),
        reconnectMaxDelay: const Duration(milliseconds: 1),
        connectionFactory: (profile) {
          final conn = _FakeConnection(profile: profile);
          connections.add(conn);
          return conn;
        },
        terminalFactory: () => Terminal(maxLines: 200),
        terminalControllerFactory: TerminalController.new,
      );
      addTearDown(() async {
        controller.dispose();
        await network.dispose();
      });

      await controller.connect(_profile('host-a'));
      expect(connections.length, 1);

      connections.first.emitError(StateError('network reset by peer'));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(connections.length, greaterThanOrEqualTo(2));
      expect(controller.activeSession?.status, SessionStatus.connected);
      expect(
        controller.activeSession?.outputText,
        contains('Reconnected'),
      );
    });

    test('waits for network restoration before reconnecting', () async {
      final network = _FakeNetworkMonitor(initialOnline: true);
      final connections = <_FakeConnection>[];
      final controller = SessionController(
        networkMonitor: network,
        reconnectBaseDelay: const Duration(milliseconds: 1),
        reconnectMaxDelay: const Duration(milliseconds: 1),
        connectionFactory: (profile) {
          final conn = _FakeConnection(profile: profile);
          connections.add(conn);
          return conn;
        },
        terminalFactory: () => Terminal(maxLines: 200),
        terminalControllerFactory: TerminalController.new,
      );
      addTearDown(() async {
        controller.dispose();
        await network.dispose();
      });

      await controller.connect(_profile('host-a'));
      network.emit(false);
      connections.first.emitDone();
      await Future<void>.delayed(const Duration(milliseconds: 15));

      expect(controller.activeSession?.status, SessionStatus.reconnecting);
      expect(controller.activeSession?.waitingForNetwork, isTrue);

      network.emit(true);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(controller.activeSession?.status, SessionStatus.connected);
      expect(controller.isNetworkOnline, isTrue);
    });

    test('toggle split mode requires at least 2 sessions', () async {
      final network = _FakeNetworkMonitor(initialOnline: true);
      final controller = SessionController(
        networkMonitor: network,
        connectionFactory: (profile) => _FakeConnection(profile: profile),
        terminalFactory: () => Terminal(maxLines: 200),
        terminalControllerFactory: TerminalController.new,
      );
      addTearDown(() async {
        controller.dispose();
        await network.dispose();
      });

      await controller.connect(_profile('host-a'));
      controller.toggleSplitView();
      expect(controller.splitView, isFalse);

      await controller.connect(_profile('host-b'));
      controller.toggleSplitView();

      expect(controller.splitView, isTrue);
      expect(controller.secondarySession, isNotNull);
    });

    test('search counts active session hits', () async {
      final network = _FakeNetworkMonitor(initialOnline: true);
      final controller = SessionController(
        networkMonitor: network,
        connectionFactory: (profile) => _FakeConnection(
          profile: profile,
          sampleStdout: 'alpha beta alpha gamma',
        ),
        terminalFactory: () => Terminal(maxLines: 200),
        terminalControllerFactory: TerminalController.new,
      );
      addTearDown(() async {
        controller.dispose();
        await network.dispose();
      });

      await controller.connect(_profile('host-a'));

      final hits = controller.searchInActiveSession('alpha');

      expect(hits, 2);
      expect(controller.activeSession?.searchHits, 2);
      expect(controller.activeSession?.searchCursor, 1);
    });

    test('close session disconnects connection', () async {
      final network = _FakeNetworkMonitor(initialOnline: true);
      final connections = <_FakeConnection>[];
      final controller = SessionController(
        networkMonitor: network,
        connectionFactory: (profile) {
          final conn = _FakeConnection(profile: profile);
          connections.add(conn);
          return conn;
        },
        terminalFactory: () => Terminal(maxLines: 200),
        terminalControllerFactory: TerminalController.new,
      );
      addTearDown(() async {
        controller.dispose();
        await network.dispose();
      });

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

class _FakeNetworkMonitor implements NetworkMonitor {
  _FakeNetworkMonitor({required bool initialOnline}) : _online = initialOnline;

  bool _online;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> isOnline() async {
    return _online;
  }

  @override
  Stream<bool> get onOnlineChanged => _controller.stream;

  void emit(bool online) {
    _online = online;
    _controller.add(online);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

class _FakeConnection implements SshConnectionAdapter {
  _FakeConnection({required this.profile, this.sampleStdout = 'hello from fake'});

  final SSHProfile profile;
  final String sampleStdout;

  bool connected = false;
  bool disconnected = false;

  OnDone? _onDone;
  OnError? _onError;

  @override
  Future<void> connect({
    required OnStdout onStdout,
    required OnStderr onStderr,
    required OnDone onDone,
    required OnError onError,
    OnTitleChange? onTitleChange,
  }) async {
    connected = true;
    _onDone = onDone;
    _onError = onError;
    onTitleChange?.call('fake-${profile.host}');
    onStdout(sampleStdout);
  }

  void emitDone() {
    _onDone?.call();
  }

  void emitError(Object error) {
    _onError?.call(error, StackTrace.current);
  }

  @override
  Future<void> disconnect() async {
    disconnected = true;
  }

  @override
  Future<List<SftpEntry>> listDirectory(String path) async {
    return const [];
  }

  @override
  Future<Uint8List> readFileBytes(String path, {int maxBytes = 32768}) async {
    return Uint8List.fromList(const []);
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

  @override
  Future<void> writeFileBytes(
    String path,
    Uint8List data, {
    bool truncate = true,
  }) async {
    // no-op
  }
}
