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
    _database = await _initDB('mansi_translator_v2.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 4, // ✅ Увеличили версию для миграции
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';
    const booleanType = 'INTEGER NOT NULL';

    // 1. Users & Media
    await db.execute('''CREATE TABLE users (id $idType, username $textType, created_at $textType, settings_json TEXT)''');
    await db.execute('''CREATE TABLE media_assets (id $idType, file_path $textType, mime_type $textType, duration_sec INTEGER, checksum TEXT)''');

    // 2. Learning
    await db.execute('''CREATE TABLE modules (id $idType, title $textType, description TEXT, order_index $integerType)''');
    await db.execute('''CREATE TABLE levels (id $idType, module_id $integerType, title $textType, difficulty $textType, FOREIGN KEY (module_id) REFERENCES modules (id) ON DELETE CASCADE)''');
    await db.execute('''CREATE TABLE theory (id $idType, level_id $integerType, media_id INTEGER, content_html $textType, FOREIGN KEY (level_id) REFERENCES levels (id) ON DELETE CASCADE, FOREIGN KEY (media_id) REFERENCES media_assets (id) ON DELETE SET NULL)''');
    await db.execute('''CREATE TABLE tasks (id $idType, level_id $integerType, media_id INTEGER, question_text $textType, type $textType, correct_answer $textType, options_json $textType, FOREIGN KEY (level_id) REFERENCES levels (id) ON DELETE CASCADE, FOREIGN KEY (media_id) REFERENCES media_assets (id) ON DELETE SET NULL)''');

    // Riddles
    await db.execute('''CREATE TABLE riddles (id $idType, question_text $textType, answer_text $textType, hint_text TEXT, difficulty_level $textType, category TEXT)''');

    // 3. Progress
    await db.execute('''CREATE TABLE user_progress (id $idType, user_id $integerType, task_id INTEGER, phrase_id INTEGER, riddle_id INTEGER, source_context $textType, is_completed $booleanType, attempts_count $integerType, score $integerType, last_attempt $textType, FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE, FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE SET NULL, FOREIGN KEY (riddle_id) REFERENCES riddles (id) ON DELETE SET NULL)''');

    // 4. Translations
    await db.execute('''CREATE TABLE translation_sessions (id $idType, user_id $integerType, session_type $textType, started_at $textType, status $textType, FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE)''');

    // ✅ Исправлено: добавлены session_id (NOT NULL) и created_at
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

    await db.execute('''CREATE TABLE documents (id $idType, session_id $integerType, original_file_path $textType, translated_file_path TEXT, file_format $textType, status $textType, uploaded_at $textType, FOREIGN KEY (session_id) REFERENCES translation_sessions (id) ON DELETE CASCADE)''');

    // 5. Phrasebook
    await db.execute('''CREATE TABLE phrase_categories (id $idType, name $textType, icon_resource $textType)''');
    await db.execute('''CREATE TABLE phrases (id $idType, category_id $integerType, media_id INTEGER, text_mansi $textType, text_russian $textType, transcription TEXT, FOREIGN KEY (category_id) REFERENCES phrase_categories (id) ON DELETE CASCADE, FOREIGN KEY (media_id) REFERENCES media_assets (id) ON DELETE SET NULL)''');
    await db.execute('''CREATE TABLE user_phrasebook (user_id $integerType, phrase_id $integerType, is_favorite $booleanType, repetition_count $integerType, learned_at TEXT, PRIMARY KEY (user_id, phrase_id), FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE, FOREIGN KEY (phrase_id) REFERENCES phrases (id) ON DELETE CASCADE)''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('''CREATE TABLE IF NOT EXISTS riddles (id INTEGER PRIMARY KEY AUTOINCREMENT, question_text TEXT NOT NULL, answer_text TEXT NOT NULL, hint_text TEXT, difficulty_level TEXT, category TEXT)''');
      try { await db.execute('ALTER TABLE user_progress ADD COLUMN riddle_id INTEGER'); } catch (_) {}
    }
    // ✅ Миграция для версии 4: добавляем created_at в translations
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE translations ADD COLUMN created_at TEXT');
      } catch (_) {}
    }
  }

  Future<void> initLearningMaterials() async {
    final db = await database;
    var count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM modules'));
    if (count == 0) {
      await db.insert('modules', {'title': 'Основы мансийского', 'description': 'Базовый курс', 'order_index': 1});
      await db.insert('modules', {'title': 'Природа и быт', 'description': 'Тематическая лексика', 'order_index': 2});
      await db.insert('levels', {'module_id': 1, 'title': 'Уровень 1: Приветствия', 'difficulty': 'easy'});
      await db.insert('tasks', {'level_id': 1, 'question_text': 'Как переводится "Здравствуйте"?', 'type': 'choice', 'correct_answer': 'Кёинва', 'options_json': jsonEncode(['Кёинва', 'Пасяиба', 'Лань'])});
      await db.insert('riddles', {'question_text': 'Зимой и летом одним цветом?', 'answer_text': 'Ель (Нёр)', 'difficulty_level': 'easy', 'category': 'nature'});
      // ✅ Создаём сессию по умолчанию для переводов
      await db.insert('translation_sessions', {'id': 1, 'user_id': 1, 'session_type': 'default', 'started_at': DateTime.now().toIso8601String(), 'status': 'active'});
    }
  }

  // === LEARNING METHODS ===
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

  Future<List<Theory>> getTheory(int levelId, int level) async {
    final db = await database;
    return (await db.query('theory', where: 'level_id = ?', whereArgs: [levelId])).map((m) => Theory.fromMap(m)).toList();
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
    var result = await db.rawQuery('SELECT COUNT(*) as count FROM user_progress WHERE user_id = ? AND source_context = "riddle" AND is_completed = 1', [userId]);
    return Sqflite.firstIntValue(result[0]['count']) ?? 0;
  }

  Future<int> getUserTotalScore(int userId) async {
    final db = await database;
    var result = await db.rawQuery('SELECT SUM(score) as total FROM user_progress WHERE user_id = ?', [userId]);
    return Sqflite.firstIntValue(result[0]['total']) ?? 0;
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
    return await db.rawInsert('INSERT INTO user_progress (user_id, riddle_id, source_context, is_completed, attempts_count, score, last_attempt) VALUES (?, ?, ?, ?, ?, ?, ?)', [userId, riddleId, 'riddle', isCompleted ? 1 : 0, 1, score, DateTime.now().toIso8601String()]);
  }

  // === TRANSLATION METHODS ===
  Future<int> addTranslation(te.Translation translation) async {
    final db = await database;
    // ✅ Гарантируем session_id и created_at
    final map = translation.toMap();
    map['session_id'] ??= 1;
    map['created_at'] ??= DateTime.now().toIso8601String();
    return await db.insert('translations', map);
  }

  Future<List<Map<String, dynamic>>> getTranslationHistory({DateTime? startDate, DateTime? endDate, String? searchQuery}) async {
    final db = await database;
    // ✅ Сортируем по created_at DESC для правильного порядка
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
        for (var item in (data['users'] as List).cast<Map<String, dynamic>>()) {
          await txn.insert('users', item, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      if (data['translations'] != null) {
        for (var item in (data['translations'] as List).cast<Map<String, dynamic>>()) {
          final map = Map<String, dynamic>.from(item);
          map['session_id'] ??= 1; // ✅ Гарантируем session_id
          await txn.insert('translations', map, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
      if (data['progress'] != null) {
        for (var item in (data['progress'] as List).cast<Map<String, dynamic>>()) {
          await txn.insert('user_progress', item, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      if (data['modules'] != null) {
        for (var item in (data['modules'] as List).cast<Map<String, dynamic>>()) {
          await txn.insert('modules', item, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
      if (data['levels'] != null) {
        for (var item in (data['levels'] as List).cast<Map<String, dynamic>>()) {
          await txn.insert('levels', item, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
      if (data['tasks'] != null) {
        for (var item in (data['tasks'] as List).cast<Map<String, dynamic>>()) {
          await txn.insert('tasks', item, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
    });
  }
}

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