import 'package:flutter/material.dart';
import '../data/m5_repository.dart';
import 'm5_records_screen.dart';
class PerformanceScreen extends StatelessWidget {
 const PerformanceScreen({super.key});
 @override Widget build(BuildContext context) => M5RecordsScreen(title: 'My Performance', load: (r) => r.performance());
}
class AchievementsScreen extends StatelessWidget {
 const AchievementsScreen({super.key});
 @override Widget build(BuildContext context) => M5RecordsScreen(title: 'Achievements', load: (r) => r.achievements());
}
class MediaGalleryScreen extends StatelessWidget {
 const MediaGalleryScreen({super.key});
 @override Widget build(BuildContext context) => M5RecordsScreen(title: 'Media Gallery', load: (r) => r.media());
}
class DocumentsScreen extends StatelessWidget {
 const DocumentsScreen({super.key});
 @override Widget build(BuildContext context) => M5RecordsScreen(title: 'My Documents', load: (r) => r.documents());
}
class VerificationScreen extends StatelessWidget {
 const VerificationScreen({super.key});
 @override Widget build(BuildContext context) => M5RecordsScreen(title: 'Verification Centre', load: (r) => r.verification());
}
