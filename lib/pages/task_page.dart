import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/phrasebook_entities.dart';
import '../services/app_database.dart';
import 'module_levels_page.dart';
import 'riddle_page.dart';
import 'translate_page.dart';
import 'main_menu_page.dart';
import '../models/learning_entities.dart';

class TaskPage extends StatefulWidget {
  final int moduleId;
  final int level;
  final String moduleTitle;
  final List<Map<String, dynamic>> tasks;
  final int initialScore;
  const TaskPage({
    super.key,
    required this.moduleId,
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
  bool _isLastLevel = false;
  final List<String> _selectedMultipleAnswers = [];
  late Future<List<Task>> _tasksFuture;

  @override
  void initState() {
    super.initState();
    _score = widget.initialScore;
    _tasksFuture = Future.value(widget.tasks.map((t) => Task.fromMap(t)).toList());
    _checkIfLastLevel();
  }

  Future<void> _checkIfLastLevel() async {
    final levels = await AppDatabase.instance.getModuleLevels(widget.moduleId);
    if (levels.isNotEmpty) {
      // Исправлено: levels.last - это объект Level, доступ через точку
      final maxLevel = levels.last.id ?? 0;
      setState(() {
        _isLastLevel = widget.level >= maxLevel;
      });
    }
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
      final isCorrect = currentTask.type == 'multiple'
          ? _selectedMultipleAnswers.contains(currentTask.correctAnswer)
          : _selectedAnswer == currentTask.correctAnswer;
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

  void _nextTaskOrLevel(BuildContext context) async {
    if (_currentTaskIndex < widget.tasks.length - 1) {
      setState(() {
        _currentTaskIndex++;
        _selectedAnswer = null;
        _answerChecked = false;
        _showSuccess = false;
      });
    } else {
      final currentTask = widget.tasks[_currentTaskIndex];
      await AppDatabase.instance.saveUserProgress(UserProgress(
        userId: 1,
        taskId: currentTask['id'] as int? ?? 0,
        riddleId: null,
        sourceContext: 'task',
        isCompleted: true,
        attemptsCount: 1,
        score: _score + 20,
      ));
      final totalScore = await AppDatabase.instance.getUserTotalScore(1);
      final solvedRiddlesCount = await AppDatabase.instance.getCompletedRiddlesCount(1);
      await AppDatabase.instance.saveRiddleProgress(1, solvedRiddlesCount + 1, true, totalScore);
      final levels = await AppDatabase.instance.getModuleLevels(widget.moduleId);
      final nextLevel = widget.level + 1;
      final hasNextLevel = levels.any((l) => l.id == nextLevel);
      if (hasNextLevel) {
        final nextLevelTasks = await AppDatabase.instance.getTasks(widget.moduleId);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TaskPage(
              moduleId: widget.moduleId,
              level: nextLevel,
              moduleTitle: widget.moduleTitle,
              tasks: nextLevelTasks.map((t) => t.toMap()).toList(),
              initialScore: _score,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Модуль завершён!')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ModuleLevelsPage(
              moduleId: widget.moduleId,
              moduleTitle: widget.moduleTitle,
            ),
          ),
        );
        if (_score >= 100 && _score % 100 == 0) {
          AppDatabase.instance.getRiddles().then((riddlesList) {
            if (riddlesList.isNotEmpty) {
              final int riddleNumber = (_score ~/ 100) - 1;
              if (riddleNumber < riddlesList.length) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RiddlePage(
                      riddleIndex: riddleNumber,
                      userScore: _score,
                      riddles: riddlesList.map((r) => r.toMap()).toList(),
                    ),
                  ),
                );
              }
            }
          });
        }
      }
    }
  }

  Widget _buildQuestionWidget(Task task) {
    final options = _parseOptions(task.optionsJson);
    switch (task.type) { // Убрано ?? 'single'
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

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text('${widget.moduleTitle} - Уровень ${widget.level}'),
        backgroundColor: const Color(0xFF0A4B47),
        foregroundColor: Colors.white,
      ),
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
                    _showSuccess ? 'Правильно!' : 'Неправильно!',
                    style: TextStyle(
                      color: _showSuccess ? Colors.green : Colors.red,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const SizedBox(height: 10),
                Text('Счет: $_score', style: const TextStyle(fontSize: 18)),
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
                    onPressed: () => _nextTaskOrLevel(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A4B47),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: Text(
                      _currentTaskIndex < tasks.length - 1
                          ? 'Следующее задание'
                          : _isLastLevel ? 'Завершить модуль' : 'Следующий уровень',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
              ],
            );
          },
        ),
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