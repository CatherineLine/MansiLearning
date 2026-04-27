import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;
  AppDatabase._internal();

  static Database? _database;
  static int _currentUserId = 1; // ID пользователя по умолчанию

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'mansi_learning.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Таблица пользователей
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT DEFAULT 'Гость',
        total_xp INTEGER DEFAULT 0,
        level INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 2. Таблица модулей
    await db.execute('''
      CREATE TABLE modules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        order_index INTEGER NOT NULL
      )
    ''');

    // 3. Таблица уровней
    await db.execute('''
      CREATE TABLE levels (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        module_id INTEGER NOT NULL,
        level_number INTEGER NOT NULL,
        required_xp INTEGER DEFAULT 0,
        is_locked INTEGER DEFAULT 1,
        FOREIGN KEY (module_id) REFERENCES modules (id) ON DELETE CASCADE,
        UNIQUE(module_id, level_number)
      )
    ''');

    // 4. Таблица теории
    await db.execute('''
      CREATE TABLE theory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        level_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        FOREIGN KEY (level_id) REFERENCES levels (id) ON DELETE CASCADE
      )
    ''');

    // 5. Таблица заданий
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        level_id INTEGER NOT NULL,
        question TEXT NOT NULL,
        task_type TEXT NOT NULL,
        options TEXT NOT NULL,
        correct_answer TEXT NOT NULL,
        points INTEGER DEFAULT 10,
        order_index INTEGER DEFAULT 0,
        FOREIGN KEY (level_id) REFERENCES levels (id) ON DELETE CASCADE
      )
    ''');

    // 6. Таблица прогресса
    await db.execute('''
      CREATE TABLE user_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        module_id INTEGER NOT NULL,
        level INTEGER NOT NULL,
        score INTEGER DEFAULT 0,
        is_completed INTEGER DEFAULT 0,
        completed_at TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // 7. Таблица загадок
    await db.execute('''
      CREATE TABLE riddles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question TEXT NOT NULL,
        options TEXT NOT NULL,
        correct_answer TEXT NOT NULL,
        required_xp INTEGER DEFAULT 100,
        reward_points INTEGER DEFAULT 50
      )
    ''');

    // 8. Таблица решённых загадок
    await db.execute('''
      CREATE TABLE user_riddles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        riddle_id INTEGER NOT NULL,
        is_solved INTEGER DEFAULT 0,
        solved_at TEXT,
        reward_points INTEGER DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (riddle_id) REFERENCES riddles (id) ON DELETE CASCADE,
        UNIQUE(user_id, riddle_id)
      )
    ''');

    // 9. Таблица истории переводов
    await db.execute('''
      CREATE TABLE translations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        original_text TEXT NOT NULL,
        translated_text TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        direction TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Создаём пользователя по умолчанию
    await db.insert('users', {'id': 1, 'username': 'Гость', 'total_xp': 0, 'level': 1});

    // Заполняем начальными данными
    await _populateInitialData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Миграции при необходимости
  }

  Future<void> _populateInitialData(Database db) async {
    // Модули
    final modules = [
      (1, 'Фонетика мансийского языка', 1),
      (2, 'Грамматика (число и местоимения)', 2),
      (3, 'Лексика (термины родства)', 3),
      (4, 'Предложения с именным сказуемым', 4),
      (5, 'Разговорная тема "Знакомство"', 5),
      (6, 'Суффиксы прилагательных', 6),
      (7, 'Уменьшительные суффиксы', 7),
      (8, 'Притяжательное склонение', 8),
      (9, 'Местный падеж', 9),
      (10, 'Предложения наличия и местонахождения', 10),
    ];
    for (var m in modules) {
      await db.insert('modules', {'id': m.$1, 'title': m.$2, 'order_index': m.$3});
    }

    // Уровни (каждый модуль имеет 5 уровней)
    for (int moduleId = 1; moduleId <= 10; moduleId++) {
      for (int levelNum = 1; levelNum <= 5; levelNum++) {
        int levelId = (moduleId - 1) * 5 + levelNum;
        await db.insert('levels', {
          'id': levelId,
          'module_id': moduleId,
          'level_number': levelNum,
          'required_xp': (levelNum - 1) * 100,
          'is_locked': levelNum > 1 ? 1 : 0,
        });

        // Теория для уровней 1 и 3
        if (levelNum == 1 || levelNum == 3) {
          await db.insert('theory', {
            'level_id': levelId,
            'title': 'Теория к модулю $moduleId, уровень $levelNum',
            'content': 'Это теоретический материал для модуля $moduleId уровня $levelNum.',
          });
        }

        // Задания
        for (int taskNum = 1; taskNum <= 3; taskNum++) {
          await db.insert('tasks', {
            'level_id': levelId,
            'question': 'Задание $taskNum: Как правильно?',
            'task_type': 'single',
            'options': json.encode(['Вариант 1', 'Вариант 2', 'Вариант 3', 'Вариант 4']),
            'correct_answer': 'Вариант 1',
            'points': 10 * taskNum,
            'order_index': taskNum,
          });
        }
      }
    }

    // Загадки
    final riddles = [
      ('Что можно увидеть с закрытыми глазами?', json.encode(['Сон', 'Тьму', 'Свет', 'Звезды']), 'Сон'),
      ('Не лает, не кусает, а в дом не пускает?', json.encode(['Замок', 'Собака', 'Охрана', 'Дверь']), 'Замок'),
      ('Висит груша — нельзя скушать?', json.encode(['Лампочка', 'Фрукт', 'Игрушка', 'Картина']), 'Лампочка'),
    ];
    for (var r in riddles) {
      await db.insert('riddles', {
        'question': r.$1,
        'options': r.$2,
        'correct_answer': r.$3,
        'required_xp': 100,
        'reward_points': 50,
      });
    }
  }

  // ==================== СТАРЫЕ МЕТОДЫ (СОВМЕСТИМОСТЬ) ====================

  Future<void> initLearningMaterials() async {
    // Уже инициализировано в onCreate
    debugPrint('Learning materials initialized');
  }

  Future<Map<String, dynamic>?> getUserProgress(int moduleId) async {
    final db = await database;
    final result = await db.query(
      'user_progress',
      where: 'user_id = ? AND module_id = ?',
      whereArgs: [_currentUserId, moduleId],
    );
    if (result.isNotEmpty) {
      return {'level': result.first['level'], 'score': result.first['score']};
    }
    return {'level': 0, 'score': 0};
  }

  Future<int> getCompletedRiddlesCount() async {
    final db = await database;
    final result = await db.query(
      'user_riddles',
      where: 'user_id = ? AND is_solved = 1',
      whereArgs: [_currentUserId],
    );
    return result.length;
  }

  Future<int> getUserTotalScore() async {
    final db = await database;
    final result = await db.query(
      'user_progress',
      where: 'user_id = ?',
      whereArgs: [_currentUserId],
    );
    int total = 0;
    for (var r in result) {
      total += r['score'] as int;
    }
    return total;
  }

  Future<Map<String, dynamic>> getRiddleProgress() async {
    final solved = await getCompletedRiddlesCount();
    final totalScore = await getUserTotalScore();
    return {
      'solved_riddles': solved,
      'total_score': totalScore,
      'next_riddle_required_score': (solved + 1) * 100,
    };
  }

  Future<void> saveRiddleProgress(int solvedRiddles, int totalScore) async {
    // Обновляем XP пользователя
    final db = await database;
    await db.update(
      'users',
      {'total_xp': totalScore},
      where: 'id = ?',
      whereArgs: [_currentUserId],
    );
  }

  Future<List<Map<String, dynamic>>> getModuleLevels(int moduleId) async {
    final db = await database;
    final result = await db.query(
      'levels',
      where: 'module_id = ?',
      whereArgs: [moduleId],
      orderBy: 'level_number',
    );
    return result.map((level) => {
      'module': level['module_id'],
      'level': level['level_number'],
      'has_theory': true,
    }).toList();
  }

  Future<Map<String, dynamic>?> getTheory(int moduleId, int level) async {
    final db = await database;
    // Находим level_id по module_id и level_number
    final levelResult = await db.query(
      'levels',
      where: 'module_id = ? AND level_number = ?',
      whereArgs: [moduleId, level],
    );
    if (levelResult.isEmpty) return null;
    final levelId = levelResult.first['id'];

    final result = await db.query(
      'theory',
      where: 'level_id = ?',
      whereArgs: [levelId],
    );
    if (result.isNotEmpty) {
      return {'content': result.first['content']};
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getTasks(int moduleId, int level) async {
    final db = await database;
    final levelResult = await db.query(
      'levels',
      where: 'module_id = ? AND level_number = ?',
      whereArgs: [moduleId, level],
    );
    if (levelResult.isEmpty) return [];
    final levelId = levelResult.first['id'];

    final result = await db.query(
      'tasks',
      where: 'level_id = ?',
      whereArgs: [levelId],
      orderBy: 'order_index',
    );

    return result.map((task) {
      task['options'] = json.decode(task['options'] as String);
      return task;
    }).toList();
  }

  Future<void> saveUserProgress(int moduleId, int level, int score) async {
    final db = await database;
    final existing = await db.query(
      'user_progress',
      where: 'user_id = ? AND module_id = ? AND level = ?',
      whereArgs: [_currentUserId, moduleId, level],
    );

    if (existing.isNotEmpty) {
      await db.update(
        'user_progress',
        {'score': score, 'is_completed': 1, 'completed_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await db.insert('user_progress', {
        'user_id': _currentUserId,
        'module_id': moduleId,
        'level': level,
        'score': score,
        'is_completed': 1,
        'completed_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<List<Map<String, dynamic>>> getRiddles() async {
    final db = await database;
    final result = await db.query('riddles');
    return result;
  }

  Future<int> clearTranslationHistory() async {
    final db = await database;
    return await db.delete(
      'translations',
      where: 'user_id = ?',
      whereArgs: [_currentUserId],
    );
  }

  Future<int> removeDuplicateTranslations() async {
    final db = await database;
    final all = await db.query(
      'translations',
      where: 'user_id = ?',
      whereArgs: [_currentUserId],
      orderBy: 'timestamp DESC',
    );

    final seen = <String>{};
    int deleted = 0;

    for (var item in all) {
      final key = '${item['original_text']}|${item['translated_text']}';
      if (seen.contains(key)) {
        await db.delete('translations', where: 'id = ?', whereArgs: [item['id']]);
        deleted++;
      } else {
        seen.add(key);
      }
    }
    return deleted;
  }

  Future<Map<String, dynamic>> exportAllData() async {
    final db = await database;
    final records = await db.query(
      'translations',
      where: 'user_id = ?',
      whereArgs: [_currentUserId],
    );
    return {
      'version': 1,
      'export_date': DateTime.now().toIso8601String(),
      'data': records
    };
  }

  Future<int> importAllData(Map<String, dynamic> jsonData) async {
    final db = await database;
    final data = jsonData['data'] as List;
    int imported = 0;
    for (var item in data) {
      await db.insert('translations', {
        'user_id': _currentUserId,
        'original_text': item['original_text'],
        'translated_text': item['translated_text'],
        'timestamp': item['timestamp'] ?? DateTime.now().toIso8601String(),
        'direction': item['direction'] ?? '1 -> 2',
      });
      imported++;
    }
    return imported;
  }

  Future<List<Map<String, dynamic>>> getTranslationHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) async {
    final db = await database;
    String where = 'user_id = ?';
    List<Object?> whereArgs = [_currentUserId];

    if (startDate != null) {
      where += ' AND timestamp >= ?';
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      where += ' AND timestamp <= ?';
      whereArgs.add(endDate.toIso8601String());
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      where += ' AND (original_text LIKE ? OR translated_text LIKE ?)';
      whereArgs.add('%$searchQuery%');
      whereArgs.add('%$searchQuery%');
    }

    final result = await db.query(
      'translations',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
    );
    return result;
  }

  Future<int> addTranslation(String originalText, String translatedText, String timestamp, String direction) async {
    final db = await database;
    return await db.insert('translations', {
      'user_id': _currentUserId,
      'original_text': originalText,
      'translated_text': translatedText,
      'timestamp': timestamp,
      'direction': direction,
    });
  }
}