import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/providers.dart';
import '../../data/models/saved_item.dart';
import '../../data/repositories/saved_repository.dart';

final savedRepositoryProvider = Provider<SavedRepository>(
  (ref) => SavedRepository(ref.watch(dioProvider)),
);

final savedFilterProvider = NotifierProvider<SavedFilterController, String?>(
  SavedFilterController.new,
);

class SavedFilterController extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? type) {
    if (state != type) state = type;
  }
}

final savedItemsProvider =
    AsyncNotifierProvider<SavedItemsController, SavedItemsState>(
      SavedItemsController.new,
    );

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

class SavedItemsController extends AsyncNotifier<SavedItemsState> {
  @override
  Future<SavedItemsState> build() async {
    final type = ref.watch(savedFilterProvider);
    final page = await ref.watch(savedRepositoryProvider).list(type: type);
    return SavedItemsState(items: page.items, nextCursor: page.nextCursor);
  }

  Future<void> refresh() async {
    final current = state.asData?.value;
    if (current == null) {
      state = const AsyncLoading();
      state = await AsyncValue.guard(() async {
        final page = await ref
            .read(savedRepositoryProvider)
            .list(type: ref.read(savedFilterProvider));
        return SavedItemsState(items: page.items, nextCursor: page.nextCursor);
      });
      return;
    }
    try {
      final page = await ref
          .read(savedRepositoryProvider)
          .list(type: ref.read(savedFilterProvider));
      state = AsyncData(
        SavedItemsState(items: page.items, nextCursor: page.nextCursor),
      );
    } catch (_) {
      state = AsyncData(current);
    }
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
          .read(savedRepositoryProvider)
          .list(
            type: ref.read(savedFilterProvider),
            cursor: current.nextCursor,
          );
      state = AsyncData(
        SavedItemsState(
          items: [...current.items, ...page.items],
          nextCursor: page.nextCursor,
        ),
      );
    } catch (_) {
      state = AsyncData(current.withLoadingMore(false));
    }
  }
}

final savedActionProvider = AsyncNotifierProvider<SavedActionController, void>(
  SavedActionController.new,
);

class SavedActionController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> setSaved(String type, String targetId, bool shouldSave) async {
    state = const AsyncLoading();
    try {
      final repository = ref.read(savedRepositoryProvider);
      if (shouldSave) {
        await repository.save(type, targetId);
      } else {
        await repository.unsave(type, targetId);
      }
      state = const AsyncData(null);
      ref.invalidate(savedItemsProvider);
    } catch (error, stackTrace) {
      state = AsyncError(Exception(apiErrorText(error)), stackTrace);
      rethrow;
    }
  }
}
