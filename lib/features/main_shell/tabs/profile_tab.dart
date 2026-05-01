import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/mascot_empty_state.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mainTabProfile)),
      body: StreamBuilder<User?>(
        stream: BrainjaminAuthService.authStateChanges,
        initialData: BrainjaminAuthService.currentUser,
        builder: (context, snapshot) {
          final user = snapshot.data;
          final showAnonymousCta = user == null || user.isAnonymous;

          if (showAnonymousCta) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // TODO(mascot): replace with illustrator deliverable per PR-14
                    const CircleAvatar(
                      radius: 36,
                      backgroundColor: BrainjaminColors.brandOrange,
                      child: Icon(
                        Icons.psychology,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.profileSignInCtaTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: BrainjaminColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.profileSignInCtaBody,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: BrainjaminColors.onSurfaceMuted,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () =>
                            context.pushNamed('onboarding-sign-in'),
                        child: Text(l10n.profileSignInCtaButton),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return MascotEmptyState(
            title: l10n.profileEmptyTitle,
            body: l10n.profileEmptyBody,
          );
        },
      ),
    );
  }
}
