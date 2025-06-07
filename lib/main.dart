import 'dart:convert';
import 'dart:async';
import 'dart:developer';
import 'dart:js_interop';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// Условные импорты для разных платформ
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast_web/sembast_web.dart' as sembast_web;
import 'package:sembast_web/sembast_web.dart' as sembastWeb;

// Для веб-платформы
import 'package:web/web.dart' as web show Blob, BlobPart, BlobPropertyBag, DragEvent, Event, File, FileReader, HTMLAnchorElement, URL, document;
import 'package:js/js.dart' as js;
import 'package:js/js_util.dart' as js_util;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    web.document.addEventListener('dragover', _handleDragOver.toJS);
    web.document.addEventListener('drop', _handleDrop.toJS);
  }

  runApp(const MyApp());
}

void _handleDragOver(web.Event e) {
  js_util.callMethod(e, 'preventDefault', []);
}

void _handleDrop(web.Event e) {
  final event = e as web.DragEvent;
  js_util.callMethod(event, 'preventDefault', []);

  final files = js_util.getProperty(event.dataTransfer as Object, 'files');
  if (js_util.getProperty(files, 'length') > 0) {
    final file = js_util.getProperty(files, '0');
    if (file != null) {
      final reader = web.FileReader();
      js_util.callMethod(reader, 'addEventListener', ['load', _handleFileLoad]);
      js_util.callMethod(reader, 'readAsText', [file]);
    }
  }
}

void _handleFileLoad(web.Event e) {
  // Приводим target к FileReader
  final target = e.target;
  if (target == null) return;

  // Для веб-платформы используем JS-интероп для проверки типа
  final reader = target is web.FileReader ? target : null;
  if (reader == null) return;

  // Получаем результат
  final content = reader.result;
  if (content == null) return;

  // Конвертируем содержимое в строку
  String contentString;
  contentString = '';
  try {
    final dynamic parsedJson = json.decode(contentString);
    if (parsedJson is! Map<String, dynamic>) {
      throw Exception('Invalid JSON format: expected Map');
    }

    final jsonData = parsedJson;

    if (jsonData['version'] == 1 && jsonData['data'] != null) {
      AppDatabase().importAllData(jsonData)
          .then((importedCount) {
        _showSuccess('Импортировано $importedCount записей');
      }).catchError((e) {
        _showError('Ошибка импорта: $e');
      });
    } else {
      _showError('Неверный формат файла', isError: false);
    }
  } catch (e) {
    _showError('Ошибка обработки файла: $e');
  }

  try {
    final jsonData = json.decode(contentString) as Map<String, dynamic>;

    if (jsonData['version'] == 1 && jsonData['data'] != null) {
      AppDatabase().importAllData(jsonData)
          .then((importedCount) {
        _showSuccess('Импортировано $importedCount записей');
      }).catchError((e) {
        _showError('Ошибка импорта: $e');
      });
    } else {
      _showError('Неверный формат файла', isError: false);
    }
  } catch (e) {
    _showError('Ошибка обработки файла: $e');
  }
}

void _showSuccess(String message) {
  if (navigatorKey.currentContext != null && navigatorKey.currentState?.mounted == true) {
    ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

void _showError(String message, {bool isError = true}) {
  if (navigatorKey.currentContext != null && navigatorKey.currentState?.mounted == true) {
    ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? Colors.red : Colors.orange),
    );
  }
}

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  late final Future<Database> _database;

  factory AppDatabase() {
    return _instance;
  }

  AppDatabase._internal() {
    _database = _initDatabase();
  }

  Future<Database> get database => _database;

  Future<Database> _initDatabase() async {
    final databaseFactory = kIsWeb
        ? sembast_web.databaseFactoryWeb
        : databaseFactoryIo;

    return await databaseFactory.openDatabase('translations.db');
  }

  // All methods need to await _database before using the database
  Future<int> clearTranslationHistory() async {
    final db = await _database;
    final store = intMapStoreFactory.store('translations');
    return await store.delete(db);
  }

  Future<int> removeDuplicateTranslations() async {
    final db = await _database;
    final store = intMapStoreFactory.store('translations');
    final allTranslations = await store.find(db);

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
          await store.record(group[i].key).delete(db);
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
    final store = intMapStoreFactory.store('translations');

    // Создаем копию Map перед изменением
    List<Map<String, dynamic>> results = [];

    try {
      final records = await store.find(db);

      for (final record in records) {
        // Создаем новый Map для каждой записи
        final item = Map<String, dynamic>.from(record.value);
        item['id'] = record.key;
        results.add(item);
      }

      // Фильтрация по датам
      if (startDate != null || endDate != null) {
        results = results.where((item) {
          final timestamp = DateTime.parse(item['timestamp']);
          return (startDate == null || timestamp.isAfter(startDate)) &&
              (endDate == null || timestamp.isBefore(endDate));
        }).toList();
      }

      // Фильтрация по поисковому запросу
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        results = results.where((item) {
          final original = item['original_text']?.toString().toLowerCase() ?? '';
          final translated = item['translated_text']?.toString().toLowerCase() ?? '';
          return original.contains(query) || translated.contains(query);
        }).toList();
      }

      return results;
    } catch (e) {
      debugPrint('Ошибка при получении истории: $e');
      rethrow;
    }
  }

  Future<int> addTranslation(
      String originalText,
      String translatedText,
      String timestamp,
      String direction,
      ) async {
    final db = await _database;
    final store = intMapStoreFactory.store('translations');
    return await store.add(db, {
      'original_text': originalText,
      'translated_text': translatedText,
      'timestamp': timestamp,
      'direction': direction,
    });
  }

  Future<dynamic> exportAllData() async {
    final db = await _database;
    final store = intMapStoreFactory.store('translations');
    final records = await store.find(db);

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
    final store = intMapStoreFactory.store('translations');

    // Исправление: явное приведение типа и проверка
    final dynamic data = jsonData['data'];
    if (data is! List) {
      throw Exception('Expected List but got ${data.runtimeType}');
    }

    final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(data);

    int importedCount = 0;
    for (var item in items) {
      await store.add(db, item);
      importedCount++;
    }

    return importedCount;
  }
}

class TranslationHistoryItem {
  final String originalText;
  final String translatedText;
  final DateTime timestamp;
  final String direction;

  TranslationHistoryItem(this.originalText, this.translatedText, this.timestamp, this.direction);
}

// Класс мансийской клавиатуры
class MansiKeyboard extends StatelessWidget {
  final Function(String) onTextInput;
  final VoidCallback onBackspace;

  const MansiKeyboard({
    super.key,
    required this.onTextInput,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> mansiLetters = [
      'а̄', 'о̄', 'ē', 'ы̄', 'э̄', 'ӈ', 'ю̄', 'ӣ', 'я̄', 'ё̄', 'ӯ'
    ];
    return Container(
      color: Color(0xFF0A4B47),
      padding: const EdgeInsets.all(5),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: mansiLetters.sublist(0, 11).map((letter) {
              return _buildKey(letter);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String letter) {
    return SizedBox(
      width: 30, // Фиксированная ширина кнопок
      height: 40, // Фиксированная высота кнопок
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7),
          ),
          padding: EdgeInsets.all(3), // Убираем внутренние отступы
        ),
        onPressed: () => onTextInput(letter),
        child: Text(
          letter,
          style: TextStyle(fontSize: 23),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Переводчик',
      navigatorKey: navigatorKey,
      color: const Color(0xFF0A4B47),
      theme: ThemeData(
        scaffoldBackgroundColor: Color(0xFFE7E4DF),
      ),
      home: TranslatePage(),
    );
  }
}

class TranslatePage extends StatefulWidget {
  const TranslatePage({super.key});
  @override
  State<TranslatePage> createState() => _TranslatePageState();
}

class _TranslatePageState extends State<TranslatePage> {
  bool _isExporting = false;
  bool _isImporting = false;
  final String translateApiEndpoint = "https://ethnoportal.admhmao.ru/api/machine-translates/translate";
  final TextEditingController controller1 = TextEditingController();
  final TextEditingController controller2 = TextEditingController();
  Timer? _debounce;
  bool _isSwapped = false;
  bool _isMansiLanguage = false;
  bool _isKeyboardVisible = false;
  final FocusNode _focusNode = FocusNode();
  List<TranslationHistoryItem> translationHistory = [];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_keyboardListener);
    // Инициализация базы данных после полной загрузки Flutter
    WidgetsFlutterBinding.ensureInitialized();
    AppDatabase().database.then((db) {
      print('База данных инициализирована');
    }).catchError((e) {
      print('Ошибка инициализации базы данных: $e');
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_keyboardListener);
    _focusNode.dispose();
    controller1.dispose();
    controller2.dispose();
    super.dispose();
  }

  void _keyboardListener() {
    if (_focusNode.hasFocus) {
      setState(() => _isKeyboardVisible = true);
    } else {
      setState(() => _isKeyboardVisible = false);
    }
  }

  Future<void> getTranslate(String text) async {
    final int sourceLanguage = _isSwapped ? 2 : 1;
    final int targetLanguage = _isSwapped ? 1 : 2;
    final String direction = '$sourceLanguage -> $targetLanguage';

    Future<void> saveTranslationHistory(String original, String translated) async {
      print('Saving translation: $original -> $translated');
      try {
        await AppDatabase().addTranslation(
            original,
            translated,
            DateTime.now().toIso8601String(),
            direction
        );
        print('Translation saved successfully');
      } catch (e) {
        print('Error saving translation: $e');
      }
    }

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
      );

      if (response.statusCode == 200) {
        String responseBody = utf8.decode(response.bodyBytes);
        final Map<String, dynamic> responseData = json.decode(responseBody);
        setState(() {
          controller2.text = responseData['translatedText'] ?? 'Ошибка: Перевод не найден';
        });
        saveTranslationHistory(text, controller2.text);
      } else {
        setState(() {
          controller2.text = 'Ошибка при запросе данных';
        });
      }
    } catch (e) {
      setState(() {
        controller2.text = 'Ошибка при соединении с сервером';
      });
    }
  }

  void swapLanguages() {
    setState(() {
      _isSwapped = !_isSwapped;
      String temp = text1;
      text1 = text2;
      text2 = temp;

      String tempController = controller1.text;
      controller1.text = controller2.text;
      controller2.text = tempController;

      _isMansiLanguage = text1 == 'Мансийский';
    });
    getTranslate(controller1.text);
  }

  void _onTextChanged(String text) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () => getTranslate(text));
  }

  void goToHistoryPage() {
    Navigator.push(
      context as BuildContext,
      MaterialPageRoute(builder: (context) => TranslationHistoryPage()),
    );
  }

  String text1 = 'Русский';
  String text2 = 'Мансийский';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openMenu() {
    _scaffoldKey.currentState?.openEndDrawer();
  }


  Future<void> _exportHistory(BuildContext context) async {
    if (!mounted) return;
    setState(() => _isExporting = true);

    try {
      final exportedData = await AppDatabase().exportAllData();

      if (kIsWeb) {
        // Веб-экспорт
        final content = exportedData as String;
        final bytes = utf8.encode(content);
        final blob = web.Blob([bytes] as JSArray<web.BlobPart>, 'application/json' as web.BlobPropertyBag);
        final url = web.URL.createObjectURL(blob);

        final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
        anchor.href = url;
        anchor.download = 'translations_export.json';
        anchor.click();

        web.URL.revokeObjectURL(url);
      } else {
        // Мобильный экспорт
        final file = exportedData as File;
        final path = await FilePicker.platform.saveFile(
          fileName: 'translations_export.json',
        );
        if (path != null) {
          await file.copy(path);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Данные экспортированы')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка экспорта: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _importHistory(BuildContext context) async {
    if (!mounted) return;
    setState(() => _isImporting = true);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.isNotEmpty) {
        String fileContent;

        if (kIsWeb) {
          fileContent = utf8.decode(result.files.first.bytes!);
        } else {
          final file = File(result.files.first.path!);
          fileContent = await file.readAsString();
        }

        final Map<String, dynamic> jsonData = json.decode(fileContent);

        if (jsonData['version'] == 1 && jsonData['data'] != null) {
          final importedCount = await AppDatabase().importAllData(jsonData);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Успешно импортировано $importedCount записей')),
            );
            setState(() {});
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Неверный формат файла')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка импорта: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset("assets/images/logo.png"),
        ),
        title: const Text("Переводчик"),
        backgroundColor: const Color(0xFF0A4B47),
        foregroundColor: Colors.white,
        actions: [
          ElevatedButton(
            onPressed: _openMenu,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A4B47),
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(12),
            ),
            child: const Icon(Icons.menu, color: Colors.white, size: 30),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Text(text1, style: const TextStyle(fontSize: 20)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A4B47),
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(12),
                      ),
                      onPressed: swapLanguages,
                      child: const Icon(Icons.swap_horiz, color: Colors.white, size: 30),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      child: Text(text2, style: const TextStyle(fontSize: 20, color: Colors.black)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  margin: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black),
                        ),
                        child: Stack(
                          children: [
                            TextField(
                              focusNode: _focusNode,
                              controller: controller1,
                              maxLines: 10,
                              onChanged: (text) => _onTextChanged(text),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.all(16),
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(Icons.content_copy, size: 30, color: Color(0xFF0A4B47)),
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: controller2.text));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Текст скопирован')),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black),
                        ),
                        child: Stack(
                          children: [
                            TextField(
                              controller: controller2,
                              maxLines: 10,
                              readOnly: true,
                              onChanged: (text) => _onTextChanged(text),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.all(16),
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(Icons.content_copy, size: 30, color: Color(0xFF0A4B47)),
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: controller2.text));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Текст скопирован')),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isMansiLanguage && _isKeyboardVisible)
            MansiKeyboard(
              onTextInput: (text) {
                final newText = controller1.text + text;
                controller1.text = newText;
                _onTextChanged(newText);
              },
              onBackspace: () {
                if (controller1.text.isNotEmpty) {
                  final newText = controller1.text.substring(0, controller1.text.length - 1);
                  controller1.text = newText;
                  _onTextChanged(newText);
                }
              },
            ),
        ],
      ),
      endDrawer: Drawer(
        child: Container(
          padding: const EdgeInsets.only(top: 40),
          decoration: const BoxDecoration(color: Color(0xFFE7E4DF)),
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              ListTile(
                title: const Text('Переводчик', style: TextStyle(fontSize: 20, color: Color(0xFF0A4B47))),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TranslatePage()),
                  );
                },
              ),
              ListTile(
                title: const Text('Обучение', style: TextStyle(fontSize: 20, color: Colors.black)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MainMenuPage()),
                  );
                },
              ),
              ListTile(
                title: const Text('История переводов', style: TextStyle(fontSize: 20, color: Colors.black)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TranslationHistoryPage()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainMenuPage extends StatelessWidget {
  final List<Map<String, dynamic>> modules = [
    {'id': 1, 'title': 'Модуль 1'},
    {'id': 2, 'title': 'Модуль 2'},
    {'id': 3, 'title': 'Модуль 3'},
    {'id': 4, 'title': 'Модуль 4'},
  ];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openMenu() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  MainMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isVerySmallScreen = screenSize.height < 600;
    final isSmallScreen = screenSize.width < 600;

    // Расчет динамических отступов
    final double rowSpacing = isVerySmallScreen ?
    max(20.0, screenSize.height * 0.02) : // Не менее 20px
    max(30.0, screenSize.height * 0.04);  // Не менее 30px

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Главное меню'),
        backgroundColor: const Color(0xFF0A4B47),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, size: 30),
            onPressed: _openMenu,
          ),
        ],
      ),
      body: SingleChildScrollView( // Добавляем скролл для очень маленьких экранов
        child: Container(
          constraints: BoxConstraints(
            minHeight: screenSize.height,
          ),
          child: Center(
            child: SizedBox(
              width: isSmallScreen ? screenSize.width * 0.9 : 560,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildMenuRow(context, modules[0], 1, Alignment(-0.4, 0)),
                  SizedBox(height: rowSpacing),
                  _buildMenuRow(context, modules[1], 2, Alignment(0.4, 0)),
                  SizedBox(height: rowSpacing),
                  _buildMenuRow(context, modules[2], 3, Alignment(-0.4, 0)),
                  SizedBox(height: rowSpacing),
                  _buildMenuRow(context, modules[3], 4, Alignment(0.4, 0)),
                  SizedBox(height: rowSpacing), // Дополнительный отступ снизу
                ],
              ),
            ),
          ),
        ),
      ),
      endDrawer: _buildAppDrawer(context),
    );
  }

  Widget _buildMenuRow(BuildContext context, Map<String, dynamic> module, int number, Alignment alignment) {
    final screenSize = MediaQuery.of(context).size;
    final isVerySmallScreen = screenSize.height < 600;

    return Align(
      alignment: alignment,
      child: Container(
        width: 120,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            InkWell(
            onTap: () {
      Navigator.push(
      context,
      MaterialPageRoute(
      builder: (context) => ModuleLevelsPage(
      moduleId: module['id'],
      moduleTitle: module['title'],
      ),
      ),
      );
      },
        child: Container(
          width: isVerySmallScreen ? 80 : 100,
          height: isVerySmallScreen ? 80 : 100,
          decoration: BoxDecoration(
            color: const Color(0xFF0A4B47),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.black,
              width: isVerySmallScreen ? 2 : 3,
            ),
            boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),],
            ),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: isVerySmallScreen ? 50 : 60,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          module['title'],
          style: TextStyle(
            fontSize: isVerySmallScreen ? 14 : 16,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        ],
      ),
    ),
    );
  }

  Widget _buildAppDrawer(BuildContext context) {
    return Drawer(
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 20,
        ),
        decoration: const BoxDecoration(color: Color(0xFFE7E4DF)),
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            ListTile(
              title: Text('Переводчик',
                  style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width * 0.05,
                      color: Colors.black)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => TranslatePage()));
              },
            ),
            ListTile(
              title: Text('Обучение',
                  style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width * 0.05,
                      color: const Color(0xFF0A4B47))),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text('История переводов',
                  style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width * 0.05,
                      color: Colors.black)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => TranslationHistoryPage()));
              },
            ),
          ],
        ),
      ),
    );
  }
}

// 3. Страница с уровнями модуля
class ModuleLevelsPage extends StatelessWidget {
  final int moduleId;
  final String moduleTitle;

  ModuleLevelsPage({super.key, required this.moduleId, required this.moduleTitle});

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openMenu() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(moduleTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: const Color(0xFF0A4B47),
        foregroundColor: Colors.white,
        actions: [
          ElevatedButton(
            onPressed: _openMenu,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A4B47),
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(12),
            ),
            child: const Icon(Icons.menu, color: Colors.white, size: 30),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: 5,
        itemBuilder: (context, index) {
          int level = index + 1;
          return ListTile(
            title: Text('Уровень $level'),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TaskPage(moduleId: moduleId, level: level),
                ),
              );
            },
          );
        },
      ),
      endDrawer: _buildAppDrawer(context),
    );
  }
}

// 4. Страница с заданиями
class TaskPage extends StatefulWidget {
  final int moduleId;
  final int level;

  const TaskPage({super.key, required this.moduleId, required this.level});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  late List<Map<String, dynamic>> tasks;
  int currentTaskIndex = 0;
  int score = 0;

  @override
  void initState() {
    super.initState();
    tasks = _getTasksForModule(widget.moduleId, widget.level);
  }

  List<Map<String, dynamic>> _getTasksForModule(int moduleId, int level) {
    List<Map<String, dynamic>> tasks = [];
    for (int i = 1; i <= 5; i++) {
      String taskType, question;
      List<String> options;
      String correctAnswer;
      if (moduleId == 1) {
        taskType = 'Выбор перевода';
        question = 'Слово $i на мансийском';
        options = ['Вариант 1', 'Вариант 2', 'Вариант 3', 'Вариант 4'];
        correctAnswer = 'Вариант ${i % 4 + 1}';
      } else if (moduleId == 2) {
        taskType = 'Собери фразу';
        question = 'Составьте фразу $i';
        options = ['Слово 1', 'Слово 2', 'Слово 3', 'Слово 4'];
        correctAnswer = 'Слово 1 Слово 2 Слово 3';
      } else {
        taskType = 'Правда/Ложь';
        question = 'Утверждение $i';
        options = ['Правда', 'Ложь'];
        correctAnswer = i % 2 == 0 ? 'Правда' : 'Ложь';
      }
      tasks.add({
        'type': taskType,
        'question': question,
        'options': options,
        'correct_answer': correctAnswer,
      });
    }
    return tasks;
  }

  void _handleAnswer(String answer) {
    bool isCorrect = answer == tasks[currentTaskIndex]['correct_answer'];
    if (isCorrect) setState(() => score += 20);
    if (currentTaskIndex < tasks.length - 1) {
      setState(() => currentTaskIndex++);
    } else {
      Navigator.pop(context as BuildContext);
    }
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openMenu() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final currentTask = tasks[currentTaskIndex];
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text('Уровень ${widget.level} - Задание ${currentTaskIndex + 1}'),
        backgroundColor: const Color(0xFF0A4B47),
        foregroundColor: Colors.white,
        actions: [
          ElevatedButton(
            onPressed: _openMenu,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A4B47),
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(12),
            ),
            child: const Icon(Icons.menu, color: Colors.white, size: 30),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(currentTask['question'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Text('Тип задания: ${currentTask['type']}'),
            const SizedBox(height: 20),
            ...currentTask['options'].map<Widget>((option) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ElevatedButton(
                onPressed: () => _handleAnswer(option),
                style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
                child: Text(option),
              ),
            )).toList(),
            const SizedBox(height: 20),
            LinearProgressIndicator(value: (currentTaskIndex + 1) / tasks.length),
            const SizedBox(height: 10),
            Text('Прогресс: ${currentTaskIndex + 1}/${tasks.length}'),
            Text('Очки: $score'),
          ],
        ),
      ),
      endDrawer: _buildAppDrawer(context),
    );
  }
}

// 5. Страница истории переводов
class TranslationHistoryPage extends StatefulWidget {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  TranslationHistoryPage({super.key});

  @override
  State<TranslationHistoryPage> createState() => _TranslationHistoryPageState();
}

class _TranslationHistoryPageState extends State<TranslationHistoryPage> {
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isClearing = false;
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy HH:mm');

  // Добавленный метод для очистки истории
  Future<void> _clearHistory(BuildContext context) async {
    if (!mounted) return;
    setState(() => _isClearing = true);

    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Подтверждение'),
          content: const Text('Вы уверены, что хотите очистить всю историю переводов?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Очистить', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await AppDatabase().clearTranslationHistory();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('История переводов очищена')),
          );
          setState(() {});
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при очистке истории: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClearing = false);
      }
    }
  }

  // Добавленный метод для удаления дубликатов
  Future<void> _removeDuplicates(BuildContext context) async {
    if (!mounted) return;
    setState(() => _isClearing = true);

    try {
      final removedCount = await AppDatabase().removeDuplicateTranslations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Удалено $removedCount дубликатов')),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при удалении дубликатов: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClearing = false);
      }
    }
  }
  Future<void> _exportAllData(BuildContext context) async {
    if (!mounted) return;
    setState(() => _isExporting = true);

    try {
      final exportResult = await AppDatabase().exportAllData();

      if (kIsWeb) {
        // Handle web export
        final jsonStr = exportResult as String;
        final bytes = utf8.encode(jsonStr);
        final blob = web.Blob(
            [bytes.toJS].toJS,
            web.BlobPropertyBag(type: 'application/json')
        );
        final url = web.URL.createObjectURL(blob);

        final anchor = web.document.createElement('a') as web.HTMLAnchorElement
          ..href = url
          ..download = 'translation_history_${DateTime.now().millisecondsSinceEpoch}.json'
          ..style.display = 'none';

        web.document.body?.appendChild(anchor);
        anchor.click();

        Future.delayed(const Duration(seconds: 1), () {
          web.document.body?.removeChild(anchor);
          web.URL.revokeObjectURL(url);
        });
      } else {
        // Handle mobile/desktop export
        final file = exportResult as File;
        final savePath = await FilePicker.platform.saveFile(
          dialogTitle: 'Экспорт истории переводов',
          fileName: 'translation_history_${DateTime.now().millisecondsSinceEpoch}.json',
        );

        if (savePath != null) {
          await file.copy(savePath);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Данные успешно экспортированы')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка экспорта: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

// Обновленный метод _importAllData в _TranslationHistoryPageState
  Future<void> _importAllData(BuildContext context) async {
    if (!mounted) return;
    setState(() => _isImporting = true);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        String fileContent;

        if (kIsWeb) {
          fileContent = utf8.decode(result.files.first.bytes!);
        } else {
          final file = File(result.files.first.path!);
          fileContent = await file.readAsString();
        }

        final Map<String, dynamic> jsonData = json.decode(fileContent);

        if (jsonData['version'] == 1 && jsonData['data'] != null) {
          final importedCount = await AppDatabase().importAllData(jsonData);

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Успешно импортировано $importedCount записей')),
          );

          setState(() {});
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Неверный формат файла')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка импорта: $e')),
      );
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _selectDateTime(BuildContext context, bool isStart) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate ?? DateTime.now() : _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: isStart ? _startTime ?? TimeOfDay.now() : _endTime ?? TimeOfDay.now(),
      );

      if (pickedTime != null) {
        setState(() {
          final combinedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );

          if (isStart) {
            _startDate = combinedDateTime;
            _startTime = pickedTime;
          } else {
            _endDate = combinedDateTime;
            _endTime = pickedTime;
          }
        });
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _openMenu() {
    widget._scaffoldKey.currentState?.openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: widget._scaffoldKey,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset("assets/images/logo.png"),
        ),
        title: const Text("История переводов"),
        backgroundColor: const Color(0xFF0A4B47),
        foregroundColor: Colors.white,
        actions: [
          ElevatedButton(
            onPressed: _openMenu,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A4B47),
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(12),
            ),
            child: const Icon(Icons.menu, color: Colors.white, size: 30),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // DateTime filters row
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDateTime(context, true),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                _startDate != null
                                    ? _dateFormat.format(_startDate!)
                                    : 'Начальная дата и время',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDateTime(context, false),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                _endDate != null
                                    ? _dateFormat.format(_endDate!)
                                    : 'Конечная дата и время',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Search field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Поиск по тексту',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                          _searchController.clear();
                        });
                      },
                    )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 8),
                // Action buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildActionButton(
                      onPressed: () => _exportAllData(context),
                      isLoading: _isExporting,
                      text: 'Экспорт',
                      color: const Color(0xFF0A4B47),
                    ),
                    _buildActionButton(
                      onPressed: () => _importAllData(context),
                      isLoading: _isImporting,
                      text: 'Импорт',
                      color: const Color(0xFF0A4B47),
                    ),
                    _buildActionButton(
                      onPressed: () => _removeDuplicates(context),
                      isLoading: _isClearing,
                      text: 'Удалить дубликаты',
                      color: Colors.orange,
                    ),
                    _buildActionButton(
                      onPressed: () => _clearHistory(context),
                      isLoading: _isClearing,
                      text: 'Очистить историю',
                      color: Colors.red,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: AppDatabase().getTranslationHistory(
                startDate: _startDate,
                endDate: _endDate,
                searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('История переводов пуста'));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final item = snapshot.data![index];
                    final dateTime = DateTime.parse(item['timestamp']);
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(
                          item['original_text'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['translated_text'] ?? ''),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.schedule, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  _dateFormat.format(dateTime),
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                                const Spacer(),
                                Text(
                                  item['direction'] ?? '',
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: Container(
          padding: const EdgeInsets.only(top: 40),
          decoration: const BoxDecoration(color: Color(0xFFE7E4DF)),
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              ListTile(
                title: const Text('Переводчик', style: TextStyle(fontSize: 20, color: Colors.black)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TranslatePage()),
                  );
                },
              ),
              ListTile(
                title: const Text('Обучение', style: TextStyle(fontSize: 20, color: Colors.black)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MainMenuPage()),
                  );
                },
              ),
              ListTile(
                title: const Text('История переводов', style: TextStyle(fontSize: 20, color: Color(0xFF0A4B47))),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TranslationHistoryPage()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildActionButton({
  required VoidCallback onPressed,
  required bool isLoading,
  required String text,
  required Color color,
}) {
  return ElevatedButton(
    onPressed: isLoading ? null : onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          ),
        Text(text),
      ],
    ),
  );
}

Widget _buildAppDrawer(BuildContext context) {
  return Drawer(
    child: Container(
      padding: EdgeInsets.only(top: 40),
      decoration: BoxDecoration(color: Color(0xFFE7E4DF)),
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          ListTile(
            title: Text('Переводчик', style: TextStyle(fontSize: 20, color: Colors.black)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TranslatePage()),
              );
            },
          ),
          ListTile(
            title: Text('Обучение', style: TextStyle(fontSize: 20, color: Color(0xFF0A4B47))),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MainMenuPage()),
              );
            },
          ),
          ListTile(
            title: Text('История переводов', style: TextStyle(fontSize: 20, color: Colors.black)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TranslationHistoryPage()),
              );
            },
          ),
        ],
      ),
    ),
  );
}
