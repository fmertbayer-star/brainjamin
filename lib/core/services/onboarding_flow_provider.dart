import 'package:flutter/widgets.dart';

import 'onboarding_flow_controller.dart';

class OnboardingFlowProvider extends InheritedNotifier<OnboardingFlowController> {
  // Not const: [controller] is runtime-only (see prefer_const_constructors_in_immutables).
  // ignore: prefer_const_constructors_in_immutables
  OnboardingFlowProvider({
    super.key,
    required OnboardingFlowController controller,
    required super.child,
  }) : super(notifier: controller);

  static OnboardingFlowController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<OnboardingFlowProvider>();
    assert(scope != null, 'OnboardingFlowProvider not found in context');
    return scope!.notifier!;
  }
}
