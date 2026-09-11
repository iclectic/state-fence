# StateFence API Proposal

> **Status: resolved and superseded by the shipped API.**
>
> This is a historical record of the design comparison made before 0.1.0. Every recommendation below was accepted and implemented, so the document is kept for the reasoning rather than as a reference. Details here have since drifted from the code: the violation model names its origin `source` rather than `fenceName`, `TransitionRule` takes `from` and `to` arguments behind the `allow<F, T>()` helper, and resources are registered with `fenceOwner` instead of being disposed by hand.
>
> For the current API, read the [README](../README.md) and the published dartdoc.

This document compares two public API shapes for transition contracts and guarded operations.

## 1. Transition Contracts

### Shape A: Type-directed rules with `allow<From, To>()`

```dart
import 'package:state_fence/state_fence.dart';

sealed class SearchState {
  const SearchState();
  const factory SearchState.idle() = Idle;
  const factory SearchState.loading() = Loading;
  const factory SearchState.data(List<String> results) = Data;
  const factory SearchState.error(String message) = Error;
}

final class Idle extends SearchState { const Idle(); }
final class Loading extends SearchState { const Loading(); }
final class Data extends SearchState { const Data(this.results); final List<String> results; }
final class Error extends SearchState { const Error(this.message); final String message; }

final fence = StateFence<SearchState>(
  name: 'search',
  initialState: const SearchState.idle(),
  rules: [
    allow<Idle, Loading>(),
    allow<Loading, Data>(),
    allow<Loading, Error>(),
    allow<Error, Loading>(),
  ],
);

final result = fence.transition(const SearchState.loading());
if (result case TransitionAccepted()) { /* ... */ }
if (result case TransitionRejected(:final violation)) { /* ... */ }
```

**Pros**
- Very concise rule list.
- Strongly typed; a rule references concrete state classes.
- Reads naturally as "allow `Idle` to become `Loading`".

**Cons**
- Requires the state classes to be distinguishable by runtime type, which can be verbose without `sealed` classes.
- `allow<From, To>()` is generic factory syntax that may confuse less experienced Dart developers.
- Hard to add optional metadata to a rule.

### Shape B: Explicit `TransitionRule` objects

```dart
final fence = StateFence<SearchState>(
  name: 'search',
  initialState: const SearchState.idle(),
  rules: [
    TransitionRule<Idle, Loading>(),
    TransitionRule<Loading, Data>(),
    TransitionRule<Loading, Error>(),
    TransitionRule<Error, Loading>(metadata: const {'canRetry': true}),
  ],
);
```

**Pros**
- Rules are first-class objects. Metadata and descriptions can be added later without changing the `StateFence` constructor.
- Slightly more explicit; developers see the rule type rather than a generic helper.
- Easier to extend with `from: [...]` or conditional guards in the future.

**Cons**
- More verbose than Shape A.
- Requires importing the rule class explicitly.

### Recommendation

Recommend **Shape A** for the MVP because the concise `allow<From, To>()` syntax communicates intent clearly and the core can still accept the underlying `TransitionRule` instances. A public `allow()` helper can produce `TransitionRule` objects, so the rule class is still first-class under the surface.

This recommendation is provisional and may change if user testing shows the generic helper is confusing.

## 2. Guarded Asynchronous Operations

### Shape A: `GuardedOperation<T>` with an `OperationPolicy` enum

```dart
final search = GuardedOperation<List<String>>(
  name: 'search',
  policy: OperationPolicy.latestWins,
  timeout: const Duration(seconds: 10),
);

final outcome = await search.run(() => repository.search(query));

if (outcome case OperationSuccess(:final value)) { emit(SearchState.data(value)); }
if (outcome case OperationIgnoredAsStale()) { /* discard */ }
```

**Pros**
- Simple, enum-based policy selection.
- `latestWins` and `firstWins` are self-explanatory.
- Easy to serialise the policy for diagnostics.

**Cons**
- An enum cannot carry behaviour or configuration. Future policies such as `restartable` may need additional parameters.
- Less open for extension without changing the public API.

### Shape B: Policy as a class hierarchy

```dart
final search = GuardedOperation<List<String>>(
  name: 'search',
  policy: const LatestWinsPolicy(timeout: Duration(seconds: 10)),
);

final outcome = await search.run(() => repository.search(query));
```

**Pros**
- Policies can carry their own configuration, such as timeout per policy.
- New policies can be added without changing the constructor signature.
- Allows custom policy implementations by advanced users.

**Cons**
- Slightly more surface area to document.
- `const` constructors are not always possible if a policy needs runtime configuration.

### Recommendation

Recommend **Shape A** for the MVP. The `OperationPolicy` enum keeps the API small. If `restartable`, `sequential` or `parallel` require parameters in v0.2.0, the public constructor can be widened to accept a `ConcurrencyPolicy` interface while preserving the enum values as convenience factories.

## 3. Violations and Reporting

Both shapes should produce a `TransitionResult` and an `OperationOutcome` that are either successful or contain a `StateFenceViolation`. The violation model is common across the API:

```dart
class StateFenceViolation {
  final String fenceName;
  final String reason;
  final DateTime timestamp;
  final String? operation;
  final Map<String, Object?> safeMetadata;
  final StackTrace? stackTrace;
}
```

A `StateFenceReporter` interface is injected into `StateFence` and `GuardedOperation` so that tests can collect violations deterministically:

```dart
abstract class StateFenceReporter {
  void report(StateFenceViolation violation);
}
```

## 4. Lifecycle and Ownership

The Flutter integration package should expose a mixin or owner that disposes fences and operations:

```dart
class _SearchScreenState extends State<SearchScreen>
    with StateFenceStateMixin {
  late final _search = GuardedOperation<List<String>>(
    name: 'search',
    policy: OperationPolicy.latestWins,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }
}
```

For v0.1.0 the owner is a thin wrapper; the diagnostic event is recorded in the core package.

## 5. Outcome

Shape A was accepted for both transition contracts and guarded operations. Transition contracts landed first, followed by guarded operations, the Flutter integration and the test matchers, all of which ship in 0.1.0.

Two items from this document remain deliberately unimplemented and are tracked as non-goals in the README: policies that carry their own configuration (Shape B for operations), and rule-level conditional guards. Both would be considered in v0.2.0 alongside `restartable`, `sequential` and `parallel`.
