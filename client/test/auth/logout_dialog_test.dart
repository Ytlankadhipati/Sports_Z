import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_z/features/auth/presentation/widgets/logout_dialog.dart';

Widget _host(void Function(bool) onResult) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () async {
              final result = await showLogoutDialog(context);
              onResult(result);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows title, message and both buttons', (tester) async {
    await tester.pumpWidget(_host((_) {}));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsOneWidget);
    expect(
      find.text('You will need to sign in again to use SportsZ.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('logout_dialog_cancel')), findsOneWidget);
    expect(find.byKey(const Key('logout_dialog_confirm')), findsOneWidget);
  });

  testWidgets('Cancel returns false', (tester) async {
    bool? result;
    await tester.pumpWidget(_host((value) => result = value));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('logout_dialog_cancel')));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(find.text('Log out?'), findsNothing);
  });

  testWidgets('Log out returns true', (tester) async {
    bool? result;
    await tester.pumpWidget(_host((value) => result = value));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('logout_dialog_confirm')));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(find.text('Log out?'), findsNothing);
  });

  testWidgets('tapping outside the dialog returns false', (tester) async {
    bool? result;
    await tester.pumpWidget(_host((value) => result = value));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(find.text('Log out?'), findsNothing);
  });
}
