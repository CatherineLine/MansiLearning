import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

/// Сервис для перевода документов
class FileTranslationService {
  static final FileTranslationService _instance = FileTranslationService._internal();
  factory FileTranslationService() => _instance;
  FileTranslationService._internal();

  static const String translateApiEndpoint = "https://ethnoportal.admhmao.ru/api/machine-translates/translate";

  // Статус перевода
  final ValueNotifier<TranslationStatus?> statusNotifier = ValueNotifier(null);
  final ValueNotifier<double> progressNotifier = ValueNotifier(0.0);

  bool _isCancelled = false;

  // ✅ Направление перевода: true = на мансийский, false = с мансийского
  bool _translateToMansi = true;

  static const List<String> supportedExtensions = ['txt', 'md', 'json', 'xml', 'html', 'rtf'];

  // ✅ API принимает максимум 200 символов за запрос
  static const int maxChunkSize = 200;

  /// Установка направления перевода
  void setTranslationDirection({required bool toMansi}) {
    _translateToMansi = toMansi;
  }

  /// Получение текущего направления
  bool get isTranslatingToMansi => _translateToMansi;

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

  /// Перевод файла с поддержкой направления
  Future<File?> translateFile(File inputFile, {Function(double)? onProgress}) async {
    _isCancelled = false;
    progressNotifier.value = 0.0;

    final directionText = _translateToMansi ? 'на мансийский' : 'с мансийского';
    statusNotifier.value = TranslationStatus(
      fileName: inputFile.path.split('/').last,
      status: 'Чтение файла...',
      progress: 0.0,
    );

    try {
      // Шаг 1: Извлечение текста
      String extractedText = await _extractTextFromFile(inputFile);
      if (_isCancelled) return null;

      statusNotifier.value = TranslationStatus(
        fileName: inputFile.path.split('/').last,
        status: 'Извлечено ${extractedText.length} символов. Перевод $directionText...',
        progress: 10.0,
      );
      progressNotifier.value = 10.0;
      onProgress?.call(0.1);

      // Шаг 2: Разбивка на чанки по 200 символов
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
        progressNotifier.value = currentProgress;
        onProgress?.call(currentProgress / 100);

        // ✅ Перевод с учётом направления
        String translated = await _translateText(chunks[i], toMansi: _translateToMansi);
        translatedChunks.add(translated);
      }

      // Шаг 3: Склеивание
      String fullTranslation = translatedChunks.join('\n');
      statusNotifier.value = TranslationStatus(
        fileName: inputFile.path.split('/').last,
        status: 'Сохранение результата...',
        progress: 95.0,
      );
      progressNotifier.value = 95.0;
      onProgress?.call(0.95);

      // Шаг 4: Сохранение
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
      progressNotifier.value = 100.0;
      onProgress?.call(1.0);

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
    return await file.readAsString(encoding: utf8);
  }

  /// ✅ Разбивка текста на чанки по 200 символов (ограничение API)
  List<String> _splitTextIntoChunks(String text) {
    List<String> chunks = [];
    for (int i = 0; i < text.length; i += maxChunkSize) {
      int end = (i + maxChunkSize < text.length) ? i + maxChunkSize : text.length;

      // ✅ Дополнительная защита: не разбивать слова посередине
      if (end < text.length && text[end] != ' ' && text[end] != '\n') {
        // Ищем ближайший пробел или перенос
        int lastSpace = text.substring(i, end).lastIndexOf(' ');
        int lastNewline = text.substring(i, end).lastIndexOf('\n');
        int breakPoint = lastSpace > lastNewline ? i + lastSpace + 1 : end;
        chunks.add(text.substring(i, breakPoint).trim());
        i = breakPoint - 1; // Компенсация инкремента в цикле
      } else {
        chunks.add(text.substring(i, end));
      }
    }
    return chunks;
  }

  /// ✅ Перевод текста с выбором направления
  Future<String> _translateText(String text, {required bool toMansi}) async {
    if (text.trim().isEmpty) return text;

    // ✅ Коды языков: 1 = русский, 2 = мансийский
    final int sourceLanguage = toMansi ? 1 : 2;
    final int targetLanguage = toMansi ? 2 : 1;

    debugPrint('📤 Отправка (${text.length} символов): ${text.substring(0, text.length > 50 ? 50 : text.length)}...');

    final Map<String, dynamic> data = {
      "text": text,
      "sourceLanguage": sourceLanguage,
      "targetLanguage": targetLanguage,
    };

    try {
      final response = await http.post(
        Uri.parse(translateApiEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      ).timeout(const Duration(seconds: 30));

      debugPrint('📥 Статус: ${response.statusCode}');

      if (response.statusCode == 200) {
        String responseBody = utf8.decode(response.bodyBytes);
        final Map<String, dynamic> responseData = json.decode(responseBody);
        String translated = responseData['translatedText'] ?? text;
        debugPrint('✅ Перевод получен (${translated.length} символов)');
        return translated;
      } else {
        debugPrint('❌ Ошибка API: ${response.statusCode} — ${response.body}');
        // Возвращаем исходный текст, чтобы не терять данные
        return text;
      }
    } catch (e) {
      debugPrint('❌ Ошибка перевода: $e');
      return text;
    }
  }

  /// Сохранение переведённого файла в публичную папку
  Future<File?> _saveTranslatedFile(String originalName, String content, String extension) async {
    try {
      // ✅ Публичная папка Downloads
      Directory targetDir;
      try {
        targetDir = Directory('/storage/emulated/0/Download/MansiTranslator');
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
      } catch (_) {
        targetDir = await getApplicationDocumentsDirectory();
      }

      final directionSuffix = _translateToMansi ? '_to_mansi' : '_from_mansi';
      final fileName = originalName.replaceAll('.$extension', '${directionSuffix}_translated.$extension');
      final file = File('${targetDir.path}/$fileName');

      await file.writeAsString(content, encoding: utf8);
      debugPrint('✅ Файл сохранён: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('❌ Ошибка сохранения: $e');
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