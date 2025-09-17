import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'screens/role_selector_screen.dart';
import 'screens/senior/senior_login_screen.dart';
import 'screens/senior/senior_signup_screen.dart';
import 'screens/student/student_login_screen.dart';
import 'screens/student/student_signup_screen.dart';
import 'screens/dashboards/senior_dashboard.dart';
import 'screens/dashboards/student_dashboard.dart';
import 'screens/email_verification_required_screen.dart';
import 'onboarding/onbording.dart';

import 'authentication-flow/role_selector_page.dart';
import 'authentication-flow/senior_login_page.dart';
import 'authentication-flow/student_login_page.dart';
import 'authentication-flow/senior_signup_page.dart';
import 'authentication-flow/student_signup_page.dart';
import 'authentication-flow/onboarding_wrapper.dart';
import 'screens/verify_phone_number_screen.dart';
import 'screens/verify_phone_test_screen.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;
final FirebaseFirestore _firestore = FirebaseFirestore.instance;

/// Redirect guard — determines where user should be navigated.
FutureOr<String?> _redirectGuard(
  BuildContext context,
  GoRouterState state,
) async {
  final user = _auth.currentUser;
  final loggedIn = user != null;
  final loggingIn =
      state.location.contains("/login") || state.location.contains("/signup");

  // 1. Not logged in → block access to dashboards
  if (!loggedIn && state.location.contains("/dashboard")) {
    return "/";
  }

  // 2. Logged in but email not verified → force verify screen
  if (loggedIn) {
    // Only require email verification for users who signed up via email/password.
    final isEmailProvider =
        user.providerData.any((p) => p.providerId == 'password') ?? false;
    if (isEmailProvider && !user.emailVerified) {
      if (state.location != "/verify-email") {
        return "/verify-email";
      }
      return null;
    }
  }

  // 3. Logged in + verified
  if (loggedIn && user.emailVerified) {
    if (loggingIn || state.location == "/") {
      try {
        final seniorDoc = await _firestore
            .collection("seniors")
            .doc(user.uid)
            .get();
        final studentDoc = await _firestore
            .collection("students")
            .doc(user.uid)
            .get();

        if (seniorDoc.exists) return "/dashboard/senior";
        if (studentDoc.exists) return "/dashboard/student";
      } catch (e) {
        debugPrint("⚠️ Firestore check failed in redirect: $e");
        return null;
      }

      await _auth.signOut();
      return "/";
    }
  }

  return null;
}

/// Listenable for GoRouter refresh when FirebaseAuth changes
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Central app router
class AppRouter {
  static GoRouter router(bool seenOnboarding) => GoRouter(
    // Always start at root; redirect will send to onboarding when appropriate.
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(_auth.authStateChanges()),
    redirect: (context, state) async {
      final user = _auth.currentUser;
      final loggedIn = user != null;
      final loggingIn =
          state.location.contains("/login") ||
          state.location.contains("/signup");

      // If the user is not logged in and they haven't seen onboarding, send them
      // to the onboarding flow first. This ensures onboarding shows once before
      // exposing login/role selector.
      if (!loggedIn && !seenOnboarding) {
        if (state.location != '/onboarding') return '/onboarding';
        return null;
      }

      // 1. Not logged in → block access to dashboards
      if (!loggedIn && state.location.contains("/dashboard")) {
        return "/";
      }

      // 2. Logged in but email not verified → force verify screen
      if (loggedIn) {
        // Only require email verification for email/password sign-ins.
        final isEmailProvider =
            user.providerData.any((p) => p.providerId == 'password') ?? false;
        if (isEmailProvider && !(user.emailVerified)) {
          if (state.location != "/verify-email") {
            return "/verify-email";
          }
          return null;
        }
      }

      // 3. Logged in + verified
      if (loggedIn && user.emailVerified) {
        if (loggingIn || state.location == "/") {
          try {
            final seniorDoc = await _firestore
                .collection("seniors")
                .doc(user.uid)
                .get();
            final studentDoc = await _firestore
                .collection("students")
                .doc(user.uid)
                .get();

            if (seniorDoc.exists) return "/dashboard/senior";
            if (studentDoc.exists) return "/dashboard/student";
          } catch (e) {
            debugPrint("⚠️ Firestore check failed in redirect: $e");
            return null;
          }

          await _auth.signOut();
          return "/";
        }
      }

      return null;
    },
    routes: [
      // Original onboarding flow
      GoRoute(
        path: "/onboarding",
        builder: (context, state) => const Onbording(),
      ),

      // Original screens
      GoRoute(
        path: "/",
        builder: (context, state) => const RoleSelectorScreen(),
      ),
      GoRoute(
        path: "/verify-email",
        builder: (context, state) => const EmailVerificationRequiredScreen(),
      ),
      // Full-screen phone verification flow
      GoRoute(
        path: '/verify-phone',
        builder: (context, state) {
          // Support passing either a String (legacy phone) or a Map<String, dynamic>
          String phone = '';
          String? name;
          String? email;
          String? role;
          if (state.extra is String) {
            phone = state.extra as String;
          } else if (state.extra is Map<String, dynamic>) {
            final m = state.extra as Map<String, dynamic>;
            phone = (m['phone'] ?? '') as String;
            name = m['name'] as String?;
            email = m['email'] as String?;
            role = m['role'] as String?;
          } else {
            phone = state.queryParams['phone'] ?? '';
            name = state.queryParams['name'];
            email = state.queryParams['email'];
            role = state.queryParams['role'];
          }
          return VerifyPhoneNumberScreen(
            phoneNumber: phone,
            name: name,
            email: email,
            role: role,
          );
        },
      ),
      // Minimal test route to isolate phone auth handler behavior
      GoRoute(
        path: '/verify-phone-test',
        builder: (context, state) => const VerifyPhoneTestStarter(),
      ),
      GoRoute(
        path: "/senior/login",
        builder: (context, state) => const SeniorLoginScreen(),
      ),
      GoRoute(
        path: "/senior/signup",
        builder: (context, state) => const SeniorSignupScreen(),
      ),
      GoRoute(
        path: "/student/login",
        builder: (context, state) => const StudentLoginScreen(),
      ),
      GoRoute(
        path: "/student/signup",
        builder: (context, state) => const StudentSignupScreen(),
      ),
      GoRoute(
        path: "/dashboard/senior",
        builder: (context, state) => const SeniorDashboard(),
      ),
      GoRoute(
        path: "/dashboard/student",
        builder: (context, state) => const StudentDashboard(),
      ),

      // New onboarding-style authentication flow
      GoRoute(
        path: "/onboarding/role",
        builder: (context, state) => RoleSelectorPage(),
      ),
      GoRoute(
        path: "/onboarding/senior-login",
        builder: (context, state) => const SeniorLoginPage(),
      ),
      GoRoute(
        path: "/onboarding/student-login",
        builder: (context, state) => const StudentLoginPage(),
      ),
      GoRoute(
        path: "/onboarding/senior-signup",
        builder: (context, state) => const SeniorSignupPage(),
      ),
      GoRoute(
        path: "/onboarding/student-signup",
        builder: (context, state) => const StudentSignupPage(),
      ),
      GoRoute(
        path: "/onboarding/flow",
        builder: (context, state) => const OnboardingWrapper(),
      ),

      // Handle Firebase phone auth deep link (recaptcha, etc)
      GoRoute(
        path: "/link",
        builder: (context, state) {
          // Instead of showing a spinner forever, trigger the OTP dialog if possible
          Future.microtask(() async {
            final verificationId = state.queryParams['verificationId'] ?? '';
            final phoneParam = state.queryParams['phone'] ?? '';

            try {
              if (SeniorSignupPage.onDeepLinkOtp != null) {
                SeniorSignupPage.onDeepLinkOtp!(verificationId);
              }
              if (StudentSignupPage.onDeepLinkOtp != null) {
                StudentSignupPage.onDeepLinkOtp!(verificationId);
              }
              if (VerifyPhoneNumberScreen.onDeepLinkOtp != null) {
                VerifyPhoneNumberScreen.onDeepLinkOtp!(verificationId);
              }

              // If there's a navigator entry we can pop (the temporary /link), pop it first
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }

              // Ensure the user is routed to the verify-phone screen so the UI becomes visible
              // Use context.go which replaces the current location with the OTP screen.
              // Pass along any phone parameter the deep-link included (fallback to empty string).
              if (GoRouter.of(context).location != '/verify-phone') {
                context.go('/verify-phone', extra: phoneParam);
              }
            } catch (e) {
              debugPrint('Error handling /link deep-link: $e');
            }
          });

          // Return a minimal placeholder while async work happens. We navigate away quickly.
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    ],
  );
}
