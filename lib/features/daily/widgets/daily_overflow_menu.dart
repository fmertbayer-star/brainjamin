import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../report/data/report_service.dart';
import '../../report/widgets/report_question_modal.dart';

class DailyOverflowMenu extends StatelessWidget {
  const DailyOverflowMenu({super.key, required this.questionId});

  final String questionId;

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
        ReportQuestionModal.show(
          context,
          questionId: questionId,
          gameMode: ReportGameMode.daily,
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
