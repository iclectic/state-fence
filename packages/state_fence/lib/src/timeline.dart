import 'dart:collection';

import 'fence_event.dart';

/// A bounded, in-memory ring buffer of [FenceEvent]s.
///
/// The timeline keeps at most [capacity] events. When the buffer is full, the
/// oldest event is dropped as a new one is appended. This keeps memory use
/// bounded regardless of how many events are produced.
class Timeline {
  /// The maximum number of events retained.
  final int capacity;

  final Queue<FenceEvent> _events = Queue<FenceEvent>();
  int _droppedCount = 0;

  /// Creates a timeline with the given [capacity].
  ///
  /// [capacity] must be greater than zero.
  Timeline({this.capacity = 256}) : assert(capacity > 0);

  /// The events currently retained, in insertion order.
  List<FenceEvent> get events => List.unmodifiable(_events);

  /// The number of events that have been dropped because the buffer was full.
  int get droppedCount => _droppedCount;

  /// The number of events currently retained.
  int get length => _events.length;

  /// Whether the timeline is empty.
  bool get isEmpty => _events.isEmpty;

  /// Whether the timeline is non-empty.
  bool get isNotEmpty => _events.isNotEmpty;

  /// Appends [event] to the timeline, dropping the oldest event if full.
  void add(FenceEvent event) {
    while (_events.length >= capacity) {
      _events.removeFirst();
      _droppedCount++;
    }
    _events.addLast(event);
  }

  /// Removes all events from the timeline.
  void clear() {
    _events.clear();
    _droppedCount = 0;
  }
}
