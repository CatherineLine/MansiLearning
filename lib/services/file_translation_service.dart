// file_translation_service.dart - ИСПРАВЛЕННАЯ ВЕРСИЯ
// КЛЮЧЕВОЕ ИСПРАВЛЕНИЕ: правильный рекурсивный обход HTML-узлов

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as html;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_media_store/flutter_media_store.dart';
import 'package:xml/xml.dart' as xml;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

/// Сервис для перевода документов с сохранением структуры
class FileTranslationService {
  static final FileTranslationService _instance = FileTranslationService._internal();
  factory FileTranslationService() => _instance;
  FileTranslationService._internal();

  static const String translateApiEndpoint = "https://ethnoportal.admhmao.ru/api/machine-translates/translate";

  final ValueNotifier<TranslationStatus?> statusNotifier = ValueNotifier(null);
  final ValueNotifier<double> progressNotifier = ValueNotifier(0.0);

  bool _isCancelled = false;
  bool _translateToMansi = true;

  static const List<String> supportedExtensions = ['txt', 'md', 'json', 'xml', 'html', 'rtf'];
  static const int maxChunkSize = 200;

  void setTranslationDirection({required bool toMansi}) {
    _translateToMansi = toMansi;
  }

  bool get isTranslatingToMansi => _translateToMansi;

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

  // ============================================================
  // ГЛАВНЫЙ МЕТОД ПЕРЕВОДА
  // ============================================================
  Future<File?> translateFile(File inputFile, {Function(double)? onProgress}) async {
    _isCancelled = false;
    progressNotifier.value = 0.0;

    final extension = _getOriginalExtension(inputFile.path);
    statusNotifier.value = TranslationStatus(
      fileName: inputFile.path.split('/').last,
      status: 'Чтение файла...',
      progress: 0.0,
    );

    try {
      final content = await inputFile.readAsString(encoding: utf8);
      if (_isCancelled) return null;

      debugPrint('📄 Файл прочитан, размер: ${content.length} символов, формат: $extension');

      String translatedContent;
      switch (extension) {
        case 'json':
          translatedContent = await _translateJson(content, onProgress);
          break;
        case 'xml':
          translatedContent = await _translateXml(content, onProgress);
          break;
        case 'html':
          translatedContent = await _translateHtml(content, onProgress);
          break;
        case 'rtf':
          translatedContent = await _translateRtf(content, onProgress);
          break;
        case 'md':
          translatedContent = await _translateMarkdown(content, onProgress);
          break;
        default:
          translatedContent = await _translatePlainText(content, onProgress);
      }

      if (_isCancelled) return null;

      final outputFile = await _saveTranslatedFile(
        inputFile.path.split('/').last,
        translatedContent,
        extension,
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

  void cancelTranslation() {
    _isCancelled = true;
    statusNotifier.value = TranslationStatus(
      fileName: statusNotifier.value?.fileName ?? '',
      status: 'Отменено',
      progress: -1.0,
    );
  }

  // ============================================================
  // JSON - переводим ТОЛЬКО значения строк, НЕ ключи
  // ============================================================
  Future<String> _translateJson(String content, Function(double)? onProgress) async {
    try {
      final data = json.decode(content);
      final translatedData = await _translateJsonValue(data, onProgress);
      return const JsonEncoder.withIndent('  ').convert(translatedData);
    } catch (e) {
      debugPrint('❌ Ошибка перевода JSON: $e');
      return content;
    }
  }

  Future<dynamic> _translateJsonValue(dynamic value, Function(double)? onProgress) async {
    if (value is String) {
      return await _translateText(value, toMansi: _translateToMansi);
    } else if (value is Map<String, dynamic>) {
      final translated = <String, dynamic>{};
      int i = 0;
      for (var entry in value.entries) {
        if (_isCancelled) return translated;
        final shouldTranslate = !_isJsonSkipField(entry.key);
        if (shouldTranslate) {
          translated[entry.key] = await _translateJsonValue(entry.value, onProgress);
        } else {
          translated[entry.key] = entry.value;
        }
        onProgress?.call(0.1 + (i++ / value.length) * 0.8);
      }
      return translated;
    } else if (value is List) {
      final translated = <dynamic>[];
      for (int i = 0; i < value.length; i++) {
        if (_isCancelled) return translated;
        translated.add(await _translateJsonValue(value[i], onProgress));
        onProgress?.call(0.1 + (i / value.length) * 0.8);
      }
      return translated;
    }
    return value;
  }

  bool _isJsonSkipField(String key) {
    const skipFields = {'id', 'icon', 'transcription'};
    return skipFields.contains(key);
  }

  // ============================================================
// XML - переводим ТОЛЬКО текст, НЕ теги и атрибуты (ИСПРАВЛЕННЫЙ)
// ============================================================
  Future<String> _translateXml(String content, Function(double)? onProgress) async {
    debugPrint('🔍 НАЧАЛО перевода XML, длина: ${content.length}');
    debugPrint('🔍 Первые 200 символов: ${content.substring(0, content.length > 200 ? 200 : content.length)}...');

    try {
      final document = xml.XmlDocument.parse(content);
      debugPrint('🔍 XML распарсен, корневых элементов: ${document.children.length}');

      // ✅ Обходим все дочерние узлы корня
      for (var child in document.children.toList()) {
        if (_isCancelled) return '';
        await _translateXmlNode(child, onProgress);
      }

      final result = document.toXmlString(pretty: true, indent: '  ');
      debugPrint('✅ XML переведён, длина: ${result.length}');
      return result;
    } catch (e) {
      debugPrint('❌ XML парсинг упал: $e');
      return await _translatePlainText(content, onProgress);
    }
  }

  Future<void> _translateXmlNode(xml.XmlNode node, Function(double)? onProgress) async {
    // ✅ ОБРАБАТЫВАЕМ ТЕКСТОВЫЕ УЗЛЫ
    if (node is xml.XmlText) {
      final trimmed = node.text.trim();
      if (trimmed.isNotEmpty) {
        debugPrint('📝 XML текст для перевода: "$trimmed"');
        final translated = await _translateText(trimmed, toMansi: _translateToMansi);
        final parent = node.parent;
        if (parent != null) {
          final newText = xml.XmlText(translated);
          final index = parent.children.indexOf(node);
          if (index != -1) {
            parent.children[index] = newText;
          }
        }
      }
      return; // ✅ ВАЖНО: завершаем обработку текстового узла
    }

    // ✅ ОБРАБАТЫВАЕМ ЭЛЕМЕНТЫ
    if (node is xml.XmlElement) {
      // ✅ РЕКУРСИВНО ОБХОДИМ ВСЕ ДОЧЕРНИЕ УЗЛЫ
      for (var child in node.children.toList()) {
        if (_isCancelled) return;
        await _translateXmlNode(child, onProgress);
      }
    }
  }

  // ============================================================
  // HTML - ИСПРАВЛЕННЫЙ (правильный рекурсивный обход)
  // ============================================================
  Future<String> _translateHtml(String content, Function(double)? onProgress) async {
    debugPrint('🔍 НАЧАЛО перевода HTML, длина: ${content.length}');

    try {
      final document = html_parser.parse(content);
      debugPrint('🔍 HTML распарсен, узлов: ${document.nodes.length}');

      // ✅ ОБХОДИМ ВСЕ УЗЛЫ НА ВЕРХНЕМ УРОВНЕ
      for (var node in document.nodes.toList()) {
        if (_isCancelled) return '';
        await _translateHtmlNode(node, onProgress);
      }

      final result = document.outerHtml;
      debugPrint('✅ HTML переведён, длина: ${result.length}');
      return result;
    } catch (e) {
      debugPrint('❌ HTML парсинг упал: $e');
      return await _translatePlainText(content, onProgress);
    }
  }

  Future<void> _translateHtmlNode(html.Node node, Function(double)? onProgress) async {
    // ✅ ОБРАБАТЫВАЕМ ТЕКСТОВЫЕ УЗЛЫ
    if (node is html.Text) {
      final trimmed = node.text.trim();
      if (trimmed.isNotEmpty) {
        debugPrint('📝 Перевод текстового узла: "$trimmed"');
        final translated = await _translateText(trimmed, toMansi: _translateToMansi);
        node.replaceWith(html.Text(translated));
      }
      return; // ✅ ВАЖНО: завершаем обработку текстового узла
    }

    // ✅ ОБРАБАТЫВАЕМ ЭЛЕМЕНТЫ
    if (node is html.Element) {
      // Атрибуты, которые НЕ ПЕРЕВОДИМ
      final skipAttrs = {
        'href', 'src', 'class', 'id', 'style', 'rel',
        'type', 'sizes', 'crossorigin', 'charset',
      };

      // Атрибуты, которые МОЖНО ПЕРЕВОДИТЬ
      final translateAttrs = {
        'content',
        'title',
        'alt',
        'placeholder',
        'value',
      };

      for (var attr in node.attributes.keys.toList()) {
        if (skipAttrs.contains(attr)) continue;
        if (translateAttrs.contains(attr)) {
          final value = node.attributes[attr]!;
          if (!value.startsWith('/') &&
              !value.startsWith('http') &&
              !value.startsWith('#') &&
              !value.startsWith('{') &&
              !value.startsWith('@') &&
              !value.startsWith('data:')) {
            try {
              debugPrint('📝 Перевод атрибута $attr="$value"');
              final translated = await _translateText(value, toMansi: _translateToMansi);
              node.attributes[attr] = translated;
            } catch (e) {
              debugPrint('⚠️ Не удалось перевести атрибут $attr: $e');
            }
          }
        }
      }

      // ✅ РЕКУРСИВНО ОБХОДИМ ВСЕ ДОЧЕРНИЕ УЗЛЫ
      for (var child in node.nodes.toList()) {
        if (_isCancelled) return;
        await _translateHtmlNode(child, onProgress);
      }
    }
  }

  // ============================================================
  // RTF
  // ============================================================
  Future<String> _translateRtf(String content, Function(double)? onProgress) async {
    final result = await _translateRtfContent(content, onProgress);
    return result;
  }

  Future<String> _translateRtfContent(String content, Function(double)? onProgress) async {
    final lines = content.split('\n');
    final translatedLines = <String>[];

    for (int i = 0; i < lines.length; i++) {
      if (_isCancelled) return translatedLines.join('\n');
      final line = lines[i];

      if (_containsRtfText(line)) {
        final translated = await _translateText(line, toMansi: _translateToMansi);
        translatedLines.add(translated);
      } else {
        translatedLines.add(line);
      }
      onProgress?.call(0.1 + (i / lines.length) * 0.8);
    }
    return translatedLines.join('\n');
  }

  bool _containsRtfText(String line) {
    final stripped = line.replaceAll(RegExp(r'\\.+?[; ]'), '');
    return stripped.trim().isNotEmpty && !stripped.contains('{') && !stripped.contains('}');
  }

  // ============================================================
  // Markdown
  // ============================================================
  Future<String> _translateMarkdown(String content, Function(double)? onProgress) async {
    final lines = content.split('\n');
    final translatedLines = <String>[];

    for (int i = 0; i < lines.length; i++) {
      if (_isCancelled) return translatedLines.join('\n');
      final translated = await _translateMarkdownLine(lines[i]);
      translatedLines.add(translated);
      onProgress?.call(0.1 + (i / lines.length) * 0.8);
    }
    return translatedLines.join('\n');
  }

  Future<String> _translateMarkdownLine(String line) async {
    final trimmed = line;

    if (RegExp(r'^#{1,6}\s+').hasMatch(trimmed)) {
      final match = RegExp(r'^(#{1,6})\s+(.*)').firstMatch(trimmed);
      if (match != null) {
        final translated = await _translateText(match.group(2)!, toMansi: _translateToMansi);
        return '${match.group(1)} $translated';
      }
    }

    if (RegExp(r'^[\*\-\+]\s+').hasMatch(trimmed)) {
      final match = RegExp(r'^([\*\-\+])\s+(.*)').firstMatch(trimmed);
      if (match != null) {
        final translated = await _translateText(match.group(2)!, toMansi: _translateToMansi);
        return '${match.group(1)} $translated';
      }
    }

    if (RegExp(r'^\d+\.\s+').hasMatch(trimmed)) {
      final match = RegExp(r'^(\d+\.)\s+(.*)').firstMatch(trimmed);
      if (match != null) {
        final translated = await _translateText(match.group(2)!, toMansi: _translateToMansi);
        return '${match.group(1)} $translated';
      }
    }

    if (RegExp(r'^>\s+').hasMatch(trimmed)) {
      final match = RegExp(r'^(>\s+)(.*)').firstMatch(trimmed);
      if (match != null) {
        final translated = await _translateText(match.group(2)!, toMansi: _translateToMansi);
        return '${match.group(1)}$translated';
      }
    }

    if (RegExp(r'\[.*\]\(.*\)').hasMatch(trimmed)) {
      final match = RegExp(r'\[(.*?)\]\((.*?)\)').firstMatch(trimmed);
      if (match != null) {
        final translated = await _translateText(match.group(1)!, toMansi: _translateToMansi);
        return trimmed.replaceFirst(match.group(1)!, translated);
      }
    }

    return await _translateText(trimmed, toMansi: _translateToMansi);
  }

  // ============================================================
  // Plain Text
  // ============================================================
  Future<String> _translatePlainText(String content, Function(double)? onProgress) async {
    final lines = content.split('\n');
    final translatedLines = <String>[];

    for (int i = 0; i < lines.length; i++) {
      if (_isCancelled) return translatedLines.join('\n');
      final line = lines[i].trim();
      if (line.isNotEmpty) {
        final translated = await _translateText(line, toMansi: _translateToMansi);
        translatedLines.add(translated);
      } else {
        translatedLines.add('');
      }
      onProgress?.call(0.1 + (i / lines.length) * 0.8);
    }
    return translatedLines.join('\n');
  }

  // ============================================================
  // ЯДРО ПЕРЕВОДА
  // ============================================================
  Future<String> _translateText(String text, {required bool toMansi}) async {
    if (text.trim().isEmpty) return text;

    final int sourceLanguage = toMansi ? 1 : 2;
    final int targetLanguage = toMansi ? 2 : 1;

    final chunks = _splitTextIntoChunks(text);
    final translatedChunks = <String>[];

    for (var chunk in chunks) {
      if (_isCancelled) return translatedChunks.join(' ');
      final result = await _translateChunk(chunk, sourceLanguage, targetLanguage);
      translatedChunks.add(result);
    }

    return translatedChunks.join(' ');
  }

  Future<String> _translateChunk(String text, int sourceLang, int targetLang) async {
    final Map<String, dynamic> data = {
      "text": text,
      "sourceLanguage": sourceLang,
      "targetLanguage": targetLang,
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
      } else {
        debugPrint('❌ Ошибка API: ${response.statusCode}');
        return text;
      }
    } catch (e) {
      debugPrint('❌ Ошибка перевода: $e');
      return text;
    }
  }

  List<String> _splitTextIntoChunks(String text) {
    final chunks = <String>[];
    for (int i = 0; i < text.length; i += maxChunkSize) {
      int end = (i + maxChunkSize < text.length) ? i + maxChunkSize : text.length;
      if (end < text.length && !RegExp(r'[\s.,!?;:)]').hasMatch(text[end])) {
        int lastSpace = text.lastIndexOf(' ', end);
        if (lastSpace > i) {
          end = lastSpace + 1;
        }
      }
      chunks.add(text.substring(i, end).trim());
    }
    return chunks;
  }

  // ============================================================
  // СОХРАНЕНИЕ
  // ============================================================
  Future<File?> _saveTranslatedFile(String originalName, String content, String extension) async {
    final directionSuffix = _translateToMansi ? '_to_mansi' : '_from_mansi';
    final fileName = originalName.replaceAll('.$extension', '${directionSuffix}_translated.$extension');

    debugPrint('💾 Сохранение файла: $fileName');

    try {
      final bytes = utf8.encode(content);
      final plugin = FlutterMediaStore();
      final String mimeType = _getMimeType(extension);
      String? savedPath;

      await plugin.saveFile(
        fileData: bytes,
        mimeType: mimeType,
        rootFolderName: 'MansiTranslator',
        fileName: fileName,
        folderName: '',
        onSuccess: (String uri, String filePath) {
          savedPath = filePath;
          debugPrint('✅ Файл сохранён: $filePath');
          debugPrint('✅ URI: $uri');
        },
        onError: (String error) {
          debugPrint('❌ Ошибка сохранения: $error');
        },
      );

      if (savedPath != null && savedPath!.isNotEmpty) {
        return File(savedPath!);
      } else {
        throw Exception('flutter_media_store вернул null или пустой путь');
      }

    } catch (e) {
      debugPrint('⚠️ flutter_media_store не сработал: $e');

      try {
        final appDir = await getApplicationDocumentsDirectory();
        final fallbackDir = Directory('${appDir.path}/MansiTranslator');
        if (!await fallbackDir.exists()) {
          await fallbackDir.create(recursive: true);
        }

        final file = File('${fallbackDir.path}/$fileName');
        await file.writeAsString(content, encoding: utf8);
        debugPrint('✅ Файл сохранён в Documents: ${file.path}');
        return file;

      } catch (fallbackError) {
        debugPrint('❌ Fallback не сработал: $fallbackError');
        return null;
      }
    }
  }

  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'txt': return 'text/plain';
      case 'json': return 'application/json';
      case 'xml': return 'text/xml';
      case 'html': return 'text/html';
      case 'rtf': return 'text/rtf';
      case 'md': return 'text/markdown';
      default: return 'text/plain';
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