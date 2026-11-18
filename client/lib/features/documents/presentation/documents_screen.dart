import 'package:flutter/material.dart';
import '../../performance/data/m5_repository.dart';
import '../../performance/presentation/m5_records_screen.dart';

/// Private athlete documents list. Download URLs must only be requested for the owner.
class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});
  @override
  Widget build(BuildContext context) => M5RecordsScreen(
    title: 'My Documents', load: (repo) => repo.documents());
}
