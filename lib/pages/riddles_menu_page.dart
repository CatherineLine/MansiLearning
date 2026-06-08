// pages/riddles_menu_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_database.dart';
import '../widgets/app_drawer.dart';
import '../widgets/base_page.dart';
import 'riddle_page.dart';

class RiddlesMenuPage extends StatefulWidget {
  const RiddlesMenuPage({super.key});

  @override
  State<RiddlesMenuPage> createState() => _RiddlesMenuPageState();
}

class _RiddlesMenuPageState extends State<RiddlesMenuPage> {
  List<Map<String, dynamic>> _riddles = [];
  Map<int, bool> _riddleStatus = {};
  bool _isLoading = true;
  int _userTotalScore = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final riddlesData = await _loadRiddlesFromAssets();
      _riddles = List<Map<String, dynamic>>.from(riddlesData['riddles']);

      for (int i = 0; i < _riddles.length; i++) {
        _riddles[i]['id'] = i + 1;
      }

      await _loadUserProgress();
    } catch (e) {
      debugPrint('Ошибка загрузки загадок: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserProgress() async {
    final progressList = await AppDatabase.instance.getUserProgress(1);
    _riddleStatus.clear();

    for (var progress in progressList) {
      if (progress.sourceContext == 'riddle' && progress.riddleId != null) {
        _riddleStatus[progress.riddleId!] = progress.isCompleted;
      }
    }

    for (var riddle in _riddles) {
      final id = riddle['id'] as int;
      if (!_riddleStatus.containsKey(id)) {
        _riddleStatus[id] = false;
      }
    }

    _userTotalScore = await AppDatabase.instance.getUserTotalScore(1);
  }

  Future<Map<String, dynamic>> _loadRiddlesFromAssets() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/riddles.json');
      final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
      if (jsonMap.containsKey('riddles')) {
        final riddles = jsonMap['riddles'];
        if (riddles is List) {
          return {
            'riddles': List<Map<String, dynamic>>.from(
                riddles.map((r) => r as Map<String, dynamic>)
            )
          };
        }
      }
      throw Exception('Неверный формат riddles.json');
    } catch (e) {
      debugPrint('Ошибка загрузки riddles.json: $e');
      return {'riddles': []};
    }
  }

  int _getRequiredScoreForRiddle(int riddleNumber) {
    return riddleNumber * 100;
  }

  bool _isRiddleUnlocked(int riddleNumber) {
    final requiredScore = _getRequiredScoreForRiddle(riddleNumber);
    return _userTotalScore >= requiredScore;
  }

  Future<void> _openRiddle(int index) async {
    final riddle = _riddles[index];
    final riddleNumber = index + 1;
    final requiredScore = _getRequiredScoreForRiddle(riddleNumber);
    final isUnlocked = _isRiddleUnlocked(riddleNumber);
    final isCompleted = _riddleStatus[riddleNumber] ?? false;

    if (!isUnlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Нужно $requiredScore очков для открытия этой загадки\nУ вас: $_userTotalScore очков'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RiddlePage(
          riddleIndex: index,
          riddles: _riddles,
          isCompleted: isCompleted,
          requiredScore: requiredScore,
          userScore: _userTotalScore,
        ),
      ),
    );

    if (result == true) {
      await _loadUserProgress();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      title: "Загадки",
      activeSection: DrawerActiveSection.riddles,
      child: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0A4B47)),
        ),
      )
          : _riddles.isEmpty
          ? const Center(
        child: Text(
          'Загадки не найдены',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      )
          : Column(
        children: [
          // Блок с очками пользователя
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0A4B47),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '💰 Ваши очки:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_userTotalScore',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A4B47),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _riddles.length,
              itemBuilder: (context, index) {
                final riddleNumber = index + 1;
                final requiredScore = _getRequiredScoreForRiddle(riddleNumber);
                final isUnlocked = _isRiddleUnlocked(riddleNumber);
                final isCompleted = _riddleStatus[riddleNumber] ?? false;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () => _openRiddle(index),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? Colors.green.withOpacity(0.1)
                                  : (isUnlocked
                                  ? const Color(0xFF0A4B47).withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.1)),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Icon(
                              isCompleted
                                  ? Icons.check_circle
                                  : (isUnlocked
                                  ? Icons.lock_open
                                  : Icons.lock),
                              color: isCompleted
                                  ? Colors.green
                                  : (isUnlocked
                                  ? const Color(0xFF0A4B47)
                                  : Colors.grey),
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Загадка №$riddleNumber',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0A4B47),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0A4B47).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.star,
                                            size: 14,
                                            color: Colors.amber,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$requiredScore очков',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF0A4B47),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    if (isCompleted)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'Разгадано ✓',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ),
                                    if (!isCompleted && isUnlocked)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'Не разгадано',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ),
                                    if (!isUnlocked)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Не хватает ${requiredScore - _userTotalScore}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 18,
                            color: isUnlocked
                                ? const Color(0xFF0A4B47)
                                : Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}