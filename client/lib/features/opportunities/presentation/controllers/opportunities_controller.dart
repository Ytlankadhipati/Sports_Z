import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/providers.dart';
import '../../data/models/opportunity.dart';
import '../../data/repositories/opportunities_repository.dart';

final opportunitiesRepositoryProvider = Provider<OpportunitiesRepository>(
  (ref) => OpportunitiesRepository(ref.watch(dioProvider)),
);

final opportunitiesControllerProvider =
    NotifierProvider<OpportunitiesController, OpportunitiesFeedState>(
      OpportunitiesController.new,
    );

class OpportunitiesFeedState {
  const OpportunitiesFeedState({
    this.items = const [],
    this.nextCursor,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  final List<Opportunity> items;
  final String? nextCursor;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;
}

class OpportunitiesController extends Notifier<OpportunitiesFeedState> {
  @override
  OpportunitiesFeedState build() => const OpportunitiesFeedState();

  Future<void> load({required String status, String? type}) async {
    state = const OpportunitiesFeedState(isLoading: true);
    try {
      final page = await ref
          .read(opportunitiesRepositoryProvider)
          .list(status: status, type: type);
      state = OpportunitiesFeedState(
        items: page.items,
        nextCursor: page.nextCursor,
        isLoading: false,
      );
    } catch (error) {
      state = OpportunitiesFeedState(
        errorMessage: apiErrorText(error),
        isLoading: false,
      );
    }
  }

  Future<void> loadMore({required String status, String? type}) async {
    final cursor = state.nextCursor;
    if (state.isLoading || state.isLoadingMore || cursor == null) return;
    state = OpportunitiesFeedState(
      items: state.items,
      nextCursor: cursor,
      isLoadingMore: true,
    );
    try {
      final page = await ref
          .read(opportunitiesRepositoryProvider)
          .list(status: status, type: type, cursor: cursor);
      state = OpportunitiesFeedState(
        items: [...state.items, ...page.items],
        nextCursor: page.nextCursor,
      );
    } catch (_) {
      state = OpportunitiesFeedState(items: state.items, nextCursor: cursor);
    }
  }
}
