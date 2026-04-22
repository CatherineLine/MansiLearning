import 'package:flutter/material.dart';
import '../services/app_database.dart';
import 'translate_page.dart';
import 'main_menu_page.dart';
import 'translation_history_page.dart';

class RiddlePage extends StatefulWidget {
  final int riddleIndex;
  final int userScore;
  final List<Map<String, dynamic>> riddles;

  const RiddlePage({
    super.key,
    required this.riddleIndex,
    required this.userScore,
    required this.riddles,
  });

  @override
  State<RiddlePage> createState() => _RiddlePageState();
}

class _RiddlePageState extends State<RiddlePage> {
  String? _selectedAnswer;
  bool _answerChecked = false;
  bool _showSuccess = false;
  late final Map<String, dynamic> currentRiddle;

  @override
  void initState() {
    super.initState();
    currentRiddle = widget.riddles[widget.riddleIndex];
  }

  void _checkAnswer() {
    setState(() {
      _answerChecked = true;
      if (_selectedAnswer == currentRiddle['correct_answer']) {
        _showSuccess = true;
        AppDatabase().saveRiddleProgress(widget.riddleIndex + 1, widget.userScore + 100);
      }
    });
  }

  void _nextRiddle(BuildContext context) {
    if (widget.riddleIndex < widget.riddles.length - 1 && _selectedAnswer == currentRiddle['correct_answer']) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RiddlePage(
            riddleIndex: widget.riddleIndex + 1,
            riddles: widget.riddles,
            userScore: widget.userScore + 100,
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Поздравляем!'),
          content: const Text('Вы решили все загадки!'),
          actions: [
            TextButton(onPressed: Navigator.of(context).pop, child: const Text('OK')),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset("assets/images/logo.png"),
        ),
        title: LayoutBuilder(
          builder: (context, constraints) {
            final fontSize = constraints.maxWidth > 600 ? 24.0 : 20.0;
            return Text(
              "Загадка",
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.normal),
            );
          },
        ),
        backgroundColor: const Color(0xFF0A4B47),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Загадка №${widget.riddleIndex + 1}', style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 10),
            Text(currentRiddle['question']),
            const SizedBox(height: 20),
            ...List<Widget>.from(
              (List<String>.from(currentRiddle['options'] ?? [])).map((option) {
                return RadioListTile<String>(
                  title: Text(option),
                  value: option,
                  groupValue: _selectedAnswer,
                  onChanged: _answerChecked ? null : (value) => setState(() => _selectedAnswer = value),
                );
              }),
            ),
            if (_answerChecked)
              Text(
                _showSuccess ? 'Правильно!' : 'Неправильно!',
                style: TextStyle(
                  color: _showSuccess ? Colors.green : Colors.red,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 10),
            Text('Очки: ${widget.userScore}'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _answerChecked ? () => _nextRiddle(context) : _checkAnswer,
              child: Text(_answerChecked ? 'Следующая загадка' : 'Проверить'),
            ),
          ],
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
            ListTile(
              title: const Text('Обучение', style: TextStyle(fontSize: 20, color: Color(0xFF0A4B47))),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MainMenuPage())),
            ),
            ListTile(
              title: const Text('История переводов', style: TextStyle(fontSize: 20, color: Colors.black)),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TranslationHistoryPage())),
            ),
          ],
        ),
      ),
    );
  }
}