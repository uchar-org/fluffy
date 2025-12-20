import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';

import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/element_call/call_service.dart';
import '../../../config/app_config.dart';

/// Widget to display call notification events in the timeline.
/// Handles both org.matrix.msc4075.call.notify and org.matrix.msc4075.rtc.notification events.
class CallNotifyEventWidget extends StatelessWidget {
  final Event event;
  final Color textColor;
  final void Function()? onJoinCall;
  final double? fontSize;

  const CallNotifyEventWidget({
    required this.event,
    required this.textColor,
    this.onJoinCall,
    this.fontSize,
    super.key,
  });

  /// Check if THIS SPECIFIC call is currently active.
  ///
  /// Due to Matrix RTC limitations, we can't reliably match notify events to
  /// specific call sessions (room.states doesn't expose event IDs for matching).
  /// Instead, we use a simple recency check:
  /// - Only notify events sent within the last 5 minutes show "Join Call"
  /// - Older events always show "Missed Call" (even during active calls)
  /// - The app bar "Join Call" button remains functional for active calls
  bool get isCallActive {
    // Check if there's an active call in room
    if (!CallService.hasActiveCall(event.room)) {
      return false;
    }

    // Only show "Join Call" if notify was sent within last 5 minutes
    final now = DateTime.now();
    final eventTime = event.originServerTs;
    final age = now.difference(eventTime);

    return age.inMinutes <= 5;
  }

  /// Get notify type from event content (ring or notify)
  String? get notifyType {
    final content = event.content;
    return content['notify_type'] as String?;
  }

  /// Check if this is a ringing call
  bool get isRinging => notifyType == 'ring';

  /// Check if this call was answered (has duration or was completed)
  bool get wasAnswered {
    final content = event.content;
    // Check for duration field
    final duration = content['duration'];
    if (duration != null && duration is int && duration > 0) return true;
    // Check for answered flag
    if (content['answered'] == true) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final effectiveFontSize =
        fontSize ?? AppConfig.messageFontSize * AppSettings.fontSizeFactor.value;

    // Determine display text based on call state
    final senderName = event.senderFromMemoryOrFallback.calcDisplayname();
    final String displayText;
    final IconData icon;
    final String? actionText;

    if (isCallActive) {
      // Call is currently active
      displayText = isRinging
          ? l10n.incomingCall(senderName)
          : l10n.startedACall(senderName);
      icon = Icons.call;
      actionText = l10n.joinCall;
    } else {
      // Call has ended - distinguish between ended and missed
      if (wasAnswered) {
        displayText = l10n.callEnded;
        icon = Icons.call_end;
        actionText = onJoinCall != null ? l10n.callBack : null;
      } else {
        displayText = l10n.missedCall(senderName);
        icon = Icons.call_missed;
        actionText = onJoinCall != null ? l10n.callBack : null;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: textColor,
            size: effectiveFontSize + 4,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              displayText,
              style: TextStyle(
                color: textColor,
                fontSize: effectiveFontSize,
              ),
            ),
          ),
          if (actionText != null && onJoinCall != null) ...[
            const SizedBox(width: 12),
            TextButton(
              onPressed: onJoinCall,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
              ),
              child: Text(
                actionText,
                style: TextStyle(fontSize: effectiveFontSize - 2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
