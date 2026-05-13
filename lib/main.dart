import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/quick_action_dispatcher.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  final storage = StorageService();
  await storage.init();
  // Best-effort notification init — failures should never block app launch.
  unawaited(NotificationService.instance.init());
  // Register launcher shortcuts immediately so the cold-launch action that
  // tripped the app is captured before HomeShell exists.
  unawaited(QuickActionDispatcher.instance.start());
  final auth = AuthService(storage);
  runApp(IponLockApp(storage: storage, auth: auth));
}

void unawaited(Future<void> _) {}
