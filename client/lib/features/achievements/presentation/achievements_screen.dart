import 'package:flutter/material.dart';
import '../../performance/data/m5_repository.dart';
import '../../performance/presentation/m5_records_screen.dart';

/// M5 achievement list. Uses the shared authenticated Dio client through M5Repository.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});
  @override
  Widget build(BuildContext context) => M5RecordsScreen(
    title: 'Achievements', load: (repo) => repo.achievements());
}
