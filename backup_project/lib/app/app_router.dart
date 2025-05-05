import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/level_select_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/leaderboard_screen.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case '/levels':
        return MaterialPageRoute(builder: (_) => const LevelSelectScreen());
      case '/settings':
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case '/leaderboard':
        return MaterialPageRoute(builder: (_) => const LeaderboardScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Страница не найдена')),
          ),
        );
    }
  }
}
