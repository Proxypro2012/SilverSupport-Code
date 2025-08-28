import 'package:flutter/material.dart';
import 'landing_content.dart';
import 'role_selector_page.dart';
import 'senior_login_page.dart';
import 'student_login_page.dart';
import 'senior_signup_page.dart';
import 'student_signup_page.dart';

class OnboardContent extends StatefulWidget {
  const OnboardContent({super.key});

  @override
  State<OnboardContent> createState() => OnboardContentState();
}

class OnboardContentState extends State<OnboardContent> {
  late PageController _pageController;

  final List<Widget> _pages = [
    const LandingContent(),
    RoleSelectorPage(),
    const SeniorLoginPage(),
    const StudentLoginPage(),
    const SeniorSignupPage(),
    const StudentSignupPage(),
  ];

  int _currentPage = 0;
  String? selectedRole;

  final double _baseHeight = 460;
  final double _heightIncrement = 100;
  final double _maxHeight = 560;

  @override
  void initState() {
    super.initState();
    _pageController = PageController()
      ..addListener(() {
        setState(() {
          final page = _pageController.page?.clamp(0, _pages.length - 1) ?? 0;
          _currentPage = page.round();
        });
      });
  }

  void nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void selectRole(String role) {
    setState(() => selectedRole = role);
  }

  void handleButtonTap() {
    switch (_currentPage) {
      case 0:
        nextPage(); // → Role Selector
        break;
      case 1:
        if (selectedRole == "senior") {
          goToPage(2);
        } else if (selectedRole == "student") {
          goToPage(3);
        }
        break;
      case 2:
        goToPage(4); // Senior → Signup
        break;
      case 3:
        goToPage(5); // Student → Signup
        break;
      case 4:
        goToPage(2); // Senior → Login
        break;
      case 5:
        goToPage(3); // Student → Login
        break;
      default:
        nextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _pageController.hasClients
        ? (_pageController.page ?? 0).clamp(0, _pages.length - 1)
        : 0;

    final double height = (_baseHeight + progress * _heightIncrement).clamp(
      _baseHeight,
      _maxHeight,
    );
    final double buttonWidth = 140 + progress * 80;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(42),
          topRight: Radius.circular(42),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 16),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    children: _pages,
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: handleButtonTap,
                  child: Container(
                    width: buttonWidth,
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      gradient: const LinearGradient(
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                        stops: [0.4, 0.8],
                        colors: [
                          Color.fromARGB(255, 239, 104, 80),
                          Color.fromARGB(255, 139, 33, 146),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: DefaultTextStyle(
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              "Continue",
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
