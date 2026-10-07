import 'package:flutter_test/flutter_test.dart';
import 'package:sports_z/features/onboarding/presentation/screens/athlete_onboarding_flow.dart';

void main() {
  test('onboarding follows the final ten-screen ownership sequence', () {
    expect(AthleteOnboardingStep.values.map((step) => step.id).toList(), [
      'O01',
      'O02',
      'O05',
      'O06',
      'O07',
      'O08',
      'O09',
      'O10',
      'O11',
      'O12',
    ]);
    expect(AthleteOnboardingStep.values, hasLength(10));
  });
}
