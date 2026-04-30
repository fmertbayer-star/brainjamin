import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Brainjamin mascot placeholder + centered title/body empty state pattern.
///
/// Keeps parity with the Sprint 1.4 tab placeholders; illustrator swap is PR-14.
class MascotEmptyState extends StatelessWidget {
  const MascotEmptyState({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // TODO(mascot): replace with illustrator deliverable per PR-14
            const CircleAvatar(
              radius: 36,
              backgroundColor: BrainjaminColors.brandOrange,
              child: Icon(Icons.psychology, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: BrainjaminColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: BrainjaminColors.onSurfaceMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
