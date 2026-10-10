import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_z/features/opportunities/presentation/state/opportunities_providers.dart';
import 'package:sports_z/features/saved/data/datasources/saved_api.dart';
import 'package:sports_z/features/saved/data/models/saved_item.dart';

final _savedApiProvider = Provider<SavedApi>(
  (ref) => SavedApi(ref.watch(opportunitiesDioProvider)),
);

final savedFilterProvider = NotifierProvider<SavedFilterNotifier, String?>(
  SavedFilterNotifier.new,
);

class SavedFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? type) {
    if (state != type) state = type;
  }
}

class SavedItemsState {
  const SavedItemsState({
    required this.items,
    required this.nextCursor,
    this.isLoadingMore = false,
  });

  final List<SavedItem> items;
  final String? nextCursor;
  final bool isLoadingMore;

  SavedItemsState withLoadingMore(bool value) => SavedItemsState(
    items: items,
    nextCursor: nextCursor,
    isLoadingMore: value,
  );
}

final savedItemsProvider =
    AsyncNotifierProvider<SavedItemsNotifier, SavedItemsState>(
      SavedItemsNotifier.new,
    );

class SavedItemsNotifier extends AsyncNotifier<SavedItemsState> {
  @override
  Future<SavedItemsState> build() async {
    final type = ref.watch(savedFilterProvider);
    final page = await ref.watch(_savedApiProvider).list(type: type);
    return SavedItemsState(items: page.items, nextCursor: page.nextCursor);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final page = await ref
          .read(_savedApiProvider)
          .list(type: ref.read(savedFilterProvider));
      return SavedItemsState(items: page.items, nextCursor: page.nextCursor);
    });
    if (ref.mounted) state = result;
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
          .read(_savedApiProvider)
          .list(
            type: ref.read(savedFilterProvider),
            cursor: current.nextCursor,
          );
      if (!ref.mounted) return;
      state = AsyncData(
        SavedItemsState(
          items: [...current.items, ...page.items],
          nextCursor: page.nextCursor,
        ),
      );
    } catch (_) {
      if (ref.mounted) state = AsyncData(current.withLoadingMore(false));
    }
  }
}

final savedActionProvider = AsyncNotifierProvider<SavedActionNotifier, void>(
  SavedActionNotifier.new,
);

class SavedActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> setSaved(String type, String targetId, bool shouldSave) async {
    state = const AsyncLoading();
    try {
      if (shouldSave) {
        await ref.read(_savedApiProvider).save(type, targetId);
      } else {
        await ref.read(_savedApiProvider).remove(type, targetId);
      }
      if (!ref.mounted) return;
      state = const AsyncData(null);
      ref.invalidate(savedItemsProvider);
    } catch (error, stackTrace) {
      if (ref.mounted) state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
