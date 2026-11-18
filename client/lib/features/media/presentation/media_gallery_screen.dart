import 'package:flutter/material.dart';
import '../../performance/data/m5_repository.dart';
import '../../performance/presentation/m5_records_screen.dart';

/// Athlete's evidence/media list. Upload and moderation endpoints are in M5Repository/API.
class MediaGalleryScreen extends StatelessWidget {
  const MediaGalleryScreen({super.key});
  @override
  Widget build(BuildContext context) => M5RecordsScreen(
    title: 'Media & Evidence', load: (repo) => repo.media());
}
