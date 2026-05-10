import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/duel_service.dart';

const int _kInviteCodeMaxLength = 12;

/// Trim, uppercase, remove whitespace, strip optional leading `BJ-` / `BJ` (illusory legacy prefix).
String _normalizeBareInviteCode(String raw) {
  var s = raw.trim().toUpperCase().replaceAll(RegExp(r'\s'), '');
  if (s.startsWith('BJ-')) {
    s = s.substring(3);
  } else if (s.startsWith('BJ')) {
    s = s.substring(2);
  }
  return s;
}

class _UppercaseNoWhitespaceFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var t = newValue.text.replaceAll(RegExp(r'\s'), '').toUpperCase();
    if (t.length > _kInviteCodeMaxLength) {
      t = t.substring(0, _kInviteCodeMaxLength);
    }
    return TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }
}

class DuelJoinCodeScreen extends StatefulWidget {
  const DuelJoinCodeScreen({super.key});

  @override
  State<DuelJoinCodeScreen> createState() => _DuelJoinCodeScreenState();
}

class _DuelJoinCodeScreenState extends State<DuelJoinCodeScreen> {
  final DuelService _duelService = DuelService();
  final TextEditingController _codeController = TextEditingController();

  bool _joining = false;
  String? _inlineError;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String _messageForFunctionsException(
    AppLocalizations l10n,
    FirebaseFunctionsException e,
  ) {
    switch (e.code.toLowerCase()) {
      case 'not-found':
        return l10n.duelJoinCodeErrorNotFound;
      case 'failed-precondition':
        return l10n.duelJoinCodeErrorClosed;
      case 'resource-exhausted':
        return l10n.duelJoinCodeErrorTooMany;
      case 'unauthenticated':
        return l10n.duelJoinCodeErrorAuth;
      default:
        return l10n.duelJoinCodeErrorGeneric;
    }
  }

  Future<void> _onJoin() async {
    final l10n = AppLocalizations.of(context);
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _inlineError = l10n.duelJoinCodeEmpty;
      });
      return;
    }

    setState(() {
      _inlineError = null;
      _joining = true;
    });

    try {
      final result = await _duelService.joinDuel(inviteCode: code);
      final duelId = result['duelId'];
      if (duelId is! String || duelId.isEmpty) {
        throw StateError('joinDuel returned an invalid duelId');
      }
      if (!mounted) return;
      final uri = Uri(path: '/duel/quiz', queryParameters: {'duelId': duelId});
      context.go(uri.toString());
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_messageForFunctionsException(l10n, e))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.duelJoinCodeErrorGeneric)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _joining = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final normalized = _normalizeBareInviteCode(_codeController.text);
    final canSubmit = normalized.isNotEmpty && !_joining;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.duelJoinCodeTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.duelJoinCodeHelper,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _codeController,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontFamily: 'monospace',
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              maxLength: _kInviteCodeMaxLength,
              buildCounter: (
                context, {
                required currentLength,
                required isFocused,
                maxLength,
              }) =>
                  const SizedBox.shrink(),
              decoration: InputDecoration(
                hintText: l10n.duelJoinCodeHint,
                errorText: _inlineError,
              ),
              inputFormatters: [
                _UppercaseNoWhitespaceFormatter(),
              ],
              onChanged: (_) {
                setState(() {
                  if (_inlineError != null) {
                    _inlineError = null;
                  }
                });
              },
              onSubmitted: (_) {
                if (canSubmit) {
                  _onJoin();
                }
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: !canSubmit ? null : _onJoin,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.duelJoinCodeCta),
                  if (_joining) ...[
                    const SizedBox(width: 12),
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _joining ? null : () => context.pop(),
              child: Text(l10n.duelJoinCodeBack),
            ),
          ],
        ),
      ),
    );
  }
}
