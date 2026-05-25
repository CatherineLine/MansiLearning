import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../models/translation_entities.dart' as te;

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
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';
    const booleanType = 'INTEGER NOT NULL';

    await db.execute('''CREATE TABLE users (id $idType, username $textType, created_at $textType, settings_json TEXT)''');
    await db.execute('''CREATE TABLE modules (id $idType, title $textType, description TEXT, order_index $integerType)''');
    await db.execute('''CREATE TABLE levels (id $idType, module_id $integerType, title $textType, difficulty $textType, FOREIGN KEY (module_id) REFERENCES modules (id) ON DELETE CASCADE)''');
    await db.execute('''CREATE TABLE theory (id $idType, level_id $integerType, content_html $textType, FOREIGN KEY (level_id) REFERENCES levels (id) ON DELETE CASCADE)''');
    await db.execute('''CREATE TABLE tasks (id $idType, level_id $integerType, question_text $textType, type $textType, correct_answer $textType, options_json TEXT, FOREIGN KEY (level_id) REFERENCES levels (id) ON DELETE CASCADE)''');
    await db.execute('''CREATE TABLE riddles (id $idType, question_text $textType, answer_text $textType, hint_text TEXT, difficulty_level TEXT, category TEXT)''');
    await db.execute('''CREATE TABLE user_progress (id $idType, user_id $integerType, task_id INTEGER, riddle_id INTEGER, source_context $textType, is_completed $booleanType, attempts_count $integerType, score $integerType, last_attempt $textType, FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE)''');
    await db.execute('''CREATE TABLE translations (id $idType, session_id $integerType, source_text $textType, target_text $textType, source_lang $textType, target_lang $textType, is_favorite $booleanType, created_at TEXT)''');

    // Тестовые данные
    await db.insert('modules', {'title': 'Основы мансийского', 'description': 'Базовый курс', 'order_index': 1});
    await db.insert('levels', {'module_id': 1, 'title': 'Уровень 1: Приветствия', 'difficulty': 'easy'});
    await db.insert('tasks', {'level_id': 1, 'question_text': 'Как переводится "Здравствуйте"?', 'type': 'choice', 'correct_answer': 'Паща о̄лэгыт', 'options_json': jsonEncode(['Паща о̄лэгыт', 'Кёинва', 'Лань'])});
    await db.insert('riddles', {'question_text': 'Зимой и летом одним цветом?', 'answer_text': 'Ель (Нёр)', 'difficulty_level': 'easy', 'category': 'nature'});
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('''CREATE TABLE IF NOT EXISTS riddles (id INTEGER PRIMARY KEY AUTOINCREMENT, question_text TEXT NOT NULL, answer_text TEXT NOT NULL, hint_text TEXT, difficulty_level TEXT, category TEXT)''');
      try { await db.execute('ALTER TABLE user_progress ADD COLUMN riddle_id INTEGER'); } catch (_) {}
    }
    if (oldVersion < 4) {
      try { await db.execute('ALTER TABLE translations ADD COLUMN created_at TEXT'); } catch (_) {}
    }
  }

  // === Переводы ===
  Future<int> addTranslation(te.Translation translation) async {
    final db = await database;
    final map = translation.toMap();
    map['session_id'] ??= 1;
    map['created_at'] ??= DateTime.now().toIso8601String();
    map['is_favorite'] = translation.isFavorite ? 1 : 0;
    return await db.insert('translations', map);
  }

  Future<List<Map<String, dynamic>>> getTranslationHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) async {
    final db = await database;
    final whereParts = <String>[];
    final whereArgs = <dynamic>[];

    if (startDate != null) { whereParts.add('created_at >= ?'); whereArgs.add(startDate.toIso8601String()); }
    if (endDate != null) { whereParts.add('created_at <= ?'); whereArgs.add(endDate.toIso8601String()); }
    if (searchQuery != null && searchQuery.isNotEmpty) { whereParts.add('source_text LIKE ? OR target_text LIKE ?'); whereArgs.addAll(['%$searchQuery%', '%$searchQuery%']); }

    return await db.query(
      'translations',
      where: whereParts.isNotEmpty ? whereParts.join(' AND ') : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'created_at DESC',
      limit: 100,
    );
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

  // === Модули обучения ===
  Future<List<Map<String, dynamic>>> getModules() async {
    final db = await database;
    return await db.query('modules', orderBy: 'order_index');
  }

  Future<List<Map<String, dynamic>>> getModuleLevels(int moduleId) async {
    final db = await database;
    return await db.query('levels', where: 'module_id = ?', whereArgs: [moduleId]);
  }

  Future<List<Map<String, dynamic>>> getTasks(int levelId) async {
    final db = await database;
    return await db.query('tasks', where: 'level_id = ?', whereArgs: [levelId]);
  }

  Future<List<Map<String, dynamic>>> getTheory(int moduleId, int level) async {
    final db = await database;
    return await db.query('theory', where: 'level_id = ?', whereArgs: [level]);
  }

  Future<List<Map<String, dynamic>>> getRiddles({String? category}) async {
    final db = await database;
    return category != null
        ? await db.query('riddles', where: 'category = ?', whereArgs: [category])
        : await db.query('riddles');
  }

  // === Прогресс пользователя ===
  Future<List<Map<String, dynamic>>> getUserProgress(int userId) async {
    final db = await database;
    return await db.query('user_progress', where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<int> saveUserProgress(Map<String, dynamic> data) async {
    final db = await database;
    final existing = data['id'];
    if (existing != null) {
      return await db.update('user_progress', data, where: 'id = ?', whereArgs: [existing]);
    }
    return await db.insert('user_progress', data);
  }

  Future<int> getCompletedRiddlesCount(int userId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM user_progress WHERE user_id = ? AND source_context = "riddle" AND is_completed = 1',
      [userId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getUserTotalScore(int userId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(score) as total FROM user_progress WHERE user_id = ?',
      [userId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Map<String, dynamic>?> getRiddleProgress(int userId, int riddleId) async {
    final db = await database;
    final maps = await db.query('user_progress', where: 'user_id = ? AND riddle_id = ?', whereArgs: [userId, riddleId]);
    return maps.isNotEmpty ? maps.first : null;
  }

  Future<int> saveRiddleProgress(int userId, int riddleId, bool isCompleted, int score) async {
    final existing = await getRiddleProgress(userId, riddleId);
    final db = await database;
    if (existing != null) {
      return await db.update('user_progress', {
        'is_completed': isCompleted || existing['is_completed'] == 1 ? 1 : 0,
        'attempts_count': (existing['attempts_count'] ?? 0) + 1,
        'score': score > (existing['score'] ?? 0) ? score : existing['score'],
        'last_attempt': DateTime.now().toIso8601String(),
        'source_context': 'riddle',
      }, where: 'id = ?', whereArgs: [existing['id']]);
    }
    return await db.rawInsert(
      'INSERT INTO user_progress (user_id, riddle_id, source_context, is_completed, attempts_count, score, last_attempt) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [userId, riddleId, 'riddle', isCompleted ? 1 : 0, 1, score, DateTime.now().toIso8601String()],
    );
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}