import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Переводчик',
      color: const Color(0xFF0A4B47),
      theme: ThemeData(
        scaffoldBackgroundColor: Color(0xFFE7E4DF), // Изменение фона приложения
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

class LevelPage extends StatefulWidget {
  const LevelPage({super.key});
  @override
  State <LevelPage> createState() => _LevelPageState();
}

class _TranslatePageState extends State<TranslatePage> {
  final String translateApiEndpoint =
      "https://ethnoportal.admhmao.ru/api/machine-translates/translate";
      final TextEditingController controller1 = TextEditingController();
      final TextEditingController controller2 = TextEditingController();
      Timer? _debounce; // Таймер для задержки отправки
      bool _isSwapped = false;

  // Функция для отправки запроса и получения перевода c русского
  Future<void> getTranslate(String text) async {
    // Определяем языки в зависимости от флага _isSwapped
    final int sourceLanguage = _isSwapped ? 2 : 1; // Если флаг активен, меняем языки местами
    final int targetLanguage = _isSwapped ? 1 : 2;

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
        String responseBody = utf8.decode(response.bodyBytes); // Декодируем байты в строку
        final Map<String, dynamic> responseData = json.decode(responseBody);
        setState(() {
          controller2.text = responseData['translatedText'] ?? 'Ошибка: Перевод не найден';
        });
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
      _isSwapped = !_isSwapped; // Переключаем флаг
    });
    getTranslate(controller1.text); // После смены языков вызываем перевод
  }

  // Функция для отправки запроса и получения перевода c русского

  // Обработчик изменения текста
  void _onTextChanged(String text) {
    // Отменяем предыдущий таймер, если текст изменился раньше
    if (_debounce?.isActive ?? false) _debounce?.cancel();

    // Запускаем новый таймер, который выполнит запрос через 3 секунды
    _debounce = Timer(const Duration(seconds: 2), () {
      _isSwapped == true ? getTranslate(text): getTranslate(text); // Отправляем текст в API
    });
  }

  // Тексты для обоих текстовых окон
  String text1 = 'Русский';
  String text2 = 'Мансийский';

  // Контроллер для управления анимацией
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Метод для открытия меню
  void _openMenu() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  // Метод для обмена местами текстовых окон и обновления текстовых полей
  void swapTextFields() {
    setState(() {
      // Меняем местами текстовые окна
      _isSwapped != _isSwapped;
      String temp = text1;
      text1 = text2;
      text2 = temp;
      // Обновляем текстовые поля
      String tempController = controller1.text;
      controller1.text = controller2.text;
      controller2.text = tempController;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel(); // Отменяем таймер при закрытии экрана
    controller1.dispose();
    controller2.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text("Переводчик"),
        backgroundColor: Color(0xFF0A4B47),
        foregroundColor: Colors.white, // Цвет текста (и иконок)
        actions: [ElevatedButton(
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
        ),]
      ),
      body: Center(
        child: ListView(
          children: [
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Первое текстовое окно
                Container(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    text1,
                    style: TextStyle(fontSize: 20),
                  ),
                ),
                // Кнопка для обмена местами текстовых окон
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0A4B47), // Цвет фона кнопки (синий)
                    shape: CircleBorder(), // Круглая форма кнопки
                    padding: EdgeInsets.all(12), // Размер кнопки
                  ),
                  onPressed: swapLanguages,
                  child: Icon(
                  Icons.swap_horiz,
                  color:Colors.white,
                  size: 30,
                  ),
                ),
                // Второе текстовое окно
                Container(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    text2,
                    style: TextStyle(fontSize: 20, color: Colors.black),
                  ),
                ),
              ],
            ),
            // Текстовое поле для первого текстa
            Container(
              margin: EdgeInsets.all(16),
              child: TextField(
                  textAlignVertical: TextAlignVertical.top,
                  controller: controller1,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), // Округление углов
                        borderSide: BorderSide(color: Colors.black), // Чёрная обводка
                    ),
                    isDense: true,
                    filled: true,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.all(16),),
                  keyboardType: TextInputType.multiline,
                  maxLines: 10,
                  onChanged: _onTextChanged, // Каждый раз, когда изменяется текст
              )
            )
            ,
            // Текстовое поле для второго текста
            Container(
              margin: EdgeInsets.all(16),
              child: TextField(
                controller: controller2,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), // Округление углов
                    borderSide: BorderSide(color: Colors.black), // Чёрная обводка
                  ),
                  isDense: true,
                  filled: true,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.all(16),
                ),
                keyboardType: TextInputType.multiline,
                readOnly: true, // Делаем поле только для чтения
                maxLines: 10,
              ),
            ),
          ],
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
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelPageState extends State<LevelPage> {
  // Переменная для хранения правильного ответа
  final String correctAnswer = "Пася о̄лэ̄н";
  String selectedAnswer = ""; // Текущий выбранный ответ
  bool isAnswered = false; // Флаг, чтобы показать, был ли уже выбран ответ

  // Список слов для выбора
  List<String> options = ["ЛЯ̄ХХАЛЫТ", "Пася о̄лэ̄н", "Ань ты мус"];

  // Функция для обработки выбора
  void onOptionSelected(String answer) {
    setState(() {
      selectedAnswer = answer;
      isAnswered = true;
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
      appBar: AppBar(
          title: Text('Выберите правильное слово'),
          backgroundColor: Color(0xFF0A4B47),
          foregroundColor: Colors.white, // Цвет текста (и иконок)
          actions: [ElevatedButton(
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
          ),]
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: ListView(
          children: <Widget>[
            // Заголовок
            Text(
              'Какое слово переводится на русский как "Привет"?',
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
    );
  }
}
