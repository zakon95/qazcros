import 'package:flutter/material.dart';
import 'app/app_router.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'screens/home_screen.dart';
import 'services/audio_service.dart';
import 'services/progress_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'screens/login_screen.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

Future<void> initializeApp() async {
  // Инициализация логгера
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });

  final logger = Logger('AppInitialization');

  try {
    // Инициализация Firebase
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyBrSMR5rXH44U1kcYIiAYNGVM65mkdSkq4",
          authDomain: "qazcros.firebaseapp.com",
          projectId: "qazcros",
          storageBucket: "qazcros.appspot.com",
          messagingSenderId: "526990363113",
          appId: "1:526990363113:web:05d9281aedc011f111a378",
          measurementId: "G-MS1W2H9ZTW",
        ),
      );
    } else {
      await Firebase.initializeApp();
    }

    // Устанавливаем ориентацию и UI режим
    await Future.wait([
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    ]);

    // Инициализация AudioService
    await AudioService().initialize();
    
    // Синхронизация прогресса, если пользователь авторизован
    await syncUserProgress();

    // Инициализация App Check
    await FirebaseAppCheck.instance.activate(
      webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.appAttest,
    );
  } catch (e, stackTrace) {
    logger.severe('Error during app initialization: $e\nStack trace: $stackTrace');
    rethrow; // Пробрасываем ошибку дальше
  }
}

// Синхронизация прогресса пользователя между устройством и облаком
Future<void> syncUserProgress() async {
  final logger = Logger('ProgressSync');
  try {
    final progressService = ProgressService();
    if (progressService.isAuthenticated) {
      logger.info("Starting progress synchronization");
      final completedLevels = await progressService.syncProgress();
      logger.info("Progress synchronized. Total completed levels: ${completedLevels.length}");
    } else {
      logger.info("User not authenticated, skipping progress synchronization");
    }
  } catch (e, stackTrace) {
    logger.severe("Error syncing progress: $e\nStack trace: $stackTrace");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeApp();
    runApp(const CrosticApp());
  } catch (e) {
    // Если инициализация не удалась, показываем экран ошибки
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Ошибка инициализации приложения'),
              Text('$e'),
              ElevatedButton(
                onPressed: () {
                  // Попытка перезапуска приложения
                  main();
                },
                child: const Text('Попробовать снова'),
              ),
            ],
          ),
        ),
      ),
    ));
  }
}

class CrosticApp extends StatelessWidget {
  const CrosticApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crostic Game',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      debugShowCheckedModeBanner: false,
      onGenerateRoute: (settings) {
        if (settings.name == '/login') {
          return MaterialPageRoute(builder: (_) => const LoginScreen());
        }
        return AppRouter.generateRoute(settings);
      },
    );
  }
}
