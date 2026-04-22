import 'package:flutter/material.dart';
import '../services/app_database.dart';
import 'theory_page.dart';
import 'task_page.dart';
import 'translate_page.dart';
import 'main_menu_page.dart';
import 'translation_history_page.dart';

class ModuleLevelsPage extends StatefulWidget {
  final int moduleId;
  final String moduleTitle;

  const ModuleLevelsPage({
    super.key,
    required this.moduleId,
    required this.moduleTitle,
  });

  @override
  State<ModuleLevelsPage> createState() => _ModuleLevelsPageState();
}

class _ModuleLevelsPageState extends State<ModuleLevelsPage> {
  late Future<List<Map<String, dynamic>>> levelsFuture;
  late Future<Map<String, dynamic>?> userProgressFuture;

  @override
  void initState() {
    super.initState();
    levelsFuture = AppDatabase().getModuleLevels(widget.moduleId);
    userProgressFuture = AppDatabase().getUserProgress(widget.moduleId);
  }

  Future<void> _startLevel(BuildContext context, int level) async {
    final hasTheory = await _hasTheoryForLevel(widget.moduleId, level);

    if (hasTheory) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TheoryPage(
            moduleId: widget.moduleId,
            level: level,
            moduleTitle: widget.moduleTitle,
          ),
        ),
      );
    } else {
      final tasks = await AppDatabase().getTasks(widget.moduleId, level);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TaskPage(
            moduleId: widget.moduleId,
            level: level,
            moduleTitle: widget.moduleTitle,
            tasks: tasks,
            initialScore: 0,
          ),
        ),
      );
    }
  }

  Future<bool> _hasTheoryForLevel(int moduleId, int level) async {
    final theory = await AppDatabase().getTheory(moduleId, level);
    return theory != null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.moduleTitle),
        backgroundColor: const Color(0xFF0A4B47),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: levelsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка загрузки: ${snapshot.error}'));
          }

          final levels = snapshot.data ?? [];

          return FutureBuilder<Map<String, dynamic>?>(
            future: userProgressFuture,
            builder: (context, progressSnapshot) {
              final maxUnlockedLevel = progressSnapshot.data?['level'] ?? 0;

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: levels.length,
                itemBuilder: (context, index) {
                  final level = levels[index];
                  final levelNumber = level['level'] as int;
                  final isUnlocked = levelNumber <= maxUnlockedLevel + 1;

                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(
                        'Уровень $levelNumber',
                        style: const TextStyle(fontSize: 18),
                      ),
                      trailing: const Icon(Icons.arrow_forward),
                      enabled: isUnlocked,
                      onTap: () => _startLevel(context, levelNumber),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      endDrawer: _buildDrawer(context),
    );
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
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => MainMenuPage()));
              },
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