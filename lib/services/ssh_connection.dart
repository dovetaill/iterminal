import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:iterminal/models/ssh_profile.dart';

typedef OnStdout = void Function(String text);
typedef OnStderr = void Function(String text);
typedef OnDone = void Function();
typedef OnError = void Function(Object error, StackTrace stackTrace);

typedef OnTitleChange = void Function(String title);

abstract class SshConnectionAdapter {
  Future<void> connect({
    required OnStdout onStdout,
    required OnStderr onStderr,
    required OnDone onDone,
    required OnError onError,
    OnTitleChange? onTitleChange,
  });

  void write(String data);

  void resize(
    int width,
    int height, {
    int pixelWidth,
    int pixelHeight,
  });

  Future<void> disconnect();
}

class SshConnection implements SshConnectionAdapter {
  SshConnection({required this.profile});

  final SSHProfile profile;

  SSHClient? _client;
  SSHSession? _shell;
  StreamSubscription<Uint8List>? _stdoutSub;
  StreamSubscription<Uint8List>? _stderrSub;

  bool _isClosed = false;

  @override
  Future<void> connect({
    required OnStdout onStdout,
    required OnStderr onStderr,
    required OnDone onDone,
    required OnError onError,
    OnTitleChange? onTitleChange,
  }) async {
    try {
      final socket = await SSHSocket.connect(profile.host, profile.port);
      final client = SSHClient(
        socket,
        username: profile.username,
        onPasswordRequest: () => profile.password,
        onVerifyHostKey: (_, __) => true,
      );
      await client.authenticated;

      final shell = await client.shell();
      _client = client;
      _shell = shell;

      _stdoutSub = shell.stdout.listen(
        (chunk) {
          final text = utf8.decode(chunk, allowMalformed: true);
          onStdout(text);

          // Window title updates are often emitted as escape sequences.
          final title = _tryExtractTitle(text);
          if (title != null) {
            onTitleChange?.call(title);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          onError(error, stackTrace);
        },
      );

      _stderrSub = shell.stderr.listen(
        (chunk) {
          onStderr(utf8.decode(chunk, allowMalformed: true));
        },
        onError: (Object error, StackTrace stackTrace) {
          onError(error, stackTrace);
        },
      );

      unawaited(
        shell.done.then((_) {
          if (!_isClosed) {
            onDone();
          }
        }).catchError((Object error, StackTrace stackTrace) {
          onError(error, stackTrace);
        }),
      );
    } catch (error, stackTrace) {
      onError(error, stackTrace);
      rethrow;
    }
  }

  @override
  void write(String data) {
    if (_isClosed) {
      return;
    }
    final shell = _shell;
    if (shell == null) {
      return;
    }
    shell.write(Uint8List.fromList(utf8.encode(data)));
  }

  @override
  void resize(
    int width,
    int height, {
    int pixelWidth = 0,
    int pixelHeight = 0,
  }) {
    if (_isClosed) {
      return;
    }
    final shell = _shell;
    if (shell == null) {
      return;
    }

    shell.resizeTerminal(
      width,
      height,
      pixelWidth,
      pixelHeight,
    );
  }

  @override
  Future<void> disconnect() async {
    _isClosed = true;

    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();

    _shell?.close();
    _client?.close();

    final client = _client;
    if (client != null) {
      await client.done;
    }
  }

  String? _tryExtractTitle(String text) {
    const marker = '\x1B]0;';
    final start = text.indexOf(marker);
    if (start < 0) {
      return null;
    }

    final contentStart = start + marker.length;
    final bellEnd = text.indexOf('\x07', contentStart);
    final stEnd = text.indexOf('\x1B\\', contentStart);

    var end = -1;
    if (bellEnd >= 0 && stEnd >= 0) {
      end = bellEnd < stEnd ? bellEnd : stEnd;
    } else if (bellEnd >= 0) {
      end = bellEnd;
    } else if (stEnd >= 0) {
      end = stEnd;
    }

    if (end < 0 || end <= contentStart) {
      return null;
    }

    final title = text.substring(contentStart, end).trim();
    return title.isEmpty ? null : title;
  }
}
