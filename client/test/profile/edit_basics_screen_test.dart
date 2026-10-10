import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_z/core/network/api_exception.dart';
import 'package:sports_z/features/profile/presentation/screens/edit_basics_screen.dart';
import 'package:sports_z/features/profile/presentation/screens/edit_hub_screen.dart';

Map<String, dynamic> _profileResponse({
  String fullName = 'Aarav Patel',
  String gender = 'male',
  String? dateOfBirth = '2002-08-14',
  String city = 'Pune',
  String region = 'Maharashtra',
}) => {
  'full_name': fullName,
  'gender': gender,
  'date_of_birth': dateOfBirth,
  'city': city,
  'region': region,
};

Widget _app(Widget home) => ProviderScope(child: MaterialApp(home: home));

Future<void> _pumpEditBasics(
  WidgetTester tester, {
  required Future<Map<String, dynamic>> Function() load,
  required Future<void> Function(Map<String, dynamic>) save,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: EditBasicsScreen(loadProfile: load, saveProfile: save),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('P02 opens P03 Edit Basics', (tester) async {
    await tester.pumpWidget(_app(const EditHubScreen()));
    await tester.tap(find.text('Basics'));
    await tester.pumpAndSettle();

    expect(find.text('Edit basics'), findsOneWidget);
  });

  testWidgets('shows loading state until profile data arrives', (tester) async {
    final response = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      _app(
        EditBasicsScreen(
          loadProfile: () => response.future,
          saveProfile: (_) async {},
        ),
      ),
    );

    expect(find.text('Loading your profile…'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);

    response.complete(_profileResponse());
    await tester.pumpAndSettle();

    expect(find.text('14 August 2002'), findsOneWidget);
  });

  testWidgets('loads profile response values into the form', (tester) async {
    await _pumpEditBasics(
      tester,
      load: () async => _profileResponse(),
      save: (_) async {},
    );

    final fields = tester.widgetList<TextFormField>(find.byType(TextFormField));
    expect(fields.first.controller?.text, 'Aarav Patel');
    expect(find.text('Male'), findsOneWidget);
    expect(find.text('14 August 2002'), findsOneWidget);
  });

  testWidgets('validates required basics before sending a save', (
    tester,
  ) async {
    var saveCalled = false;
    await _pumpEditBasics(
      tester,
      load: () async => _profileResponse(
        fullName: '',
        gender: '',
        dateOfBirth: null,
        city: '',
        region: '',
      ),
      save: (_) async {
        saveCalled = true;
      },
    );

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your full name.'), findsOneWidget);
    expect(find.text('Choose your gender.'), findsOneWidget);
    expect(find.text('Select your date of birth.'), findsOneWidget);
    expect(saveCalled, isFalse);
  });

  testWidgets('save failure preserves entered values and offers safe error', (
    tester,
  ) async {
    var saveCalls = 0;
    await _pumpEditBasics(
      tester,
      load: () async => _profileResponse(),
      save: (_) async {
        saveCalls++;
        throw const ApiException(
          message: 'Could not save your changes. Please try again.',
          statusCode: 503,
        );
      },
    );

    await tester.enterText(find.byType(TextFormField).first, 'Aarav New Name');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    final fields = tester.widgetList<TextFormField>(find.byType(TextFormField));
    expect(fields.first.controller?.text, 'Aarav New Name');
    expect(saveCalls, 1);
    expect(
      find.text('Could not save your changes. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('successful save sends P03 fields and returns a success result', (
    tester,
  ) async {
    final savedPayloads = <Map<String, dynamic>>[];
    final routeResults = <bool?>[];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    routeResults.add(
                      await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditBasicsScreen(
                            loadProfile: () async => _profileResponse(),
                            saveProfile: (payload) async {
                              savedPayloads.add(payload);
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Edit Basics'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Edit Basics'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Aarav Updated');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(routeResults, [true]);
    expect(savedPayloads, hasLength(1));
    expect(savedPayloads.single, {
      'full_name': 'Aarav Updated',
      'date_of_birth': '2002-08-14',
      'gender': 'male',
      'city': 'Pune',
      'region': 'Maharashtra',
    });
    expect(savedPayloads.single.keys, isNot(contains('user_id')));
  });

  testWidgets('load failure shows retry and recovers with profile data', (
    tester,
  ) async {
    var loadCount = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: EditBasicsScreen(
            loadProfile: () async {
              loadCount++;
              if (loadCount == 1) {
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

    expect(loadCount, 2);
    expect(find.text('14 August 2002'), findsOneWidget);
  });
}
