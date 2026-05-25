import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/app_database.dart';
import 'riddle_page.dart';
import 'main_menu_page.dart';

class ExercisePage extends StatefulWidget {
  final int moduleId;
  final int levelId;
  final String moduleTitle;
  const ExercisePage({super.key, required this.moduleId, required this.levelId, required this.moduleTitle});

  @override
  State<ExercisePage> createState() => _ExercisePageState();
}

class _ExercisePageState extends State<ExercisePage> {
  List<Map<String, dynamic>> _tasks = [];
  int _currentIndex = 0;
  int _score = 0;
  bool _isFinished = false;
  String? _selectedAnswer;
  bool _isChecked = false;
  final List<String> _multiSelect = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final tasks = await AppDatabase.instance.getTasks(widget.levelId);
    setState(() => _tasks = tasks.cast<Map<String, dynamic>>());
  }

  List<String> _parseOptions(String? jsonStr) {
    if (jsonStr == null) return [];
    try { return (jsonDecode(jsonStr) as List).map((e) => e.toString()).toList(); }
    catch (_) { return []; }
  }

  void _checkAnswer() {
    if (_selectedAnswer == null && _multiSelect.isEmpty) return;
    final task = _tasks[_currentIndex];
    final isCorrect = task['type'] == 'multiple'
        ? _multiSelect.contains(task['correct_answer'])
        : _selectedAnswer == task['correct_answer'];
    setState(() {
      _isChecked = true;
      if (isCorrect) _score += 10;
    });
  }

  Future<void> _finishLevel() async {
    await AppDatabase.instance.completeLevel(1, widget.levelId, widget.moduleId);
    final totalScore = await AppDatabase.instance.getUserTotalScore(1);
    final solved = await AppDatabase.instance.getCompletedRiddlesCount(1);
    await AppDatabase.instance.saveRiddleProgress(1, solved + 1, totalScore >= (solved + 1) * 100, totalScore);

    if (totalScore % 100 == 0 && totalScore > 0) {
      final riddles = await AppDatabase.instance.getRiddles();
      if (riddles.length > solved) {
        if (mounted) Navigator.push(context, MaterialPageRoute(
            builder: (_) => RiddlePage(riddleIndex: solved, userScore: totalScore, riddles: riddles.map((r) => r.toMap()).toList())
        ));
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Уровень завершён! +10 очков. Всего: $totalScore'), backgroundColor: Colors.green));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tasks.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final task = _tasks[_currentIndex];
    final options = _parseOptions(task['options_json']);

    return Scaffold(
      appBar: AppBar(title: Text('${widget.moduleTitle} - Уровень ${widget.levelId}'), backgroundColor: const Color(0xFF0A4B47), foregroundColor: Colors.white),
      body: Padding(padding: const EdgeInsets.all(16), child: Column(
        children: [
          LinearProgressIndicator(value: (_currentIndex + 1) / _tasks.length, backgroundColor: Colors.grey[200], valueColor: const AlwaysStoppedAnimation(Color(0xFF0A4B47))),
          const SizedBox(height: 20),
          Text(task['question_text'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          const SizedBox(height: 20),
          if (task['type'] == 'multiple') ...options.map((opt) => CheckboxListTile(
              title: Text(opt), value: _multiSelect.contains(opt),
              onChanged: _isChecked ? null : (v) => setState(() => v == true ? _multiSelect.add(opt) : _multiSelect.remove(opt))
          )).toList()
          else ...options.map((opt) => RadioListTile<String>(
              title: Text(opt), value: opt, groupValue: _selectedAnswer,
              onChanged: _isChecked ? null : (v) => setState(() => _selectedAnswer = v)
          )).toList(),
          const Spacer(),
          if (_isChecked) Text(_score > 0 ? 'Верно!' : 'Неверно', style: TextStyle(fontSize: 18, color: _score > 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isChecked
                ? (_currentIndex < _tasks.length - 1 ? () => setState(() { _currentIndex++; _selectedAnswer = null; _multiSelect.clear(); _isChecked = false; }) : _finishLevel)
                : _checkAnswer,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A4B47), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
            child: Text(_isChecked ? (_currentIndex < _tasks.length - 1 ? 'Далее' : 'Завершить уровень') : 'Проверить'),
          ),
        ],
      )),
    );
  }
}