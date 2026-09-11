import 'package:flutter/material.dart';

import 'info_card.dart';

/// A shared scaffold for a scenario screen.
///
/// Renders a consistent header, a problem and solution [InfoCard] and the
/// scenario specific [children] in a scrollable, centred column.
class ScenarioPage extends StatelessWidget {
  /// Creates a scenario page.
  const ScenarioPage({
    super.key,
    required this.title,
    required this.icon,
    required this.accent,
    required this.problem,
    required this.solution,
    required this.children,
  });

  /// Title shown in the app bar and header.
  final String title;

  /// Icon shown in the header badge.
  final IconData icon;

  /// Accent colour for the header badge and solution highlight.
  final Color accent;

  /// Description of the failure mode being demonstrated.
  final String problem;

  /// Description of how StateFence prevents the failure.
  final String solution;

  /// Scenario specific content rendered below the info card.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Row(
                children: [
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: accent, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              InfoCard(
                problem: problem,
                solution: solution,
                accent: accent,
              ),
              const SizedBox(height: 20),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
