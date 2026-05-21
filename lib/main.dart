import 'package:Mansi_Translator/pages/translate_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mansi Translator',
      debugShowCheckedModeBanner: false,

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru', 'RU'), // Русский
        Locale('en', 'US'), // Английский (fallback)
      ],
      locale: const Locale('ru', 'RU'), // Устанавливаем русский язык
      color: const Color(0xFF0A4B47),
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFE7E4DF),
      ),
      home: const TranslatePage(),
    );
  }
}