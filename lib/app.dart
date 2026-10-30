import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'widgets/glass.dart';
import 'screens/home/home_screen.dart';
import 'screens/schedule/schedule_screen.dart';
import 'screens/call_history/call_history_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/splash/splash_screen.dart';

class SalahSilentApp extends StatefulWidget {
  const SalahSilentApp({super.key});

  @override
  State<SalahSilentApp> createState() => _SalahSilentAppState();
}

class _SalahSilentAppState extends State<SalahSilentApp> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Salah Silent',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: _showSplash
          ? SplashScreen(
              onFinished: () {
                if (mounted) setState(() => _showSplash = false);
              },
            )
          : const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    ScheduleScreen(),
    CallHistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: GlassNavigationBar(
        index: _currentIndex,
        onChanged: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}
