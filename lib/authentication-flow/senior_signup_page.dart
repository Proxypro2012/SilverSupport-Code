import 'package:flutter/material.dart';
import 'onboard_content.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';
import 'package:silver_support/screens/email_verification_required_screen.dart';

class SeniorSignupPage extends StatefulWidget {
  const SeniorSignupPage({super.key});

  // Static callback to allow deep link route to trigger OTP dialog
  static void Function(String verificationId)? onDeepLinkOtp;

  @override
  State<SeniorSignupPage> createState() => _SeniorSignupPageState();
}

class _SeniorSignupPageState extends State<SeniorSignupPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  String? _phoneNumber;
  bool _isLoading = false;
  String? _error;
  bool _isVerifyingWithEmail = false;
  bool _isVerifyingWithSms = false;

  @override
  void initState() {
    super.initState();
    // Register static callback for deep link OTP
    SeniorSignupPage.onDeepLinkOtp = (verificationId) {
      // Defensive: only call setState when this State is still mounted.
      if (!mounted) return;
      setState(() {
        // store verification id if needed in future
      });
    };
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      if (mounted) {
        setState(() {
          _error = 'A Flutter error occurred: \n${details.exceptionAsString()}';
        });
      }
    };
    WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
      if (mounted) {
        setState(() {
          _error = 'A platform error occurred: \n$error';
        });
      }
      return true;
    };
  }

  @override
  void dispose() {
    // Clear static deep-link callback to avoid it being invoked after dispose.
    if (SeniorSignupPage.onDeepLinkOtp != null) {
      SeniorSignupPage.onDeepLinkOtp = null;
    }
    super.dispose();
  }

  void _onEmailVerification() async {
    setState(() {
      _isVerifyingWithEmail = true;
      _isVerifyingWithSms = false;
      _isLoading = true;
      _error = null;
    });
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final name = _nameController.text.trim();
      if (name.isEmpty || email.isEmpty || password.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isVerifyingWithEmail = false;
            _error = "Please fill in all fields.";
          });
        }
        return;
      }
      final userCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      await userCred.user?.updateDisplayName(name);
      await userCred.user?.sendEmailVerification();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isVerifyingWithEmail = false;
      });
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const EmailVerificationRequiredScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isVerifyingWithEmail = false;
          _error = e.toString();
        });
      }
    }
  }

  void _onSmsVerification() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final phone = _phoneNumber;
    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        phone == null ||
        phone.isEmpty) {
      if (mounted) setState(() => _error = "Please fill in all fields.");
      return;
    }
    if (!phone.startsWith('+')) {
      if (mounted) {
        setState(
          () => _error =
              "Phone number must start with + and country code (e.g. +1234567890)",
        );
      }
      return;
    }
    if (mounted) {
      setState(() {
        _isVerifyingWithSms = true;
        _isVerifyingWithEmail = false;
        _isLoading = true;
        _error = null;
      });
    }

    // Navigate to the full-screen verification route
    if (mounted) {
      context.push(
        '/verify-phone',
        extra: {'phone': phone, 'name': name, 'email': email, 'role': 'senior'},
      );
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isVerifyingWithSms = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final parentState = context.findAncestorStateOfType<OnboardContentState>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              "Senior Sign Up",
              style: GlassTheme.textStyle(
                size: 26,
                weight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: GlassTheme.glassTextFieldDecoration("Full name"),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: GlassTheme.glassTextFieldDecoration("Email address"),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: GlassTheme.glassTextFieldDecoration("Password"),
            ),
            const SizedBox(height: 14),
            IntlPhoneField(
              decoration: GlassTheme.glassTextFieldDecoration("Phone number"),
              initialCountryCode: 'US',
              onChanged: (phone) {
                _phoneNumber = phone.completeNumber;
              },
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading || _isVerifyingWithSms
                        ? null
                        : _onEmailVerification,
                    style: GlassTheme.glassButtonStyle(),
                    child: _isVerifyingWithEmail
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text("Verify with Email"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading || _isVerifyingWithEmail
                        ? null
                        : _onSmsVerification,
                    style: GlassTheme.glassButtonStyle(),
                    child: _isVerifyingWithSms
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text("Verify with SMS"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Center(
              child: TextButton(
                onPressed: () => parentState?.goToPage(2),
                child: Text(
                  "Already have an account? Log in",
                  style: GlassTheme.textStyle(size: 14, color: Colors.blue),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
