import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

enum UcharNotificationType { info, success, warning, error }

class UcharSnackBarContent extends StatelessWidget {
  final String message;
  final UcharNotificationType type;
  final String? actionLabel;
  final VoidCallback? onAction;

  const UcharSnackBarContent({
    super.key,
    required this.message,
    this.type = UcharNotificationType.info,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _resolveColors(theme);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colors.iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_resolveIcon(), size: 20, color: colors.iconFg),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: colors.action,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            child: Text(actionLabel!),
          ),
        ],
      ],
    );
  }

  IconData _resolveIcon() => switch (type) {
    UcharNotificationType.error => TablerIcons.alert_circle,
    UcharNotificationType.warning => TablerIcons.alert_triangle,
    UcharNotificationType.success => TablerIcons.circle_check,
    UcharNotificationType.info => TablerIcons.info_circle,
  };

  _NotificationColors _resolveColors(ThemeData theme) => switch (type) {
    UcharNotificationType.error => _NotificationColors(
      iconBg: theme.colorScheme.errorContainer,
      iconFg: theme.colorScheme.onErrorContainer,
      text: theme.colorScheme.onErrorContainer,
      action: theme.colorScheme.error,
    ),
    UcharNotificationType.warning => _NotificationColors(
      iconBg: theme.colorScheme.tertiaryContainer,
      iconFg: theme.colorScheme.onTertiaryContainer,
      text: theme.colorScheme.onTertiaryContainer,
      action: theme.colorScheme.tertiary,
    ),
    UcharNotificationType.success => _NotificationColors(
      iconBg: theme.colorScheme.secondaryContainer,
      iconFg: theme.colorScheme.onSecondaryContainer,
      text: theme.colorScheme.onSecondaryContainer,
      action: theme.colorScheme.secondary,
    ),
    UcharNotificationType.info => _NotificationColors(
      iconBg: theme.colorScheme.primaryContainer,
      iconFg: theme.colorScheme.onPrimaryContainer,
      text: theme.colorScheme.onPrimaryContainer,
      action: theme.colorScheme.primary,
    ),
  };
}

class _NotificationColors {
  final Color iconBg;
  final Color iconFg;
  final Color text;
  final Color action;

  const _NotificationColors({
    required this.iconBg,
    required this.iconFg,
    required this.text,
    required this.action,
  });
}

extension UcharScaffoldMessenger on ScaffoldMessengerState {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showUcharSnackBar({
    required String message,
    UcharNotificationType type = UcharNotificationType.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 6),
    bool showCloseIcon = true,
  }) {
    late ScaffoldFeatureController<SnackBar, SnackBarClosedReason> controller;
    controller = showSnackBar(
      SnackBar(
        duration: duration,
        showCloseIcon: showCloseIcon,
        content: UcharSnackBarContent(
          message: message,
          type: type,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
      ),
    );
    return controller;
  }
}
