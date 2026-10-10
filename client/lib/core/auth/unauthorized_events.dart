import 'dart:async';

/// Paths that are part of the auth handshake itself.  A 401 on these must
/// NOT trigger the global "session expired" flow — a token-refresh retry that
/// still fails, or a logout with an already-expired token, must not cascade
/// into SessionExpiredScreen.
const _kAuthPaths = {'/auth/session', '/auth/logout'};

/// Lightweight, singleton event bus for unauthenticated (HTTP 401) responses.
///
/// Usage:
///   • Network layer calls [signal401] when the final (post-retry) response
///     from a *protected* endpoint is 401.
///   • UI layer listens to [stream] (or subscribes via [unauthorizedEventsProvider]
///     in `core/auth/providers.dart`).
///
/// Design decisions:
///   • Broadcast stream so multiple listeners (current: HomeScreen) can attach.
///   • One-shot debounce: once signalled, subsequent 401s within the same
///     "session" are suppressed until [reset] is called.  [reset] is called
///     by [AuthController.verifyWithBackend] on a successful POST /auth/session
///     so that a re-login followed by another expiry still fires.
class UnauthorizedEvents {
  UnauthorizedEvents._();

  static final UnauthorizedEvents instance = UnauthorizedEvents._();

  final _controller = StreamController<void>.broadcast();
  bool _signalled = false;

  /// Fires at most once per session (until [reset] is called).
  ///
  /// [path] is the Dio request path (e.g. '/v1/me/profile/athlete').  Calls
  /// originating from auth-handshake paths are silently ignored.
  void signal401(String path) {
    if (_authPathMatches(path)) return; // Do not trigger for auth endpoints
    if (_signalled) return;            // Already fired; suppress duplicates
    _signalled = true;
    _controller.add(null);
  }

  /// Resets the debounce flag so a future 401 will fire again.
  ///
  /// Call this after a successful re-authentication (POST /auth/session 200).
  void reset() => _signalled = false;

  /// Stream of 401 events.  Each emission means "one protected request
  /// returned 401 and the user must re-authenticate."
  Stream<void> get stream => _controller.stream;
}

bool _authPathMatches(String path) {
  for (final authPath in _kAuthPaths) {
    if (path.endsWith(authPath)) return true;
  }
  return false;
}
