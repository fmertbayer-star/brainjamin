import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../core/constants/app_colors.dart';
import 'age_gate_screen.dart';

/// PR-14 mascot surface — placeholder until illustrator asset ships.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

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
              const SizedBox(height: 32),
              Text(
                l10n.welcomeTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: BrainjaminColors.brandOrange,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.welcomeBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: BrainjaminColors.onSurfaceMuted,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => const AgeGateScreen(),
                      ),
                    );
                  },
                  child: Text(l10n.welcomeCta),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
