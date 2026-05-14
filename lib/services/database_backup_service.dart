import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'app_database.dart';
import '../models/user.dart';
import '../models/media_asset.dart';
import '../models/learning_entities.dart';
import '../models/translation_entities.dart';
import '../models/phrasebook_entities.dart';

class DatabaseBackupService {
  final AppDatabase _db = AppDatabase.instance;

  /// Экспортирует всю базу данных в JSON файл
  Future<String> exportDatabaseToJson() async {
    final db = await _db.database;

    // 1. Сбор данных из всех таблиц
    final List<Map<String, dynamic>> users = await db.query('users');
    final List<Map<String, dynamic>> media = await db.query('media_assets');
    final List<Map<String, dynamic>> modules = await db.query('modules');
    final List<Map<String, dynamic>> levels = await db.query('levels');
    final List<Map<String, dynamic>> theory = await db.query('theory');
    final List<Map<String, dynamic>> tasks = await db.query('tasks');
    final List<Map<String, dynamic>> sessions = await db.query('translation_sessions');
    final List<Map<String, dynamic>> translations = await db.query('translations');
    final List<Map<String, dynamic>> documents = await db.query('documents');
    final List<Map<String, dynamic>> categories = await db.query('phrase_categories');
    final List<Map<String, dynamic>> phrases = await db.query('phrases');
    final List<Map<String, dynamic>> userPhrasebook = await db.query('user_phrasebook');
    final List<Map<String, dynamic>> progress = await db.query('user_progress');

    // 2. Формирование единой структуры
    final Map<String, dynamic> backupData = {
      'version': 2, // Версия схемы данных
      'export_date': DateTime.now().toIso8601String(),
      'data': {
        'users': users,
        'media_assets': media,
        'modules': modules,
        'levels': levels,
        'theory': theory,
        'tasks': tasks,
        'translation_sessions': sessions,
        'translations': translations,
        'documents': documents,
        'phrase_categories': categories,
        'phrases': phrases,
        'user_phrasebook': userPhrasebook,
        'user_progress': progress,
      },
    };

    // 3. Сериализация в JSON
    final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);

    // 4. Сохранение в файл
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'mansi_translator_backup_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File('${directory.path}/$fileName');

    await file.writeAsString(jsonString);

    return file.path;
  }

  /// Импортирует данные из JSON файла в базу данных
  /// [filePath] - путь к файлу резервной копии
  /// [clearExisting] - если true, текущая БД будет очищена перед импортом
  Future<bool> importDatabaseFromJson(String filePath, {bool clearExisting = true}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) throw Exception('Файл не найден');

      final jsonString = await file.readAsString();
      final Map<String, dynamic> backupData = json.decode(jsonString);

      // Проверка версии (можно добавить логику миграции между версиями)
      final version = backupData['version'];
      if (version == null) throw Exception('Неверный формат файла резервной копии');

      final data = backupData['data'] as Map<String, dynamic>;
      final db = await _db.database;

      // Транзакция гарантирует целостность: либо всё сохранится, либо ничего
      await db.transaction((txn) async {
        if (clearExisting) {
          // Отключаем проверки FK на время очистки, чтобы избежать ошибок
          await txn.execute('PRAGMA foreign_keys = OFF');

          // Очистка таблиц в обратном порядке зависимостей
          await txn.delete('user_progress');
          await txn.delete('user_phrasebook');
          await txn.delete('documents');
          await txn.delete('translations');
          await txn.delete('translation_sessions');
          await txn.delete('phrases');
          await txn.delete('phrase_categories');
          await txn.delete('tasks');
          await txn.delete('theory');
          await txn.delete('levels');
          await txn.delete('modules');
          await txn.delete('media_assets');
          await txn.delete('users');

          await txn.execute('PRAGMA foreign_keys = ON');
        }

        // Вставка данных в порядке зависимостей (от родителей к детям)

        // 1. Базовые справочники и пользователи
        for (var item in data['users']) await txn.insert('users', item);
        for (var item in data['media_assets']) await txn.insert('media_assets', item);
        for (var item in data['modules']) await txn.insert('modules', item);
        for (var item in data['phrase_categories']) await txn.insert('phrase_categories', item);

        // 2. Зависимые от модулей и категорий
        for (var item in data['levels']) await txn.insert('levels', item);
        for (var item in data['phrases']) await txn.insert('phrases', item);

        // 3. Контент (теория, задания)
        for (var item in data['theory']) await txn.insert('theory', item);
        for (var item in data['tasks']) await txn.insert('tasks', item);

        // 4. Переводы и сессии
        for (var item in data['translation_sessions']) await txn.insert('translation_sessions', item);
        for (var item in data['translations']) await txn.insert('translations', item);
        for (var item in data['documents']) await txn.insert('documents', item);

        // 5. Пользовательские данные (прогресс, избранное)
        for (var item in data['user_phrasebook']) await txn.insert('user_phrasebook', item);
        for (var item in data['user_progress']) await txn.insert('user_progress', item);
      });

      return true;
    } catch (e) {
      print('Ошибка импорта базы данных: $e');
      return false;
    }
  }
}