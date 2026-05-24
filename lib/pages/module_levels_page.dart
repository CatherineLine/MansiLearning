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

  @override
  void initState() {
    super.initState();
    levelsFuture = AppDatabase.instance.getModuleLevels(widget.moduleId);
  }

  Future<void> _startLevel(BuildContext context, int levelId) async {
    final theory = await AppDatabase.instance.getTheory(widget.moduleId, levelId);
    if (theory.isNotEmpty) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => TheoryPage(
          moduleId: widget.moduleId, level: levelId, moduleTitle: widget.moduleTitle)));
    } else {
      final tasks = await AppDatabase.instance.getTasks(levelId);
      Navigator.push(context, MaterialPageRoute(builder: (context) => TaskPage(
          moduleId: widget.moduleId, level: levelId, moduleTitle: widget.moduleTitle,
          tasks: tasks, initialScore: 0)));
    }
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(title: Text(widget.moduleTitle), backgroundColor: const Color(0xFF0A4B47), foregroundColor: Colors.white),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: levelsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Ошибка загрузки: ${snapshot.error}'));
          final levels = snapshot.data ?? [];
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: levels.length,
            itemBuilder: (context, index) {
              final level = levels[index];
              final levelId = level['id'] ?? 0;
              return Card(
                elevation: 4, margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  title: Text('Уровень $levelId', style: const TextStyle(fontSize: 18)),
                  subtitle: Text(level['title'] ?? ''),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () => _startLevel(context, levelId),
                ),
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
      child: Container(padding: const EdgeInsets.only(top: 40), decoration: const BoxDecoration(color: Color(0xFFE7E4DF)),
        child: ListView(padding: EdgeInsets.zero, children: [
          ListTile(title: const Text('Переводчик', style: TextStyle(fontSize: 20, color: Colors.black)),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TranslatePage()))),
          const Divider(height: 1, thickness: 0.5, color: Colors.grey),
          ListTile(title: const Text('Обучение', style: TextStyle(fontSize: 20, color: Color(0xFF0A4B47))),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MainMenuPage()))),
          const Divider(height: 1, thickness: 0.5, color: Colors.grey),
          ListTile(title: const Text('История переводов', style: TextStyle(fontSize: 20, color: Colors.black)), onTap: () {}),
        ]),
      ),
    );
  }
}