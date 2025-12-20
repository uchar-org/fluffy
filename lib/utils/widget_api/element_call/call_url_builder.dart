import 'package:matrix/matrix.dart';

import 'package:fluffychat/utils/element_call/call_service.dart';

/// Build Element Call widget URL
class CallUrlBuilder {
  /// Build Element Call URL for a room
  static String build({
    required Room room,
    required String widgetId,
    required String deviceId,
    required String baseUrl,
    required String parentUrl,
    String? theme,
  }) {
    final callUrl = baseUrl;
    final homeserver = room.client.homeserver;

    if (homeserver == null) {
      throw Exception('Client homeserver is null');
    }

    // Enable E2EE if room is encrypted (cross-signing not required)
    final enableE2EE = room.encrypted;

    final params = {
      'roomId': room.id,
      'userId': room.client.userID!,
      'deviceId': deviceId,
      'baseUrl': homeserver.toString(),
      'widgetId': widgetId,
      'perParticipantE2EE': enableE2EE.toString(),
      'intent': CallService.hasActiveCall(room)
          ? 'join'
          : (room.isDirectChat ? 'start_call_dm' : 'start_call'),
      'confineToRoom': 'true',
      'hideHeader': 'true',
      'preload': 'false',
      'appPrompt': 'false',
      'fontScale': '1',
      'lang': 'en',
      'theme': theme ?? '\$org.matrix.msc2873.client_theme',
      'parentUrl': parentUrl,
    };

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return '$callUrl/room/#/${Uri.encodeComponent(room.id)}?$query';
  }

  /// Build wrapper HTML URL with widget URL as parameter
  static String buildWrapperUrl({
    required String wrapperHtmlPath,
    required String widgetUrl,
    String? parentUrl,
  }) {
    final params = <String, String>{};

    if (parentUrl != null) {
      params['parentUrl'] = parentUrl;
    }

    final query = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';

    return '$wrapperHtmlPath$query';
  }
}
