import 'package:flutter/material.dart';
import '../services/app_database.dart';
import 'module_levels_page.dart';
import 'riddle_page.dart';
import 'translate_page.dart';
import 'main_menu_page.dart';
import 'translation_history_page.dart';

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
  List<String> _selectedMultipleAnswers = [];
  late Future<List<Map<String, dynamic>>> _tasksFuture;

  @override
  void initState() {
    super.initState();
    _score = widget.initialScore;
    _tasksFuture = widget.tasks != null
        ? Future.value(widget.tasks!)
        : AppDatabase().getTasks(widget.moduleId, widget.level);
    _checkIfLastLevel();
  }

  Future<void> _checkIfLastLevel() async {
    final levels = await AppDatabase().getModuleLevels(widget.moduleId);
    final maxLevel = levels.last['level'] as int;
    setState(() {
      _isLastLevel = widget.level >= maxLevel;
    });
  }

  void _checkAnswer() {
    if (_selectedAnswer == null && _selectedMultipleAnswers.isEmpty) return;

    _tasksFuture.then((tasks) {
      final currentTask = tasks[_currentTaskIndex];
      final isCorrect = currentTask['type'] == 'multiple'
          ? _selectedMultipleAnswers.contains(currentTask['correct_answer'])
          : _selectedAnswer == currentTask['correct_answer'];

      setState(() {
        _answerChecked = true;
        if (isCorrect) {
          _score += currentTask['points'] as int;
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
      await AppDatabase().saveUserProgress(widget.moduleId, widget.level, _score);
      final totalScore = await AppDatabase().getUserTotalScore();
      final solvedRiddlesCount = await AppDatabase().getCompletedRiddlesCount();
      await AppDatabase().saveRiddleProgress(solvedRiddlesCount, totalScore);

      final levels = await AppDatabase().getModuleLevels(widget.moduleId);
      final nextLevel = widget.level + 1;
      final hasNextLevel = levels.any((l) => l['level'] == nextLevel);

      if (hasNextLevel) {
        final nextLevelTasks = await AppDatabase().getTasks(widget.moduleId, nextLevel);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TaskPage(
              moduleId: widget.moduleId,
              level: nextLevel,
              moduleTitle: widget.moduleTitle,
              tasks: nextLevelTasks,
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
          AppDatabase().getRiddles().then((riddlesList) {
            if (riddlesList.isNotEmpty) {
              final int riddleNumber = (_score ~/ 100) - 1;
              if (riddleNumber < riddlesList.length) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RiddlePage(
                      riddleIndex: riddleNumber,
                      userScore: _score,
                      riddles: riddlesList,
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

  Widget _buildQuestionWidget(Map<String, dynamic> task) {
    switch (task['type'] ?? 'single') {
      case 'true_false':
        return Column(
          children: [
            Text(task['question'], style: const TextStyle(fontSize: 20)),
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
            Text(task['question'], style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            ...(task['options'] as List).map((option) => CheckboxListTile(
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
            Text(task['question'], style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            ...(task['options'] as List).map((option) => RadioListTile<String>(
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
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.moduleTitle} - Уровень ${widget.level}'),
        backgroundColor: const Color(0xFF0A4B47),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<List<Map<String, dynamic>>>(
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