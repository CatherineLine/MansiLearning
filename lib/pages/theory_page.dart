import 'package:flutter/material.dart';
import '../base_scafford.dart';
import '../models/learning_entities.dart';
import '../services/app_database.dart';
import '../services/voice_cash_service.dart';
import '../services/tts_api_service.dart';
import '../widgets/app_drawer.dart';
import 'task_page.dart';

class TheoryPage extends StatefulWidget {
  final int moduleId;
  final int levelId;
  final int level;
  final String moduleTitle;

  const TheoryPage({
    super.key,
    required this.moduleId,
    required this.levelId,
    required this.level,
    required this.moduleTitle,
  });

  @override
  State<TheoryPage> createState() => _TheoryPageState();
}

class _TheoryPageState extends State<TheoryPage> {
  late Future<List<Theory>> _theoryFuture;
  late Future<List<Task>> _tasksFuture;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late VoiceCacheService _voiceCache;

  @override
  void initState() {
    super.initState();
    _theoryFuture = AppDatabase.instance.getTheory(widget.levelId);
    _tasksFuture = AppDatabase.instance.getTasks(widget.levelId);
    _voiceCache = VoiceCacheService();
    _voiceCache.init();
  }

  Future<void> _speakText(String text) async {
    if (text.trim().isEmpty) return;

    debugPrint('🎙️ Озвучивание в теории: $text');

    try {
      final audioBytes = await _voiceCache.getOrSynthesize(text);
      if (audioBytes != null) {
        await TtsAudioPlayer.play(audioBytes, text: text);
        debugPrint('✅ Воспроизведение начато для: $text');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось озвучить'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Ошибка: $e');
    }
  }

  Widget _parseHtmlToWidget(String html) {
    final List<Widget> widgets = [];
    String remaining = html;

    // Заменяем <tts>текст</tts> на кнопки
    while (remaining.isNotEmpty) {
      final ttsStart = remaining.indexOf('<tts>');
      if (ttsStart == -1) {
        // Нет больше тегов — добавляем остальной текст
        final cleanText = remaining
            .replaceAll(RegExp(r'<[^>]+>'), '')
            .trim();
        if (cleanText.isNotEmpty) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                cleanText,
                style: const TextStyle(fontSize: 16, height: 1.4),
              ),
            ),
          );
        }
        break;
      }

      // Добавляем текст перед тегом
      if (ttsStart > 0) {
        final beforeText = remaining.substring(0, ttsStart)
            .replaceAll(RegExp(r'<[^>]+>'), '')
            .trim();
        if (beforeText.isNotEmpty) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                beforeText,
                style: const TextStyle(fontSize: 16, height: 1.4),
              ),
            ),
          );
        }
      }

      // Находим закрывающий тег
      final ttsEnd = remaining.indexOf('</tts>', ttsStart);
      if (ttsEnd == -1) break;

      // Извлекаем текст для озвучки
      final ttsText = remaining.substring(ttsStart + 5, ttsEnd);
      if (ttsText.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ElevatedButton.icon(
              onPressed: () => _speakText(ttsText),
              icon: const Icon(Icons.volume_up, size: 18),
              label: Text(ttsText, style: const TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A4B47),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        );
      }

      // Продолжаем с остатком строки
      remaining = remaining.substring(ttsEnd + 6);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      scaffoldKey: _scaffoldKey,
      appBar: AppBar(
        title: Text(
          '${widget.moduleTitle} - Уровень ${widget.level}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0A4B47),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: const AppDrawer(activeSection: DrawerActiveSection.learning),
      body: FutureBuilder<List<Theory>>(
        future: _theoryFuture,
        builder: (context, theorySnapshot) {
          if (theorySnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final hasTheory = theorySnapshot.hasData && theorySnapshot.data!.isNotEmpty;
          final rawTheoryHtml = hasTheory ? theorySnapshot.data!.first.contentHtml : '';

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: hasTheory
                          ? _parseHtmlToWidget(rawTheoryHtml)
                          : const Column(
                        children: [
                          Icon(Icons.school, size: 48, color: Color(0xFF0A4B47)),
                          SizedBox(height: 16),
                          Text(
                            'Теория не требуется для этого уровня',
                            style: TextStyle(fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: ElevatedButton(
                  onPressed: () async {
                    final tasks = await _tasksFuture;
                    if (tasks.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Нет заданий для этого уровня')),
                      );
                      return;
                    }
                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TaskPage(
                          moduleId: widget.moduleId,
                          levelId: widget.levelId,
                          level: widget.level,
                          moduleTitle: widget.moduleTitle,
                          tasks: tasks.map((t) => t.toMap()).toList(),
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A4B47),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Перейти к заданиям', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}