import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maintify/widgets/shimmer_loading.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('EmptyState', () {
    testWidgets('displays title and subtitle', (tester) async {
      await tester.pumpWidget(_wrap(const EmptyState(
        title: 'No Bills Yet',
        subtitle: 'Create a bill to get started',
        icon: Icons.receipt_long_outlined,
      )));
      expect(find.text('No Bills Yet'), findsOneWidget);
      expect(find.text('Create a bill to get started'), findsOneWidget);
    });

    testWidgets('displays the icon', (tester) async {
      await tester.pumpWidget(_wrap(const EmptyState(
        title: 'Empty',
        subtitle: 'Nothing here',
        icon: Icons.inbox_outlined,
      )));
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });

    testWidgets('does not show action button when onAction is null', (tester) async {
      await tester.pumpWidget(_wrap(const EmptyState(
        title: 'Empty',
        subtitle: 'Nothing here',
        icon: Icons.inbox_outlined,
      )));
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('shows action button when onAction is provided', (tester) async {
      await tester.pumpWidget(_wrap(EmptyState(
        title: 'Empty',
        subtitle: 'Nothing here',
        icon: Icons.inbox_outlined,
        onAction: () {},
        actionLabel: 'Do Something',
      )));
      expect(find.text('Do Something'), findsOneWidget);
    });

    testWidgets('calls onAction when action button is tapped', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(_wrap(EmptyState(
        title: 'Empty',
        subtitle: 'Nothing here',
        icon: Icons.inbox_outlined,
        onAction: () => tapped = true,
        actionLabel: 'Act',
      )));
      await tester.tap(find.text('Act'));
      expect(tapped, isTrue);
    });

    testWidgets('renders without throwing', (tester) async {
      await tester.pumpWidget(_wrap(const EmptyState(
        title: 'X',
        subtitle: 'Y',
        icon: Icons.error,
      )));
      expect(tester.takeException(), isNull);
    });
  });

  group('ShimmerBox', () {
    testWidgets('renders with given dimensions', (tester) async {
      await tester.pumpWidget(_wrap(const ShimmerBox(width: 200, height: 60)));
      final box = tester.getSize(find.byType(ShimmerBox));
      expect(box.width, 200);
      expect(box.height, 60);
    });

    testWidgets('renders without throwing', (tester) async {
      await tester.pumpWidget(
          _wrap(const ShimmerBox(width: 100, height: 40)));
      expect(tester.takeException(), isNull);
    });
  });
}
