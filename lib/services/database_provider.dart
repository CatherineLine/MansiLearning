import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' as sqlite;
import 'package:path/path.dart' as path;
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';

abstract class DatabaseProvider {
  Future<void> init();

  Future<int> addTranslation(Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>> getTranslationHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  });
  Future<void> clearTranslationHistory();
  Future<void> removeDuplicateTranslations();
  Future<Map<String, dynamic>> exportAllData();
  Future<void> importAllData(Map<String, dynamic> data);

  Future<List<Map<String, dynamic>>> getModules();
  Future<List<Map<String, dynamic>>> getModuleLevels(int moduleId);
  Future<List<Map<String, dynamic>>> getTasks(int levelId);
  Future<List<Map<String, dynamic>>> getTheory(int moduleId, int level);
  Future<List<Map<String, dynamic>>> getRiddles({String? category});

  Future<List<Map<String, dynamic>>> getUserProgress(int userId);
  Future<int> saveUserProgress(Map<String, dynamic> data);
  Future<int> getCompletedRiddlesCount(int userId);
  Future<int> getUserTotalScore(int userId);
  Future<Map<String, dynamic>?> getRiddleProgress(int userId, int riddleId);
  Future<int> saveRiddleProgress(
      int userId,
      int riddleId,
      bool isCompleted,
      int score,
      );

  Future<Map<String, dynamic>> loadRiddlesFromAssets();

  Future<void> close();
}

class SqliteDatabaseProvider implements DatabaseProvider {
  sqlite.Database? _db;

  @override
  Future<void> init() async {
    final dbPath = await sqlite.getDatabasesPath();
    final db = await sqlite.openDatabase(
      path.join(dbPath, 'mansi_translator.db'),
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
    _db = db;
  }

  Future<void> _createDB(sqlite.Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';
    const booleanType = 'INTEGER NOT NULL';

    await db.execute('''
      CREATE TABLE users (
        id $idType, username $textType, created_at TEXT, settings_json TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE modules (
        id $idType, title $textType, description TEXT, order_index $integerType
      )
    ''');

    await db.execute('''
      CREATE TABLE levels (
        id $idType, module_id $integerType, title $textType, difficulty $textType,
        FOREIGN KEY (module_id) REFERENCES modules (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE theory (
        id $idType, module_id $integerType, level_id $integerType, content_html $textType,
        FOREIGN KEY (level_id) REFERENCES levels (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks (
        id $idType, level_id $integerType, module_id $integerType,
        question_text $textType, type $textType, correct_answer TEXT, options_json TEXT,
        FOREIGN KEY (level_id) REFERENCES levels (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE riddles (
        id $idType, question_text $textType, answer_text $textType,
        hint_text TEXT, difficulty_level TEXT, category TEXT,
        required_score $integerType DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE user_progress (
        id $idType, user_id $integerType, task_id INTEGER, phrase_id INTEGER,
        riddle_id INTEGER, source_context $textType, is_completed $booleanType,
        attempts_count $integerType, score $integerType, last_attempt TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE translations (
        id $idType, session_id $integerType, source_text $textType,
        target_text $textType, source_lang $textType, target_lang $textType,
        is_favorite $booleanType, created_at TEXT
      )
    ''');

    // Инициализация тестовых данных
    await db.insert('users', {
      'username': 'user1',
      'created_at': DateTime.now().toIso8601String(),
    });

    await db.insert('modules', {
      'title': 'Основы мансийского',
      'description': 'Базовый курс',
      'order_index': 1,
    });

    await db.insert('levels', {
      'module_id': 1,
      'title': 'Уровень 1: Приветствия',
      'difficulty': 'easy',
    });

    await db.insert('tasks', {
      'level_id': 1,
      'module_id': 1,
      'question_text': 'Как переводится "Здравствуйте"?',
      'type': 'choice',
      'correct_answer': 'Паща о̄лэгыт',
      'options_json': jsonEncode(['Паща о̄лэгыт', 'Кёинва', 'Лань']),
    });

    await db.insert('riddles', {
      'question_text': 'Зимой и летом одним цветом?',
      'answer_text': 'Ель (Нёр)',
      'difficulty_level': 'easy',
      'category': 'nature',
      'required_score': 100,
    });
  }

  Future<void> _onUpgrade(sqlite.Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS riddles (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          question_text TEXT NOT NULL,
          answer_text TEXT NOT NULL,
          hint_text TEXT,
          difficulty_level TEXT,
          category TEXT,
          required_score INTEGER DEFAULT 0
        )
      ''');
      try {
        await db.execute('ALTER TABLE user_progress ADD COLUMN riddle_id INTEGER');
      } catch (_) {}
    }
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE translations ADD COLUMN created_at TEXT');
      } catch (_) {}
    }
  }

  @override
  Future<int> addTranslation(Map<String, dynamic> data) async {
    data['session_id'] ??= 1;
    data['created_at'] ??= DateTime.now().toIso8601String();
    return await _db!.insert('translations', data);
  }

  @override
  Future<List<Map<String, dynamic>>> getTranslationHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) async {
    final whereParts = <String>[];
    final whereArgs = <dynamic>[];

    if (startDate != null) {
      whereParts.add('created_at >= ?');
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      whereParts.add('created_at <= ?');
      whereArgs.add(endDate.toIso8601String());
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      whereParts.add('source_text LIKE ? OR target_text LIKE ?');
      whereArgs.addAll(['%$searchQuery%', '%$searchQuery%']);
    }

    return await _db!.query(
      'translations',
      where: whereParts.isNotEmpty ? whereParts.join(' AND ') : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'created_at DESC',
      limit: 100,
    );
  }

  @override
  Future<void> clearTranslationHistory() async {
    await _db!.delete('translations');
  }

  @override
  Future<void> removeDuplicateTranslations() async {
    await _db!.rawDelete('''
      DELETE FROM translations 
      WHERE id NOT IN (
        SELECT MAX(id) FROM translations 
        GROUP BY source_text, target_text
      )
    ''');
  }

  @override
  Future<Map<String, dynamic>> exportAllData() async {
    return {
      'export_date': DateTime.now().toIso8601String(),
      'users': await _db!.query('users'),
      'translations': await _db!.query('translations'),
      'progress': await _db!.query('user_progress'),
      'modules': await _db!.query('modules'),
      'levels': await _db!.query('levels'),
      'tasks': await _db!.query('tasks'),
      'riddles': await _db!.query('riddles'),
    };
  }

  @override
  Future<void> importAllData(Map<String, dynamic> data) async {
    await _db!.transaction((txn) async {
      if (data['translations'] != null) {
        for (var item in List<Map<String, dynamic>>.from(data['translations'])) {
          final map = Map<String, dynamic>.from(item);
          map['session_id'] ??= 1;
          await txn.insert('translations', map,
              conflictAlgorithm: sqlite.ConflictAlgorithm.ignore);
        }
      }
      if (data['progress'] != null) {
        for (var item in List<Map<String, dynamic>>.from(data['progress'])) {
          await txn.insert('user_progress', item,
              conflictAlgorithm: sqlite.ConflictAlgorithm.replace);
        }
      }
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getModules() async {
    return await _db!.query('modules', orderBy: 'order_index');
  }

  @override
  Future<List<Map<String, dynamic>>> getModuleLevels(int moduleId) async {
    return await _db!.query('levels',
        where: 'module_id = ?', whereArgs: [moduleId]);
  }

  @override
  Future<List<Map<String, dynamic>>> getTasks(int levelId) async {
    return await _db!.query('tasks',
        where: 'level_id = ?', whereArgs: [levelId]);
  }

  @override
  Future<List<Map<String, dynamic>>> getTheory(int moduleId, int level) async {
    return await _db!.query('theory',
        where: 'module_id = ? AND level_id = ?', whereArgs: [moduleId, level]);
  }

  @override
  Future<List<Map<String, dynamic>>> getRiddles({String? category}) async {
    return category != null
        ? await _db!.query('riddles',
        where: 'category = ?', whereArgs: [category])
        : await _db!.query('riddles');
  }

  @override
  Future<List<Map<String, dynamic>>> getUserProgress(int userId) async {
    return await _db!.query('user_progress',
        where: 'user_id = ?', whereArgs: [userId]);
  }

  @override
  Future<int> saveUserProgress(Map<String, dynamic> data) async {
    final existing = data['id'];
    if (existing != null) {
      return await _db!.update('user_progress', data,
          where: 'id = ?', whereArgs: [existing]);
    }
    return await _db!.insert('user_progress', data);
  }

  @override
  Future<int> getCompletedRiddlesCount(int userId) async {
    final result = await _db!.rawQuery(
      'SELECT COUNT(*) as count FROM user_progress WHERE user_id = ? AND source_context = "riddle" AND is_completed = 1',
      [userId],
    );
    return sqlite.Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<int> getUserTotalScore(int userId) async {
    final result = await _db!.rawQuery(
      'SELECT SUM(score) as total FROM user_progress WHERE user_id = ?',
      [userId],
    );
    return sqlite.Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<Map<String, dynamic>?> getRiddleProgress(
      int userId, int riddleId) async {
    final maps = await _db!.query('user_progress',
        where: 'user_id = ? AND riddle_id = ?', whereArgs: [userId, riddleId]);
    return maps.isNotEmpty ? maps.first : null;
  }

  @override
  Future<int> saveRiddleProgress(
      int userId, int riddleId, bool isCompleted, int score) async {
    final existing = await getRiddleProgress(userId, riddleId);
    if (existing != null) {
      return await _db!.update('user_progress', {
        'is_completed': isCompleted || (existing['is_completed'] == 1) ? 1 : 0,
        'attempts_count': (existing['attempts_count'] ?? 0) + 1,
        'score': score > (existing['score'] ?? 0) ? score : existing['score'],
        'last_attempt': DateTime.now().toIso8601String(),
        'source_context': 'riddle',
      }, where: 'id = ?', whereArgs: [existing['id']]);
    }
    return await _db!.rawInsert(
        'INSERT INTO user_progress (user_id, riddle_id, source_context, is_completed, attempts_count, score, last_attempt) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          userId,
          riddleId,
          'riddle',
          isCompleted ? 1 : 0,
          1,
          score,
          DateTime.now().toIso8601String()
        ]);
  }

  @override
  Future<Map<String, dynamic>> loadRiddlesFromAssets() async {
    // Для SQLite загадки хранятся в БД, возвращаем их
    final riddles = await _db!.query('riddles');
    return {'riddles': riddles};
  }

  @override
  Future<void> close() async {
    await _db?.close();
  }
}

/// Реализация для веба (Hive)
class HiveDatabaseProvider implements DatabaseProvider {
  late Box _box;
  static const String _translationsKey = 'translations';
  static const String _progressKey = 'progress';
  static const String _modulesKey = 'modules';
  static const String _levelsKey = 'levels';
  static const String _tasksKey = 'tasks';
  static const String _riddlesKey = 'riddles';
  static const String _usersKey = 'users';
  static const String _theoryKey = 'theory';

  @override
  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox('mansi_translator_web');

    final tables = [
      _translationsKey,
      _progressKey,
      _modulesKey,
      _levelsKey,
      _tasksKey,
      _riddlesKey,
      _usersKey,
      _theoryKey,
    ];

    for (final table in tables) {
      if (_box.get(table) == null) {
        await _box.put(table, <Map<String, dynamic>>[]);
      }
    }

    // Инициализация тестовых данных
    if (_box.get(_modulesKey)!.isEmpty) {
      await _saveTable(_modulesKey, [
        {
          'id': 1,
          'title': 'Основы мансийского',
          'description': 'Базовый курс',
          'order_index': 1,
        }
      ]);

      await _saveTable(_levelsKey, [
        {
          'id': 1,
          'module_id': 1,
          'title': 'Уровень 1: Приветствия',
          'difficulty': 'easy',
        }
      ]);

      await _saveTable(_tasksKey, [
        {
          'id': 1,
          'level_id': 1,
          'module_id': 1,
          'question_text': 'Как переводится "Здравствуйте"?',
          'type': 'choice',
          'correct_answer': 'Паща о̄лэгыт',
          'options': ['Паща о̄лэгыт', 'Кёинва', 'Лань'],
        }
      ]);

      await _saveTable(_riddlesKey, [
        {
          'id': 1,
          'question_text': 'Зимой и летом одним цветом?',
          'answer_text': 'Ель (Нёр)',
          'difficulty_level': 'easy',
          'category': 'nature',
          'required_score': 100,
        }
      ]);

      await _saveTable(_usersKey, [
        {
          'id': 1,
          'username': 'user1',
          'created_at': DateTime.now().toIso8601String(),
        }
      ]);
    }
  }

  List<Map<String, dynamic>> _getTable(String key) {
    return List<Map<String, dynamic>>.from(_box.get(key) ?? []);
  }

  Future<void> _saveTable(String key, List<Map<String, dynamic>> data) async {
    await _box.put(key, data);
  }

  int _generateId(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return 1;
    return (list.map((e) => e['id'] as int? ?? 0).reduce((a, b) => a > b ? a : b)) + 1;
  }

  @override
  Future<int> addTranslation(Map<String, dynamic> data) async {
    final allData = _getTable(_translationsKey);
    data['id'] = _generateId(allData);
    data['session_id'] ??= 1;
    data['created_at'] ??= DateTime.now().toIso8601String();
    allData.add(data);
    await _saveTable(_translationsKey, allData);
    return data['id'] as int;
  }

  @override
  Future<List<Map<String, dynamic>>> getTranslationHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) async {
    var results = _getTable(_translationsKey);

    if (startDate != null) {
      results = results.where((item) {
        final createdAt = DateTime.tryParse(item['created_at']?.toString() ?? '');
        return createdAt != null && !createdAt.isBefore(startDate);
      }).toList();
    }

    if (endDate != null) {
      results = results.where((item) {
        final createdAt = DateTime.tryParse(item['created_at']?.toString() ?? '');
        return createdAt != null && !createdAt.isAfter(endDate);
      }).toList();
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      results = results.where((item) {
        final sourceText = (item['source_text']?.toString() ?? '').toLowerCase();
        final targetText = (item['target_text']?.toString() ?? '').toLowerCase();
        return sourceText.contains(query) || targetText.contains(query);
      }).toList();
    }

    results.sort((a, b) {
      final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(0);
      final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(0);
      return bDate.compareTo(aDate);
    });

    if (results.length > 100) {
      results = results.take(100).toList();
    }

    return results;
  }

  @override
  Future<void> clearTranslationHistory() async {
    await _saveTable(_translationsKey, []);
  }

  @override
  Future<void> removeDuplicateTranslations() async {
    final allData = _getTable(_translationsKey);
    final seen = <String>{};
    final uniqueData = <Map<String, dynamic>>[];

    for (final item in allData) {
      final key = '${item['source_text']}_${item['target_text']}';
      if (!seen.contains(key)) {
        seen.add(key);
        uniqueData.add(item);
      }
    }

    await _saveTable(_translationsKey, uniqueData);
  }

  @override
  Future<Map<String, dynamic>> exportAllData() async {
    return {
      'export_date': DateTime.now().toIso8601String(),
      'users': _getTable(_usersKey),
      'translations': _getTable(_translationsKey),
      'progress': _getTable(_progressKey),
      'modules': _getTable(_modulesKey),
      'levels': _getTable(_levelsKey),
      'tasks': _getTable(_tasksKey),
      'riddles': _getTable(_riddlesKey),
    };
  }

  @override
  Future<void> importAllData(Map<String, dynamic> data) async {
    if (data['translations'] != null) {
      var translations = _getTable(_translationsKey);
      for (var item in List<Map<String, dynamic>>.from(data['translations'])) {
        final map = Map<String, dynamic>.from(item);
        map['session_id'] ??= 1;
        translations.add(map);
      }
      await _saveTable(_translationsKey, translations);
    }

    if (data['progress'] != null) {
      var progress = _getTable(_progressKey);
      for (var item in List<Map<String, dynamic>>.from(data['progress'])) {
        progress.add(item);
      }
      await _saveTable(_progressKey, progress);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getModules() async {
    return _getTable(_modulesKey);
  }

  @override
  Future<List<Map<String, dynamic>>> getModuleLevels(int moduleId) async {
    return _getTable(_levelsKey).where((item) => item['module_id'] == moduleId).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getTasks(int levelId) async {
    return _getTable(_tasksKey).where((item) => item['level_id'] == levelId).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getTheory(int moduleId, int level) async {
    return _getTable(_theoryKey)
        .where((item) => item['module_id'] == moduleId && item['level_id'] == level)
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getRiddles({String? category}) async {
    var riddles = _getTable(_riddlesKey);
    if (category != null) {
      riddles = riddles.where((item) => item['category'] == category).toList();
    }
    return riddles;
  }

  @override
  Future<List<Map<String, dynamic>>> getUserProgress(int userId) async {
    return _getTable(_progressKey).where((item) => item['user_id'] == userId).toList();
  }

  @override
  Future<int> saveUserProgress(Map<String, dynamic> data) async {
    final allData = _getTable(_progressKey);
    final existing = data['id'];

    if (existing != null) {
      for (int i = 0; i < allData.length; i++) {
        if (allData[i]['id'] == existing) {
          allData[i] = data;
          await _saveTable(_progressKey, allData);
          return existing as int;
        }
      }
    }

    data['id'] = _generateId(allData);
    allData.add(data);
    await _saveTable(_progressKey, allData);
    return data['id'] as int;
  }

  @override
  Future<int> getCompletedRiddlesCount(int userId) async {
    return _getTable(_progressKey)
        .where((item) =>
    item['user_id'] == userId &&
        item['source_context'] == 'riddle' &&
        item['is_completed'] == 1)
        .length;
  }

  @override
  Future<int> getUserTotalScore(int userId) async {
    final progress = _getTable(_progressKey)
        .where((item) => item['user_id'] == userId)
        .toList();
    return progress.fold<int>(0, (sum, item) => sum + (item['score'] as int? ?? 0));
  }

  @override
  Future<Map<String, dynamic>?> getRiddleProgress(int userId, int riddleId) async {
    final progress = _getTable(_progressKey);
    for (final item in progress) {
      if (item['user_id'] == userId && item['riddle_id'] == riddleId) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<int> saveRiddleProgress(
      int userId, int riddleId, bool isCompleted, int score) async {
    final existing = await getRiddleProgress(userId, riddleId);
    final allData = _getTable(_progressKey);

    if (existing != null) {
      for (int i = 0; i < allData.length; i++) {
        if (allData[i]['id'] == existing['id']) {
          allData[i] = {
            ...allData[i],
            'is_completed': isCompleted || existing['is_completed'] == 1 ? 1 : 0,
            'attempts_count': (existing['attempts_count'] ?? 0) + 1,
            'score': score > (existing['score'] ?? 0) ? score : existing['score'],
            'last_attempt': DateTime.now().toIso8601String(),
            'source_context': 'riddle',
          };
          await _saveTable(_progressKey, allData);
          return existing['id'] as int;
        }
      }
    }

    final newData = {
      'id': _generateId(allData),
      'user_id': userId,
      'riddle_id': riddleId,
      'source_context': 'riddle',
      'is_completed': isCompleted ? 1 : 0,
      'attempts_count': 1,
      'score': score,
      'last_attempt': DateTime.now().toIso8601String(),
    };
    allData.add(newData);
    await _saveTable(_progressKey, allData);
    return newData['id'] as int;
  }

  @override
  Future<Map<String, dynamic>> loadRiddlesFromAssets() async {
    final riddles = _getTable(_riddlesKey);
    return {'riddles': riddles};
  }

  @override
  Future<void> close() async {
    await _box.close();
  }
}

DatabaseProvider createDatabaseProvider() {
  if (kIsWeb) {
    return HiveDatabaseProvider();
  } else {
    return SqliteDatabaseProvider();
  }
}