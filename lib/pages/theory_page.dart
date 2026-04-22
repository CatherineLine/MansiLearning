import 'package:flutter/material.dart';
import '../services/app_database.dart';
import 'task_page.dart';
import 'translate_page.dart';
import 'main_menu_page.dart';
import 'translation_history_page.dart';

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
  late Future<Map<String, dynamic>?> _theoryFuture;
  late Future<List<Map<String, dynamic>>> _tasksFuture;

  @override
  void initState() {
    super.initState();
    _theoryFuture = AppDatabase().getTheory(widget.moduleId, widget.level);
    _tasksFuture = AppDatabase().getTasks(widget.moduleId, widget.level);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.moduleTitle} - Уровень ${widget.level}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0A4B47),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
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
                  child: theorySnapshot.hasData
                      ? Text(
                    theorySnapshot.data!['content'] as String,
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
                  child: FutureBuilder<List<Map<String, dynamic>>>(
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
                                tasks: tasksSnapshot.data!,
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