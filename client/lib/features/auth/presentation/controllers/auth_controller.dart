import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/unauthorized_events.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/providers.dart';
import '../../data/datasources/auth_service.dart';
import '../../data/repositories/auth_repository.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    dio: ref.watch(dioProvider),
    authService: ref.watch(authServiceProvider),
  ),
);

final authControllerProvider =
    NotifierProvider<AuthController, AuthControllerState>(AuthController.new);

/// Surfaces [UnauthorizedEvents] as a Riverpod stream so widgets can
/// react to global 401 events with [ref.listen] without recreating the
/// provider on every rebuild.
final unauthorizedEventsProvider = StreamProvider<void>(
  (ref) => UnauthorizedEvents.instance.stream,
);

class AuthControllerState {
  const AuthControllerState({this.isLoading = false, this.errorMessage});

  final bool isLoading;
  final String? errorMessage;

  AuthControllerState copyWith({bool? isLoading, String? errorMessage}) =>
      AuthControllerState(
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
      );
}

class AuthController extends Notifier<AuthControllerState> {
  int _latestOperationId = 0;

  @override
  AuthControllerState build() => const AuthControllerState();

  Future<Map<String, dynamic>?> verifyWithBackend() async {
    final result = await _run(
      () => ref.read(authRepositoryProvider).verifyWithBackend(),
    );
    // Reset the 401 debounce so a future expiry (after this re-login) still
    // fires the global session-expired event.
    if (result != null) UnauthorizedEvents.instance.reset();
    return result;
  }

  Future<Map<String, dynamic>?> selectRole(String role) =>
      _run(() => ref.read(authRepositoryProvider).selectRole(role));

  Future<Map<String, dynamic>?> _run(
    Future<Map<String, dynamic>?> Function() request,
  ) async {
    final operationId = ++_latestOperationId;
    state = const AuthControllerState(isLoading: true);
    try {
      // Firebase token refresh and the backend verification request happen
      // sequentially; allow both their configured network timeouts to finish
      // before classifying a slow connection as an expired session.
      final result = await request().timeout(const Duration(seconds: 35));
      if (_latestOperationId == operationId) {
        state = AuthControllerState(
          errorMessage: result == null
              ? 'Authentication could not be verified.'
              : null,
        );
      }
      return result;
    } on TimeoutException {
      if (_latestOperationId == operationId) {
        state = const AuthControllerState(
          errorMessage:
              'Authentication timed out. Check your connection and try again.',
        );
      }
      return null;
    } catch (error) {
      if (_latestOperationId == operationId) {
        state = AuthControllerState(errorMessage: apiErrorText(error));
      }
      return null;
    } finally {
      if (_latestOperationId == operationId && state.isLoading) {
        state = state.copyWith(isLoading: false);
      }
    }
  }
}
