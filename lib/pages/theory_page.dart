import 'package:flutter/material.dart';
import '../services/app_database.dart';
import 'exercise_page.dart';
import 'translate_page.dart';
import 'main_menu_page.dart';

class TheoryPage extends StatefulWidget {
  final int moduleId;
  final int levelId;
  final String moduleTitle;
  const TheoryPage({super.key, required this.moduleId, required this.levelId, required this.moduleTitle});

  @override
  State<TheoryPage> createState() => _TheoryPageState();
}

class _TheoryPageState extends State<TheoryPage> {
  late Future<List<Map<String, dynamic>>> _theoryFuture;

  @override
  void initState() {
    super.initState();
    _theoryFuture = AppDatabase.instance.getTheory(widget.levelId, widget.levelId) as Future<List<Map<String, dynamic>>>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.moduleTitle} - Теория уровня ${widget.levelId}', style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0A4B47),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _theoryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final content = (snapshot.data?.isNotEmpty ?? false)
              ? snapshot.data!.first['content_html'] ?? 'Текст теории отсутствует.'
              : 'Для этого уровня теория не предусмотрена.';

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Text(content, style: const TextStyle(fontSize: 16, height: 1.5)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                      builder: (context) => ExercisePage(moduleId: widget.moduleId, levelId: widget.levelId, moduleTitle: widget.moduleTitle)
                  )),
                  icon: const Icon(Icons.quiz),
                  label: const Text('Перейти к упражнениям'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A4B47), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
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
