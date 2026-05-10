import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/home_shell.dart';
import 'screens/intro_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/tour_screen.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

class IponLockApp extends StatelessWidget {
  const IponLockApp({
    super.key,
    required this.storage,
    required this.auth,
  });

  final StorageService storage;
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storage),
        Provider<AuthService>.value(value: auth),
        ChangeNotifierProvider<AppState>(
          create: (_) => AppState(storage),
        ),
      ],
      child: MaterialApp(
        title: 'PesoFlow',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.light,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const _RootGate(),
      ),
    );
  }
}

class _RootGate extends StatefulWidget {
  const _RootGate();
  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate>
    with WidgetsBindingObserver {
  bool _splashDone = false;
  bool _introDone = false;
  bool _locked = true;
  bool _onboarded = false;
  bool _tourDone = true;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    final auth = context.read<AuthService>();
    _onboarded = auth.storage.onboardingComplete && auth.hasPin;
    // Intro is part of first-run setup. If the user closed the app before
    // setting their PIN, show the intro again so they're never dropped
    // straight into a half-finished setup.
    _introDone = _onboarded;
    _locked = _onboarded;
    _tourDone = auth.storage.tourSeen;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_splashDone) return;
    final storage = context.read<StorageService>();
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (!_onboarded) return;
      final since = _backgroundedAt;
      final mins = storage.autoLockMinutes;
      if (since == null) return;
      final elapsed = DateTime.now().difference(since);
      if (mins == 0 || elapsed.inMinutes >= mins) {
        if (!_locked) setState(() => _locked = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) {
      return SplashScreen(onDone: () {
        if (mounted) setState(() => _splashDone = true);
      });
    }
    if (!_introDone) {
      return IntroScreen(onDone: () {
        setState(() => _introDone = true);
      });
    }
    if (!_onboarded) {
      return OnboardingScreen(onDone: () {
        setState(() {
          _onboarded = true;
          _locked = false;
        });
      });
    }
    if (_locked) {
      return LockScreen(onUnlocked: () {
        setState(() => _locked = false);
      });
    }
    if (!_tourDone) {
      return TourScreen(onDone: () {
        context.read<StorageService>().tourSeen = true;
        setState(() => _tourDone = true);
      });
    }
    return const HomeShell();
  }
}
