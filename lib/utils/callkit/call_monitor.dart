import 'dart:async';

import 'package:matrix/matrix.dart';

import '../platform_infos.dart';
import 'callkit_service.dart';

/// Monitors Matrix sync events for incoming calls and triggers CallKit.
/// This handles the foreground case when push notifications don't trigger.
class CallMonitor {
  static CallMonitor? _instance;
  static CallMonitor get instance => _instance ??= CallMonitor._();

  CallMonitor._();

  StreamSubscription? _syncSub;
  Client? _client;

  // De-duplication: track recently shown calls (roomId -> timestamp)
  final Map<String, DateTime> _seenCalls = {};

  // Track rooms with active calls to detect new ones
  final Set<String> _roomsWithActiveCall = {};

  void start(Client client) {
    if (!PlatformInfos.isMobile) return;

    _client = client;
    Logs().i('[CallMonitor] Starting call monitor');

    // Initialize current call state
    _initializeCallState(client);

    // Subscribe to sync events
    _syncSub = client.onSync.stream.listen(_checkForIncomingCalls);
  }

  void _initializeCallState(Client client) {
    // Record which rooms already have active calls
    for (final room in client.rooms) {
      if (_hasActiveCall(room)) {
        _roomsWithActiveCall.add(room.id);
      }
    }
    Logs().d(
      '[CallMonitor] Initialized with ${_roomsWithActiveCall.length} active calls',
    );
  }

  void _checkForIncomingCalls(SyncUpdate sync) {
    final client = _client;
    if (client == null) return;

    // Check joined rooms for call.member state changes
    final joinedRooms = sync.rooms?.join;
    if (joinedRooms == null) return;

    for (final entry in joinedRooms.entries) {
      final roomId = entry.key;
      final roomUpdate = entry.value;

      // Check state events for call.member
      final stateEvents = roomUpdate.state;
      if (stateEvents != null) {
        for (final event in stateEvents) {
          if (event.type == 'org.matrix.msc3401.call.member') {
            _handleCallMemberEvent(client, roomId, event);
          }
        }
      }

      // Check timeline events for call.notify (MSC4075)
      final timelineEvents = roomUpdate.timeline?.events;
      if (timelineEvents != null) {
        for (final event in timelineEvents) {
          if (event.type == 'org.matrix.msc4075.call.notify' ||
              event.type == 'org.matrix.msc4075.rtc.notification') {
            _handleCallNotifyEvent(client, roomId, event);
          }
        }
      }
    }
  }

  void _handleCallNotifyEvent(
    Client client,
    String roomId,
    MatrixEvent event,
  ) {
    Logs().d('[CallMonitor] call.notify event in room $roomId');

    final content = event.content;
    final notifyType = content['notify_type'] as String?;

    // Only show CallKit for "ring" type
    if (notifyType != 'ring') {
      Logs().v('[CallMonitor] Ignoring non-ring notify: $notifyType');
      return;
    }

    // Skip own events
    final senderId = event.senderId;
    if (senderId == client.userID) {
      Logs().v('[CallMonitor] Skipping own call.notify event');
      return;
    }

    // De-duplication check
    final lastSeen = _seenCalls[roomId];
    if (lastSeen != null &&
        DateTime.now().difference(lastSeen).inSeconds < 5) {
      Logs().v('[CallMonitor] Already processed call.notify in room $roomId');
      return;
    }

    // Mark as seen
    _seenCalls[roomId] = DateTime.now();

    // Clean up old seen calls
    _seenCalls.removeWhere(
      (key, value) => DateTime.now().difference(value).inMinutes > 1,
    );

    // Get room and show CallKit
    final room = client.getRoomById(roomId);
    if (room == null) {
      Logs().w('[CallMonitor] Room not found: $roomId');
      return;
    }

    // Get caller details
    final caller = room.getState('m.room.member', senderId);
    final callerName = caller?.content['displayname'] as String?;
    final callerAvatarUrl = caller?.content['avatar_url'] as String?;
    final callerAvatar =
        callerAvatarUrl != null ? Uri.tryParse(callerAvatarUrl) : null;

    Logs().i('[CallMonitor] Showing CallKit for call.notify in room $roomId');

    // Show CallKit
    CallKitService.instance.showIncomingCall(
      room: room,
      callerName: callerName,
      callerAvatar: callerAvatar,
    );
  }

  Future<void> _handleCallMemberEvent(
    Client client,
    String roomId,
    MatrixEvent event,
  ) async {
    Logs().d('[CallMonitor] call.member event in room $roomId');

    final content = event.content;

    // Empty content = call ended
    if (content.isEmpty) {
      Logs().v('[CallMonitor] Call ended in room $roomId');
      _roomsWithActiveCall.remove(roomId);
      // End CallKit if still ringing (remote hangup before answer)
      await CallKitService.instance.endCallByRoomId(roomId);
      return;
    }

    // Skip if this room already had an active call (not new)
    if (_roomsWithActiveCall.contains(roomId)) {
      Logs().v('[CallMonitor] Room $roomId already has active call');
      return;
    }

    // Skip own device events
    final stateKey = event.stateKey;
    final userId = client.userID;
    final deviceId = client.deviceID;
    if (stateKey != null &&
        userId != null &&
        stateKey.contains(userId) &&
        deviceId != null &&
        stateKey.contains(deviceId)) {
      Logs().v('[CallMonitor] Skipping own call.member event');
      return;
    }

    // Validate call data
    final callId = content['call_id'] as String?;
    final expiresTs = content['expires_ts'] as int?;

    if (callId == null || expiresTs == null) {
      Logs().w('[CallMonitor] Invalid call.member: missing call_id or expires_ts');
      return;
    }

    // Check if expired
    final now = DateTime.now().millisecondsSinceEpoch;
    if (expiresTs < now) {
      Logs().v('[CallMonitor] Ignoring expired call');
      return;
    }

    // De-duplication check
    final lastSeen = _seenCalls[roomId];
    if (lastSeen != null &&
        DateTime.now().difference(lastSeen).inSeconds < 5) {
      Logs().v('[CallMonitor] Already processed call in room $roomId');
      return;
    }

    // Mark as seen
    _seenCalls[roomId] = DateTime.now();
    _roomsWithActiveCall.add(roomId);

    // Clean up old seen calls
    _seenCalls.removeWhere(
      (key, value) => DateTime.now().difference(value).inMinutes > 1,
    );

    // Get room and show CallKit
    final room = client.getRoomById(roomId);
    if (room == null) {
      Logs().w('[CallMonitor] Room not found: $roomId');
      return;
    }

    // Get caller details
    final senderId = event.senderId;
    final caller = room.getState('m.room.member', senderId);
    final callerName = caller?.content['displayname'] as String?;
    final callerAvatarUrl = caller?.content['avatar_url'] as String?;
    final callerAvatar =
        callerAvatarUrl != null ? Uri.tryParse(callerAvatarUrl) : null;

    Logs().i('[CallMonitor] Showing CallKit for incoming call in room $roomId');

    // Show CallKit
    CallKitService.instance.showIncomingCall(
      room: room,
      callerName: callerName,
      callerAvatar: callerAvatar,
    );
  }

  bool _hasActiveCall(Room room) {
    final callMembers = room.states['org.matrix.msc3401.call.member'];
    if (callMembers == null || callMembers.isEmpty) return false;

    final now = DateTime.now().millisecondsSinceEpoch;

    return callMembers.values.any((event) {
      final content = event.content;
      if (content.isEmpty) return false;

      final expiresTs = content['expires_ts'];
      if (expiresTs != null && expiresTs is int && expiresTs < now) {
        return false;
      }

      final app = content['application'];
      if (app is String && app == 'm.call' && content.containsKey('call_id')) {
        return true;
      }
      if (app is Map && app['type'] == 'm.call') {
        return true;
      }

      return false;
    });
  }

  void stop() {
    Logs().i('[CallMonitor] Stopping call monitor');
    _syncSub?.cancel();
    _syncSub = null;
    _client = null;
    _seenCalls.clear();
    _roomsWithActiveCall.clear();
  }
}
