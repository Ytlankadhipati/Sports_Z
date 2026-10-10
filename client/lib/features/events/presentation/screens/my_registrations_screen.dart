import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_z/core/network/api_exception.dart';
import 'package:sports_z/features/events/data/models/event.dart';
import 'package:sports_z/features/events/presentation/screens/event_detail_screen.dart';
import 'package:sports_z/features/events/presentation/controllers/events_controller.dart';
import 'package:sports_z/shared/theme/app_theme.dart';

const _myTop = AppColors.mustard900;
const _myBottom = Color(0xFF120D02);

class MyRegistrationsScreen extends ConsumerStatefulWidget {
  const MyRegistrationsScreen({super.key});

  @override
  ConsumerState<MyRegistrationsScreen> createState() =>
      _MyRegistrationsScreenState();
}

class _MyRegistrationsScreenState extends ConsumerState<MyRegistrationsScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        ref.read(myRegistrationsProvider.notifier).loadMore();
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
    final registrations = ref.watch(myRegistrationsProvider);
    final action = ref.watch(eventRegistrationActionProvider);

    return Scaffold(
      backgroundColor: _myBottom,
      appBar: AppBar(
        backgroundColor: _myTop,
        foregroundColor: Colors.white,
        title: const Text('My registrations'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_myTop, _myBottom],
          ),
        ),
        child: _body(registrations, action),
      ),
    );
  }

  Widget _body(
    AsyncValue<MyRegistrationsState> registrations,
    AsyncValue<EventRegistrationResult?> action,
  ) {
    if (registrations.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (registrations.hasError) {
      return _ErrorPanel(
        message: _message(registrations.error),
        onRetry: () => ref.read(myRegistrationsProvider.notifier).refresh(),
      );
    }
    final data = registrations.requireValue;
    if (data.items.isEmpty) {
      return RefreshIndicator(
        color: AppColors.gold,
        backgroundColor: AppColors.mustard800,
        onRefresh: () => ref.read(myRegistrationsProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 220),
            Center(
              child: Text(
                'No registrations yet',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }
    final actionError = action.hasError ? _message(action.error) : null;
    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.mustard800,
      onRefresh: () => ref.read(myRegistrationsProvider.notifier).refresh(),
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        itemCount: data.items.length + (data.isLoadingMore ? 1 : 0),
        separatorBuilder: (_, index) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          if (index >= data.items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final registration = data.items[index];
          return _RegistrationCard(
            registration: registration,
            error: actionError,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EventDetailScreen(
                  event: SportEvent(
                    publicId: registration.eventPublicId,
                    title: registration.title,
                    sportId: '',
                    location: registration.location,
                    startsAt: registration.startsAt,
                    registrationDeadline: null,
                    seatsLeft: 0,
                    status: 'upcoming',
                    registrationState: registration.registrationStatus,
                  ),
                ),
              ),
            ),
            onCancel: () => _confirmCancel(registration),
          );
        },
      ),
    );
  }

  Future<void> _confirmCancel(MyEventRegistration registration) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel registration?'),
        content: Text('Cancel your registration for ${registration.title}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep registration'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel registration'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      await ref
          .read(eventRegistrationActionProvider.notifier)
          .cancel(registration.eventPublicId);
    } catch (_) {
      // The action provider displays the API error on this screen.
    }
  }
}

class _RegistrationCard extends StatelessWidget {
  const _RegistrationCard({
    required this.registration,
    required this.onTap,
    required this.onCancel,
    this.error,
  });

  final MyEventRegistration registration;
  final VoidCallback onTap;
  final VoidCallback onCancel;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final waitlisted = registration.registrationStatus == 'waitlisted';
    final startsAt = registration.startsAt;
    final errorMessage = error;
    return GestureDetector(
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
            Text(
              registration.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${registration.location} • ${startsAt == null ? 'Date TBA' : formatEventDate(startsAt)}',
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatusTag(
                  label: waitlisted ? 'Waitlisted' : 'Registered',
                  color: waitlisted
                      ? AppColors.mustard300
                      : const Color(0xFF5CD68A),
                ),
                const Spacer(),
                TextButton(onPressed: onCancel, child: const Text('Cancel')),
              ],
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                errorMessage,
                style: const TextStyle(color: Color(0xFFFF8A80)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
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
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

String _message(Object? error) => error == null
    ? 'Something went wrong.'
    : apiErrorText(error);
