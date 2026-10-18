import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_z/core/network/api_exception.dart';
import 'package:sports_z/features/profile/presentation/screens/sportsz_id_screen.dart';
import 'package:sports_z/features/profile/presentation/widgets/share_sportsz_id_sheet.dart';

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
  ShareIdCallback? shareText,
  Future<Uint8List?> Function()? captureCard,
  SportsZIdentityLoader? loader,
  bool openShareOnLoad = false,
}) => ProviderScope(
  child: MaterialApp(
    home: SportsZIdScreen(
      loadIdentity: loader ?? () async => _identity(),
      shareText: shareText,
      captureCard: captureCard,
      openShareOnLoad: openShareOnLoad,
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

  testWidgets('openShareOnLoad opens the sheet once the ID has loaded', (
    tester,
  ) async {
    await tester.pumpWidget(_app(openShareOnLoad: true));
    await tester.pumpAndSettle();

    expect(find.text('Share your SportsZ ID'), findsOneWidget);
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

  testWidgets('Share sends the ID text together with the card picture', (
    tester,
  ) async {
    String? sharedText;
    Uint8List? sharedPng;
    final png = Uint8List.fromList([1, 2, 3]);
    await tester.pumpWidget(
      _app(
        captureCard: () async => png,
        shareText: (text, cardPng) async {
          sharedText = text;
          sharedPng = cardPng;
        },
      ),
    );
    await tester.pumpAndSettle();
    await _openSheet(tester);
    await tester.tap(find.byKey(const Key('share_sheet_share')));
    await tester.pumpAndSettle();

    expect(sharedText, 'My SportsZ ID: $_id');
    expect(sharedPng, png);
    expect(find.text('Share your SportsZ ID'), findsNothing);
  });

  testWidgets('Share still works with text only when the picture fails', (
    tester,
  ) async {
    String? sharedText;
    Uint8List? sharedPng = Uint8List.fromList([9]);
    await tester.pumpWidget(
      _app(
        captureCard: () async => null,
        shareText: (text, cardPng) async {
          sharedText = text;
          sharedPng = cardPng;
        },
      ),
    );
    await tester.pumpAndSettle();
    await _openSheet(tester);
    await tester.tap(find.byKey(const Key('share_sheet_share')));
    await tester.pumpAndSettle();

    expect(sharedText, 'My SportsZ ID: $_id');
    expect(sharedPng, isNull);
  });

  testWidgets('Share failure shows a safe message', (tester) async {
    await tester.pumpWidget(
      _app(
        captureCard: () async => null,
        shareText: (text, cardPng) async {
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
