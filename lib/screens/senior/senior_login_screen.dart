import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';

class SeniorLoginScreen extends StatefulWidget {
  const SeniorLoginScreen({super.key});

  @override
  State<SeniorLoginScreen> createState() => _SeniorLoginScreenState();
}

class _SeniorLoginScreenState extends State<SeniorLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient background (same as RoleSelectorScreen)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xffdfe9f3), // light blue
                  Color(0xffe2d6f5), // light purple
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Back arrow in SafeArea
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () {
                    if (GoRouter.of(context).canPop()) {
                      context.pop();
                    } else {
                      context.go("/"); // fallback to home/role selector
                    }
                  },
                ),
              ),
            ),
          ),

          // White card (like RoleSelectorScreen)
          Center(
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Senior Login",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Email TextField
                  TextField(
                    controller: _email,
                    decoration: InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Password TextField
                  TextField(
                    controller: _password,
                    decoration: InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 20),

                  // Login Button (functionality preserved)
                  _loading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () async {
                              setState(() => _loading = true);
                              try {
                                final verified = await _authService.loginUser(
                                  _email.text,
                                  _password.text,
                                );
                                if (!verified) {
                                  _showMessage(
                                    "Please verify your email before logging in.",
                                  );
                                  return;
                                }
                                context.go("/dashboard/senior");
                              } catch (e) {
                                _showMessage(e.toString());
                              } finally {
                                setState(() => _loading = false);
                              }
                            },
                            child: const Text("Login"),
                          ),
                        ),

                  // Text buttons (functionality preserved)
                  TextButton(
                    child: const Text("Create an account"),
                    onPressed: () => context.go("/senior/signup"),
                  ),
                  TextButton(
                    child: const Text("Resend verification email"),
                    onPressed: () async {
                      final user = _authService.getCurrentUser();
                      if (user != null && !user.emailVerified) {
                        await user.sendEmailVerification();
                        _showMessage("Verification email sent.");
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
