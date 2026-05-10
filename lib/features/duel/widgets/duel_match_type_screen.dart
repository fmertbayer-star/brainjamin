import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/duel_service.dart';

class DuelMatchTypeScreen extends StatefulWidget {
  const DuelMatchTypeScreen({super.key});

  @override
  State<DuelMatchTypeScreen> createState() => _DuelMatchTypeScreenState();
}

class _DuelMatchTypeScreenState extends State<DuelMatchTypeScreen> {
  final DuelService _duelService = DuelService();
  int? _queueCount;
  bool _creatingRandom = false;
  bool _creatingInvite = false;

  @override
  void initState() {
    super.initState();
    _loadLobbyStats();
  }

  Future<void> _loadLobbyStats() async {
    try {
      final result = await _duelService.getDuelLobbyStats();
      final count = result['randomQueueSize'];
      if (!mounted || count is! num) return;
      setState(() {
        _queueCount = count.toInt();
      });
    } catch (_) {
      // Keep UI usable if stats fail.
    }
  }

  Future<void> _handleRandomTap() async {
    if (_creatingRandom || _creatingInvite) return;
    setState(() {
      _creatingRandom = true;
    });

    try {
      final result = await _duelService.createDuel(type: 'random');
      final duelId = result['duelId'];

      if (duelId is! String || duelId.isEmpty) {
        throw StateError('createDuel returned an invalid duelId');
      }

      if (!mounted) return;
      final uri = Uri(path: '/duel/quiz', queryParameters: {'duelId': duelId});
      context.push(uri.toString());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _creatingRandom = false;
        });
      }
    }
  }

  Future<void> _handleInviteTap() async {
    if (_creatingRandom || _creatingInvite) return;
    setState(() {
      _creatingInvite = true;
    });

    try {
      final result = await _duelService.createDuel(type: 'invite');
      final duelId = result['duelId'];
      final inviteCode = result['inviteCode'];

      if (duelId is! String ||
          duelId.isEmpty ||
          inviteCode is! String ||
          inviteCode.isEmpty) {
        throw StateError('createDuel invite returned invalid payload');
      }

      if (!mounted) return;
      final uri = Uri(
        path: '/duel/invite-share',
        queryParameters: {
          'duelId': duelId,
          'inviteCode': inviteCode,
        },
      );
      context.push(uri.toString());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _creatingInvite = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.duelMatchTypeTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_queueCount != null) ...[
              Text(l10n.duelMatchTypeQueueCount(_queueCount!)),
              const SizedBox(height: 12),
            ],
            ElevatedButton(
              onPressed: (_creatingRandom || _creatingInvite) ?
                  null :
                  _handleRandomTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.duelMatchTypeRandom),
                  if (_creatingRandom) ...[
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
            OutlinedButton(
              onPressed: (_creatingRandom || _creatingInvite) ?
                  null :
                  _handleInviteTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.duelMatchTypeInvite),
                  if (_creatingInvite) ...[
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
              onPressed: (_creatingRandom || _creatingInvite) ?
                  null :
                  () => context.push('/duel/join'),
              child: Text(l10n.duelMatchTypeJoinCode),
            ),
          ],
        ),
      ),
    );
  }
}
