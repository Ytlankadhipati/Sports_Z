import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_z/features/opportunities/data/models/opportunity.dart';
import 'package:sports_z/features/opportunities/presentation/screens/opportunity_detail_screen.dart';
import 'package:sports_z/features/opportunities/presentation/controllers/opportunities_controller.dart';
import 'package:sports_z/shared/theme/app_theme.dart';

const _bgTop = AppColors.mustard900;
const _bgBottom = Color(0xFF120D02);
const _okColor = Color(0xFF5CD68A);
const _badColor = Color(0xFFFF8A80);

class OpportunitiesScreen extends ConsumerStatefulWidget {
  const OpportunitiesScreen({super.key});

  @override
  ConsumerState<OpportunitiesScreen> createState() =>
      _OpportunitiesScreenState();
}

class _OpportunitiesScreenState extends ConsumerState<OpportunitiesScreen> {
  static const _filters = <String?, String>{
    null: 'All',
    'trial': 'Trials',
    'scholarship': 'Scholarships',
    'job': 'Jobs',
    'camp': 'Camps',
  };

  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    ref.read(opportunitiesControllerProvider.notifier).load(status: 'open');
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        ref.read(opportunitiesControllerProvider.notifier).loadMore(
          status: 'open',
          type: ref.read(opportunityTypeProvider),
        );
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _setType(String? type) {
    ref.read(opportunityTypeProvider.notifier).select(type);
    ref.read(opportunitiesControllerProvider.notifier).load(
      status: 'open',
      type: type,
    );
  }

  void _openDetail(Opportunity item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            OpportunityDetailScreen(publicId: item.publicId, preview: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bgBottom,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bgTop, _bgBottom],
            ),
          ),
          child: Column(
            children: [
              const _Header(
                title: 'Opportunities',
                tagline: 'TRIALS  •  SCHOLARSHIPS  •  JOBS',
              ),
              SizedBox(
                height: 58,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  children: [
                    for (final e in _filters.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FilterPill(
                          label: e.value,
                          selected: ref.watch(opportunityTypeProvider) == e.key,
                          onTap: () => _setType(e.key),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    final opportunities = ref.watch(opportunitiesControllerProvider);
    if (opportunities.isLoading && opportunities.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (opportunities.errorMessage != null && opportunities.items.isEmpty) {
      final message = opportunities.errorMessage!;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(opportunitiesControllerProvider.notifier).refresh(
                      status: 'open',
                      type: ref.read(opportunityTypeProvider),
                    ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final data = opportunities;
    if (data.items.isEmpty) {
      return RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () => ref.read(opportunitiesControllerProvider.notifier).refresh(
          status: 'open',
          type: ref.read(opportunityTypeProvider),
        ),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Center(
              child: Text(
                'No opportunities found',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.mustard800,
      onRefresh: () => ref.read(opportunitiesControllerProvider.notifier).refresh(
        status: 'open',
        type: ref.read(opportunityTypeProvider),
      ),
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: data.items.length + (data.isLoadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (_, i) {
          if (i >= data.items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final item = data.items[i];
          return _OpportunityCard(item: item, onTap: () => _openDetail(item));
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.tagline});
  final String title;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return SizedBox(
      height: 190 + top,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/splash_bg.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, _, _) => const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: AppColors.splashGradient,
                ),
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66000000), Color(0x99000000), _bgTop],
              ),
            ),
          ),
          if (Navigator.of(context).canPop())
            Positioned(
              top: top + 4,
              left: 4,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tagline,
                  style: const TextStyle(
                    color: AppColors.mustard300,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.goldBright,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gold
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? AppColors.goldBright
                : Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({required this.item, required this.onTap});
  final Opportunity item;
  final VoidCallback onTap;

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  IconData _icon(String sport) {
    switch (sport) {
      case 'athletics':
        return Icons.directions_run;
      case 'wrestling':
        return Icons.sports_mma;
      case 'football':
        return Icons.sports_soccer;
      default:
        return Icons.emoji_events;
    }
  }

  @override
  Widget build(BuildContext context) {
    final deadline = item.deadline;
    final open = item.isOpen;
    final deadlineText = deadline == null
        ? 'No deadline'
        : open
        ? 'Apply by ${formatDate(deadline)}'
        : 'Closed on ${formatDate(deadline)}';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.mustard500, AppColors.mustard700],
                    ),
                  ),
                  child: Icon(
                    _icon(item.sportId),
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.organizationName} • ${item.location}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _Tag(text: _cap(item.type), color: AppColors.mustard300),
                const SizedBox(width: 8),
                _Tag(
                  text: open ? 'Open' : 'Closed',
                  color: open ? _okColor : _badColor,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.schedule,
                  size: 16,
                  color: AppColors.goldBright,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    deadlineText,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white38),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
