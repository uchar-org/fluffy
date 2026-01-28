import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:matrix/matrix.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:universal_html/html.dart' as html;

import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/client_manager.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'cipher.dart';

import 'sqlcipher_stub.dart'
    if (dart.library.io) 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';

/// Thrown when encrypted database exists but encryption key is unavailable.
/// This typically happens when iOS keychain data is lost (device restore, etc.)
/// but database file remains.
class DatabaseKeyLostException implements Exception {
  final String path;
  DatabaseKeyLostException(this.path);

  @override
  String toString() =>
      'DatabaseKeyLostException: Encrypted database exists at $path but encryption key is unavailable';
}

Future<DatabaseApi> flutterMatrixSdkDatabaseBuilder(String clientName) async {
  MatrixSdkDatabase? database;
  try {
    database = await _constructDatabase(clientName);
    await database.open();
    return database;
  } on DatabaseKeyLostException catch (e) {
    // Encryption key lost but database exists - notify user and delete DB
    // so they can re-login. This is better than crashing with "file is not a database".
    Logs().e('Database key lost, deleting database for recovery', e);

    try {
      final l10n = await lookupL10n(PlatformDispatcher.instance.locale);
      ClientManager.sendInitNotification(
        l10n.databaseKeyLost,
        l10n.databaseKeyLostSubtitle,
      );
    } catch (notifError, s) {
      Logs().e('Unable to send key lost notification', notifError, s);
    }

    // Delete the orphaned encrypted database file
    final dbFile = File(e.path);
    if (await dbFile.exists()) {
      await dbFile.delete();
      Logs().i('Deleted orphaned encrypted database at ${e.path}');
    }

    // Retry - will create fresh unencrypted database
    return flutterMatrixSdkDatabaseBuilder(clientName);
  } catch (e, s) {
    Logs().wtf('Unable to construct database!', e, s);

    try {
      // Send error notification:
      final l10n = await lookupL10n(PlatformDispatcher.instance.locale);
      ClientManager.sendInitNotification(l10n.initAppError, e.toString());
    } catch (e, s) {
      Logs().e('Unable to send error notification', e, s);
    }

    // Try to delete database so that it can created again on next init:
    database?.delete().catchError(
      (e, s) => Logs().wtf(
        'Unable to delete database, after failed construction',
        e,
        s,
      ),
    );

    // Delete database file:
    if (!kIsWeb) {
      final dbFile = File(await _getDatabasePath(clientName));
      if (await dbFile.exists()) await dbFile.delete();
    }

    rethrow;
  }
}

Future<MatrixSdkDatabase> _constructDatabase(String clientName) async {
  if (kIsWeb) {
    html.window.navigator.storage?.persist();
    return await MatrixSdkDatabase.init(clientName);
  }

  final cipher = await getDatabaseCipher();
  final path = await _getDatabasePath(clientName);

  // Key loss detection: if encrypted DB exists but cipher key is unavailable,
  // we cannot open it. This typically happens after iOS device restore where
  // keychain data is lost but app files remain.
  final dbFile = File(path);
  final dbExists = await dbFile.exists();

  if (cipher == null && dbExists) {
    Logs().e(
      'Database file exists at $path but encryption key is unavailable. '
      'This may happen after device restore or keychain corruption.',
    );
    throw DatabaseKeyLostException(path);
  }

  Directory? fileStorageLocation;
  try {
    fileStorageLocation = await getTemporaryDirectory();
  } on MissingPlatformDirectoryException catch (_) {
    Logs().w(
      'No temporary directory for file cache available on this platform.',
    );
  }

  // fix dlopen for old Android
  await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
  // import the SQLite / SQLCipher shared objects / dynamic libraries
  final factory = createDatabaseFactoryFfi(
    ffiInit: SQfLiteEncryptionHelper.ffiInit,
  );

  // required for [getDatabasesPath]
  databaseFactory = factory;

  // migrate from potential previous SQLite database path to current one
  await _migrateLegacyLocation(path, clientName);

  // in case we got a cipher, we use the encryption helper
  // to manage SQLite encryption
  final helper = cipher == null
      ? null
      : SQfLiteEncryptionHelper(factory: factory, path: path, cipher: cipher);

  // check whether the DB is already encrypted and otherwise do so
  await helper?.ensureDatabaseFileEncrypted();

  final database = await factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      // most important : apply encryption when opening the DB
      onConfigure: helper?.applyPragmaKey,
    ),
  );

  return await MatrixSdkDatabase.init(
    clientName,
    database: database,
    maxFileSize: 1000 * 1000 * 10,
    fileStorageLocation: fileStorageLocation?.uri,
    deleteFilesAfterDuration: const Duration(days: 30),
  );
}

Future<String> _getDatabasePath(String clientName) async {
  final databaseDirectory = PlatformInfos.isIOS || PlatformInfos.isMacOS
      ? await getLibraryDirectory()
      : await getApplicationSupportDirectory();

  return join(databaseDirectory.path, '$clientName.sqlite');
}

Future<void> _migrateLegacyLocation(
  String sqlFilePath,
  String clientName,
) async {
  final oldPath = PlatformInfos.isDesktop
      ? (await getApplicationSupportDirectory()).path
      : await getDatabasesPath();

  final oldFilePath = join(oldPath, clientName);
  if (oldFilePath == sqlFilePath) return;

  final maybeOldFile = File(oldFilePath);
  if (await maybeOldFile.exists()) {
    Logs().i(
      'Migrate legacy location for database from "$oldFilePath" to "$sqlFilePath"',
    );
    await maybeOldFile.copy(sqlFilePath);
    await maybeOldFile.delete();
  }
}
