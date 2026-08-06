# StateFence Product Brief

Working package name: `state_fence`  
Product name: StateFence  
Tagline: Catch dangerous state transitions before your users do.

## Problem Statement

Flutter applications frequently move through states such as `loading`, `success` and `error` while waiting for asynchronous work. At the boundary between async work and UI state, developers repeatedly encounter the same categories of bug:

- A slower, older network response overwrites a newer response.
- The same save or payment operation is submitted twice because the button was tapped rapidly.
- A screen remains stuck in a loading or submitting state without a visible timeout.
- A state transitions through a path the team considers illegal, but the path is only documented informally.
- State is updated after its owner has been disposed.

These are correctness problems, not framework problems. They can occur with `setState`, `ChangeNotifier`, `Riverpod`, `BLoC` or any custom controller.

## Target Users

- Flutter developers working with REST APIs, local databases or background tasks.
- Teams using `Riverpod`, `BLoC`, `Provider`, `ChangeNotifier` or `setState`.
- Package authors who want deterministic, testable state-transition assertions.
- Developers currently experiencing duplicate submissions, stale responses or stuck loading screens.

## Jobs to be Done

1. Declare which state-to-state movements are legal and receive a structured, testable signal when a rule is broken.
2. Run async work with a chosen concurrency policy so that stale or duplicate results cannot silently overwrite newer state.
3. Detect when a transitional state has persisted for longer than allowed, without depending on real wall-clock time in tests.
4. Record a bounded, redactable diagnostic timeline that helps reproduce failures without exposing sensitive values.
5. Bind the lifecycle of fences and guarded operations to UI disposal, making post-dispose updates visible.

## Non-Goals

- Replace `Riverpod`, `BLoC`, `Provider`, `ChangeNotifier` or `setState`.
- Provide production application-performance monitoring, network inspection or general logging.
- Become a replacement for Flutter DevTools.
- Offer AI-generated debugging advice.
- Track analytics, telemetry or network calls.

## Three Failure Scenarios

### Scenario 1: Stale search response

A user types "a", then "ab", then "abc". The "ab" request is slow and returns after the "abc" request. The search results briefly show "abc" results, then flip to older "ab" results. The UI looks broken.

### Scenario 2: Duplicate submission

A checkout screen enters a `submitting` state. The user taps the pay button twice because the UI did not disable the button fast enough. The application fires two payment requests. The backend may process the payment twice or reject the second with an error that the user sees.

### Scenario 3: Stuck loading state

A pull-to-refresh triggers a loading state. The repository call never returns because of a missing handler in a test path. The UI stays in `loading` forever. There is no timeout or violation, so the user has to restart the app.

## MVP Scope (v0.1.0)

- Transition contracts with allowed and rejected transition results.
- `latestWins` and `firstWins` guarded operation policies.
- Structured violations with an injectable reporter.
- Stuck-state timeout detection using an injectable clock.
- Lifecycle ownership and post-dispose violation reporting.
- Bounded, redactable diagnostic timeline with JSON export.
- Test matchers and fake-clock support in `state_fence_test`.
- Flutter integration package for lifecycle bindings.

## Out of Scope for v0.1.0

- `restartable`, `sequential` and `parallel` operation policies.
- Retry policies with exponential backoff and jitter.
- Riverpod and BLoC adapters.
- In-app inspector, Mermaid/Graphviz graphs or DevTools extension.
- Markdown diagnostic report export.

## Measurable Acceptance Criteria

1. All public APIs are documented with `dartdoc`.
2. `state_fence` has no Flutter dependency.
3. `dart format` and `dart analyze` pass with no warnings.
4. Deterministic concurrency tests cover two requests completing in reverse order and three overlapping `latestWins` requests.
5. Privacy tests prove that nested maps and lists are redacted before export.
6. Every package has a smoke test that resolves and runs.
7. CI runs formatting, analysis and tests for all packages.
