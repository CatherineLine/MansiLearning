import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

/// Сервис для перевода документов в фоновом режиме
class FileTranslationService {
  static final FileTranslationService _instance = FileTranslationService._internal();
  factory FileTranslationService() => _instance;
  FileTranslationService._internal();

  static const String translateApiEndpoint =
      "https://ethnoportal.admhmao.ru/api/machine-translates/translate";

  // Статус перевода
  final ValueNotifier<TranslationStatus?> statusNotifier = ValueNotifier(null);

  // Текущий прогресс (0-100)
  final ValueNotifier<double> progressNotifier = ValueNotifier(0.0);

  // Отмена перевода
  bool _isCancelled = false;

  /// Поддерживаемые форматы
  static const List<String> supportedExtensions = [
    'txt', 'md', 'json', 'xml', 'html', 'rtf'
  ];

  /// Выбор файла для перевода
  static Future<File?> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: supportedExtensions,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      return File(result.files.first.path!);
    }
    return null;
  }

  /// Перевод файла
  Future<File?> translateFile(File inputFile, {Function(String)? onProgress}) async {
    _isCancelled = false;
    statusNotifier.value = TranslationStatus(
      fileName: inputFile.path.split('/').last,
      status: 'Чтение файла...',
      progress: 0.0,
    );

    try {
      // Шаг 1: Извлечение текста из файла
      String extractedText = await _extractTextFromFile(inputFile);
      if (_isCancelled) return null;

      statusNotifier.value = TranslationStatus(
        fileName: inputFile.path.split('/').last,
        status: 'Извлечено ${extractedText.length} символов. Перевод...',
        progress: 10.0,
      );

      // Шаг 2: Разбивка на части (если текст длинный)
      List<String> chunks = _splitTextIntoChunks(extractedText);
      List<String> translatedChunks = [];

      for (int i = 0; i < chunks.length; i++) {
        if (_isCancelled) return null;

        double currentProgress = 10 + ((i / chunks.length) * 80);
        statusNotifier.value = TranslationStatus(
          fileName: inputFile.path.split('/').last,
          status: 'Перевод части ${i + 1}/${chunks.length}...',
          progress: currentProgress,
        );

        String translated = await _translateText(chunks[i]);
        translatedChunks.add(translated);

        onProgress?.call(((i + 1) / chunks.length) as String);
      }

      // Шаг 3: Склеивание результата
      String fullTranslation = translatedChunks.join('\n\n');

      statusNotifier.value = TranslationStatus(
        fileName: inputFile.path.split('/').last,
        status: 'Сохранение результата...',
        progress: 95.0,
      );

      // Шаг 4: Сохранение переведённого файла
      File? outputFile = await _saveTranslatedFile(
        inputFile.path.split('/').last,
        fullTranslation,
        _getOriginalExtension(inputFile.path),
      );

      statusNotifier.value = TranslationStatus(
        fileName: inputFile.path.split('/').last,
        status: 'Завершено!',
        progress: 100.0,
        outputFile: outputFile,
      );

      return outputFile;

    } catch (e) {
      statusNotifier.value = TranslationStatus(
        fileName: inputFile.path.split('/').last,
        status: 'Ошибка: $e',
        progress: -1.0,
      );
      return null;
    }
  }

  /// Отмена перевода
  void cancelTranslation() {
    _isCancelled = true;
    statusNotifier.value = TranslationStatus(
      fileName: statusNotifier.value?.fileName ?? '',
      status: 'Отменено',
      progress: -1.0,
    );
  }

  /// Извлечение текста из файла
  Future<String> _extractTextFromFile(File file) async {
    String extension = file.path.split('.').last.toLowerCase();
    String content = await file.readAsString(encoding: utf8);
    return content;
  }

  /// Разбивка текста на части (API имеет ограничение на размер)
  List<String> _splitTextIntoChunks(String text) {
    const int maxChunkSize = 5000; // Максимальный размер части
    List<String> chunks = [];

    for (int i = 0; i < text.length; i += maxChunkSize) {
      int end = (i + maxChunkSize < text.length) ? i + maxChunkSize : text.length;
      chunks.add(text.substring(i, end));
    }

    return chunks;
  }

  /// Перевод текста через API
  Future<String> _translateText(String text) async {
    final Map<String, dynamic> data = {
      "text": text,
      "sourceLanguage": 1, // Русский
      "targetLanguage": 2, // Мансийский
    };

    try {
      final response = await http.post(
        Uri.parse(translateApiEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        String responseBody = utf8.decode(response.bodyBytes);
        final Map<String, dynamic> responseData = json.decode(responseBody);
        return responseData['translatedText'] ?? text;
      }

      return text;
    } catch (e) {
      debugPrint('Ошибка перевода: $e');
      return text;
    }
  }

  /// Сохранение переведённого файла
  Future<File?> _saveTranslatedFile(String originalName, String content, String extension) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = originalName.replaceAll('.$extension', '_translated.$extension');
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(content, encoding: utf8);
      return file;
    } catch (e) {
      debugPrint('Ошибка сохранения файла: $e');
      return null;
    }
  }

  String _getOriginalExtension(String path) {
    return path.split('.').last.toLowerCase();
  }
}

/// Статус перевода
class TranslationStatus {
  final String fileName;
  final String status;
  final double progress;
  final File? outputFile;

  TranslationStatus({
    required this.fileName,
    required this.status,
    required this.progress,
    this.outputFile,
  });
}