import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_z/core/network/api_exception.dart';
import 'package:sports_z/features/account/data/repositories/account_repository.dart';
import 'package:sports_z/features/account/presentation/controllers/account_controller.dart';
import 'package:sports_z/features/account/presentation/screens/account_screen.dart';

class _FakeAccountRepository extends AccountRepository {
  _FakeAccountRepository(this._handler) : super(Dio());

  final Future<Map<String, dynamic>> Function() _handler;
  int calls = 0;

  @override
  Future<Map<String, dynamic>> getMe() {
    calls++;
    return _handler();
  }
}

Map<String, dynamic> _account({
  String? fullName = 'Ravi Kumar',
  String? email = 'r•••@example.com',
  bool emailVerified = true,
  String? phone = '+91 98••• ••210',
  bool phoneVerified = true,
  List<String> providers = const ['email', 'phone', 'google.com'],
}) => {
  'user_id': 'u1',
  'full_name': fullName,
  'account_label': 'SportsZ athlete account',
  'email_masked': email,
  'email_verified': emailVerified,
  'phone_masked': phone,
  'phone_verified': phoneVerified,
  'linked_providers': providers,
  'roles': ['athlete'],
  'sportsz_id': 'SZ-4K7M-91Q2-7',
};

Widget _app(_FakeAccountRepository repository) => ProviderScope(
  overrides: [accountRepositoryProvider.overrideWithValue(repository)],
  child: const MaterialApp(home: AccountScreen()),
);

void main() {
  testWidgets('ST02 shows loading until GET /me returns', (tester) async {
    final pending = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(_app(_FakeAccountRepository(() => pending.future)));
    await tester.pump();

    expect(find.text('Loading your account…'), findsOneWidget);
    expect(find.text('Ravi Kumar'), findsNothing);

    pending.complete(_account());
    await tester.pumpAndSettle();

    expect(find.text('Loading your account…'), findsNothing);
    expect(find.text('Ravi Kumar'), findsOneWidget);
  });

  testWidgets('ST02 renders the masked values exactly as received', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_FakeAccountRepository(() async => _account())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Account information'), findsOneWidget);
    expect(find.text('RK'), findsOneWidget);
    expect(find.text('Ravi Kumar'), findsOneWidget);
    expect(find.text('SportsZ athlete account'), findsOneWidget);
    expect(find.text('r•••@example.com'), findsOneWidget);
    expect(find.text('+91 98••• ••210'), findsOneWidget);
    expect(find.text('Verified'), findsNWidgets(2));
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Linked'), findsOneWidget);
    expect(find.text('Security'), findsOneWidget);
    expect(find.text('Methods, sessions and devices'), findsOneWidget);
  });

  testWidgets('ST02 hides missing rows and uses fallbacks without crashing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _FakeAccountRepository(
          () async => _account(
            fullName: null,
            phone: null,
            phoneVerified: false,
            providers: const ['email'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('SportsZ athlete'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Phone'), findsNothing);
    expect(find.text('Google'), findsNothing);
  });

  testWidgets('ST02 marks an unverified email as Not verified', (tester) async {
    await tester.pumpWidget(
      _app(_FakeAccountRepository(() async => _account(emailVerified: false))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not verified'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
  });

  testWidgets('ST02 shows a safe error and Retry reloads GET /me', (
    tester,
  ) async {
    late _FakeAccountRepository repository;
    repository = _FakeAccountRepository(() async {
      if (repository.calls == 1) {
        throw const ApiException(statusCode: 500, message: 'boom');
      }
      return _account();
    });

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Could not load your account. Check your connection and retry.',
      ),
      findsOneWidget,
    );
    expect(find.text('boom'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(repository.calls, 2);
    expect(find.text('Ravi Kumar'), findsOneWidget);
  });

  testWidgets('ST02 Security row is a non-interactive placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_FakeAccountRepository(() async => _account())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Security'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountScreen), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
  });

  test('accountLoadError maps status codes to safe messages', () {
    expect(
      accountLoadError(const ApiException(statusCode: 401, message: 'x')),
      'Your session has expired. Sign in again and retry.',
    );
    expect(
      accountLoadError(const ApiException(statusCode: 404, message: 'x')),
      'Your account could not be found.',
    );
    expect(
      accountLoadError(Exception('anything')),
      'Could not load your account. Check your connection and retry.',
    );
  });
}
