import 'dart:convert';

import 'fence_event.dart';
import 'redactor.dart';
import 'timeline.dart';
import 'violation.dart';

/// Exports a [Timeline] as a JSON-encoded string with metadata redaction.
///
/// Events are serialised in insertion order. Each event object includes its
/// `kind`, `source`, `timestamp` (ISO 8601), optional `operation` and a
/// redacted `metadata` map. Event-specific fields are included as documented
/// on each [FenceEvent] subtype.
String exportTimelineJson(
  Timeline timeline, {
  MetadataRedactor redactor = const MetadataRedactor(),
}) {
  final list = timeline.events.map((e) => _encodeEvent(e, redactor)).toList();
  return JsonEncoder.withIndent('  ').convert(list);
}

Map<String, Object?> _encodeEvent(FenceEvent event, MetadataRedactor redactor) {
  final map = <String, Object?>{
    'kind': event.kind,
    'source': event.source,
    'timestamp': event.timestamp.toIso8601String(),
    if (event.operation != null) 'operation': event.operation,
    'metadata': redactor.redact(event.metadata),
  };

  switch (event) {
    case TransitionAcceptedEvent():
      map['fromState'] = event.fromState.toString();
      map['toState'] = event.toState.toString();
    case TransitionRejectedEvent():
      map['violation'] = _encodeViolation(event.violation, redactor);
    case OperationStartedEvent():
      map['token'] = event.token.value;
    case OperationSucceededEvent():
      map['token'] = event.token.value;
    case OperationFailedEvent():
      map['token'] = event.token.value;
      map['errorDescription'] = event.errorDescription;
    case OperationIgnoredAsStaleEvent():
      map['token'] = event.token.value;
      map['supersededBy'] = event.supersededBy.value;
    case OperationIgnoredAsDuplicateEvent():
      map['token'] = event.token.value;
      map['blockedBy'] = event.blockedBy.value;
    case OperationTimedOutEvent():
      map['token'] = event.token.value;
    case OwnerDisposedEvent():
      // No additional fields.
      break;
  }

  return map;
}

Map<String, Object?> _encodeViolation(
  StateFenceViolation violation,
  MetadataRedactor redactor,
) {
  return <String, Object?>{
    'fenceName': violation.fenceName,
    'previousState': violation.previousState.toString(),
    'attemptedState': violation.attemptedState.toString(),
    'reason': violation.reason,
    if (violation.operation != null) 'operation': violation.operation,
    'safeMetadata': redactor.redact(violation.safeMetadata),
  };
}
