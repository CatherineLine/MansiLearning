import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'file_translation_service.dart';

/// Инициализация WorkManager для фоновых задач
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case "translateFileTask":
        final filePath = inputData?['filePath'];
        if (filePath != null) {
          final file = File(filePath);
          final service = FileTranslationService();
          await service.translateFile(file);
        }
        break;
    }
    return Future.value(true);
  });
}

class BackgroundTranslationService {
  static Future<void> init() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true, // В релизе установить false
    );
  }

  /// Запуск перевода файла в фоне
  static Future<void> startBackgroundTranslation(String filePath) async {
    await Workmanager().registerOneOffTask(
      "translateFileTask_${DateTime.now().millisecondsSinceEpoch}",
      "translateFileTask",
      inputData: {"filePath": filePath},
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
    );
  }

  /// Остановка всех фоновых задач
  static Future<void> cancelAllTasks() async {
    await Workmanager().cancelAll();
  }
}