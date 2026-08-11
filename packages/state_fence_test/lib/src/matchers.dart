import 'package:matcher/matcher.dart';
import 'package:state_fence/state_fence.dart';

/// Matches a [StateFence] that currently allows a transition from [F] to [T].
///
/// ```dart
/// expect(fence, allowsTransition<Idle, Loading>());
/// ```
Matcher allowsTransition<F, T>() => _TransitionRuleMatcher<F, T>(true);

/// Matches a [StateFence] that has no rule permitting a transition from [F]
/// to [T].
///
/// ```dart
/// expect(fence, rejectsTransition<Success, Loading>());
/// ```
Matcher rejectsTransition<F, T>() => _TransitionRuleMatcher<F, T>(false);

/// Matches an [OperationOutcome] that is an [OperationSuccess].
///
/// Optionally matches the success [value].
Matcher isOperationSuccess({Object? value}) =>
    _OutcomeMatcher<OperationSuccess<Object?>>(
      'OperationSuccess',
      value == null
          ? null
          : (outcome) => (outcome as OperationSuccess).value == value,
      value == null ? null : 'with value $value',
    );

/// Matches an [OperationOutcome] that is an [OperationFailure].
const Matcher isOperationFailure =
    _OutcomeMatcher<OperationFailure<Object?>>('OperationFailure', null, null);

/// Matches an [OperationOutcome] that is an [OperationIgnoredAsStale].
const Matcher isIgnoredAsStale =
    _OutcomeMatcher<OperationIgnoredAsStale<Object?>>(
        'OperationIgnoredAsStale', null, null);

/// Matches an [OperationOutcome] that is an [OperationIgnoredAsDuplicate].
const Matcher isIgnoredAsDuplicate =
    _OutcomeMatcher<OperationIgnoredAsDuplicate<Object?>>(
        'OperationIgnoredAsDuplicate', null, null);

/// Matches an [OperationOutcome] that is an [OperationTimedOut].
const Matcher isOperationTimedOut = _OutcomeMatcher<OperationTimedOut<Object?>>(
    'OperationTimedOut', null, null);

/// Matches a [CollectingReporter] or a list of violations containing no
/// violations at all.
const Matcher hasNoViolations = _NoViolationsMatcher();

class _TransitionRuleMatcher<F, T> extends Matcher {
  final bool expectAllowed;

  const _TransitionRuleMatcher(this.expectAllowed);

  @override
  bool matches(Object? item, Map<Object?, Object?> matchState) {
    if (item is! StateFence) return false;
    return item.wouldAllow(from: F, to: T) == expectAllowed;
  }

  @override
  Description describe(Description description) => description.add(
        expectAllowed
            ? 'a StateFence allowing $F -> $T'
            : 'a StateFence rejecting $F -> $T',
      );
}

class _OutcomeMatcher<O> extends Matcher {
  final String label;
  final bool Function(Object outcome)? extraCheck;
  final String? extraDescription;

  const _OutcomeMatcher(this.label, this.extraCheck, this.extraDescription);

  @override
  bool matches(Object? item, Map<Object?, Object?> matchState) {
    if (item is! O) return false;
    final check = extraCheck;
    return check == null || check(item as Object);
  }

  @override
  Description describe(Description description) {
    description.add('an $label');
    if (extraDescription != null) {
      description.add(' $extraDescription');
    }
    return description;
  }
}

class _NoViolationsMatcher extends Matcher {
  const _NoViolationsMatcher();

  @override
  bool matches(Object? item, Map<Object?, Object?> matchState) {
    if (item is List<StateFenceViolation>) return item.isEmpty;
    return false;
  }

  @override
  Description describe(Description description) =>
      description.add('an empty list of StateFence violations');
}
