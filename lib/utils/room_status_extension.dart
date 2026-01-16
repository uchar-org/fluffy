import 'package:flutter/widgets.dart';

import 'package:matrix/matrix.dart';

import 'package:fluffychat/l10n/l10n.dart';
import '../config/app_config.dart';

/// Find the newest event ID that any other user has read
/// Returns null if no other users have read any messages
String? getLatestReadEventId(Timeline timeline, String currentUserId) {
  if (timeline.events.isEmpty) return null;

  // Iterate from newest (index 0) to oldest
  for (final event in timeline.events) {
    // Check if ANY other user (not current user) has receipt on this event
    final hasOtherReader = event.receipts.any((r) => r.user.id != currentUserId);

    if (hasOtherReader) {
      return event.eventId;  // This is the latest read position
    }
  }

  return null;  // No one has read any messages
}

extension RoomStatusExtension on Room {
  String getLocalizedTypingText(BuildContext context) {
    var typingText = '';
    final typingUsers = this.typingUsers;
    typingUsers.removeWhere((User u) => u.id == client.userID);

    if (AppConfig.hideTypingUsernames) {
      typingText = L10n.of(context).isTyping;
      if (typingUsers.first.id != directChatMatrixID) {
        typingText = L10n.of(context).numUsersTyping(typingUsers.length);
      }
    } else if (typingUsers.length == 1) {
      typingText = L10n.of(context).isTyping;
      if (typingUsers.first.id != directChatMatrixID) {
        typingText = L10n.of(
          context,
        ).userIsTyping(typingUsers.first.calcDisplayname());
      }
    } else if (typingUsers.length == 2) {
      typingText = L10n.of(context).userAndUserAreTyping(
        typingUsers.first.calcDisplayname(),
        typingUsers[1].calcDisplayname(),
      );
    } else if (typingUsers.length > 2) {
      typingText = L10n.of(context).userAndOthersAreTyping(
        typingUsers.first.calcDisplayname(),
        (typingUsers.length - 1),
      );
    }
    return typingText;
  }

  List<User> getSeenByUsers(Timeline timeline, {String? eventId}) {
    if (timeline.events.isEmpty) return [];
    eventId ??= timeline.events.first.eventId;

    final lastReceipts = <User>{};
    // now we iterate the timeline events until we hit the first rendered event
    for (final event in timeline.events) {
      lastReceipts.addAll(event.receipts.map((r) => r.user));
      if (event.eventId == eventId) {
        break;
      }
    }
    lastReceipts.removeWhere(
      (user) =>
          user.id == client.userID || user.id == timeline.events.first.senderId,
    );
    return lastReceipts.toList();
  }

}
