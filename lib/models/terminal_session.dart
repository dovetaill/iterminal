import 'dart:collection';

import 'package:iterminal/models/ssh_profile.dart';
import 'package:xterm/xterm.dart';

enum SessionStatus {
  connecting,
  connected,
  disconnected,
  error,
}

class TerminalSession {
  TerminalSession({
    required this.id,
    required this.profile,
    required this.terminal,
    required this.controller,
    this.status = SessionStatus.connecting,
  });

  final String id;
  final SSHProfile profile;
  final Terminal terminal;
  final TerminalController controller;

  SessionStatus status;
  String? runtimeTitle;
  String? lastError;
  int searchHits = 0;
  int searchCursor = 0;
  static const int _maxOutputChars = 500000;
  final ListQueue<String> _outputChunks = ListQueue<String>();
  int _outputSize = 0;

  String get title {
    final title = runtimeTitle?.trim();
    if (title != null && title.isNotEmpty) {
      return title;
    }
    return profile.title;
  }

  void appendOutput(String text) {
    if (text.isEmpty) {
      return;
    }

    _outputChunks.addLast(text);
    _outputSize += text.length;

    while (_outputSize > _maxOutputChars && _outputChunks.isNotEmpty) {
      final removed = _outputChunks.removeFirst();
      _outputSize -= removed.length;
    }
  }

  String get outputText => _outputChunks.join();
}
