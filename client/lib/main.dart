import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/firebase_options.dart';
import 'core/navigation/navigator_key.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';
import 'features/auth/presentation/screens/session_expired_screen.dart';
import 'features/auth/presentation/screens/splash_screen.dart';
import 'shared/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<void>>(
      unauthorizedEventsProvider,
      (_, next) {
        if (next is AsyncData) {
          rootNavigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const SessionExpiredScreen(
                reason: 'Your session has expired. Please sign in again.',
              ),
            ),
            (route) => false,
          );
        }
      },
    );

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'SportsZ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}
