import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_z/features/events/data/models/event.dart';
import 'package:sports_z/features/events/presentation/screens/my_registrations_screen.dart';
import 'package:sports_z/features/events/presentation/state/events_providers.dart';
import 'package:sports_z/features/saved/presentation/state/saved_providers.dart';
import 'package:sports_z/shared/theme/app_theme.dart';

const _detailTop = AppColors.mustard900;
const _detailBottom = Color(0xFF120D02);

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, this.event, this.publicId})
    : assert(event != null || publicId != null);

  final SportEvent? event;
  final String? publicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = publicId ?? event!.publicId;
    final detailState = ref.watch(eventDetailProvider(id));
    final detail = detailState.asData?.value;
    final summary = detail?.summary ?? event;
    final error = detailState.hasError
        ? detailState.error.toString().replaceFirst('Exception: ', '')
        : null;

    if (summary == null) {
      return Scaffold(
        backgroundColor: _detailBottom,
        body: Center(
          child: detailState.isLoading
              ? const CircularProgressIndicator(color: AppColors.gold)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      error ?? 'Could not load event details.',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    TextButton(
                      onPressed: () => ref.invalidate(eventDetailProvider(id)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _detailBottom,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_detailTop, _detailBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Text(
                    'Event details',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  _EventBookmark(
                    publicId: id,
                    isSaved: detail?.isSaved ?? false,
                  ),
                ],
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.gold,
                  backgroundColor: AppColors.mustard800,
                  onRefresh: () async {
                    ref.invalidate(eventDetailProvider(id));
                    await ref.read(eventDetailProvider(id).future);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      _EventDetailCard(event: summary),
                      const SizedBox(height: 16),
                      _EventInfoCard(event: summary),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: _cardDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'About this event',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (detail != null)
                              Text(
                                detail.description.trim().isEmpty
                                    ? 'Not provided yet.'
                                    : detail.description,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              )
                            else if (detailState.isLoading)
                              const LinearProgressIndicator(minHeight: 3)
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    error ?? 'Could not load event details.',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        ref.invalidate(eventDetailProvider(id)),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _RegistrationButton(event: summary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventBookmark extends ConsumerStatefulWidget {
  const _EventBookmark({required this.publicId, required this.isSaved});

  final String publicId;
  final bool isSaved;

  @override
  ConsumerState<_EventBookmark> createState() => _EventBookmarkState();
}

class _EventBookmarkState extends ConsumerState<_EventBookmark> {
  bool? _optimisticValue;
  bool _busy = false;

  @override
  void didUpdateWidget(covariant _EventBookmark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSaved != widget.isSaved && !_busy) {
      _optimisticValue = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaved = _optimisticValue ?? widget.isSaved;
    return IconButton(
      tooltip: isSaved ? 'Remove from Saved' : 'Save event',
      onPressed: _busy ? null : () => _toggle(isSaved),
      icon: Icon(
        isSaved ? Icons.bookmark : Icons.bookmark_border,
        color: AppColors.gold,
      ),
    );
  }

  Future<void> _toggle(bool previous) async {
    final next = !previous;
    setState(() {
      _busy = true;
      _optimisticValue = next;
    });
    try {
      await ref
          .read(savedActionProvider.notifier)
          .setSaved('event', widget.publicId, next);
      if (!mounted) return;
      ref.invalidate(eventDetailProvider(widget.publicId));
    } catch (error) {
      if (!mounted) return;
      setState(() => _optimisticValue = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _RegistrationButton extends StatelessWidget {
  const _RegistrationButton({required this.event});

  final SportEvent event;

  bool get _closed {
    final deadline = event.registrationDeadline;
    return event.status != 'upcoming' ||
        (deadline != null && !deadline.isAfter(DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    final registered = event.registrationState == 'registered';
    final waitlisted = event.registrationState == 'waitlisted';
    final disabled = _closed || registered || waitlisted;
    final label = registered
        ? 'Registered'
        : waitlisted
        ? 'Waitlisted'
        : _closed
        ? 'Registration closed'
        : event.isFull
        ? 'Join waitlist'
        : 'Register';

    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: disabled
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EventRegistrationConfirmScreen(event: event),
                ),
              ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.white12,
          disabledForegroundColor: Colors.white70,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class EventRegistrationConfirmScreen extends ConsumerWidget {
  const EventRegistrationConfirmScreen({super.key, required this.event});

  final SportEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = ref.watch(eventRegistrationActionProvider);
    final isLoading = action.isLoading;
    final error = action.hasError
        ? action.error.toString().replaceFirst('Exception: ', '')
        : null;

    return Scaffold(
      backgroundColor: _detailBottom,
      appBar: AppBar(
        backgroundColor: _detailTop,
        foregroundColor: Colors.white,
        title: const Text('Confirm registration'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_detailTop, _detailBottom],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _EventDetailCard(event: event),
            const SizedBox(height: 20),
            Text(
              event.isFull
                  ? 'This event is full. Confirm to join its waitlist.'
                  : 'Confirm your registration for this event.',
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            if (error != null) ...[
              const SizedBox(height: 14),
              Text(error, style: const TextStyle(color: Color(0xFFFF8A80))),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        try {
                          final result = await ref
                              .read(eventRegistrationActionProvider.notifier)
                              .register(event.publicId);
                          if (!context.mounted) return;
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) =>
                                  EventRegistrationConfirmationScreen(
                                    result: result,
                                  ),
                            ),
                          );
                        } catch (_) {
                          // The action provider exposes the user-facing error.
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Confirm',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EventRegistrationConfirmationScreen extends StatelessWidget {
  const EventRegistrationConfirmationScreen({super.key, required this.result});

  final EventRegistrationResult result;

  @override
  Widget build(BuildContext context) {
    final waitlisted = result.status == 'waitlisted';
    return Scaffold(
      backgroundColor: _detailBottom,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_detailTop, _detailBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    waitlisted ? Icons.hourglass_top : Icons.check_circle,
                    size: 64,
                    color: AppColors.goldBright,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    waitlisted
                        ? 'You joined the waitlist'
                        : 'Registration confirmed',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    waitlisted
                        ? 'You will be notified if a place becomes available.'
                        : 'Your place at this event is reserved.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MyRegistrationsScreen(),
                      ),
                    ),
                    child: const Text('My registrations'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to event'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EventDetailCard extends StatelessWidget {
  const _EventDetailCard({required this.event});

  final SportEvent event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${event.sportId} • ${event.location}',
            style: const TextStyle(color: Colors.white60, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _EventInfoCard extends StatelessWidget {
  const _EventInfoCard({required this.event});

  final SportEvent event;

  @override
  Widget build(BuildContext context) {
    final startsAt = event.startsAt;
    final deadline = event.registrationDeadline;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoLine(
            icon: Icons.event,
            label: 'Date',
            value: startsAt == null
                ? 'Date to be announced'
                : formatEventDate(startsAt),
          ),
          const SizedBox(height: 12),
          _InfoLine(
            icon: Icons.place_outlined,
            label: 'Location',
            value: event.location,
          ),
          const SizedBox(height: 12),
          _InfoLine(
            icon: Icons.groups_outlined,
            label: 'Availability',
            value: event.isFull ? 'Full' : '${event.seatsLeft} seats left',
          ),
          if (deadline != null) ...[
            const SizedBox(height: 12),
            _InfoLine(
              icon: Icons.schedule,
              label: 'Registration deadline',
              value: formatEventDate(deadline),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: AppColors.goldBright, size: 19),
      const SizedBox(width: 10),
      SizedBox(
        width: 145,
        child: Text(label, style: const TextStyle(color: Colors.white60)),
      ),
      Expanded(
        child: Text(value, style: const TextStyle(color: Colors.white)),
      ),
    ],
  );
}

BoxDecoration _cardDecoration() => BoxDecoration(
  color: Colors.white.withValues(alpha: 0.07),
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
);
