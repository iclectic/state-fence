import 'package:flutter_test/flutter_test.dart';
import 'package:state_fence_example/main.dart';

void main() {
  testWidgets('home screen lists the demos', (tester) async {
    await tester.pumpWidget(const StateFenceExampleApp());

    expect(find.text('StateFence'), findsOneWidget);
    expect(find.text('Checkout contract'), findsOneWidget);
    expect(find.text('Stale search response'), findsOneWidget);
    expect(find.text('Duplicate submission'), findsOneWidget);
    expect(find.text('Stuck loading state'), findsOneWidget);
  });

  testWidgets('tapping checkout contract opens its screen', (tester) async {
    await tester.pumpWidget(const StateFenceExampleApp());

    await tester.tap(find.text('Checkout contract'));
    await tester.pumpAndSettle();

    expect(find.text('Checkout'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Run the combined flow'), 200);
    expect(find.text('Run the combined flow'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Current state'), 200);
    expect(find.text('Current state'), findsOneWidget);
  });

  testWidgets('tapping a scenario opens its detail screen', (tester) async {
    await tester.pumpWidget(const StateFenceExampleApp());

    await tester.tap(find.text('Stale search response'));
    await tester.pumpAndSettle();

    expect(find.text('Stale Search'), findsWidgets);
    expect(find.text('Run the search race'), findsOneWidget);
  });
}
