import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/providers.dart';
import '../../data/models/event.dart';
import '../../data/repositories/events_repository.dart';

final eventsRepositoryProvider = Provider<EventsRepository>(
  (ref) => EventsRepository(ref.watch(dioProvider)),
);

final eventsControllerProvider =
    NotifierProvider<EventsController, EventsFeedState>(EventsController.new);

class EventsFeedState {
  const EventsFeedState({
    this.items = const [],
    this.nextCursor,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  final List<SportEvent> items;
  final String? nextCursor;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;
}

class EventsController extends Notifier<EventsFeedState> {
  @override
  EventsFeedState build() => const EventsFeedState();

  Future<void> load({required String status}) async {
    state = const EventsFeedState(isLoading: true);
    try {
      final page = await ref
          .read(eventsRepositoryProvider)
          .list(status: status);
      state = EventsFeedState(
        items: page.items,
        nextCursor: page.nextCursor,
        isLoading: false,
      );
    } catch (error) {
      state = EventsFeedState(
        errorMessage: apiErrorText(error),
        isLoading: false,
      );
    }
  }

  Future<void> loadMore({required String status}) async {
    final cursor = state.nextCursor;
    if (state.isLoading || state.isLoadingMore || cursor == null) return;
    state = EventsFeedState(
      items: state.items,
      nextCursor: cursor,
      isLoadingMore: true,
    );
    try {
      final page = await ref
          .read(eventsRepositoryProvider)
          .list(status: status, cursor: cursor);
      state = EventsFeedState(
        items: [...state.items, ...page.items],
        nextCursor: page.nextCursor,
      );
    } catch (_) {
      state = EventsFeedState(items: state.items, nextCursor: cursor);
    }
  }
}
