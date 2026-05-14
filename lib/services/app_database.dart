import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/media_asset.dart';
import '../models/learning_entities.dart';
import '../models/translation_entities.dart';
import '../models/phrasebook_entities.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

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
      version: 2,
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
      CREATE TABLE users (
        id $idType,
        username $textType,
        created_at $textType,
        settings_json TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE media_assets (
        id $idType,
        file_path $textType,
        mime_type $textType,
        duration_sec INTEGER,
        checksum TEXT
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
      CREATE TABLE theory (
        id $idType,
        level_id $integerType,
        media_id INTEGER,
        content_html $textType,
        FOREIGN KEY (level_id) REFERENCES levels (id) ON DELETE CASCADE,
        FOREIGN KEY (media_id) REFERENCES media_assets (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks (
        id $idType,
        level_id $integerType,
        media_id INTEGER,
        question_text $textType,
        type $textType,
        correct_answer $textType,
        options_json $textType,
        FOREIGN KEY (level_id) REFERENCES levels (id) ON DELETE CASCADE,
        FOREIGN KEY (media_id) REFERENCES media_assets (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE translation_sessions (
        id $idType,
        user_id $integerType,
        session_type $textType,
        started_at $textType,
        status $textType,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE translations (
        id $idType,
        session_id $integerType,
        source_text $textType,
        target_text $textType,
        source_lang $textType,
        target_lang $textType,
        is_favorite $booleanType,
        FOREIGN KEY (session_id) REFERENCES translation_sessions (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE documents (
        id $idType,
        session_id $integerType,
        original_file_path $textType,
        translated_file_path TEXT,
        file_format $textType,
        status $textType,
        uploaded_at $textType,
        FOREIGN KEY (session_id) REFERENCES translation_sessions (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE phrase_categories (
        id $idType,
        name $textType,
        icon_resource $textType
      )
    ''');

    await db.execute('''
      CREATE TABLE phrases (
        id $idType,
        category_id $integerType,
        media_id INTEGER,
        text_mansi $textType,
        text_russian $textType,
        transcription TEXT,
        FOREIGN KEY (category_id) REFERENCES phrase_categories (id) ON DELETE CASCADE,
        FOREIGN KEY (media_id) REFERENCES media_assets (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE user_phrasebook (
        user_id $integerType,
        phrase_id $integerType,
        is_favorite $booleanType,
        repetition_count $integerType,
        learned_at TEXT,
        PRIMARY KEY (user_id, phrase_id),
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (phrase_id) REFERENCES phrases (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE user_progress (
        id $idType,
        user_id $integerType,
        task_id INTEGER,
        phrase_id INTEGER,
        source_context $textType,
        is_completed $booleanType,
        attempts_count $integerType,
        score $integerType,
        last_attempt $textType,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE SET NULL,
        FOREIGN KEY (phrase_id) REFERENCES phrases (id) ON DELETE SET NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createDB(db, newVersion);
    }
  }

  Future<int> createUser(User user) async {
    final db = await database;
    return await db.insert('users', user.toMap());
  }

  Future<int> createSession(TranslationSession session) async {
    final db = await database;
    return await db.insert('translation_sessions', session.toMap());
  }

  Future<List<Translation>> getTranslationsBySession(int sessionId) async {
    final db = await database;
    final maps = await db.query(
      'translations',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    return maps.map((map) => Translation.fromMap(map)).toList();
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}