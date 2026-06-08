import 'package:flutter/material.dart';
import '../base_scafford.dart';
import '../models/learning_entities.dart';
import '../models/phrasebook_entities.dart' as pb;
import '../services/app_database.dart';
import 'theory_page.dart';
import 'task_page.dart';
import 'translate_page.dart';
import 'main_menu_page.dart';
import 'translation_history_page.dart';
import 'phrasebook_page.dart';

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
  late Future<List<Level>> levelsFuture;
  late Future<List<pb.UserProgress>> userProgressFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    levelsFuture = AppDatabase.instance.getModuleLevels(widget.moduleId);
    userProgressFuture = AppDatabase.instance.getUserProgress(1);
    setState(() {});
  }

  // ✅ Возврат в Главное меню
  Future<void> _goToMainMenu() async {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => MainMenuPage()),
    );
  }

  Future<void> _startLevel(BuildContext context, int levelId, int levelNumber) async {
    final hasTheory = await _hasTheoryForLevel(levelId);
    if (hasTheory) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TheoryPage(
            moduleId: widget.moduleId,
            levelId: levelId,  // ✅ ПЕРЕДАЁМ levelId
            level: levelNumber,
            moduleTitle: widget.moduleTitle,
          ),
        ),
      ).then((_) => _refreshData());
    } else {
      final tasks = await AppDatabase.instance.getTasks(levelId);
      if (tasks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('В этом уровне нет заданий')),
        );
        return;
      }
      final currentScore = await _getCurrentScore();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TaskPage(
            moduleId: widget.moduleId,
            levelId: levelId,  // ✅ ПЕРЕДАЁМ levelId
            level: levelNumber,
            moduleTitle: widget.moduleTitle,
            tasks: tasks.map((t) => t.toMap()).toList(),
            initialScore: currentScore,
          ),
        ),
      ).then((_) => _refreshData());
    }
  }

  Future<int> _getCurrentScore() async {
    final progress = await AppDatabase.instance.getUserProgress(1);
    int totalScore = 0;
    for (var p in progress) {
      if (p.sourceContext == 'task') {
        totalScore += p.score;
      }
    }
    return totalScore;
  }

  // ✅ ИСПРАВЛЕНО: вызов getTheory с ОДНИМ аргументом
  Future<bool> _hasTheoryForLevel(int levelId) async {
    final theory = await AppDatabase.instance.getTheory(levelId);
    return theory.isNotEmpty;
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        await _goToMainMenu();
      },
      child: BaseScaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          // ✅ Кастомная кнопка "Назад" → Главное меню
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goToMainMenu,
          ),
          title: Text(widget.moduleTitle),
          backgroundColor: const Color(0xFF0A4B47),
          foregroundColor: Colors.white,
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            _refreshData();
          },
          child: FutureBuilder<List<Level>>(
            future: levelsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Ошибка загрузки: ${snapshot.error}'));
              }
              final levels = snapshot.data ?? [];
              return FutureBuilder<List<pb.UserProgress>>(
                future: userProgressFuture,
                builder: (context, progressSnapshot) {
                  final completedLevelIds = <int>{};
                  if (progressSnapshot.hasData) {
                    for (var p in progressSnapshot.data!) {
                      if (p.sourceContext == 'task' && p.isCompleted && p.taskId != null) {
                        for (var level in levels) {
                          if (level.id == p.taskId) {
                            completedLevelIds.add(level.id!);
                          }
                        }
                      }
                    }
                  }

                  int maxCompletedLevelId = 0;
                  for (var level in levels) {
                    if (completedLevelIds.contains(level.id)) {
                      if ((level.id ?? 0) > maxCompletedLevelId) {
                        maxCompletedLevelId = level.id ?? 0;
                      }
                    }
                  }

                  int maxCompletedIndex = -1;
                  for (int i = 0; i < levels.length; i++) {
                    if (levels[i].id == maxCompletedLevelId) {
                      maxCompletedIndex = i;
                      break;
                    }
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: levels.length,
                    itemBuilder: (context, index) {
                      final level = levels[index];
                      final levelId = level.id ?? 0;
                      final isCompleted = completedLevelIds.contains(levelId);
                      final isUnlocked = index == 0 || index <= maxCompletedIndex + 1;

                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          title: Text(
                            level.title,
                            style: const TextStyle(fontSize: 18),
                          ),
                          subtitle: isCompleted
                              ? const Text('✅ Пройден', style: TextStyle(color: Colors.green))
                              : (!isUnlocked
                              ? const Text('🔒 Заблокирован', style: TextStyle(color: Colors.grey))
                              : const Text('📚 Доступен', style: TextStyle(color: Color(0xFF0A4B47)))),
                          trailing: isCompleted
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : const Icon(Icons.arrow_forward),
                          enabled: isUnlocked,
                          onTap: isUnlocked
                              ? () {
                            _startLevel(context, levelId, index + 1);
                          }
                              : null,
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        endDrawer: _buildDrawer(context),
      ),
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
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TranslatePage())),
            ),
            const Divider(height: 1, thickness: 0.5, color: Colors.grey),
            ListTile(
              title: const Text('Обучение', style: TextStyle(fontSize: 20, color: Color(0xFF0A4B47))),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MainMenuPage())),
            ),
            const Divider(height: 1, thickness: 0.5, color: Colors.grey),
            ListTile(
              title: const Text('История переводов', style: TextStyle(fontSize: 20, color: Colors.black)),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TranslationHistoryPage())),
            ),
            const Divider(height: 1, thickness: 0.5, color: Colors.grey),
            ListTile(
              title: const Text('Разговорник', style: TextStyle(fontSize: 20, color: Colors.black)),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PhrasebookPage())),
            ),
          ],
        ),
      ),
    );
  }
}