import 'package:flutter/material.dart';
import 'package:state_fence/state_fence.dart';

/// Checkout states owned by [CheckoutController].
///
/// This file is application code. It does not come from an adapter package.
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

  /// Receipt text for the accepted payment.
  final String receipt;
}

/// The payment failed or timed out.
final class Failed extends CheckoutState {
  const Failed(this.message);

  /// Why the payment did not complete.
  final String message;
}

/// Holds a [StateFence] and notifies listeners only when a transition is
/// accepted.
class CheckoutController extends ChangeNotifier {
  /// Creates a controller whose fence starts at [Idle].
  CheckoutController()
      : _fence = StateFence<CheckoutState>(
          name: 'notifier-checkout',
          initialState: const Idle(),
          rules: <TransitionRule>[
            allow<Idle, Submitting>(),
            allow<Submitting, Paid>(),
            allow<Submitting, Failed>(),
            allow<Failed, Submitting>(),
          ],
        );

  final StateFence<CheckoutState> _fence;

  /// The fence's current state.
  CheckoutState get state => _fence.current;

  /// Attempts [next] and notifies listeners only when the fence accepts it.
  TransitionResult<CheckoutState> transition(CheckoutState next) {
    final TransitionResult<CheckoutState> result = _fence.transition(next);
    if (result is TransitionAccepted<CheckoutState>) {
      notifyListeners();
    }
    return result;
  }

  /// Releases the fence.
  @override
  void dispose() {
    _fence.dispose();
    super.dispose();
  }
}

/// Screen that drives [CheckoutController] by hand.
class ChangeNotifierCheckoutScreen extends StatefulWidget {
  /// Creates the ChangeNotifier checkout screen.
  const ChangeNotifierCheckoutScreen({super.key});

  @override
  State<ChangeNotifierCheckoutScreen> createState() =>
      _ChangeNotifierCheckoutScreenState();
}

class _ChangeNotifierCheckoutScreenState
    extends State<ChangeNotifierCheckoutScreen> {
  final CheckoutController _controller = CheckoutController();
  String _note = 'Listeners are notified only after an accepted transition.';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _markPaid() {
    final TransitionResult<CheckoutState> result = _controller.transition(
      const Paid('receipt-1'),
    );
    setState(() {
      _note = switch (result) {
        TransitionAccepted() => 'Accepted. Listeners were notified.',
        TransitionRejected(:final StateFenceViolation violation) =>
          'Rejected: ${violation.reason}',
      };
    });
  }

  void _submit() {
    final TransitionResult<CheckoutState> result = _controller.transition(
      const Submitting(),
    );
    setState(() {
      _note = switch (result) {
        TransitionAccepted() => 'Accepted. Listeners were notified.',
        TransitionRejected(:final StateFenceViolation violation) =>
          'Rejected: ${violation.reason}',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('ChangeNotifier')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: <Widget>[
              Text(
                'ChangeNotifier checkout',
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The controller holds the fence. notifyListeners runs only '
                'when the transition is accepted.',
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              ListenableBuilder(
                listenable: _controller,
                builder: (BuildContext context, Widget? child) {
                  return Text(
                    'Current state: ${_label(_controller.state)}',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(_note, style: text.bodyMedium),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submit,
                child: const Text('Submit'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _markPaid,
                child: const Text('Mark paid'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _label(CheckoutState state) {
  return switch (state) {
    Idle() => 'Idle',
    Submitting() => 'Submitting',
    Paid(:final String receipt) => 'Paid($receipt)',
    Failed(:final String message) => 'Failed($message)',
  };
}
