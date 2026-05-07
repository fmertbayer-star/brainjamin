import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class DailyOverflowMenu extends StatelessWidget {
  const DailyOverflowMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      onSelected: (value) {
        if (value != 'report') {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.daily_overflow_report_coming_soon)),
        );
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'report',
          child: Text(l10n.daily_overflow_report),
        ),
      ],
    );
  }
}
