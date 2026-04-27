import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'file_translation_service.dart';

/// Сервис для фонового перевода (без WorkManager)
class BackgroundTranslationService {
  static final BackgroundTranslationService _instance =
  BackgroundTranslationService._internal();
  factory BackgroundTranslationService() => _instance;
  BackgroundTranslationService._internal();

  bool _isRunning = false;
  Completer<File?>? _currentTask;
  final FileTranslationService _translationService = FileTranslationService();

  // Текущий статус для отображения в UI
  final ValueNotifier<TranslationStatus?> statusNotifier = ValueNotifier(null);

  /// Инициализация (для совместимости с предыдущим кодом)
  static Future<void> init() async {
    debugPrint('BackgroundTranslationService initialized');
  }

  /// Запуск перевода в фоне (можно свернуть приложение)
  Future<File?> startBackgroundTranslation(File file, {
    Function(double progress)? onProgress,
    Function(String status)? onStatus,
  }) async {
    if (_isRunning) {
      debugPrint('Перевод уже выполняется');
      return null;
    }

    _isRunning = true;
    _currentTask = Completer<File?>();

    // Подписываемся на обновления статуса
    _translationService.statusNotifier.addListener(_onStatusChange);
    _translationService.progressNotifier.addListener(_onProgressChange);

    // Запускаем перевод в фоне (не блокируем UI)
    await Future.delayed(Duration.zero);

    _translationService.translateFile(file, onProgress: (progress) {
      onProgress?.call(progress as double);
    }).then((result) {
      _isRunning = false;
      _currentTask?.complete(result);
      _translationService.statusNotifier.removeListener(_onStatusChange);
      _translationService.progressNotifier.removeListener(_onProgressChange);
    }).catchError((e) {
      _isRunning = false;
      _currentTask?.completeError(e);
    });

    return _currentTask!.future;
  }

  void _onStatusChange() {
    statusNotifier.value = _translationService.statusNotifier.value;
  }

  void _onProgressChange() {
    // Обновление прогресса
  }

  /// Проверка, выполняется ли перевод
  bool get isRunning => _isRunning;

  /// Получение текущего статуса
  TranslationStatus? get currentStatus => _translationService.statusNotifier.value;

  /// Отмена перевода
  void cancel() {
    _translationService.cancelTranslation();
    _isRunning = false;
    if (_currentTask != null && !_currentTask!.isCompleted) {
      _currentTask?.completeError('Отменено');
    }
  }
}