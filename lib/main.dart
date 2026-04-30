import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/bootstrap/app_bootstrap.dart';
import 'core/services/onboarding_flow_controller.dart';
import 'core/services/onboarding_flow_provider.dart';
import 'core/theme/app_theme.dart';
import 'router/app_router.dart';

Future<void> main() async {
  final bootstrap = await bootstrapBrainjamin();
  runApp(BrainjaminApp(bootstrap: bootstrap));
}

class BrainjaminApp extends StatefulWidget {
  const BrainjaminApp({super.key, required this.bootstrap});

  final BootstrapResult bootstrap;

  @override
  State<BrainjaminApp> createState() => _BrainjaminAppState();
}

class _BrainjaminAppState extends State<BrainjaminApp> {
  late final OnboardingFlowController _onboardingController;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _onboardingController = OnboardingFlowController(
      initialCompleted: widget.bootstrap.onboardingCompleted,
      initialAgeGatePassed: widget.bootstrap.ageGatePassed,
      initialAuthCompleted: widget.bootstrap.authCompleted,
    );
    _router = AppRouter.create(onboardingController: _onboardingController);
  }

  @override
  void dispose() {
    _onboardingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingFlowProvider(
      controller: _onboardingController,
      child: MaterialApp.router(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: BrainjaminTheme.light,
        routerConfig: _router,
      ),
    );
  }
}
