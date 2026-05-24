import 'database_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static DatabaseProvider? _provider;

  AppDatabase._init();

  Future<DatabaseProvider> get _db async {
    if (_provider == null) {
      _provider = createDatabaseProvider();
      await _provider!.init();
    }
    return _provider!;
  }

  Future<void> init() async {
    await _db;
  }

  Future<int> addTranslation(Map<String, dynamic> data) async {
    final db = await _db;
    return await db.addTranslation(data);
  }

  Future<List<Map<String, dynamic>>> getTranslationHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) async {
    final db = await _db;
    return await db.getTranslationHistory(
      startDate: startDate,
      endDate: endDate,
      searchQuery: searchQuery,
    );
  }

  Future<void> clearTranslationHistory() async {
    final db = await _db;
    await db.clearTranslationHistory();
  }

  Future<void> removeDuplicateTranslations() async {
    final db = await _db;
    await db.removeDuplicateTranslations();
  }

  Future<Map<String, dynamic>> exportAllData() async {
    final db = await _db;
    return await db.exportAllData();
  }

  Future<void> importAllData(Map<String, dynamic> data) async {
    final db = await _db;
    await db.importAllData(data);
  }

  Future<List<Map<String, dynamic>>> getModules() async {
    final db = await _db;
    return await db.getModules();
  }

  Future<List<Map<String, dynamic>>> getModuleLevels(int moduleId) async {
    final db = await _db;
    return await db.getModuleLevels(moduleId);
  }

  Future<List<Map<String, dynamic>>> getTasks(int levelId) async {
    final db = await _db;
    return await db.getTasks(levelId);
  }

  Future<List<Map<String, dynamic>>> getTheory(int moduleId, int level) async {
    final db = await _db;
    return await db.getTheory(moduleId, level);
  }

  Future<List<Map<String, dynamic>>> getRiddles({String? category}) async {
    final db = await _db;
    return await db.getRiddles(category: category);
  }

  Future<List<Map<String, dynamic>>> getUserProgress(int userId) async {
    final db = await _db;
    return await db.getUserProgress(userId);
  }

  Future<int> saveUserProgress(Map<String, dynamic> data) async {
    final db = await _db;
    return await db.saveUserProgress(data);
  }

  Future<int> getCompletedRiddlesCount(int userId) async {
    final db = await _db;
    return await db.getCompletedRiddlesCount(userId);
  }

  Future<int> getUserTotalScore(int userId) async {
    final db = await _db;
    return await db.getUserTotalScore(userId);
  }

  Future<Map<String, dynamic>?> getRiddleProgress(int userId, int riddleId) async {
    final db = await _db;
    return await db.getRiddleProgress(userId, riddleId);
  }

  Future<int> saveRiddleProgress(
      int userId,
      int riddleId,
      bool isCompleted,
      int score,
      ) async {
    final db = await _db;
    return await db.saveRiddleProgress(userId, riddleId, isCompleted, score);
  }

  Future<Map<String, dynamic>> loadRiddles() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/riddles.json');
      final jsonMap = json.decode(jsonString) as Map<String, dynamic>;

      if (jsonMap.containsKey('riddles')) {
        final riddles = jsonMap['riddles'];
        if (riddles is List) {
          return {
            'riddles': List<Map<String, dynamic>>.from(
              riddles.map((r) => r as Map<String, dynamic>),
            ),
          };
        }
      }
      throw Exception('Неверный формат riddles.json');
    } catch (e) {
      print('Ошибка загрузки riddles.json: $e');
      final db = await _db;
      final dbRiddles = await db.getRiddles();
      return {'riddles': dbRiddles};
    }
  }

  Future<void> close() async {
    await _provider?.close();
    _provider = null;
  }
}