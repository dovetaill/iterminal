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
  final StringBuffer outputBuffer = StringBuffer();

  String get title {
    final title = runtimeTitle?.trim();
    if (title != null && title.isNotEmpty) {
      return title;
    }
    return profile.title;
  }

  void appendOutput(String text) {
    outputBuffer.write(text);
  }

  String get outputText => outputBuffer.toString();
}
