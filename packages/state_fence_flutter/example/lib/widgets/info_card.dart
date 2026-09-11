import 'package:flutter/material.dart';

/// A card that frames a scenario as a problem and the guard that solves it.
class InfoCard extends StatelessWidget {
  /// Creates an info card describing the [problem] and its [solution].
  const InfoCard({
    super.key,
    required this.problem,
    required this.solution,
    required this.accent,
  });

  /// Short description of the failure mode being demonstrated.
  final String problem;

  /// Short description of how StateFence prevents the failure.
  final String solution;

  /// Accent colour used for the solution highlight.
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Row(
              icon: Icons.warning_amber_rounded,
              iconColor: scheme.error,
              label: 'The problem',
              body: problem,
            ),
            const SizedBox(height: 16),
            _Row(
              icon: Icons.verified_user_outlined,
              iconColor: accent,
              label: 'With StateFence',
              body: solution,
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.body,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: text.labelLarge?.copyWith(
                  color: iconColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
