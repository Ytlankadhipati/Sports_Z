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

final eventStatusProvider = NotifierProvider<EventStatusNotifier, String>(
  EventStatusNotifier.new,
);

class EventStatusNotifier extends Notifier<String> {
  @override
  String build() => 'upcoming';

  void select(String status) {
    if (state != status) state = status;
  }
}

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
  final Map<String, EventPage> _pageCache = {};
  String? _loadingStatus;
  int _requestId = 0;

  @override
  EventsFeedState build() => const EventsFeedState();

  Future<void> load({required String status}) async {
    final cached = _pageCache[status];
    if (_loadingStatus == status) return;
    final requestId = ++_requestId;
    _loadingStatus = status;
    state = EventsFeedState(
      items: cached?.items ?? const [],
      nextCursor: cached?.nextCursor,
      isLoading: true,
    );
    try {
      final page = await ref
          .read(eventsRepositoryProvider)
          .list(status: status);
      _pageCache[status] = page;
      if (requestId != _requestId) return;
      state = EventsFeedState(
        items: page.items,
        nextCursor: page.nextCursor,
        isLoading: false,
      );
    } catch (error) {
      if (requestId != _requestId) return;
      state = EventsFeedState(
        items: cached?.items ?? const [],
        nextCursor: cached?.nextCursor,
        errorMessage: apiErrorText(error),
        isLoading: false,
      );
    } finally {
      if (_loadingStatus == status) _loadingStatus = null;
    }
  }

  Future<void> refresh({required String status}) => load(status: status);

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

final eventDetailProvider = FutureProvider.autoDispose
    .family<EventDetail, String>((ref, publicId) async {
      try {
        return await ref.watch(eventsRepositoryProvider).getById(publicId);
      } catch (error) {
        if (apiExceptionFrom(error)?.statusCode == 404) {
          throw const ApiException(
            message: 'This event is no longer available.',
            statusCode: 404,
          );
        }
        rethrow;
      }
    });

final myRegistrationsProvider =
    AsyncNotifierProvider<MyRegistrationsController, MyRegistrationsState>(
      MyRegistrationsController.new,
    );

class MyRegistrationsState {
  const MyRegistrationsState({
    required this.items,
    required this.nextCursor,
    this.isLoadingMore = false,
  });
  final List<MyEventRegistration> items;
  final String? nextCursor;
  final bool isLoadingMore;
  MyRegistrationsState withLoadingMore(bool value) => MyRegistrationsState(
    items: items,
    nextCursor: nextCursor,
    isLoadingMore: value,
  );
}

class MyRegistrationsController extends AsyncNotifier<MyRegistrationsState> {
  @override
  Future<MyRegistrationsState> build() async {
    final page = await ref.watch(eventsRepositoryProvider).myRegistrations();
    return MyRegistrationsState(items: page.items, nextCursor: page.nextCursor);
  }

  Future<void> refresh() async {
    final current = state.asData?.value;
    if (current == null) {
      state = const AsyncLoading();
      state = await AsyncValue.guard(() async {
        final page = await ref.read(eventsRepositoryProvider).myRegistrations();
        return MyRegistrationsState(
          items: page.items,
          nextCursor: page.nextCursor,
        );
      });
      return;
    }
    try {
      final page = await ref.read(eventsRepositoryProvider).myRegistrations();
      state = AsyncData(
        MyRegistrationsState(items: page.items, nextCursor: page.nextCursor),
      );
    } catch (_) {
      state = AsyncData(current);
    }
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || current.isLoadingMore || current.nextCursor == null) {
      return;
    }
    state = AsyncData(current.withLoadingMore(true));
    try {
      final page = await ref
          .read(eventsRepositoryProvider)
          .myRegistrations(cursor: current.nextCursor);
      state = AsyncData(
        MyRegistrationsState(
          items: [...current.items, ...page.items],
          nextCursor: page.nextCursor,
        ),
      );
    } catch (_) {
      state = AsyncData(current.withLoadingMore(false));
    }
  }
}

final eventRegistrationActionProvider =
    AsyncNotifierProvider<
      EventRegistrationActionController,
      EventRegistrationResult?
    >(EventRegistrationActionController.new);

class EventRegistrationActionController
    extends AsyncNotifier<EventRegistrationResult?> {
  @override
  Future<EventRegistrationResult?> build() async => null;
  Future<EventRegistrationResult> register(String publicId) async {
    state = const AsyncLoading();
    try {
      final result = await ref
          .read(eventsRepositoryProvider)
          .register(publicId);
      state = AsyncData(result);
      ref.invalidate(eventsControllerProvider);
      ref.invalidate(eventDetailProvider(publicId));
      ref.invalidate(myRegistrationsProvider);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> cancel(String publicId) async {
    state = const AsyncLoading();
    try {
      await ref.read(eventsRepositoryProvider).cancel(publicId);
      state = const AsyncData(null);
      ref.invalidate(eventsControllerProvider);
      ref.invalidate(eventDetailProvider(publicId));
      ref.invalidate(myRegistrationsProvider);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
