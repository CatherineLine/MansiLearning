import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../base_scafford.dart';
import '../models/learning_entities.dart';
import '../models/phrasebook_entities.dart';
import '../services/app_database.dart';
import '../services/voice_cash_service.dart';
import '../services/tts_api_service.dart';
import '../widgets/app_drawer.dart';
import 'module_levels_page.dart';

class TaskPage extends StatefulWidget {
  final int moduleId;
  final int levelId;
  final int level;
  final String moduleTitle;
  final List<Map<String, dynamic>> tasks;

  const TaskPage({
    super.key,
    required this.moduleId,
    required this.levelId,
    required this.level,
    required this.moduleTitle,
    required this.tasks,
  });

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  int _currentTaskIndex = 0;
  bool _levelCompleted = false;
  bool _levelProgressSaved = false;
  bool _showSuccess = false;
  String? _selectedAnswer;
  bool _answerChecked = false;
  final List<String> _selectedMultipleAnswers = [];
  final TextEditingController _textAnswerController = TextEditingController();
  String _textAnswer = '';
  late Future<List<Task>> _tasksFuture;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<bool> _taskResults = [];

  final VoiceCacheService _voiceCache = VoiceCacheService();
  bool _isAudioLoading = false;

  @override
  void initState() {
    super.initState();
    _tasksFuture = Future.value(widget.tasks.map((t) => Task.fromMap(t)).toList());
    _voiceCache.init();
  }

  @override
  void dispose() {
    _textAnswerController.dispose();
    super.dispose();
  }

  List<String> _parseOptions(String optionsJson) {
    try {
      final List<dynamic> decoded = jsonDecode(optionsJson);
      return decoded.map((e) => e.toString()).toList();
    } catch (e) {
      return [];
    }
  }

  void _checkAnswer() async {
    if (_answerChecked) return;

    if (_selectedAnswer == null && _selectedMultipleAnswers.isEmpty && _textAnswer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите или введите ответ')),
      );
      return;
    }

    final tasks = await _tasksFuture;
    final currentTask = tasks[_currentTaskIndex];
    bool isCorrect = false;

    switch (currentTask.type) {
      case 'multiple':
        List<String> correctAnswers = [];
        try {
          final decoded = jsonDecode(currentTask.correctAnswer);
          if (decoded is List) {
            correctAnswers = decoded.map((e) => e.toString().trim().toLowerCase()).toList();
          } else {
            correctAnswers = currentTask.correctAnswer
                .split(',')
                .map((s) => s.trim().toLowerCase())
                .toList();
          }
        } catch (e) {
          correctAnswers = currentTask.correctAnswer
              .split(',')
              .map((s) => s.trim().toLowerCase())
              .toList();
        }

        final selectedAnswers = _selectedMultipleAnswers
            .map((s) => s.trim().toLowerCase())
            .toList();

        correctAnswers.sort();
        selectedAnswers.sort();

        isCorrect = correctAnswers.join(',') == selectedAnswers.join(',');
        break;

      case 'audio_write':
        final userAnswer = _textAnswer.trim().toLowerCase();
        final correctAnswer = currentTask.correctAnswer.trim().toLowerCase();
        isCorrect = userAnswer == correctAnswer;
        break;

      default:
        isCorrect = _selectedAnswer?.trim().toLowerCase() ==
            currentTask.correctAnswer.trim().toLowerCase();
        break;
    }

    setState(() {
      _answerChecked = true;
      if (isCorrect) {
        _taskResults.add(true);
        _showSuccess = true;
        debugPrint('✅ Правильно!');
      } else {
        _taskResults.add(false);
        _showSuccess = false;
        debugPrint('❌ Неправильно! Правильный ответ: ${currentTask.correctAnswer}');
      }
    });
  }

  Future<void> _saveProgress() async {
    if (_levelCompleted || _levelProgressSaved) return;

    _levelCompleted = true;
    _levelProgressSaved = true;

    // ✅ Проверяем, все ли задания решены правильно
    final allTasksCompleted = _taskResults.length == widget.tasks.length &&
        _taskResults.every((result) => result == true);

    if (!allTasksCompleted) {
      debugPrint('⚠️ Уровень ${widget.levelId} НЕ пройден (есть ошибки)');
      return;
    }

    debugPrint('✅ Уровень ${widget.levelId} пройден полностью!');

    final existingProgress = await AppDatabase.instance.getUserProgress(1);
    final existingForLevel = existingProgress.firstWhere(
          (p) => p.taskId == widget.levelId && p.sourceContext == 'task',
      orElse: () => UserProgress(userId: 1, taskId: widget.levelId, sourceContext: 'task'),
    );

    // ✅ Сохраняем ТОЛЬКО факт прохождения, score не трогаем
    await AppDatabase.instance.saveUserProgress(UserProgress(
      id: existingForLevel.id,
      userId: 1,
      taskId: widget.levelId,
      riddleId: null,
      sourceContext: 'task',
      isCompleted: true,
      attemptsCount: (existingForLevel.attemptsCount + 1),
      score: 0,  // Не храним очки в БД
    ));
  }

  void _nextTask() {
    _tasksFuture.then((tasks) async {
      if (_currentTaskIndex < tasks.length - 1) {
        setState(() {
          _currentTaskIndex++;
          _selectedAnswer = null;
          _answerChecked = false;
          _showSuccess = false;
          _selectedMultipleAnswers.clear();
          _textAnswerController.clear();
          _textAnswer = '';
        });
      } else {
        await _saveProgress();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ModuleLevelsPage(
                moduleId: widget.moduleId,
                moduleTitle: widget.moduleTitle,
              ),
            ),
          );
        }
      }
    });
  }

  Future<Uint8List?> _getAudioForTask(Task task) async {
    final audioText = task.audioText ?? task.questionText;
    if (audioText.isEmpty) return null;

    setState(() => _isAudioLoading = true);
    final audioBytes = await _voiceCache.getOrSynthesize(audioText);
    setState(() => _isAudioLoading = false);
    return audioBytes;
  }

  Widget _buildQuestionWidget(Task task) {
    final options = _parseOptions(task.optionsJson);

    switch (task.type) {
      case 'audio_recognition':
        return Column(
          children: [
            ElevatedButton.icon(
              onPressed: () async {
                final audioBytes = await _getAudioForTask(task);
                if (audioBytes != null) {
                  await TtsAudioPlayer.play(audioBytes, text: task.audioText ?? task.questionText);
                }
              },
              icon: const Icon(Icons.volume_up),
              label: const Text('Прослушать'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A4B47),
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(task.questionText, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            ...options.map((option) => RadioListTile<String>(
              title: Text(option),
              value: option,
              groupValue: _selectedAnswer,
              onChanged: _answerChecked ? null : (value) => setState(() => _selectedAnswer = value),
            )),
          ],
        );

      case 'audio_write':
        return Column(
          children: [
            ElevatedButton.icon(
              onPressed: () async {
                final audioBytes = await _getAudioForTask(task);
                if (audioBytes != null) {
                  await TtsAudioPlayer.play(audioBytes, text: task.audioText ?? task.questionText);
                }
              },
              icon: const Icon(Icons.volume_up),
              label: const Text('Прослушать'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A4B47),
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(task.questionText, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            TextField(
              controller: _textAnswerController,
              decoration: InputDecoration(
                hintText: 'Введите ответ...',
                border: const OutlineInputBorder(),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF0A4B47), width: 2),
                ),
              ),
              onChanged: (value) => _textAnswer = value,
            ),
          ],
        );

      case 'multiple':
        return Column(
          children: [
            Text(task.questionText, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            ...options.map((option) => CheckboxListTile(
              title: Text(option),
              value: _selectedMultipleAnswers.contains(option),
              onChanged: _answerChecked ? null : (checked) {
                setState(() {
                  if (checked == true) {
                    _selectedMultipleAnswers.add(option);
                  } else {
                    _selectedMultipleAnswers.remove(option);
                  }
                });
              },
            )),
          ],
        );

      case 'true_false':
        return Column(
          children: [
            Text(task.questionText, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            RadioListTile<String>(
              title: const Text('Правда'),
              value: 'true',
              groupValue: _selectedAnswer,
              onChanged: _answerChecked ? null : (value) => setState(() => _selectedAnswer = value),
            ),
            RadioListTile<String>(
              title: const Text('Ложь'),
              value: 'false',
              groupValue: _selectedAnswer,
              onChanged: _answerChecked ? null : (value) => setState(() => _selectedAnswer = value),
            ),
          ],
        );

      default:
        return Column(
          children: [
            Text(task.questionText, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            ...options.map((option) => RadioListTile<String>(
              title: Text(option),
              value: option,
              groupValue: _selectedAnswer,
              onChanged: _answerChecked ? null : (value) => setState(() => _selectedAnswer = value),
            )),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        if (!_levelCompleted && _answerChecked && !_levelProgressSaved) {
          await _saveProgress();
        }
      },
      child: BaseScaffold(
        scaffoldKey: _scaffoldKey,
        appBar: AppBar(
          title: Text('${widget.moduleTitle} - Уровень ${widget.level}'),
          backgroundColor: const Color(0xFF0A4B47),
          foregroundColor: Colors.white,
          leading: const SizedBox.shrink(),
          actions: [
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
          ],
        ),
        endDrawer: const AppDrawer(activeSection: DrawerActiveSection.learning),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: FutureBuilder<List<Task>>(
            future: _tasksFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Ошибка: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('Задания не найдены'));
              }

              final tasks = snapshot.data!;
              final currentTask = tasks[_currentTaskIndex];

              return Column(
                children: [
                  LinearProgressIndicator(
                    value: (_currentTaskIndex + 1) / tasks.length,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0A4B47)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Задание ${_currentTaskIndex + 1} из ${tasks.length}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: _buildQuestionWidget(currentTask),
                    ),
                  ),
                  if (_answerChecked)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _showSuccess ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _showSuccess ? Icons.check_circle : Icons.cancel,
                            color: _showSuccess ? Colors.green : Colors.red,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _showSuccess
                                  ? '✅ Правильно!'
                                  : '❌ Неправильно! Правильный ответ: ${currentTask.correctAnswer}',
                              style: TextStyle(
                                color: _showSuccess ? Colors.green : Colors.red,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (!_answerChecked)
                    ElevatedButton(
                      onPressed: _checkAnswer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A4B47),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Проверить', style: TextStyle(fontSize: 18)),
                    )
                  else
                    ElevatedButton(
                      onPressed: _nextTask,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A4B47),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: Text(
                        _currentTaskIndex < tasks.length - 1
                            ? '➡️ Следующее задание'
                            : '🎉 Завершить уровень',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}