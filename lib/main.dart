import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'core/services/app_state.dart';
import 'core/services/service_instances.dart';
import 'core/services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await subscriptionService.init();
  await authService.ready;
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider.value(value: subscriptionService),
        ChangeNotifierProvider(create: (_) => ThemeService()),
      ],
      child: const VenueLockApp(),
    ),
  );
}

class VenueLockApp extends StatefulWidget {
  const VenueLockApp({super.key});

  @override
  State<VenueLockApp> createState() => _VenueLockAppState();
}

class _VenueLockAppState extends State<VenueLockApp> {
  @override
  void initState() {
    super.initState();
    // Sync venues automatically as the admin's login state changes.
    authService.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  void _onAuthChanged() {
    final appState = context.read<AppState>();
    if (authService.isLoggedIn) {
      appState.startSync(authService.phone!, authService.token!);
    } else {
      appState.stopSync();
    }
  }

  @override
  void dispose() {
    authService.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    return MaterialApp.router(
      title: 'VenueLock',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(themeService.seedColor),
      darkTheme: AppTheme.dark(themeService.seedColor),
      themeMode: themeService.mode,
      routerConfig: router,
    );
  }
}
