import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_z/core/config/api_config.dart';
import 'package:sports_z/features/opportunities/data/datasources/opportunities_api.dart';
import 'package:sports_z/features/opportunities/data/models/opportunity.dart';

// TODO(M2): replace with the shared Dio provider from lib/core/network.
final opportunitiesDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      headers: const {'Accept': 'application/json'},
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await FirebaseAuth.instance.currentUser?.getIdToken();
        if (token == null) {
          handler.reject(
            DioException(requestOptions: options, error: LoginRequired()),
          );
          return;
        }
        options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
    ),
  );
  return dio;
});

final opportunitiesApiProvider = Provider<OpportunitiesApi>(
  (ref) => OpportunitiesApi(ref.watch(opportunitiesDioProvider)),
);

final opportunityTypeProvider =
    NotifierProvider<OpportunityTypeNotifier, String?>(
      OpportunityTypeNotifier.new,
    );

class OpportunityTypeNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? type) {
    if (type != state) state = type;
  }
}

class OpportunitiesState {
  const OpportunitiesState({
    required this.items,
    required this.nextCursor,
    this.isLoadingMore = false,
  });

  final List<Opportunity> items;
  final String? nextCursor;
  final bool isLoadingMore;

  OpportunitiesState withLoadingMore(bool value) => OpportunitiesState(
    items: items,
    nextCursor: nextCursor,
    isLoadingMore: value,
  );
}

final opportunitiesProvider =
    AsyncNotifierProvider<OpportunitiesNotifier, OpportunitiesState>(
      OpportunitiesNotifier.new,
    );

class OpportunitiesNotifier extends AsyncNotifier<OpportunitiesState> {
  @override
  Future<OpportunitiesState> build() async {
    final type = ref.watch(opportunityTypeProvider);
    final page = await ref.watch(opportunitiesApiProvider).list(type: type);
    return OpportunitiesState(items: page.items, nextCursor: page.nextCursor);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final refreshed = await AsyncValue.guard(() async {
      final type = ref.read(opportunityTypeProvider);
      final page = await ref.read(opportunitiesApiProvider).list(type: type);
      return OpportunitiesState(items: page.items, nextCursor: page.nextCursor);
    });
    if (!ref.mounted) return;
    state = refreshed;
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
          .read(opportunitiesApiProvider)
          .list(
            type: ref.read(opportunityTypeProvider),
            cursor: current.nextCursor,
          );
      if (!ref.mounted) return;
      state = AsyncData(
        OpportunitiesState(
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

final opportunityDetailProvider = FutureProvider.autoDispose
    .family<OpportunityDetail, String>(
      (ref, publicId) => ref.watch(opportunitiesApiProvider).getById(publicId),
    );
