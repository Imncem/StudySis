import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'screens/practice_screen.dart';
import 'screens/quiz_screen.dart';
import 'screens/student_app_shell.dart';
import 'screens/study_pet_screen.dart';
import 'services/student_auth_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'theme/theme_controller_scope.dart';
import 'widgets/floating_muffin_shell.dart';
import 'widgets/page_translation_scope.dart';
import 'widgets/roaming_study_pet_companion.dart';
import 'widgets/theme_toggle_button.dart';

final studySisNavigatorKey = GlobalKey<NavigatorState>();
final pageTranslationController = PageTranslationController();
final studySisRouteTracker = StudySisRouteTracker();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? startupError;
  try {
    final firebaseApp = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint(
      '[StudySis] Firebase initialized: projectId=${firebaseApp.options.projectId}',
    );
    final user = await StudentAuthService().ensureSignedInAnonymously();
    debugPrint('[StudySis] Student session ready: uid=${user.uid}');
  } catch (error) {
    startupError = error;
  }

  final themeController = ThemeController();
  await themeController.load();

  runApp(
    ThemeControllerScope(
      controller: themeController,
      child: StudySisApp(
        startupError: startupError,
        themeController: themeController,
      ),
    ),
  );
}

class StudySisApp extends StatelessWidget {
  const StudySisApp({
    required this.themeController,
    super.key,
    this.startupError,
  });

  final Object? startupError;
  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: studySisNavigatorKey,
          navigatorObservers: [studySisRouteTracker],
          title: 'StudySis',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeController.themeMode,
          builder: (context, child) {
            final top = MediaQuery.paddingOf(context).top + 12;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: AppTheme.systemOverlayStyle(themeController.themeMode),
              child: PageTranslationScope(
                controller: pageTranslationController,
                child: FloatingMuffinShell(
                  navigatorKey: studySisNavigatorKey,
                  translationController: pageTranslationController,
                  enabled: startupError == null,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      child ?? const SizedBox.shrink(),
                      AnimatedBuilder(
                        animation: studySisRouteTracker,
                        builder: (context, _) {
                          final routeName =
                              studySisRouteTracker.currentRouteName;
                          return RoamingStudyPetCompanion(
                            enabled: startupError == null,
                            hidden: routeName == StudyPetScreen.routeName ||
                                routeName == QuizScreen.routeName,
                            mode: routeName == PracticeScreen.routeName
                                ? RoamingStudyPetMode.stationary
                                : RoamingStudyPetMode.normal,
                          );
                        },
                      ),
                      Positioned(
                        top: top,
                        right: 14,
                        width: 44,
                        height: 44,
                        child: ThemeToggleButton(
                          controller: themeController,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          home: startupError == null
              ? const StudentAppShell()
              : FirebaseSetupScreen(error: startupError!),
        );
      },
    );
  }
}

class StudySisRouteTracker extends NavigatorObserver with ChangeNotifier {
  final List<Route<dynamic>> _routes = [];

  String? get currentRouteName {
    for (final route in _routes.reversed) {
      final name = route.settings.name;
      if (name != null && name.isNotEmpty) return name;
    }
    return null;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    notifyListeners();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    notifyListeners();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    notifyListeners();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0 && newRoute != null) {
      _routes[index] = newRoute;
    } else if (newRoute != null) {
      _routes.add(newRoute);
    } else if (oldRoute != null) {
      _routes.remove(oldRoute);
    }
    notifyListeners();
  }
}

class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.settings_rounded, size: 52),
                const SizedBox(height: 20),
                Text('Connect StudySis to Firebase',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(
                  error is StudentAuthException
                      ? 'Enable Anonymous Authentication in Firebase Console > Authentication > Sign-in method > Anonymous, then restart StudySis.'
                      : 'Run `flutterfire configure` in the app folder, then restart the app. See the root README for details.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(error.toString(),
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
