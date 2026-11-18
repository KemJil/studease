import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import 'screens/auth/auth_screen.dart';
import 'screens/home_shell.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';

/// Root widget: owns the theme and routes between splash, auth and the app.
class StudEaseApp extends StatefulWidget {
  const StudEaseApp({super.key});

  @override
  State<StudEaseApp> createState() => _StudEaseAppState();
}

class _StudEaseAppState extends State<StudEaseApp> {
  final AuthService _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance.mode,
      builder: (BuildContext context, ThemeMode mode, Widget? _) {
        return MaterialApp(
          title: 'StudEase',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          home: StreamBuilder<User?>(
            stream: _auth.authStateChanges,
            builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SplashScreen();
              }

              final User? user = snapshot.data;
              if (user == null) {
                return AuthScreen(authService: _auth);
              }
              return HomeShell(uid: user.uid);
            },
          ),
        );
      },
    );
  }
}
