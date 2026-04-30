import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/onboarding_flow_provider.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  void _showComingSoon(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.signInComingSoon)),
    );
  }

  Future<void> _continueAnonymous(BuildContext context) async {
    await OnboardingFlowProvider.of(context).markOnboardingCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              // TODO(mascot): replace with illustrator deliverable per PR-14
              const Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: BrainjaminColors.brandOrange,
                  child: Icon(
                    Icons.psychology,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.signInTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: BrainjaminColors.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.signInSubtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: BrainjaminColors.onSurfaceMuted,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showComingSoon(context),
                  icon: const Icon(Icons.apple),
                  label: Text(l10n.signInWithApple),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showComingSoon(context),
                  icon: const Icon(Icons.g_mobiledata),
                  label: Text(l10n.signInWithGoogle),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showComingSoon(context),
                  icon: const Icon(Icons.mail_outline),
                  label: Text(l10n.signInWithEmail),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => _continueAnonymous(context),
                  child: Text(l10n.signInContinueAnonymous),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
