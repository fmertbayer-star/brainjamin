import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../core/constants/app_colors.dart';

class SelfTestTab extends StatelessWidget {
  const SelfTestTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mainTabSelfTest)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // TODO(mascot): replace with illustrator deliverable per PR-14
              const CircleAvatar(
                radius: 36,
                backgroundColor: BrainjaminColors.brandOrange,
                child: Icon(Icons.psychology, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.selfTestEmptyTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: BrainjaminColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.selfTestEmptyBody,
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
