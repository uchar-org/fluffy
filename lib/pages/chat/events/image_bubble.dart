import 'package:fluffychat/pages/chat/events/message.dart';
import 'package:fluffychat/pages/chat/events/message_status.dart';
import 'package:flutter/material.dart';

import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:matrix/matrix.dart';

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/pages/image_viewer/image_viewer.dart';
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
    super.key,
  });

  Widget _buildPlaceholder(BuildContext context) {
    final String blurHashString =
        event.infoMap['xyz.amorgan.blurhash'] is String
        ? event.infoMap['xyz.amorgan.blurhash']
        : 'LEHV6nWB2yk8pyo0adR*.7kCMdnj';
    return SizedBox(
      width: width,
      height: height,
      child: BlurHash(
        blurhash: blurHashString,
        width: width,
        height: height,
        fit: fit,
      ),
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
      builder: (_) =>
          ImageViewer(event, timeline: timeline, outerContext: context),
    );
  }

  @override
  Widget build(BuildContext context) {
    var borderRadius =
        this.borderRadius ?? BorderRadius.circular(AppConfig.borderRadius);

    final imageBorderRadius = BorderRadius.only(
      topLeft: Radius.circular(AppConfig.borderRadius - 2),
      topRight: Radius.circular(AppConfig.borderRadius - 2),
      bottomLeft: Radius.circular(AppConfig.borderRadius / 2),
      bottomRight: Radius.circular(AppConfig.borderRadius / 2),
    );

    final fileDescription = event.fileDescription;
    final textColor = this.textColor;

    if (fileDescription != null) {
      borderRadius = borderRadius.copyWith(
        bottomLeft: Radius.zero,
        bottomRight: Radius.zero,
      );
    }

    final messageTime = event.originServerTs;
    final formattedTime =
        "${messageTime.hour.toString().padLeft(2, '0')}:${messageTime.minute.toString().padLeft(2, '0')}";

    return Column(
      mainAxisSize: .min,
      spacing: 6,
      children: [
        Material(
          color: Colors.transparent,
          clipBehavior: Clip.hardEdge,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          child: InkWell(
            onTap: () => _onTap(context),
            borderRadius: borderRadius,
            child: Padding(
              padding: const EdgeInsets.all(2.5),
              child: Hero(
                tag: event.eventId,
                child: ClipRRect(
                  borderRadius: imageBorderRadius,
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
                        placeholder: event.messageType == MessageTypes.Sticker
                            ? null
                            : _buildPlaceholder,
                      ),

                      if (fileDescription == null)
                        Padding(
                          padding: const EdgeInsets.only(
                            right: 8.0,
                            bottom: 8.0,
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: .3),
                              borderRadius: BorderRadius.all(
                                Radius.circular(AppConfig.borderRadius / 3),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    formattedTime,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),

                                  if (messageStatus != null) SizedBox(width: 6,),

                                  if (messageStatus != null) MessageStatusWidget(
                                    iconColor: Colors.white,
                                    status: messageStatus,
                                  ),
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
        if (fileDescription != null && textColor != null)
          SizedBox(
            width: width,
            child: Padding(
              padding: const EdgeInsets.only(left: 6, right: 12,),
              child: SizedBox(
                width: double.infinity,
                child: Wrap(
                  // alignment: WrapAlignment.end,
                  alignment: WrapAlignment.start,
                  children: [
                    Linkify(
                      text: fileDescription,
                      textScaleFactor: MediaQuery.textScalerOf(
                        context,
                      ).scale(1),
                      style: TextStyle(
                        color: textColor,
                        fontSize:
                            AppSettings.fontSizeFactor.value *
                            AppConfig.messageFontSize,
                      ),
                      options: const LinkifyOptions(humanize: false),
                      linkStyle: TextStyle(
                        color: linkColor,
                        fontSize:
                            AppSettings.fontSizeFactor.value *
                            AppConfig.messageFontSize,
                        decoration: TextDecoration.underline,
                        decorationColor: linkColor,
                      ),
                      onOpen: (url) =>
                          UrlLauncher(context, url.url).launchUrl(),
                    ),

                    Align(
                      alignment: Alignment.topRight,
                      child: Transform.translate(
                        offset: const Offset(0, -15),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formattedTime,
                              style: TextStyle(
                                color: textColor,
                                fontSize:
                                    AppSettings.fontSizeFactor.value *
                                    (AppConfig.messageFontSize - 5),
                              ),
                            ),
                        
                            const SizedBox(
                              width: 6,
                            ),
                        
                            MessageStatusWidget(
                              iconColor: textColor,
                              status: messageStatus,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}