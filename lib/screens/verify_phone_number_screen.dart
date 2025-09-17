import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../services/auth_service.dart';
import 'package:firebase_core/firebase_core.dart';

void verboseLog(String message, {String name = 'VerifyPhone'}) {
  try {
    developer.log(message, name: name);
  } catch (_) {}
  try {
    // keep a visible stdout fallback for device logs
    // ignore: avoid_print
    print('[$name] $message');
  } catch (_) {}
}

class VerifyPhoneNumberScreen extends StatefulWidget {
  final String phoneNumber;
  final bool appVerificationDisabledForTesting;
  // Optional metadata passed from the signup flow so we can create the
  // Firestore user document after successful phone sign-in.
  final String? name;
  final String? email;
  final String? role; // 'student' or 'senior'

  // Static callback to be invoked by the app router when a /link deep link
  // returns a verificationId (reCAPTCHA web flow). This lets the running
  // OTP screen pick up the verificationId and avoid showing a black "link"
  // landing page.
  static void Function(String verificationId)? onDeepLinkOtp;

  const VerifyPhoneNumberScreen({
    super.key,
    required this.phoneNumber,
    this.appVerificationDisabledForTesting = false,
    this.name,
    this.email,
    this.role,
  });

  @override
  State<VerifyPhoneNumberScreen> createState() =>
      _VerifyPhoneNumberScreenState();
}

class _VerifyPhoneNumberScreenState extends State<VerifyPhoneNumberScreen>
    with WidgetsBindingObserver {
  final _authService = AuthService();

  String? _error;
  String _displayPhone = '';
  bool isKeyboardVisible = false;
  late final ScrollController _scrollController;

  // Flow state
  bool _isSending = false;
  bool _codeSent = false;
  bool _isVerifying = false;

  // Countdown for OTP expiry / resend UI
  static const _otpTimeout = Duration(seconds: 60);
  Timer? _countdownTimer;
  int _secondsLeft = 0;

  // Diagnostics / stuck detection
  bool _autoRetryTriggered = false;
  Timer? _autoRetryTimer;
  Timer? _stuckTimer;
  bool _stuck = false;

  static const _kVerificationIdKey = 'authVerificationID';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addObserver(this);
    verboseLog('initState');

    // Ensure _displayPhone has a synchronous initial value so build() never
    // encounters an uninitialized late variable. The async restore below
    // may override this with a persisted, normalized phone.
    _displayPhone = widget.phoneNumber;

    // Register deep-link callback so /link route can notify this screen.
    VerifyPhoneNumberScreen.onDeepLinkOtp = (verificationId) async {
      try {
        verboseLog(
          'Deep-link OTP received verificationIdPreview=${verificationId.length > 8 ? '${verificationId.substring(0, 4)}...' : verificationId}',
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kVerificationIdKey, verificationId);
        if (!mounted) return;
        setState(() {
          _isSending = false;
          _codeSent = true;
          _error = null;
        });
        // Start countdown on deep-link because verification completed via web flow
        _startCountdown();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification complete — please enter the code'),
          ),
        );
      } catch (e) {
        verboseLog('Error handling deep-link OTP: $e');
      }
    };

    // If verification was already started (codeSent persisted), restore UI state
    (() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final stored = prefs.getString(_kVerificationIdKey);
        // Attempt to restore persisted phone as well so UI can show the number
        final storedPhone = prefs.getString('authVerificationPhone');
        // Start with the widget-provided phone, then override with any
        // persisted normalized phone found in SharedPreferences.
        _displayPhone = widget.phoneNumber;
        if (storedPhone != null && storedPhone.isNotEmpty) {
          _displayPhone = storedPhone;
        }
        verboseLog(
          'Restored persisted phone from prefs: storedPhone=${storedPhone ?? '<none>'} -> displayPhone=$_displayPhone',
        );
        if (stored != null && stored.isNotEmpty) {
          verboseLog(
            'Found persisted verificationId on init — assuming code was sent',
          );
          if (mounted) {
            setState(() {
              // Mark that a verification exists so UI will show OTP entry, but
              // do NOT start the resend countdown automatically. Countdown
              // should only begin when the user explicitly presses Send OTP
              // or when the deep-link arrives.
              _isSending = false;
              _codeSent = true;
            });
          }
          // Note: do not call _startCountdown() here to avoid duplicate timers
        }
      } catch (e) {
        verboseLog('Failed to restore persisted verificationId on init: $e');
      }
    })();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _autoRetryTimer?.cancel();
    _stuckTimer?.cancel();
    _scrollController.dispose();
    verboseLog('dispose');

    // Clear static registration so it isn't invoked after this screen is gone
    if (VerifyPhoneNumberScreen.onDeepLinkOtp != null) {
      VerifyPhoneNumberScreen.onDeepLinkOtp = null;
    }

    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _secondsLeft = _otpTimeout.inSeconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _secondsLeft = (_secondsLeft - 1).clamp(0, _otpTimeout.inSeconds);
      });
      if (_secondsLeft <= 0) {
        _countdownTimer?.cancel();
      }
    });
  }

  void _scheduleAutoRetry() {
    if (_autoRetryTriggered) return;
    _autoRetryTriggered = true;
    verboseLog('Scheduling auto-retry in 6s if still sending');
    _autoRetryTimer = Timer(const Duration(seconds: 6), () async {
      verboseLog('Auto-retry timer fired');
      if (!mounted) return;
      try {
        if (_isSending && !_codeSent) {
          verboseLog('Auto-retry: calling sendSmsCode again');
          await _sendSms(
            allowTesting: widget.appVerificationDisabledForTesting,
          );
          verboseLog('Auto-retry: sendSmsCode returned');
        }
      } catch (e) {
        verboseLog('Auto-retry failed: $e');
        if (mounted) setState(() => _error = 'Auto-retry failed: $e');
      }
    });
  }

  void _scheduleStuckTimer() {
    if (_stuckTimer != null || _stuck) return;
    verboseLog('Scheduling stuck-detection timer (20s)');
    _stuckTimer = Timer(const Duration(seconds: 20), () {
      verboseLog('Stuck-detection timer fired');
      if (!mounted) return;
      setState(() {
        _stuck = true;
        _error = 'Sending appears stuck. You can retry or cancel.';
      });
    });
  }

  void _cancelStuckTimer() {
    _stuckTimer?.cancel();
    _stuckTimer = null;
    if (_stuck) {
      _stuck = false;
      _error = null;
    }
  }

  Future<void> _sendSms({
    bool allowTesting = false,
    bool forceResend = false,
  }) async {
    // If neither the widget-provided phone nor the in-memory display phone
    // are available, attempt to restore a persisted normalized phone before
    // failing. This fixes cases where the Verify screen was opened without
    // a phone in the widget and the persisted phone was not yet loaded.
    if ((_displayPhone.trim().isEmpty) && (widget.phoneNumber.trim().isEmpty)) {
      verboseLog(
        'No phone in memory/widget — attempting to restore persisted phone from prefs',
      );
      try {
        final prefs = await SharedPreferences.getInstance();
        final storedPhone = prefs.getString('authVerificationPhone');
        if (storedPhone != null && storedPhone.isNotEmpty) {
          _displayPhone = storedPhone;
          verboseLog('Restored phone from prefs: $_displayPhone');
          if (mounted) setState(() {});
        } else {
          verboseLog('No persisted phone found in prefs');
        }
      } catch (e) {
        verboseLog('Failed to read persisted phone: $e');
      }
    }

    final phoneToSend = (_displayPhone.trim().isNotEmpty)
        ? _displayPhone.trim()
        : widget.phoneNumber.trim();
    if (phoneToSend.isEmpty) {
      if (mounted) setState(() => _error = 'Phone number is empty.');
      return;
    }
    setState(() {
      _isSending = true;
      _error = null;
      _codeSent = false;
    });

    // start stuck detection and auto-retry
    _scheduleAutoRetry();
    _scheduleStuckTimer();

    try {
      await _authService.sendSmsCode(
        phoneNumber: phoneToSend,
        appVerificationDisabledForTesting: allowTesting,
        forceResend: forceResend,
        onCodeSent: () {
          verboseLog('AuthService: codeSent');
          // Cancel any pending auto-retry to avoid duplicate sends
          _autoRetryTimer?.cancel();
          _autoRetryTimer = null;
          _autoRetryTriggered = false;

          if (mounted) {
            setState(() {
              _isSending = false;
              _codeSent = true;
            });
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('OTP sent')));
            _startCountdown();
            _cancelStuckTimer();
          }
        },
        onAutoVerified: (credential) async {
          // Auto verified (Android). Route the user.
          verboseLog('AuthService: autoVerified uid=${credential.user?.uid}');
          await _handleSuccessfulSignIn(credential.user?.uid);
        },
        onError: (err) {
          verboseLog('AuthService:onError: $err');
          if (mounted) {
            setState(() {
              _isSending = false;
              _error = err;
            });
          }
        },
      );
    } catch (e) {
      verboseLog('sendSms caught: $e');
      if (mounted) {
        setState(() {
          _isSending = false;
          _error = e.toString();
        });
      }
    } finally {
      // ensure we clear stuck timers if code was sent
      if (_codeSent) {
        _cancelStuckTimer();
      }
    }
  }

  Future<void> _verifyOtp(String smsCode) async {
    setState(() {
      _isVerifying =
          true; // used so analyzer doesn't complain about unused field
      _error = null;
    });
    try {
      final cred = await _authService.signInWithSmsCode(smsCode);
      verboseLog('signInWithSmsCode success uid=${cred.user?.uid}');
      await _handleSuccessfulSignIn(cred.user?.uid);
    } catch (e) {
      verboseLog('signInWithSmsCode error: $e');
      if (mounted) {
        setState(() => _error = 'Verification failed: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _handleSuccessfulSignIn(String? uid) async {
    if (uid == null) return;
    final firestore = FirebaseFirestore.instance;
    try {
      final seniorDoc = await firestore.collection('seniors').doc(uid).get();
      final studentDoc = await firestore.collection('students').doc(uid).get();
      if (seniorDoc.exists) {
        if (mounted) context.go('/dashboard/senior');
      } else if (studentDoc.exists) {
        if (mounted) context.go('/dashboard/student');
      } else {
        // No existing user doc found. If the signup flow provided metadata
        // (role/name/email) create the Firestore doc and route accordingly.
        try {
          final providedRole = widget.role;
          if (providedRole != null &&
              (providedRole == 'student' || providedRole == 'senior')) {
            // Prefer provided name/email, fall back to Firebase user fields.
            final currentUser = _authService.getCurrentUser();
            // Defensive check: ensure the client is actually signed in and the
            // UID matches the UID returned by the phone sign-in flow. If the
            // client isn't authenticated (or App Check blocked the request), a
            // subsequent Firestore write will be rejected with PERMISSION_DENIED.
            if (currentUser == null || currentUser.uid != uid) {
              verboseLog(
                'Auth mismatch before createUserDoc: currentUser=${currentUser?.uid} expected=$uid',
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Authentication state invalid. Please try signing in again.',
                    ),
                  ),
                );
                context.go('/');
              }
              return;
            }
            final resolvedName = widget.name ?? currentUser.displayName ?? '';
            final resolvedEmail = widget.email ?? currentUser.email ?? '';
            try {
              await _authService.createUserDoc(
                uid: uid,
                role: providedRole,
                name: resolvedName,
                email: resolvedEmail,
                phone: widget.phoneNumber,
              );
            } on FirebaseException catch (fe) {
              verboseLog(
                'createUserDoc FirebaseException: code=${fe.code} message=${fe.message}',
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Failed to create user record: ${fe.message ?? fe.code}. This may be caused by Firestore security rules or App Check enforcement.',
                    ),
                  ),
                );
              }
              return;
            } catch (e) {
              verboseLog('createUserDoc failed: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to create user record: $e')),
                );
              }
              return;
            }
            if (mounted) {
              if (providedRole == 'student') {
                context.go('/dashboard/student');
              } else {
                context.go('/dashboard/senior');
              }
            }
            return;
          }
        } catch (e) {
          verboseLog('Failed to create user doc after phone sign-in: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to create user record: $e')),
            );
          }
        }

        // If unable to determine role or creation failed, route to root.
        if (mounted) context.go('/');
      }
    } catch (e) {
      verboseLog('role lookup failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to determine role: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      double pinBoxSize = (MediaQuery.of(context).size.width - 80) / 6;
      pinBoxSize = pinBoxSize.clamp(40.0, 72.0);

      final defaultPinTheme = PinTheme(
        width: pinBoxSize,
        height: pinBoxSize,
        textStyle: const TextStyle(
          fontSize: 20,
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
      );

      return Scaffold(
        appBar: AppBar(
          title: const Text('Verify phone'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _isSending
                  ? const SizedBox.shrink()
                  : (_codeSent
                        ? TextButton(
                            onPressed: _secondsLeft <= 0
                                ? () async {
                                    verboseLog('Resend tapped (appbar)');
                                    setState(() => _error = null);
                                    await _sendSms(
                                      allowTesting: widget
                                          .appVerificationDisabledForTesting,
                                      forceResend: true,
                                    );
                                  }
                                : null,
                            child: Text(
                              _secondsLeft <= 0 ? 'Resend' : '$_secondsLeft s',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 16,
                              ),
                            ),
                          )
                        : const SizedBox.shrink()),
            ),
          ],
        ),
        // No floating action button: primary Send OTP control is in AppBar
        body: _isSending
            ? _stuck
                  ? _buildStuckUI()
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 8),
                        const Center(child: CircularProgressIndicator()),
                        const SizedBox(height: 24),
                        const Center(
                          child: Text(
                            'Sending OTP',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text(
                            'If sending appears stuck, you can retry. Detailed diagnostics are printed to the device logs.',
                            textAlign: TextAlign.center,
                            style: GlassTheme.textStyle(
                              size: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () async {
                                verboseLog('Retry send tapped while isSending');
                                // Reset auto-retry guard so schedule can run again
                                _autoRetryTriggered = false;
                                _autoRetryTimer?.cancel();
                                _autoRetryTimer = null;
                                await _sendSms(
                                  allowTesting:
                                      widget.appVerificationDisabledForTesting,
                                  forceResend: true,
                                );
                              },
                              child: const Text('Retry'),
                            ),
                            const SizedBox(width: 12),
                            TextButton(
                              onPressed: () async {
                                verboseLog('Cancel tapped while isSending');
                                if (mounted) {
                                  setState(
                                    () => _error = 'Send cancelled by user.',
                                  );
                                }
                              },
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                      ],
                    )
            : ListView(
                padding: const EdgeInsets.all(20),
                controller: _scrollController,
                children: [
                  // Prominent top Send OTP button so users don't have to rely on AppBar actions
                  if (!_codeSent)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: ElevatedButton(
                        onPressed: _isSending
                            ? null
                            : () async {
                                verboseLog('Send OTP (top) pressed');
                                setState(() => _error = null);
                                await _sendSms(
                                  allowTesting:
                                      widget.appVerificationDisabledForTesting,
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Send OTP',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  Text(
                    'We will send an SMS with a verification code to $_displayPhone',
                    style: GlassTheme.textStyle(size: 16),
                  ),
                  const SizedBox(height: 10),
                  const Divider(),

                  // Removed duplicate in-body white "Send OTP" button — keep the prominent blue button above.
                  // Keep a small spacer to maintain layout consistency when no code has been sent.
                  if (!_codeSent) const SizedBox(height: 12),
                  const SizedBox(height: 15),
                  const Text(
                    'Enter OTP',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 15),
                  Pinput(
                    length: 6,
                    defaultPinTheme: defaultPinTheme,
                    autofocus: true,
                    onCompleted: (pin) async {
                      verboseLog('Pinput completed with pin=$pin');
                      setState(() => _error = null);
                      await _verifyOtp(pin);
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),

                  if (kDebugMode) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Debug',
                      style: GlassTheme.textStyle(
                        size: 14,
                        weight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'appVerificationDisabledForTesting = ${widget.appVerificationDisabledForTesting}',
                      style: GlassTheme.textStyle(size: 12),
                    ),
                  ],
                ],
              ),
      );
    } catch (e, st) {
      verboseLog('Layout/build exception: $e\n$st');
      return Scaffold(
        appBar: AppBar(
          title: const Text('Verify phone'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 12),
                const Text(
                  'A rendering error occurred. Please restart the flow.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    verboseLog('User pressed restart after layout exception');
                    if (mounted) Navigator.of(context).maybePop();
                  },
                  child: const Text('Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildStuckUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 56,
              color: Colors.orange,
            ),
            const SizedBox(height: 12),
            Text(
              'Sending appears stuck. You can retry sending the code, cancel and re-enter your phone number, or go back.',
              textAlign: TextAlign.center,
              style: GlassTheme.textStyle(size: 15, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    verboseLog('Stuck UI: Retry tapped');
                    try {
                      // Reset auto-retry guard
                      _autoRetryTriggered = false;
                      _autoRetryTimer?.cancel();
                      _autoRetryTimer = null;
                      await _sendSms(
                        allowTesting: widget.appVerificationDisabledForTesting,
                        forceResend: true,
                      );
                      setState(() => _error = null);
                      _cancelStuckTimer();
                    } catch (e) {
                      verboseLog('Stuck UI: resend failed: $e');
                      setState(() => _error = 'Resend failed: $e');
                    }
                  },
                  child: const Text('Retry'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () {
                    verboseLog(
                      'Stuck UI: Cancel tapped - popping to previous screen',
                    );
                    if (mounted) Navigator.of(context).maybePop();
                  },
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
