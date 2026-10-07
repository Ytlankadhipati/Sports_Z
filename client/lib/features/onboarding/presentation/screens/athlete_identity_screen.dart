import 'package:flutter/material.dart';

import 'athlete_onboarding_flow.dart';

/// Backwards-compatible entry point used by the existing authentication flow.
class AthleteIdentityScreen extends StatelessWidget {
  const AthleteIdentityScreen({super.key});

  @override
  Widget build(BuildContext context) => const AthleteOnboardingFlow();
}
