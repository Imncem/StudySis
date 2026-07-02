import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

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
  } catch (error) {
    startupError = error;
  }

  runApp(StudySisApp(startupError: startupError));
}

class StudySisApp extends StatelessWidget {
  const StudySisApp({super.key, this.startupError});

  final Object? startupError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StudySis',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: startupError == null
          ? const HomeScreen()
          : FirebaseSetupScreen(error: startupError!),
    );
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
                const Text(
                  'Run `flutterfire configure` in the app folder, then restart the app. See the root README for details.',
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
