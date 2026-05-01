import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/auth_constants.dart';
import '../../core/services/auth_result.dart';
import '../../core/services/auth_service.dart';

/// Anonymous → permanent account attempt using email/password (no verification mail — CONTEXT § Auth).
///
/// Prefer `fetchSignInMethodsForEmail` when it still resolves (deprecated upstream); fallback: segmented UX.
class EmailSignInBottomSheet extends StatefulWidget {
  const EmailSignInBottomSheet({super.key});

  static Future<AuthResult?> open(BuildContext context) {
    return showModalBottomSheet<AuthResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const EmailSignInBottomSheet(),
    );
  }

  @override
  State<EmailSignInBottomSheet> createState() => _EmailSignInBottomSheetState();
}

class _EmailSignInBottomSheetState extends State<EmailSignInBottomSheet> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _loading = false;
  /// 0 = sign up, 1 = sign in (fallback when Firebase cannot list methods).
  int _segment = 0;

  Future<List<String>?> _signInMethodsForEmail(String email) async {
    try {
      // ignore: deprecated_member_use
      return FirebaseAuth.instance.fetchSignInMethodsForEmail(email.trim());
    } catch (_) {
      return null;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final email = _email.text.trim();
      final methods = await _signInMethodsForEmail(email);

      final bool isSignUp;
      if (methods != null) {
        isSignUp = methods.isEmpty;
      } else {
        isSignUp = _segment == 0;
      }

      final result = await BrainjaminAuthService.linkOrSignInWithEmail(
        email: email,
        password: _password.text,
        isSignUp: isSignUp,
      );

      if (!mounted) return;
      Navigator.of(context).pop(result);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final inset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: BrainjaminColors.onSurfaceMuted
                        .withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.emailSignInSheetTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: BrainjaminColors.onSurface,
                    ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(
                    value: 0,
                    label: Text(l10n.emailSignInTabSignUp),
                  ),
                  ButtonSegment(
                    value: 1,
                    label: Text(l10n.emailSignInTabSignIn),
                  ),
                ],
                selected: {_segment},
                showSelectedIcon: false,
                emptySelectionAllowed: false,
                onSelectionChanged: (selection) =>
                    setState(() => _segment = selection.single),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.emailSignInFetchFallbackHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: BrainjaminColors.onSurfaceMuted,
                    ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  labelText: l10n.emailSignInEmailLabel,
                  hintText: l10n.emailHint,
                ),
                validator: (v) {
                  final s = v?.trim() ?? '';
                  if (s.isEmpty) {
                    return l10n.authFieldRequired;
                  }
                  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s)) {
                    return l10n.authErrorInvalidEmail;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: l10n.emailSignInPasswordLabel,
                  hintText: l10n.passwordHint,
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (v) {
                  final s = v ?? '';
                  if (s.isEmpty) {
                    return l10n.authFieldRequired;
                  }
                  if (s.length < BrainjaminAuthConstants.minPasswordLength) {
                    return l10n.authErrorWeakPassword;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.emailContinue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
