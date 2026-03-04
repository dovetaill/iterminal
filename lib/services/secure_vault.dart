import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:iterminal/models/vault_data.dart';
import 'package:iterminal/services/secure_store.dart';

class SecureVaultService {
  SecureVaultService({
    required SecureStore store,
    Cipher? cipher,
  })  : _store = store,
        _cipher = cipher ?? AesGcm.with256bits();

  final SecureStore _store;
  final Cipher _cipher;

  static const String _masterKeyStorageKey = 'iterminal.vault.masterKey.v1';
  static const String _payloadStorageKey = 'iterminal.vault.payload.v1';

  Future<VaultData> load() async {
    final payloadText = await _store.read(_payloadStorageKey);
    if (payloadText == null || payloadText.isEmpty) {
      return VaultData.empty();
    }

    try {
      final payload = jsonDecode(payloadText) as Map<String, dynamic>;
      final nonce = base64Decode(payload['nonce'] as String);
      final cipherText = base64Decode(payload['cipherText'] as String);
      final macBytes = base64Decode(payload['mac'] as String);

      final secretBox = SecretBox(
        cipherText,
        nonce: nonce,
        mac: Mac(macBytes),
      );

      final secretKey = await _readOrCreateMasterKey();
      final clearBytes = await _cipher.decrypt(secretBox, secretKey: secretKey);
      final clearText = utf8.decode(clearBytes, allowMalformed: true);
      final data = jsonDecode(clearText) as Map<String, dynamic>;
      return VaultData.fromJson(data);
    } catch (_) {
      return VaultData.empty();
    }
  }

  Future<void> save(VaultData data) async {
    final secretKey = await _readOrCreateMasterKey();
    final clearText = jsonEncode(data.toJson());
    final nonce = _randomBytes(12);
    final secretBox = await _cipher.encrypt(
      utf8.encode(clearText),
      secretKey: secretKey,
      nonce: nonce,
    );

    final payload = {
      'nonce': base64Encode(secretBox.nonce),
      'cipherText': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    };

    await _store.write(_payloadStorageKey, jsonEncode(payload));
  }

  Future<void> clear() async {
    await _store.delete(_payloadStorageKey);
    await _store.delete(_masterKeyStorageKey);
  }

  Future<SecretKey> _readOrCreateMasterKey() async {
    final existing = await _store.read(_masterKeyStorageKey);
    if (existing != null && existing.isNotEmpty) {
      return SecretKey(base64Decode(existing));
    }

    final bytes = _randomBytes(32);
    await _store.write(_masterKeyStorageKey, base64Encode(bytes));
    return SecretKey(bytes);
  }

  Uint8List _randomBytes(int length) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return Uint8List.fromList(bytes);
  }
}
