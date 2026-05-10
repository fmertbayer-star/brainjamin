import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../data/arena_service.dart';

const int _kInviteCodeMaxLength = 12;

/// Uppercase; strip whitespace; optional leading `BJ-` only (not bare `BJ`).
String _normalizeArenaInviteCode(String raw) {
  var s = raw.trim().toUpperCase().replaceAll(RegExp(r'\s'), '');
  if (s.startsWith('BJ-')) {
    s = s.substring(3);
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

class ArenaJoinCodeScreen extends StatefulWidget {
  const ArenaJoinCodeScreen({super.key});

  @override
  State<ArenaJoinCodeScreen> createState() => _ArenaJoinCodeScreenState();
}

class _ArenaJoinCodeScreenState extends State<ArenaJoinCodeScreen> {
  final ArenaService _arenaService = ArenaService();
  final TextEditingController _codeController = TextEditingController();

  bool _joining = false;
  String? _inlineError;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String _messageForArenaException(
    AppLocalizations l10n,
    ArenaServiceException e,
  ) {
    switch (e.code.toLowerCase()) {
      case 'not-found':
        return l10n.arena_join_error_not_found;
      case 'failed-precondition':
        return l10n.arena_join_error_closed;
      case 'resource-exhausted':
        return l10n.arena_join_error_closed;
      case 'unauthenticated':
        return l10n.arena_join_error_auth;
      case 'permission-denied':
        return l10n.arena_join_error_closed;
      default:
        return l10n.arena_join_error_generic;
    }
  }

  Future<void> _onJoin() async {
    final l10n = AppLocalizations.of(context);
    final code = _normalizeArenaInviteCode(_codeController.text);
    if (code.isEmpty) {
      setState(() {
        _inlineError = l10n.arena_join_error_empty;
      });
      return;
    }

    setState(() {
      _inlineError = null;
      _joining = true;
    });

    try {
      final result = await _arenaService.joinArena(inviteCode: code);
      final arenaId = result['arena_id'];
      if (arenaId is! String || arenaId.isEmpty) {
        throw StateError('joinArena returned an invalid arena_id');
      }
      if (!mounted) return;
      final uri = Uri(
        path: '/arena/lobby',
        queryParameters: {'arenaId': arenaId},
      );
      context.go(uri.toString());
    } on ArenaServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_messageForArenaException(l10n, e))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.arena_join_error_generic)),
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
    final normalized = _normalizeArenaInviteCode(_codeController.text);
    final canSubmit = normalized.isNotEmpty && !_joining;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.arena_join_title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                labelText: l10n.arena_join_label,
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
                  Text(l10n.arena_join_submit),
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
              child: Text(l10n.arena_create_back),
            ),
          ],
        ),
      ),
    );
  }
}
