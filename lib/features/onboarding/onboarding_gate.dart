import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/onboarding_state_service.dart';
import 'welcome_screen.dart';

class OnboardingGate extends StatefulWidget {
  const OnboardingGate({super.key});

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  late final Future<bool> _completedFuture;

  @override
  void initState() {
    super.initState();
    _completedFuture = OnboardingStateService.isOnboardingCompleted();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _completedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final completed = snapshot.data ?? false;
        if (completed) {
          return const MainShellPlaceholder();
        }
        return const WelcomeScreen();
      },
    );
  }
}

// TODO(sprint-1.4): replace MainShellPlaceholder with the real 5-tab shell.
class MainShellPlaceholder extends StatelessWidget {
  const MainShellPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.mainPlaceholderTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: BrainjaminColors.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.mainPlaceholderSubtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: BrainjaminColors.onSurfaceMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
