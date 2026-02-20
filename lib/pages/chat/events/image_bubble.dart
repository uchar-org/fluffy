import 'package:fluffychat/pages/chat/events/html_message.dart';
import 'package:fluffychat/pages/chat/events/message.dart';
import 'package:fluffychat/pages/chat/events/message_status.dart';
import 'package:fluffychat/pages/image_viewer/image_viewer.dart';
import 'package:fluffychat/utils/event_checkbox_extension.dart';
import 'package:fluffychat/utils/html_cleaner.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/utils/file_description.dart';
import 'package:fluffychat/utils/url_launcher.dart';
import 'package:fluffychat/widgets/mxc_image.dart';
import '../../../widgets/blur_hash.dart';

class ImageBubble extends StatelessWidget {
  final Event event;
  final bool tapToView;
  final BoxFit fit;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? linkColor;
  final bool thumbnailOnly;
  final bool animated;
  final double width;
  final double height;
  final void Function()? onTap;
  final BorderRadius? borderRadius;
  final Timeline? timeline;
  final MessageStatus? messageStatus;
  final bool selected;

  const ImageBubble(
    this.event, {
    this.tapToView = true,
    this.backgroundColor,
    this.fit = BoxFit.contain,
    this.thumbnailOnly = true,
    this.width = 400,
    this.height = 300,
    this.animated = false,
    this.onTap,
    this.borderRadius,
    this.timeline,
    this.textColor,
    this.linkColor,
    this.messageStatus,
    required this.selected,
    super.key,
  });

  Widget _buildPlaceholder(BuildContext context) {
    final blurHashString = event.infoMap.tryGet<String>('xyz.amorgan.blurhash') ?? 'LEHV6nWB2yk8pyo0adR*.7kCMdnj';
    return SizedBox(
      width: width,
      height: height,
      child: BlurHash(blurhash: blurHashString, width: width, height: height, fit: fit),
    );
  }

  void _onTap(BuildContext context) {
    if (onTap != null) {
      onTap!();
      return;
    }
    if (!tapToView) return;
    showDialog(
      context: context,
      builder: (_) => ImageViewer(event, timeline: timeline, outerContext: context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = this.borderRadius ?? BorderRadius.circular(AppConfig.borderRadius);

    final fileDescription = event.fileDescription;
    final textColor = this.textColor;

    final messageTime = event.originServerTs;
    final formattedTime =
        "${messageTime.hour.toString().padLeft(2, '0')}:${messageTime.minute.toString().padLeft(2, '0')}";

    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: .min,
        children: [
          SizedBox(
            height: height,
            width: width,
            child: Material(
              color: Colors.transparent,
              clipBehavior: Clip.hardEdge,
              shape: RoundedRectangleBorder(borderRadius: borderRadius),
              child: InkWell(
                onTap: () => _onTap(context),
                borderRadius: borderRadius,
                child: Padding(
                  padding: const EdgeInsets.all(AppConfig.imageMessagePadding),
                  child: Hero(
                    tag: event.eventId,
                    child: ClipRRect(
                      borderRadius: borderRadius,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          MxcImage(
                            event: event,
                            width: width,
                            height: height,
                            fit: fit,
                            animated: animated,
                            isThumbnail: thumbnailOnly,
                            placeholder: event.messageType == MessageTypes.Sticker ? null : _buildPlaceholder,
                          ),

                          if (fileDescription == null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: .3),
                                  borderRadius: BorderRadius.all(Radius.circular(AppConfig.borderRadius / 3)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(formattedTime, style: TextStyle(color: Colors.white, fontSize: 10)),

                                      if (messageStatus != null) SizedBox(width: 6),

                                      if (messageStatus != null)
                                        MessageStatusWidget(iconColor: Colors.white, status: messageStatus),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          Builder(
            builder: (context) {
              if (fileDescription != null && textColor != null) {
                var html = AppSettings.renderHtml.value && event.isRichMessage
                    ? event.formattedText
                    : event.body.replaceAll('<', '&lt;').replaceAll('>', '&gt;');

                // clearing for reply
                if (html.startsWith("<mx-reply>")) {
                  html = stripMxReply(html);
                }

                if (event.messageType == MessageTypes.Emote) {
                  html = '* $html';
                }

                final bigEmotes = event.onlyEmotes && event.numberEmotes > 0 && event.numberEmotes <= 3;

                return SizedBox(
                  width: width,
                  child: Padding(
                    padding: EdgeInsets.only(left: 6, right: 6, bottom: 12),
                    child: Stack(
                      children: [
                        HtmlMessage(
                          html: fileDescription,
                          textColor: textColor,
                          room: event.room,
                          fontSize: AppSettings.fontSizeFactor.value * AppConfig.messageFontSize * (bigEmotes ? 5 : 1),
                          limitHeight: !selected,
                          linkStyle: TextStyle(
                            color: linkColor,
                            fontSize: AppSettings.fontSizeFactor.value * AppConfig.messageFontSize,
                            decoration: TextDecoration.underline,
                            decorationColor: linkColor,
                          ),
                          onOpen: (url) => UrlLauncher(context, url.url).launchUrl(),
                          eventId: event.eventId,
                          checkboxCheckedEvents: event.aggregatedEvents(
                            timeline!,
                            EventCheckboxRoomExtension.relationshipType,
                          ),
                          trailingWidget: SizedBox(width: 42, height: 14),
                        ),

                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                formattedTime,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: AppSettings.fontSizeFactor.value * (AppConfig.messageFontSize - 5),
                                ),
                              ),

                              if (messageStatus != null) const SizedBox(width: 4),

                              if (messageStatus != null)
                                MessageStatusWidget(status: messageStatus, iconColor: textColor),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                return SizedBox();
              }
            },
          ),
        ],
      ),
    );
  }
}
