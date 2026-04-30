import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brainjamin/core/bootstrap/app_bootstrap.dart';
import 'package:brainjamin/main.dart';

// TODO(sprint-7): Add Firebase Auth mocking for sign-in / linkWithCredential flows.
void main() {
  testWidgets('Shows welcome when onboarding not completed', (tester) async {
    await tester.pumpWidget(
      const BrainjaminApp(
        bootstrap: BootstrapResult(
          onboardingCompleted: false,
          ageGatePassed: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Hello — I'm Brainjamin."), findsOneWidget);
  });

  testWidgets('Shows main shell when onboarding completed', (tester) async {
    await tester.pumpWidget(
      const BrainjaminApp(
        bootstrap: BootstrapResult(
          onboardingCompleted: true,
          ageGatePassed: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
  });
}
