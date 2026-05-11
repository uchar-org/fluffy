import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/widgets/uchar_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';

abstract class UpdateNotifier {
  static const String versionStoreKey = 'last_known_version';

  static void showUpdateSnackBar(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final l10n = L10n.of(context);
    final currentVersion = await PlatformInfos.getVersion();
    final store = await SharedPreferences.getInstance();
    final storedVersion = store.getString(versionStoreKey);

    if (currentVersion != storedVersion) {
      if (storedVersion != null) {
        scaffoldMessenger.showUcharSnackBar(
          message: l10n.updateInstalled(currentVersion),
          type: UcharNotificationType.success,
          actionLabel: l10n.changelog,
          onAction: () => launchUrlString(AppConfig.changelogUrl),
          duration: const Duration(seconds: 30),
        );
      }
      await store.setString(versionStoreKey, currentVersion);
    }
  }
}
