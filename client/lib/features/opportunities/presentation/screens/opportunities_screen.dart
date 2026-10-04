import 'package:flutter/material.dart';
import 'package:sports_z/features/opportunities/data/datasources/opportunities_api.dart';
import 'package:sports_z/features/opportunities/data/models/opportunity.dart';
import 'package:sports_z/shared/theme/app_theme.dart';

class OpportunitiesScreen extends StatefulWidget {
  const OpportunitiesScreen({super.key});

  @override
  State<OpportunitiesScreen> createState() => _OpportunitiesScreenState();
}

class _OpportunitiesScreenState extends State<OpportunitiesScreen> {
  static const _filters = <String?, String>{
    null: 'All',
    'trial': 'Trials',
    'scholarship': 'Scholarships',
    'job': 'Jobs',
    'camp': 'Camps',
  };

  final _api = OpportunitiesApi();
  final _scroll = ScrollController();
  final List<Opportunity> _items = [];
  String? _cursor;
  String? _type;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _api.list(type: _type);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _cursor = page.nextCursor;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _api.list(type: _type, cursor: _cursor);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _setType(String? type) {
    if (type == _type) return;
    _type = type;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Opportunities')),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (final e in _filters.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: _type == e.key,
                      selectedColor: AppColors.goldSoft,
                      onSelected: (_) => _setType(e.key),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(child: Text('No opportunities found'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _OpportunityCard(item: _items[i]);
        },
      ),
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({required this.item});
  final Opportunity item;

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    final deadline = item.deadline;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Pill(text: _cap(item.type), color: AppColors.goldDark, bg: AppColors.goldSoft),
                const SizedBox(width: 8),
                _Pill(
                  text: item.isOpen ? 'Open' : 'Closed',
                  color: item.isOpen ? AppColors.success : AppColors.error,
                  bg: (item.isOpen ? AppColors.success : AppColors.error).withValues(alpha: 0.12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(item.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${item.organizationName} • ${item.location}', style: TextStyle(color: muted)),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.sports, size: 16, color: muted),
                const SizedBox(width: 6),
                Text(_cap(item.sportId), style: TextStyle(color: muted)),
                const Spacer(),
                if (deadline != null)
                  Text(
                    item.isOpen ? 'Apply by ${formatDate(deadline)}' : 'Closed ${formatDate(deadline)}',
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color, required this.bg});
  final String text;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}