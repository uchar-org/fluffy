import 'package:fluffychat/pages/chat/events/message.dart';
import 'package:flutter/material.dart';

class MessageStatusWidget extends StatelessWidget {
  final MessageStatus? status;
  final Color iconColor;
  const MessageStatusWidget({super.key, required this.status, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        switch (status) {
          case null:
            {
              return SizedBox.shrink();
            }
          case MessageStatus.seen:
            {
              return Icon(Icons.done_all, size: 14, color: iconColor);
            }
          case MessageStatus.pending:
            {
              return Icon(Icons.schedule, size: 14, color: iconColor);
            }
          case MessageStatus.sent:
            {
              return Icon(Icons.check, size: 14, color: iconColor);
            }
          case MessageStatus.error:
            {
              return Icon(
                Icons.error,
                size: 14,
                color: Theme.of(context).colorScheme.error,
              );
            }
        }
      },
    );
  }
}
