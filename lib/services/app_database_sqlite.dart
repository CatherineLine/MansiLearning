import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/translation_entities.dart' as te;

class AppDatabaseSqlite {
  static final AppDatabaseSqlite instance = AppDatabaseSqlite._init();
  static Database? _database;

  AppDatabaseSqlite._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('mansi_translator.db');
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

    await db.execute('''
      CREATE TABLE translations (
        id $idType,
        session_id $integerType,
        source_text $textType,
        target_text $textType,
        source_lang $textType,
        target_lang $textType,
        is_favorite $booleanType,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE users (
        id $idType,
        username $textType,
        created_at TEXT,
        settings_json TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE modules (
        id $idType,
        title $textType,
        description TEXT,
        order_index $integerType
      )
    ''');

    await db.execute('''
      CREATE TABLE levels (
        id $idType,
        module_id $integerType,
        title $textType,
        difficulty $textType,
        FOREIGN KEY (module_id) REFERENCES modules (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks (
        id $idType,
        level_id $integerType,
        media_id INTEGER,
        question_text $textType,
        type $textType,
        correct_answer TEXT,
        options_json TEXT,
        FOREIGN KEY (level_id) REFERENCES levels (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE riddles (
        id $idType,
        question_text $textType,
        answer_text $textType,
        hint_text TEXT,
        difficulty_level TEXT,
        category TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE user_progress (
        id $idType,
        user_id $integerType,
        task_id INTEGER,
        riddle_id INTEGER,
        source_context TEXT,
        is_completed $booleanType,
        attempts_count $integerType,
        score $integerType,
        last_attempt TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE SET NULL,
        FOREIGN KEY (riddle_id) REFERENCES riddles (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE translation_sessions (
        id $idType,
        user_id $integerType,
        session_type $textType,
        started_at TEXT,
        status TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS riddles (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          question_text TEXT NOT NULL,
          answer_text TEXT NOT NULL,
          hint_text TEXT,
          difficulty_level TEXT,
          category TEXT
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
    await db.rawDelete('''
      DELETE FROM translations 
      WHERE id NOT IN (
        SELECT MAX(id) FROM translations 
        GROUP BY source_text, target_text
      )
    ''');
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
    final db = await database;
    await db.close();
    _database = null;
  }
}