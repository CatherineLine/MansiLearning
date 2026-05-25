import 'package:flutter/material.dart';
import '../services/app_database.dart';
import 'word_edit_page.dart';
import '../widgets/app_drawer.dart';

class WordPracticePage extends StatefulWidget {
  final int moduleId;
  final String moduleTitle;
  const WordPracticePage({super.key, required this.moduleId, required this.moduleTitle});

  @override
  State<WordPracticePage> createState() => _WordPracticePageState();
}

class _WordPracticePageState extends State<WordPracticePage> {
  late Future<List<Map<String, dynamic>>> _wordsFuture;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  void _loadWords() => setState(() => _wordsFuture = AppDatabase.instance.getPracticeWords(widget.moduleId));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.moduleTitle} - Практика слов'), backgroundColor: const Color(0xFF0A4B47), foregroundColor: Colors.white),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _wordsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final words = snapshot.data ?? [];
          if (words.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
            Icon(Icons.book_outlined, size: 64, color: Colors.grey), SizedBox(height: 16), Text('Список пуст. Добавьте слова для практики.', style: TextStyle(color: Colors.grey))
          ]));
          return ListView.builder(padding: const EdgeInsets.all(12), itemCount: words.length, itemBuilder: (context, i) {
            final w = words[i];
            return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
              title: Text(w['mansi_word'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A4B47))),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('🇷 ${w['russian_translation'] ?? 'Нет перевода'}'),
                if (w['transcription'] != null) Text('🔤 [${w['transcription']}]', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
              ]),
              trailing: IconButton(icon: const Icon(Icons.edit, color: Color(0xFF0A4B47)), onPressed: () async {
                final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => WordEditPage(moduleId: widget.moduleId, word: w)));
                if (res == true) _loadWords();
              }),
            ));
          });
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0A4B47),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => WordEditPage(moduleId: widget.moduleId)));
          if (res == true) _loadWords();
        },
      ),
      endDrawer: const AppDrawer(activeSection: DrawerActiveSection.learning),
    );
  }
}