import 'package:matcher/matcher.dart';
import 'package:state_fence/state_fence.dart';

import 'collecting_reporter.dart';

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

/// Sentinel meaning "no value expectation was supplied".
///
/// This distinguishes `isOperationSuccess()` from `isOperationSuccess(value:
/// null)`, which asserts that the success value really is `null`.
const Object _unspecified = Object();

/// Matches an [OperationOutcome] that is an [OperationSuccess].
///
/// When [value] is supplied, the success value must also match it. A [Matcher]
/// is applied as a matcher; any other object is compared with `==`, so
/// `isOperationSuccess(value: null)` matches only a success carrying `null`.
///
/// ```dart
/// expect(outcome, isOperationSuccess(value: 42));
/// expect(outcome, isOperationSuccess(value: greaterThan(10)));
/// ```
Matcher isOperationSuccess({Object? value = _unspecified}) =>
    _OutcomeMatcher<OperationSuccess<Object?>>(
      'OperationSuccess',
      identical(value, _unspecified)
          ? null
          : (outcome) => wrapMatcher(value)
              .matches((outcome as OperationSuccess).value, {}),
      identical(value, _unspecified) ? null : 'with value $value',
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

/// Matches a [CollectingReporter] or an [Iterable] of violations that holds no
/// violations at all.
///
/// ```dart
/// expect(reporter, hasNoViolations);
/// expect(reporter.violations, hasNoViolations);
/// ```
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
    if (check != null && !check(item as Object)) {
      matchState['wrongValue'] = true;
      return false;
    }
    return true;
  }

  @override
  Description describe(Description description) {
    description.add('an $label');
    if (extraDescription != null) {
      description.add(' $extraDescription');
    }
    return description;
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<Object?, Object?> matchState,
    bool verbose,
  ) {
    if (matchState['wrongValue'] == true) {
      return mismatchDescription.add('is $item with a different value');
    }
    if (item is OperationOutcome) {
      return mismatchDescription.add('is ${item.runtimeType}: $item');
    }
    return mismatchDescription.add('is not an OperationOutcome');
  }
}

class _NoViolationsMatcher extends Matcher {
  const _NoViolationsMatcher();

  @override
  bool matches(Object? item, Map<Object?, Object?> matchState) {
    final violations = _violationsOf(item);
    if (violations == null) return false;
    matchState['violations'] = violations;
    return violations.isEmpty;
  }

  @override
  Description describe(Description description) =>
      description.add('a source reporting no StateFence violations');

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<Object?, Object?> matchState,
    bool verbose,
  ) {
    final violations = matchState['violations'];
    if (violations is! List<StateFenceViolation>) {
      return mismatchDescription
          .add('is not a CollectingReporter or an iterable of violations');
    }
    mismatchDescription.add('reported ${violations.length} violation(s):');
    for (final violation in violations) {
      mismatchDescription
          .add('\n  ${violation.runtimeType}: ${violation.reason}');
    }
    return mismatchDescription;
  }

  List<StateFenceViolation>? _violationsOf(Object? item) {
    if (item is CollectingReporter) return item.violations;
    if (item is Iterable<StateFenceViolation>) return item.toList();
    // An empty literal such as `[]` is a List<dynamic>, so fall back to an
    // element check rather than rejecting it outright.
    if (item is Iterable && item.every((e) => e is StateFenceViolation)) {
      return item.cast<StateFenceViolation>().toList();
    }
    return null;
  }
}
