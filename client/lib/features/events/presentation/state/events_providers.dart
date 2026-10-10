import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_z/features/events/data/datasources/events_api.dart';
import 'package:sports_z/features/events/data/models/event.dart';
import 'package:sports_z/features/opportunities/presentation/state/opportunities_providers.dart'
    show opportunitiesDioProvider;

final eventsApiProvider = Provider<EventsApi>(
  (ref) => EventsApi(ref.watch(opportunitiesDioProvider)),
);

final eventStatusProvider = NotifierProvider<EventStatusNotifier, String>(
  EventStatusNotifier.new,
);

class EventStatusNotifier extends Notifier<String> {
  @override
  String build() => 'upcoming';

  void select(String status) {
    if (status != state) state = status;
  }
}

class EventsListState {
  const EventsListState({
    required this.items,
    required this.nextCursor,
    this.isLoadingMore = false,
  });

  final List<SportEvent> items;
  final String? nextCursor;
  final bool isLoadingMore;

  EventsListState withLoadingMore(bool value) => EventsListState(
    items: items,
    nextCursor: nextCursor,
    isLoadingMore: value,
  );
}

final eventsListProvider =
    AsyncNotifierProvider<EventsListNotifier, EventsListState>(
      EventsListNotifier.new,
    );

class EventsListNotifier extends AsyncNotifier<EventsListState> {
  @override
  Future<EventsListState> build() async {
    final status = ref.watch(eventStatusProvider);
    final page = await ref.watch(eventsApiProvider).list(status: status);
    return EventsListState(items: page.items, nextCursor: page.nextCursor);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final page = await ref
          .read(eventsApiProvider)
          .list(status: ref.read(eventStatusProvider));
      return EventsListState(items: page.items, nextCursor: page.nextCursor);
    });
    if (!ref.mounted) return;
    state = result;
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null ||
        current.isLoadingMore ||
        current.nextCursor == null) {
      return;
    }
    state = AsyncData(current.withLoadingMore(true));
    try {
      final page = await ref
          .read(eventsApiProvider)
          .list(
            status: ref.read(eventStatusProvider),
            cursor: current.nextCursor,
          );
      if (!ref.mounted) return;
      state = AsyncData(
        EventsListState(
          items: [...current.items, ...page.items],
          nextCursor: page.nextCursor,
        ),
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = AsyncData(current.withLoadingMore(false));
    }
  }
}

final eventDetailProvider = FutureProvider.autoDispose
    .family<EventDetail, String>(
      (ref, publicId) => ref.watch(eventsApiProvider).getById(publicId),
    );

final myRegistrationsProvider =
    AsyncNotifierProvider<MyRegistrationsNotifier, MyRegistrationsState>(
      MyRegistrationsNotifier.new,
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

class MyRegistrationsNotifier extends AsyncNotifier<MyRegistrationsState> {
  @override
  Future<MyRegistrationsState> build() async {
    final page = await ref.watch(eventsApiProvider).myRegistrations();
    return MyRegistrationsState(items: page.items, nextCursor: page.nextCursor);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final page = await ref.read(eventsApiProvider).myRegistrations();
      return MyRegistrationsState(
        items: page.items,
        nextCursor: page.nextCursor,
      );
    });
    if (!ref.mounted) return;
    state = result;
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null ||
        current.isLoadingMore ||
        current.nextCursor == null) {
      return;
    }
    state = AsyncData(current.withLoadingMore(true));
    try {
      final page = await ref
          .read(eventsApiProvider)
          .myRegistrations(cursor: current.nextCursor);
      if (!ref.mounted) return;
      state = AsyncData(
        MyRegistrationsState(
          items: [...current.items, ...page.items],
          nextCursor: page.nextCursor,
        ),
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = AsyncData(current.withLoadingMore(false));
    }
  }
}

final eventRegistrationActionProvider =
    AsyncNotifierProvider<
      EventRegistrationActionNotifier,
      EventRegistrationResult?
    >(EventRegistrationActionNotifier.new);

class EventRegistrationActionNotifier
    extends AsyncNotifier<EventRegistrationResult?> {
  @override
  Future<EventRegistrationResult?> build() async => null;

  Future<EventRegistrationResult> register(String publicId) async {
    state = const AsyncLoading();
    try {
      final result = await ref.read(eventsApiProvider).register(publicId);
      if (ref.mounted) {
        state = AsyncData(result);
        ref.invalidate(eventsListProvider);
        ref.invalidate(eventDetailProvider(publicId));
        ref.invalidate(myRegistrationsProvider);
      }
      return result;
    } catch (error, stackTrace) {
      if (ref.mounted) state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> cancel(String publicId) async {
    state = const AsyncLoading();
    try {
      await ref.read(eventsApiProvider).cancel(publicId);
      if (!ref.mounted) return;
      state = const AsyncData(null);
      ref.invalidate(eventsListProvider);
      ref.invalidate(eventDetailProvider(publicId));
      ref.invalidate(myRegistrationsProvider);
    } catch (error, stackTrace) {
      if (ref.mounted) state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
