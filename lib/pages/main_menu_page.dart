import 'package:flutter/material.dart';
import '../base_scafford.dart';
import '../models/learning_entities.dart';
import '../models/phrasebook_entities.dart' as pb;
import '../services/app_database.dart';
import '../widgets/app_drawer.dart';
import 'module_levels_page.dart';
import 'riddles_menu_page.dart';

class MainMenuPage extends StatefulWidget {
  const MainMenuPage({super.key});

  @override
  State<MainMenuPage> createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage> {
  // ✅ Исправленный список модулей — соответствует JSON (9 модулей)
  final List<Map<String, dynamic>> modules = [
    {'id': 1, 'title': 'Фонетика мансийского языка'},
    {'id': 2, 'title': 'Личные местоимения'},
    {'id': 3, 'title': 'Грамматика (число и падежи существительных)'},
    {'id': 4, 'title': 'Глагол (настоящее время)'},
    {'id': 5, 'title': 'Глагол (прошедшее и будущее время)'},
    {'id': 6, 'title': 'Качественные имена прилагательные'},
    {'id': 7, 'title': 'Относительные прилагательные и притяжательность'},
    {'id': 8, 'title': 'Имена числительные'},
    {'id': 9, 'title': 'Основы синтаксиса'},
  ];

  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  int _completedLevelsCount = 0;
  int _totalScore = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final completedLevels = await AppDatabase.instance.getCompletedLevelsCount(1);
    final totalScore = await AppDatabase.instance.getUserTotalScore(1);
    setState(() {
      _completedLevelsCount = completedLevels;
      _totalScore = totalScore;
      _isLoading = false;
    });
    debugPrint('💰 Пройдено уровней: $_completedLevelsCount, Очков: $_totalScore');
  }

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
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Блок с очками
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A4B47),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '💰 Ваши очки:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    if (_isLoading)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$_totalScore',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A4B47),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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
            subtitle: const Text('В процессе разработки'),
            trailing: const Icon(Icons.arrow_forward),
            enabled: false,
          );
        }

        return FutureBuilder<List<pb.UserProgress>>(
          future: AppDatabase.instance.getUserProgress(1),
          builder: (context, progressSnapshot) {
            final progress = progressSnapshot.data ?? [];
            final completedTaskIds = progress
                .where((p) => p.sourceContext == 'task' && p.isCompleted && p.taskId != null)
                .map((p) => p.taskId!)
                .toSet();

            // Считаем процент выполнения модуля
            int totalTasks = 0;
            int completedTasks = 0;
            for (var level in allLevels) {
              final tasksInLevel = level.id != null ? (AppDatabase.instance.getTasks(level.id!).then((t) => t.length)) : Future.value(0);
              // Упрощённо: для отображения статуса используем количество пройденных уровней
            }

            final allLevelIds = allLevels.map((l) => l.id!).toSet();
            final completedLevelIds = progress
                .where((p) => p.sourceContext == 'level' && p.isCompleted && p.taskId != null && allLevelIds.contains(p.taskId))
                .map((p) => p.taskId!)
                .toSet();

            final isModuleCompleted = allLevelIds.difference(completedLevelIds).isEmpty;
            final completedCount = completedLevelIds.length;
            final percent = allLevels.isEmpty ? 0 : (completedCount / allLevels.length * 100).round();

            return ListTile(
              title: Text(module['title']),
              subtitle: Text(
                isModuleCompleted
                    ? '✅ Модуль пройден'
                    : '📚 Пройдено $percent% ($completedCount/${allLevels.length} уровней)',
                style: TextStyle(
                  color: isModuleCompleted ? Colors.green : const Color(0xFF0A4B47),
                ),
              ),
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