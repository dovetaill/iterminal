import 'dart:math';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:iterminal/models/sftp_entry.dart';
import 'package:iterminal/models/ssh_profile.dart';
import 'package:iterminal/models/terminal_session.dart';
import 'package:iterminal/services/ssh_connection.dart';
import 'package:xterm/xterm.dart';

typedef ConnectionFactory = SshConnectionAdapter Function(SSHProfile profile);
typedef TerminalFactory = Terminal Function();
typedef TerminalControllerFactory = TerminalController Function();

class SessionController extends ChangeNotifier {
  SessionController({
    ConnectionFactory? connectionFactory,
    TerminalFactory? terminalFactory,
    TerminalControllerFactory? terminalControllerFactory,
  })  : _connectionFactory =
            connectionFactory ?? ((profile) => SshConnection(profile: profile)),
        _terminalFactory = terminalFactory ?? _defaultTerminalFactory,
        _terminalControllerFactory =
            terminalControllerFactory ?? TerminalController.new;

  final ConnectionFactory _connectionFactory;
  final TerminalFactory _terminalFactory;
  final TerminalControllerFactory _terminalControllerFactory;

  final List<TerminalSession> _sessions = <TerminalSession>[];
  final Map<String, SshConnectionAdapter> _connections =
      <String, SshConnectionAdapter>{};

  int _activeIndex = -1;
  bool _splitView = false;
  int? _secondaryIndex;
  String _searchQuery = '';

  List<TerminalSession> get sessions => List.unmodifiable(_sessions);

  bool get hasSessions => _sessions.isNotEmpty;

  int get activeIndex => _activeIndex;

  TerminalSession? get activeSession {
    if (_activeIndex < 0 || _activeIndex >= _sessions.length) {
      return null;
    }
    return _sessions[_activeIndex];
  }

  bool get splitView => _splitView;

  int? get secondaryIndex => _secondaryIndex;

  TerminalSession? get secondarySession {
    if (!_splitView) {
      return null;
    }

    final index = _secondaryIndex;
    if (index == null || index < 0 || index >= _sessions.length) {
      return null;
    }

    if (index == _activeIndex) {
      return null;
    }

    return _sessions[index];
  }

  String get searchQuery => _searchQuery;

  Future<TerminalSession> connect(SSHProfile profile) async {
    final session = TerminalSession(
      id: _nextId(),
      profile: profile,
      terminal: _terminalFactory(),
      controller: _terminalControllerFactory(),
      status: SessionStatus.connecting,
    );

    _sessions.add(session);
    _activeIndex = _sessions.length - 1;

    _writeSystemLine(session,
        '==> Connecting to ${profile.username}@${profile.host}:${profile.port}');

    _ensureSecondaryIndex();
    notifyListeners();

    final connection = _connectionFactory(profile);
    _connections[session.id] = connection;

    session.terminal.onOutput = connection.write;
    session.terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      connection.resize(
        width,
        height,
        pixelWidth: pixelWidth,
        pixelHeight: pixelHeight,
      );
    };

    try {
      await connection.connect(
        onStdout: (text) {
          session.terminal.write(text);
          session.appendOutput(text);
        },
        onStderr: (text) {
          session.terminal.write(text);
          session.appendOutput(text);
        },
        onDone: () {
          session.status = SessionStatus.disconnected;
          _writeSystemLine(session, '==> Remote shell exited.');
          notifyListeners();
        },
        onError: (error, stackTrace) {
          session.status = SessionStatus.error;
          session.lastError = '$error';
          _writeSystemLine(session, '==> Error: $error');
          notifyListeners();
        },
        onTitleChange: (title) {
          session.runtimeTitle = title;
          notifyListeners();
        },
      );

      session.status = SessionStatus.connected;
      _writeSystemLine(session, '==> Connected.');
    } catch (error) {
      session.status = SessionStatus.error;
      session.lastError = '$error';
      _writeSystemLine(session, '==> Failed: $error');
    }

    notifyListeners();
    return session;
  }

  void setActiveIndex(int index) {
    if (index < 0 || index >= _sessions.length || index == _activeIndex) {
      return;
    }
    _activeIndex = index;
    _ensureSecondaryIndex();
    notifyListeners();
  }

  void activateNextTab() {
    if (_sessions.length < 2) {
      return;
    }
    _activeIndex = (_activeIndex + 1) % _sessions.length;
    _ensureSecondaryIndex();
    notifyListeners();
  }

  void activatePreviousTab() {
    if (_sessions.length < 2) {
      return;
    }
    _activeIndex = (_activeIndex - 1 + _sessions.length) % _sessions.length;
    _ensureSecondaryIndex();
    notifyListeners();
  }

  Future<void> closeActiveSession() async {
    final session = activeSession;
    if (session == null) {
      return;
    }
    await closeSession(session.id);
  }

  Future<void> closeSession(String sessionId) async {
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index == -1) {
      return;
    }

    final session = _sessions[index];
    final connection = _connections.remove(session.id);
    await connection?.disconnect();

    _sessions.removeAt(index);

    if (_sessions.isEmpty) {
      _activeIndex = -1;
      _secondaryIndex = null;
      _splitView = false;
    } else if (_activeIndex >= _sessions.length) {
      _activeIndex = _sessions.length - 1;
    }

    _ensureSecondaryIndex();
    notifyListeners();
  }

  Future<void> closeAllSessions() async {
    final ids = _sessions.map((e) => e.id).toList(growable: false);
    for (final id in ids) {
      await closeSession(id);
    }
  }

  void toggleSplitView() {
    if (_sessions.length < 2) {
      _splitView = false;
      _secondaryIndex = null;
      notifyListeners();
      return;
    }

    _splitView = !_splitView;
    _ensureSecondaryIndex();
    notifyListeners();
  }

  void setSecondaryIndex(int index) {
    if (!_splitView) {
      return;
    }
    if (index < 0 || index >= _sessions.length || index == _activeIndex) {
      return;
    }
    _secondaryIndex = index;
    notifyListeners();
  }

  int searchInActiveSession(String query) {
    _searchQuery = query;
    final session = activeSession;
    if (session == null) {
      return 0;
    }

    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      session.searchHits = 0;
      session.searchCursor = 0;
      notifyListeners();
      return 0;
    }

    final output = session.outputText.toLowerCase();
    var cursor = 0;
    var count = 0;

    while (true) {
      final match = output.indexOf(normalized, cursor);
      if (match < 0) {
        break;
      }
      count += 1;
      cursor = match + normalized.length;
    }

    session.searchHits = count;
    session.searchCursor = count > 0 ? 1 : 0;
    notifyListeners();
    return count;
  }

  int moveSearchCursor({required bool forward}) {
    final session = activeSession;
    if (session == null || session.searchHits == 0) {
      return 0;
    }

    if (forward) {
      session.searchCursor += 1;
      if (session.searchCursor > session.searchHits) {
        session.searchCursor = 1;
      }
    } else {
      session.searchCursor -= 1;
      if (session.searchCursor <= 0) {
        session.searchCursor = session.searchHits;
      }
    }

    notifyListeners();
    return session.searchCursor;
  }

  Future<void> copyActiveSelection() async {
    final session = activeSession;
    if (session == null) {
      return;
    }
    await copySelectionFromSession(session);
  }

  Future<void> copySelectionFromSession(TerminalSession session) async {
    final selection = session.controller.selection;
    if (selection == null) {
      return;
    }

    final text = session.terminal.buffer.getText(selection);
    await Clipboard.setData(ClipboardData(text: text));
    session.controller.clearSelection();
  }

  Future<void> pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (text == null || text.isEmpty) {
      return;
    }

    activeSession?.terminal.paste(text);
  }

  void pasteToSession(TerminalSession session, String text) {
    if (text.isEmpty) {
      return;
    }
    session.terminal.paste(text);
  }

  Future<List<SftpEntry>> listDirectory(String path,
      {String? sessionId}) async {
    final pair = _resolveSessionAndConnection(sessionId: sessionId);
    return await pair.connection.listDirectory(path);
  }

  Future<String> readRemoteTextFile(
    String path, {
    String? sessionId,
    int maxBytes = 32768,
  }) async {
    final pair = _resolveSessionAndConnection(sessionId: sessionId);
    final bytes = await pair.connection.readFileBytes(path, maxBytes: maxBytes);
    return utf8.decode(bytes, allowMalformed: true);
  }

  Future<void> writeRemoteTextFile(
    String path,
    String content, {
    String? sessionId,
    bool truncate = true,
  }) async {
    final pair = _resolveSessionAndConnection(sessionId: sessionId);
    final bytes = Uint8List.fromList(utf8.encode(content));
    await pair.connection.writeFileBytes(path, bytes, truncate: truncate);
  }

  void _writeSystemLine(TerminalSession session, String message) {
    final line = '$message\r\n';
    session.terminal.write(line);
    session.appendOutput(line);
  }

  _SessionConnectionPair _resolveSessionAndConnection({String? sessionId}) {
    final session = sessionId == null
        ? activeSession
        : _sessions.firstWhere((item) => item.id == sessionId);
    if (session == null) {
      throw StateError('No active session');
    }

    final connection = _connections[session.id];
    if (connection == null) {
      throw StateError('Session connection not found');
    }

    return _SessionConnectionPair(connection: connection);
  }

  void _ensureSecondaryIndex() {
    if (!_splitView || _sessions.length < 2) {
      _secondaryIndex = null;
      return;
    }

    final candidate = _secondaryIndex;
    if (candidate != null &&
        candidate >= 0 &&
        candidate < _sessions.length &&
        candidate != _activeIndex) {
      return;
    }

    for (var i = 0; i < _sessions.length; i++) {
      if (i != _activeIndex) {
        _secondaryIndex = i;
        return;
      }
    }

    _secondaryIndex = null;
  }

  String _nextId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final salt = Random().nextInt(1 << 32);
    return '$now-$salt';
  }

  static Terminal _defaultTerminalFactory() {
    return Terminal(
      maxLines: 20000,
      platform: _targetPlatform(),
    );
  }

  static TerminalTargetPlatform _targetPlatform() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return TerminalTargetPlatform.android;
      case TargetPlatform.iOS:
        return TerminalTargetPlatform.ios;
      case TargetPlatform.fuchsia:
        return TerminalTargetPlatform.fuchsia;
      case TargetPlatform.linux:
        return TerminalTargetPlatform.linux;
      case TargetPlatform.macOS:
        return TerminalTargetPlatform.macos;
      case TargetPlatform.windows:
        return TerminalTargetPlatform.windows;
    }
  }
}

class _SessionConnectionPair {
  const _SessionConnectionPair({
    required this.connection,
  });

  final SshConnectionAdapter connection;
}
