import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:iterminal/models/command_snippet.dart';
import 'package:iterminal/models/saved_ssh_profile.dart';
import 'package:iterminal/models/ssh_profile.dart';
import 'package:iterminal/models/vault_data.dart';
import 'package:iterminal/services/secure_vault.dart';

class ProfileController extends ChangeNotifier {
  ProfileController({required SecureVaultService vault}) : _vault = vault;

  final SecureVaultService _vault;

  VaultData _data = VaultData.empty();
  bool _loaded = false;
  bool _saving = false;
  String? _lastError;

  bool get loaded => _loaded;
  bool get saving => _saving;
  String? get lastError => _lastError;

  String? get accountName => _data.accountName;
  List<SavedSshProfile> get profiles => List.unmodifiable(_data.profiles);
  List<SavedSshProfile> get favoriteProfiles => List.unmodifiable(
        _data.profiles.where((profile) => profile.favorite),
      );
  List<CommandSnippet> get snippets => List.unmodifiable(_data.snippets);

  Future<void> load() async {
    _data = await _vault.load();
    _loaded = true;

    if (_data.snippets.isEmpty) {
      _data = _data.copyWith(
        snippets: _defaultSnippets(),
      );
      await _persist();
    }

    notifyListeners();
  }

  Future<void> setAccountName(String? value) async {
    final normalized = value?.trim();
    _data = _data.copyWith(
      accountName:
          (normalized == null || normalized.isEmpty) ? null : normalized,
      clearAccountName: normalized == null || normalized.isEmpty,
    );
    await _persistAndNotify();
  }

  Future<SavedSshProfile> upsertProfile(
    SSHProfile profile, {
    String? existingId,
    bool favorite = false,
  }) async {
    final all = _data.profiles.toList(growable: true);
    final index = existingId == null
        ? -1
        : all.indexWhere((element) => element.id == existingId);

    if (index >= 0) {
      final current = all[index];
      all[index] = current.copyWith(
        host: profile.host,
        port: profile.port,
        username: profile.username,
        password: profile.password,
        displayName: profile.displayName,
        favorite: favorite,
        lastUsedAt: DateTime.now(),
      );
      _data = _data.copyWith(profiles: all);
      await _persistAndNotify();
      return all[index];
    }

    final created = SavedSshProfile(
      id: _nextId(),
      host: profile.host,
      port: profile.port,
      username: profile.username,
      password: profile.password,
      displayName: profile.displayName,
      favorite: favorite,
      lastUsedAt: DateTime.now(),
    );
    all.add(created);
    _data = _data.copyWith(profiles: all);
    await _persistAndNotify();
    return created;
  }

  Future<void> removeProfile(String profileId) async {
    final all =
        _data.profiles.where((profile) => profile.id != profileId).toList();
    _data = _data.copyWith(profiles: all);
    await _persistAndNotify();
  }

  Future<void> setProfileFavorite(String profileId, bool favorite) async {
    final all = _data.profiles
        .map(
          (profile) => profile.id == profileId
              ? profile.copyWith(favorite: favorite)
              : profile,
        )
        .toList(growable: false);
    _data = _data.copyWith(profiles: all);
    await _persistAndNotify();
  }

  Future<void> markProfileUsed(String profileId) async {
    final all = _data.profiles
        .map(
          (profile) => profile.id == profileId
              ? profile.copyWith(lastUsedAt: DateTime.now())
              : profile,
        )
        .toList(growable: false);
    _data = _data.copyWith(profiles: all);
    await _persistAndNotify();
  }

  Future<CommandSnippet> upsertSnippet({
    String? existingId,
    required String name,
    required String command,
    bool favorite = false,
  }) async {
    final normalizedName = name.trim();
    final normalizedCommand = command.trim();
    final all = _data.snippets.toList(growable: true);
    final now = DateTime.now();
    final index = existingId == null
        ? -1
        : all.indexWhere((snippet) => snippet.id == existingId);

    if (index >= 0) {
      final updated = all[index].copyWith(
        name: normalizedName,
        command: normalizedCommand,
        favorite: favorite,
        updatedAt: now,
      );
      all[index] = updated;
      _data = _data.copyWith(snippets: all);
      await _persistAndNotify();
      return updated;
    }

    final created = CommandSnippet(
      id: _nextId(),
      name: normalizedName,
      command: normalizedCommand,
      favorite: favorite,
      createdAt: now,
      updatedAt: now,
    );
    all.add(created);
    _data = _data.copyWith(snippets: all);
    await _persistAndNotify();
    return created;
  }

  Future<void> removeSnippet(String snippetId) async {
    final all =
        _data.snippets.where((snippet) => snippet.id != snippetId).toList();
    _data = _data.copyWith(snippets: all);
    await _persistAndNotify();
  }

  Future<void> setSnippetFavorite(String snippetId, bool favorite) async {
    final now = DateTime.now();
    final all = _data.snippets
        .map(
          (snippet) => snippet.id == snippetId
              ? snippet.copyWith(favorite: favorite, updatedAt: now)
              : snippet,
        )
        .toList(growable: false);
    _data = _data.copyWith(snippets: all);
    await _persistAndNotify();
  }

  Future<void> _persistAndNotify() async {
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    _saving = true;
    _lastError = null;
    notifyListeners();
    try {
      await _vault.save(_data);
    } catch (error) {
      _lastError = '$error';
    } finally {
      _saving = false;
    }
  }

  List<CommandSnippet> _defaultSnippets() {
    return [
      CommandSnippet(
        id: _nextId(),
        name: 'System Info',
        command: 'uname -a && uptime',
      ),
      CommandSnippet(
        id: _nextId(),
        name: 'Disk Usage',
        command: 'df -h',
      ),
      CommandSnippet(
        id: _nextId(),
        name: 'Docker Status',
        command: 'docker ps',
      ),
    ];
  }

  String _nextId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final salt = Random().nextInt(1 << 32);
    return '$now-$salt';
  }
}
