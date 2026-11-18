import 'package:flutter/material.dart';
import '../../performance/data/m5_repository.dart';
import '../../performance/presentation/m5_records_screen.dart';

/// Athlete verification request history and status list.
class VerificationScreen extends StatelessWidget {
  const VerificationScreen({super.key});
  @override
  Widget build(BuildContext context) => M5RecordsScreen(
    title: 'Verification Centre', load: (repo) => repo.verification());
}
