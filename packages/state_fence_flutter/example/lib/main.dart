import 'package:flutter/material.dart';

import 'scenarios/duplicate_submission_scenario.dart';
import 'scenarios/stale_search_scenario.dart';
import 'scenarios/stuck_loading_scenario.dart';
import 'theme.dart';

void main() {
  runApp(const StateFenceExampleApp());
}

/// Root widget of the StateFence example application.
class StateFenceExampleApp extends StatelessWidget {
  /// Creates the example app.
  const StateFenceExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StateFence Example',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      home: const HomeScreen(),
    );
  }
}

/// Describes a single interactive demo shown on the home screen.
class _Scenario {
  const _Scenario({
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
    required this.builder,
  });

  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final WidgetBuilder builder;
}

/// Landing screen that lists the available demos.
class HomeScreen extends StatelessWidget {
  /// Creates the home screen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scenarios = <_Scenario>[
      _Scenario(
        title: 'Stale search response',
        summary: 'A slow older request overwrites newer results.',
        icon: Icons.search_rounded,
        accent: const Color(0xFF0EA5E9),
        builder: (_) => const StaleSearchScenario(),
      ),
      _Scenario(
        title: 'Duplicate submission',
        summary: 'A pay button is tapped twice and charges twice.',
        icon: Icons.payments_outlined,
        accent: const Color(0xFF10B981),
        builder: (_) => const DuplicateSubmissionScenario(),
      ),
      _Scenario(
        title: 'Stuck loading state',
        summary: 'A request never resolves and the spinner hangs forever.',
        icon: Icons.hourglass_top_rounded,
        accent: const Color(0xFFF59E0B),
        builder: (_) => const StuckLoadingScenario(),
      ),
    ];

    return Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: _Header()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                sliver: SliverList.separated(
                  itemCount: scenarios.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) =>
                      _ScenarioCard(scenario: scenarios[index]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.alphaBlend(
              scheme.tertiary.withValues(alpha: 0.55),
              scheme.primary,
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: scheme.onPrimary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.shield_outlined, color: scheme.onPrimary),
              ),
              const SizedBox(width: 14),
              Text(
                'StateFence',
                style: text.headlineMedium?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Catch dangerous state transitions before your users do.',
            style: text.titleMedium?.copyWith(
              color: scheme.onPrimary.withValues(alpha: 0.92),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'INTERACTIVE DEMOS',
            style: text.labelMedium?.copyWith(
              color: scheme.onPrimary.withValues(alpha: 0.85),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({required this.scenario});

  final _Scenario scenario;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;

    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: scenario.builder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: scenario.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(scenario.icon, color: scenario.accent, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scenario.title,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scenario.summary,
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
