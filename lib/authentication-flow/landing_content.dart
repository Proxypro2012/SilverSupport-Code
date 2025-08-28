import 'package:flutter/material.dart';

class LandingContent extends StatelessWidget {
  const LandingContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Get started with \nSilver Support",
            style: Theme.of(
              context,
            ).textTheme.headlineLarge!.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            "Empower seniors with the support they deserve and give aspiring students a boost.",
            style: TextStyle(fontSize: 24, color: Colors.blueGrey.shade300),
          ),
        ],
      ),
    );
  }
}
