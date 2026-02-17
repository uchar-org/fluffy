import 'dart:ui';

abstract class AppConfig {
  // Const and final configuration values (immutable)
  static const Color primaryColor = Color(0xFF5625BA);
  static const Color primaryColorLight = Color(0xFFCCBDEA);
  static const Color secondaryColor = Color(0xFF41a2bc);

  static const Color chatColor = primaryColor;
  static const double messageFontSize = 16.0;
  static const bool allowOtherHomeservers = true;
  static const bool enableRegistration = true;
  static const bool hideTypingUsernames = false;

  static const String inviteLinkPrefix = 'https://matrix.to/#/';
  static const String deepLinkPrefix = 'uz.uzinfocom.uchar://chat/';
  static const String schemePrefix = 'matrix:';
  static const String pushNotificationsChannelId = 'fluffychat_push';
  static const String pushNotificationsAppId = 'uz.uzinfocom.uchar';
  static const double borderRadius = 18.0;
  static const double columnWidth = 360.0;
  static const double imageMessagePadding = 2.5;
  static const double innerWidgetRadius = borderRadius - imageMessagePadding;

  static const String website = 'https://uchar.uz';
  static const String enablePushTutorial =
      // 'https://fluffy.chat/faq/#push_without_google_services';
      'https://uchar.uz';
  static const String encryptionTutorial =
      // 'https://fluffy.chat/faq/#how_to_use_end_to_end_encryption';
      'https://uchar.uz';
  static const String startChatTutorial =
      // 'https://fluffy.chat/faq/#how_do_i_find_other_users';
      'https://uchar.uz';
  static const String howDoIGetStickersTutorial =
      // 'https://fluffy.chat/faq/#how_do_i_get_stickers';
      'https://uchar.uz';
  static const String appId = 'uz.uzinfocom.uchar';
  static const String appOpenUrlScheme = 'uz.uzinfocom.uchar';

  static const String sourceCodeUrl = 'https://github.com/efael/fluffy';
  static const String supportUrl = 'https://github.com/efael/fluffy/issues';
  // static const String changelogUrl = 'https://fluffy.chat/en/changelog/';
  static const String changelogUrl = 'https://uchar.uz/';
  static const String donationUrl = 'https://ko-fi.com/krille';

  static const Set<String> defaultReactions = {'👍', '❤️', '😂', '😮', '😢'};

  static final Uri newIssueUrl = Uri(
    scheme: 'https',
    host: 'github.com',
    path: '/efael/fluffy/issues/new',
  );

  static final Uri homeserverList = Uri(
    scheme: 'https',
    host: 'servers.joinmatrix.org',
    path: 'servers.json',
  );

  static final Uri privacyUrl = Uri(
    scheme: 'https',
    // host: 'fluffy.chat',
    host: 'uchar.uz',
    path: '/en/privacy',
  );

  static const String mainIsolatePortName = 'main_isolate';
  static const String pushIsolatePortName = 'push_isolate';
}
