import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../core/constants/app_colors.dart';
import '../data/self_test_service.dart';
import '../self_test_navigation.dart';
import '../state/self_test_controller.dart';

class SelfTestLandingScreen extends StatefulWidget {
  const SelfTestLandingScreen({
    super.key,
    required this.controller,
  });

  final SelfTestController controller;

  @override
  State<SelfTestLandingScreen> createState() => _SelfTestLandingScreenState();
}

class _SelfTestLandingScreenState extends State<SelfTestLandingScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = widget.controller;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) {
              return;
            }
            popSelfTestOrGoHome(context);
          },
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => popSelfTestOrGoHome(context),
              ),
              title: Text(l10n.self_test_landing_title),
            ),
            body: _buildBody(context, l10n, controller),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    SelfTestController controller,
  ) {
    switch (controller.status) {
      case SelfTestStatus.idle:
        return _buildIdle(context, l10n, controller);
      case SelfTestStatus.loading:
        return _buildLoading(l10n);
      case SelfTestStatus.error:
        return _buildError(context, l10n, controller);
      case SelfTestStatus.inProgress:
      case SelfTestStatus.submitting:
      case SelfTestStatus.completed:
        return const SizedBox.shrink();
    }
  }

  Widget _buildIdle(
    BuildContext context,
    AppLocalizations l10n,
    SelfTestController controller,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.self_test_tagline,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: BrainjaminColors.brandOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 18,
                ),
                minimumSize: const Size(200, 52),
              ),
              onPressed: () => controller.startSession(),
              child: Text(l10n.self_test_start_button),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.self_test_caption,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: BrainjaminColors.onSurfaceMuted,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(l10n.self_test_loading),
        ],
      ),
    );
  }

  Widget _buildError(
    BuildContext context,
    AppLocalizations l10n,
    SelfTestController controller,
  ) {
    final insufficient =
        controller.errorCode == SelfTestErrorCode.insufficientPool;
    final message = insufficient ?
        l10n.self_test_error_insufficient_pool :
        l10n.self_test_error_generic;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            if (!insufficient) ...[
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: BrainjaminColors.brandOrange,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => controller.startSession(),
                child: Text(l10n.self_test_try_again),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
