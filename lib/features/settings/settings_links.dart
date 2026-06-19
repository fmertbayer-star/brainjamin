import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> launchSettingsUri(BuildContext context, Uri uri) async {
  final launched = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  );
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open link.')),
    );
  }
}

void showComingSoonSnackBar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Coming soon')),
  );
}
