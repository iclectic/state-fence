import 'package:meta/meta.dart';

/// A rule that permits a transition from one concrete state type to another.
///
/// Rules are compared by runtime [Type], so state classes must be
/// distinguishable by their type. Use the top-level [allow] helper to create
/// instances.
@immutable
final class TransitionRule {
  /// The state type this rule permits a transition from.
  final Type from;

  /// The state type this rule permits a transition to.
  final Type to;

  /// An optional human-readable name for this rule.
  ///
  /// This is a descriptive label for the rule itself. It is never written to
  /// violations or timeline events, so it cannot leak into diagnostics.
  final String? name;

  /// Optional descriptive metadata kept with this rule.
  ///
  /// The map is stored unmodifiable. Like [name], it is never copied into
  /// violations or timeline events; it is there for callers that build or
  /// inspect rule sets programmatically. Application state must never be
  /// captured here.
  final Map<String, Object?>? metadata;

  /// Creates a rule that permits a transition from [from] to [to].
  TransitionRule({
    required this.from,
    required this.to,
    this.name,
    Map<String, Object?>? metadata,
  }) : metadata = metadata == null
            ? null
            : Map<String, Object?>.unmodifiable(metadata);

  /// Whether this rule permits a transition from [from] to [to].
  bool allows(Type from, Type to) => from == this.from && to == this.to;

  /// A string representation, such as `TransitionRule(Idle -> Loading)`.
  @override
  String toString() => name == null
      ? 'TransitionRule($from -> $to)'
      : 'TransitionRule($name: $from -> $to)';
}

/// Creates a [TransitionRule] that permits a transition from [F] to [T].
///
/// The state classes [F] and [T] should be subtypes of the state domain used
/// with [StateFence]. Rule mismatches are detected at transition time, so the
/// helper does not enforce the bound at compile time.
TransitionRule allow<F, T>({String? name, Map<String, Object?>? metadata}) =>
    TransitionRule(from: F, to: T, name: name, metadata: metadata);
