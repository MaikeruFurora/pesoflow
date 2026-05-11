import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
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
  final auth = AuthService(storage);
  runApp(IponLockApp(storage: storage, auth: auth));
}

void unawaited(Future<void> _) {}
