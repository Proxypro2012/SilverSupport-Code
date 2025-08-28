import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'onboard_content.dart';

class OnboardingWrapper extends StatefulWidget {
  const OnboardingWrapper({super.key});

  @override
  State<OnboardingWrapper> createState() => _OnboardingWrapperState();
}

class _OnboardingWrapperState extends State<OnboardingWrapper> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        isDismissible: false, // ✅ Prevent tap-outside dismissal
        enableDrag: false, // ✅ Prevent swipe-down dismissal
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(42),
            topRight: Radius.circular(42),
          ),
        ),
        builder: (_) => const OnboardContent(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        elevation: 0,
      ),
      body: Image.asset(
        "assets/bg.png",
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }
}
