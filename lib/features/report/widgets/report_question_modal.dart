import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../data/report_service.dart';

final class ReportQuestionModal {
  ReportQuestionModal._();

  static Future<void> show(
    BuildContext context, {
    required String questionId,
    required ReportGameMode gameMode,
  }) async {
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _ReportDialogContent(
        scaffoldMessenger: messenger,
        questionId: questionId,
        gameMode: gameMode,
      ),
    );
  }
}

enum _InlineErrorKind {
  alreadyReported,
  capReached,
  authRequired,
  invalid,
  generic,
}

class _ReportDialogContent extends StatefulWidget {
  const _ReportDialogContent({
    required this.scaffoldMessenger,
    required this.questionId,
    required this.gameMode,
  });

  final ScaffoldMessengerState scaffoldMessenger;
  final String questionId;
  final ReportGameMode gameMode;

  @override
  State<_ReportDialogContent> createState() => _ReportDialogContentState();
}

class _ReportDialogContentState extends State<_ReportDialogContent> {
  ReportReason? _selectedReason;
  final TextEditingController _freeTextController = TextEditingController();
  bool _submitting = false;
  _InlineErrorKind? _inlineError;

  @override
  void dispose() {
    _freeTextController.dispose();
    super.dispose();
  }

  String _resolveError(AppLocalizations l10n, _InlineErrorKind kind) {
    return switch (kind) {
      _InlineErrorKind.alreadyReported => l10n.report_modal_error_already_reported,
      _InlineErrorKind.capReached => l10n.report_modal_error_cap_reached,
      _InlineErrorKind.authRequired => l10n.report_modal_error_auth_required,
      _InlineErrorKind.invalid => l10n.report_modal_error_invalid,
      _InlineErrorKind.generic => l10n.report_modal_error_generic,
    };
  }

  _InlineErrorKind _mapException(ReportServiceException e) {
    if (e.code == 'already-exists') {
      return _InlineErrorKind.alreadyReported;
    }
    if (e.code == 'failed-precondition' && e.message == 'daily_cap_reached') {
      return _InlineErrorKind.capReached;
    }
    if (e.code == 'failed-precondition') {
      return _InlineErrorKind.generic;
    }
    if (e.code == 'unauthenticated') {
      return _InlineErrorKind.authRequired;
    }
    if (e.code == 'invalid-argument') {
      return _InlineErrorKind.invalid;
    }
    return _InlineErrorKind.generic;
  }

  Future<void> _submit() async {
    if (_selectedReason == null || _submitting) {
      return;
    }

    setState(() {
      _submitting = true;
      _inlineError = null;
    });

    try {
      final tzEntity = await FlutterTimezone.getLocalTimezone();
      final timezone = tzEntity.identifier;

      await ReportService().submitReport(
        questionId: widget.questionId,
        reason: _selectedReason!,
        freeText: _freeTextController.text.trim().isEmpty ?
          null :
          _freeTextController.text,
        timezone: timezone,
        gameMode: widget.gameMode,
      );

      if (!mounted) {
        return;
      }
      final successMsg = AppLocalizations.of(context).report_modal_success;
      Navigator.of(context).pop();
      widget.scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(successMsg)),
      );
    } on ReportServiceException catch (e) {
      if (mounted) {
        setState(() {
          _inlineError = _mapException(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.report_modal_title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<ReportReason>(
              value: _selectedReason,
              hint: Text(l10n.report_modal_reason_hint),
              items: ReportReason.values
                  .map(
                    (r) => DropdownMenuItem<ReportReason>(
                      value: r,
                      child: Text(switch (r) {
                        ReportReason.wrongAnswer =>
                          l10n.report_modal_reason_wrong_answer,
                        ReportReason.wrongOrUnclear =>
                          l10n.report_modal_reason_wrong_or_unclear,
                        ReportReason.inappropriateContent =>
                          l10n.report_modal_reason_inappropriate,
                        ReportReason.other => l10n.report_modal_reason_other,
                      }),
                    ),
                  )
                  .toList(),
              onChanged: _submitting ?
                null :
                (v) => setState(() => _selectedReason = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _freeTextController,
              maxLength: 200,
              maxLines: 3,
              enabled: !_submitting,
              decoration: InputDecoration(
                labelText: l10n.report_modal_free_text_label,
              ),
            ),
            if (_inlineError != null) ...[
              const SizedBox(height: 8),
              Text(
                _resolveError(l10n, _inlineError!),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.report_modal_cancel),
        ),
        TextButton(
          onPressed: (_selectedReason == null || _submitting) ? null : _submit,
          child: Text(l10n.report_modal_submit),
        ),
      ],
    );
  }
}
