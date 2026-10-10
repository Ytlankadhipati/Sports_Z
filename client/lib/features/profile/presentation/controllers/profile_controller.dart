import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/providers.dart';
import '../../data/repositories/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(dioProvider)),
);

final profileControllerProvider =
    NotifierProvider<ProfileController, ProfileControllerState>(
      ProfileController.new,
    );

class ProfileControllerState {
  const ProfileControllerState({
    this.isLoading = false,
    this.isSaving = false,
    this.profile,
    this.sportszId,
    this.sportsCatalog,
    this.organizations,
    this.errorMessage,
  });

  final bool isLoading;
  final bool isSaving;
  final Map<String, dynamic>? profile;
  final Map<String, dynamic>? sportszId;
  final List<Map<String, dynamic>>? sportsCatalog;
  final List<Map<String, dynamic>>? organizations;
  final String? errorMessage;

  ProfileControllerState copyWith({
    bool? isLoading,
    bool? isSaving,
    Map<String, dynamic>? profile,
    Map<String, dynamic>? sportszId,
    List<Map<String, dynamic>>? sportsCatalog,
    List<Map<String, dynamic>>? organizations,
    String? errorMessage,
    bool clearError = false,
  }) => ProfileControllerState(
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    profile: profile ?? this.profile,
    sportszId: sportszId ?? this.sportszId,
    sportsCatalog: sportsCatalog ?? this.sportsCatalog,
    organizations: organizations ?? this.organizations,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );
}

class ProfileController extends Notifier<ProfileControllerState> {
  int _activeLoads = 0;
  int _activeSaves = 0;

  @override
  ProfileControllerState build() => const ProfileControllerState();

  Future<Map<String, dynamic>>? _inFlightProfileLoad;

  Future<Map<String, dynamic>> loadProfile() {
    final inFlight = _inFlightProfileLoad;
    if (inFlight != null) return inFlight;

    final future = _run(
      ref.read(profileRepositoryProvider).getAthleteProfile,
      onSuccess: (data) => state = state.copyWith(profile: data),
    );
    _inFlightProfileLoad = future;
    return future.whenComplete(() {
      if (identical(_inFlightProfileLoad, future)) {
        _inFlightProfileLoad = null;
      }
    });
  }

  Future<Map<String, dynamic>> loadSportszId() => _run(
    ref.read(profileRepositoryProvider).getSportszId,
    onSuccess: (data) => state = state.copyWith(sportszId: data),
  );

  Future<List<Map<String, dynamic>>> loadSportsCatalog() => _run(() async {
    final data = await ref.read(profileRepositoryProvider).getSportsCatalog();
    final raw = data['sports'];
    return raw is List
        ? raw
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
  }, onSuccess: (data) => state = state.copyWith(sportsCatalog: data));

  Future<Map<String, dynamic>> loadSportConfig(String sportId) =>
      _run(() => ref.read(profileRepositoryProvider).getSportConfig(sportId));

  Future<List<Map<String, dynamic>>> loadOrganizations() => _run(() async {
    final data = await ref.read(profileRepositoryProvider).getOrganizations();
    final raw = data['organizations'];
    return raw is List
        ? raw
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
  }, onSuccess: (data) => state = state.copyWith(organizations: data));

  Future<Map<String, dynamic>> saveProfile(Map<String, dynamic> payload) =>
      _run(
        () => ref.read(profileRepositoryProvider).patchAthleteProfile(payload),
        saving: true,
        onSuccess: (data) => state = state.copyWith(profile: data),
      );

  Future<Map<String, dynamic>> savePhysical(Map<String, dynamic> payload) =>
      _run(
        () => ref.read(profileRepositoryProvider).patchPhysical(payload),
        saving: true,
        onSuccess: (data) => state = state.copyWith(profile: data),
      );

  Future<Map<String, dynamic>> saveSport(
    String sportId,
    Map<String, dynamic> payload,
  ) => _run(
    () => ref.read(profileRepositoryProvider).putSport(sportId, payload),
    saving: true,
  );

  Future<Map<String, dynamic>> addSport(Map<String, dynamic> payload) => _run(
    () => ref.read(profileRepositoryProvider).addSport(payload),
    saving: true,
  );

  Future<Map<String, dynamic>> setPrimarySport(String sportId) => _run(
    () => ref.read(profileRepositoryProvider).setPrimarySport(sportId),
    saving: true,
  );

  Future<void> removeSport(String sportId) => _run(
    () => ref.read(profileRepositoryProvider).removeSport(sportId),
    saving: true,
  );

  Future<Map<String, dynamic>> addExperience(Map<String, dynamic> payload) =>
      _run(
        () => ref.read(profileRepositoryProvider).addExperience(payload),
        saving: true,
      );

  Future<Map<String, dynamic>> updateExperience(
    String experienceId,
    Map<String, dynamic> payload,
  ) => _run(
    () => ref
        .read(profileRepositoryProvider)
        .updateExperience(experienceId, payload),
    saving: true,
  );

  Future<void> removeExperience(String experienceId) => _run(
    () => ref.read(profileRepositoryProvider).removeExperience(experienceId),
    saving: true,
  );

  Future<T> _run<T>(
    Future<T> Function() request, {
    bool saving = false,
    void Function(T value)? onSuccess,
  }) async {
    if (saving) {
      _activeSaves++;
    } else {
      _activeLoads++;
    }
    state = state.copyWith(
      isLoading: _activeLoads > 0,
      isSaving: _activeSaves > 0,
      clearError: true,
    );
    try {
      final result = await request().timeout(const Duration(seconds: 15));
      onSuccess?.call(result);
      return result;
    } catch (error) {
      state = state.copyWith(errorMessage: apiErrorText(error));
      rethrow;
    } finally {
      if (saving) {
        _activeSaves--;
      } else {
        _activeLoads--;
      }
      state = state.copyWith(
        isLoading: _activeLoads > 0,
        isSaving: _activeSaves > 0,
      );
    }
  }
}
