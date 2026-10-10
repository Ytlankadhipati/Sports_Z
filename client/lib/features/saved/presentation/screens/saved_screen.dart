import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_z/core/network/api_exception.dart';
import 'package:sports_z/features/events/presentation/screens/event_detail_screen.dart';
import 'package:sports_z/features/opportunities/presentation/screens/opportunity_detail_screen.dart';
import 'package:sports_z/features/saved/data/models/saved_item.dart';
import 'package:sports_z/features/saved/presentation/controllers/saved_controller.dart';
import 'package:sports_z/shared/theme/app_theme.dart';

const _savedBottom = Color(0xFF120D02);

class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 220) {
        ref.read(savedItemsProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(savedFilterProvider);
    final saved = ref.watch(savedItemsProvider);
    return Scaffold(
      backgroundColor: _savedBottom,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.mustard900, _savedBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 2),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'Saved',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Icon(Icons.bookmark, color: AppColors.gold),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Text(
                  'Your bookmarked opportunities and events',
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _FilterPill(
                      label: 'All',
                      selected: filter == null,
                      onTap: () =>
                          ref.read(savedFilterProvider.notifier).select(null),
                    ),
                    _FilterPill(
                      label: 'Opportunities',
                      selected: filter == 'opportunity',
                      onTap: () => ref
                          .read(savedFilterProvider.notifier)
                          .select('opportunity'),
                    ),
                    _FilterPill(
                      label: 'Events',
                      selected: filter == 'event',
                      onTap: () => ref
                          .read(savedFilterProvider.notifier)
                          .select('event'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _content(saved)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(AsyncValue<SavedItemsState> saved) {
    if (saved.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }
    if (saved.hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              apiErrorText(saved.error!),
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: () => ref.invalidate(savedItemsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final data = saved.requireValue;
    if (data.items.isEmpty) {
      return RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () => ref.read(savedItemsProvider.notifier).refresh(),
        child: ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 170),
            Center(
              child: Text(
                'Nothing saved yet',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.mustard800,
      onRefresh: () => ref.read(savedItemsProvider.notifier).refresh(),
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: data.items.length + (data.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == data.items.length) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SavedCard(
              item: data.items[index],
              onRemove: () => _remove(data.items[index]),
              onTap: () => _open(data.items[index]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _remove(SavedItem item) async {
    try {
      await ref
          .read(savedActionProvider.notifier)
          .setSaved(item.type, item.targetId, false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(apiErrorText(error)),
        ),
      );
    }
  }

  void _open(SavedItem item) {
    if (!item.available) return;
    final screen = item.type == 'opportunity'
        ? OpportunityDetailScreen(publicId: item.targetId)
        : EventDetailScreen(publicId: item.targetId);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 10),
    child: Material(
      color: selected ? AppColors.gold : const Color(0xFF302919),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? AppColors.gold : Colors.white38,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.mustard300,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ),
  );
}

class _SavedCard extends StatelessWidget {
  const _SavedCard({
    required this.item,
    required this.onRemove,
    required this.onTap,
  });

  final SavedItem item;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = item.available ? Colors.white : Colors.white38;
    return Material(
      color: item.available ? const Color(0xFF302919) : const Color(0xFF211F1A),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: item.available ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                ),
                child: Icon(_sportIcon(item.sportId), color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.available ? item.title : 'No longer available',
                      style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.available
                          ? item.opportunity != null
                                ? '${item.category} • ${item.opportunity!.organizationName} • ${item.location}'
                                : 'Event • ${item.location}'
                          : 'This item has been removed.',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                    if (item.available) ...[
                      const SizedBox(height: 8),
                      Text(
                        item.type == 'opportunity'
                            ? '${item.sportId.toUpperCase()} • ${item.opportunity?.status.toUpperCase() ?? ''}'
                            : '${item.sportId.toUpperCase()} • ${item.event?.status.toUpperCase() ?? ''}',
                        style: const TextStyle(
                          color: AppColors.mustard300,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.opportunity != null
                            ? 'Deadline: ${_date(item.opportunity!.deadline) ?? 'No deadline'}'
                            : 'Starts: ${_date(item.event?.startsAt) ?? 'Date unavailable'}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove from Saved',
                onPressed: onRemove,
                icon: const Icon(Icons.bookmark, color: AppColors.gold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _sportIcon(String sport) => switch (sport) {
    'athletics' => Icons.directions_run,
    'wrestling' => Icons.sports_mma,
    'football' => Icons.sports_soccer,
    _ => Icons.emoji_events,
  };

  String? _date(DateTime? value) => value == null
      ? null
      : '${value.day} ${_month(value.month)} ${value.year}';

  String _month(int month) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];
}
