import 'dart:async';

import 'package:state_fence/state_fence.dart';

/// Checkout states for the combined console sample.
///
/// The fence stores one of these. The local `ui` variable in [main] changes
/// only when [StateFence.transition] returns [TransitionAccepted].
sealed class CheckoutState {
  const CheckoutState();
}

/// No payment is in flight.
final class Idle extends CheckoutState {
  const Idle();
}

/// A payment has been accepted and is in flight.
final class Submitting extends CheckoutState {
  const Submitting();
}

/// The payment was accepted and produced a [receipt].
final class Paid extends CheckoutState {
  const Paid(this.receipt);

  /// Receipt text returned by the accepted operation.
  final String receipt;
}

/// The payment failed or timed out.
final class Failed extends CheckoutState {
  const Failed(this.message);

  /// Why the payment did not complete.
  final String message;
}

/// Runs one checkout.
///
/// Guarded outcomes go through the fence. A rejected transition is printed
/// and leaves the UI variable unchanged. A stuck submitting state is printed
/// from the timeline. The default reporter is silent; the timeline still
/// records the stuck-state event.
Future<void> main() async {
  final timeline = Timeline(capacity: 64);
  final fence = StateFence<CheckoutState>(
    name: 'checkout',
    initialState: const Idle(),
    rules: [
      allow<Idle, Submitting>(),
      allow<Submitting, Paid>(),
      allow<Submitting, Failed>(),
      allow<Failed, Submitting>(),
    ],
    timeline: timeline,
    stuckStateTimeouts: const {Submitting: Duration(milliseconds: 100)},
  );
  final pay = GuardedOperation<String>(
    name: 'pay',
    policy: OperationPolicy.firstWins,
    timeout: const Duration(milliseconds: 40),
    timeline: timeline,
  );
  final quote = GuardedOperation<String>(
    name: 'quote',
    policy: OperationPolicy.latestWins,
    timeline: timeline,
  );

  CheckoutState ui = const Idle();

  String describe(CheckoutState state) => switch (state) {
        Idle() => 'Idle',
        Submitting() => 'Submitting',
        Paid(:final receipt) => 'Paid($receipt)',
        Failed(:final message) => 'Failed($message)',
      };

  CheckoutState apply(TransitionResult<CheckoutState> result) {
    switch (result) {
      case TransitionAccepted(:final state):
        print('Accepted. UI is now ${describe(state)}.');
        return state;
      case TransitionRejected(:final violation):
        print('Rejected: ${violation.reason}');
        print('UI unchanged: ${describe(ui)}.');
        return ui;
    }
  }

  CheckoutState applyOutcome(OperationOutcome<String> outcome) {
    switch (outcome) {
      case OperationSuccess(:final value):
        return apply(
          fence.transition(
            Paid(value),
            operation: 'pay',
            metadata: const <String, Object?>{
              'token': 'card-token-secret',
              'amount': '42.00',
            },
          ),
        );
      case OperationFailure(:final error):
        return apply(fence.transition(Failed('$error'), operation: 'pay'));
      case OperationTimedOut(:final timeout):
        print('Timed out after $timeout. The future is not cancelled.');
        return apply(
          fence.transition(
            Failed('Timed out after $timeout.'),
            operation: 'pay',
          ),
        );
      case OperationIgnoredAsStale():
        print('Ignored as stale. UI stays ${describe(ui)}.');
        return ui;
      case OperationIgnoredAsDuplicate():
        print('Ignored as duplicate. UI stays ${describe(ui)}.');
        return ui;
    }
  }

  print('1. Reject a jump from idle to paid.');
  ui = apply(fence.transition(const Paid('skipped'), operation: 'pay'));
  if (ui is! Idle) {
    throw StateError('Rejection changed the UI to ${describe(ui)}.');
  }

  print('2. Enter submitting and wait for the stuck-state timeout.');
  ui = apply(fence.transition(const Submitting(), operation: 'pay'));
  await Future<void>.delayed(const Duration(milliseconds: 150));
  final stuck = timeline.events.whereType<StateStuckEvent>().toList();
  if (stuck.length != 1) {
    throw StateError('Expected one stuck-state event, found ${stuck.length}.');
  }
  print(
    'Stuck: ${stuck.single.stuckState} exceeded ${stuck.single.maxDuration}. '
    'UI stays ${describe(ui)}.',
  );

  print('3. Fail the payment. A second tap is a duplicate.');
  final failing = pay.run(() async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    throw StateError('card declined');
  });
  ui = applyOutcome(await pay.run(() async => 'second tap'));
  if (ui is! Submitting) {
    throw StateError('Duplicate changed the UI to ${describe(ui)}.');
  }
  ui = applyOutcome(await failing);
  if (ui is! Failed) {
    throw StateError('Failure should move the UI to Failed, got $ui.');
  }

  print('4. Time out a payment that never completes.');
  ui = apply(fence.transition(const Submitting(), operation: 'pay'));
  ui = applyOutcome(await pay.run(() => Completer<String>().future));
  if (ui is! Failed) {
    throw StateError('Timeout should move the UI to Failed, got $ui.');
  }

  print('5. Accept the fast quote and ignore the slow one.');
  ui = apply(fence.transition(const Submitting(), operation: 'pay'));
  final slow = quote.run(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return 'slow-receipt';
  });
  final fast = quote.run(() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return 'fast-receipt';
  });
  ui = applyOutcome(await fast);
  ui = applyOutcome(await slow);
  if (ui is! Paid || ui.receipt != 'fast-receipt') {
    throw StateError('Expected Paid(fast-receipt), got ${describe(ui)}.');
  }

  final exported = exportTimelineJson(timeline);
  print(exported);
  if (!exported.contains('<redacted>') ||
      exported.contains('card-token-secret') ||
      !exported.contains('42.00')) {
    throw StateError('Timeline export did not redact the token metadata.');
  }
  print('Redacted export replaced the token and kept the amount.');
}
