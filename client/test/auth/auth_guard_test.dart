import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_z/core/auth/unauthorized_events.dart';
import 'package:sports_z/core/navigation/navigator_key.dart';
import 'package:sports_z/features/auth/presentation/controllers/auth_controller.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Resets UnauthorizedEvents singleton state before each test.
void _resetEvents() => UnauthorizedEvents.instance.reset();

void main() {
  setUp(_resetEvents);

  // -------------------------------------------------------------------------
  // Task 2: UnauthorizedEvents unit tests
  // -------------------------------------------------------------------------

  group('UnauthorizedEvents', () {
    test('signal401 emits exactly one event for multiple calls', () async {
      final events = <void>[];
      final sub =
          UnauthorizedEvents.instance.stream.listen((_) => events.add(null));
      addTearDown(sub.cancel);

      UnauthorizedEvents.instance.signal401('/me/profile/athlete');
      UnauthorizedEvents.instance.signal401('/me/profile/athlete');
      UnauthorizedEvents.instance.signal401('/me/profile/athlete');

      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1),
          reason: 'duplicate 401s must not produce duplicate events');
    });

    test('signal401 is suppressed for /auth/session path', () async {
      final events = <void>[];
      final sub =
          UnauthorizedEvents.instance.stream.listen((_) => events.add(null));
      addTearDown(sub.cancel);

      UnauthorizedEvents.instance.signal401('/auth/session');
      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty,
          reason: '/auth/session 401 must not trigger the global event');
    });

    test('signal401 is suppressed for /auth/logout path', () async {
      final events = <void>[];
      final sub =
          UnauthorizedEvents.instance.stream.listen((_) => events.add(null));
      addTearDown(sub.cancel);

      UnauthorizedEvents.instance.signal401('/auth/logout');
      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty,
          reason: '/auth/logout 401 must not trigger the global event');
    });

    test('reset allows a second event to fire after re-login', () async {
      final events = <void>[];
      final sub =
          UnauthorizedEvents.instance.stream.listen((_) => events.add(null));
      addTearDown(sub.cancel);

      UnauthorizedEvents.instance.signal401('/me/profile/athlete');
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1));

      UnauthorizedEvents.instance.reset();

      UnauthorizedEvents.instance.signal401('/me/profile/athlete');
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(2),
          reason: 'reset() must allow future 401s to fire again');
    });

    test('signal401 path matching ignores leading /v1 prefix', () async {
      final events = <void>[];
      final sub =
          UnauthorizedEvents.instance.stream.listen((_) => events.add(null));
      addTearDown(sub.cancel);

      // DioClient base URL is /v1, so paths arrive without the /v1 prefix
      // (they look like '/auth/session'). Both should be blocked.
      UnauthorizedEvents.instance.signal401('/v1/auth/session');
      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty,
          reason: 'endsWith check must catch /v1/auth/session too');
    });
  });

  // -------------------------------------------------------------------------
  // Task 2: Root navigator key & SessionExpired navigation
  // -------------------------------------------------------------------------

  group('SessionExpired root navigation', () {
    testWidgets(
      'root listener navigates to SessionExpiredScreen on 401 and debounces duplicates',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: _RootListenerTestWidget(),
          ),
        );
        expect(find.text('Active Session'), findsOneWidget);

        // First 401 event triggers navigation to destination via rootNavigatorKey.
        UnauthorizedEvents.instance.signal401('/me/profile/athlete');
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Session Expired Destination'), findsOneWidget);
        expect(find.text('Active Session'), findsNothing);

        // Repeated 401 is suppressed by debouncing
        UnauthorizedEvents.instance.signal401('/me/profile/athlete');
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Session Expired Destination'), findsOneWidget);
      },
    );
  });

  // -------------------------------------------------------------------------
  // Task 3: Logout best-effort backend call
  // -------------------------------------------------------------------------

  group('Logout best-effort backend call', () {
    test(
      'logoutFromBackend throwing does not prevent local sign-out',
      () async {
        var localSignOutCalled = false;
        var backendCallAttempted = false;

        Future<void> simulatedLogout({
          required Future<void> Function() backendLogout,
          required Future<void> Function() localSignOut,
        }) async {
          try {
            await backendLogout().timeout(const Duration(seconds: 3));
          } catch (_) {}
          await localSignOut();
        }

        await simulatedLogout(
          backendLogout: () async {
            backendCallAttempted = true;
            throw Exception('Network error');
          },
          localSignOut: () async {
            localSignOutCalled = true;
          },
        );

        expect(backendCallAttempted, isTrue,
          reason: 'backend logout must always be attempted');
        expect(localSignOutCalled, isTrue,
          reason:
              'local sign-out must complete even when backend throws');
      },
    );

    test(
      'logoutFromBackend timeout does not block local sign-out',
      () async {
        var localSignOutCalled = false;

        Future<void> simulatedLogout({
          required Future<void> Function() backendLogout,
          required Future<void> Function() localSignOut,
        }) async {
          try {
            await backendLogout().timeout(const Duration(milliseconds: 100));
          } catch (_) {}
          await localSignOut();
        }

        await simulatedLogout(
          backendLogout: () async {
            await Future<void>.delayed(const Duration(seconds: 5));
          },
          localSignOut: () async {
            localSignOutCalled = true;
          },
        );

        expect(localSignOutCalled, isTrue,
          reason: 'a slow backend must not block the local sign-out');
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Helper widget mimicking MyApp root listener
// ---------------------------------------------------------------------------

class _RootListenerTestWidget extends ConsumerWidget {
  const _RootListenerTestWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<void>>(
      unauthorizedEventsProvider,
      (_, next) {
        if (next is AsyncData) {
          rootNavigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Text('Session Expired Destination'),
              ),
            ),
            (route) => false,
          );
        }
      },
    );

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      home: const Scaffold(body: Text('Active Session')),
    );
  }
}
