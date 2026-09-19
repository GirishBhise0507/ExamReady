class OnboardingPageDefinition {
  const OnboardingPageDefinition({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;
}

const onboardingPages = <OnboardingPageDefinition>[
  OnboardingPageDefinition(
    title: 'Stay Ahead of Every Exam',
    description: 'Keep relevant examination dates and official updates together.',
  ),
  OnboardingPageDefinition(
    title: 'Never Miss a Requirement',
    description: 'Use a contextual checklist for your selected examinations.',
  ),
  OnboardingPageDefinition(
    title: 'Get Important Updates',
    description: 'Receive source-verified changes that affect your examinations.',
  ),
];
