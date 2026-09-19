import 'package:flutter/material.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  static const String currentVersion = '2026-09-20';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Terms & Conditions',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'ExamReady Terms & Conditions',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Version: $currentVersion',
            style: Theme.of(context)
                .textTheme
                .bodySmall,
          ),
          const SizedBox(height: 24),

          const _TermsSection(
            title: '1. About ExamReady',
            body:
                'ExamReady is an examination information and '
                'organization application designed to help users '
                'track examinations, important dates, requirements, '
                'official updates, documents, and related information.',
          ),

          const _TermsSection(
            title: '2. Official Information Sources',
            body:
                'ExamReady collects, organizes, and presents information '
                'obtained from official examination authorities, official '
                'websites, notices, bulletins, portals, and other linked '
                'official sources where available.',
          ),

          const _TermsSection(
            title: '3. Verify Important Information',
            body:
                'Although ExamReady is designed to present information '
                'accurately, examination authorities may change dates, '
                'fees, eligibility requirements, instructions, documents, '
                'or other details. Users should verify critical and '
                'time-sensitive information through the official source '
                'linked inside ExamReady before taking action.',
          ),

          const _TermsSection(
            title: '4. No Affiliation With Examination Authorities',
            body:
                'Unless explicitly stated otherwise, ExamReady is not an '
                'official examination authority and is not affiliated with '
                'or endorsed by the organizations whose information may '
                'be displayed in the application.',
          ),

          const _TermsSection(
            title: '5. Notifications and Reminders',
            body:
                'ExamReady may provide reminders and notifications about '
                'important examination information. Delivery can depend on '
                'internet connectivity, device settings, operating-system '
                'restrictions, and notification permissions. Users remain '
                'responsible for checking official deadlines and notices.',
          ),

          const _TermsSection(
            title: '6. User Accounts',
            body:
                'Users are responsible for maintaining access to their '
                'account credentials and for providing accurate information '
                'when using ExamReady.',
          ),

          const _TermsSection(
            title: '7. Acceptable Use',
            body:
                'Users must not misuse ExamReady, attempt unauthorized '
                'access, interfere with the service, manipulate application '
                'data, or use the application for unlawful purposes.',
          ),

          const _TermsSection(
            title: '8. Availability',
            body:
                'Features, examination coverage, data sources, and '
                'availability may change as ExamReady develops. Some '
                'information may be unavailable until an examination '
                'authority officially publishes it.',
          ),

          const _TermsSection(
            title: '9. Changes to These Terms',
            body:
                'These Terms & Conditions may be updated when ExamReady '
                'features, services, or legal requirements change. '
                'Important changes may require users to review and accept '
                'a newer version.',
          ),

          const _TermsSection(
            title: '10. Acceptance',
            body:
                'By creating an ExamReady account, you confirm that you '
                'have read and agree to these Terms & Conditions.',
          ),

          const SizedBox(height: 16),

          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text(
              'Back',
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _TermsSection extends StatelessWidget {
  const _TermsSection({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 22,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}
