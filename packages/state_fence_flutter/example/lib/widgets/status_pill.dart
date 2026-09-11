import 'package:flutter/material.dart';

/// Visual intent used to colour a [StatusPill].
enum StatusTone {
  /// A neutral, idle state.
  neutral,

  /// An in-progress state.
  progress,

  /// A successful outcome.
  success,

  /// A discarded, ignored or timed-out outcome worth highlighting.
  warning,

  /// A failure outcome.
  error,
}

/// A compact, colour-coded chip that summarises a state or outcome.
class StatusPill extends StatelessWidget {
  /// Creates a status pill with the given [label], [icon] and [tone].
  const StatusPill({
    super.key,
    required this.label,
    required this.icon,
    this.tone = StatusTone.neutral,
  });

  /// Text shown inside the pill.
  final String label;

  /// Leading icon shown before the [label].
  final IconData icon;

  /// Colour intent for the pill.
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final (Color background, Color foreground) = switch (tone) {
      StatusTone.neutral => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
        ),
      StatusTone.progress => (
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
        ),
      StatusTone.success => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
        ),
      StatusTone.warning => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
        ),
      StatusTone.error => (
          scheme.errorContainer,
          scheme.onErrorContainer,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
