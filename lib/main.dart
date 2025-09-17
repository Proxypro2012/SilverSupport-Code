import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';
import 'app_router.dart';
import 'package:firebase_phone_auth_handler/firebase_phone_auth_handler.dart';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:async';
import 'services/persistent_log.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Simple logging helper that uses both `developer.log` and `print` so logs
// are visible in devtools and on the device stdout (release builds as well).
void appLog(String message, {String name = 'SilverSupport'}) {
  try {
    developer.log(message, name: name);
  } catch (_) {}
  // Also print to stdout to increase the chance the message appears in
  // platform logs (logcat / Xcode) even for release builds.
  try {
    // Keep prints short and prefixed so they are easy to find in logs.
    print('[$name] $message');
  } catch (_) {}
  // Persist logs to file for later retrieval. Non-fatal if this fails.
  try {
    PersistentLog.append(message, name: name);
  } catch (_) {}
}

Future<void> main() async {
  // Run the app inside a guarded async zone and initialize bindings inside
  // that zone to avoid the "Zone mismatch" error when calling runApp.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      appLog('WidgetsFlutterBinding.ensureInitialized() called');

      // Initialize persistent file logging early so later logs are captured.
      await PersistentLog.init();

      // Initialize Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      appLog('Firebase.initializeApp completed');

      // Initialize Firebase App Check.
      // - Use Debug provider in debug builds (register debug token in Console).
      // - Use Play Integrity (Android) and App Attest (iOS) in release builds.
      try {
        if (kDebugMode) {
          await FirebaseAppCheck.instance.activate(
            androidProvider: AndroidProvider.debug,
            appleProvider: AppleProvider.debug,
          );
          appLog(
            'Firebase App Check activated with DebugProvider (kDebugMode)',
            name: 'AppCheck',
          );
        } else {
          await FirebaseAppCheck.instance.activate(
            androidProvider: AndroidProvider.playIntegrity,
            appleProvider: AppleProvider.appAttest,
          );
          appLog(
            'Firebase App Check activated with platform providers',
            name: 'AppCheck',
          );
        }
      } catch (e, st) {
        appLog(
          'Failed to activate Firebase App Check: $e\n$st',
          name: 'AppCheck',
        );
      }

      appLog('flutterLocalNotificationsPlugin.initialize completed');

      // Initialize local notifications
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      await flutterLocalNotificationsPlugin.initialize(initSettings);
      appLog('flutterLocalNotificationsPlugin.initialize completed');

      // Request iOS notification permissions
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      appLog('Requested iOS notification permissions (if available)');

      // Check onboarding status
      final prefs = await SharedPreferences.getInstance();
      final seenOnboarding = prefs.getBool('seenOnboarding') ?? false;
      appLog('Read SharedPreferences: seenOnboarding=$seenOnboarding');

      appLog('About to call runApp()');

      // Install framework-level error handlers so errors are logged using our
      // appLog helper (visible in debug and release logs). This helps capture
      // layout / rendering issues (including NaN-related crashes) and any
      // uncaught Dart errors.
      FlutterError.onError = (FlutterErrorDetails details) {
        appLog(
          'FlutterError: ${details.exceptionAsString()}\n${details.stack}',
          name: 'FlutterError',
        );
        // Keep default behavior for presentError so errors still show in devtools.
        FlutterError.presentError(details);
      };

      WidgetsBinding.instance.platformDispatcher.onError =
          (Object error, StackTrace stack) {
            appLog(
              'PlatformDispatcher.onError: $error\n$stack',
              name: 'PlatformError',
            );
            // Returning true tells the engine we've handled the error.
            return true;
          };

      // Run the app. Keep the FirebasePhoneAuthProvider wrapper as before.
      runApp(
        FirebasePhoneAuthProvider(child: MyApp(seenOnboarding: seenOnboarding)),
      );
    },
    (error, stack) {
      appLog('Uncaught zone error: $error\n$stack', name: 'ZoneError');
    },
  );
}

class MyApp extends StatelessWidget {
  final bool seenOnboarding;

  const MyApp({super.key, required this.seenOnboarding});

  @override
  Widget build(BuildContext context) {
    appLog('MyApp.build() - building app; seenOnboarding=$seenOnboarding');
    return MaterialApp.router(
      title: 'Silver Support',
      debugShowCheckedModeBanner: false,
      routerConfig: AppRouter.router(seenOnboarding),
    );
  }
}
