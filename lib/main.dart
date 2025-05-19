import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

// Класс для хранения пары: исходное слово и перевод
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
  final String translateApiEndpoint =
      "https://ethnoportal.admhmao.ru/api/machine-translates/translate";
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
      setState(() {
        _isKeyboardVisible = true;
      });
    } else {
      setState(() {
        _isKeyboardVisible = false;
      });
    }
  }

  Future<void> getTranslate(String text) async {
    final int sourceLanguage = _isSwapped ? 2 : 1;
    final int targetLanguage = _isSwapped ? 1 : 2;

    void saveTranslationHistory(String originalText, String translatedText) {
      setState(() {
        translationHistory.add(TranslationHistoryItem(originalText, translatedText));
      });
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
    _debounce = Timer(const Duration(seconds: 2), () {
      getTranslate(text);
    });
  }

  void goToHistoryPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TranslationHistoryPage(history: translationHistory)),
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
          title: Text("Переводчик"),
          backgroundColor: Color(0xFF0A4B47),
          foregroundColor: Colors.white,
          actions: [
            ElevatedButton(
              onPressed: _openMenu,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0A4B47),
                shape: CircleBorder(),
                padding: EdgeInsets.all(12),
              ),
              child: Icon(Icons.menu, color:Colors.white, size: 30),
            ),
          ]
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      child: Text(text1, style: TextStyle(fontSize: 20)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0A4B47),
                        shape: CircleBorder(),
                        padding: EdgeInsets.all(12),
                      ),
                      onPressed: swapLanguages,
                      child: Icon(Icons.swap_horiz, color:Colors.white, size: 30),
                    ),
                    Container(
                      padding: EdgeInsets.all(8),
                      child: Text(text2, style: TextStyle(fontSize: 20, color: Colors.black)),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Container(
                    margin: EdgeInsets.all(10),
                    child: TextField(
                      focusNode: _focusNode,
                      textAlignVertical: TextAlignVertical.top,
                      controller: controller1,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.black)),
                        isDense: true,
                        filled: true,
                        isCollapsed: true,
                        contentPadding: EdgeInsets.all(10),
                      ),
                      keyboardType: TextInputType.multiline,
                      maxLines: 10,
                      onChanged: _onTextChanged,
                    )
                ),
                Container(
                  margin: EdgeInsets.all(10),
                  child: TextField(
                    controller: controller2,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.black)),
                      isDense: true,
                      filled: true,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.all(10),
                    ),
                    keyboardType: TextInputType.multiline,
                    readOnly: true,
                    maxLines: 10,
                  ),
                ),
              ],
            ),
          ),
          // Мансийская клавиатура
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
          padding: EdgeInsets.only(top: 40),
          decoration: BoxDecoration(color: Color(0xFFE7E4DF)),
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              ListTile(
                title: Text('Переводчик', style: TextStyle(fontSize: 20, color: Color(0xFF0A4B47))),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TranslatePage()),
                  );
                },
              ),
              ListTile(
                title: Text('Обучение', style: TextStyle(fontSize: 20, color: Colors.black)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LevelPage()),
                  );
                },
              ),
              ListTile(
                title: Text('История переводов', style: TextStyle(fontSize: 20, color: Colors.black)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TranslationHistoryPage(history: translationHistory)),
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


class LevelPage extends StatefulWidget {
  const LevelPage({super.key});
  @override
  State <LevelPage> createState() => _LevelPageState();
}

class _LevelPageState extends State<LevelPage> {
  // Переменная для хранения правильного ответа
  final String correctAnswer = "Пася о̄лэ̄н";
  String selectedAnswer = ""; // Текущий выбранный ответ
  bool isAnswered = false; // Флаг, чтобы показать, был ли уже выбран ответ

  // Список слов для выбора
  List<String> options = ["ЛЯ̄ХХАЛЫТ", "Пася о̄лэ̄н", "Ань ты мус"];
  List<TranslationHistoryItem> translationHistory = []; // История переводов

  // Функция для обработки выбора
  void onOptionSelected(String answer) {
    setState(() {
      selectedAnswer = answer;
      isAnswered = true;
    });
  }

  // Функция для перехода на страницу истории
  void goToHistoryPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TranslationHistoryPage(history: translationHistory)),
    );
  }

  // Контроллер для управления анимацией
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  // Метод для открытия меню
  void _openMenu() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text('Выберите правильное слово'),
          backgroundColor: Color(0xFF0A4B47),
          foregroundColor: Colors.white, // Цвет текста (и иконок)
          actions: [ElevatedButton(
            onPressed: _openMenu, //нихуя не работает
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF0A4B47), // Цвет фона кнопки (синий)
              shape: CircleBorder(), // Круглая форма кнопки
              padding: EdgeInsets.all(12), // Размер кнопки
            ),
            child: Icon(
              Icons.menu,
              color:Colors.white,
              size: 30,),
          ),]
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: ListView(
            children: <Widget>[
              // Заголовок
              Text(
                'Привет, дорогой друг! Поздоровайся со мной тоже, пожалуйста. Какое слово переводится на русский как "Привет"?',
                style: TextStyle(fontSize: 24),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              // Кнопки для выбора
              for (var option in options)
                Container(
                  margin: EdgeInsets.all(8),
                  child: ElevatedButton(
                      onPressed: isAnswered
                          ? null // Отключаем кнопки после ответа
                          : () => onOptionSelected(option),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedAnswer == option
                            ? (option == correctAnswer
                            ? Color(0xFF00B333) // Правильный ответ — зелёный
                            : Color(0xFFE3001B)) // Неправильный ответ — красный
                            : Color(0xFFE7E4DF), // По умолчанию
                      ), // add margin here
                      child: Text(
                          option,
                          style:
                          TextStyle(fontSize: 18, color: Colors.black)
                      )
                  ),
                ),

              SizedBox(height: 30),
              // Поздравление или сообщение об ошибке
              if (isAnswered)
                Text(
                  selectedAnswer == correctAnswer
                      ? 'Поздравляю! Вы выбрали правильный перевод!'
                      : 'Неправильно! Попробуйте ещё раз.',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: selectedAnswer == correctAnswer
                        ? Color(0xFF00B333)
                        : Color(0xFFE3001B),
                  ),
                  textAlign: TextAlign.center,
                ),
              SizedBox(height: 20),
              // Кнопка для сброса и нового выбора
              if (isAnswered)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFE7E4DF), // Цвет фона кнопки
                  ),
                  onPressed: () {
                    setState(() {
                      isAnswered = false;
                      selectedAnswer = "";
                    });
                  },
                  child: Text('Попробовать снова',
                    style: TextStyle(
                        fontSize: 20,
                        color: Colors.black),
                  ),
                ),
            ]
        ),
      ),
      endDrawer: Drawer(
        child: Container(
          padding: EdgeInsets.only(top: 40),
          decoration: BoxDecoration(color: Color(0xFFE7E4DF)),
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              ListTile(
                title: Text('Переводчик', style: TextStyle(fontSize: 20, color: Color(0xFF0A4B47)),),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TranslatePage()),
                  );
                },
              ),
              ListTile(
                  title: Text('Обучение', style: TextStyle(fontSize: 20, color: Colors.black),),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LevelPage()),
                    );
                  } //,
              ),
              ListTile(
                  title: Text('История переводов', style: TextStyle(fontSize: 20, color: Colors.black),),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => TranslationHistoryPage(history: translationHistory)),
                    );
                  } //,
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class TranslationHistoryPage extends StatefulWidget {
  final List<TranslationHistoryItem> history;

  // Получаем историю переводов через конструктор
  const TranslationHistoryPage({super.key, required this.history});

  @override
  State <TranslationHistoryPage> createState() => _TranslationHistoryPageState();
}

class _TranslationHistoryPageState extends State<TranslationHistoryPage> {
  List<TranslationHistoryItem> filteredHistory = [];
  TextEditingController searchController = TextEditingController();
  List<TranslationHistoryItem> translationHistory = []; // История переводов

  @override
  void initState() {
    super.initState();
    filteredHistory = widget.history;  // Используем widget.history для доступа к истории

    // Добавление функционала для поиска
    searchController.addListener(() {
      filterHistory();
    });
  }

  // Фильтрация истории переводов
  void filterHistory() {
    setState(() {
      filteredHistory = widget.history
          .where((item) =>
      item.originalText.toLowerCase().contains(searchController.text.toLowerCase()) ||
          item.translatedText.toLowerCase().contains(searchController.text.toLowerCase()))
          .toList();
    });
  }

  // Функция для удаления перевода
  void deleteTranslation(int index) {
    setState(() {
      widget.history.removeAt(index);  // Удаляем запись из оригинальной истории
      filteredHistory = widget.history; // Обновляем отображаемую историю
    });
  }


  // Контроллер для управления анимацией
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Метод для открытия меню
  void _openMenu() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
          title: Text("История переводов"),
          leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image.asset(
                  "assets/images/logo.png",
              ),
          ),
          backgroundColor: Color(0xFF0A4B47),
          foregroundColor: Colors.white, // Цвет текста (и иконок)
          actions: [
            ElevatedButton(
              onPressed: _openMenu,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0A4B47), // Цвет фона кнопки (синий)
                shape: CircleBorder(), // Круглая форма кнопки
                padding: EdgeInsets.all(12), // Размер кнопки
              ),
              child: Icon(
                Icons.menu,
                color:Colors.white,
                size: 30,),
            ),
          ]
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: "Поиск",
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredHistory.length,
              itemBuilder: (context, index) {
                final item = filteredHistory[index];
                return ListTile(
                  title: Text("${item.originalText} -> ${item.translatedText}"),
                  trailing: IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () => deleteTranslation(index),  // Удаление записи
                  ),
                );
              },
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: Container(
          padding: EdgeInsets.only(top: 40),
          decoration: BoxDecoration(color: Color(0xFFE7E4DF)),
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              ListTile(
                title: Text('Переводчик', style: TextStyle(fontSize: 20, color: Color(0xFF0A4B47)),),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TranslatePage()),
                  );
                },
              ),
              ListTile(
                  title: Text('Обучение', style: TextStyle(fontSize: 20, color: Colors.black),),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LevelPage()),
                    );
                  } //,
              ),
              ListTile(
                  title: Text('История переводов', style: TextStyle(fontSize: 20, color: Colors.black),),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => TranslationHistoryPage(history: translationHistory)),
                    );
                  } //,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
