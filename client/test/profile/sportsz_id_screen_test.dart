import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_z/core/network/api_exception.dart';
import 'package:sports_z/features/profile/presentation/screens/my_profile_screen.dart';
import 'package:sports_z/features/profile/presentation/screens/sportsz_id_screen.dart';

Map<String, dynamic> _identityResponse({
  String id = 'SZ-4K7M-91Q2-7',
  String name = 'Ravi Kumar',
}) => {
  'sportsz_id': id,
  'full_name': name,
  'photo_url': null,
  'primary_sport': 'Cricket',
  'positions': ['Batter'],
  'level': 'State',
};

Widget _app(Widget home) => ProviderScope(child: MaterialApp(home: home));

void main() {
  testWidgets('I01 displays backend identity data and no fake verification', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(SportsZIdScreen(loadIdentity: () async => _identityResponse())),
    );
    await tester.pumpAndSettle();

    expect(find.text('SZ-4K7M-91Q2-7'), findsOneWidget);
    expect(find.text('Ravi Kumar'), findsOneWidget);
    expect(find.text('Cricket · Batter · State'), findsOneWidget);
    expect(find.text('ID issued'), findsOneWidget);
    expect(find.text('Verified'), findsNothing);
    expect(find.text('ACTIVE'), findsNothing);
    expect(
      find.text('SportsZ digital sports credential. Not a government ID.'),
      findsOneWidget,
    );
  });

  testWidgets('shows loading until the authenticated ID response arrives', (
    tester,
  ) async {
    final pending = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      _app(SportsZIdScreen(loadIdentity: () => pending.future)),
    );
    expect(find.text('Loading your profile…'), findsOneWidget);
    expect(find.text('SZ-4K7M-91Q2-7'), findsNothing);
    pending.complete(_identityResponse());
    await tester.pumpAndSettle();
    expect(find.text('SZ-4K7M-91Q2-7'), findsOneWidget);
  });

  testWidgets('missing ID has a safe error and retry recovers', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      _app(
        SportsZIdScreen(
          loadIdentity: () async {
            attempts++;
            if (attempts == 1) {
              throw const ApiException(statusCode: 404, message: 'Not found');
            }
            return _identityResponse();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Your SportsZ ID has not been issued yet.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('SZ-4K7M-91Q2-7'), findsOneWidget);
  });

  testWidgets('P01 View ID opens I01 and Back returns to P01', (tester) async {
    const profile = AthleteProfileData(
      name: 'Ravi Kumar',
      sport: 'Cricket',
      role: 'Batter',
      level: 'State',
      ageCategory: '',
      gender: '',
      sportszId: 'profile-summary-id',
    );
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => MyProfileScreen(
            data: profile,
            onViewId: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => SportsZIdScreen(
                  loadIdentity: () async => _identityResponse(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('View ID'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View ID'));
    await tester.pumpAndSettle();
    expect(find.text('SportsZ ID'), findsOneWidget);
    expect(find.text('SZ-4K7M-91Q2-7'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to profile'));
    await tester.pumpAndSettle();
    expect(find.text('View ID'), findsOneWidget);
    expect(find.text('SportsZ ID'), findsNothing);
  });

  testWidgets('long athlete name remains contained on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        SportsZIdScreen(
          loadIdentity: () async => _identityResponse(
            name: 'A Very Long Athlete Name That Needs To Wrap Neatly',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('SZ-4K7M-91Q2-7'), findsOneWidget);
  });
}
