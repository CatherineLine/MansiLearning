import 'package:hive_flutter/hive_flutter.dart';
import '../models/translation_entities.dart' as te;

class AppDatabaseHive {
  static final AppDatabaseHive instance = AppDatabaseHive._init();
  static Box? _box;

  AppDatabaseHive._init();

  Future<Box> get box async {
    if (_box != null) return _box!;
    _box = await _initHive();
    return _box!;
  }

  Future<Box> _initHive() async {
    await Hive.initFlutter();
    final box = await Hive.openBox('mansi_translator_db');

    // Инициализация "таблиц" (списков)
    final tables = [
      'translations',
      'users',
      'modules',
      'levels',
      'tasks',
      'riddles',
      'user_progress',
      'translation_sessions',
    ];

    for (final table in tables) {
      if (box.get(table) == null) {
        await box.put(table, <Map<String, dynamic>>[]);
      }
    }

    return box;
  }

  List<Map<String, dynamic>> _getTable(String tableName) {
    return List<Map<String, dynamic>>.from(_box!.get(tableName) ?? []);
  }

  Future<void> _saveTable(String tableName, List<Map<String, dynamic>> data) async {
    await _box!.put(tableName, data);
  }

  Future<int> addTranslation(te.Translation translation) async {
    final allData = _getTable('translations');

    final map = translation.toMap();
    map['session_id'] ??= 1;
    map['created_at'] ??= DateTime.now().toIso8601String();
    map['is_favorite'] = translation.isFavorite ? 1 : 0;

    // Генерируем ID
    int maxId = 0;
    for (final item in allData) {
      final id = item['id'] as int? ?? 0;
      if (id > maxId) maxId = id;
    }
    map['id'] = maxId + 1;

    allData.add(map);
    await _saveTable('translations', allData);
    return map['id'] as int;
  }

  Future<List<Map<String, dynamic>>> getTranslationHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) async {
    var results = _getTable('translations');

    // Фильтрация по дате
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

    // Поиск
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      results = results.where((item) {
        final sourceText = (item['source_text']?.toString() ?? '').toLowerCase();
        final targetText = (item['target_text']?.toString() ?? '').toLowerCase();
        return sourceText.contains(query) || targetText.contains(query);
      }).toList();
    }

    // Сортировка по дате (DESC)
    results.sort((a, b) {
      final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(0);
      final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(0);
      return bDate.compareTo(aDate);
    });

    // Лимит
    if (results.length > 100) {
      results = results.take(100).toList();
    }

    return results;
  }

  Future<void> clearTranslationHistory() async {
    await _saveTable('translations', []);
  }

  Future<void> removeDuplicateTranslations() async {
    final allData = _getTable('translations');
    final seen = <String>{};
    final uniqueData = <Map<String, dynamic>>[];

    for (final item in allData) {
      final key = '${item['source_text']}_${item['target_text']}';
      if (!seen.contains(key)) {
        seen.add(key);
        uniqueData.add(item);
      }
    }

    await _saveTable('translations', uniqueData);
  }

  Future<Map<String, dynamic>> exportAllData() async {
    return {
      'export_date': DateTime.now().toIso8601String(),
      'users': _getTable('users'),
      'translations': _getTable('translations'),
      'progress': _getTable('user_progress'),
      'modules': _getTable('modules'),
      'levels': _getTable('levels'),
      'tasks': _getTable('tasks'),
      'riddles': _getTable('riddles'),
    };
  }

  Future<void> importAllData(Map<String, dynamic> data) async {
    if (data['users'] != null) {
      var users = _getTable('users');
      for (var item in List<Map<String, dynamic>>.from(data['users'])) {
        final map = Map<String, dynamic>.from(item);
        if (map.containsKey('name') && !map.containsKey('username')) {
          map['username'] = map['name'];
          map.remove('name');
        }
        map.removeWhere((key, value) =>
        !['id', 'username', 'created_at', 'settings_json'].contains(key));
        users.add(map);
      }
      await _saveTable('users', users);
    }

    if (data['translations'] != null) {
      var translations = _getTable('translations');
      for (var item in List<Map<String, dynamic>>.from(data['translations'])) {
        final map = Map<String, dynamic>.from(item);
        map['session_id'] ??= 1;
        translations.add(map);
      }
      await _saveTable('translations', translations);
    }

    if (data['progress'] != null) {
      var progress = _getTable('user_progress');
      for (var item in List<Map<String, dynamic>>.from(data['progress'])) {
        progress.add(item);
      }
      await _saveTable('user_progress', progress);
    }
  }

  Future<void> close() async {
    await _box?.close();
    _box = null;
  }
}