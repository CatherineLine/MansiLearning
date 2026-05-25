import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/learning_entities.dart';
import '../services/app_database.dart';
import '../widgets/app_drawer.dart';
import 'document_translation_page.dart';
import 'module_levels_page.dart';
import 'riddle_page.dart';

class MainMenuPage extends StatefulWidget {
  const MainMenuPage({super.key});

  @override
  State<MainMenuPage> createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage> {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  late Future<List<Module>> _modulesFuture; // ✅ Исправлено: List<Module> вместо List<Map>

  @override
  void initState() {
    super.initState();
    _modulesFuture = AppDatabase.instance.getModules();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset("assets/images/logo.png"),
        ),
        title: LayoutBuilder(
          builder: (context, constraints) {
            final fontSize = constraints.maxWidth > 600 ? 24.0 : 20.0;
            return Text(
              "Главное меню",
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.normal),
            );
          },
        ),
        backgroundColor: const Color(0xFF0A4B47),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white, size: 30),
            onPressed: () => scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Выберите модуль:', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<List<Module>>( // ✅ Исправлено: List<Module>
                future: _modulesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Ошибка: ${snapshot.error}'));
                  }
                  final modules = snapshot.data ?? [];
                  if (modules.isEmpty) {
                    return const Center(child: Text('Модули не найдены'));
                  }
                  return ListView.builder(
                    itemCount: modules.length,
                    itemBuilder: (context, index) => _buildModuleItem(context, modules[index]),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            _buildRiddleButton(),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DocumentTranslationPage()),
                );
              },
              icon: const Icon(Icons.description),
              label: const Text('Перевод документов'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A4B47),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
      endDrawer: const AppDrawer(activeSection: DrawerActiveSection.learning),
    );
  }

  Widget _buildModuleItem(BuildContext context, Module module) { // ✅ Исправлено: Module вместо Map
    return ListTile(
      title: Text(module.title ?? ''), // ✅ Доступ через точку
      subtitle: const Text('В процессе'),
      trailing: const Icon(Icons.arrow_forward),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ModuleLevelsPage(
              moduleId: module.id ?? 0, // ✅ Доступ через точку
              moduleTitle: module.title ?? '',
            ),
          ),
        );
      },
    );
  }

  Widget _buildRiddleButton() {
    return FutureBuilder<int>(
      future: AppDatabase.instance.getUserTotalScore(1),
      builder: (context, scoreSnapshot) {
        final totalScore = scoreSnapshot.data ?? 0;
        return FutureBuilder<int>(
          future: AppDatabase.instance.getCompletedRiddlesCount(1),
          builder: (context, riddleSnapshot) {
            final solved = riddleSnapshot.data ?? 0;
            final nextRiddleNumber = solved + 1;
            final neededScore = nextRiddleNumber * 100;
            final canOpen = totalScore >= neededScore;
            return ListTile(
              tileColor: canOpen ? Colors.green[100] : Colors.grey[200],
              title: const Text('Решить загадку'),
              subtitle: Text(
                canOpen
                    ? 'Загадка №$nextRiddleNumber (доступно)'
                    : 'Загадка №$nextRiddleNumber (нужно $neededScore очков, сейчас: $totalScore)',
              ),
              trailing: const Icon(Icons.arrow_forward),
              onTap: canOpen ? () => _openRiddlePage(context, solved, totalScore) : null,
            );
          },
        );
      },
    );
  }

  Future<void> _openRiddlePage(BuildContext context, int solvedRiddles, int totalScore) async {
    final data = await loadRiddles();
    final riddles = data['riddles'] as List<Map<String, dynamic>>? ?? [];
    if (riddles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Загадки не найдены')),
      );
      return;
    }
    if (solvedRiddles >= riddles.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Вы решили все загадки!')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RiddlePage(
          riddleIndex: solvedRiddles,
          userScore: totalScore,
          riddles: riddles,
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> loadRiddles() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/riddles.json');
      final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
      if (jsonMap.containsKey('riddles')) {
        final riddles = jsonMap['riddles'];
        if (riddles is List) {
          return {
            'riddles': List<Map<String, dynamic>>.from(
                riddles.map((r) => r as Map<String, dynamic>)
            )
          };
        }
      }
      throw Exception('Неверный формат riddles.json');
    } catch (e) {
      debugPrint('❌ Ошибка загрузки riddles.json: $e');
      final dbRiddles = await AppDatabase.instance.getRiddles();
      return {'riddles': dbRiddles.map((r) => r.toMap()).toList()};
    }
  }
}