# StateFence Ecosystem Review

Access date: 6 August 2026.

This document records documented capabilities of packages that overlap with StateFence's problem space. Claims are limited to what the package documentation or API reference explicitly shows. The purpose is to identify where StateFence can add value rather than to assert superiority.

## Relevant Packages Reviewed

### 1. `state_machine`

- **Publisher**: Workiva (pub.dev/packages/state_machine).
- **Documented capability**: Finite state machine library that lets developers define states and legal transitions. A `StateTransition` declares valid "from" states and a single "to" state. Illegal transitions are rejected at runtime.
- **What it does not show**: No mention of structured violations with privacy-aware export, async race-condition protection, or framework-neutral Flutter lifecycle integration.
- **Gap for StateFence**: It focuses on synchronous state machines. It does not appear to provide guarded asynchronous operations or transition diagnostics that sit beside existing state-management solutions.

### 2. `simple_fsm`

- **Publisher**: mrOriguchi (pub.dev/packages/simple_fsm).
- **Documented capability**: Enum-based state machine with guard functions, transition callbacks and logging. Events trigger transitions; guards can cancel them.
- **What it does not show**: No documented support for async in-flight request management, stale-result rejection, or bounded diagnostic timelines.
- **Gap for StateFence**: Lightweight, but the public API is enum-oriented. StateFence can target strongly-typed state classes and async operation guarding.

### 3. `automata`

- **Publisher**: Kaue-Tada (pub.dev/packages/automata).
- **Documented capability**: Event-driven finite state machine with typed states and events, entry/exit/transition actions, and hierarchical state nodes.
- **What it does not show**: No documented async request governance, violation reporting or redacted metadata export.
- **Gap for StateFence**: More expressive state-machine machinery. StateFence can remain smaller and focused on async boundary correctness.

### 4. `inflight_request_manager`

- **Publisher**: MarnickCoditsu (pub.dev/packages/inflight_request_manager).
- **Documented capability**: Prevents duplicate in-flight asynchronous requests by ID. Supports `override` flag to replace an active request.
- **What it does not show**: No structured event timeline, transition contracts, lifecycle ownership, or multiple concurrency policies beyond override.
- **Gap for StateFence**: Confirms the existence of the duplicate/stale async problem but leaves room for a policy-based, state-management-neutral solution with observability.

### 5. `locked_async`

- **Publisher**: kefasjw (pub.dev/packages/locked_async).
- **Documented capability**: Ensures one async task runs at a time. A new `lock.run()` cancels the previous one. Provides `state.guard()` and `state.wait()` helpers to cooperate with cancellation.
- **What it does not show**: No latest-wins or first-wins policies, no state transition rules, and no diagnostic timeline. Network cancellation requires Dio.
- **Gap for StateFence**: Covers mutual exclusion but not broader concurrency policies or structured state-transition validation.

### 6. `tanquery` / `tanquery_flutter`

- **Publisher**: tanstack (pub.dev/packages/tanquery).
- **Documented capability**: Caching-first async data management with request deduplication, stale-while-revalidate, background refetching, retries and optimistic updates.
- **What it does not show**: It is a full data-fetching solution, not a small correctness layer. No documented state-transition contracts or privacy-aware redaction.
- **Gap for StateFence**: Tackles the same race conditions but as a framework. StateFence can provide a narrower, pluggable correctness toolkit that does not replace state management.

### 7. `fasq`

- **Publisher**: urvaius (pub.dev/packages/fasq).
- **Documented capability**: FASQ is a caching-first async state package with deduplication, refetching, mutations and adapters for Bloc, Riverpod and Hooks.
- **What it does not show**: No framework-neutral transition contracts or diagnostic privacy features.
- **Gap for StateFence**: Another full solution. StateFence can remain a focused correctness add-on.

### 8. `dio_auth_guard`

- **Publisher**: cachapa (pub.dev/packages/dio_auth_guard).
- **Documented capability**: Dio interceptor that cancels all in-flight requests on 401/403 and debounces redirects. State management agnostic.
- **What it does not show**: No general async concurrency policies, no state transition validation and no test utilities.
- **Gap for StateFence**: A specific authentication use case; StateFence can generalise stale/duplicate protection and make it testable.

## Comparison Summary

| Package | Synchronous transitions | Async race protection | Bounded diagnostics | Testability focus | Framework neutral | Pure Dart core |
|---|---|---|---|---|---|---|
| `state_machine` | Yes | No | No | Partial | Yes | Yes |
| `simple_fsm` | Yes | No | No | Partial | Yes | Yes |
| `automata` | Yes | No | No | Partial | Yes | Yes |
| `inflight_request_manager` | No | Partial | No | No | Yes | No (Flutter) |
| `locked_async` | No | Partial | No | Partial | Yes | Yes |
| `tanquery` | No | Yes (full framework) | No | Partial | Yes | Yes (core) |
| `fasq` | No | Yes (full framework) | No | Partial | Flutter oriented | No (Flutter) |
| `dio_auth_guard` | No | Partial | No | No | Yes | No (Flutter) |

## Gap Analysis

No reviewed package combines all three of the following in a single, small, state-management-neutral library:

1. **Explicit, typed state-transition contracts** that produce structured, testable violations.
2. **Guarded asynchronous operations** with selectable policies such as `latestWins` and `firstWins`.
3. **Privacy-aware, bounded diagnostics** with opt-in metadata and redaction.

StateFence's proposed niche is therefore the boundary between asynchronous work and UI state: adding enforceable rules and race-condition protection without requiring a new state-management framework.

## Unresolved Questions

- Should the Riverpod and BLoC adapters be published before v0.1.0? The product plan defers them to v0.2.0.
- How strict should the default analysis and linting rules be? This will be resolved in `analysis_options.yaml` configuration.
