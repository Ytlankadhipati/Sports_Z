import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/providers.dart';
import '../../data/models/opportunity.dart';
import '../../data/repositories/opportunities_repository.dart';

final opportunityTypeProvider =
    NotifierProvider<OpportunityTypeNotifier, String?>(
      OpportunityTypeNotifier.new,
    );

class OpportunityTypeNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? type) {
    if (state != type) state = type;
  }
}

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
  final Map<String, OpportunityPage> _pageCache = {};
  String? _loadingKey;
  int _requestId = 0;

  @override
  OpportunitiesFeedState build() => const OpportunitiesFeedState();

  Future<void> load({required String status, String? type}) async {
    final key = '$status|${type ?? 'all'}';
    final cached = _pageCache[key];
    if (_loadingKey == key) return;
    final requestId = ++_requestId;
    _loadingKey = key;
    state = OpportunitiesFeedState(
      items: cached?.items ?? const [],
      nextCursor: cached?.nextCursor,
      isLoading: true,
    );
    try {
      final page = await ref
          .read(opportunitiesRepositoryProvider)
          .list(status: status, type: type);
      _pageCache[key] = page;
      if (requestId != _requestId) return;
      state = OpportunitiesFeedState(
        items: page.items,
        nextCursor: page.nextCursor,
        isLoading: false,
      );
    } catch (error) {
      if (requestId != _requestId) return;
      state = OpportunitiesFeedState(
        items: cached?.items ?? const [],
        nextCursor: cached?.nextCursor,
        errorMessage: apiErrorText(error),
        isLoading: false,
      );
    } finally {
      if (_loadingKey == key) _loadingKey = null;
    }
  }

  Future<void> refresh({required String status, String? type}) =>
      load(status: status, type: type);

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

final opportunityDetailProvider = FutureProvider.autoDispose
    .family<OpportunityDetail, String>((ref, publicId) async {
      try {
        return await ref
            .watch(opportunitiesRepositoryProvider)
            .getById(publicId);
      } catch (error) {
        final apiError = apiExceptionFrom(error);
        if (apiError?.statusCode == 404) {
          throw const ApiException(
            message: 'This opportunity is no longer available.',
            statusCode: 404,
          );
        }
        rethrow;
      }
    });
