import 'package:flutter/material.dart';
import '../services/app_database.dart';
import 'theory_page.dart';
import 'task_page.dart';
import 'translate_page.dart';
import 'main_menu_page.dart';

class ModuleLevelsPage extends StatefulWidget {
  final int moduleId;
  final String moduleTitle;
  const ModuleLevelsPage({super.key, required this.moduleId, required this.moduleTitle});

  @override
  State<ModuleLevelsPage> createState() => _ModuleLevelsPageState();
}

class _ModuleLevelsPageState extends State<ModuleLevelsPage> {
  late Future<List<Map<String, dynamic>>> levelsFuture;
  late Future<List<Map<String, dynamic>>> userProgressFuture;

  @override
  void initState() {
    super.initState();
    levelsFuture = AppDatabase.instance.getModuleLevels(widget.moduleId) as Future<List<Map<String, dynamic>>>;
    userProgressFuture = AppDatabase.instance.getUserProgress(1) as Future<List<Map<String, dynamic>>>;
  }

  Future<void> _startLevel(BuildContext context, int levelNumber) async {
    final hasTheory = await _hasTheoryForLevel(widget.moduleId, levelNumber);
    if (hasTheory) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TheoryPage(
            moduleId: widget.moduleId,
            levelId: levelNumber, // ✅ Исправлено: параметр levelId
            moduleTitle: widget.moduleTitle,
          ),
        ),
      );
    } else {
      final tasks = await AppDatabase.instance.getTasks(levelNumber);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TaskPage(
            moduleId: widget.moduleId,
            level: levelNumber,
            moduleTitle: widget.moduleTitle,
            tasks: tasks.map((t) => t.toMap()).toList(),
            initialScore: 0,
          ),
        ),
      );
    }
  }

  Future<bool> _hasTheoryForLevel(int moduleId, int level) async {
    final theory = await AppDatabase.instance.getTheory(moduleId, level);
    return theory.isNotEmpty;
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(widget.moduleTitle),
        backgroundColor: const Color(0xFF0A4B47),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: levelsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Ошибка: ${snapshot.error}'));
          final levels = snapshot.data ?? [];

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: userProgressFuture,
            builder: (context, progressSnapshot) {
              final progressList = progressSnapshot.data ?? [];
              // Считаем максимальный пройденный уровень для разблокировки
              final completedLevels = progressList
                  .where((p) => p['source_context'] == 'level' && p['is_completed'] == 1)
                  .toList();
              final maxUnlockedLevel = completedLevels.isEmpty
                  ? 1
                  : (completedLevels.map((p) => p['level_id'] as int? ?? 0).reduce((a, b) => a > b ? a : b) + 1);

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: levels.length,
                itemBuilder: (context, index) {
                  final level = levels[index];
                  final levelNumber = level['id'] as int? ?? 0;
                  final isUnlocked = levelNumber <= maxUnlockedLevel;

                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    color: isUnlocked ? null : Colors.grey[300],
                    child: ListTile(
                      title: Text('Уровень $levelNumber', style: const TextStyle(fontSize: 18)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.book, color: Colors.blue),
                            onPressed: isUnlocked
                                ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => TheoryPage(moduleId: widget.moduleId, levelId: levelNumber, moduleTitle: widget.moduleTitle)))
                                : null,
                            tooltip: 'Теория',
                          ),
                          IconButton(
                            icon: const Icon(Icons.quiz, color: Colors.green),
                            onPressed: isUnlocked ? () => _startLevel(context, levelNumber) : null,
                            tooltip: 'Задания',
                          ),
                        ],
                      ),
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
            ListTile(title: const Text('Переводчик', style: TextStyle(fontSize: 20, color: Colors.black)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TranslatePage()))),
            const Divider(height: 1, thickness: 0.5, color: Colors.grey),
            ListTile(title: const Text('Обучение', style: TextStyle(fontSize: 20, color: Color(0xFF0A4B47))), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MainMenuPage()))),
            const Divider(height: 1, thickness: 0.5, color: Colors.grey),
            ListTile(title: const Text('История переводов', style: TextStyle(fontSize: 20, color: Colors.black)), onTap: () {}),
          ],
        ),
      ),
    );
  }
}