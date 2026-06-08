import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../base_scafford.dart';
import '../models/learning_entities.dart';
import '../models/phrasebook_entities.dart' as pb;
import '../services/app_database.dart';
import '../widgets/app_drawer.dart';
import 'module_levels_page.dart';
import 'riddles_menu_page.dart';

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
    return BaseScaffold(
      scaffoldKey: scaffoldKey,
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
      endDrawer: const AppDrawer(activeSection: DrawerActiveSection.learning),
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
            _buildRiddleButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleItem(BuildContext context, Map<String, dynamic> module) {
    return FutureBuilder<List<Level>>(
      future: AppDatabase.instance.getModuleLevels(module['id']),
      builder: (context, levelsSnapshot) {
        if (!levelsSnapshot.hasData) {
          return ListTile(
            title: Text(module['title']),
            subtitle: const Text('Загрузка...'),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ModuleLevelsPage(moduleId: module['id'], moduleTitle: module['title'])));
            },
          );
        }

        final allLevels = levelsSnapshot.data!;
        if (allLevels.isEmpty) {
          return ListTile(
            title: Text(module['title']),
            subtitle: const Text('В процессе'),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ModuleLevelsPage(moduleId: module['id'], moduleTitle: module['title'])));
            },
          );
        }

        return FutureBuilder<List<pb.UserProgress>>(
          future: AppDatabase.instance.getUserProgress(1),
          builder: (context, progressSnapshot) {
            final progress = progressSnapshot.data ?? [];
            final completedLevelIds = <int>{};

            for (var p in progress) {
              if (p.sourceContext == 'task' && p.isCompleted && p.taskId != null) {
                if (allLevels.any((l) => l.id == p.taskId)) {
                  completedLevelIds.add(p.taskId!);
                }
              }
            }

            final allLevelIds = allLevels.map((l) => l.id!).toSet();
            final isCompleted = allLevelIds.difference(completedLevelIds).isEmpty;

            return ListTile(
              title: Text(module['title']),
              subtitle: Text(isCompleted ? 'Пройден' : 'В процессе'),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ModuleLevelsPage(moduleId: module['id'], moduleTitle: module['title'])));
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRiddleButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RiddlesMenuPage()),
        );
      },
      icon: const Icon(Icons.psychology),
      label: const Text('Загадки'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0A4B47),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
      ),
    );
  }
}