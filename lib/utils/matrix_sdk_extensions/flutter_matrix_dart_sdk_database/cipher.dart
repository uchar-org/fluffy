import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:matrix/matrix.dart';

import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/client_manager.dart';

const _passwordStorageKey = 'database_password';
const _maxRetries = 3;
const _retryDelay = Duration(milliseconds: 500);

// Use first_unlock (NOT this_device) to survive device restore/backup
// first_unlock_this_device keys are NOT backed up and lost on device migration
const _writeOptions = IOSOptions(
  accessibility: KeychainAccessibility.first_unlock,
);

Future<String?> getDatabaseCipher() async {
  for (var attempt = 1; attempt <= _maxRetries; attempt++) {
    try {
      // 1. Try reading WITHOUT accessibility filter first
      //    This fixes flutter_secure_storage 9.1.x breaking change where
      //    kSecAttrAccessible is now applied on reads, causing keys stored
      //    with different accessibility to be invisible.
      const storageNoFilter = FlutterSecureStorage();
      var password = await storageNoFilter.read(key: _passwordStorageKey);

      if (password != null) {
        // 2. Migrate: re-write with correct accessibility for future reads
        //    and to ensure key survives device backup/restore
        const storageWithOptions = FlutterSecureStorage(iOptions: _writeOptions);
        await storageWithOptions.delete(key: _passwordStorageKey);
        await storageWithOptions.write(
          key: _passwordStorageKey,
          value: password,
          iOptions: _writeOptions,
        );
        Logs().i('Migrated database cipher key to first_unlock accessibility');
        return password;
      }

      // 3. No existing key - generate new one
      final rng = Random.secure();
      final list = Uint8List(32);
      list.setAll(0, Iterable.generate(32, (i) => rng.nextInt(256)));
      password = base64UrlEncode(list);

      const storageWithOptions = FlutterSecureStorage(iOptions: _writeOptions);
      await storageWithOptions.write(
        key: _passwordStorageKey,
        value: password,
        iOptions: _writeOptions,
      );

      // Verify write succeeded
      password = await storageWithOptions.read(key: _passwordStorageKey);
      if (password != null) return password;

      throw MissingPluginException('Keychain write verification failed');
    } on MissingPluginException catch (e) {
      Logs().w('Keychain access attempt $attempt failed (not supported)', e);
      if (attempt < _maxRetries) {
        await Future.delayed(_retryDelay);
        continue;
      }
      // Platform doesn't support secure storage - proceed without encryption
      Logs().w('Database encryption is not supported on this platform', e);
      _sendNoEncryptionWarning(e);
      return null;
    } catch (e, s) {
      Logs().w('Keychain access attempt $attempt failed', e, s);
      if (attempt < _maxRetries) {
        await Future.delayed(_retryDelay);
        continue;
      }
      // All retries exhausted - DO NOT delete key, just warn and return null
      Logs().e('All keychain access attempts failed', e, s);
      _sendNoEncryptionWarning(e);
      return null;
    }
  }

  return null;
}

void _sendNoEncryptionWarning(Object exception) async {
  final isStored = AppSettings.noEncryptionWarningShown.value;

  if (isStored == true) return;

  final l10n = await lookupL10n(PlatformDispatcher.instance.locale);
  ClientManager.sendInitNotification(
    l10n.noDatabaseEncryption,
    exception.toString(),
  );

  await AppSettings.noEncryptionWarningShown.setItem(true);
}
