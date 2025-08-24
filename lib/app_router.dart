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
  if (loggedIn && !user!.emailVerified) {
    if (state.location != "/verify-email") {
      return "/verify-email";
    }
    return null;
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
    initialLocation: seenOnboarding ? "/" : "/onboarding",
    refreshListenable: GoRouterRefreshStream(_auth.authStateChanges()),
    redirect: (context, state) async => await _redirectGuard(context, state),
    routes: [
      GoRoute(
        path: "/onboarding",
        builder: (context, state) => const Onbording(),
      ),
      GoRoute(
        path: "/",
        builder: (context, state) => const RoleSelectorScreen(),
      ),
      GoRoute(
        path: "/verify-email",
        builder: (context, state) => const EmailVerificationRequiredScreen(),
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
    ],
  );
}
