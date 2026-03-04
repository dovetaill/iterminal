class SSHProfile {
  SSHProfile({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    this.displayName,
  });

  final String host;
  final int port;
  final String username;
  final String password;
  final String? displayName;

  String get title {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return '$username@$host:$port';
  }
}
