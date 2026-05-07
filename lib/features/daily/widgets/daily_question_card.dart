import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../core/constants/app_colors.dart';
import '../state/daily_question_controller.dart';

class DailyQuestionCard extends StatefulWidget {
  const DailyQuestionCard({
    super.key,
    required this.controller,
    required this.onTap,
  });

  final DailyQuestionController controller;
  final VoidCallback onTap;

  @override
  State<DailyQuestionCard> createState() => _DailyQuestionCardState();
}

class _DailyQuestionCardState extends State<DailyQuestionCard> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final isLoading = widget.controller.status == DailyQuestionStatus.loading ||
            widget.controller.status == DailyQuestionStatus.idle;
        final question = widget.controller.question;
        final alreadyAnswered = question?.alreadyAnswered ?? false;
        final streak = widget.controller.streak;
        final forgives = widget.controller.forgivesAvailableThisWeek;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Card(
            elevation: 0,
            color: BrainjaminColors.brandOrange.withValues(alpha: 0.06),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: BrainjaminColors.brandOrange.withValues(alpha: 0.35),
              ),
            ),
            child: InkWell(
              onTap: isLoading ? null : widget.onTap,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      width: 52,
                      height: 52,
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: BrainjaminColors.brandOrange,
                        child: Icon(Icons.psychology, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.daily_card_headline,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: BrainjaminColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (streak != null && streak >= 1)
                            Text(
                              l10n.daily_card_streak_label(streak),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: BrainjaminColors.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (streak != null && streak >= 1 && forgives == 1) ...[
                            const SizedBox(height: 4),
                            Text(
                              l10n.daily_card_forgive_available,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: BrainjaminColors.onSurfaceMuted,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          if (isLoading)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Text(
                              alreadyAnswered ?
                                l10n.daily_card_cta_see_result :
                                l10n.daily_card_cta_play,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: BrainjaminColors.brandOrangeDark,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: BrainjaminColors.onSurfaceMuted.withValues(alpha: 0.75),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
