import 'package:matrix/matrix.dart';

import 'package:fluffychat/config/setting_keys.dart';

extension VisibleInGuiExtension on List<Event> {
  List<Event> filterByVisibleInGui({
    String? exceptionEventId,
    String? threadId,
  }) => where((event) {
    if (threadId != null &&
        event.relationshipType != RelationshipTypes.reaction) {
      if ((event.relationshipType != RelationshipTypes.thread ||
              event.relationshipEventId != threadId) &&
          event.eventId != threadId) {
        return false;
      }
    } else if (event.relationshipType == RelationshipTypes.thread) {
      return false;
    }
    return event.isVisibleInGui || event.eventId == exceptionEventId;
  }).toList();
}

extension IsStateExtension on Event {
  bool get isVisibleInGui =>
      // always filter out edit and reaction relationships
      !{
        RelationshipTypes.edit,
        RelationshipTypes.reaction,
      }.contains(relationshipType) &&
      // always filter out m.key.* and other known but unimportant events
      !isKnownHiddenStates &&
      // event types to hide: redaction and reaction events
      // if a reaction has been redacted we also want it to be hidden in the timeline
      !{EventTypes.Reaction, EventTypes.Redaction}.contains(type) &&
      // if we enabled to hide all redacted events, don't show those
      (!AppSettings.hideRedactedEvents.value || !redacted) &&
      // if we enabled to hide all unknown events, don't show those
      // but always show call notification events (custom MSC types)
      (!AppSettings.hideUnknownEvents.value ||
          isEventTypeKnown ||
          _isCallNotifyEvent);

  /// Check if this is a call notification event that should always be visible
  bool get _isCallNotifyEvent => {
    'org.matrix.msc4075.call.notify',
    'org.matrix.msc4075.rtc.notification',
  }.contains(type);

  /// Get call_id from call notification event for deduplication
  String? get callSessionId {
    if (!_isCallNotifyEvent) return null;
    // Try direct call_id first
    final directId = content.tryGet<String>('call_id');
    if (directId != null) return directId;
    // Fall back to m.relates_to.event_id (RTC member event reference)
    return content
        .tryGetMap<String, dynamic>('m.relates_to')
        ?.tryGet<String>('event_id');
  }

  bool get isState => !{
    EventTypes.Message,
    EventTypes.Sticker,
    EventTypes.Encrypted,
    'org.matrix.msc4075.call.notify',
    'org.matrix.msc4075.rtc.notification',
  }.contains(type);

  bool get isCollapsedState => !{
    EventTypes.Message,
    EventTypes.Sticker,
    EventTypes.Encrypted,
    EventTypes.RoomCreate,
    EventTypes.RoomTombstone,
  }.contains(type);

  bool get isKnownHiddenStates =>
      {PollEventContent.responseType}.contains(type) ||
      type.startsWith('m.key.verification.');
}

extension CallEventDeduplication on List<Event> {
  /// Deduplicate call notification events - show only LATEST event per call session
  List<Event> deduplicateCallEvents() {
    final callIdToEvent = <String, Event>{};

    // Iterate through all events, last one wins
    for (final event in this) {
      final callId = event.callSessionId;
      if (callId == null) continue;
      callIdToEvent[callId] = event; // Overwrite with latest
    }

    // Return list with non-call events + latest call event per session
    return where((event) {
      final callId = event.callSessionId;
      if (callId == null) return true; // Not a call event, keep
      return callIdToEvent[callId] == event; // Keep if this is the latest
    }).toList();
  }
}
