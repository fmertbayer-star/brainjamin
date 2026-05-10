import 'package:flutter/material.dart';

import 'data/self_test_service.dart';
import 'state/self_test_controller.dart';
import 'widgets/self_test_landing_screen.dart';
import 'widgets/self_test_question_screen.dart';
import 'widgets/self_test_result_screen.dart';

/// Self-Test flow root — landing, question loop, results.
class SelfTestScreen extends StatefulWidget {
  const SelfTestScreen({super.key});

  @override
  State<SelfTestScreen> createState() => _SelfTestScreenState();
}

class _SelfTestScreenState extends State<SelfTestScreen> {
  late final SelfTestController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SelfTestController(service: SelfTestService());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        switch (_controller.status) {
          case SelfTestStatus.inProgress:
          case SelfTestStatus.submitting:
            return SelfTestQuestionScreen(controller: _controller);
          case SelfTestStatus.completed:
            return SelfTestResultScreen(controller: _controller);
          case SelfTestStatus.idle:
          case SelfTestStatus.loading:
          case SelfTestStatus.error:
            return SelfTestLandingScreen(controller: _controller);
        }
      },
    );
  }
}
