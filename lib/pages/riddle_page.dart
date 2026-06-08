// riddle_page.dart (обновлённая версия)
import 'package:flutter/material.dart';
import '../base_scafford.dart';
import '../services/app_database.dart';

class RiddlePage extends StatefulWidget {
  final int riddleIndex;
  final List<Map<String, dynamic>> riddles;
  final bool isCompleted;
  final int requiredScore;
  final int userScore;

  const RiddlePage({
    super.key,
    required this.riddleIndex,
    required this.riddles,
    required this.isCompleted,
    required this.requiredScore,
    required this.userScore,
  });

  @override
  State<RiddlePage> createState() => _RiddlePageState();
}

class _RiddlePageState extends State<RiddlePage> {
  String? _selectedAnswer;
  bool _answerChecked = false;
  bool _showSuccess = false;
  late final Map<String, dynamic> currentRiddle;
  String? _hintText;
  int _currentUserScore = 0;

  @override
  void initState() {
    super.initState();
    currentRiddle = widget.riddles[widget.riddleIndex];
    _hintText = currentRiddle['hint'] ?? currentRiddle['hint_text'];
    _loadCurrentScore();
  }

  Future<void> _loadCurrentScore() async {
    _currentUserScore = await AppDatabase.instance.getUserTotalScore(1);
    setState(() {});
  }

  Future<void> _checkAnswer() async {
    if (_selectedAnswer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите вариант ответа'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final isCorrect = _selectedAnswer == currentRiddle['correct_answer'];

    setState(() {
      _answerChecked = true;
      _showSuccess = isCorrect;
    });

    if (isCorrect && !widget.isCompleted) {
      await AppDatabase.instance.saveRiddleProgress(
        1,
        widget.riddleIndex + 1,
        true,
        0,
      );
    }
  }

  Future<void> _nextRiddle() async {
    final nextIndex = widget.riddleIndex + 1;

    if (nextIndex < widget.riddles.length) {
      // Проверяем, хватает ли очков для следующей загадки
      final nextRequiredScore = (nextIndex + 1) * 100;
      final currentScore = await AppDatabase.instance.getUserTotalScore(1);

      if (currentScore < nextRequiredScore) {
        // Показываем диалог о нехватке очков
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Недостаточно очков',
              style: TextStyle(color: Color(0xFF0A4B47), fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Для следующей загадки нужно $nextRequiredScore очков.\n'
                  'У вас: $currentScore очков.\n\n'
                  'Проходите обучение, чтобы заработать больше очков!',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context, true);
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF0A4B47),
                ),
                child: const Text('В меню'),
              ),
            ],
          ),
        );
        return;
      }

      // Если очков достаточно, переходим
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RiddlePage(
            riddleIndex: nextIndex,
            riddles: widget.riddles,
            isCompleted: false,
            requiredScore: nextRequiredScore,
            userScore: currentScore,
          ),
        ),
      );
    } else {
      // Последняя загадка
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Поздравляем!',
            style: TextStyle(color: Color(0xFF0A4B47), fontWeight: FontWeight.bold),
          ),
          content: const Text('Вы решили все загадки!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context, true);
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0A4B47),
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _showHint() {
    if (_hintText != null && _hintText!.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Подсказка',
            style: TextStyle(color: Color(0xFF0A4B47), fontWeight: FontWeight.bold),
          ),
          content: Text(_hintText!),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0A4B47),
              ),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Подсказки нет для этой загадки'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = List<String>.from(currentRiddle['options'] ?? []);

    return BaseScaffold(
      backgroundColor: const Color(0xFFE7E4DF),
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset("assets/images/logo.png"),
        ),
        title: Text(
          "Загадка №${widget.riddleIndex + 1}",
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.normal,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF0A4B47),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
      body: SafeArea(
        // SafeArea обеспечивает отступ от системных кнопок
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Статус и очки
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF0A4B47), width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '📖 Статус:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0A4B47),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.isCompleted
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.isCompleted ? 'Разгадано ✓' : 'Не разгадано',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: widget.isCompleted ? Colors.green : Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Требуемые очки
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A4B47).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '⭐ Требуется очков:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0A4B47),
                      ),
                    ),
                    Text(
                      '${widget.requiredScore}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A4B47),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Вопрос
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  currentRiddle['question'] ?? 'Вопрос не найден',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Кнопка подсказки
              if (_hintText != null && _hintText!.isNotEmpty && !_answerChecked)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: OutlinedButton.icon(
                    onPressed: _showHint,
                    icon: const Icon(Icons.lightbulb_outline, size: 18),
                    label: const Text('Подсказка'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0A4B47),
                      side: const BorderSide(color: Color(0xFF0A4B47)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),

              // Варианты ответов
              const Text(
                'Выберите ответ:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0A4B47),
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: ListView.builder(
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final isSelected = _selectedAnswer == option;

                    return GestureDetector(
                      onTap: (_answerChecked || widget.isCompleted) ? null : () {
                        setState(() {
                          _selectedAnswer = option;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF0A4B47).withOpacity(0.1)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF0A4B47)
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF0A4B47)
                                      : Colors.grey.shade400,
                                  width: 2,
                                ),
                                color: isSelected
                                    ? const Color(0xFF0A4B47)
                                    : Colors.transparent,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                option,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isSelected
                                      ? const Color(0xFF0A4B47)
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Результат
              if (_answerChecked)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _showSuccess ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _showSuccess ? Icons.check_circle : Icons.cancel,
                        color: _showSuccess ? Colors.green : Colors.red,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _showSuccess
                              ? 'Правильно! Загадка разгадана.'
                              : 'Неправильно! Правильный ответ: ${currentRiddle['correct_answer']}',
                          style: TextStyle(
                            fontSize: 16,
                            color: _showSuccess ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Кнопка действия
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _answerChecked
                      ? (widget.riddleIndex < widget.riddles.length - 1 ? _nextRiddle : null)
                      : (_answerChecked ? null : _checkAnswer),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A4B47),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: Colors.grey.shade400,
                  ),
                  child: Text(
                    !_answerChecked
                        ? 'Проверить ответ'
                        : (widget.riddleIndex < widget.riddles.length - 1
                        ? 'Следующая загадка →'
                        : 'Завершить'),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              // Отступ снизу для безопасной зоны
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}