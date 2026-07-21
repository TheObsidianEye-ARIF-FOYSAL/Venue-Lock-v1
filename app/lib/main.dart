import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'core/services/app_state.dart';
import 'core/services/service_instances.dart';
import 'core/services/student_profile_service.dart';
import 'core/services/theme_service.dart';
import 'core/utils/mobile_web_detector.dart';

/// True only for the web build running on a desktop/laptop browser.
final bool _devicePreviewEnabled = kIsWeb && !isMobileWebBrowser();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await subscriptionService.init();
  await authService.ready;
  final studentProfile = StudentProfileService();
  await studentProfile.load();
  final app = MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppState()),
      ChangeNotifierProvider.value(value: authService),
      ChangeNotifierProvider.value(value: subscriptionService),
      ChangeNotifierProvider(create: (_) => ThemeService()),
      ChangeNotifierProvider.value(value: studentProfile),
    ],
    child: const VenueLockApp(),
  );

  // Device Preview lets someone browsing the web build on a desktop/laptop
  // pick a phone frame to view the app in. Skipped for the real mobile app
  // and for the web build when opened (or installed as a PWA) on a phone,
  // where it should just fill the screen like a native app.
  runApp(_devicePreviewEnabled
      ? DevicePreview(enabled: true, builder: (context) => app)
      : app);
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
      locale: _devicePreviewEnabled ? DevicePreview.locale(context) : null,
      builder: _devicePreviewEnabled ? DevicePreview.appBuilder : null,
    );
  }
}
