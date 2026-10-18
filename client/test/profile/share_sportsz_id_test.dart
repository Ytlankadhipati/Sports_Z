import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_z/core/network/api_exception.dart';
import 'package:sports_z/features/profile/presentation/screens/sportsz_id_screen.dart';

const _id = 'SZ-4K7M-91Q2-7';

Map<String, dynamic> _identity() => {
  'sportsz_id': _id,
  'full_name': 'Ravi Kumar',
  'photo_url': null,
  'primary_sport': 'Cricket',
  'positions': ['Batter'],
  'level': 'State',
};

Widget _app({
  Future<void> Function(String text)? shareText,
  SportsZIdentityLoader? loader,
}) => ProviderScope(
  child: MaterialApp(
    home: SportsZIdScreen(
      loadIdentity: loader ?? () async => _identity(),
      shareText: shareText,
    ),
  ),
);

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Share SportsZ ID'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no share icon when the ID failed to load', (tester) async {
    await tester.pumpWidget(
      _app(
        loader: () async {
          throw const ApiException(statusCode: 404, message: 'Not found');
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Share SportsZ ID'), findsNothing);
  });

  testWidgets('share icon opens the sheet with Share and Copy buttons', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _openSheet(tester);

    expect(find.text('Share your SportsZ ID'), findsOneWidget);
    expect(find.byKey(const Key('share_sheet_share')), findsOneWidget);
    expect(find.byKey(const Key('share_sheet_copy')), findsOneWidget);
    expect(
      find.descendant(of: find.byType(BottomSheet), matching: find.text(_id)),
      findsOneWidget,
    );
  });

  testWidgets('Copy puts only the ID on the clipboard and closes the sheet', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _openSheet(tester);
    await tester.tap(find.byKey(const Key('share_sheet_copy')));
    await tester.pumpAndSettle();

    final copy = calls.where((call) => call.method == 'Clipboard.setData');
    expect(copy, hasLength(1));
    expect((copy.first.arguments as Map)['text'], _id);
    expect(find.text('Share your SportsZ ID'), findsNothing);
    expect(find.text('SportsZ ID copied'), findsOneWidget);
  });

  testWidgets('Share sends the ID text and closes the sheet', (tester) async {
    String? shared;
    await tester.pumpWidget(
      _app(
        shareText: (text) async {
          shared = text;
        },
      ),
    );
    await tester.pumpAndSettle();
    await _openSheet(tester);
    await tester.tap(find.byKey(const Key('share_sheet_share')));
    await tester.pumpAndSettle();

    expect(shared, 'My SportsZ ID: $_id');
    expect(find.text('Share your SportsZ ID'), findsNothing);
  });

  testWidgets('Share failure shows a safe message', (tester) async {
    await tester.pumpWidget(
      _app(
        shareText: (text) async {
          throw StateError('share failed');
        },
      ),
    );
    await tester.pumpAndSettle();
    await _openSheet(tester);
    await tester.tap(find.byKey(const Key('share_sheet_share')));
    await tester.pumpAndSettle();

    expect(find.text('Could not open the share sheet.'), findsOneWidget);
  });
}
