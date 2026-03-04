import 'package:flutter_test/flutter_test.dart';
import 'package:iterminal/models/ssh_profile.dart';
import 'package:iterminal/services/secure_store.dart';
import 'package:iterminal/services/secure_vault.dart';
import 'package:iterminal/state/profile_controller.dart';

void main() {
  group('ProfileController', () {
    test('loads default snippets on first run', () async {
      final store = InMemorySecureStore();
      final controller = ProfileController(
        vault: SecureVaultService(store: store),
      );

      await controller.load();

      expect(controller.snippets, isNotEmpty);
    });

    test('persists profile in encrypted vault', () async {
      final store = InMemorySecureStore();
      final vault = SecureVaultService(store: store);
      final controller = ProfileController(vault: vault);
      await controller.load();

      await controller.upsertProfile(
        SSHProfile(
          host: '10.0.0.12',
          port: 22,
          username: 'demo',
          password: 'pw',
          displayName: 'Demo Host',
        ),
        favorite: true,
      );

      final second = ProfileController(vault: vault);
      await second.load();

      expect(second.profiles.length, 1);
      expect(second.favoriteProfiles.length, 1);
      expect(second.profiles.first.host, '10.0.0.12');
    });
  });
}
