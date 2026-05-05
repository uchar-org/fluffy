import 'dart:async';
import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter/services.dart';

import 'package:matrix/matrix.dart';

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat/chat.dart';
import 'package:fluffychat/utils/date_time_extension.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/event_extension.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/utils/room_status_extension.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/user_dialog.dart';
import 'package:fluffychat/widgets/avatar.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:fluffychat/widgets/mxc_image.dart';

enum _ContextAction {
  reply,
  replyInThread,
  edit,
  copy,
  forward,
  pin,
  download,
  delete,
  select,
  info,
  report,
}

class _UserReaction {
  final String key;
  final DateTime? time;
  const _UserReaction({required this.key, this.time});
}

class _SeenEntry {
  final Receipt receipt;
  final _UserReaction? reaction;

  const _SeenEntry({required this.receipt, this.reaction});

  bool get hasReaction => reaction != null;
}

class MessageContextMenu extends StatefulWidget {
  final Event event;
  final Widget child;
  final ChatController controller;
  final Timeline timeline;
  final bool ownMessage;

  const MessageContextMenu({
    super.key,
    required this.event,
    required this.child,
    required this.controller,
    required this.timeline,
    required this.ownMessage,
  });

  @override
  State<MessageContextMenu> createState() => _MessageContextMenuState();
}

class _MessageContextMenuState extends State<MessageContextMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _likeAnimController;
  late final Animation<double> _likeScale;
  late final Animation<double> _likeOpacity;
  String? _animEmoji;
  bool _isHovered = false;
  OverlayEntry? _emojiPickerOverlay;
  Timer? _emojiPickerTimer;
  final _likeButtonKey = GlobalKey();

  bool get _buttonVisible => _isHovered || _emojiPickerOverlay != null;

  @override
  void initState() {
    super.initState();
    _likeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _likeScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.2, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 20),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_likeAnimController);
    _likeOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 65),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_likeAnimController);
  }

  @override
  void dispose() {
    _likeAnimController.dispose();
    _emojiPickerTimer?.cancel();
    _emojiPickerOverlay?.remove();
    super.dispose();
  }

  bool get _canEdit {
    if (widget.controller.room.isArchived || !widget.event.status.isSent) return false;
    final clients = Matrix.of(widget.controller.context).currentBundle;
    return clients != null && clients.any((cl) => widget.event.senderId == cl!.userID);
  }

  bool get _canRedact {
    if (widget.controller.room.isArchived || !widget.event.status.isSent) return false;
    final clients = Matrix.of(widget.controller.context).currentBundle;
    return widget.event.canRedact ||
        (clients != null && clients.any((cl) => widget.event.senderId == cl!.userID));
  }

  bool get _canPin {
    return !widget.controller.room.isArchived &&
        widget.controller.room.canChangeStateEvent(EventTypes.RoomPinnedEvents) &&
        widget.event.status.isSent &&
        widget.controller.activeThreadId == null;
  }

  bool get _canSave {
    return {
      MessageTypes.Video,
      MessageTypes.Image,
      MessageTypes.Sticker,
      MessageTypes.Audio,
      MessageTypes.File,
    }.contains(widget.event.messageType);
  }

  bool get _isPinned =>
      widget.controller.room.pinnedEventIds.contains(widget.event.eventId);

  void _onSelected(BuildContext context, _ContextAction action) {
    switch (action) {
      case _ContextAction.reply:
        widget.controller.replyAction(replyTo: widget.event);
        break;
      case _ContextAction.replyInThread:
        widget.controller.enterThread(widget.event.eventId);
        break;
      case _ContextAction.edit:
        widget.controller.selectSingleEvent(widget.event);
        widget.controller.editSelectedEventAction();
        break;
      case _ContextAction.copy:
        final displayEvent = widget.event.getDisplayEvent(widget.timeline);
        Clipboard.setData(
          ClipboardData(
            text: displayEvent.calcLocalizedBodyFallback(
              MatrixLocals(L10n.of(context)),
              withSenderNamePrefix: false,
              hideReply: true,
            ),
          ),
        );
        break;
      case _ContextAction.forward:
        widget.controller.selectSingleEvent(widget.event);
        widget.controller.forwardEventsAction();
        break;
      case _ContextAction.pin:
        widget.controller.selectSingleEvent(widget.event);
        widget.controller.pinEvent();
        widget.controller.clearSelectedEvents();
        break;
      case _ContextAction.download:
        widget.event.saveFile(context);
        break;
      case _ContextAction.delete:
        widget.controller.selectSingleEvent(widget.event);
        widget.controller.redactEventsAction();
        break;
      case _ContextAction.select:
        widget.controller.onSelectMessage(widget.event);
        break;
      case _ContextAction.info:
        widget.controller.selectSingleEvent(widget.event);
        widget.controller.showEventInfo();
        widget.controller.clearSelectedEvents();
        break;
      case _ContextAction.report:
        widget.controller.selectSingleEvent(widget.event);
        widget.controller.reportEventAction();
        break;
    }
  }

  List<_ContextMenuItem> _buildItems(BuildContext context) {
    final l10n = L10n.of(context);
    final room = widget.controller.room;
    final canSendMessages = room.canSendDefaultMessages;
    final items = <_ContextMenuItem>[];

    if (canSendMessages && widget.event.status.isSent) {
      items.add(_ContextMenuItem(
        action: _ContextAction.reply,
        icon: TablerIcons.arrow_back_up,
        label: l10n.reply,
      ));
    }

    if (canSendMessages &&
        widget.event.status.isSent &&
        widget.controller.activeThreadId == null) {
      items.add(_ContextMenuItem(
        action: _ContextAction.replyInThread,
        icon: TablerIcons.message,
        label: l10n.replyInThread,
      ));
    }

    if (_canEdit && widget.event.messageType == MessageTypes.Text) {
      items.add(_ContextMenuItem(
        action: _ContextAction.edit,
        icon: TablerIcons.pencil,
        label: l10n.edit,
      ));
    }

    if ({MessageTypes.Text, MessageTypes.Notice, MessageTypes.Emote}
        .contains(widget.event.messageType)) {
      items.add(_ContextMenuItem(
        action: _ContextAction.copy,
        icon: TablerIcons.copy,
        label: l10n.copyToClipboard,
      ));
    }

    if (widget.event.status.isSent) {
      items.add(_ContextMenuItem(
        action: _ContextAction.forward,
        icon: TablerIcons.corner_down_right,
        label: l10n.forward,
      ));
    }

    if (_canPin) {
      items.add(_ContextMenuItem(
        action: _ContextAction.pin,
        icon: _isPinned ? TablerIcons.pin_filled : TablerIcons.pin,
        label: _isPinned ? l10n.unpin : l10n.pinMessage,
      ));
    }

    if (_canSave) {
      items.add(_ContextMenuItem(
        action: _ContextAction.download,
        icon: TablerIcons.cloud_download,
        label: l10n.downloadFile,
      ));
    }

    items.add(_ContextMenuItem(
      action: _ContextAction.select,
      icon: TablerIcons.circle_check,
      label: l10n.select,
    ));

    if (_canRedact) {
      items.add(_ContextMenuItem(
        action: _ContextAction.delete,
        icon: TablerIcons.trash,
        label: l10n.redactMessage,
        isDestructive: true,
      ));
    }

    items.add(_ContextMenuItem(
      action: _ContextAction.info,
      icon: TablerIcons.info_circle,
      label: l10n.messageInfo,
    ));

    if (widget.event.status.isSent &&
        widget.event.senderId != room.client.userID) {
      items.add(_ContextMenuItem(
        action: _ContextAction.report,
        icon: TablerIcons.shield,
        label: l10n.reportMessage,
        isDestructive: true,
      ));
    }

    return items;
  }

  void _showContextMenu(BuildContext context, Offset position) {
    if (widget.event.redacted) return;

    final items = _buildItems(context);
    if (items.isEmpty) return;

    widget.controller.closeContextMenu?.call();

    final isOwnMessage =
        widget.event.senderId == widget.event.room.client.userID;

    final reactionsByUser = <String, List<_UserReaction>>{};
    for (final re in widget.event
        .aggregatedEvents(widget.timeline, RelationshipTypes.reaction)) {
      final key = re.content
          .tryGetMap<String, dynamic>('m.relates_to')
          ?.tryGet<String>('key');
      if (key != null) {
        reactionsByUser
            .putIfAbsent(re.senderId, () => [])
            .add(_UserReaction(key: key, time: re.originServerTs));
      }
    }

    final seenEntries = isOwnMessage
        ? () {
            final seenUsers = widget.event.room.getSeenByUsers(
              widget.timeline,
              eventId: widget.event.eventId,
            );
            final otherUserReceipts =
                widget.event.room.receiptState.global.otherUsers;
            final entries = <_SeenEntry>[];

            final ownUserId = widget.event.room.client.userID;
            if (ownUserId != null) {
              final ownReactions = reactionsByUser[ownUserId] ?? [];
              if (ownReactions.isNotEmpty) {
                final ownUser = widget.event.room
                    .unsafeGetUserFromMemoryOrFallback(ownUserId);
                for (final r in ownReactions) {
                  entries.add(_SeenEntry(
                    receipt: Receipt(ownUser, r.time ?? DateTime.now()),
                    reaction: r,
                  ));
                }
              }
            }

            for (final user in seenUsers) {
              final time =
                  otherUserReceipts[user.id]?.timestamp ?? DateTime.now();
              final receipt = Receipt(user, time);
              final userReactions = reactionsByUser[user.id] ?? [];
              if (userReactions.isNotEmpty) {
                for (final r in userReactions) {
                  entries.add(_SeenEntry(receipt: receipt, reaction: r));
                }
              } else {
                entries.add(_SeenEntry(receipt: receipt));
              }
            }
            entries.sort((a, b) {
              if (a.hasReaction && !b.hasReaction) return -1;
              if (!a.hasReaction && b.hasReaction) return 1;
              return 0;
            });
            return entries;
          }()
        : () {
            final entries = <_SeenEntry>[];
            for (final userId in reactionsByUser.keys) {
              final user = widget.event.room
                  .unsafeGetUserFromMemoryOrFallback(userId);
              for (final r in reactionsByUser[userId]!) {
                entries.add(_SeenEntry(
                  receipt: Receipt(user, r.time ?? DateTime.now()),
                  reaction: r,
                ));
              }
            }
            return entries;
          }();

    late OverlayEntry overlayEntry;
    final menuKey = GlobalKey<_ContextMenuOverlayState>();

    void removeOverlay() {
      overlayEntry.remove();
      widget.controller.closeContextMenu = null;
    }

    Future<void> animateClose() async {
      final state = menuKey.currentState;
      if (state != null && state.mounted) {
        await state.animateOut();
      }
      removeOverlay();
    }

    final editedAt = widget.event.hasAggregatedEvents(
            widget.timeline, RelationshipTypes.edit)
        ? widget.event.getDisplayEvent(widget.timeline).originServerTs
        : null;

    overlayEntry = OverlayEntry(
      builder: (overlayContext) => _ContextMenuOverlay(
        key: menuKey,
        position: position,
        items: items,
        seenEntries: seenEntries,
        editedAt: editedAt,
        onSelected: (action) async {
          await animateClose();
          if (context.mounted) _onSelected(context, action);
        },
        onDismiss: animateClose,
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(overlayEntry);
    widget.controller.closeContextMenu = removeOverlay;
  }

  void _triggerAnim(String emoji) {
    setState(() => _animEmoji = emoji);
    _likeAnimController.forward(from: 0).then((_) {
      if (mounted) setState(() => _animEmoji = null);
    });
  }

  void _toggleReaction(String emoji) {
    final existing = widget.event
        .aggregatedEvents(widget.timeline, RelationshipTypes.reaction)
        .where(
          (e) =>
              e.senderId == widget.event.room.client.userID &&
              e.content
                      .tryGetMap<String, Object?>('m.relates_to')
                      ?.tryGet<String>('key') ==
                  emoji,
        );
    if (existing.isNotEmpty) {
      widget.event.room.redactEvent(existing.first.eventId);
    } else {
      widget.event.room.sendReaction(widget.event.eventId, emoji);
      _triggerAnim(emoji);
    }
  }

  void _onDoubleTap() {
    HapticFeedback.mediumImpact();
    _toggleReaction('👍');
  }

  void _openEmojiPicker() {
    _emojiPickerTimer?.cancel();
    if (_emojiPickerOverlay != null) return;

    final box =
        _likeButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;

    _emojiPickerOverlay = OverlayEntry(
      builder: (_) => _EmojiExpandOverlay(
        anchorPos: pos,
        anchorSize: size,
        reactions:
            AppConfig.defaultReactions.where((e) => e != '👍').toList(),
        onSelect: (emoji) {
          _closeEmojiPicker();
          _toggleReaction(emoji);
        },
        onMouseEnter: _cancelCloseEmojiPicker,
        onMouseExit: _scheduleCloseEmojiPicker,
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_emojiPickerOverlay!);
    setState(() {});
  }

  void _scheduleCloseEmojiPicker() {
    _emojiPickerTimer?.cancel();
    _emojiPickerTimer =
        Timer(const Duration(milliseconds: 180), _closeEmojiPicker);
  }

  void _cancelCloseEmojiPicker() => _emojiPickerTimer?.cancel();

  void _closeEmojiPicker() {
    _emojiPickerOverlay?.remove();
    _emojiPickerOverlay = null;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktopOrWeb = PlatformInfos.isDesktop || PlatformInfos.isWeb;
    final canDoubleTap = widget.event.status.isSent &&
        widget.controller.room.canSendDefaultMessages;
    final showHoverBtn = isDesktopOrWeb &&
        widget.event.status.isSent &&
        !widget.event.redacted &&
        widget.controller.room.canSendDefaultMessages;

    return MouseRegion(
      onEnter: showHoverBtn ? (_) => setState(() => _isHovered = true) : null,
      onExit: showHoverBtn ? (_) => setState(() => _isHovered = false) : null,
      child: GestureDetector(
        onDoubleTap: canDoubleTap ? _onDoubleTap : null,
        onSecondaryTapUp: (details) {
          _showContextMenu(context, details.globalPosition);
        },
        onLongPressStart: isDesktopOrWeb
            ? null
            : widget.controller.selectedEvents.isNotEmpty
                ? null
                : (details) {
                    HapticFeedback.heavyImpact();
                    _showContextMenu(context, details.globalPosition);
                  },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            widget.child,
            if (_animEmoji != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _likeAnimController,
                      builder: (context, _) => Opacity(
                        opacity: _likeOpacity.value,
                        child: Transform.scale(
                          scale: _likeScale.value,
                          child: Text(
                            _animEmoji!,
                            style: const TextStyle(fontSize: 48),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (showHoverBtn)
              Positioned(
                bottom: -4,
                left: widget.ownMessage ? -16 : null,
                right: widget.ownMessage ? null : -16,
                child: AnimatedOpacity(
                  opacity: _buttonVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 120),
                  child: IgnorePointer(
                    ignoring: !_buttonVisible,
                    child: MouseRegion(
                      onEnter: (_) => _openEmojiPicker(),
                      onExit: (_) => _scheduleCloseEmojiPicker(),
                      child: Material(
                        key: _likeButtonKey,
                        elevation: 2,
                        borderRadius: BorderRadius.only(
                          topLeft: _emojiPickerOverlay != null
                              ? Radius.zero
                              : const Radius.circular(20),
                          topRight: _emojiPickerOverlay != null
                              ? Radius.zero
                              : const Radius.circular(20),
                          bottomLeft: const Radius.circular(20),
                          bottomRight: const Radius.circular(20),
                        ),
                        color: theme.colorScheme.surfaceContainer,
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: _onDoubleTap,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Text(
                              '👍',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


class _EmojiExpandOverlay extends StatelessWidget {
  final Offset anchorPos;
  final Size anchorSize;
  final List<String> reactions;
  final void Function(String) onSelect;
  final VoidCallback onMouseEnter;
  final VoidCallback onMouseExit;

  const _EmojiExpandOverlay({
    required this.anchorPos,
    required this.anchorSize,
    required this.reactions,
    required this.onSelect,
    required this.onMouseEnter,
    required this.onMouseExit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final left = anchorPos.dx;
    final bottom = MediaQuery.sizeOf(context).height - anchorPos.dy;

    return Stack(
      children: [
        Positioned(
          left: left,
          bottom: bottom,
          child: MouseRegion(
            onEnter: (_) => onMouseEnter(),
            onExit: (_) => onMouseExit(),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              builder: (_, t, child) => Opacity(
                opacity: t,
                child: Transform.scale(
                  scale: 0.8 + 0.2 * t,
                  alignment: Alignment.bottomCenter,
                  child: child,
                ),
              ),
              child: Material(
                elevation: 2,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                color: theme.colorScheme.surfaceContainer,
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 6, bottom: 2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: reactions
                          .map(
                            (emoji) => InkWell(
                              onTap: () => onSelect(emoji),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ContextMenuItem {
  final _ContextAction action;
  final IconData icon;
  final String label;
  final bool isDestructive;

  const _ContextMenuItem({
    required this.action,
    required this.icon,
    required this.label,
    this.isDestructive = false,
  });
}

class _ContextMenuOverlay extends StatefulWidget {
  final Offset position;
  final List<_ContextMenuItem> items;
  final List<_SeenEntry> seenEntries;
  final DateTime? editedAt;
  final void Function(_ContextAction) onSelected;
  final VoidCallback onDismiss;

  const _ContextMenuOverlay({
    super.key,
    required this.position,
    required this.items,
    required this.seenEntries,
    this.editedAt,
    required this.onSelected,
    required this.onDismiss,
  });

  @override
  State<_ContextMenuOverlay> createState() => _ContextMenuOverlayState();
}

class _ContextMenuOverlayState extends State<_ContextMenuOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _controller.forward();
  }

  Future<void> animateOut() => _controller.reverse();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.sizeOf(context);

    const menuWidth = 220.0;
    const itemHeight = 44.0;
    const seenByRowHeight = 40.0;
    const editedAtRowHeight = 30.0;
    final menuHeight = widget.items.length * itemHeight +
        (widget.seenEntries.isNotEmpty ? seenByRowHeight + 1 : 0) +
        (widget.editedAt != null ? editedAtRowHeight + 1 : 0);

    var left = widget.position.dx;
    var top = widget.position.dy;

    // Determine scale origin based on which edge the menu is clamped to
    var alignX = -1.0; // default: top-left origin
    var alignY = -1.0;

    if (left + menuWidth > screenSize.width) {
      left = screenSize.width - menuWidth - 8;
      alignX = 1.0;
    }
    if (top + menuHeight > screenSize.height) {
      top = screenSize.height - menuHeight - 8;
      alignY = 1.0;
    }
    if (left < 8) left = 8;
    if (top < 8) top = 8;

    return Stack(
      children: [
        // Dismiss barrier
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            onSecondaryTap: widget.onDismiss,
            behavior: HitTestBehavior.opaque,
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        // Menu
        Positioned(
          left: left,
          top: top,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.8, end: 1.0)
                  .animate(_scaleAnimation),
              alignment: Alignment(alignX, alignY),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: theme.colorScheme.surfaceContainer,
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: menuWidth),
                  child: IntrinsicWidth(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...widget.items.map((item) {
                          final color = item.isDestructive
                              ? Colors.red
                              : theme.colorScheme.onSurface;
                          return InkWell(
                            onTap: () => widget.onSelected(item.action),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Icon(item.icon, size: 20, color: color),
                                  const SizedBox(width: 12),
                                  Text(
                                    item.label,
                                    style:
                                        TextStyle(color: color, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        if (widget.seenEntries.isNotEmpty ||
                            widget.editedAt != null) ...[
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: theme.colorScheme.outline.withValues(alpha: 0.15),
                          ),
                          if (widget.seenEntries.isNotEmpty)
                            _SeenByMenuRow(entries: widget.seenEntries),
                          if (widget.seenEntries.isNotEmpty &&
                              widget.editedAt != null)
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: theme.colorScheme.outline.withValues(alpha: 0.08),
                            ),
                          if (widget.editedAt != null)
                            _EditedAtRow(editedAt: widget.editedAt!),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SeenByMenuRow extends StatefulWidget {
  final List<_SeenEntry> entries;

  const _SeenByMenuRow({required this.entries});

  @override
  State<_SeenByMenuRow> createState() => _SeenByMenuRowState();
}

class _SeenByMenuRowState extends State<_SeenByMenuRow> {
  OverlayEntry? _submenu;
  Timer? _closeTimer;

  static const _submenuWidth = 240.0;
  static const _gap = 6.0;

  void _showSubmenu() {
    _closeTimer?.cancel();
    _closeTimer = null;
    if (_submenu != null) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final rowTopLeft = renderBox.localToGlobal(Offset.zero);
    final rowSize = renderBox.size;
    final screen = MediaQuery.sizeOf(context);

    final openRight =
        rowTopLeft.dx + rowSize.width + _gap + _submenuWidth <= screen.width;

    final left = openRight
        ? rowTopLeft.dx + rowSize.width + _gap
        : rowTopLeft.dx - _submenuWidth - _gap;

    const itemHeight = 52.0;
    const maxSubmenuHeight = 360.0;
    final submenuHeight = min(
      widget.entries.length * itemHeight + 16.0,
      maxSubmenuHeight,
    );
    final topMax = (screen.height - submenuHeight - 8).clamp(8.0, double.infinity);
    final top = rowTopLeft.dy.clamp(8.0, topMax);

    _submenu = OverlayEntry(
      builder: (ctx) => _SeenBySubmenuOverlay(
        left: left,
        top: top,
        openRight: openRight,
        entries: widget.entries,
        onMouseEnter: _cancelClose,
        onMouseExit: _scheduleClose,
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(_submenu!);
    if (mounted) setState(() {});
  }

  void _scheduleClose() {
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(milliseconds: 200), () {
      _submenu?.remove();
      _submenu = null;
      if (mounted) setState(() {});
    });
  }

  void _cancelClose() {
    _closeTimer?.cancel();
    _closeTimer = null;
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _submenu?.remove();
    _submenu = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = widget.entries;
    final isOpen = _submenu != null;

    final seenUserIds = entries.map((e) => e.receipt.user.id).toSet();
    final reactedUserIds = entries
        .where((e) => e.hasReaction)
        .map((e) => e.receipt.user.id)
        .toSet();

    final totalUsers = seenUserIds.length;
    final reactedUsers = reactedUserIds.length;
    final hasAnyReaction = reactedUsers > 0;

    final seenSet = <String>{};
    final uniqueUsers = entries
        .where((e) => seenSet.add(e.receipt.user.id))
        .toList();

    const maxAvatars = 3;
    const avatarSize = 18.0;
    const ringWidth = 1.5;
    const totalAvatarSize = avatarSize + ringWidth * 2;
    const step = 12.0;

    final displayEntries = uniqueUsers.take(maxAvatars).toList();
    final stackWidth =
        totalAvatarSize + (displayEntries.length - 1) * step;

    final iconColor = theme.colorScheme.onSurface;

    return GestureDetector(
      onTap: () => _submenu == null ? _showSubmenu() : _scheduleClose(),
      child: MouseRegion(
        onEnter: (_) => _showSubmenu(),
        onExit: (_) => _scheduleClose(),
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        color: isOpen
            ? theme.colorScheme.onSurface.withValues(alpha: 0.08)
            : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                hasAnyReaction ? TablerIcons.mood_smile : TablerIcons.eye,
                size: 20,
                color: iconColor,
              ),
              const SizedBox(width: 12),
              Text(
                hasAnyReaction ? '$reactedUsers/$totalUsers' : '$totalUsers',
                style: TextStyle(fontSize: 14, color: iconColor),
              ),
              const Spacer(),
              // Stacked overlapping avatars aligned to the right
              SizedBox(
                width: stackWidth,
                height: totalAvatarSize,
                child: Stack(
                  children: [
                    for (int i = displayEntries.length - 1; i >= 0; i--)
                      Positioned(
                        left: i * step,
                        child: Container(
                          padding: const EdgeInsets.all(ringWidth),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOpen
                                ? theme.colorScheme.surfaceContainerHigh
                                : theme.colorScheme.surfaceContainer,
                          ),
                          child: Avatar(
                            mxContent: displayEntries[i].receipt.user.avatarUrl,
                            name: displayEntries[i].receipt.user.calcDisplayname(),
                            size: avatarSize,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _SeenBySubmenuOverlay extends StatelessWidget {
  final double left;
  final double top;
  final bool openRight;
  final List<_SeenEntry> entries;
  final VoidCallback onMouseEnter;
  final VoidCallback onMouseExit;

  const _SeenBySubmenuOverlay({
    required this.left,
    required this.top,
    required this.openRight,
    required this.entries,
    required this.onMouseEnter,
    required this.onMouseExit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOutCubic,
            builder: (ctx, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(openRight ? (1 - t) * 8 : (t - 1) * 8, 0),
                child: child,
              ),
            ),
            child: MouseRegion(
              onEnter: (_) => onMouseEnter(),
              onExit: (_) => onMouseExit(),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: theme.colorScheme.surfaceContainer,
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 200,
                    maxWidth: 240,
                    maxHeight: 360,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: entries
                            .map((e) => _SeenByUserRow(entry: e))
                            .toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SeenByUserRow extends StatelessWidget {
  final _SeenEntry entry;

  const _SeenByUserRow({required this.entry});

  void _openProfile(BuildContext context) => UserDialog.show(
        context: context,
        profile: Profile(
          userId: entry.receipt.user.id,
          displayName: entry.receipt.user.displayName,
          avatarUrl: entry.receipt.user.avatarUrl,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = entry.reaction;
    final displayTime = r?.time != null
        ? r!.time!.localizedTime(context)
        : entry.receipt.time.localizedTime(context);

    Widget rightWidget;
    if (r != null) {
      if (r.key.startsWith('mxc://')) {
        rightWidget = MxcImage(
          uri: Uri.parse(r.key),
          width: 20,
          height: 20,
          animated: false,
          isThumbnail: false,
        );
      } else {
        final display = r.key.characters.length > 2
            ? r.key.characters.getRange(0, 2).toString()
            : r.key;
        rightWidget = Text(display, style: const TextStyle(fontSize: 18));
      }
    } else {
      rightWidget = Icon(
        TablerIcons.checks,
        size: 15,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
      );
    }

    return InkWell(
      onTap: () => _openProfile(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Avatar(
              mxContent: entry.receipt.user.avatarUrl,
              name: entry.receipt.user.calcDisplayname(),
              size: 32,
              onTap: () => _openProfile(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.receipt.user.calcDisplayname(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    displayTime,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            rightWidget,
          ],
        ),
      ),
    );
  }
}

class _EditedAtRow extends StatelessWidget {
  final DateTime editedAt;

  const _EditedAtRow({required this.editedAt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Icon(TablerIcons.clock_edit, size: 16, color: color),
          const SizedBox(width: 10),
          Text(
            editedAt.localizedTime(context),
            style: TextStyle(fontSize: 13, color: color),
          ),
        ],
      ),
    );
  }
}
