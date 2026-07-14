import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maintify/models/bill_model.dart';
import 'package:maintify/widgets/status_chip.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('StatusChip', () {
    testWidgets('displays status text', (tester) async {
      await tester.pumpWidget(_wrap(const StatusChip(status: BillStatus.paid)));
      expect(find.text(BillStatus.paid), findsOneWidget);
    });

    testWidgets('displays Paid status', (tester) async {
      await tester.pumpWidget(_wrap(const StatusChip(status: BillStatus.paid)));
      expect(find.text('Paid'), findsOneWidget);
    });

    testWidgets('displays Pending status', (tester) async {
      await tester.pumpWidget(_wrap(const StatusChip(status: BillStatus.pending)));
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('displays Overdue status', (tester) async {
      await tester.pumpWidget(_wrap(const StatusChip(status: BillStatus.overdue)));
      expect(find.text('Overdue'), findsOneWidget);
    });

    testWidgets('displays Partial status', (tester) async {
      await tester.pumpWidget(_wrap(const StatusChip(status: BillStatus.partiallyPaid)));
      expect(find.text('Partial'), findsOneWidget);
    });

    testWidgets('contains an icon', (tester) async {
      await tester.pumpWidget(_wrap(const StatusChip(status: BillStatus.paid)));
      expect(find.byType(Icon), findsWidgets);
    });

    testWidgets('Paid chip uses check-circle icon', (tester) async {
      await tester.pumpWidget(_wrap(const StatusChip(status: BillStatus.paid)));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.check_circle_outline);
    });

    testWidgets('Overdue chip uses error icon', (tester) async {
      await tester.pumpWidget(_wrap(const StatusChip(status: BillStatus.overdue)));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.error_outline);
    });

    testWidgets('Pending chip uses schedule icon', (tester) async {
      await tester.pumpWidget(_wrap(const StatusChip(status: BillStatus.pending)));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.schedule_outlined);
    });

    testWidgets('renders without throwing', (tester) async {
      for (final status in [
        BillStatus.paid,
        BillStatus.pending,
        BillStatus.overdue,
        BillStatus.partiallyPaid,
      ]) {
        await tester.pumpWidget(_wrap(StatusChip(status: status)));
        expect(tester.takeException(), isNull);
      }
    });
  });
}
