import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../core/services/push_primer_service.dart';

final class PushPrimerDialog {
  PushPrimerDialog._();

  static Future<void> showIfNeeded(BuildContext context) async {
    if (kIsWeb) {
      return;
    }

    try {
      final shouldShow = await PushPrimerService.shouldShowPrimer();
      if (!shouldShow || !context.mounted) {
        return;
      }

      await PushPrimerService.writeCooldown();
      if (!context.mounted) {
        return;
      }
    } catch (error, stackTrace) {
      debugPrint('[PushPrimerDialog] preflight failed: $error');
      debugPrint(stackTrace.toString());
      return;
    }

    final l10n = AppLocalizations.of(context);
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.push_primer_title),
        content: Text(l10n.push_primer_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.push_primer_decline),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.push_primer_accept),
          ),
        ],
      ),
    );

    if (accepted == true) {
      await PushPrimerService.requestAndCaptureToken();
    }
  }
}
