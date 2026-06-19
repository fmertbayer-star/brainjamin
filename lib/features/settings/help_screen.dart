import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'settings_links.dart';

class _FaqItem {
  const _FaqItem(this.question, this.answer);

  final String question;
  final String answer;
}

class _FaqCategory {
  const _FaqCategory(this.title, this.items);

  final String title;
  final List<_FaqItem> items;
}

const _faqCategories = <_FaqCategory>[
  _FaqCategory('Account', [
    _FaqItem(
      'How do I save my progress?',
      'Create a free account via Profile → Save my account. Your XP, streak, and history are already saved and will carry over.',
    ),
    _FaqItem(
      'Can I change my username?',
      'Yes — once every 30 days. Go to Profile and tap your username to change it.',
    ),
    _FaqItem(
      'How do I delete my account?',
      'Go to Profile → Settings → Delete account. Your data is permanently removed after 30 days.',
    ),
  ]),
  _FaqCategory('Gameplay', [
    _FaqItem(
      'What happens if I miss a daily question?',
      'You get one streak forgiveness per week — it auto-applies on the first miss. A second miss in the same week breaks your streak.',
    ),
    _FaqItem(
      'How does the Duel work?',
      "You answer 10 questions, then your opponent does the same. Whoever scores higher wins. You don't have to play at the same time.",
    ),
    _FaqItem(
      'What is Battle Arena mode?',
      "A wrong answer eliminates you. Last player standing wins. You can watch as a spectator after you're eliminated.",
    ),
    _FaqItem(
      'How is XP calculated?',
      'Every mode awards XP — Daily gives 50 for correct and 10 for wrong. Tournaments scale by rank. Duels give 50 for a win, 25 for a draw, 10 for a loss.',
    ),
  ]),
  _FaqCategory('Issues', [
    _FaqItem(
      'A question seems wrong — what do I do?',
      'Tap the three-dot menu on any question and choose Report. We review all reports weekly.',
    ),
    _FaqItem(
      "The app isn't loading — what should I try?",
      'Force-close and reopen the app. If the problem continues, check your internet connection and try again.',
    ),
    _FaqItem(
      'I lost my streak — can it be restored?',
      "Streaks can't be manually restored. The one-per-week forgiveness is automatic — it's the only safety net we offer.",
    ),
  ]),
  _FaqCategory('Legal / Privacy', [
    _FaqItem(
      'What data does Brainjamin collect?',
      'We collect your gameplay activity and optional account info (email or Apple/Google ID). Full details in our Privacy Policy.',
    ),
    _FaqItem(
      'How do I request my data?',
      "Go to Profile → Settings → Export my data. We'll prepare a download within 48 hours.",
    ),
  ]),
];

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static final Uri _contactSupportUri = Uri.parse(
    'mailto:support@brainjamin.com?subject=Brainjamin%20Support&body=Device%3A%20%5Byour%20device%5D%0AOS%3A%20%5Byour%20OS%5D%0AApp%20version%3A%20%5Bversion%5D',
  );

  static final Uri _reportBugUri = Uri.parse(
    'mailto:support@brainjamin.com?subject=Brainjamin%20Bug%20Report&body=Device%3A%20%5Byour%20device%5D%0AOS%3A%20%5Byour%20OS%5D%0AVersion%3A%20%5Bversion%5D',
  );

  static final Uri _privacyUri = Uri.parse('https://brainjamin.com/privacy');
  static final Uri _termsUri = Uri.parse('https://brainjamin.com/terms');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Help')),
      body: ListView(
        children: [
          ..._faqCategories.expand(
            (category) => [
              ListTile(
                title: Text(
                  category.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ...category.items.map(
                (item) => ExpansionTile(
                  title: Text(item.question),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          item.answer,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: BrainjaminColors.onSurfaceMuted,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Contact Support'),
            onTap: () => launchSettingsUri(context, _contactSupportUri),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Report a Bug'),
            onTap: () => launchSettingsUri(context, _reportBugUri),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            onTap: () => launchSettingsUri(context, _privacyUri),
          ),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('Terms of Service'),
            onTap: () => launchSettingsUri(context, _termsUri),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              // TODO(sprint-7): replace with package_info_plus version + build number.
              'Brainjamin v1.0.0',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: BrainjaminColors.onSurfaceMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
