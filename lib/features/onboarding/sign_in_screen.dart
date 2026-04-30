import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/auth_result.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/onboarding_flow_provider.dart';
import '../../core/utils/auth_error_localizations.dart';
import 'email_sign_in_sheet.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  /// Which control is mid-flight: `apple`, `google`, `email`, `anon`, or null.
  String? _active;

  bool get _busy => _active != null;

  Future<void> _finishOnboardingFlow() async {
    final flow = OnboardingFlowProvider.of(context);
    await flow.markAuthCompleted();
    await flow.markOnboardingCompleted();
    if (!mounted) return;
    context.go('/');
  }

  Future<void> _handleAuthResult(AuthResult result) async {
    if (result is AuthCancelled) {
      return;
    }
    if (result is AuthFailure) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authFailureMessage(l10n, result.code))),
      );
      return;
    }
    if (result is AuthSuccess) {
      await _finishOnboardingFlow();
      return;
    }
    if (result is AuthLinkedToExistingAccount) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final wantSwitch = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.accountExistsTitle),
          content: Text(l10n.accountExistsBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.accountExistsCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: BrainjaminColors.error,
              ),
              child: Text(l10n.accountExistsSwitch),
            ),
          ],
        ),
      );
      if (!mounted || wantSwitch != true) return;
      final swapped = await BrainjaminAuthService
          .signInWithCredentialReplacingAnonymous(result.credential);
      if (!mounted) return;
      if (swapped is AuthSuccess) {
        await _finishOnboardingFlow();
      } else if (swapped is AuthFailure) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authFailureMessage(loc, swapped.code))),
        );
      }
    }
  }

  Future<void> _withSpinner(String id, Future<AuthResult> Function() job) async {
    setState(() => _active = id);
    try {
      final r = await job();
      if (!mounted) return;
      await _handleAuthResult(r);
    } finally {
      if (mounted) setState(() => _active = null);
    }
  }

  Future<void> _onApple() =>
      _withSpinner('apple', BrainjaminAuthService.linkOrSignInWithApple);

  Future<void> _onGoogle() =>
      _withSpinner('google', BrainjaminAuthService.linkOrSignInWithGoogle);

  Future<void> _onEmail() async {
    setState(() => _active = 'email');
    try {
      final r = await EmailSignInBottomSheet.open(context);
      if (!mounted) return;
      if (r != null) {
        await _handleAuthResult(r);
      }
    } finally {
      if (mounted) setState(() => _active = null);
    }
  }

  Future<void> _onAnonymous() async {
    setState(() => _active = 'anon');
    try {
      final flow = OnboardingFlowProvider.of(context);
      await flow.markAuthCompleted();
      await flow.markOnboardingCompleted();
      if (!mounted) return;
      context.go('/');
    } finally {
      if (mounted) setState(() => _active = null);
    }
  }

  Widget _oauthButton({
    required String id,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _busy ? null : onPressed,
        child: _active == id
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon),
                  const SizedBox(width: 8),
                  Text(label),
                ],
              ),
      ),
    );
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
              _oauthButton(
                id: 'apple',
                icon: Icons.apple,
                label: l10n.signInWithApple,
                onPressed: _onApple,
              ),
              const SizedBox(height: 12),
              _oauthButton(
                id: 'google',
                icon: Icons.g_mobiledata,
                label: l10n.signInWithGoogle,
                onPressed: _onGoogle,
              ),
              const SizedBox(height: 12),
              _oauthButton(
                id: 'email',
                icon: Icons.mail_outline,
                label: l10n.signInWithEmail,
                onPressed: _onEmail,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _busy ? null : _onAnonymous,
                  child: _active == 'anon'
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.signInContinueAnonymous),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
