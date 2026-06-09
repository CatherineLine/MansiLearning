import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
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
      version: 16,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';

    await db.execute('''CREATE TABLE users (id $idType, username $textType, created_at $textType, settings_json TEXT)''');
    await db.execute('''CREATE TABLE media_assets (id $idType, file_path $textType, mime_type $textType, duration_sec INTEGER, checksum TEXT)''');
    await db.execute('''CREATE TABLE modules (id $idType, title $textType, description TEXT, order_index $integerType)''');
    await db.execute('''CREATE TABLE levels (id $idType, module_id $integerType, title $textType, difficulty $textType, FOREIGN KEY (module_id) REFERENCES modules (id) ON DELETE CASCADE)''');
    await db.execute('''CREATE TABLE theory (id $idType, level_id $integerType, media_id INTEGER, content_html $textType, FOREIGN KEY (level_id) REFERENCES levels (id) ON DELETE CASCADE, FOREIGN KEY (media_id) REFERENCES media_assets (id) ON DELETE SET NULL)''');
    await db.execute('''CREATE TABLE tasks (id $idType, level_id $integerType, media_id INTEGER, question_text $textType, type $textType, correct_answer $textType, options_json $textType, audio_text TEXT, points $integerType DEFAULT 10, FOREIGN KEY (level_id) REFERENCES levels (id) ON DELETE CASCADE, FOREIGN KEY (media_id) REFERENCES media_assets (id) ON DELETE SET NULL)''');
    await db.execute('''CREATE TABLE riddles (id $idType, question_text $textType, answer_text $textType, hint_text TEXT, difficulty_level $textType, category TEXT)''');
    await db.execute('''CREATE TABLE user_progress (id $idType, user_id $integerType, task_id INTEGER, phrase_id INTEGER, riddle_id INTEGER, source_context $textType, is_completed $integerType, attempts_count $integerType, score $integerType, last_attempt $textType, FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE, FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE SET NULL, FOREIGN KEY (riddle_id) REFERENCES riddles (id) ON DELETE SET NULL)''');
    await db.execute('''CREATE TABLE translation_sessions (id $idType, user_id $integerType, session_type $textType, started_at $textType, status $textType, FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE)''');
    await db.execute('''CREATE TABLE translations (id $idType, session_id $integerType, source_text $textType, target_text $textType, source_lang $textType, target_lang $textType, is_favorite $integerType, created_at TEXT, FOREIGN KEY (session_id) REFERENCES translation_sessions (id) ON DELETE CASCADE)''');
    await db.execute('''CREATE TABLE documents (id $idType, session_id $integerType, original_file_path $textType, translated_file_path TEXT, file_format $textType, status $textType, uploaded_at $textType, FOREIGN KEY (session_id) REFERENCES translation_sessions (id) ON DELETE CASCADE)''');
    await db.execute('''CREATE TABLE phrase_categories (id $idType, name $textType, icon_resource $textType)''');
    await db.execute('''CREATE TABLE phrases (id $idType, category_id $integerType, media_id INTEGER, text_mansi $textType, text_russian $textType, transcription TEXT, FOREIGN KEY (category_id) REFERENCES phrase_categories (id) ON DELETE CASCADE, FOREIGN KEY (media_id) REFERENCES media_assets (id) ON DELETE SET NULL)''');
    await db.execute('''CREATE TABLE user_phrasebook (user_id $integerType, phrase_id $integerType, is_favorite $integerType, repetition_count $integerType, learned_at TEXT, PRIMARY KEY (user_id, phrase_id), FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE, FOREIGN KEY (phrase_id) REFERENCES phrases (id) ON DELETE CASCADE)''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 16) {
      // Добавляем колонку audio_text и points в таблицу tasks
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN audio_text TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN points INTEGER DEFAULT 10');
      } catch (_) {}
    }

    if (oldVersion < 15) {
      await _fixMultipleChoiceAnswers(db);
    }
  }

  Future<void> _fixMultipleChoiceAnswers(Database db) async {
    try {
      await db.update('tasks', {
        'correct_answer': '["Губы, язык, гортань"]',
      }, where: 'level_id = ? AND question_text = ?', whereArgs: [1, 'Что из перечисленного относится к органам речи?']);
    } catch (e) {
      debugPrint('Ошибка исправления: $e');
    }
  }

  /// Импорт модулей из JSON файла
  Future<void> importModulesFromJson() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/learning_modules.json');
      final Map<String, dynamic> data = json.decode(jsonString);

      final db = await database;

      await db.transaction((txn) async {
        // 1. Очищаем существующие данные (каскадно удалятся связанные записи)
        await txn.delete('tasks');
        await txn.delete('theory');
        await txn.delete('levels');
        await txn.delete('modules');
        await txn.delete('media_assets');

        // 2. Импортируем media_assets
        final mediaAssets = data['media_assets'] as List<dynamic>?;
        if (mediaAssets != null) {
          for (var asset in mediaAssets) {
            await txn.insert('media_assets', {
              'id': asset['id'],
              'file_path': asset['file_path'],
              'mime_type': asset['mime_type'],
              'duration_sec': asset['duration_sec'],
              'checksum': asset['checksum'],
            });
          }
        }

        // 3. Импортируем модули и уровни
        final modules = data['modules'] as List<dynamic>;
        for (var module in modules) {
          final moduleId = module['id'] as int;

          await txn.insert('modules', {
            'id': moduleId,
            'title': module['title'],
            'description': module['description'],
            'order_index': module['order_index'],
          });

          final levels = module['levels'] as List<dynamic>?;
          if (levels != null && levels.isNotEmpty) {
            for (var level in levels) {
              final levelId = level['id'] as int;

              await txn.insert('levels', {
                'id': levelId,
                'module_id': moduleId,
                'title': level['title'],
                'difficulty': level['difficulty'],
              });

              // Импортируем теорию
              final theoryHtml = level['theory'] as String?;
              if (theoryHtml != null && theoryHtml.isNotEmpty) {
                await txn.insert('theory', {
                  'level_id': levelId,
                  'content_html': theoryHtml,
                  'media_id': null,
                });
              }

              // Импортируем задания
              final tasks = level['tasks'] as List<dynamic>?;
              if (tasks != null && tasks.isNotEmpty) {
                for (var task in tasks) {
                  await txn.insert('tasks', {
                    'level_id': levelId,
                    'question_text': task['question_text'],
                    'type': task['type'],
                    'correct_answer': task['correct_answer'],
                    'options_json': task['options_json'] is List
                        ? json.encode(task['options_json'])
                        : task['options_json'],
                    'audio_text': task['audio_text'],
                    'points': task['points'] ?? 10,
                    'media_id': task['media_id'],
                  });
                }
              }
            }
          }
        }
      });

      debugPrint('✅ Модули успешно импортированы из JSON');
    } catch (e, stack) {
      debugPrint('❌ Ошибка импорта модулей: $e');
      debugPrint(stack.toString());
    }
  }

  /// Переключить статус избранного для перевода
  Future<void> toggleFavoriteTranslation(int translationId, bool isFavorite) async {
    final db = await database;
    await db.update('translations', {'is_favorite': isFavorite ? 1 : 0}, where: 'id = ?', whereArgs: [translationId]);
  }

  Future<List<Map<String, dynamic>>> getFavoriteTranslations() async {
    final db = await database;
    return await db.query('translations', where: 'is_favorite = 1', orderBy: 'created_at DESC');
  }

  Future<void> deleteTranslation(int translationId) async {
    final db = await database;
    await db.delete('translations', where: 'id = ?', whereArgs: [translationId]);
  }

  Future<void> clearAllFavorites() async {
    final db = await database;
    await db.update('translations', {'is_favorite': 0}, where: 'is_favorite = 1');
  }

  Future<void> initLearningMaterials() async {
    final db = await database;
    var moduleCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM modules'));
    if (moduleCount == 0) {
      await importModulesFromJson();
    }
  }

  Future<void> deletePhrase(int phraseId) async {
    final db = await database;
    await db.delete('user_phrasebook', where: 'phrase_id = ?', whereArgs: [phraseId]);
    await db.delete('phrases', where: 'id = ?', whereArgs: [phraseId]);
  }

  Future<void> movePhraseToCategory(int phraseId, int newCategoryId) async {
    final db = await database;
    await db.update('phrases', {'category_id': newCategoryId}, where: 'id = ?', whereArgs: [phraseId]);
  }

  Future<void> deletePhraseCategory(int categoryId) async {
    final db = await database;
    await db.delete('phrase_categories', where: 'id = ?', whereArgs: [categoryId]);
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

  Future<List<Theory>> getTheory(int levelId) async {
    final db = await database;
    final result = await db.query('theory', where: 'level_id = ?', whereArgs: [levelId]);
    return result.map((m) => Theory.fromMap(m)).toList();
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
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getUserTotalScore(int userId) async {
    final db = await database;
    var result = await db.rawQuery('''
    SELECT SUM(score) as total 
    FROM user_progress 
    WHERE user_id = ? AND (source_context = 'task' OR source_context = 'riddle')
  ''', [userId]);
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
    return await db.rawInsert('INSERT INTO user_progress (user_id, riddle_id, source_context, is_completed, attempts_count, score, last_attempt) VALUES (?, ?, ?, ?, ?, ?, ?)', [userId, riddleId, 'riddle', isCompleted ? 1 : 0, 1, score, DateTime.now().toIso8601String()]);
  }

  Future<List<Map<String, dynamic>>> getAllPhraseCategories() async {
    final db = await database;
    return await db.query('phrase_categories', orderBy: 'name');
  }

  Future<List<Map<String, dynamic>>> getPhrasesByCategory(int categoryId) async {
    final db = await database;
    return await db.query('phrases', where: 'category_id = ?', whereArgs: [categoryId], orderBy: 'text_mansi');
  }

  Future<int> addPhraseCategory(String name) async {
    final db = await database;
    return await db.insert('phrase_categories', {'name': name, 'icon_resource': 'custom'});
  }

  Future<int> addPhrase({required int categoryId, required String textRussian, required String textMansi, String? transcription}) async {
    final db = await database;
    return await db.insert('phrases', {'category_id': categoryId, 'media_id': null, 'text_russian': textRussian, 'text_mansi': textMansi, 'transcription': transcription});
  }

  Future<void> toggleFavoritePhrase(int userId, int phraseId, bool isFavorite) async {
    final db = await database;
    final existing = await db.query('user_phrasebook', where: 'user_id = ? AND phrase_id = ?', whereArgs: [userId, phraseId]);
    if (existing.isNotEmpty) {
      await db.update('user_phrasebook', {'is_favorite': isFavorite ? 1 : 0}, where: 'user_id = ? AND phrase_id = ?', whereArgs: [userId, phraseId]);
    } else {
      await db.insert('user_phrasebook', {'user_id': userId, 'phrase_id': phraseId, 'is_favorite': isFavorite ? 1 : 0, 'repetition_count': 0, 'learned_at': null});
    }
  }

  Future<List<Map<String, dynamic>>> getFavoritePhrases(int userId) async {
    final db = await database;
    return await db.rawQuery('SELECT p.*, pc.name as category_name, up.is_favorite FROM phrases p JOIN phrase_categories pc ON p.category_id = pc.id JOIN user_phrasebook up ON p.id = up.phrase_id WHERE up.user_id = ? AND up.is_favorite = 1 ORDER BY pc.name, p.text_mansi', [userId]);
  }

  Future<int> addTranslation(te.Translation translation) async {
    final db = await database;
    final map = translation.toMap();
    map['session_id'] ??= 1;
    map['created_at'] ??= DateTime.now().toIso8601String();
    return await db.insert('translations', map);
  }

  Future<List<Map<String, dynamic>>> getTranslationHistory({DateTime? startDate, DateTime? endDate, String? searchQuery, bool onlyFavorites = false}) async {
    final db = await database;
    final whereParts = <String>[];
    final whereArgs = <dynamic>[];
    if (onlyFavorites) { whereParts.add('is_favorite = 1'); }
    if (startDate != null) { whereParts.add('created_at >= ?'); whereArgs.add(startDate.toIso8601String()); }
    if (endDate != null) { whereParts.add('created_at <= ?'); whereArgs.add(endDate.toIso8601String()); }
    if (searchQuery != null && searchQuery.isNotEmpty) { whereParts.add('(source_text LIKE ? OR target_text LIKE ?)'); whereArgs.addAll(['%$searchQuery%', '%$searchQuery%']); }
    final whereClause = whereParts.isNotEmpty ? whereParts.join(' AND ') : null;
    return await db.query('translations', where: whereClause, whereArgs: whereArgs.isNotEmpty ? whereArgs : null, orderBy: 'created_at DESC', limit: 500);
  }

  Future<int> getCompletedLevelsCount(int userId) async {
    final db = await database;
    final result = await db.rawQuery('''
    SELECT COUNT(DISTINCT task_id) as count 
    FROM user_progress 
    WHERE user_id = ? AND source_context = 'task' AND is_completed = 1
  ''', [userId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> clearTranslationHistory() async {
    final db = await database;
    await db.delete('translations');
  }

  Future<void> removeDuplicateTranslations() async {
    final db = await database;
    await db.rawDelete('DELETE FROM translations WHERE id NOT IN (SELECT MAX(id) FROM translations GROUP BY source_text, target_text)');
  }

  Future<Map<String, dynamic>> exportAllData() async {
    final db = await database;
    return {'export_date': DateTime.now().toIso8601String(), 'users': await db.query('users'), 'translations': await db.query('translations'), 'progress': await db.query('user_progress'), 'modules': await db.query('modules'), 'levels': await db.query('levels'), 'tasks': await db.query('tasks'), 'riddles': await db.query('riddles')};
  }

  Future<void> importAllData(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      if (data['users'] != null) {
        for (var item in List<Map<String, dynamic>>.from(data['users'])) {
          final map = Map<String, dynamic>.from(item);
          if (map.containsKey('name') && !map.containsKey('username')) { map['username'] = map['name']; map.remove('name'); }
          map.removeWhere((key, value) => !['id', 'username', 'created_at', 'settings_json'].contains(key));
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
}

class Riddle {
  final int? id;
  final String questionText;
  final String answerText;
  final String? hintText;
  final String? difficultyLevel;
  final String? category;
  Riddle({this.id, required this.questionText, required this.answerText, this.hintText, this.difficultyLevel, this.category});
  Map<String, dynamic> toMap() => {'id': id, 'question_text': questionText, 'answer_text': answerText, 'hint_text': hintText, 'difficulty_level': difficultyLevel, 'category': category};
  factory Riddle.fromMap(Map<String, dynamic> map) => Riddle(id: map['id'], questionText: map['question_text'], answerText: map['answer_text'], hintText: map['hint_text'], difficultyLevel: map['difficulty_level'], category: map['category']);
}