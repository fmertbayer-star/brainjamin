import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'core/bootstrap/app_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/onboarding_gate.dart';
import 'features/onboarding/onboarding_routes.dart';

Future<void> main() async {
  await bootstrapBrainjamin();
  runApp(const BrainjaminApp());
}

class BrainjaminApp extends StatelessWidget {
  const BrainjaminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: BrainjaminTheme.light,
      routes: {
        OnboardingRoutes.root: (_) => const OnboardingGate(),
      },
      home: const OnboardingGate(),
    );
  }
}
