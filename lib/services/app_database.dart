import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../models/learning_entities.dart';
import '../models/translation_entities.dart' as te;
import '../models/phrasebook_entities.dart' as pb;

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('mansi_translator_v5.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        await _seedDataIfEmpty(db);
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';
    const booleanType = 'INTEGER NOT NULL';

    // 1. Пользователи
    await db.execute('''CREATE TABLE users (id $idType, username $textType, created_at $textType, settings_json TEXT)''');

    // 2. Медиа
    await db.execute('''CREATE TABLE media_assets (id $idType, file_path $textType, mime_type $textType, duration_sec INTEGER, checksum TEXT)''');

    // 3. Модули обучения
    await db.execute('''CREATE TABLE modules (id $idType, title $textType, description TEXT, order_index $integerType)''');

    // 4. Уровни
    await db.execute('''CREATE TABLE levels (id $idType, module_id $integerType, title $textType, difficulty $textType, FOREIGN KEY (module_id) REFERENCES modules (id) ON DELETE CASCADE)''');

    // 5. Теория
    await db.execute('''CREATE TABLE theory (id $idType, level_id $integerType, media_id INTEGER, content_html $textType, FOREIGN KEY (level_id) REFERENCES levels (id) ON DELETE CASCADE, FOREIGN KEY (media_id) REFERENCES media_assets (id) ON DELETE SET NULL)''');

    // 6. Задания
    await db.execute('''CREATE TABLE tasks (id $idType, level_id $integerType, media_id INTEGER, question_text $textType, type $textType, correct_answer $textType, options_json $textType, FOREIGN KEY (level_id) REFERENCES levels (id) ON DELETE CASCADE, FOREIGN KEY (media_id) REFERENCES media_assets (id) ON DELETE SET NULL)''');

    // 7. Загадки
    await db.execute('''CREATE TABLE riddles (id $idType, question_text $textType, answer_text $textType, hint_text TEXT, difficulty_level $textType, category TEXT)''');

    // 8. Прогресс пользователя
    await db.execute('''CREATE TABLE user_progress (
      id $idType, 
      user_id $integerType, 
      task_id INTEGER, 
      phrase_id INTEGER, 
      riddle_id INTEGER, 
      level_id INTEGER,
      source_context $textType, 
      is_completed $booleanType, 
      attempts_count $integerType, 
      score $integerType, 
      last_attempt $textType, 
      FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE, 
      FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE SET NULL, 
      FOREIGN KEY (riddle_id) REFERENCES riddles (id) ON DELETE SET NULL
    )''');

    // 9. Сессии перевода
    await db.execute('''CREATE TABLE translation_sessions (id $idType, user_id $integerType, session_type $textType, started_at $textType, status $textType, FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE)''');

    // 10. Переводы
    await db.execute('''CREATE TABLE translations (
      id $idType,
      session_id $integerType,
      source_text $textType,
      target_text $textType,
      source_lang $textType,
      target_lang $textType,
      is_favorite $booleanType,
      created_at TEXT,
      FOREIGN KEY (session_id) REFERENCES translation_sessions (id) ON DELETE CASCADE
    )''');

    // 11. Документы
    await db.execute('''CREATE TABLE documents (id $idType, session_id $integerType, original_file_path $textType, translated_file_path TEXT, file_format $textType, status $textType, uploaded_at $textType, FOREIGN KEY (session_id) REFERENCES translation_sessions (id) ON DELETE CASCADE)''');

    // 12. Разговорник
    await db.execute('''CREATE TABLE phrase_categories (id $idType, name $textType, icon_resource $textType)''');
    await db.execute('''CREATE TABLE phrases (id $idType, category_id $integerType, media_id INTEGER, text_mansi $textType, text_russian $textType, transcription TEXT, FOREIGN KEY (category_id) REFERENCES phrase_categories (id) ON DELETE CASCADE, FOREIGN KEY (media_id) REFERENCES media_assets (id) ON DELETE SET NULL)''');
    await db.execute('''CREATE TABLE user_phrasebook (user_id $integerType, phrase_id $integerType, is_favorite $booleanType, repetition_count $integerType, learned_at TEXT, PRIMARY KEY (user_id, phrase_id), FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE, FOREIGN KEY (phrase_id) REFERENCES phrases (id) ON DELETE CASCADE)''');

    // 13. Практика слов
    await db.execute('''CREATE TABLE practice_words (
      id $idType,
      module_id $integerType,
      mansi_word $textType,
      russian_translation TEXT,
      transcription TEXT,
      note TEXT,
      created_at TEXT,
      FOREIGN KEY (module_id) REFERENCES modules (id) ON DELETE CASCADE
    )''');
  }

  Future<void> completeLevel(int userId, int levelId, int moduleId) async {
    final db = await database;

    var existing = await db.query(
        'user_progress',
        where: 'user_id = ? AND source_context = ? AND level_id = ?',
        whereArgs: [userId, 'level', levelId]
    );

    if (existing.isEmpty) {
      await db.insert('user_progress', {
        'user_id': userId,
        'level_id': levelId,
        'source_context': 'level',
        'is_completed': 1,
        'score': 10,
        'attempts_count': 1,
        'last_attempt': DateTime.now().toIso8601String(),
      });
      debugPrint('Уровень $levelId пройден! Начислено 10 очков.');
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('''CREATE TABLE IF NOT EXISTS riddles (id INTEGER PRIMARY KEY AUTOINCREMENT, question_text TEXT NOT NULL, answer_text TEXT NOT NULL, hint_text TEXT, difficulty_level TEXT, category TEXT)''');
      try { await db.execute('ALTER TABLE user_progress ADD COLUMN riddle_id INTEGER'); } catch (_) {}
    }
    if (oldVersion < 4) {
      try { await db.execute('ALTER TABLE translations ADD COLUMN created_at TEXT'); } catch (_) {}
    }
    if (oldVersion < 5) {
      try {
        await db.execute('''CREATE TABLE IF NOT EXISTS practice_words (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          module_id INTEGER,
          mansi_word TEXT NOT NULL,
          russian_translation TEXT,
          transcription TEXT,
          note TEXT,
          created_at TEXT
        )''');
      } catch (_) {}
    }
  }

  // Заполнение базы данных
  Future<void> _seedDataIfEmpty(Database db) async {
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM modules'));
    if (count == 0) {
      debugPrint('База данных пуста. Заполняем начальными данными...');

      // 1. Модуль 1: Звуки и произношение
      await db.insert('modules', {'id': 1, 'title': 'Звуки и произношение', 'description': 'Фонетика мансийского языка', 'order_index': 1});
      await db.insert('levels', {'id': 1, 'module_id': 1, 'title': 'Уровень 1: Гласные звуки', 'difficulty': 'easy'});
      await db.insert('tasks', {
        'id': 1, 'level_id': 1, 'question_text': 'Какой звук является долгим гласным?',
        'type': 'choice', 'correct_answer': 'ӓ',
        'options_json': jsonEncode(['а', 'ӓ', 'б', 'п'])
      });

      // 2. Модуль 2: Состав слова
      await db.insert('modules', {'id': 2, 'title': 'Состав слова', 'description': 'Морфология и словообразование', 'order_index': 2});
      await db.insert('levels', {'id': 2, 'module_id': 2, 'title': 'Уровень 1: Корень и суффикс', 'difficulty': 'medium'});
      await db.insert('tasks', {
        'id': 2, 'level_id': 2, 'question_text': 'Что такое суффикс?',
        'type': 'choice', 'correct_answer': 'Часть слова после корня',
        'options_json': jsonEncode(['Часть слова до корня', 'Часть слова после корня', 'Отдельное слово'])
      });

      // 3. Загадки
      await db.insert('riddles', {
        'id': 1, 'question_text': 'Зимой и летом одним цветом?',
        'answer_text': 'Ель (Нёр)', 'difficulty_level': 'easy', 'category': 'nature'
      });
      await db.insert('riddles', {
        'id': 2, 'question_text': 'Кто зимой ходит злой, голодный?',
        'answer_text': 'Волк', 'difficulty_level': 'easy', 'category': 'animals'
      });

      // 4. Сессия перевода
      await db.insert('translation_sessions', {
        'id': 1, 'user_id': 1, 'session_type': 'default',
        'started_at': DateTime.now().toIso8601String(), 'status': 'active'
      });

      debugPrint('✅ Начальные данные добавлены!');
    }
  }

  Future<List<Module>> getModules() async {
    final db = await database;
    return (await db.query('modules', orderBy: 'order_index')).map((m) => Module.fromMap(m)).toList();
  }

  Future<List<Level>> getModuleLevels(int moduleId) async {
    final db = await database;
    return (await db.query('levels', where: 'module_id = ?', whereArgs: [moduleId])).map((m) => Level.fromMap(m)).toList();
  }

  Future<List<Task>> getTasks(int levelId) async {
    final db = await database;
    return (await db.query('tasks', where: 'level_id = ?', whereArgs: [levelId])).map((m) => Task.fromMap(m)).toList();
  }

  Future<List<Theory>> getTheory(int moduleId, int level) async {
    final db = await database;
    // Получаем теорию для конкретного уровня
    return (await db.query('theory', where: 'level_id = ?', whereArgs: [level])).map((m) => Theory.fromMap(m)).toList();
  }

  Future<List<Riddle>> getRiddles({String? category}) async {
    final db = await database;
    final maps = category != null ? await db.query('riddles', where: 'category = ?', whereArgs: [category]) : await db.query('riddles');
    return maps.map((m) => Riddle.fromMap(m)).toList();
  }

  Future<List<pb.UserProgress>> getUserProgress(int userId) async {
    final db = await database;
    return (await db.query('user_progress', where: 'user_id = ?', whereArgs: [userId])).map((m) => pb.UserProgress.fromMap(m)).toList();
  }

  Future<int> saveUserProgress(pb.UserProgress progress) async {
    final db = await database;
    return progress.id != null
        ? await db.update('user_progress', progress.toMap(), where: 'id = ?', whereArgs: [progress.id])
        : await db.insert('user_progress', progress.toMap());
  }

  Future<int> getCompletedRiddlesCount(int userId) async {
    final db = await database;
    var result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM user_progress WHERE user_id = ? AND source_context = "riddle" AND is_completed = 1',
        [userId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getUserTotalScore(int userId) async {
    final db = await database;
    var result = await db.rawQuery(
        'SELECT SUM(score) as total FROM user_progress WHERE user_id = ?',
        [userId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<pb.UserProgress?> getRiddleProgress(int userId, int riddleId) async {
    final db = await database;
    final maps = await db.query('user_progress', where: 'user_id = ? AND riddle_id = ?', whereArgs: [userId, riddleId]);
    return maps.isNotEmpty ? pb.UserProgress.fromMap(maps.first) : null;
  }

  Future<int> saveRiddleProgress(int userId, int riddleId, bool isCompleted, int score) async {
    final existing = await getRiddleProgress(userId, riddleId);
    final db = await database;
    if (existing != null) {
      return await db.update('user_progress', {
        'is_completed': isCompleted || existing.isCompleted ? 1 : 0,
        'attempts_count': existing.attemptsCount + 1,
        'score': score > existing.score ? score : existing.score,
        'last_attempt': DateTime.now().toIso8601String(),
        'source_context': 'riddle',
      }, where: 'id = ?', whereArgs: [existing.id]);
    }
    return await db.rawInsert(
        'INSERT INTO user_progress (user_id, riddle_id, source_context, is_completed, attempts_count, score, last_attempt) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [userId, riddleId, 'riddle', isCompleted ? 1 : 0, 1, score, DateTime.now().toIso8601String()]);
  }

  Future<int> addTranslation(te.Translation translation) async {
    final db = await database;
    final map = translation.toMap();
    map['session_id'] ??= 1;
    map['created_at'] ??= DateTime.now().toIso8601String();
    return await db.insert('translations', map);
  }

  Future<List<Map<String, dynamic>>> getTranslationHistory(
      {DateTime? startDate, DateTime? endDate, String? searchQuery}) async {
    final db = await database;
    String orderBy = 'created_at DESC';
    if (startDate != null || endDate != null || searchQuery != null) {
      final whereParts = <String>[];
      final whereArgs = <dynamic>[];
      if (startDate != null) { whereParts.add('created_at >= ?'); whereArgs.add(startDate.toIso8601String()); }
      if (endDate != null) { whereParts.add('created_at <= ?'); whereArgs.add(endDate.toIso8601String()); }
      if (searchQuery != null) { whereParts.add('source_text LIKE ? OR target_text LIKE ?'); whereArgs.addAll(['%$searchQuery%', '%$searchQuery%']); }
      return await db.query('translations', where: whereParts.join(' AND '), whereArgs: whereArgs, orderBy: orderBy, limit: 100);
    }
    return await db.query('translations', orderBy: orderBy, limit: 100);
  }

  Future<void> clearTranslationHistory() async {
    final db = await database;
    await db.delete('translations');
  }

  Future<void> removeDuplicateTranslations() async {
    final db = await database;
    await db.rawDelete('''DELETE FROM translations WHERE id NOT IN (SELECT MAX(id) FROM translations GROUP BY source_text, target_text)''');
  }

  // ---------------------------------------------------------
  // Методы для Практики Слов
  // ---------------------------------------------------------

  Future<List<Map<String, dynamic>>> getPracticeWords(int moduleId) async {
    final db = await database;
    return await db.query(
      'practice_words',
      where: 'module_id = ?',
      whereArgs: [moduleId],
      orderBy: 'created_at DESC',
    );
  }

  Future<int> addPracticeWord(Map<String, dynamic> wordData) async {
    final db = await database;
    wordData['created_at'] ??= DateTime.now().toIso8601String();
    return await db.insert('practice_words', wordData);
  }

  Future<int> updatePracticeWord(int wordId, Map<String, dynamic> wordData) async {
    final db = await database;
    return await db.update(
      'practice_words',
      wordData,
      where: 'id = ?',
      whereArgs: [wordId],
    );
  }

  Future<int> deletePracticeWord(int wordId) async {
    final db = await database;
    return await db.delete(
      'practice_words',
      where: 'id = ?',
      whereArgs: [wordId],
    );
  }

  Future<Map<String, dynamic>> exportAllData() async {
    final db = await database;
    return {
      'export_date': DateTime.now().toIso8601String(),
      'users': await db.query('users'),
      'translations': await db.query('translations'),
      'progress': await db.query('user_progress'),
      'modules': await db.query('modules'),
      'levels': await db.query('levels'),
      'tasks': await db.query('tasks'),
      'riddles': await db.query('riddles'),
    };
  }

  Future<void> importAllData(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      if (data['users'] != null) {
        for (var item in List<Map<String, dynamic>>.from(data['users'])) {
          final map = Map<String, dynamic>.from(item);
          if (map.containsKey('name') && !map.containsKey('username')) {
            map['username'] = map['name'];
            map.remove('name');
          }
          map.removeWhere((key, value) =>
          !['id', 'username', 'created_at', 'settings_json'].contains(key));
          await txn.insert('users', map, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      if (data['translations'] != null) {
        for (var item in List<Map<String, dynamic>>.from(data['translations'])) {
          final map = Map<String, dynamic>.from(item);
          map['session_id'] ??= 1;
          await txn.insert('translations', map, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
      if (data['progress'] != null) {
        for (var item in List<Map<String, dynamic>>.from(data['progress'])) {
          await txn.insert('user_progress', item, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}

// Класс Riddle (на случай, если он не определен в другом файле)
class Riddle {
  final int? id;
  final String questionText;
  final String answerText;
  final String? hintText;
  final String? difficultyLevel;
  final String? category;

  Riddle({this.id, required this.questionText, required this.answerText, this.hintText, this.difficultyLevel, this.category});

  Map<String, dynamic> toMap() => {
    'id': id,
    'question_text': questionText,
    'answer_text': answerText,
    'hint_text': hintText,
    'difficulty_level': difficultyLevel,
    'category': category,
  };

  factory Riddle.fromMap(Map<String, dynamic> map) => Riddle(
    id: map['id'],
    questionText: map['question_text'],
    answerText: map['answer_text'],
    hintText: map['hint_text'],
    difficultyLevel: map['difficulty_level'],
    category: map['category'],
  );
}