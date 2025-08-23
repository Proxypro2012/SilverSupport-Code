import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class EmailVerificationRequiredScreen extends StatelessWidget {
  const EmailVerificationRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Please verify your email to continue",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),

              // ✅ Check again after the user clicks this
              ElevatedButton(
                onPressed: () async {
                  // refresh user info from Firebase
                  await user?.reload();

                  final refreshedUser = FirebaseAuth.instance.currentUser;

                  // if verified → go to “/” (redirect guard will send to the correct dashboard)
                  if (refreshedUser != null && refreshedUser.emailVerified) {
                    if (context.mounted) {
                      context.go("/");
                    }
                    return;
                  }

                  // otherwise just resend verification email + message
                  await refreshedUser?.sendEmailVerification();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Verification email sent. Check your inbox.",
                      ),
                    ),
                  );
                },
                child: const Text("I’ve verified / Resend verification email"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
