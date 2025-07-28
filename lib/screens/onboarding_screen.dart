import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quick_photo_sorter/services/app_state.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  static const routeName = '/onboarding';

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  final _pages = [
    {
      'image': 'assets/onboarding_panel.png',
      'gradient': [Color(0xFFB57AF2), Color(0xFFB57AF2)],
    },
    {
      'image': 'assets/onboarding_mode1.png',
      'gradient': [Color(0xFF875dc4), Color(0xFF795bc6)],
    },
    {
      'image': 'assets/onboarding_mode2.png',
      'gradient': [Color(0xFFfff9f4), Color(0xFFfff9f4)],
    },
    {
      'image': 'assets/onboarding_mode3.png',
      'gradient': [Color(0xFF6456a0), const Color(0xFF54488f)],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final current = _pages[_page];
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: current['gradient'] as List<Color>,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _buildPage(_pages[i]),
              ),
            ),
            // Page indicator with margin to avoid bottomSheet overlap
            Container(
              margin: const EdgeInsets.only(
                bottom: 80,
              ), // Space for bottomSheet
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: SmoothPageIndicator(
                controller: _controller,
                count: _pages.length,
                effect: WormEffect(
                  dotColor: Colors.white.withOpacity(0.5),
                  activeDotColor: Colors.white,
                  dotHeight: 12,
                  dotWidth: 12,
                  spacing: 16,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: _page == _pages.length - 1
          ? Container(
              width: double.infinity,
              height: 60,
              child: TextButton(
                onPressed: () {
                  context.read<AppState>().completeOnboarding();
                },
                style: TextButton.styleFrom(backgroundColor: Colors.white),
                child: Text(
                  'Get Started',
                  style: TextStyle(
                    fontSize: 20,
                    color: const Color.fromARGB(255, 138, 70, 216),
                  ),
                ),
              ),
            )
          : Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => _controller.jumpToPage(_pages.length - 1),
                    child: Text('Skip', style: TextStyle(fontSize: 18)),
                  ),
                  TextButton(
                    onPressed: () => _controller.nextPage(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.ease,
                    ),
                    child: Text('Next', style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPage(Map data) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          data['image'],
          fit: BoxFit.contain,
          width: MediaQuery.of(context).size.width * 1,
        ),
      ],
    );
  }
}
