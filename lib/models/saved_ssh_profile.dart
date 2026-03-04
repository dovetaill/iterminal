import 'package:iterminal/models/ssh_profile.dart';

class SavedSshProfile {
  SavedSshProfile({
    required this.id,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    this.displayName,
    this.favorite = false,
    DateTime? createdAt,
    this.lastUsedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String host;
  final int port;
  final String username;
  final String password;
  final String? displayName;
  final bool favorite;
  final DateTime createdAt;
  final DateTime? lastUsedAt;

  String get title {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return '$username@$host:$port';
  }

  SSHProfile toSshProfile() {
    return SSHProfile(
      host: host,
      port: port,
      username: username,
      password: password,
      displayName: displayName,
    );
  }

  SavedSshProfile copyWith({
    String? id,
    String? host,
    int? port,
    String? username,
    String? password,
    String? displayName,
    bool? favorite,
    DateTime? createdAt,
    DateTime? lastUsedAt,
  }) {
    return SavedSshProfile(
      id: id ?? this.id,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      displayName: displayName ?? this.displayName,
      favorite: favorite ?? this.favorite,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'host': host,
      'port': port,
      'username': username,
      'password': password,
      'displayName': displayName,
      'favorite': favorite,
      'createdAt': createdAt.toIso8601String(),
      'lastUsedAt': lastUsedAt?.toIso8601String(),
    };
  }

  factory SavedSshProfile.fromJson(Map<String, dynamic> json) {
    return SavedSshProfile(
      id: json['id'] as String,
      host: json['host'] as String,
      port: json['port'] as int,
      username: json['username'] as String,
      password: json['password'] as String? ?? '',
      displayName: json['displayName'] as String?,
      favorite: json['favorite'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      lastUsedAt: DateTime.tryParse(json['lastUsedAt'] as String? ?? ''),
    );
  }
}
