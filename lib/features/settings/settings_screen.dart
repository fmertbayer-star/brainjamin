import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'settings_links.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static final Uri _privacyUri = Uri.parse('https://brainjamin.com/privacy');
  static final Uri _termsUri = Uri.parse('https://brainjamin.com/terms');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & FAQ'),
            onTap: () => context.pushNamed('help'),
          ),
          ListTile(
            leading: const Icon(Icons.manage_accounts_outlined),
            title: const Text('Account'),
            onTap: () => context.pushNamed('account'),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Push notifications'),
            onTap: () => showComingSoonSnackBar(context),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            onTap: () => launchSettingsUri(context, _privacyUri),
          ),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('Terms of Service'),
            onTap: () => launchSettingsUri(context, _termsUri),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Export my data'),
            onTap: () => showComingSoonSnackBar(context),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text(
              'Delete account',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () => showComingSoonSnackBar(context),
          ),
        ],
      ),
    );
  }
}
