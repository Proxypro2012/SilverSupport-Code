import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'content_model.dart';

class Onbording extends StatefulWidget {
  const Onbording({Key? key}) : super(key: key);

  @override
  OnbordingState createState() => OnbordingState();
}

class OnbordingState extends State<Onbording> {
  int currentIndex = 0;
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Onboarding Pages
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: contents.length,
              onPageChanged: (int index) {
                setState(() {
                  currentIndex = index;
                });
              },
              itemBuilder: (_, i) {
                final isVisible = i == currentIndex;
                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  opacity: isVisible ? 1.0 : 0.0,
                  curve: Curves.easeInOut,
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Image.asset(contents[i].image, height: 300),
                        const SizedBox(height: 30),
                        Text(
                          contents[i].title,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          contents[i].discription,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Dot Indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              contents.length,
              (index) => buildDot(index, context),
            ),
          ),

          // Navigation Button
          Container(
            height: 60,
            width: double.infinity,
            margin: const EdgeInsets.all(40),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () async {
                if (currentIndex == contents.length - 1) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('seenOnboarding', true);
                  if (!mounted) return;
                  context.go("/"); // Navigate to RoleSelectorScreen
                } else {
                  _controller.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
              child: Text(
                currentIndex == contents.length - 1 ? "Continue" : "Next",
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDot(int index, BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: 10,
      width: currentIndex == index ? 25 : 10,
      margin: const EdgeInsets.only(right: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).primaryColor,
      ),
    );
  }
}
