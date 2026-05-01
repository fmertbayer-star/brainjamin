import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/widgets.dart';

import '../../firebase_options.dart';
import '../services/auth_service.dart';
import '../services/onboarding_state_service.dart';
import '../services/server_time_service.dart';

/// Result of [bootstrapBrainjamin] — onboarding flags pre-loaded for sync startup.
class BootstrapResult {
  const BootstrapResult({
    required this.onboardingCompleted,
    required this.ageGatePassed,
    this.authCompleted = false,
  });

  final bool onboardingCompleted;
  final bool ageGatePassed;
  final bool authCompleted;
}

/// Initializes Firebase and wires Crashlytics handlers.
/// Must be awaited before runApp().
Future<BootstrapResult> bootstrapBrainjamin() async {
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

  final onboardingCompleted =
      await OnboardingStateService.isOnboardingCompleted();
  final ageGatePassed = await OnboardingStateService.isAgeGatePassed();
  final authCompleted = await OnboardingStateService.isAuthCompleted();

  if (!kIsWeb) {
    FlutterError.onError =
        FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  return BootstrapResult(
    onboardingCompleted: onboardingCompleted,
    ageGatePassed: ageGatePassed,
    authCompleted: authCompleted,
  );
}
