import 'package:flutter/material.dart';
import '../models/learning_entities.dart';
import '../services/app_database.dart';
import 'task_page.dart';
import 'translate_page.dart';
import 'main_menu_page.dart';

class TheoryPage extends StatefulWidget {
  final int moduleId;
  final int level;
  final String moduleTitle;

  const TheoryPage({
    super.key,
    required this.moduleId,
    required this.level,
    required this.moduleTitle,
  });

  @override
  State<TheoryPage> createState() => _TheoryPageState();
}

class _TheoryPageState extends State<TheoryPage> {
  late Future<List<Theory>> _theoryFuture;
  late Future<List<Task>> _tasksFuture;

  @override
  void initState() {
    super.initState();
    _theoryFuture = AppDatabase.instance.getTheory(widget.moduleId, widget.level);
    _tasksFuture = AppDatabase.instance.getTasks(widget.moduleId);
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,  // Добавить ключ
      appBar: AppBar(
        title: Text(
          '${widget.moduleTitle} - Уровень ${widget.level}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0A4B47),
      ),
      body: FutureBuilder<List<Theory>>(
        future: _theoryFuture,
        builder: (context, theorySnapshot) {
          if (theorySnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: theorySnapshot.hasData && theorySnapshot.data!.isNotEmpty
                      ? Text(
                    theorySnapshot.data!.first.contentHtml,
                    style: const TextStyle(fontSize: 18),
                  )
                      : const Text(
                    'Теория не требуется для этого уровня',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: FutureBuilder<List<Task>>(
                    future: _tasksFuture,
                    builder: (context, tasksSnapshot) {
                      if (tasksSnapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }

                      final hasTasks = tasksSnapshot.hasData && tasksSnapshot.data!.isNotEmpty;

                      return ElevatedButton(
                        onPressed: hasTasks
                            ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TaskPage(
                                moduleId: widget.moduleId,
                                level: widget.level,
                                moduleTitle: widget.moduleTitle,
                                tasks: tasksSnapshot.data!.map((t) => t.toMap()).toList(),
                                initialScore: 0,
                              ),
                            ),
                          );
                        }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A4B47),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Перейти к заданиям'),
                      );
                    },
                  ),
                ),
              ),
            ],
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
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}