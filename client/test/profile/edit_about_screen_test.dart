import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_z/core/network/api_exception.dart';
import 'package:sports_z/features/profile/presentation/screens/edit_about_screen.dart';
import 'package:sports_z/features/profile/presentation/screens/edit_hub_screen.dart';

Map<String, dynamic> _profileResponse({
  String bio = 'A short athlete introduction.',
}) => {'bio': bio};

Widget _app(Widget home) => ProviderScope(child: MaterialApp(home: home));

void main() {
  testWidgets('P02 opens P04 Edit About', (tester) async {
    await tester.pumpWidget(_app(EditHubScreen()));
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();

    expect(find.text('Edit about'), findsOneWidget);
  });

  testWidgets('shows loading state until profile data arrives', (tester) async {
    final response = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      _app(
        EditAboutScreen(
          loadProfile: () => response.future,
          saveProfile: (_) async {},
        ),
      ),
    );
    expect(find.text('Loading your profile…'), findsOneWidget);

    response.complete(_profileResponse());
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller?.text,
      'A short athlete introduction.',
    );
  });

  testWidgets('saves bio through P01 profile patch and returns success', (
    tester,
  ) async {
    final payloads = <Map<String, dynamic>>[];
    final results = <bool?>[];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => results.add(
                  await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditAboutScreen(
                        loadProfile: () async => _profileResponse(),
                        saveProfile: (payload) async {
                          payloads.add(payload);
                        },
                      ),
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Updated bio');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(payloads, [
      {'bio': 'Updated bio'},
    ]);
    expect(payloads.single.keys, isNot(contains('user_id')));
    expect(results, [true]);
  });

  testWidgets('save failure preserves text and shows safe error', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: EditAboutScreen(
            loadProfile: () async => _profileResponse(),
            saveProfile: (_) async => throw const ApiException(
              message: 'Could not save your changes. Please try again.',
              statusCode: 503,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Draft bio');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller?.text,
      'Draft bio',
    );
    expect(
      find.text('Could not save your changes. Please try again.'),
      findsWidgets,
    );
  });

  testWidgets('load failure offers retry', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: EditAboutScreen(
            loadProfile: () async {
              if (++calls == 1) {
                throw const ApiException(
                  message: 'Could not load your profile. Check your connection and retry.',
                  statusCode: 503,
                );
              }
              return _profileResponse();
            },
            saveProfile: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('A short athlete introduction.'), findsOneWidget);
  });
}
