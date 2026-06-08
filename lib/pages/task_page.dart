import 'dart:convert';
import 'package:flutter/material.dart';
import '../base_scafford.dart';
import '../models/phrasebook_entities.dart';
import '../services/app_database.dart';
import '../widgets/app_drawer.dart';
import 'module_levels_page.dart';
import '../models/learning_entities.dart';

class TaskPage extends StatefulWidget {
  final int moduleId;
  final int levelId;
  final int level;
  final String moduleTitle;
  final List<Map<String, dynamic>> tasks;
  final int initialScore;

  const TaskPage({
    super.key,
    required this.moduleId,
    required this.levelId,
    required this.level,
    required this.moduleTitle,
    required this.tasks,
    required this.initialScore,
  });

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  int _currentTaskIndex = 0;
  int _score = 0;
  bool _showSuccess = false;
  String? _selectedAnswer;
  bool _answerChecked = false;
  final List<String> _selectedMultipleAnswers = [];
  late Future<List<Task>> _tasksFuture;
  bool _levelCompleted = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _score = widget.initialScore;
    _tasksFuture = Future.value(widget.tasks.map((t) => Task.fromMap(t)).toList());
  }

  @override
  void dispose() {
    if (_answerChecked && !_levelCompleted) {
      _saveProgressOnClose();
    }
    super.dispose();
  }

  Future<void> _saveProgressOnClose() async {
    await AppDatabase.instance.saveUserProgress(UserProgress(
      userId: 1,
      taskId: widget.levelId,
      riddleId: null,
      sourceContext: 'task',
      isCompleted: false,
      attemptsCount: 1,
      score: _score,
    ));
  }

  List<String> _parseOptions(String optionsJson) {
    try {
      final List<dynamic> decoded = jsonDecode(optionsJson);
      return decoded.map((e) => e.toString()).toList();
    } catch (e) {
      return [];
    }
  }

  void _checkAnswer() {
    if (_selectedAnswer == null && _selectedMultipleAnswers.isEmpty) return;

    _tasksFuture.then((tasks) {
      final currentTask = tasks[_currentTaskIndex];
      bool isCorrect = false;

      if (currentTask.type == 'multiple') {
        List<String> correctAnswers = [];
        try {
          final decoded = jsonDecode(currentTask.correctAnswer);
          if (decoded is List) {
            correctAnswers = decoded.map((e) => e.toString().toLowerCase().trim()).toList();
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
      } else {
        isCorrect = _selectedAnswer?.trim().toLowerCase() ==
            currentTask.correctAnswer.trim().toLowerCase();
      }

      setState(() {
        _answerChecked = true;
        if (isCorrect) {
          _score += 10;
          _showSuccess = true;
        } else {
          _showSuccess = false;
        }
      });
    });
  }

  Future<void> _saveProgress() async {
    if (_levelCompleted) return;
    _levelCompleted = true;

    await AppDatabase.instance.saveUserProgress(UserProgress(
      userId: 1,
      taskId: widget.levelId,
      riddleId: null,
      sourceContext: 'task',
      isCompleted: true,
      attemptsCount: 1,
      score: _score,
    ));
  }

  void _nextTask() {
    if (_currentTaskIndex < widget.tasks.length - 1) {
      setState(() {
        _currentTaskIndex++;
        _selectedAnswer = null;
        _answerChecked = false;
        _showSuccess = false;
        _selectedMultipleAnswers.clear();
      });
    } else {
      _saveProgress().then((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ModuleLevelsPage(
              moduleId: widget.moduleId,
              moduleTitle: widget.moduleTitle,
            ),
          ),
        );
      });
    }
  }

  Widget _buildQuestionWidget(Task task) {
    final options = _parseOptions(task.optionsJson);

    switch (task.type) {
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
      case 'multiple':
        return Column(
          children: [
            Text(task.questionText, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            ...options.map((option) => CheckboxListTile(
              title: Text(option),
              value: _selectedMultipleAnswers.contains(option),
              onChanged: _answerChecked
                  ? null
                  : (checked) {
                setState(() {
                  if (checked == true) {
                    _selectedMultipleAnswers.add(option);
                  } else {
                    _selectedMultipleAnswers.remove(option);
                  }
                });
              },
            )),
            const SizedBox(height: 10),
            Text(
              'Выбрано: ${_selectedMultipleAnswers.length} из ${options.length}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
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
        if (!_levelCompleted && _answerChecked) {
          await _saveProgressOnClose();
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
                return Center(child: Text('Ошибка загрузки заданий: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('Задания не найдены'));
              }

              final tasks = snapshot.data!;
              final currentTask = tasks[_currentTaskIndex];

              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: _buildQuestionWidget(currentTask),
                    ),
                  ),
                  if (_answerChecked)
                    Text(
                      _showSuccess ? '✅ Правильно! +10 очков' : '❌ Неправильно!',
                      style: TextStyle(
                        color: _showSuccess ? Colors.green : Colors.red,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text('💰 Счет: $_score', style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 20),
                  if (!_answerChecked)
                    ElevatedButton(
                      onPressed: _checkAnswer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A4B47),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Проверить', style: TextStyle(fontSize: 18)),
                    )
                  else
                    ElevatedButton(
                      onPressed: _nextTask,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A4B47),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: Text(
                        _currentTaskIndex < tasks.length - 1
                            ? '➡️ Следующее задание'
                            : ' Завершить уровень',
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