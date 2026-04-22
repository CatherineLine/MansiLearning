import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sqflite/sqflite.dart' as sqlite;
import '../models/database.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  late final Future<Database> _database;

  factory AppDatabase() => _instance;

  final riddleProgressStore = intMapStoreFactory.store('riddle_progress');
  final translationStore = intMapStoreFactory.store('translations');
  final theoryStore = intMapStoreFactory.store('theory');
  final tasksStore = intMapStoreFactory.store('tasks');
  final userProgressStore = intMapStoreFactory.store('user_progress');
  final riddleStore = intMapStoreFactory.store('riddles');

  AppDatabase._internal() {
    _database = DatabaseConfig.initDatabase();
  }

  Future<Database> get database => _database;

  // Riddle Progress
  Future<void> saveRiddleProgress(int solvedRiddles, int totalScore) async {
    final db = await _database;
    final record = riddleProgressStore.record(1);
    await record.put(db, {
      'solved_riddles': solvedRiddles,
      'total_score': totalScore,
      'next_riddle_required_score': (solvedRiddles + 1) * 100
    });
  }

  Future<Map<String, dynamic>> getRiddleProgress() async {
    final db = await _database;
    final record = riddleProgressStore.record(1);
    final snapshot = await record.get(db);
    return snapshot ?? {
      'solved_riddles': 0,
      'total_score': 0,
      'next_riddle_required_score': 100
    };
  }

  Future<int> getCompletedRiddlesCount() async {
    final db = await _database;
    final record = riddleProgressStore.record(1);
    final snapshot = await record.get(db);
    final count = snapshot?['solved_riddles'];
    return count is num ? count.toInt() : 0;
  }

  Future<int> getUserTotalScore() async {
    final db = await _database;
    final records = await tasksStore.find(db);
    int totalScore = 0;
    for (var record in records) {
      final points = record.value['points'];
      if (points is num) totalScore += points.toInt();
    }
    return totalScore;
  }

  // Translation History
  Future<int> clearTranslationHistory() async {
    final db = await _database;
    return await translationStore.delete(db);
  }

  Future<int> removeDuplicateTranslations() async {
    final db = await _database;
    final allTranslations = await translationStore.find(db);

    final Map<String, List<RecordSnapshot<int, Map<String, dynamic>>>> grouped = {};
    for (var snapshot in allTranslations) {
      final key = '${snapshot.value['original_text']}|${snapshot.value['translated_text']}';
      grouped.putIfAbsent(key, () => []).add(snapshot);
    }

    int deletedCount = 0;
    for (var group in grouped.values) {
      if (group.length > 1) {
        group.sort((a, b) => b.value['timestamp'].compareTo(a.value['timestamp']));
        for (var i = 1; i < group.length; i++) {
          await translationStore.record(group[i].key).delete(db);
          deletedCount++;
        }
      }
    }
    return deletedCount;
  }

  Future<List<Map<String, dynamic>>> getTranslationHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) async {
    final db = await _database;
    List<Map<String, dynamic>> results = [];

    final records = await translationStore.find(db);
    for (final record in records) {
      final item = Map<String, dynamic>.from(record.value);
      item['id'] = record.key;
      results.add(item);
    }

    if (startDate != null || endDate != null) {
      results = results.where((item) {
        final timestamp = DateTime.parse(item['timestamp']);
        return (startDate == null || timestamp.isAfter(startDate)) &&
            (endDate == null || timestamp.isBefore(endDate));
      }).toList();
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      results = results.where((item) {
        final original = item['original_text']?.toString().toLowerCase() ?? '';
        final translated = item['translated_text']?.toString().toLowerCase() ?? '';
        return original.contains(query) || translated.contains(query);
      }).toList();
    }
    return results;
  }

  Future<int> addTranslation(String originalText, String translatedText, String timestamp, String direction) async {
    final db = await _database;
    return await translationStore.add(db, {
      'original_text': originalText,
      'translated_text': translatedText,
      'timestamp': timestamp,
      'direction': direction,
    });
  }

  // Learning Materials
  Future<void> initLearningMaterials() async {
    try {
      final db = await _database;
      final theoryCount = await theoryStore.count(db);
      final tasksCount = await tasksStore.count(db);
      if (theoryCount == 0 || tasksCount == 0) {
        await _populateInitialData(db);
      }
      await _initRiddles(db);
    } catch (e) {
      debugPrint('Ошибка инициализации учебных материалов: $e');
      rethrow;
    }
  }

  Future<void> _initRiddles(Database db) async {
    final count = await riddleStore.count(db);
    if (count == 0) {
      debugPrint('Добавляем загадки...');
    }
  }

  Future<void> _populateInitialData(Database db) async {
    // Содержимое метода _populateInitialData из вашего main.dart
    // (полный код модулей 1-10)
  }

  Future<List<Map<String, dynamic>>> getModuleLevels(int moduleId) async {
    final db = await _database;
    final finder = Finder(
      filter: Filter.equals('module', moduleId),
      sortOrders: [SortOrder('level')],
    );
    final records = await tasksStore.find(db, finder: finder);

    final levels = <int, Map<String, dynamic>>{};
    for (final record in records) {
      final level = record.value['level'] as int;
      if (!levels.containsKey(level)) {
        levels[level] = {
          'module': moduleId,
          'level': level,
          'has_theory': true,
        };
      }
    }
    return levels.values.toList()..sort((a, b) => (a['level'] as int).compareTo(b['level'] as int));
  }

  Future<Map<String, dynamic>?> getTheory(int moduleId, int level) async {
    final db = await _database;
    final finder = Finder(
      filter: Filter.and([
        Filter.equals('module', moduleId),
        Filter.equals('level', level),
      ]),
    );
    final record = await theoryStore.findFirst(db, finder: finder);
    return record?.value;
  }

  Future<List<Map<String, dynamic>>> getTasks(int moduleId, int level) async {
    final db = await _database;
    final records = await tasksStore.find(db, finder: Finder(filter: Filter.and([
      Filter.equals('module', moduleId),
      Filter.equals('level', level),
    ])));
    return records.map((record) => record.value).toList();
  }

  Future<void> saveUserProgress(int moduleId, int level, int score) async {
    final db = await _database;
    await userProgressStore.record(moduleId).put(db, {
      'module': moduleId,
      'level': level,
      'score': score,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> getUserProgress(int moduleId) async {
    final db = await _database;
    return await userProgressStore.record(moduleId).get(db);
  }

  Future<List<Map<String, dynamic>>> getRiddles() async {
    final db = await _database;
    final records = await riddleStore.find(db);
    List<Map<String, dynamic>> riddles = [];
    for (final record in records) {
      final Map<String, dynamic> riddle = {};
      record.value.forEach((key, value) {
        riddle[key.toString()] = value;
      });
      riddles.add(riddle);
    }
    return riddles;
  }

  // Export/Import
  Future<dynamic> exportAllData() async {
    final db = await _database;
    final records = await translationStore.find(db);
    final data = <String, dynamic>{
      'version': 1,
      'data': records.map((record) => record.value).toList(),
    };

    if (kIsWeb) {
      return json.encode(data);
    } else {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/translations_export.json');
      await file.writeAsString(json.encode(data));
      return file;
    }
  }

  Future<int> importAllData(Map<String, dynamic> jsonData) async {
    if (jsonData['version'] != 1 || jsonData['data'] == null) {
      throw Exception('Invalid data format');
    }
    final db = await _database;
    final dynamic data = jsonData['data'];
    List<Map<String, dynamic>> items = [];

    if (data is List) {
      for (var item in data) {
        if (item is Map<String, dynamic>) {
          items.add(item);
        } else if (item is Map) {
          items.add(Map<String, dynamic>.from(item.cast<String, dynamic>()));
        }
      }
    } else {
      throw Exception('Expected List but got ${data.runtimeType}');
    }

    int importedCount = 0;
    for (var item in items) {
      await translationStore.add(db, item);
      importedCount++;
    }
    return importedCount;
  }
}