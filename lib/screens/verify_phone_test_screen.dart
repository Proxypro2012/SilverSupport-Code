import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:firebase_phone_auth_handler/firebase_phone_auth_handler.dart';

void testLog(String message, {String name = 'VerifyPhoneTest'}) {
  try {
    developer.log(message, name: name);
  } catch (_) {}
  try {
    print('[$name] $message');
  } catch (_) {}
}

class VerifyPhoneTestStarter extends StatefulWidget {
  const VerifyPhoneTestStarter({super.key});

  @override
  State<VerifyPhoneTestStarter> createState() => _VerifyPhoneTestStarterState();
}

class _VerifyPhoneTestStarterState extends State<VerifyPhoneTestStarter> {
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VerifyPhone Test Starter')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone (e.g. +15551234567)'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                final phone = _phoneController.text.trim();
                if (phone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter phone')));
                  return;
                }
                testLog('Starting test handler for $phone');
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => VerifyPhoneTestHandler(phoneNumber: phone)));
              },
              child: const Text('Start Test Handler'),
            ),
          ],
        ),
      ),
    );
  }
}

class VerifyPhoneTestHandler extends StatefulWidget {
  final String phoneNumber;
  const VerifyPhoneTestHandler({super.key, required this.phoneNumber});

  @override
  State<VerifyPhoneTestHandler> createState() => _VerifyPhoneTestHandlerState();
}

class _VerifyPhoneTestHandlerState extends State<VerifyPhoneTestHandler> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FirebasePhoneAuthHandler(
        phoneNumber: widget.phoneNumber,
        signOutOnSuccessfulVerification: false,
        sendOtpOnInitialize: false,
        linkWithExistingUser: false,
        autoRetrievalTimeOutDuration: const Duration(seconds: 60),
        otpExpirationDuration: const Duration(seconds: 60),
        onCodeSent: () {
          testLog('TestHandler onCodeSent');
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP sent (test)')));
        },
        onLoginSuccess: (userCredential, autoVerified) {
          testLog('TestHandler onLoginSuccess autoVerified=$autoVerified');
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login success (test)')));
        },
        onLoginFailed: (e, s) {
          testLog('TestHandler onLoginFailed: ${e.code} ${e.message}');
          setState(() => _error = e.message);
        },
        onError: (e, s) {
          testLog('TestHandler onError: $e');
          setState(() => _error = e.toString());
        },
        builder: (context, controller) {
          final isSending = controller.isSendingCode;
          final codeSent = controller.codeSent;
          return Scaffold(
            appBar: AppBar(title: const Text('VerifyPhone Test Handler')),
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Phone: ${widget.phoneNumber}'),
                  const SizedBox(height: 12),
                  if (!codeSent)
                    ElevatedButton(
                      onPressed: isSending
                          ? null
                          : () async {
                              testLog('TestHandler calling sendOTP()');
                              try {
                                await controller.sendOTP();
                                testLog('TestHandler sendOTP completed');
                              } catch (e) {
                                testLog('TestHandler sendOTP error: $e');
                                setState(() => _error = 'sendOTP error: $e');
                              }
                            },
                      child: Text(isSending ? 'Sending...' : 'Send OTP'),
                    ),
                  if (codeSent) const Text('Code sent — check SMS'),
                  const SizedBox(height: 12),
                  if (_error != null) Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
