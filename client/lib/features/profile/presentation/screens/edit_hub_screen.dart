import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
import 'edit_about_screen.dart';
import 'edit_basics_screen.dart';
import 'edit_physical_screen.dart';
import 'edit_sport_screen.dart';
import 'edit_sports_screen.dart';
import 'experience_screen.dart';

/// P02 — navigation hub for the v3.0 M1 athlete profile edit screens.
class EditHubScreen extends StatefulWidget {
  const EditHubScreen({super.key});

  @override
  State<EditHubScreen> createState() => _EditHubScreenState();
}

class _EditHubScreenState extends State<EditHubScreen> {
  static const _destinations = <_EditDestination>[
    _EditDestination(
      id: 'P03',
      title: 'Basics',
      description: 'Name and basic profile details',
      icon: Icons.badge_outlined,
    ),
    _EditDestination(
      id: 'P04',
      title: 'About',
      description: 'Your profile introduction',
      icon: Icons.notes_outlined,
    ),
    _EditDestination(
      id: 'P05',
      title: 'Sports',
      description: 'Manage your sports and primary sport',
      icon: Icons.sports_outlined,
    ),
    _EditDestination(
      id: 'P06',
      title: 'Sport details',
      description: 'Add or update details for a sport',
      icon: Icons.tune_outlined,
    ),
    _EditDestination(
      id: 'P07',
      title: 'Physical',
      description: 'Manage your physical profile details',
      icon: Icons.fitness_center_outlined,
    ),
    _EditDestination(
      id: 'P15',
      title: 'Experience',
      description: 'View and manage your experience',
      icon: Icons.workspace_premium_outlined,
    ),
  ];

  Future<void> _openBasics() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditBasicsScreen()),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Basic profile details saved.')),
      );
    }
  }

  Future<void> _openAbout() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditAboutScreen()),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('About section saved.')));
    }
  }

  Future<void> _openSports() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditSportsScreen()),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Sports updated.')));
    }
  }

  Future<void> _openSport() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditSportScreen()),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Sport details saved.')));
    }
  }

  Future<void> _openPhysical() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditPhysicalScreen()),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Physical details saved.')));
    }
  }

  Future<void> _openExperience() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ExperienceScreen()),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Experience updated.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit profile'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text('Your profile', style: AppTypography.h1),
          const SizedBox(height: 8),
          Text(
            'Choose a section to manage your athlete profile.',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Manage each supported profile section below. Experience entries can be added and edited from Experience.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          for (final destination in _destinations) ...[
            _DestinationCard(
              destination: destination,
              onTap: switch (destination.id) {
                'P03' => _openBasics,
                'P04' => _openAbout,
                'P05' => _openSports,
                'P06' => _openSport,
                'P07' => _openPhysical,
                'P15' => _openExperience,
                _ => null,
              },
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _EditDestination {
  final String id;
  final String title;
  final String description;
  final IconData icon;

  const _EditDestination({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });
}

class _DestinationCard extends StatelessWidget {
  final _EditDestination destination;
  final VoidCallback? onTap;

  const _DestinationCard({required this.destination, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.lightGold,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(destination.icon, color: AppColors.deepAccent),
        ),
        title: Row(
          children: [
            Expanded(child: Text(destination.title, style: AppTypography.h4)),
            Text(
              destination.id,
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.deepAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(destination.description, style: AppTypography.bodySmall),
        ),
        trailing: Icon(
          onTap == null ? Icons.lock_outline : Icons.arrow_forward_ios,
          size: onTap == null ? 18 : 15,
          color: onTap == null ? AppColors.textMuted : AppColors.deepAccent,
        ),
        enabled: onTap != null,
        onTap: onTap,
      ),
    );
  }
}
