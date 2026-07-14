import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maintify/widgets/common_button.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('CommonButton — ElevatedButton variant', () {
    testWidgets('displays button text', (tester) async {
      await tester.pumpWidget(
        _wrap(CommonButton(text: 'Submit', onPressed: () {}, backgroundColor: Colors.blue)),
      );
      expect(find.text('Submit'), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        _wrap(CommonButton(
          text: 'Tap Me',
          onPressed: () => tapped = true,
          backgroundColor: Colors.blue,
        )),
      );
      await tester.tap(find.byType(ElevatedButton));
      expect(tapped, isTrue);
    });

    testWidgets('shows spinner and no text when isLoading is true', (tester) async {
      await tester.pumpWidget(
        _wrap(CommonButton(
          text: 'Loading',
          onPressed: () {},
          backgroundColor: Colors.blue,
          isLoading: true,
        )),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading'), findsNothing);
    });

    testWidgets('does not call onPressed when isLoading', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        _wrap(CommonButton(
          text: 'Loading',
          onPressed: () => tapped = true,
          backgroundColor: Colors.blue,
          isLoading: true,
        )),
      );
      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
      expect(tapped, isFalse);
    });
  });

  group('CommonButton — outlined variant', () {
    testWidgets('renders as OutlinedButton', (tester) async {
      await tester.pumpWidget(
        _wrap(CommonButton(
          text: 'Cancel',
          onPressed: () {},
          isOutlined: true,
        )),
      );
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        _wrap(CommonButton(
          text: 'Cancel',
          onPressed: () => tapped = true,
          isOutlined: true,
        )),
      );
      await tester.tap(find.byType(OutlinedButton));
      expect(tapped, isTrue);
    });
  });

  group('CommonButton — gradient variant', () {
    testWidgets('renders with GestureDetector (no ElevatedButton)', (tester) async {
      await tester.pumpWidget(
        _wrap(CommonButton(
          text: 'Login',
          onPressed: () {},
          gradient: [Colors.blue, Colors.indigo],
        )),
      );
      expect(find.byType(GestureDetector), findsWidgets);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        _wrap(CommonButton(
          text: 'Login',
          onPressed: () => tapped = true,
          gradient: [Colors.blue, Colors.indigo],
        )),
      );
      await tester.tap(find.text('Login'));
      expect(tapped, isTrue);
    });

    testWidgets('shows spinner in loading state', (tester) async {
      await tester.pumpWidget(
        _wrap(CommonButton(
          text: 'Login',
          onPressed: () {},
          gradient: [Colors.blue, Colors.indigo],
          isLoading: true,
        )),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('CommonButton — icon variant', () {
    testWidgets('renders icon alongside text', (tester) async {
      await tester.pumpWidget(
        _wrap(CommonButton(
          text: 'Add Bill',
          onPressed: () {},
          backgroundColor: Colors.blue,
          icon: Icons.add,
        )),
      );
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.text('Add Bill'), findsOneWidget);
    });
  });
}
