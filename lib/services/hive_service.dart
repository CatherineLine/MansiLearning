/*import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';

class HiveService {
  static late Box _box;

  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox('translations');
  }

  static Future<List<Map<String, dynamic>>> getTranslationHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) async {
    final allData = _box.values.map((e) => Map<String, dynamic>.from(json.decode(e as String))).toList();

    return allData.where((item) {
      final createdAt = DateTime.tryParse(item['created_at'] ?? '');

      if (startDate != null && createdAt != null && createdAt.isBefore(startDate)) return false;
      if (endDate != null && createdAt != null && createdAt.isAfter(endDate)) return false;

      if (searchQuery != null && searchQuery.isNotEmpty) {
        final sourceText = (item['source_text'] ?? '').toLowerCase();
        final targetText = (item['target_text'] ?? '').toLowerCase();
        final query = searchQuery.toLowerCase();
        if (!sourceText.contains(query) && !targetText.contains(query)) return false;
      }

      return true;
    }).toList();
  }

  static Future<void> addTranslation(Map<String, dynamic> translation) async {
    final key = DateTime.now().millisecondsSinceEpoch.toString();
    await _box.put(key, json.encode(translation));
  }

  static Future<void> clearHistory() async {
    await _box.clear();
  }

  static Future<void> removeDuplicates() async {
    final seen = <String>{};
    final toRemove = <String>[];

    for (final key in _box.keys) {
      final item = json.decode(_box.get(key) as String);
      final text = '${item['source_text']}_${item['target_text']}';
      if (seen.contains(text)) {
        toRemove.add(key);
      } else {
        seen.add(text);
      }
    }

    for (final key in toRemove) {
      await _box.delete(key);
    }
  }

  static Future<Map<String, dynamic>> exportAllData() async {
    final allData = _box.values.map((e) => json.decode(e as String)).toList();
    return {
      'export_date': DateTime.now().toIso8601String(),
      'translations': allData,
    };
  }

  static Future<void> importAllData(Map<String, dynamic> data) async {
    final translations = data['translations'] as List;
    for (final item in translations) {
      final key = DateTime.now().millisecondsSinceEpoch.toString() + item['id'].toString();
      await _box.put(key, json.encode(item));
    }
  }

  static Future<void> close() async {
    await _box.close();
  }
}*/