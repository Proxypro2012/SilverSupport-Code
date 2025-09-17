import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // Keep last verification details so UI can complete verification
  String? _verificationId;
  int? _resendToken;

  // Guard to prevent concurrent verifyPhoneNumber calls which can trigger
  // duplicate reCAPTCHA / web flows and confusing UI behavior.
  bool _sendInFlight = false;

  static const _kVerificationIdKey = 'authVerificationID';
  static const _kResendTokenKey = 'authResendToken';
  static const _kVerificationSentAtKey = 'authVerificationSentAt';
  static const _kPhoneKey = 'authVerificationPhone';
  static const _kBlockedUntilKey = 'authVerificationBlockedUntil';
  // Persisted short-lived lock to prevent duplicate verifyPhoneNumber calls
  // across multiple app instances / service instances. Stores a millisecond
  // timestamp representing the lock expiration time.
  static const _kSendInFlightKey = 'authSendInFlightUntil';

  /// Conservative E.164 requirement helper. Accepts numbers starting with '+'
  /// or international numbers beginning with '00' and converts them to '+'.
  /// Throws FormatException if the input doesn't look like E.164 to avoid
  /// accidental reformats in release builds.
  String _requireE164(String phone) {
    final p = phone.trim();
    if (p.startsWith('+') && p.length > 3) return p;
    if (p.startsWith('00') && p.length > 4) return '+${p.substring(2)}';
    throw FormatException(
      'Phone number must be in E.164 format (e.g. +15551234567). Provided: "$phone"',
    );
  }

  /// Send SMS verification code to [phoneNumber].
  ///
  /// Provide optional callbacks for codeSent and errors. This mirrors the
  /// PhoneAuthProvider.verifyPhoneNumber Swift API in Dart.
  Future<void> sendSmsCode({
    required String phoneNumber,
    Function()? onCodeSent,
    Function(String error)? onError,
    Function(UserCredential credential)? onAutoVerified,
    Duration timeout = const Duration(seconds: 60),
    bool appVerificationDisabledForTesting = false, // for simulator/dev only
    bool forceResend =
        false, // when true, ignore recent persisted verification and force a new send
  }) async {
    // Prevent concurrent sends
    if (_sendInFlight) {
      developer.log(
        'sendSmsCode: call ignored because another send is in-flight',
      );
      if (onError != null) onError('A send operation is already in progress.');
      return;
    }

    // Defensive persisted lock check: if another process/instance recently
    // started a send, avoid triggering another verifyPhoneNumber which can
    // cause duplicate SMS / reCAPTCHA. The persisted lock uses a short
    // expiration (2 minutes) so crashed processes won't permanently block.
    try {
      final prefs = await SharedPreferences.getInstance();
      final lockedUntil = prefs.getInt(_kSendInFlightKey);
      if (lockedUntil != null) {
        final until = DateTime.fromMillisecondsSinceEpoch(lockedUntil);
        if (until.isAfter(DateTime.now())) {
          final diff = until.difference(DateTime.now());
          developer.log(
            'sendSmsCode: persisted send-lock present, refusing send until $until',
          );
          _sendInFlight = false;
          if (onError != null)
            onError(
              'A send is already in progress. Try again in ${diff.inSeconds}s.',
            );
          return;
        } else {
          // expired: clear it and continue
          await prefs.remove(_kSendInFlightKey);
          developer.log('sendSmsCode: expired persisted send-lock cleared');
        }
      }
    } catch (e, st) {
      developer.log(
        'sendSmsCode: failed to read persisted send-lock: $e',
        error: e,
        stackTrace: st,
      );
      // Not fatal; continue and rely on in-memory guard
    }

    _sendInFlight = true;

    String normalized;
    try {
      normalized = _requireE164(phoneNumber);
    } catch (e) {
      final msg = 'sendSmsCode: invalid phone format: ${e.toString()}';
      developer.log(msg, level: 1000);
      _sendInFlight = false;
      if (onError != null) onError(msg);
      return;
    }

    final maskedPhone = (normalized.length > 4)
        ? '***${normalized.substring(normalized.length - 4)}'
        : normalized;

    // Collect some runtime context for diagnostics. Keep simple to avoid web import issues.
    final String platformInfo = kIsWeb ? 'web' : 'native';

    developer.log(
      'sendSmsCode ENTER phone=$maskedPhone timeout=${timeout.inSeconds}s testing=$appVerificationDisabledForTesting platform=$platformInfo forceResend=$forceResend',
    );
    final start = DateTime.now();

    // Persist a short-lived send lock immediately before calling verifyPhoneNumber
    // to defend against concurrent instances. Use a conservative 2 minute expiry.
    Future<void> _setPersistedSendLock() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final until = DateTime.now()
            .add(const Duration(seconds: 120))
            .millisecondsSinceEpoch;
        await prefs.setInt(_kSendInFlightKey, until);
        developer.log(
          'sendSmsCode: persisted send-lock until=${DateTime.fromMillisecondsSinceEpoch(until)}',
        );
      } catch (e, st) {
        developer.log(
          'sendSmsCode: failed to persist send-lock: $e',
          error: e,
          stackTrace: st,
        );
      }
    }

    Future<void> _clearPersistedSendLock() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_kSendInFlightKey);
        developer.log('sendSmsCode: cleared persisted send-lock');
      } catch (e, st) {
        developer.log(
          'sendSmsCode: failed to clear persisted send-lock: $e',
          error: e,
          stackTrace: st,
        );
      }
    }

    // Quick blocked-window check: if previous attempts triggered a
    // too-many-requests response, refuse further sends until the block
    // expires. This avoids immediate retry storms and surfaces a clear
    // message to the UI.
    try {
      final prefs = await SharedPreferences.getInstance();
      final blockedUntil = prefs.getInt(_kBlockedUntilKey);
      if (blockedUntil != null) {
        final until = DateTime.fromMillisecondsSinceEpoch(blockedUntil);
        if (until.isAfter(DateTime.now())) {
          final diff = until.difference(DateTime.now());
          final msg =
              'Too many requests from this device. Try again in ${diff.inMinutes} minute(s).';
          developer.log('sendSmsCode: blocked until=$until -> refusing send');
          _sendInFlight = false;
          if (onError != null) onError(msg);
          return;
        } else {
          // expired: clear the key so normal flow continues
          await prefs.remove(_kBlockedUntilKey);
          developer.log(
            'sendSmsCode: previous blocked-until expired; continuing',
          );
        }
      }
    } catch (e, st) {
      developer.log(
        'sendSmsCode: failed to check blocked-until key: $e',
        error: e,
        stackTrace: st,
      );
    }

    try {
      // De-dup: if a verificationId was recently persisted, avoid calling
      // verifyPhoneNumber can trigger duplicate SMS/reCAPTCHA flows. Check
      // SharedPreferences for a recent verification and skip re-sending unless
      // forceResend is set.
      try {
        final prefs = await SharedPreferences.getInstance();
        final storedId = prefs.getString(_kVerificationIdKey);
        final sentAt = prefs.getInt(_kVerificationSentAtKey);
        final storedPhone = prefs.getString(_kPhoneKey);
        developer.log(
          'sendSmsCode: prefs check: verificationIdPresent=${storedId != null}, sentAt=$sentAt, storedPhone=${storedPhone ?? '<none>'}',
        );
        if (!forceResend &&
            storedId != null &&
            storedId.isNotEmpty &&
            sentAt != null) {
          final age = DateTime.now().difference(
            DateTime.fromMillisecondsSinceEpoch(sentAt),
          );
          // Only consider the stored verification as relevant if it was for the
          // same phone number. If storedPhone doesn't match the phone we're
          // about to send to, proceed and issue a fresh verification.
          if (storedPhone == normalized) {
            // If a code was sent less than 2 minutes ago, assume it's still valid
            // and avoid re-sending.
            if (age.inSeconds < 120) {
              developer.log(
                'sendSmsCode: recent verificationId found for same phone (age=${age.inSeconds}s). Skipping duplicate send and invoking onCodeSent.',
              );
              _verificationId = storedId;
              if (onCodeSent != null) onCodeSent();
              return;
            }
          } else {
            developer.log(
              'sendSmsCode: persisted verification found but for a different phone (storedPhone=${storedPhone ?? '<none>'} vs normalized=$normalized). Proceeding to send a new code.',
            );
          }
        } else if (forceResend) {
          developer.log(
            'sendSmsCode: forceResend=true, ignoring recent persisted verification and proceeding to send a new code',
          );
        }
      } catch (e, st) {
        developer.log(
          'sendSmsCode: failed to check persisted verificationId: $e',
          error: e,
          stackTrace: st,
        );
      }

      // Optionally disable app verification for testing (simulator / test numbers).
      if (appVerificationDisabledForTesting && kDebugMode) {
        try {
          await _auth.setSettings(appVerificationDisabledForTesting: true);
          developer.log('sendSmsCode: appVerificationDisabledForTesting=true');
        } catch (e, st) {
          developer.log(
            'sendSmsCode: failed to set testing flag: $e',
            error: e,
            stackTrace: st,
          );
        }
      } else if (appVerificationDisabledForTesting && !kDebugMode) {
        developer.log(
          'sendSmsCode: appVerificationDisabledForTesting request ignored outside debug builds',
          level: 900,
        );
      }

      // Persist the send-lock so other instances will not trigger a parallel send.
      await _setPersistedSendLock();

      await _auth.verifyPhoneNumber(
        phoneNumber: normalized,
        timeout: timeout,
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          final stack = StackTrace.current;
          developer.log(
            'sendSmsCode.callback.verificationCompleted called (auto) platform=$platformInfo',
            stackTrace: stack,
          );
          try {
            final result = await _auth.signInWithCredential(credential);
            if (onAutoVerified != null) onAutoVerified(result);
            developer.log(
              'sendSmsCode: verificationCompleted, uid=${result.user?.uid}',
            );
            await _clearPersistedVerification();
            // Clear persisted send-lock when flow completes
            await _clearPersistedSendLock();
          } catch (e, st) {
            developer.log(
              'sendSmsCode: verificationCompleted signIn error: $e',
              error: e,
              stackTrace: st,
            );
            if (onError != null) {
              onError('verificationCompleted error: ${e.toString()}\n$st');
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) async {
          final stack = StackTrace.current;
          // Log rich details to developer log (persistent/log file) but avoid
          // printing raw PII to stdout. Device console can still show developer.log.
          final msg =
              'sendSmsCode.callback.verificationFailed code=${e.code} message=${e.message} platform=$platformInfo';
          developer.log(msg, error: e, stackTrace: stack);

          // If Firebase rate-limits this device, persist a temporary block
          // window to avoid retry storms and provide a friendly message to
          // the UI. Keep the block conservative (15 minutes).
          if (e.code == 'too-many-requests') {
            try {
              final prefs = await SharedPreferences.getInstance();
              final blockedUntil = DateTime.now()
                  .add(const Duration(minutes: 15))
                  .millisecondsSinceEpoch;
              await prefs.setInt(_kBlockedUntilKey, blockedUntil);
              developer.log(
                'sendSmsCode: received too-many-requests; blocked until=${DateTime.fromMillisecondsSinceEpoch(blockedUntil)}',
              );
            } catch (ee, st2) {
              developer.log(
                'sendSmsCode: failed to persist blocked-until: $ee',
                error: ee,
                stackTrace: st2,
              );
            }
          }

          if (onError != null) {
            final details =
                '${e.code}: ${e.message} -- exception=${e.toString()}\nstack:$stack';
            onError(details);
          }
          // Ensure persisted send-lock is removed on failure so user can retry
          await _clearPersistedSendLock();
        },
        codeSent: (String verificationId, int? resendToken) async {
          final elapsed = DateTime.now().difference(start);
          _verificationId = verificationId;
          _resendToken = resendToken;
          final idPreview = verificationId.length > 8
              ? '${verificationId.substring(0, 4)}...${verificationId.substring(verificationId.length - 4)}'
              : verificationId;
          developer.log(
            'sendSmsCode.callback.codeSent verificationIdPreview=$idPreview resendToken=$resendToken elapsedMs=${elapsed.inMilliseconds}',
          );

          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_kVerificationIdKey, verificationId);
            // Persist the normalized phone so UI can restore it after resends/app restarts
            await prefs.setString(_kPhoneKey, normalized);
            if (resendToken != null) {
              await prefs.setInt(_kResendTokenKey, resendToken);
            }
            await prefs.setInt(
              _kVerificationSentAtKey,
              DateTime.now().millisecondsSinceEpoch,
            );
            developer.log(
              'sendSmsCode: persisted verificationId and phone to SharedPreferences: verificationIdPreview=$idPreview phone=$maskedPhone',
            );
          } catch (e, st) {
            developer.log(
              'sendSmsCode: failed to persist verificationId: $e',
              error: e,
              stackTrace: st,
            );
          }

          // Clear persisted send-lock after codeSent so other instances can send later/resend
          await _clearPersistedSendLock();

          if (onCodeSent != null) onCodeSent();
        },
        codeAutoRetrievalTimeout: (String verificationId) async {
          final elapsed = DateTime.now().difference(start);
          _verificationId = verificationId;
          developer.log(
            'sendSmsCode.callback.codeAutoRetrievalTimeout verificationIdPreview=${verificationId.length > 8 ? "${verificationId.substring(0, 4)}...${verificationId.substring(verificationId.length - 4)}" : verificationId} elapsedMs=${elapsed.inMilliseconds}',
          );
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_kVerificationIdKey, verificationId);
            // Also persist phone on timeout so Verify screen can restore phone even if auto-retrieval timed out
            await prefs.setString(_kPhoneKey, normalized);
            developer.log(
              'sendSmsCode: persisted verificationId and phone on auto-retrieval timeout phone=$maskedPhone',
            );
          } catch (e, st) {
            developer.log(
              'sendSmsCode: failed to persist verificationId on timeout: $e',
              error: e,
              stackTrace: st,
            );
          }
          // Clear persisted send-lock on auto-retrieval timeout so UI can re-send
          await _clearPersistedSendLock();
        },
      );
      developer.log(
        'sendSmsCode EXIT verifyPhoneNumber returned (async callbacks may follow)',
      );
    } catch (e, st) {
      final elapsed = DateTime.now().difference(start);
      developer.log(
        'sendSmsCode error: $e elapsedMs=${elapsed.inMilliseconds}',
        error: e,
        stackTrace: st,
      );
      if (onError != null) onError('${e.runtimeType}: ${e.toString()}\n$st');
    } finally {
      _sendInFlight = false;
      // Ensure persisted lock is cleared even if an unexpected error occurs
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_kSendInFlightKey);
      } catch (e, st) {
        developer.log(
          'sendSmsCode: failed to clear persisted send-lock in finally: $e',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  /// Complete sign-in with the [smsCode] the user entered.
  Future<UserCredential> signInWithSmsCode(String smsCode) async {
    developer.log('signInWithSmsCode ENTER smsCodeLength=${smsCode.length}');
    // Restore persisted verificationId if in-memory copy is lost (app restart)
    if (_verificationId == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final stored = prefs.getString(_kVerificationIdKey);
        if (stored != null && stored.isNotEmpty) {
          _verificationId = stored;
          developer.log(
            'signInWithSmsCode: restored verificationId from SharedPreferences',
          );
        }
      } catch (e, st) {
        developer.log(
          'signInWithSmsCode: failed to restore verificationId: $e',
          error: e,
          stackTrace: st,
        );
      }
    }

    if (_verificationId == null) {
      developer.log('signInWithSmsCode ERROR: no verificationId available');
      throw StateError('No verificationId available. Call sendSmsCode first.');
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );
      final result = await _auth.signInWithCredential(credential);
      developer.log('signInWithSmsCode: signed in uid=${result.user?.uid}');

      await _clearPersistedVerification();
      developer.log('signInWithSmsCode EXIT success');
      return result;
    } catch (e, st) {
      developer.log('signInWithSmsCode ERROR: $e', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Clear persisted verificationId/resendToken
  Future<void> _clearPersistedVerification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kVerificationIdKey);
      await prefs.remove(_kResendTokenKey);
      await prefs.remove(_kPhoneKey);
      _verificationId = null;
      _resendToken = null;
      developer.log('Cleared persisted verification data');
    } catch (e, st) {
      developer.log(
        'Failed to clear persisted verification data: $e',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> createUserDoc({
    required String uid,
    required String role, // 'senior' or 'student'
    required String name,
    required String email,
    String? phone,
  }) async {
    try {
      final doc = _firestore
          .collection(role == 'senior' ? 'seniors' : 'students')
          .doc(uid);
      final Map<String, dynamic> data = {
        'uid': uid,
        'name': name,
        'email': email,
        'phone': phone ?? '',
      };
      if (role == 'student') {
        data['userdata'] = <String, dynamic>{
          'redeemable_volunteer_hours': 0,
          'current_tasks': 0,
        };
      }
      await doc.set(data);
      developer.log('createUserDoc: created user doc for $role uid=$uid');
    } catch (e, st) {
      developer.log('createUserDoc ERROR: $e', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<UserCredential?> registerUser({
    required String email,
    required String password,
    required String name,
    required String role, // "senior" or "student"
    String? phoneNumber, // <-- add phone number
    Function(String verificationId)?
    onCodeSent, // <-- callback for code sent (optional)
    Function(String error)? onError, // <-- callback for error (optional)
  }) async {
    try {
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        // Persist the provided phone number (normalized when possible)
        // so the Verify screen can display it after navigation or app restarts.
        try {
          String normalizedPhone;
          try {
            normalizedPhone = _requireE164(phoneNumber);
          } catch (_) {
            normalizedPhone = phoneNumber.trim();
          }
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_kPhoneKey, normalizedPhone);
          developer.log(
            'registerUser: persisted phone for verification: $normalizedPhone',
          );
        } catch (e, st) {
          developer.log(
            'registerUser: failed to persist phone: $e',
            error: e,
            stackTrace: st,
          );
        }
        // Don't auto-send SMS from registerUser: the UI / verify-phone screen
        // is responsible for initiating the SMS send to avoid duplicate
        // reCAPTCHA / web flows. Notify caller so they can navigate to the
        // OTP screen which will call sendSmsCode when the user presses Send.
        if (onCodeSent != null) {
          // Pass an empty verificationId — callers only use this callback to
          // navigate to the OTP UI; the actual verificationId will be set
          // when sendSmsCode publishes codeSent.
          onCodeSent('');
        }
        return null;
      } else {
        // Fallback to email signup
        final result = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final uid = result.user!.uid;
        // Create Firestore document for the user
        await createUserDoc(
          uid: uid,
          role: role,
          name: name,
          email: email,
          phone: phoneNumber,
        );
        return result;
      }
    } catch (e) {
      if (onError != null) {
        onError(e.toString());
      }
      return null;
    }
  }

  Future<bool> loginUser(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (!result.user!.emailVerified) {
      await _auth.signOut();
      return false; // Not verified
    }

    return true; // Verified
  }

  Future<void> signOut() async => await _auth.signOut();

  User? getCurrentUser() => _auth.currentUser; // ✅ added
}
