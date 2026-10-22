import 'package:flutter/material.dart';
import 'package:payflex/core/theme.dart';
import 'package:payflex/screens/login.dart';
import 'package:payflex/screens/signup.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<Map<String, String>> _onboardingData = [
    {
      'title': 'Instant Transfers',
      'description':
          'Send and receive money seamlessly with low fees and instant processing.',
      'image': 'assets/images/icon1.gif',
    },
    {
      'title': 'Bills & Telecom Utilities',
      'description':
          'Recharge airtime, buy data bundles, and pay utility bills in a few taps.',
      'image': 'assets/images/icon2.gif',
    },
    {
      'title': 'Multi-Currency Exchange',
      'description':
          'Hold and exchange NGN, USD, GBP, and EUR at competitive real-time rates.',
      'image': 'assets/images/icon3.gif',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onSkip() {
    _pageController.animateToPage(
      _onboardingData.length - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onNext() {
    if (_currentIndex < _onboardingData.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Navigate to Login/Home screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentIndex == _onboardingData.length - 1;

    return Scaffold(
      backgroundColor: PayFlexColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Bar with Skip Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Align(
                alignment: Alignment.centerRight,
                child: AnimatedOpacity(
                  opacity: isLastPage ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: TextButton(
                    onPressed: isLastPage ? null : _onSkip,
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: PayFlexColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Swipable Pages Carousel
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _onboardingData.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (context, index) {
                  final item = _onboardingData[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Image Display
                        Container(
                          height: 280,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            image: DecorationImage(
                              image: AssetImage(item['image']!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),

                        // Title Text
                        Text(
                          item['title']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: PayFlexColors.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Description Text
                        Text(
                          item['description']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFA0A0A0),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Navigation (Dots Indicator & Next Button)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Dots Indicator
                  Row(
                    children: List.generate(_onboardingData.length, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 6),
                        height: 8,
                        width: _currentIndex == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentIndex == index
                              ? const Color(0xFF00E676)
                              : const Color(0xFF2C2C2C),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),

                  // Next / Get Started Action Button
                  ElevatedButton(
                    onPressed: _onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isLastPage ? 'Get Started' : 'Next',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          isLastPage
                              ? Icons.check_circle_rounded
                              : Icons.arrow_forward_rounded,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
