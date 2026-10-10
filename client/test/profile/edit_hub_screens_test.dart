import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_z/features/profile/presentation/screens/edit_experience_screen.dart';
import 'package:sports_z/features/profile/presentation/screens/edit_physical_screen.dart';
import 'package:sports_z/features/profile/presentation/screens/edit_sport_screen.dart';
import 'package:sports_z/features/profile/presentation/screens/edit_sports_screen.dart';
import 'package:sports_z/features/profile/presentation/screens/experience_screen.dart';

Widget _app(Widget home) => ProviderScope(child: MaterialApp(home: home));

void main() {
  testWidgets('P07 maps physical fields and sends only editable values', (
    tester,
  ) async {
    final payloads = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      _app(
        EditPhysicalScreen(
          loadProfile: () async => {
            'physical': {
              'height_cm': 180,
              'weight_kg': 75,
              'dominant_hand': 'Right',
            },
          },
          saveProfile: (payload) async => payloads.add(payload),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fields = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .toList();
    expect(fields[0].controller?.text, '180');
    expect(fields[1].controller?.text, '75');
    await tester.enterText(find.byType(TextFormField).first, '182');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(payloads.single['height_cm'], 182.0);
    expect(payloads.single['weight_kg'], 75.0);
    expect(payloads.single.keys, isNot(contains('user_id')));
  });

  testWidgets('P05 lists profile sports and sets primary using own-sport API', (
    tester,
  ) async {
    var changedId = '';
    await tester.pumpWidget(
      _app(
        EditSportsScreen(
          loadProfile: () async => {
            'sports': [
              {
                'sport_id': 'cricket',
                'sport_name': 'Cricket',
                'is_primary': false,
                'positions': ['Batter'],
                'level': 'State',
              },
            ],
          },
          setPrimary: (id) async => changedId = id,
          deleteSport: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cricket'), findsOneWidget);
    await tester.tap(find.text('Set primary'));
    await tester.pumpAndSettle();
    expect(changedId, 'cricket');
  });

  testWidgets('P06 loads catalog and saves supported sport details', (
    tester,
  ) async {
    final payloads = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      _app(
        EditSportScreen(
          loadSports: () async => [
            {'sport_id': 'cricket', 'name': 'Cricket'},
          ],
          loadProfile: () async => {'sports': []},
          loadConfig: (_) async => {
            'sport': {
              'config': {'fields': []},
            },
          },
          saveSport: (id, payload) async =>
              payloads.add({'sport_id': id, ...payload}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cricket').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Batter, Wicket Keeper',
    );
    await tester.enterText(find.byType(TextFormField).last, 'State');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(payloads.single, {
      'sport_id': 'cricket',
      'positions': ['Batter', 'Wicket Keeper'],
      'level': 'State',
    });
  });

  testWidgets('P15 shows empty state and opens P16 add experience', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        ExperienceScreen(
          loadProfile: () async => {'experience': []},
          loadOrganizations: () async => [],
          deleteExperience: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No experience added yet.'), findsOneWidget);
    await tester.tap(find.text('Add experience'));
    await tester.pumpAndSettle();
    expect(find.text('Add experience'), findsWidgets);
    expect(find.text('Role or title'), findsOneWidget);
  });

  testWidgets('P16 posts experience payload with selected organization', (
    tester,
  ) async {
    final payloads = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      _app(
        EditExperienceScreen(
          loadOrganizations: () async => [
            {'public_id': 'org-1', 'name': 'Club One'},
          ],
          createExperience: (payload) async => payloads.add(payload),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Player');
    await tester.enterText(find.byType(TextFormField).at(1), '2020');
    await tester.enterText(find.byType(TextFormField).at(2), '2024');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Club One').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(payloads.single['title'], 'Player');
    expect(payloads.single['organization_id'], 'org-1');
    expect(payloads.single['started_year'], 2020);
    expect(payloads.single['ended_year'], 2024);
    expect(payloads.single.keys, isNot(contains('user_id')));
  });
}
