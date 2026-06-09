// main.dart - обновлённый
import 'dart:async';
import 'package:Mansi_Translator/pages/translate_page.dart';
import 'package:Mansi_Translator/services/tts_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/app_database.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.database;
  await AppDatabase.instance.initLearningMaterials();
  unawaited(_initializeDatabase());
  runApp(const MyApp());
}

Future<void> _initializeDatabase() async {
  try {
    final db = AppDatabase.instance;
    await db.database;
    await db.initLearningMaterials();
    debugPrint('✅ База данных инициализирована');

    // ✅ Инициализируем TTS с задержкой
    await Future.delayed(const Duration(seconds: 1));
    await TtsAudioPlayer.init();
    debugPrint('✅ TTS инициализирован');
  } catch (e) {
    debugPrint('❌ Ошибка инициализации БД: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Мансийский переводчик',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru', 'RU'),
        Locale('en', 'US'),
      ],
      locale: const Locale('ru', 'RU'),
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFE7E4DF),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      builder: (context, child) {
        // Глобальный MediaQuery с отступом снизу
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: MediaQuery.of(context).padding.copyWith(
              bottom: MediaQuery.of(context).size.height * 0.05, // 5% от высоты экрана
            ),
          ),
          child: child!,
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TranslatePage()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A4B47),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 120,
              height: 120,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.translate, size: 80, color: Colors.white);
              },
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
            const SizedBox(height: 16),
            const Text(
              'Мансийский переводчик',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}