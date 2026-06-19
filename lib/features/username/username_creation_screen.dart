import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/firebase_config.dart';

class UsernameCreationScreen extends StatefulWidget {
  const UsernameCreationScreen({super.key});

  @override
  State<UsernameCreationScreen> createState() => _UsernameCreationScreenState();
}

class _UsernameCreationScreenState extends State<UsernameCreationScreen> {
  static const int _maxLength = 20;

  final TextEditingController _usernameController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _usernameController.removeListener(_onUsernameChanged);
    _usernameController.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    setState(() {});
  }

  bool get _canSubmit =>
      _usernameController.text.trim().isNotEmpty && !_submitting;

  String _snackbarForFunctionsException(FirebaseFunctionsException e) {
    final code = e.code.toLowerCase();
    final message = (e.message ?? '').toLowerCase();

    if (code == 'invalid-argument' && message == 'cooldown') {
      return 'You can only change your username once every 30 days.';
    }
    if (code == 'invalid-argument' && message == 'blocked') {
      return "That username isn't allowed. Please choose another.";
    }
    if (code == 'already-exists' && message == 'taken') {
      return 'That username is already taken.';
    }
    if (code == 'invalid-argument') {
      return 'Username must be 3–20 characters, start with a letter, '
          'and use only letters, numbers, and underscores.';
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> _onConfirm() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty || _submitting) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: FirebaseConfig.functionsRegion,
      ).httpsCallable('validateUsername');
      final result = await callable.call<Map<String, dynamic>>({
        'username': username,
      });
      final data = result.data;
      if (data['ok'] == true) {
        if (!mounted) return;
        context.pop(true);
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_snackbarForFunctionsException(e))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose your username'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _usernameController,
                maxLength: _maxLength,
                keyboardType: TextInputType.visiblePassword,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  counterText: '',
                ),
                buildCounter: (
                  context, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '$currentLength / ${maxLength ?? _maxLength}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                '3–20 characters · letters, numbers, underscores · '
                'must start with a letter',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _canSubmit ? _onConfirm : null,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Confirm'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
