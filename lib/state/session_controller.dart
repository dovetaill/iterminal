import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:iterminal/models/sftp_entry.dart';
import 'package:iterminal/models/ssh_profile.dart';
import 'package:iterminal/models/terminal_session.dart';
import 'package:iterminal/services/network_monitor.dart';
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
    NetworkMonitor? networkMonitor,
    Duration reconnectBaseDelay = const Duration(seconds: 1),
    Duration reconnectMaxDelay = const Duration(seconds: 20),
    int maxReconnectAttempts = 6,
  })  : _connectionFactory =
            connectionFactory ?? ((profile) => SshConnection(profile: profile)),
        _terminalFactory = terminalFactory ?? _defaultTerminalFactory,
        _terminalControllerFactory =
            terminalControllerFactory ?? TerminalController.new,
        _networkMonitor = networkMonitor ?? ConnectivityPlusNetworkMonitor(),
        _reconnectBaseDelay = reconnectBaseDelay,
        _reconnectMaxDelay = reconnectMaxDelay,
        _maxReconnectAttempts = maxReconnectAttempts {
    _initializeNetworkMonitor();
  }

  final ConnectionFactory _connectionFactory;
  final TerminalFactory _terminalFactory;
  final TerminalControllerFactory _terminalControllerFactory;
  final NetworkMonitor _networkMonitor;
  final Duration _reconnectBaseDelay;
  final Duration _reconnectMaxDelay;
  final int _maxReconnectAttempts;

  final List<TerminalSession> _sessions = <TerminalSession>[];
  final Map<String, SshConnectionAdapter> _connections =
      <String, SshConnectionAdapter>{};
  final Map<String, Timer> _reconnectTimers = <String, Timer>{};
  final Set<String> _closingSessionIds = <String>{};
  final Map<String, int> _connectionEpochs = <String, int>{};

  StreamSubscription<bool>? _networkSubscription;
  int _activeIndex = -1;
  bool _splitView = false;
  int? _secondaryIndex;
  String _searchQuery = '';
  bool _networkOnline = true;
  bool _disposed = false;

  List<TerminalSession> get sessions => List.unmodifiable(_sessions);

  bool get hasSessions => _sessions.isNotEmpty;

  int get activeIndex => _activeIndex;

  bool get isNetworkOnline => _networkOnline;

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
    _notifyListeners();

    final connection = _connectionFactory(profile);
    _attachConnection(session, connection);

    final connected = await _connectSession(session, isReconnect: false);
    if (!connected && !_networkOnline) {
      _scheduleReconnect(
        session,
        reason: session.lastError ?? 'Network unavailable during connect.',
      );
    }

    return session;
  }

  Future<bool> reconnectActiveSession() async {
    final session = activeSession;
    if (session == null) {
      return false;
    }
    return reconnectSession(session.id);
  }

  Future<bool> reconnectSession(String sessionId) async {
    final session = _findSessionById(sessionId);
    if (session == null || _isClosingSession(sessionId)) {
      return false;
    }

    _cancelReconnectTimer(sessionId);
    session.reconnectAttempt = 0;
    session.nextReconnectAt = null;
    session.waitingForNetwork = false;
    _writeSystemLine(session, '==> Manual reconnect requested.');
    _notifyListeners();

    return _performReconnect(sessionId);
  }

  void setActiveIndex(int index) {
    if (index < 0 || index >= _sessions.length || index == _activeIndex) {
      return;
    }
    _activeIndex = index;
    _ensureSecondaryIndex();
    _notifyListeners();
  }

  void activateNextTab() {
    if (_sessions.length < 2) {
      return;
    }
    _activeIndex = (_activeIndex + 1) % _sessions.length;
    _ensureSecondaryIndex();
    _notifyListeners();
  }

  void activatePreviousTab() {
    if (_sessions.length < 2) {
      return;
    }
    _activeIndex = (_activeIndex - 1 + _sessions.length) % _sessions.length;
    _ensureSecondaryIndex();
    _notifyListeners();
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

    _closingSessionIds.add(sessionId);
    _cancelReconnectTimer(sessionId);

    final session = _sessions[index];
    final connection = _connections.remove(session.id);
    _connectionEpochs.remove(session.id);
    await _safeDisconnect(connection);

    _sessions.removeAt(index);
    _closingSessionIds.remove(sessionId);

    if (_sessions.isEmpty) {
      _activeIndex = -1;
      _secondaryIndex = null;
      _splitView = false;
    } else if (_activeIndex >= _sessions.length) {
      _activeIndex = _sessions.length - 1;
    }

    _ensureSecondaryIndex();
    _notifyListeners();
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
      _notifyListeners();
      return;
    }

    _splitView = !_splitView;
    _ensureSecondaryIndex();
    _notifyListeners();
  }

  void setSecondaryIndex(int index) {
    if (!_splitView) {
      return;
    }
    if (index < 0 || index >= _sessions.length || index == _activeIndex) {
      return;
    }
    _secondaryIndex = index;
    _notifyListeners();
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
      _notifyListeners();
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
    _notifyListeners();
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

    _notifyListeners();
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

  @override
  void dispose() {
    _disposed = true;
    _networkSubscription?.cancel();
    _networkSubscription = null;

    for (final timer in _reconnectTimers.values) {
      timer.cancel();
    }
    _reconnectTimers.clear();

    for (final connection in _connections.values) {
      unawaited(_safeDisconnect(connection));
    }
    _connections.clear();

    super.dispose();
  }

  Future<bool> _connectSession(
    TerminalSession session, {
    required bool isReconnect,
  }) async {
    final connection = _connections[session.id];
    if (connection == null) {
      return false;
    }

    final epoch = _connectionEpochs[session.id] ?? 0;
    if (epoch == 0) {
      return false;
    }

    if (_isClosingSession(session.id)) {
      return false;
    }

    if (isReconnect) {
      session.status = SessionStatus.reconnecting;
      _notifyListeners();
    }

    try {
      await connection.connect(
        onStdout: (text) {
          if (!_isCurrentEpoch(session.id, epoch)) {
            return;
          }
          session.terminal.write(text);
          session.appendOutput(text);
        },
        onStderr: (text) {
          if (!_isCurrentEpoch(session.id, epoch)) {
            return;
          }
          session.terminal.write(text);
          session.appendOutput(text);
        },
        onDone: () {
          _handleConnectionDone(sessionId: session.id, epoch: epoch);
        },
        onError: (error, stackTrace) {
          _handleConnectionError(sessionId: session.id, epoch: epoch, error: error);
        },
        onTitleChange: (title) {
          if (!_isCurrentEpoch(session.id, epoch)) {
            return;
          }
          session.runtimeTitle = title;
          _notifyListeners();
        },
      );
    } catch (error) {
      if (!_isCurrentEpoch(session.id, epoch) || _isClosingSession(session.id)) {
        return false;
      }

      session.lastError = '$error';
      session.waitingForNetwork = !_networkOnline;
      session.status = isReconnect ? SessionStatus.reconnecting : SessionStatus.error;
      _writeSystemLine(
        session,
        isReconnect ? '==> Reconnect failed: $error' : '==> Failed: $error',
      );
      _notifyListeners();
      return false;
    }

    if (!_isCurrentEpoch(session.id, epoch) || _isClosingSession(session.id)) {
      return false;
    }

    _cancelReconnectTimer(session.id);
    session.status = SessionStatus.connected;
    session.lastError = null;
    session.hasEverConnected = true;
    session.reconnectAttempt = 0;
    session.waitingForNetwork = false;
    session.nextReconnectAt = null;
    _writeSystemLine(session, isReconnect ? '==> Reconnected.' : '==> Connected.');
    _notifyListeners();
    return true;
  }

  void _handleConnectionDone({
    required String sessionId,
    required int epoch,
  }) {
    if (!_isCurrentEpoch(sessionId, epoch) || _isClosingSession(sessionId)) {
      return;
    }

    final session = _findSessionById(sessionId);
    if (session == null) {
      return;
    }

    session.status = SessionStatus.disconnected;
    session.waitingForNetwork = !_networkOnline;
    session.nextReconnectAt = null;
    _writeSystemLine(
      session,
      _networkOnline
          ? '==> Remote shell exited. Use reconnect to restore session.'
          : '==> Remote shell exited due to network interruption.',
    );

    if (session.hasEverConnected && !_networkOnline) {
      _scheduleReconnect(session, reason: 'Transport closed during offline state.');
      return;
    }

    _notifyListeners();
  }

  void _handleConnectionError({
    required String sessionId,
    required int epoch,
    required Object error,
  }) {
    if (!_isCurrentEpoch(sessionId, epoch) || _isClosingSession(sessionId)) {
      return;
    }

    final session = _findSessionById(sessionId);
    if (session == null) {
      return;
    }

    session.lastError = '$error';
    _writeSystemLine(session, '==> Error: $error');

    if (session.hasEverConnected || session.status == SessionStatus.reconnecting) {
      _scheduleReconnect(session, reason: '$error');
      return;
    }

    session.status = SessionStatus.error;
    _notifyListeners();
  }

  void _scheduleReconnect(
    TerminalSession session, {
    required String reason,
    bool immediate = false,
  }) {
    if (_isClosingSession(session.id)) {
      return;
    }

    _cancelReconnectTimer(session.id);

    if (!_networkOnline) {
      final waitingChanged = !session.waitingForNetwork;
      session.status = SessionStatus.reconnecting;
      session.waitingForNetwork = true;
      session.nextReconnectAt = null;
      if (waitingChanged) {
        _writeSystemLine(
          session,
          '==> Network unavailable. Reconnect will resume when network is back.',
        );
      }
      _notifyListeners();
      return;
    }

    final attempt = session.reconnectAttempt + 1;
    if (attempt > _maxReconnectAttempts) {
      session.status = SessionStatus.error;
      session.waitingForNetwork = false;
      session.nextReconnectAt = null;
      session.lastError = 'Reconnect exhausted. Last reason: $reason';
      _writeSystemLine(
        session,
        '==> Reconnect stopped after $_maxReconnectAttempts attempts.',
      );
      _notifyListeners();
      return;
    }

    final delay = immediate ? Duration.zero : _computeReconnectDelay(attempt);
    session.status = SessionStatus.reconnecting;
    session.reconnectAttempt = attempt;
    session.waitingForNetwork = false;
    session.nextReconnectAt = DateTime.now().add(delay);

    if (delay > Duration.zero) {
      _writeSystemLine(
        session,
        '==> Reconnecting in ${delay.inSeconds}s (attempt $attempt/$_maxReconnectAttempts)...',
      );
    } else {
      _writeSystemLine(
        session,
        '==> Reconnecting now (attempt $attempt/$_maxReconnectAttempts)...',
      );
    }

    _notifyListeners();

    _reconnectTimers[session.id] = Timer(delay, () {
      _reconnectTimers.remove(session.id);
      unawaited(_performReconnect(session.id));
    });
  }

  Future<bool> _performReconnect(String sessionId) async {
    final session = _findSessionById(sessionId);
    if (session == null || _isClosingSession(sessionId)) {
      return false;
    }

    if (!_networkOnline) {
      _scheduleReconnect(
        session,
        reason: 'Network unavailable during reconnect.',
      );
      return false;
    }

    final previous = _connections.remove(sessionId);
    await _safeDisconnect(previous);

    final newConnection = _connectionFactory(session.profile);
    _attachConnection(session, newConnection);

    final connected = await _connectSession(session, isReconnect: true);
    if (!connected && !_isClosingSession(sessionId)) {
      _scheduleReconnect(
        session,
        reason: session.lastError ?? 'Reconnect failed.',
      );
    }

    return connected;
  }

  void _initializeNetworkMonitor() {
    _networkSubscription = _networkMonitor.onOnlineChanged.listen(
      _handleNetworkChanged,
      onError: (_, __) {
        // Keep current state when network monitoring stream fails.
      },
    );

    unawaited(_refreshInitialNetworkState());
  }

  Future<void> _refreshInitialNetworkState() async {
    try {
      final online = await _networkMonitor.isOnline();
      _networkOnline = online;
      _notifyListeners();
    } catch (_) {
      // Fallback to optimistic online state when the platform checker is unavailable.
      _networkOnline = true;
    }
  }

  void _handleNetworkChanged(bool online) {
    final previous = _networkOnline;
    _networkOnline = online;

    if (!online) {
      for (final timer in _reconnectTimers.values) {
        timer.cancel();
      }
      _reconnectTimers.clear();

      for (final session in _sessions) {
        if (session.status == SessionStatus.reconnecting) {
          session.waitingForNetwork = true;
          session.nextReconnectAt = null;
        }
      }

      if (previous != online) {
        _notifyListeners();
      }
      return;
    }

    for (final session in _sessions) {
      if (_isClosingSession(session.id) || !session.hasEverConnected) {
        continue;
      }

      final networkRecovered = !previous && online;
      final shouldReconnect = session.waitingForNetwork ||
          (networkRecovered &&
              (session.status == SessionStatus.reconnecting ||
                  session.status == SessionStatus.disconnected));
      if (shouldReconnect) {
        _scheduleReconnect(
          session,
          reason: previous == online ? 'Network changed.' : 'Network restored.',
          immediate: true,
        );
      }
    }

    _notifyListeners();
  }

  int _attachConnection(
    TerminalSession session,
    SshConnectionAdapter connection,
  ) {
    _connections[session.id] = connection;
    final epoch = (_connectionEpochs[session.id] ?? 0) + 1;
    _connectionEpochs[session.id] = epoch;

    session.terminal.onOutput = connection.write;
    session.terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      connection.resize(
        width,
        height,
        pixelWidth: pixelWidth,
        pixelHeight: pixelHeight,
      );
    };

    return epoch;
  }

  bool _isCurrentEpoch(String sessionId, int epoch) {
    return _connectionEpochs[sessionId] == epoch;
  }

  bool _isClosingSession(String sessionId) {
    return _closingSessionIds.contains(sessionId);
  }

  void _cancelReconnectTimer(String sessionId) {
    final timer = _reconnectTimers.remove(sessionId);
    timer?.cancel();
  }

  Duration _computeReconnectDelay(int attempt) {
    final backoff = _reconnectBaseDelay * (1 << (attempt - 1));
    if (backoff > _reconnectMaxDelay) {
      return _reconnectMaxDelay;
    }
    return backoff;
  }

  Future<void> _safeDisconnect(SshConnectionAdapter? connection) async {
    if (connection == null) {
      return;
    }

    try {
      await connection.disconnect();
    } catch (_) {
      // Ignore cleanup errors from stale/half-closed transport.
    }
  }

  TerminalSession? _findSessionById(String sessionId) {
    for (final session in _sessions) {
      if (session.id == sessionId) {
        return session;
      }
    }
    return null;
  }

  void _notifyListeners() {
    if (_disposed) {
      return;
    }
    notifyListeners();
  }

  void _writeSystemLine(TerminalSession session, String message) {
    final line = '$message\r\n';
    session.terminal.write(line);
    session.appendOutput(line);
  }

  _SessionConnectionPair _resolveSessionAndConnection({String? sessionId}) {
    final session =
        sessionId == null ? activeSession : _findSessionById(sessionId);
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
