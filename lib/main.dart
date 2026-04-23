import 'package:flutter/material.dart';
import 'pages/translate_page.dart';
import 'services/app_database.dart';
import 'services/background_translation_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackgroundTranslationService.init();
  final db = AppDatabase();
  await db.database;
  await db.initLearningMaterials();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Переводчик',
      navigatorKey: navigatorKey,
      color: const Color(0xFF0A4B47),
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFE7E4DF),
      ),
      home: const TranslatePage(),
    );
  }
}