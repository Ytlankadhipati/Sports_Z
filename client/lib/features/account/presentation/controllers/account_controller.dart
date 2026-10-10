import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/providers.dart';
import '../../data/repositories/account_repository.dart';

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(ref.watch(dioProvider)),
);

final accountControllerProvider =
    NotifierProvider<AccountController, AccountControllerState>(
      AccountController.new,
    );

class AccountControllerState {
  const AccountControllerState({
    this.isLoading = false,
    this.account,
    this.errorMessage,
  });

  final bool isLoading;
  final Map<String, dynamic>? account;
  final String? errorMessage;
}

class AccountController extends Notifier<AccountControllerState> {
  Future<void>? _inFlight;

  @override
  AccountControllerState build() => const AccountControllerState();

  /// Loads `GET /me`. Concurrent calls reuse the request already in flight.
  Future<void> loadAccount() {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    final future = _load();
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
  }

  Future<void> _load() async {
    state = AccountControllerState(isLoading: true, account: state.account);
    try {
      final data = await ref
          .read(accountRepositoryProvider)
          .getMe()
          .timeout(const Duration(seconds: 15));
      state = AccountControllerState(account: data);
    } catch (error) {
      state = AccountControllerState(errorMessage: accountLoadError(error));
    }
  }
}

String accountLoadError(Object error) {
  final statusCode = apiExceptionFrom(error)?.statusCode;
  return switch (statusCode) {
    401 => 'Your session has expired. Sign in again and retry.',
    403 => 'You do not have access to this account.',
    404 => 'Your account could not be found.',
    _ => 'Could not load your account. Check your connection and retry.',
  };
}
