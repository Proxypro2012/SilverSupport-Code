import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight phone verification helper modeled after the project's
/// AuthService.sendSmsCode implementation. Call `sendSmsCode` to send an
/// OTP and `signInWithSmsCode` to complete verification.
class PhoneVerification {
  static final _auth = FirebaseAuth.instance;
  static String? _verificationId;
  static int? _resendToken;

  static const _kVerificationIdKey = 'authVerificationID';
  static const _kResendTokenKey = 'authResendToken';

  /// Send an SMS verification code to [phoneNumber].
  ///
  /// Callbacks:
  /// - onCodeSent() -> called when codeSent callback fires
  /// - onAutoVerified(UserCredential) -> when verificationCompleted auto signs in
  /// - onError(String) -> receives verbose error details
  static Future<void> sendSmsCode({
    required String phoneNumber,
    Function()? onCodeSent,
    Function(String details)? onError,
    Function(UserCredential credential)? onAutoVerified,
    Duration timeout = const Duration(seconds: 60),
    bool appVerificationDisabledForTesting = false,
  }) async {
    final masked = (phoneNumber.length > 4)
        ? '***${phoneNumber.substring(phoneNumber.length - 4)}'
        : phoneNumber;
    final platformInfo = kIsWeb ? 'web' : 'native';
    developer.log(
      'PhoneVerification.sendSmsCode ENTER phone=$masked timeout=${timeout.inSeconds}s testing=$appVerificationDisabledForTesting platform=$platformInfo',
    );
    final start = DateTime.now();

    try {
      // Only allow disabling app verification in debug builds.
      if (appVerificationDisabledForTesting && kDebugMode) {
        try {
          await _auth.setSettings(appVerificationDisabledForTesting: true);
          developer.log(
            'PhoneVerification: appVerificationDisabledForTesting=true',
          );
        } catch (e, st) {
          developer.log(
            'PhoneVerification: failed to set testing flag: $e',
            error: e,
            stackTrace: st,
          );
        }
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: timeout,
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          final stack = StackTrace.current;
          developer.log(
            'PhoneVerification.callback.verificationCompleted (auto) platform=$platformInfo',
            stackTrace: stack,
          );
          try {
            final result = await _auth.signInWithCredential(credential);
            if (onAutoVerified != null) onAutoVerified(result);
            developer.log(
              'PhoneVerification: verificationCompleted uid=${result.user?.uid}',
            );
            await _clearPersistedVerification();
          } catch (e, st) {
            developer.log(
              'PhoneVerification: verificationCompleted signIn error: $e',
              error: e,
              stackTrace: st,
            );
            if (onError != null) {
              onError('verificationCompleted error: ${e.toString()}\n$st');
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          final stack = StackTrace.current;
          final msg =
              'PhoneVerification.callback.verificationFailed code=${e.code} message=${e.message} platform=$platformInfo';
          developer.log(msg, error: e, stackTrace: stack);
          try {
            // ignore: avoid_print
            print('[PhoneVerification] $msg  fullException=$e\nstack:$stack');
          } catch (_) {}
          if (onError != null) {
            final details =
                '${e.code}: ${e.message} -- exception=${e.toString()}\nstack:$stack';
            onError(details);
          }
        },
        codeSent: (String verificationId, int? resendToken) async {
          final elapsed = DateTime.now().difference(start);
          _verificationId = verificationId;
          _resendToken = resendToken;
          final idPreview = verificationId.length > 8
              ? '${verificationId.substring(0, 4)}...${verificationId.substring(verificationId.length - 4)}'
              : verificationId;
          developer.log(
            'PhoneVerification.callback.codeSent verificationIdPreview=$idPreview resendToken=$resendToken elapsedMs=${elapsed.inMilliseconds}',
          );

          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_kVerificationIdKey, verificationId);
            if (resendToken != null) {
              await prefs.setInt(_kResendTokenKey, resendToken);
            }
            developer.log(
              'PhoneVerification: persisted verificationId to SharedPreferences',
            );
          } catch (e, st) {
            developer.log(
              'PhoneVerification: failed to persist verificationId: $e',
              error: e,
              stackTrace: st,
            );
          }

          if (onCodeSent != null) onCodeSent();
        },
        codeAutoRetrievalTimeout: (String verificationId) async {
          final elapsed = DateTime.now().difference(start);
          _verificationId = verificationId;
          developer.log(
            'PhoneVerification.callback.codeAutoRetrievalTimeout verificationIdPreview=${verificationId.length > 8 ? "${verificationId.substring(0, 4)}...${verificationId.substring(verificationId.length - 4)}" : verificationId} elapsedMs=${elapsed.inMilliseconds}',
          );
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_kVerificationIdKey, verificationId);
          } catch (e, st) {
            developer.log(
              'PhoneVerification: failed to persist verificationId on timeout: $e',
              error: e,
              stackTrace: st,
            );
          }
        },
      );

      developer.log(
        'PhoneVerification.sendSmsCode EXIT verifyPhoneNumber returned (async callbacks may follow)',
      );
    } catch (e, st) {
      final elapsed = DateTime.now().difference(start);
      developer.log(
        'PhoneVerification.sendSmsCode ERROR: $e elapsedMs=${elapsed.inMilliseconds}',
        error: e,
        stackTrace: st,
      );
      try {
        // ignore: avoid_print
        print('[PhoneVerification] sendSmsCode ERROR: $e\n$st');
      } catch (_) {}
      if (onError != null) onError('${e.runtimeType}: ${e.toString()}\n$st');
    }
  }

  /// Complete sign-in with the [smsCode] the user entered.
  static Future<UserCredential> signInWithSmsCode(String smsCode) async {
    developer.log(
      'PhoneVerification.signInWithSmsCode ENTER smsCodeLength=${smsCode.length}',
    );

    if (_verificationId == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final stored = prefs.getString(_kVerificationIdKey);
        if (stored != null && stored.isNotEmpty) {
          _verificationId = stored;
          developer.log(
            'PhoneVerification: restored verificationId from SharedPreferences',
          );
        }
      } catch (e, st) {
        developer.log(
          'PhoneVerification: failed to restore verificationId: $e',
          error: e,
          stackTrace: st,
        );
        try {
          // ignore: avoid_print
          print(
            '[PhoneVerification] signInWithSmsCode restore failed: $e\n$st',
          );
        } catch (_) {}
      }
    }

    if (_verificationId == null) {
      developer.log(
        'PhoneVerification.signInWithSmsCode ERROR: no verificationId available',
      );
      throw StateError('No verificationId available. Call sendSmsCode first.');
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );
      final result = await _auth.signInWithCredential(credential);
      developer.log(
        'PhoneVerification.signInWithSmsCode: signed in uid=${result.user?.uid}',
      );
      await _clearPersistedVerification();
      developer.log('PhoneVerification.signInWithSmsCode EXIT success');
      return result;
    } catch (e, st) {
      developer.log(
        'PhoneVerification.signInWithSmsCode ERROR: $e',
        error: e,
        stackTrace: st,
      );
      try {
        // ignore: avoid_print
        print('[PhoneVerification] signInWithSmsCode ERROR: $e\n$st');
      } catch (_) {}
      rethrow;
    }
  }

  static Future<void> _clearPersistedVerification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kVerificationIdKey);
      await prefs.remove(_kResendTokenKey);
      _verificationId = null;
      _resendToken = null;
      developer.log('PhoneVerification: Cleared persisted verification data');
    } catch (e, st) {
      developer.log(
        'PhoneVerification: Failed to clear persisted verification data: $e',
        error: e,
        stackTrace: st,
      );
    }
  }
}
