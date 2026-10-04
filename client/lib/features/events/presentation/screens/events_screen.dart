import 'package:flutter/material.dart';
import 'package:sports_z/features/events/data/datasources/events_api.dart';
import 'package:sports_z/features/events/data/models/event.dart';
import 'package:sports_z/shared/theme/app_theme.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  static const _filters = <String, String>{
    'upcoming': 'Upcoming',
    'ongoing': 'Ongoing',
    'completed': 'Completed',
  };

  final _api = EventsApi();
  final _scroll = ScrollController();
  final List<SportEvent> _items = [];
  String? _cursor;
  String _status = 'upcoming';
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
      final page = await _api.list(status: _status);
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
      final page = await _api.list(status: _status, cursor: _cursor);
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

  void _setStatus(String status) {
    if (status == _status) return;
    _status = status;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
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
                      selected: _status == e.key,
                      selectedColor: AppColors.goldSoft,
                      onSelected: (_) => _setStatus(e.key),
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
    if (_items.isEmpty) return const Center(child: Text('No events found'));
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
          return _EventCard(item: _items[i]);
        },
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.item});
  final SportEvent item;

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    final starts = item.startsAt;
    final deadline = item.registrationDeadline;
    final showSeats = item.status == 'upcoming';
    final seatColor = item.isFull ? AppColors.error : AppColors.success;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.goldSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _cap(item.sportId),
                    style: const TextStyle(
                      color: AppColors.goldDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                if (showSeats)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: seatColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      item.isFull ? 'Full' : '${item.seatsLeft} seats left',
                      style: TextStyle(color: seatColor, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(item.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.place_outlined, size: 16, color: muted),
                const SizedBox(width: 6),
                Text(item.location, style: TextStyle(color: muted)),
              ],
            ),
            if (starts != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.event_outlined, size: 16, color: muted),
                  const SizedBox(width: 6),
                  Text(formatEventDate(starts), style: TextStyle(color: muted)),
                ],
              ),
            ],
            if (showSeats && deadline != null) ...[
              const SizedBox(height: 8),
              Text('Register by ${formatEventDate(deadline)}',
                  style: TextStyle(color: muted, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}