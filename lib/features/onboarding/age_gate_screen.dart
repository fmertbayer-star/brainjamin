import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/onboarding_flow_provider.dart';
import '../../core/services/server_time_service.dart';

class AgeGateScreen extends StatefulWidget {
  const AgeGateScreen({super.key});

  @override
  State<AgeGateScreen> createState() => _AgeGateScreenState();
}

class _AgeGateScreenState extends State<AgeGateScreen> {
  int? _birthMonth;
  int? _birthYear;

  bool _passesAgeGate(int birthYear, int birthMonth) {
    final now = ServerTimeService.now();
    final y = now.year - birthYear;
    if (y > 13) return true;
    if (y < 13) return false;
    return now.month >= birthMonth;
  }

  Future<void> _onContinue() async {
    final birthYear = _birthYear!;
    final birthMonth = _birthMonth!;
    if (!_passesAgeGate(birthYear, birthMonth)) {
      if (!mounted) return;
      context.goNamed('onboarding-age-blocked');
      return;
    }
    await OnboardingFlowProvider.of(context).markAgeGatePassed();
    if (!mounted) return;
    context.goNamed('onboarding-sign-in');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = ServerTimeService.now();
    final currentYear = now.year;
    final years = List<int>.generate(101, (i) => currentYear - i);

    final monthItems = List<int>.generate(12, (i) => i + 1).map((m) {
      final label = DateFormat('MMM', 'en').format(DateTime(2024, m));
      return DropdownMenuItem<int>(
        value: m,
        child: Text(label),
      );
    }).toList();

    final yearItems = years.map((y) {
      return DropdownMenuItem<int>(
        value: y,
        child: Text('$y'),
      );
    }).toList();

    final canContinue = _birthMonth != null && _birthYear != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.ageGateTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.ageGateSubtitle,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: BrainjaminColors.onSurfaceMuted,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      decoration: InputDecoration(
                        labelText: l10n.ageGateBirthMonth,
                      ),
                      value: _birthMonth,
                      items: monthItems,
                      onChanged: (v) => setState(() => _birthMonth = v),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      decoration: InputDecoration(
                        labelText: l10n.ageGateBirthYear,
                      ),
                      value: _birthYear,
                      items: yearItems,
                      onChanged: (v) => setState(() => _birthYear = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: canContinue ? _onContinue : null,
                child: Text(l10n.ageGateContinue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
