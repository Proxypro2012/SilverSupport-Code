import 'package:flutter/material.dart';
import 'onboard_content.dart';
// 👈 Required for haptic feedback

class RoleSelectorPage extends StatefulWidget {
  const RoleSelectorPage({super.key});

  @override
  State<RoleSelectorPage> createState() => _RoleSelectorPageState();
}

class _RoleSelectorPageState extends State<RoleSelectorPage> {
  @override
  Widget build(BuildContext context) {
    final parentState = context.findAncestorStateOfType<OnboardContentState>();
    final selectedRole = parentState?.selectedRole;

    Widget buildRoleButton({
      required String role,
      required String label,
      required Color baseColor,
      required Color textColor,
    }) {
      final isSelected = selectedRole == role;

      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade100 : baseColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: baseColor.withOpacity(0.5)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: () {
              parentState?.selectRole(role);
              setState(() {}); // ✅ Force rebuild
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            key: ValueKey("check"),
                          )
                        : const SizedBox(key: ValueKey("empty")),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            "Who are you?",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          buildRoleButton(
            role: "senior",
            label: "I'm a Senior",
            baseColor: Colors.deepPurple.shade50,
            textColor: Colors.deepPurple,
          ),
          buildRoleButton(
            role: "student",
            label: "I'm a Student",
            baseColor: Colors.blue.shade50,
            textColor: Colors.blue.shade700,
          ),
        ],
      ),
    );
  }
}
