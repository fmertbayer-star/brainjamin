import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';

class AgeBlockedScreen extends StatelessWidget {
  const AgeBlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              // TODO(mascot): replace with illustrator deliverable per PR-14
              const CircleAvatar(
                radius: 64,
                backgroundColor: BrainjaminColors.brandOrange,
                child: Icon(
                  Icons.psychology,
                  size: 64,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.ageGateBlockedTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: BrainjaminColors.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.ageGateBlockedBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: BrainjaminColors.onSurfaceMuted,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () =>
                      context.goNamed('onboarding-age-gate'),
                  child: Text(l10n.ageGateBlockedBack),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
