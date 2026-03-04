import 'package:iterminal/models/command_snippet.dart';
import 'package:iterminal/models/saved_ssh_profile.dart';

class VaultData {
  VaultData({
    this.accountName,
    List<SavedSshProfile>? profiles,
    List<CommandSnippet>? snippets,
  })  : profiles = profiles ?? <SavedSshProfile>[],
        snippets = snippets ?? <CommandSnippet>[];

  final String? accountName;
  final List<SavedSshProfile> profiles;
  final List<CommandSnippet> snippets;

  static VaultData empty() => VaultData();

  VaultData copyWith({
    String? accountName,
    List<SavedSshProfile>? profiles,
    List<CommandSnippet>? snippets,
    bool clearAccountName = false,
  }) {
    return VaultData(
      accountName: clearAccountName ? null : (accountName ?? this.accountName),
      profiles: profiles ?? this.profiles,
      snippets: snippets ?? this.snippets,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accountName': accountName,
      'profiles': profiles.map((p) => p.toJson()).toList(growable: false),
      'snippets': snippets.map((s) => s.toJson()).toList(growable: false),
    };
  }

  factory VaultData.fromJson(Map<String, dynamic> json) {
    return VaultData(
      accountName: json['accountName'] as String?,
      profiles: (json['profiles'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SavedSshProfile.fromJson)
          .toList(growable: false),
      snippets: (json['snippets'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CommandSnippet.fromJson)
          .toList(growable: false),
    );
  }
}
