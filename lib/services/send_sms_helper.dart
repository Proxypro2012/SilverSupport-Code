import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class SendSmsHelper {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _verificationId;
  int? _resendToken;

  // Use the same keys as AuthService so persisted state is interoperable.
  static const _kVerificationIdKey = 'authVerificationID';
  static const _kResendTokenKey = 'authResendToken';

  /// Normalize a phone number to E.164. This helper is conservative and
  /// requires callers to pass a number already in E.164 (starting with '+').
  /// This avoids accidental formatting assumptions in release builds.
  String _requireE164(String phone) {
    final p = phone.trim();
    if (p.startsWith('+') && p.length > 3) return p;
    if (p.startsWith('00') && p.length > 4) return '+${p.substring(2)}';
    throw FormatException(
      'Phone number must be in E.164 format (e.g. +15551234567). Provided: "$phone"',
    );
  }

  /// Send SMS verification code to [phoneNumber].
  /// Mirrors the project's AuthService.sendSmsCode behaviour (diagnostic logs,
  /// persisted verificationId/resendToken, testing flag support).
  Future<void> sendSmsCode({
    required String phoneNumber,
    Function()? onCodeSent,
    Function(String error)? onError,
    Function(UserCredential credential)? onAutoVerified,
    Duration timeout = const Duration(seconds: 60),
    bool appVerificationDisabledForTesting = false, // for simulator/dev only
  }) async {
    String normalized;
    try {
      normalized = _requireE164(phoneNumber);
    } catch (e) {
      final msg =
          'SendSmsHelper.sendSmsCode: invalid phone format: ${e.toString()}';
      developer.log(msg, level: 1000);
      if (onError != null) onError(msg);
      return;
    }

    final maskedPhone = (normalized.length > 4)
        ? '***${normalized.substring(normalized.length - 4)}'
        : normalized;
    final start = DateTime.now();

    developer.log(
      'SendSmsHelper.sendSmsCode ENTER phone=$maskedPhone timeout=${timeout.inSeconds}s testing=$appVerificationDisabledForTesting',
    );

    try {
      if (appVerificationDisabledForTesting && kDebugMode) {
        try {
          await _auth.setSettings(appVerificationDisabledForTesting: true);
          developer.log(
            'SendSmsHelper: appVerificationDisabledForTesting=true',
          );
        } catch (e, st) {
          developer.log(
            'SendSmsHelper: failed to set testing flag: $e',
            error: e,
            stackTrace: st,
          );
        }
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: normalized,
        timeout: timeout,
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          final stack = StackTrace.current;
          developer.log(
            'SendSmsHelper.callback.verificationCompleted (auto)',
            stackTrace: stack,
          );
          try {
            final result = await _auth.signInWithCredential(credential);
            if (onAutoVerified != null) onAutoVerified(result);
            developer.log(
              'SendSmsHelper: verificationCompleted uid=${result.user?.uid}',
            );
            await _clearPersistedVerification();
          } catch (e, st) {
            developer.log(
              'SendSmsHelper: verificationCompleted signIn error: $e',
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
              'SendSmsHelper.callback.verificationFailed code=${e.code} message=${e.message}';
          developer.log(msg, error: e, stackTrace: stack);
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
            'SendSmsHelper.callback.codeSent verificationIdPreview=$idPreview resendToken=$resendToken elapsedMs=${elapsed.inMilliseconds}',
          );

          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_kVerificationIdKey, verificationId);
            if (resendToken != null) {
              await prefs.setInt(_kResendTokenKey, resendToken);
            }
            developer.log(
              'SendSmsHelper: persisted verificationId to SharedPreferences',
            );
          } catch (e, st) {
            developer.log(
              'SendSmsHelper: failed to persist verificationId: $e',
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
            'SendSmsHelper.callback.codeAutoRetrievalTimeout verificationIdPreview=${verificationId.length > 8 ? "${verificationId.substring(0, 4)}...${verificationId.substring(verificationId.length - 4)}" : verificationId} elapsedMs=${elapsed.inMilliseconds}',
          );
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_kVerificationIdKey, verificationId);
          } catch (e, st) {
            developer.log(
              'SendSmsHelper: failed to persist verificationId on timeout: $e',
              error: e,
              stackTrace: st,
            );
          }
        },
      );

      developer.log(
        'SendSmsHelper.sendSmsCode EXIT verifyPhoneNumber returned (async callbacks may follow)',
      );
    } catch (e, st) {
      final elapsed = DateTime.now().difference(start);
      developer.log(
        'SendSmsHelper.sendSmsCode error: $e elapsedMs=${elapsed.inMilliseconds}',
        error: e,
        stackTrace: st,
      );
      if (onError != null) onError('${e.runtimeType}: ${e.toString()}\n$st');
    }
  }

  /// Complete sign-in with the [smsCode] the user entered.
  Future<UserCredential> signInWithSmsCode(String smsCode) async {
    developer.log(
      'SendSmsHelper.signInWithSmsCode ENTER smsCodeLength=${smsCode.length}',
    );

    if (_verificationId == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final stored = prefs.getString(_kVerificationIdKey);
        if (stored != null && stored.isNotEmpty) {
          _verificationId = stored;
          developer.log(
            'SendSmsHelper: restored verificationId from SharedPreferences',
          );
        }
      } catch (e, st) {
        developer.log(
          'SendSmsHelper: failed to restore verificationId: $e',
          error: e,
          stackTrace: st,
        );
      }
    }

    if (_verificationId == null) {
      developer.log(
        'SendSmsHelper.signInWithSmsCode ERROR: no verificationId available',
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
        'SendSmsHelper.signInWithSmsCode: signed in uid=${result.user?.uid}',
      );

      await _clearPersistedVerification();
      developer.log('SendSmsHelper.signInWithSmsCode EXIT success');
      return result;
    } catch (e, st) {
      developer.log(
        'SendSmsHelper.signInWithSmsCode ERROR: $e',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> _clearPersistedVerification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kVerificationIdKey);
      await prefs.remove(_kResendTokenKey);
      _verificationId = null;
      _resendToken = null;
      developer.log('SendSmsHelper: Cleared persisted verification data');
    } catch (e, st) {
      developer.log(
        'SendSmsHelper: Failed to clear persisted verification data: $e',
        error: e,
        stackTrace: st,
      );
    }
  }
}
