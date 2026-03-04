import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:iterminal/models/sftp_entry.dart';
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

  Future<List<SftpEntry>> listDirectory(String path);

  Future<Uint8List> readFileBytes(
    String path, {
    int maxBytes,
  });

  Future<void> writeFileBytes(
    String path,
    Uint8List data, {
    bool truncate,
  });

  Future<void> disconnect();
}

class SshConnection implements SshConnectionAdapter {
  SshConnection({required this.profile});

  final SSHProfile profile;

  SSHClient? _client;
  SSHSession? _shell;
  SftpClient? _sftp;
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
    _isClosed = false;
    var doneReported = false;
    void reportDone() {
      if (_isClosed || doneReported) {
        return;
      }
      doneReported = true;
      onDone();
    }

    try {
      final socket = await SSHSocket.connect(profile.host, profile.port)
          .timeout(const Duration(seconds: 15));
      final client = SSHClient(
        socket,
        username: profile.username,
        onPasswordRequest: () => profile.password,
        onVerifyHostKey: (_, __) => true,
        keepAliveInterval: const Duration(seconds: 15),
      );
      await client.authenticated;

      final shell = await client.shell();
      _client = client;
      _shell = shell;

      _stdoutSub = shell.stdout.listen(
        (chunk) {
          final text = utf8.decode(chunk, allowMalformed: true);
          onStdout(text);

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
          reportDone();
        }).catchError((Object error, StackTrace stackTrace) {
          onError(error, stackTrace);
        }),
      );

      unawaited(
        client.done.then((_) {
          reportDone();
        }).catchError((Object error, StackTrace stackTrace) {
          onError(error, stackTrace);
          reportDone();
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
  Future<List<SftpEntry>> listDirectory(String path) async {
    final sftp = await _ensureSftp();
    final names = await sftp.listdir(path);
    final entries = names
        .where((item) => item.filename != '.' && item.filename != '..')
        .map(
          (item) => SftpEntry(
            path: _joinPath(path, item.filename),
            name: item.filename,
            longname: item.longname,
            isDirectory: item.attr.isDirectory,
            size: item.attr.size,
            modifiedAtEpochSeconds: item.attr.modifyTime,
          ),
        )
        .toList(growable: false);

    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  @override
  Future<Uint8List> readFileBytes(
    String path, {
    int maxBytes = 32768,
  }) async {
    final sftp = await _ensureSftp();
    final file = await sftp.open(path);
    try {
      return await file.readBytes(length: maxBytes);
    } finally {
      await file.close();
    }
  }

  @override
  Future<void> writeFileBytes(
    String path,
    Uint8List data, {
    bool truncate = true,
  }) async {
    final sftp = await _ensureSftp();
    final mode = truncate
        ? SftpFileOpenMode.create |
            SftpFileOpenMode.write |
            SftpFileOpenMode.truncate
        : SftpFileOpenMode.create |
            SftpFileOpenMode.write |
            SftpFileOpenMode.append;
    final file = await sftp.open(path, mode: mode);
    try {
      await file.writeBytes(data);
    } finally {
      await file.close();
    }
  }

  @override
  Future<void> disconnect() async {
    _isClosed = true;

    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();

    _sftp?.close();
    _shell?.close();
    _client?.close();

    final client = _client;
    if (client != null) {
      await client.done;
    }
  }

  Future<SftpClient> _ensureSftp() async {
    final existing = _sftp;
    if (existing != null) {
      return existing;
    }

    final client = _client;
    if (client == null || _isClosed) {
      throw StateError('SSH connection is not ready');
    }

    final created = await client.sftp();
    _sftp = created;
    return created;
  }

  String _joinPath(String base, String name) {
    if (base.isEmpty || base == '/') {
      return '/$name';
    }
    if (base.endsWith('/')) {
      return '$base$name';
    }
    return '$base/$name';
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
