import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../../services/auth_service.dart';

class StudentSignupScreen extends StatefulWidget {
  const StudentSignupScreen({super.key});

  @override
  State<StudentSignupScreen> createState() => _StudentSignupScreenState();
}

class _StudentSignupScreenState extends State<StudentSignupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _authService = AuthService();
  String? _phoneNumber; // Store full phone number with country code
  bool _loading = false;
  String? _verificationId;
  final String _smsCode = '';

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSmsDialog() {
    // Navigate to full-screen verification flow handled by firebase_phone_auth_handler
    final phone = _phoneNumber ?? '';
    if (phone.isEmpty) {
      _showMessage('Please enter your phone number first.');
      return;
    }
    context.push('/verify-phone', extra: phone);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xffdfe9f3), Color(0xffe2d6f5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Back arrow
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
                      context.go(
                        "/student/login",
                      ); // fallback to home/role selector
                    }
                  },
                ),
              ),
            ),
          ),

          // White card
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
                    "Student Sign Up",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 24),

                  TextField(
                    controller: _name,
                    decoration: InputDecoration(
                      labelText: "Name",
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

                  TextField(
                    controller: _password,
                    obscureText: true,
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
                  ),
                  const SizedBox(height: 12),

                  IntlPhoneField(
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                    ),
                    initialCountryCode: 'US',
                    onChanged: (phone) {
                      _phoneNumber = phone.completeNumber;
                    },
                  ),
                  const SizedBox(height: 12),

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
                                await _authService.registerUser(
                                  email: _email.text,
                                  password: _password.text,
                                  name: _name.text,
                                  role: "student",
                                  phoneNumber: _phoneNumber,
                                  onCodeSent: (verificationId) {
                                    // Navigate to dedicated OTP screen
                                    final phone = _phoneNumber ?? '';
                                    context.push('/verify-phone', extra: phone);
                                  },
                                  onError: (error) {
                                    _showMessage(error);
                                  },
                                );
                                _showMessage(
                                  "Account created! Please check your email for verification.",
                                );
                                context.go("/student/login");
                              } catch (e) {
                                _showMessage(e.toString());
                              } finally {
                                setState(() => _loading = false);
                              }
                            },
                            child: const Text("Create Account"),
                          ),
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
