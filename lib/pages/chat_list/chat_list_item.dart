import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat_list/unread_bubble.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:fluffychat/utils/room_status_extension.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:fluffychat/widgets/future_loading_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:matrix/matrix.dart';

import '../../config/themes.dart';
import '../../utils/date_time_extension.dart';
import '../../widgets/avatar.dart';
import '../../widgets/mxc_image.dart';

enum ArchivedRoomAction { delete, rejoin }

class ChatListItem extends StatelessWidget {
  final Room room;
  final Room? space;
  final bool activeChat;
  final void Function(BuildContext context, Offset? tapPosition)? onLongPress;
  final void Function()? onForget;
  final void Function() onTap;
  final String? filter;

  const ChatListItem(
    this.room, {
    this.activeChat = false,
    required this.onTap,
    this.onLongPress,
    this.onForget,
    this.filter,
    this.space,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isMuted = room.pushRuleState != PushRuleState.notify;
    final typingText = room.getLocalizedTypingText(context);
    final lastEvent = room.lastEvent;
    final ownMessage = lastEvent?.senderId == room.client.userID;
    final unread = room.isUnread;
    final directChatMatrixId = room.directChatMatrixID;
    final isDirectChat = directChatMatrixId != null;
    final hasNotifications = room.notificationCount > 0;
    final isReadByOthers = ownMessage &&
        lastEvent != null &&
        (lastEvent.status == EventStatus.synced ||
            lastEvent.status == EventStatus.sent) &&
        room.receiptState.global.otherUsers.values
            .any((r) => r.ts >= lastEvent.originServerTs.millisecondsSinceEpoch);
    final backgroundColor = activeChat
        ? theme.colorScheme.secondaryContainer
        : null;
    final matrixLocals = MatrixLocals(L10n.of(context));
    final filter = this.filter;
    if (filter != null &&
        !room.getLocalizedDisplayname(matrixLocals).toLowerCase().contains(
          filter,
        )) {
      return const SizedBox.shrink();
    }

    final needLastEventSender =
        lastEvent != null &&
        room.getState(EventTypes.RoomMember, lastEvent.senderId) == null;
    final space = this.space;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        borderRadius: BorderRadius.circular(AppConfig.borderRadius),
        clipBehavior: Clip.hardEdge,
        color: backgroundColor,
        child: FutureBuilder(
          future: room.name.isEmpty ? room.loadHeroUsers() : null,
          builder: (context, _) {
            final displayname = room.getLocalizedDisplayname(matrixLocals);
            return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onSecondaryTapDown: (details) =>
                onLongPress?.call(context, details.globalPosition),
            onLongPressStart: (details) =>
                onLongPress?.call(context, details.globalPosition),
              child: ListTile(
              visualDensity: const VisualDensity(vertical: -0.5),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: SizedBox(
                  width: Avatar.defaultSize,
                  height: Avatar.defaultSize,
                  child: Stack(
                    children: [
                        if (space != null)
                          Positioned(
                            top: 0,
                            left: 0,
                            child: Avatar(
                              shapeBorder: RoundedSuperellipseBorder(
                                side: BorderSide(
                                  width: 2,
                                  color:
                                      backgroundColor ??
                                      theme.colorScheme.surface,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppConfig.spaceBorderRadius * 0.75,
                                ),
                              ),
                              borderRadius: BorderRadius.circular(
                                AppConfig.spaceBorderRadius * 0.75,
                              ),
                              mxContent: space.avatar,
                              size: Avatar.defaultSize * 0.75,
                              name: space.getLocalizedDisplayname(),
                              onTap: () => onLongPress?.call(context, null),
                            ),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Avatar(
                            shapeBorder: space == null
                                ? room.isSpace
                                      ? RoundedSuperellipseBorder(
                                          side: BorderSide(
                                            width: 1,
                                            color: theme.dividerColor,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            AppConfig.spaceBorderRadius,
                                          ),
                                        )
                                      : null
                                : RoundedRectangleBorder(
                                    side: BorderSide(
                                      width: 2,
                                      color:
                                          backgroundColor ??
                                          theme.colorScheme.surface,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      Avatar.defaultSize,
                                    ),
                                  ),
                            borderRadius: room.isSpace
                                ? BorderRadius.circular(
                                    AppConfig.spaceBorderRadius,
                                  )
                                : null,
                            mxContent: room.avatar,
                            size: space != null
                                ? Avatar.defaultSize * 0.75
                                : Avatar.defaultSize,
                            name: displayname,
                            presenceUserId: directChatMatrixId,
                            presenceBackgroundColor: backgroundColor,
                            onTap: () => onLongPress?.call(context, null),
                          ),
                        ),
                    ],
                  ),
                ),
              title: Row(
                children: <Widget>[
                  if (!isDirectChat) ...[
                    Icon(
                      room.isSpace
                          ? TablerIcons.layout_grid
                          : room.joinRules == JoinRules.public
                          ? TablerIcons.speakerphone
                          : TablerIcons.users,
                      size: 16,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      displayname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: TextStyle(
                        fontWeight: unread || room.hasNewMessages
                            ? FontWeight.w500
                            : null,
                      ),
                    ),
                  ),
                  if (isMuted)
                    const Padding(
                      padding: EdgeInsets.only(left: 4.0),
                      child: Icon(TablerIcons.bell_off, size: 16),
                    ),
                  if (room.isLowPriority)
                    Padding(
                      padding: EdgeInsets.only(
                        right: hasNotifications ? 4.0 : 0.0,
                      ),
                      child: Icon(
                        TablerIcons.arrow_bar_to_down,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  if (room.isFavourite)
                    Padding(
                      padding: EdgeInsets.only(
                        right: hasNotifications ? 4.0 : 0.0,
                      ),
                      child: Icon(
                        TablerIcons.pin_filled,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  if (!room.isSpace && room.membership != Membership.invite)
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Text(
                        room.latestEventReceivedTime.localizedTimeShort(
                          context,
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: room.hasNewMessages
                              ? FontWeight.bold
                              : null,
                          color: hasNotifications
                              ? theme.colorScheme.primary
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: Row(
                crossAxisAlignment: .center,
                mainAxisAlignment: .center,
                children: <Widget>[
                  if (typingText.isEmpty &&
                      ownMessage &&
                      room.lastEvent?.status.isSending == true) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    ),
                    const SizedBox(width: 4),
                  ],
                  AnimatedSize(
                    clipBehavior: Clip.hardEdge,
                    duration: FluffyThemes.animationDuration,
                    curve: FluffyThemes.animationCurve,
                    child: typingText.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(right: 4.0),
                            child: Icon(
                              TablerIcons.pencil,
                              color: theme.colorScheme.secondary,
                              size: 16,
                            ),
                          )
                        : room.lastEvent?.relationshipType ==
                              RelationshipTypes.thread
                        ? Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: theme.colorScheme.outline,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppConfig.borderRadius,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                            ),
                            margin: const EdgeInsets.only(right: 4.0),
                            child: Row(
                              mainAxisSize: .min,
                              children: [
                                Icon(
                                  TablerIcons.message,
                                  size: 12,
                                  color: theme.colorScheme.outline,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  L10n.of(context).thread,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  Expanded(
                    child: room.isSpace && room.membership == Membership.join
                        ? Text(
                            L10n.of(
                              context,
                            ).countChats(room.spaceChildren.length),
                            style: TextStyle(color: theme.colorScheme.outline),
                          )
                        : typingText.isNotEmpty
                        ? Text(
                            typingText,
                            style: TextStyle(color: theme.colorScheme.primary),
                            maxLines: 1,
                            softWrap: false,
                          )
                        : _buildLastEventPreview(
                            context,
                            theme,
                            lastEvent,
                            needLastEventSender,
                            isDirectChat,
                            directChatMatrixId,
                            unread,
                          ),
                  ),
                  if (typingText.isEmpty &&
                      ownMessage &&
                      lastEvent != null &&
                      (lastEvent.status == EventStatus.synced ||
                          lastEvent.status == EventStatus.sent)) ...[
                    const SizedBox(width: 4),
                    Icon(
                      isReadByOthers ? TablerIcons.checks : TablerIcons.check,
                      size: 14,
                      color: isReadByOthers
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                  ],
                  const SizedBox(width: 8),
                  UnreadBubble(room: room),
                ],
              ),
              onTap: onTap,
              trailing: onForget == null
                  ? room.membership == Membership.invite
                        ? IconButton(
                            tooltip: L10n.of(context).declineInvitation,
                            icon: const Icon(TablerIcons.trash_filled),
                            color: theme.colorScheme.error,
                            onPressed: () async {
                              final consent = await showOkCancelAlertDialog(
                                context: context,
                                title: L10n.of(context).declineInvitation,
                                message: L10n.of(context).areYouSure,
                                okLabel: L10n.of(context).yes,
                                isDestructive: true,
                              );
                              if (consent != OkCancelResult.ok) return;
                              if (!context.mounted) return;
                              await showFutureLoadingDialog(
                                context: context,
                                future: room.leave,
                              );
                            },
                          )
                        : null
                  : IconButton(
                      icon: const Icon(TablerIcons.trash),
                      onPressed: onForget,
                    ),
            ),
          );
          },
        ),
      ),
    );
  }

  Widget _buildLastEventPreview(
    BuildContext context,
    ThemeData theme,
    Event? lastEvent,
    bool needLastEventSender,
    bool isDirectChat,
    String? directChatMatrixId,
    bool unread,
  ) {
    if (lastEvent?.type == EventTypes.Reaction &&
        lastEvent?.senderId == room.client.userID) {
      final relatedId = lastEvent!.content
          .tryGetMap<String, Object?>('m.relates_to')
          ?.tryGet<String>('event_id');
      return FutureBuilder<Event?>(
        key: ValueKey('own_reaction_preview_$relatedId'),
        future: relatedId != null ? room.getEventById(relatedId) : null,
        builder: (context, snapshot) {
          final related = snapshot.data;
          if (related == null) return const SizedBox.shrink();
          final relatedNeedSender =
              room.getState(EventTypes.RoomMember, related.senderId) == null;
          return FutureBuilder<String?>(
            key: ValueKey('related_body_${related.eventId}'),
            future: relatedNeedSender
                ? related.calcLocalizedBody(
                    MatrixLocals(L10n.of(context)),
                    hideReply: true,
                    hideEdit: true,
                    plaintextBody: true,
                    removeMarkdown: true,
                    withSenderNamePrefix:
                        !isDirectChat ||
                        directChatMatrixId != related.senderId,
                  )
                : null,
            initialData: related.calcLocalizedBodyFallback(
              MatrixLocals(L10n.of(context)),
              hideReply: true,
              hideEdit: true,
              plaintextBody: true,
              removeMarkdown: true,
              withSenderNamePrefix:
                  !isDirectChat || directChatMatrixId != related.senderId,
            ),
            builder: (context, snapshot) => Text(
              snapshot.data ?? L10n.of(context).noMessagesYet,
              softWrap: false,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: unread || room.hasNewMessages
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.outline,
                decoration: related.redacted
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
          );
        },
      );
    }

    final msgType = lastEvent?.messageType;
    final isImage = msgType == MessageTypes.Image;
    final isVideo = msgType == MessageTypes.Video;
    final isMedia = isImage || isVideo;

    final textStyle = TextStyle(
      color: unread || room.hasNewMessages
          ? theme.colorScheme.onSurface
          : theme.colorScheme.outline,
      decoration:
          room.lastEvent?.redacted == true ? TextDecoration.lineThrough : null,
    );

    if (isMedia && lastEvent != null) {
      final caption = lastEvent.body.isNotEmpty &&
              lastEvent.body != lastEvent.content
                  .tryGet<Map<String, Object?>>('info')
                  ?.tryGet<String>('mimetype')
          ? lastEvent.body
          : null;

      final label = caption != null && caption != lastEvent.content.tryGet<String>('filename')
          ? caption
          : (isVideo ? L10n.of(context).video : L10n.of(context).photo);

      return Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: MxcImage(
              event: lastEvent,
              width: 18,
              height: 18,
              fit: BoxFit.cover,
              isThumbnail: true,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
        ],
      );
    }

    return FutureBuilder(
      key: ValueKey(
        '${lastEvent?.eventId}_${lastEvent?.type}_${lastEvent?.redacted}',
      ),
      future: needLastEventSender
          ? lastEvent?.calcLocalizedBody(
              MatrixLocals(L10n.of(context)),
              hideReply: true,
              hideEdit: true,
              plaintextBody: true,
              removeMarkdown: true,
              withSenderNamePrefix:
                  (!isDirectChat ||
                  directChatMatrixId != room.lastEvent?.senderId),
            )
          : null,
      initialData: lastEvent?.calcLocalizedBodyFallback(
        MatrixLocals(L10n.of(context)),
        hideReply: true,
        hideEdit: true,
        plaintextBody: true,
        removeMarkdown: true,
        withSenderNamePrefix:
            (!isDirectChat || directChatMatrixId != room.lastEvent?.senderId),
      ),
      builder: (context, snapshot) => Text(
        room.membership == Membership.invite
            ? room
                      .getState(
                        EventTypes.RoomMember,
                        room.client.userID!,
                      )
                      ?.content
                      .tryGet<String>('reason') ??
                  (isDirectChat
                      ? L10n.of(context).newChatRequest
                      : L10n.of(context).inviteGroupChat)
            : snapshot.data ?? L10n.of(context).noMessagesYet,
        softWrap: false,
        maxLines: room.notificationCount >= 1 ? 2 : 1,
        overflow: TextOverflow.ellipsis,
        style: textStyle,
      ),
    );
  }
}
