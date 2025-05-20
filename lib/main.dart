import 'dart:convert';
import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqflite;
import 'package:sembast/sembast.dart' as sembast;
import 'package:sembast_web/sembast_web.dart' as sembast_web;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация для не-веб платформ
  if (!kIsWeb) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Инициализация базы данных (для не-веб платформ)
  if (!kIsWeb) {
    await AppDatabase.instance.database;
  }

  runApp(const MyApp());
}

// 1. Создаем класс для работы с базой данных
class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static dynamic _database; // Используем dynamic для совместимости с разными типами баз данных

  AppDatabase._init();

  Future<dynamic> get database async { // Возвращаем dynamic
    if (_database != null) return _database;
    _database = await _initDB('language_learning.db');
    log('Database initialized successfully');
    return _database;
  }

  Future<dynamic> _initDB(String filePath) async {
    if (kIsWeb) {
      // Используем sembast для веба
      final dbFactory = sembast_web.databaseFactoryWeb;
      return await dbFactory.openDatabase(filePath); // Возвращаем sembast.Database
    } else {
      // Используем sqflite для десктопа
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, filePath);
      return await sqflite.openDatabase(path, version: 1, onCreate: _createDB);
    }
  }

  Future _createDB(dynamic db, int version) async { // Используем dynamic
    if (!kIsWeb) {
      // Таблицы для sqflite
      await (db as sqflite.Database).execute('''
        CREATE TABLE learning_progress (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          module_id INTEGER NOT NULL,
          level INTEGER NOT NULL,
          is_completed BOOLEAN NOT NULL,
          score INTEGER,
          last_accessed TEXT,
          UNIQUE(module_id, level)
        )
      ''');
      await (db as sqflite.Database).execute('''
        CREATE TABLE translation_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          original_text TEXT NOT NULL,
          translated_text TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          direction TEXT NOT NULL
        )
      ''');
      await (db as sqflite.Database).execute('''
        CREATE TABLE completed_tasks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          module_id INTEGER NOT NULL,
          level INTEGER NOT NULL,
          task_type TEXT NOT NULL,
          is_correct BOOLEAN NOT NULL,
          timestamp TEXT NOT NULL
        )
      ''');
    }
  }

  Future<void> addTranslation(String original, String translated, String timestamp, String direction) async {
    final db = await instance.database;
    if (kIsWeb) {
      final store = sembast.intMapStoreFactory.store('translation_history');
      await store.add(db as sembast.Database, { // Используем store.add
        'original_text': original,
        'translated_text': translated,
        'timestamp': timestamp,
        'direction': direction,
      });
    } else {
      await (db as sqflite.Database).insert('translation_history', {
        'original_text': original,
        'translated_text': translated,
        'timestamp': timestamp,
        'direction': direction,
      });
    }
  }


  Future<List<Map<String, dynamic>>> getTranslationHistory() async {
    final db = await instance.database;
    if (kIsWeb) {
      final store = sembast.intMapStoreFactory.store('translation_history');
      final records = await store.find(db as sembast.Database);
      return records.map((record) => record.value as Map<String, dynamic>).toList();
    } else {
      return await (db as sqflite.Database).query('translation_history', orderBy: 'timestamp DESC');
    }
  }

  Future<void> addCompletedTask(int moduleId, int level, String taskType, bool isCorrect) async {
    final db = await instance.database;
    await (db as sqflite.Database).insert(
      'completed_tasks',
      {
        'module_id': moduleId,
        'level': level,
        'task_type': taskType,
        'is_correct': isCorrect ? 1 : 0,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<List<Map<String, dynamic>>> getCompletedTasks(int moduleId, int level) async {
    final db = await instance.database;
    return await (db as sqflite.Database).query(
      'completed_tasks',
      where: 'module_id = ? AND level = ?',
      whereArgs: [moduleId, level],
    );
  }

  Future close() async {
    final db = await instance.database;
    if (!kIsWeb) {
      await (db as sqflite.Database).close();
    } else {
      // sembast не требует явного закрытия в вебе
    }
  }
}

class TranslationHistoryItem {
  final String originalText;
  final String translatedText;

  TranslationHistoryItem(this.originalText, this.translatedText);
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
  State <TranslatePage> createState() => _TranslatePageState();
}

class _TranslatePageState extends State<TranslatePage> {
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
    AppDatabase.instance.database.then((db) {
      log('База данных инициализирована');
    }).catchError((e) {
      log('Ошибка инициализации базы данных: $e');
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
      log('Saving translation: $original -> $translated');
      try {
        await AppDatabase.instance.addTranslation(original, translated, DateTime.now().toIso8601String(), direction);
        log('Translation saved successfully');
      } catch (e) {
        log('Error saving translation: $e');
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

// 2. Главное меню приложения
class MainMenuPage extends StatelessWidget {
  final List<Map<String, dynamic>> modules = [    {'id': 1, 'title': 'Основные слова'},    {'id': 2, 'title': 'Фразы'},    {'id': 3, 'title': 'Грамматика'},    {'id': 4, 'title': 'Диалоги'},  ];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openMenu() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  MainMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Главное меню'),
        automaticallyImplyLeading: false,
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildMenuRow(context, modules[0], 1, Alignment.centerRight),
            const SizedBox(height: 40),
            _buildMenuRow(context, modules[1], 2, Alignment.centerLeft),
            const SizedBox(height: 40),
            _buildMenuRow(context, modules[2], 3, Alignment.centerRight),
            const SizedBox(height: 40),
            _buildMenuRow(context, modules[3], 4, Alignment.centerLeft),
          ],
        ),
      ),
      endDrawer: _buildAppDrawer(context),
    );
  }

  Widget _buildMenuRow(BuildContext context, Map<String, dynamic> module, int number, Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 400),
        child: _buildMenuButton(context, module, number),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, Map<String, dynamic> module, int number) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ModuleLevelsPage(moduleId: module['id'], moduleTitle: module['title']),
              ),
            );
          },
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF0A4B47),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 60),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          module['title'],
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
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
class TranslationHistoryPage extends StatelessWidget {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openMenu() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  TranslationHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('История переводов'),
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
      body: FutureBuilder(
        future: AppDatabase.instance.getTranslationHistory(),
        builder: (context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('История переводов пуста'));
          }
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final item = snapshot.data![index];
              return ListTile(
                title: Text(item['original_text']),
                subtitle: Text(item['translated_text']),
                trailing: Text(item['direction']),
                onTap: () {},
              );
            },
          );
        },
      ),
      endDrawer: _buildAppDrawer(context),
    );
  }
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
