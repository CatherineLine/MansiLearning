import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/phrasebook_entities.dart' as pb;
import '../services/app_database.dart';
import '../widgets/app_drawer.dart';
import 'document_translation_page.dart';
import 'module_levels_page.dart';
import 'riddle_page.dart';

class MainMenuPage extends StatelessWidget {
  final List<Map<String, dynamic>> modules = [
    {'id': 1, 'title': 'Фонетика мансийского языка'},
    {'id': 2, 'title': 'Грамматика (число и местоимения)'},
    {'id': 3, 'title': 'Лексика (термины родства)'},
    {'id': 4, 'title': 'Предложения с именным сказуемым'},
    {'id': 5, 'title': 'Разговорная тема "Знакомство"'},
    {'id': 6, 'title': 'Суффиксы прилагательных'},
    {'id': 7, 'title': 'Уменьшительные суффиксы'},
    {'id': 8, 'title': 'Притяжательное склонение'},
    {'id': 9, 'title': 'Местный падеж'},
    {'id': 10, 'title': 'Предложения наличия и местонахождения'},
  ];

  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  MainMenuPage({super.key});

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
              child: ListView.builder(
                itemCount: modules.length,
                itemBuilder: (context, index) => _buildModuleItem(context, modules[index]),
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


  Widget _buildModuleItem(BuildContext context, Map<String, dynamic> module) {
    return FutureBuilder<List<pb.UserProgress>>(
      future: AppDatabase.instance.getUserProgress(1),
      builder: (context, snapshot) {
        final progress = snapshot.data ?? [];
        final moduleProgress = progress.where((p) => p.sourceContext == 'task').toList();
        final completed = moduleProgress.isNotEmpty;

        return ListTile(
          title: Text(module['title']),
          subtitle: completed ? const Text('Пройден') : const Text('В процессе'),
          trailing: const Icon(Icons.arrow_forward),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ModuleLevelsPage(
                  moduleId: module['id'],
                  moduleTitle: module['title'],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRiddleButton() {
    return FutureBuilder<int>(
      future: AppDatabase.instance.getCompletedRiddlesCount(1),
      builder: (context, snapshot) {
        final solved = snapshot.data ?? 0;
        final nextRiddleNumber = solved + 1;
        final neededScore = nextRiddleNumber * 100;
        return FutureBuilder<int>(
          future: AppDatabase.instance.getUserTotalScore(1),
          builder: (context, scoreSnapshot) {
            final totalScore = scoreSnapshot.data ?? 0;
            return ListTile(
              tileColor: Colors.green[100],
              title: const Text('Решить загадку'),
              subtitle: Text('Загадка №$nextRiddleNumber (доступно при $neededScore очках)'),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () async {
                if (totalScore >= neededScore) {
                  _openRiddlePage(context, solved);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Нужно ещё ${neededScore - totalScore} очков (сейчас: $totalScore)')),
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  Future<void> _openRiddlePage(BuildContext context, int solvedRiddles) async {
    final data = await loadRiddles();
    final progressData = await AppDatabase.instance.getRiddleProgress(1, solvedRiddles + 1);
    final totalScore = progressData?.score ?? 0;
    final nextRequiredScore = (solvedRiddles + 1) * 100;
    if (totalScore >= nextRequiredScore || true) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RiddlePage(
            riddleIndex: solvedRiddles,
            userScore: totalScore,
            riddles: data['riddles'],
          ),
        ),
      );
    }
  }

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
    print('Ошибка загрузки riddles.json: $e');
    return {'riddles': []};
  }
}