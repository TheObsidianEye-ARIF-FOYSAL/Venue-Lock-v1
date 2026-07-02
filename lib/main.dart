import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'core/services/app_state.dart';
import 'core/services/auth_service.dart';
import 'core/services/service_instances.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await subscriptionService.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider.value(value: subscriptionService),
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
    // Listen to Firebase Auth changes and sync venues automatically
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      final appState = context.read<AppState>();
      if (user != null) {
        appState.startSync(user.uid);
      } else {
        appState.stopSync();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'VenueLock',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
