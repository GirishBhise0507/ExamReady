import 'package:flutter/material.dart';

import '../../../core/onboarding/onboarding_content.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    required this.onCompleted,
    super.key,
  });

  final Future<void> Function() onCompleted;

  @override
  State<OnboardingScreen> createState() =>
      _OnboardingScreenState();
}

class _OnboardingScreenState
    extends State<OnboardingScreen> {
  final PageController _pageController =
      PageController();

  int _currentPage = 0;
  bool _finishing = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNextPage() {
    if (
      _currentPage <
      onboardingPages.length - 1
    ) {
      _pageController.nextPage(
        duration:
            const Duration(
          milliseconds: 300,
        ),
        curve:
            Curves.easeInOut,
      );
    }
  }

  Future<void> _finishOnboarding() async {
    if (_finishing) {
      return;
    }

    setState(() {
      _finishing = true;
    });

    try {
      await widget.onCompleted();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _finishing = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to continue. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage =
        _currentPage ==
        onboardingPages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(
            24,
            16,
            24,
            24,
          ),
          child: Column(
            children: [
              Align(
                alignment:
                    Alignment.centerRight,
                child: TextButton(
                  onPressed:
                      _finishing
                          ? null
                          : () {
                              _pageController
                                  .animateToPage(
                                onboardingPages
                                        .length -
                                    1,
                                duration:
                                    const Duration(
                                  milliseconds:
                                      300,
                                ),
                                curve:
                                    Curves
                                        .easeInOut,
                              );
                            },
                  child:
                      const Text(
                    'Skip',
                  ),
                ),
              ),

              Expanded(
                child: PageView.builder(
                  controller:
                      _pageController,
                  itemCount:
                      onboardingPages.length,
                  onPageChanged:
                      (index) {
                    setState(() {
                      _currentPage =
                          index;
                    });
                  },
                  itemBuilder:
                      (context, index) {
                    final page =
                        onboardingPages[
                            index];

                    return Column(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .center,
                      children: [
                        Icon(
                          _iconForPage(
                            index,
                          ),
                          size: 96,
                          color:
                              Theme.of(
                                context,
                              )
                                  .colorScheme
                                  .primary,
                        ),
                        const SizedBox(
                          height: 40,
                        ),
                        Text(
                          page.title,
                          textAlign:
                              TextAlign
                                  .center,
                          style:
                              Theme.of(
                                context,
                              )
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                        ),
                        const SizedBox(
                          height: 16,
                        ),
                        Text(
                          page.description,
                          textAlign:
                              TextAlign
                                  .center,
                          style:
                              Theme.of(
                                context,
                              )
                                  .textTheme
                                  .bodyLarge,
                        ),
                      ],
                    );
                  },
                ),
              ),

              Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .center,
                children:
                    List.generate(
                  onboardingPages.length,
                  (index) =>
                      AnimatedContainer(
                    duration:
                        const Duration(
                      milliseconds: 200,
                    ),
                    width:
                        _currentPage ==
                                index
                            ? 24
                            : 8,
                    height: 8,
                    margin:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 4,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          _currentPage ==
                                  index
                              ? Theme.of(
                                  context,
                                )
                                    .colorScheme
                                    .primary
                              : Theme.of(
                                  context,
                                )
                                    .colorScheme
                                    .outlineVariant,
                      borderRadius:
                          BorderRadius
                              .circular(
                        4,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 32,
              ),

              SizedBox(
                width:
                    double.infinity,
                height: 52,
                child:
                    FilledButton(
                  onPressed:
                      _finishing
                          ? null
                          : isLastPage
                              ? _finishOnboarding
                              : _goToNextPage,
                  child:
                      _finishing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                              ),
                            )
                          : Text(
                              isLastPage
                                  ? 'Get Started'
                                  : 'Next',
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForPage(
    int index,
  ) {
    switch (index) {
      case 0:
        return Icons
            .calendar_month_rounded;

      case 1:
        return Icons.checklist_rounded;

      case 2:
        return Icons
            .notifications_active_rounded;

      default:
        return Icons.school_rounded;
    }
  }
}
