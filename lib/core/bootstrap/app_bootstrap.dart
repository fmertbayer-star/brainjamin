import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../firebase_options.dart';
import '../services/auth_service.dart';
import '../services/server_time_service.dart';

/// Initializes Firebase and wires Crashlytics handlers.
/// Must be awaited before runApp().
Future<void> bootstrapBrainjamin() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  try {
    await ServerTimeService.initialize();
  } catch (e, stackTrace) {
    debugPrint(
      '[bootstrapBrainjamin] ServerTimeService.initialize failed: $e\n$stackTrace',
    );
  }
  try {
    await BrainjaminAuthService.ensureSignedIn();
  } catch (e, stackTrace) {
    debugPrint(
      '[bootstrapBrainjamin] BrainjaminAuthService.ensureSignedIn failed: $e\n$stackTrace',
    );
  }
  FlutterError.onError =
      FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
}
