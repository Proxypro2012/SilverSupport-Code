import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmailVerificationRequiredScreen extends StatefulWidget {
  const EmailVerificationRequiredScreen({super.key});

  @override
  State<EmailVerificationRequiredScreen> createState() =>
      _EmailVerificationRequiredScreenState();
}

class _EmailVerificationRequiredScreenState
    extends State<EmailVerificationRequiredScreen> {
  String? _smsCode;
  String? _verificationId;
  String? _error;
  bool _verifying = false;
  String? _phoneNumber;
  String? _otpError;

  void showSmsDialog(String phoneNumber) {
    // Navigate to the dedicated full-screen OTP flow. Pass phone via extra payload.
    final phone = phoneNumber.isNotEmpty ? phoneNumber : '';
    context.push('/verify-phone', extra: phone);
  }

  void showEmailDialog() {
    _showEmailVerificationDialog();
  }

  Future<void> _showEmailVerificationDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Email Verification'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Check your email for a verification link.'),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _verifying
                      ? null
                      : () async {
                          setState(() => _verifying = true);
                          await FirebaseAuth.instance.currentUser?.reload();
                          final refreshedUser = FirebaseAuth.instance.currentUser;
                          if (refreshedUser != null && refreshedUser.emailVerified) {
                            Navigator.of(context).pop();
                            final firestore = FirebaseFirestore.instance;
                            final seniorDoc = await firestore.collection('seniors').doc(refreshedUser.uid).get();
                            final studentDoc = await firestore.collection('students').doc(refreshedUser.uid).get();
                            if (seniorDoc.exists) {
                              if (mounted) context.go('/dashboard/senior');
                            } else if (studentDoc.exists) {
                              if (mounted) context.go('/dashboard/student');
                            } else {
                              if (mounted) context.go('/');
                            }
                          } else {
                            setDialogState(() => _error = 'Please verify your email before continuing.');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please verify your email before continuing.')),
                            );
                          }
                          setState(() => _verifying = false);
                        },
                  child: _verifying ? const CircularProgressIndicator() : const Text("I've Verified"),
                ),
                TextButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.currentUser?.sendEmailVerification();
                    setDialogState(() => _error = 'Verification email resent.');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Verification email resent.')),
                    );
                  },
                  child: const Text('Resend Email'),
                ),
                TextButton(
                  onPressed: _verifying
                      ? null
                      : () async {
                          // Sign out and return to role selector (clears the redirect guard)
                          try {
                            await FirebaseAuth.instance.signOut();
                          } catch (_) {}
                          if (!mounted) return;
                          // Use go to replace the stack and avoid being redirected back
                          context.go('/');
                        },
                  child: const Text('Cancel & Sign out'),
                ),
              ],
            );
          },
        );
      },
    );
  }

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
                "Please verify your email or phone to continue",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _verifying ? null : showEmailDialog,
                    child: const Text('Verify with Email'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _verifying ? null : () => showSmsDialog(user?.phoneNumber ?? ''),
                    child: const Text('Verify with SMS'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () async {
                  try {
                    await FirebaseAuth.instance.signOut();
                  } catch (_) {}
                  if (!mounted) return;
                  context.go('/');
                },
                child: const Text('Cancel and Sign out', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
