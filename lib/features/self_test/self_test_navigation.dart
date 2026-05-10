import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Self-Test is usually opened with [GoRouter.go] (no stack entry). Prefer a normal
/// pop when nested; otherwise replace location with Home.
void popSelfTestOrGoHome(BuildContext context) {
  if (!context.mounted) {
    return;
  }
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  } else {
    context.go('/');
  }
}
