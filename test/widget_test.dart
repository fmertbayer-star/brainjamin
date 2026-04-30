import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:brainjamin/core/theme/app_theme.dart';
import 'package:brainjamin/features/onboarding/onboarding_gate.dart';

void main() {
  testWidgets('Onboarding gate shows welcome on first launch', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        theme: BrainjaminTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const OnboardingGate(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Let's go"), findsOneWidget);
  });

  testWidgets('Onboarding gate skips welcome when already completed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'brainjamin.onboarding.completed': true,
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: BrainjaminTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const OnboardingGate(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("You're in."), findsOneWidget);
  });
}
