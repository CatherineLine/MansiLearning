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
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось озвучить'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint('❌ Ошибка: $e');
    }
  }

  /// Парсит HTML и создаёт виджеты с поддержкой <tts>
  Widget _parseHtmlToWidget(String html) {
    final List<Widget> widgets = [];
    String remaining = html;

    while (remaining.isNotEmpty) {
      final ttsStart = remaining.indexOf('<tts>');

      if (ttsStart == -1) {
        // Нет больше тегов — добавляем остальной текст с базовым форматированием
        final cleanText = _cleanHtmlTags(remaining);
        if (cleanText.isNotEmpty) {
          widgets.addAll(_buildTextWithFormatting(cleanText));
        }
        break;
      }

      // Добавляем текст перед тегом
      if (ttsStart > 0) {
        final beforeText = _cleanHtmlTags(remaining.substring(0, ttsStart));
        if (beforeText.isNotEmpty) {
          widgets.addAll(_buildTextWithFormatting(beforeText));
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
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () => _speakText(ttsText),
              icon: const Icon(Icons.volume_up, size: 20),
              label: Text(
                ttsText,
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A4B47),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

  /// Очищает HTML-теги и возвращает чистый текст
  String _cleanHtmlTags(String html) {
    String result = html;
    // Удаляем все HTML-теги
    result = result.replaceAll(RegExp(r'<[^>]+>'), '');
    // Заменяем множественные пробелы и переносы на один пробел
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
    return result;
  }

  /// Создаёт виджеты текста с базовым форматированием (заголовки, списки)
  List<Widget> _buildTextWithFormatting(String text) {
    final List<Widget> widgets = [];
    final lines = text.split('\n');

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      // Определяем заголовки по маркерам
      if (line.startsWith('##')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              line.replaceFirst('##', '').trim(),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0A4B47),
              ),
            ),
          ),
        );
      } else if (line.startsWith('#')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 8),
            child: Text(
              line.replaceFirst('#', '').trim(),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0A4B47),
              ),
            ),
          ),
        );
      }
      // Обрабатываем маркированные списки
      else if (line.startsWith('-') || line.startsWith('•')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontSize: 16)),
                Expanded(
                  child: Text(
                    line.replaceFirst(RegExp(r'^[-•]'), '').trim(),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      // Обычный текст
      else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              line,
              style: const TextStyle(fontSize: 16, height: 1.4),
            ),
          ),
        );
      }
    }

    return widgets;
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