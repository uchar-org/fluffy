import 'package:fluffychat/utils/matrix_sdk_extensions/device_extension.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat_encryption_settings/chat_encryption_settings.dart';
import 'package:fluffychat/utils/beautify_string_extension.dart';
import 'package:fluffychat/widgets/avatar.dart';
import 'package:fluffychat/widgets/layouts/max_width_body.dart';

import '../../utils/date_time_extension.dart';

class ChatEncryptionSettingsView extends StatelessWidget {
  final ChatEncryptionSettingsController controller;

  const ChatEncryptionSettingsView(this.controller, {super.key});

  FutureBuilder<List<DeviceKeys>> buildDeviceKeysList(BuildContext context) {
    final theme = Theme.of(context);
    final room = controller.room;
    return FutureBuilder<List<DeviceKeys>>(
      future: room.getUserDeviceKeys(),
      builder: (BuildContext context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              '${L10n.of(context).oopsSomethingWentWrong}: ${snapshot.error}',
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator.adaptive(
              strokeWidth: 2,
            ),
          );
        }
        final deviceKeys = snapshot.data!;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: deviceKeys.length,
          itemBuilder: (BuildContext context, int i) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (i == 0 ||
                  deviceKeys[i].userId != deviceKeys[i - 1].userId) ...[
                const Divider(),
                FutureBuilder(
                  future: room.client.getUserProfile(deviceKeys[i].userId),
                  builder: (context, snapshot) {
                    final deviceKey = deviceKeys[i];
                    final displayname = snapshot.data?.displayname ??
                        deviceKey.userId.localpart ??
                        deviceKey.userId;

                    return Column(
                      children: <Widget>[
                        ExpansionTile(
                          title: Text(displayname),
                          leading: Avatar(
                            name: displayname,
                            mxContent: snapshot.data?.avatarUrl,
                          ),
                          subtitle: Text(deviceKey.userId),
                          children: [
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: deviceKeys.length,
                              itemBuilder: (
                                BuildContext context,
                                int i,
                              ) =>
                                  ExpansionTile(
                                leading: Icon(
                                  deviceKey.icon,
                                ),
                                title: Text(
                                  deviceKey.displayname,
                                  style: deviceKey.blocked
                                      ? const TextStyle(
                                          color: Colors.red,
                                        )
                                      : TextStyle(
                                          color: deviceKey.verified
                                              ? Colors.green
                                              : Colors.orange,
                                        ),
                                ),
                                subtitle: Text(
                                  "${L10n.of(context).deviceId}: ${deviceKey.deviceId}",
                                ),
                                // subtitle: Text(devices[i].ac),
                                children: [
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      SwitchListTile(
                                        value: !deviceKey.blocked,
                                        activeThumbColor: deviceKey.verified
                                            ? Colors.green
                                            : Colors.orange,
                                        onChanged: (_) =>
                                            controller.toggleDeviceKey(
                                          deviceKey,
                                        ),
                                        title: Row(
                                          children: [
                                            Text(
                                              deviceKey.verified
                                                  ? L10n.of(
                                                      context,
                                                    ).verified
                                                  : deviceKey.blocked
                                                      ? L10n.of(
                                                          context,
                                                        ).blocked
                                                      : L10n.of(
                                                          context,
                                                        ).unverified,
                                              style: TextStyle(
                                                color: deviceKey.verified
                                                    ? Colors.green
                                                    : deviceKey.blocked
                                                        ? Colors.red
                                                        : Colors.orange,
                                              ),
                                            ),
                                            const Text(' | ID: '),
                                            Text(
                                              deviceKey.deviceId ??
                                                  L10n.of(context)
                                                      .unknownDevice,
                                            ),
                                          ],
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              deviceKey
                                                      .ed25519Key?.beautified ??
                                                  L10n.of(context)
                                                      .unknownEncryptionAlgorithm,
                                              style: TextStyle(
                                                fontFamily: 'RobotoMono',
                                                color:
                                                    theme.colorScheme.secondary,
                                                fontSize: 11,
                                              ),
                                            ),
                                            Text(
                                              L10n.of(context).lastActiveAgo(
                                                deviceKey.lastActive
                                                    .localizedTimeShort(
                                                  context,
                                                ),
                                              ),
                                              style: const TextStyle(
                                                fontVariations: <FontVariation>[
                                                  FontVariation.weight(
                                                    600,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final room = controller.room;

    return StreamBuilder<Object>(
      stream: room.client.onSync.stream.where(
        (s) => s.rooms?.join?[room.id] != null || s.deviceLists != null,
      ),
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_outlined),
            onPressed: () => context.go('/rooms/${controller.roomId!}'),
          ),
          title: Text(L10n.of(context).encryption),
          actions: [
            TextButton(
              onPressed: () => launchUrlString(AppConfig.encryptionTutorial),
              child: Text(L10n.of(context).help),
            ),
          ],
        ),
        body: MaxWidthBody(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                secondary: CircleAvatar(
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: const Icon(Icons.lock_outlined),
                ),
                title: Text(L10n.of(context).encryptThisChat),
                value: room.encrypted,
                onChanged: controller.enableEncryption,
              ),
              Icon(
                CupertinoIcons.lock_shield,
                size: 128,
                color: theme.colorScheme.onInverseSurface,
              ),
              if (room.isDirectChat)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: controller.startVerification,
                      icon: const Icon(Icons.verified_outlined),
                      label: Text(L10n.of(context).verifyStart),
                    ),
                  ),
                ),
              if (room.encrypted) ...[
                const SizedBox(height: 16),
                ListTile(
                  title: Text(
                    L10n.of(context).deviceKeys,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                StreamBuilder(
                  stream: room.client.onRoomState.stream
                      .where((update) => update.roomId == controller.room.id),
                  builder: (context, snapshot) => buildDeviceKeysList(context),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      L10n.of(context).encryptionNotEnabled,
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
