import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/firebase_config.dart';
import '../../core/services/auth_service.dart';

/// Account management — anonymous conversion CTA or permanent sign-in / danger zone.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: FirebaseConfig.functionsRegion);

  Future<void> _showBlockingProgress() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }

  void _dismissBlockingProgress() {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  Future<void> _exportUserData() async {
    if (!mounted) return;
    await _showBlockingProgress();
    try {
      await _functions.httpsCallable('exportUserData').call();
      if (!mounted) return;
      _dismissBlockingProgress();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your data has been prepared. Check your profile for the export.',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      _dismissBlockingProgress();
      final message = e.code == 'resource-exhausted' ?
          'You can only export your data once every 30 days.' :
          'Something went wrong. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;
      _dismissBlockingProgress();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    }
  }

  String _signInMethodLabel(User user) {
    for (final info in user.providerData) {
      switch (info.providerId) {
        case 'apple.com':
          return 'Apple ID';
        case 'google.com':
          return 'Google';
        case 'password':
          final email = info.email ?? user.email;
          if (email != null && email.isNotEmpty) {
            return email;
          }
          return 'Email';
      }
    }
    final email = user.email;
    if (email != null && email.isNotEmpty) {
      return email;
    }
    return 'Account';
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'All your data will be permanently removed after 30 days. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep my account'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    await _showBlockingProgress();
    try {
      await _functions.httpsCallable('softDeleteAccount').call();
      if (!mounted) return;
      _dismissBlockingProgress();
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      context.goNamed('onboarding-welcome');
    } catch (_) {
      if (!mounted) return;
      _dismissBlockingProgress();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: StreamBuilder<User?>(
        stream: BrainjaminAuthService.authStateChanges,
        initialData: BrainjaminAuthService.currentUser,
        builder: (context, snapshot) {
          final user = snapshot.data;
          if (user == null || user.isAnonymous) {
            return const _AnonymousAccountBody();
          }
          return _PermanentAccountBody(
            signInMethodLabel: _signInMethodLabel(user),
            onExport: _exportUserData,
            onDelete: _confirmDeleteAccount,
          );
        },
      ),
    );
  }
}

class _AnonymousAccountBody extends StatelessWidget {
  const _AnonymousAccountBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "You're playing anonymously",
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: BrainjaminColors.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your streak and XP are saved on this device. Create a free account '
              'to unlock leaderboards and protect your progress — it takes 30 seconds.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: BrainjaminColors.onSurfaceMuted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.pushNamed('onboarding-sign-in'),
                child: const Text('Continue with Apple'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () => context.pushNamed('onboarding-sign-in'),
                child: const Text('Continue with Google'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.pushNamed('onboarding-sign-in'),
                child: const Text('Continue with Email'),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your anonymous progress will be preserved when you sign in.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: BrainjaminColors.onSurfaceMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermanentAccountBody extends StatelessWidget {
  const _PermanentAccountBody({
    required this.signInMethodLabel,
    required this.onExport,
    required this.onDelete,
  });

  final String signInMethodLabel;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      children: [
        _SectionHeader(title: 'Sign-in method', theme: theme),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: Text(signInMethodLabel),
        ),
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('Add or change sign-in method'),
          onTap: () => context.pushNamed('onboarding-sign-in'),
        ),
        const Divider(height: 32),
        _SectionHeader(
          title: 'Danger zone',
          theme: theme,
          color: Colors.red,
        ),
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: const Text('Export my data'),
          onTap: onExport,
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline, color: Colors.red),
          title: const Text(
            'Delete account',
            style: TextStyle(color: Colors.red),
          ),
          onTap: onDelete,
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.theme,
    this.color,
  });

  final String title;
  final ThemeData theme;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: color ?? BrainjaminColors.onSurfaceMuted,
        ),
      ),
    );
  }
}
