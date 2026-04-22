import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_database.dart';
import 'module_levels_page.dart';
import 'riddle_page.dart';
import 'translate_page.dart';
import 'translation_history_page.dart';

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

  MainMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            onPressed: () => _openMenu(context),
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
          ],
        ),
      ),
      endDrawer: _buildDrawer(context),
    );
  }

  void _openMenu(BuildContext context) {
    Scaffold.of(context).openEndDrawer();
  }

  Widget _buildModuleItem(BuildContext context, Map<String, dynamic> module) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: AppDatabase().getUserProgress(module['id']),
      builder: (context, snapshot) {
        final progress = snapshot.data;
        final completed = progress != null && (progress['level'] as int) >= 5;
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
      future: AppDatabase().getCompletedRiddlesCount(),
      builder: (context, snapshot) {
        final solved = snapshot.data ?? 0;
        final nextRiddleNumber = solved + 1;
        final neededScore = nextRiddleNumber * 100;

        return ListTile(
          tileColor: Colors.green[100],
          title: const Text('Решить загадку'),
          subtitle: Text('Доступна загадка №$nextRiddleNumber'),
          trailing: const Icon(Icons.arrow_forward),
          onTap: () async {
            final totalScore = await AppDatabase().getUserTotalScore();
            if (totalScore >= neededScore) {
              _openRiddlePage(context, solved);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Нужно ещё $neededScore очков')),
              );
            }
          },
        );
      },
    );
  }

  Future<void> _openRiddlePage(BuildContext context, int solvedRiddles) async {
    final data = await loadRiddles();
    final progressData = await AppDatabase().getRiddleProgress();
    final totalScore = progressData['total_score'] as int? ?? 0;
    final nextRequiredScore = (solvedRiddles + 1) * 100;

    if (totalScore >= nextRequiredScore) {
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Нужно ещё $nextRequiredScore очков')),
      );
    }
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Container(
        padding: const EdgeInsets.only(top: 40),
        decoration: const BoxDecoration(color: Color(0xFFE7E4DF)),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ListTile(
              title: const Text('Переводчик', style: TextStyle(fontSize: 20, color: Colors.black)),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const TranslatePage()));
              },
            ),
            ListTile(
              title: const Text('Обучение', style: TextStyle(fontSize: 20, color: Color(0xFF0A4B47))),
              onTap: () {},
            ),
            ListTile(
              title: const Text('История переводов', style: TextStyle(fontSize: 20, color: Colors.black)),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => TranslationHistoryPage()));
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Вспомогательная функция для загрузки загадок (можно вынести в utils)
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