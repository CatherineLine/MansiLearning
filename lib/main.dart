import 'dart:convert';
import 'dart:async';
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
import 'dart:convert';
import 'package:flutter/services.dart';

// Условные импорты для разных платформ
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast_web/sembast_web.dart' as sembast_web;

// Для веб-платформы
import 'package:web/web.dart' as web show Blob, BlobPropertyBag, DragEvent, Event, FileReader, HTMLAnchorElement, URL, document;
import 'package:js/js_util.dart' as js_util;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    web.document.addEventListener('dragover', _handleDragOver.toJS);
    web.document.addEventListener('drop', _handleDrop.toJS);
  }
  final db = AppDatabase();
  await db.database;
  await db.initLearningMaterials();

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

Future<Map<String, dynamic>> loadRiddles() async {
  final String jsonString = await rootBundle.loadString('assets/riddles.json');
  final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
  return jsonMap;
}
void _handleFileLoad(web.Event e) {
  final target = e.target;
  if (target == null) return;

  // Безопасная проверка типа
  final isFileReader = js_util.hasProperty(target, 'result');
  if (!isFileReader) return;

  // Получаем результат
  final content = js_util.getProperty(target, 'result');
  if (content == null || content.toString().isEmpty) return;

  try {
    // Безопасное декодирование JSON
    final dynamic parsedJson = json.decode(content.toString());

    if (parsedJson is! Map<String, dynamic>) {
      _showError('Неверный формат JSON: ожидался объект');
      return;
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

final riddleStore = intMapStoreFactory.store('riddles');

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  late final Future<Database> _database;

  factory AppDatabase() {
    return _instance;
  }

  final riddleProgressStore = intMapStoreFactory.store('riddle_progress');

  Future<void> saveRiddleProgress(int solvedRiddles, int totalScore) async {
    final db = await _database;
    final record = riddleProgressStore.record(1);
    await record.put(db, {
      'solved_riddles': solvedRiddles,
      'total_score': totalScore,
      'next_riddle_required_score': (solvedRiddles + 1) * 100
    });
  }

  Future<Map<String, dynamic>> getRiddleProgress() async {
    final db = await _database;
    final record = riddleProgressStore.record(1);
    final snapshot = await record.get(db);

    return snapshot ?? {
      'solved_riddles': 0,
      'total_score': 0,
      'next_riddle_required_score': 100
    };
  }

  Future<int> getCompletedRiddlesCount() async {
    final db = await _database;
    final record = riddleProgressStore.record(1);
    final snapshot = await record.get(db);

    final count = snapshot?['solved_riddles'];
    if (count is num) return count.toInt();
    return 0;
  }

  AppDatabase._internal() {
    _database = _initDatabase();
  }

  Future<Database> get database => _database;

  Future<Database> _initDatabase() async {
    final databaseFactory = kIsWeb
        ? sembast_web.databaseFactoryWeb
        : databaseFactoryIo;

    return await databaseFactory.openDatabase('learning_app.db');
  }

  Future<int> getUserTotalScore() async {
    final db = await _database;
    final taskStore = intMapStoreFactory.store('tasks');
    final records = await taskStore.find(db);

    int totalScore = 0;

    for (var record in records) {
      final points = record.value['points'];
      if (points is int) {
        totalScore += points;
      } else if (points is num) {
        totalScore += points.toInt();
      }
    }

    return totalScore;
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

    // ИСПРАВЛЕНИЕ: Безопасное приведение типов
    final dynamic data = jsonData['data'];
    List<Map<String, dynamic>> items = [];

    if (data is List) {
      for (var item in data) {
        if (item is Map<String, dynamic>) {
          items.add(item);
        } else if (item is Map) {
          // Конвертируем Map<dynamic, dynamic> в Map<String, dynamic>
          final convertedItem = Map<String, dynamic>.from(item.cast<String, dynamic>());
          items.add(convertedItem);
        } else {
          print('Warning: Skipping invalid item: $item');
        }
      }
    } else {
      throw Exception('Expected List but got ${data.runtimeType}');
    }

    int importedCount = 0;
    for (var item in items) {
      await store.add(db, item);
      importedCount++;
    }

    return importedCount;
  }

  // Новые методы для работы с учебными материалами
  Future<void> initLearningMaterials() async {
    final db = await _database;
    final theoryStore = intMapStoreFactory.store('theory');
    final tasksStore = intMapStoreFactory.store('tasks');

    // Проверяем, есть ли уже данные
    final theoryCount = await theoryStore.count(db);
    if (theoryCount == 0) {
      // Заполняем начальные данные
      await _populateInitialData(db);
    }
  }

  Future<void> _populateInitialData(Database db) async {
    final theoryStore = intMapStoreFactory.store('theory');
    final tasksStore = intMapStoreFactory.store('tasks');

    // Модуль 1: Фонетика мансийского языка
    final module1Theory = '''
Мансийский язык имеет богатую фонетическую систему. В нем различаются долгие и краткие гласные, которые отличаются не только длительностью, но и качеством звучания. 

**Гласные звуки:**
- Переднего ряда: и (i), й (i), е (e), ё (ё)
- Среднего ряда: ы (ə)
- Заднего ряда: у (u), ў (ū), о (o), б (о), а (a), â (ā)

**Согласные звуки:**
Отличаются от русских отсутствием противопоставления по глухости-звонкости и твердости-мягкости. Есть специфические звуки:
- Палатальные согласные: t' (ть), n' (нь), l' (ль)
- Сложные согласные: k° (кв), x° (хв)
- Заднеязычный носовой ŋ (нг)

**Ударение:** всегда падает на первый слог, дополнительные ударения - на нечетные слоги.
''';

    await theoryStore.add(db, {
      'module': 1,
      'level': 1,
      'content': module1Theory,
      'order': 1,
    });

    // 5 типов заданий для модуля 1
    // Тип 1: Распознавание гласных
    await tasksStore.add(db, {
      'module': 1,
      'level': 1,
      'theory_id': 1,
      'question': 'Какой гласный звук в слове "кёлл" (кровь)?',
      'options': ['Переднего ряда', 'Среднего ряда', 'Заднего ряда'],
      'correct_answer': 'Переднего ряда',
      'points': 20,
      'order': 1,
    });

    // Тип 2: Долгие vs краткие гласные
    await tasksStore.add(db, {
      'module': 1,
      'level': 2,
      'theory_id': 1,
      'question': 'Как обозначается долгота гласных в мансийском алфавите?',
      'options': ['Черта над буквой', 'Двоеточие после буквы', 'Удвоение буквы'],
      'correct_answer': 'Черта над буквой',
      'points': 20,
      'order': 2,
    });

    // Тип 3: Согласные звуки
    await tasksStore.add(db, {
      'module': 1,
      'level': 3,
      'theory_id': 1,
      'question': 'Какой из этих согласных отсутствует в мансийском языке?',
      'options': ['t\' (ть)', 'k° (кв)', 'ц'],
      'correct_answer': 'ц',
      'points': 20,
      'order': 3,
    });

    // Тип 4: Ударение
    await tasksStore.add(db, {
      'module': 1,
      'level': 4,
      'theory_id': 1,
      'question': 'Куда падает ударение в мансийских словах?',
      'options': ['На первый слог', 'На последний слог', 'Произвольно'],
      'correct_answer': 'На первый слог',
      'points': 20,
      'order': 4,
    });

    // Тип 5: Практическое задание
    await tasksStore.add(db, {
      'module': 1,
      'level': 5,
      'theory_id': 1,
      'question': 'Как правильно произнести "ãc" (река Обь)?',
      'options': ['С кратким "а"', 'С долгим "а"', 'С редуцированным гласным'],
      'correct_answer': 'С долгим "а"',
      'points': 20,
      'order': 5,
    });

    // Модуль 2: Грамматика (число и местоимения)
    final module2Theory = '''
**Число в мансийском языке:**
Различается три числа:
1. Единственное (нулевой показатель)
2. Двойственное (суффикс -ыг/-иг)
3. Множественное (суффикс -т/-ит)

**Личные местоимения:**
|          | Ед.ч. | Дв.ч. | Мн.ч. |
|----------|-------|-------|-------|
| 1 лицо  | ам    | мен   | ман   |
| 2 лицо  | нан   | нэн   | нан   |
| 3 лицо  | тав   | тэн   | тан   |

**Притяжательные формы:**
Образуются с помощью суффиксов:
- 1 лицо: -ум/-м
- 2 лицо: -ын/-н
- 3 лицо: -э/-тэ
''';

    await theoryStore.add(db, {
      'module': 2,
      'level': 1,
      'content': module2Theory,
      'order': 2,
    });

    // 5 типов заданий для модуля 2
    // Тип 1: Образование чисел
    await tasksStore.add(db, {
      'module': 2,
      'level': 1,
      'theory_id': 2,
      'question': 'Как будет "две лодки" (хал) на мансийском?',
      'options': ['халыт', 'халиг', 'хал'],
      'correct_answer': 'халиг',
      'points': 20,
      'order': 1,
    });

    // Тип 2: Местоимения
    await tasksStore.add(db, {
      'module': 2,
      'level': 2,
      'theory_id': 2,
      'question': 'Как будет "мы двое" на мансийском?',
      'options': ['ам', 'мен', 'ман'],
      'correct_answer': 'мен',
      'points': 20,
      'order': 2,
    });

    // Тип 3: Притяжательные формы
    await tasksStore.add(db, {
      'module': 2,
      'level': 3,
      'theory_id': 2,
      'question': 'Как будет "твой дом" (кол) на мансийском?',
      'options': ['колум', 'колын', 'кол'],
      'correct_answer': 'колын',
      'points': 20,
      'order': 3,
    });

    // Тип 4: Перевод предложений
    await tasksStore.add(db, {
      'module': 2,
      'level': 4,
      'theory_id': 2,
      'question': 'Переведите: "Это моя собака"',
      'options': ['Тым ам ёмпум', 'Тым нан ёмпын', 'Тым тав ёмпэ'],
      'correct_answer': 'Тым ам ёмпум',
      'points': 20,
      'order': 4,
    });

    // Тип 5: Грамматический анализ
    await tasksStore.add(db, {
      'module': 2,
      'level': 5,
      'theory_id': 2,
      'question': 'Какое число в слове "ёмпыт" (собаки)?',
      'options': ['Единственное', 'Двойственное', 'Множественное'],
      'correct_answer': 'Множественное',
      'points': 20,
      'order': 5,
    });

    // Модуль 3: Лексика (термины родства)
    final module3Theory = '''
**Термины родства в мансийском языке:**
- аш/аб - отец
- атя - папа
- щўнь - мать
- ома - мама
- аги - дочь, девочка
- пыл - сын, мальчик
- канк - старший брат
- апиш - младший брат
- ўвиш - старшая сестра
- мўнь ягўти - младшая сестра

Особенности:
1. Различают родство по материнской и отцовской линии
2. Важен относительный возраст (старше/младше)
3. Есть специальные термины для родственников супругов
''';

    await theoryStore.add(db, {
      'module': 3,
      'level': 1,
      'content': module3Theory,
      'order': 3,
    });

    // 5 типов заданий для модуля 3
    // Тип 1: Базовые термины
    await tasksStore.add(db, {
      'module': 3,
      'level': 1,
      'theory_id': 3,
      'question': 'Как будет "отец" на мансийском?',
      'options': ['аш/аб', 'щўнь', 'аги'],
      'correct_answer': 'аш/аб',
      'points': 20,
      'order': 1,
    });

    // Тип 2: Различение родства
    await tasksStore.add(db, {
      'module': 3,
      'level': 2,
      'theory_id': 3,
      'question': 'Как называется младший брат на мансийском?',
      'options': ['канк', 'апиш', 'ўвиш'],
      'correct_answer': 'апиш',
      'points': 20,
      'order': 2,
    });

    // Тип 3: Состав семьи
    await tasksStore.add(db, {
      'module': 3,
      'level': 3,
      'theory_id': 3,
      'question': 'Как будет "старшая сестра моего друга"?',
      'options': ['рума ўвишум', 'рума апишум', 'рума канкум'],
      'correct_answer': 'рума ўвишум',
      'points': 20,
      'order': 3,
    });

    // Тип 4: Возрастные различия
    await tasksStore.add(db, {
      'module': 3,
      'level': 4,
      'theory_id': 3,
      'question': 'Какое слово означает "младший брат отца"?',
      'options': ['канк', 'сасыт', 'акн'],
      'correct_answer': 'сасыт',
      'points': 20,
      'order': 4,
    });

    // Тип 5: Практическое применение
    await tasksStore.add(db, {
      'module': 3,
      'level': 5,
      'theory_id': 3,
      'question': 'Как обратиться к пожилой незнакомой женщине?',
      'options': ['акв', 'щўнь', 'ойка'],
      'correct_answer': 'акв',
      'points': 20,
      'order': 5,
    });

    // Модуль 4: Предложения с именным сказуемым
    final module4Theory = '''
**Предложения с именным сказуемым:**
1. Предложения ознакомления:
   - Структура: "указательное местоимение - имя"
   - Пример: "Тын ам" (Это я)

2. Предложения классификации:
   - Структура: "существительное - существительное"
   - Пример: "Ам лёккар" (Я врач)

3. Предложения характеристики:
   - Структура: "существительное - прилагательное"
   - Пример: "Ты нэпак ёмас" (Эта книга хорошая)

**Отрицание:** частица "ёги" перед или после сказуемого
''';

    await theoryStore.add(db, {
      'module': 4,
      'level': 1,
      'content': module4Theory,
      'order': 4,
    });

    // 5 типов заданий для модуля 4
    // Тип 1: Типы предложений
    await tasksStore.add(db, {
      'module': 4,
      'level': 1,
      'theory_id': 4,
      'question': 'К какому типу относится предложение "Тын ам"?',
      'options': ['Ознакомление', 'Классификация', 'Характеристика'],
      'correct_answer': 'Ознакомление',
      'points': 20,
      'order': 1,
    });

    // Тип 2: Построение предложений
    await tasksStore.add(db, {
      'module': 4,
      'level': 2,
      'theory_id': 4,
      'question': 'Как построить предложение "Он рыбак"?',
      'options': ['Тав хўл äлыщлан хум', 'Тын хўл äлыщлан хум', 'Хўл äлыщлан хум тав'],
      'correct_answer': 'Тав хўл äлыщлан хум',
      'points': 20,
      'order': 2,
    });

    // Тип 3: Отрицание
    await tasksStore.add(db, {
      'module': 4,
      'level': 3,
      'theory_id': 4,
      'question': 'Как правильно отрицать "Я не врач"?',
      'options': ['Ам ёги лёккар', 'Ам лёккар ёги', 'Оба варианта верны'],
      'correct_answer': 'Оба варианта верны',
      'points': 20,
      'order': 3,
    });

    // Тип 4: Согласование
    await tasksStore.add(db, {
      'module': 4,
      'level': 4,
      'theory_id': 4,
      'question': 'Как будет "Эти две чашки большие"?',
      'options': ['Ты ёны яныг', 'Ты ёныгыт янгыт', 'Ты ёныт янгыт'],
      'correct_answer': 'Ты ёныгыт янгыт',
      'points': 20,
      'order': 4,
    });

    // Тип 5: Практическое задание
    await tasksStore.add(db, {
      'module': 4,
      'level': 5,
      'theory_id': 4,
      'question': 'Как перевести "Мой старший брат не женат"?',
      'options': ['Ам канкум ёги нэн', 'Ам канкум нэн ёги', 'Ам канкум нэтал'],
      'correct_answer': 'Ам канкум нэтал',
      'points': 20,
      'order': 5,
    });

    // Модуль 5: Разговорная тема "Знакомство"
    final module5Theory = '''
**Фразы для знакомства:**
- Приветствия:
  - "Панда блэн!" - Здравствуй!
  - "Панда, панда!" - Ответ на приветствие

- Представление:
  - "Ам намум [имя]" - Меня зовут [имя]
  - "Нац намын мãныр?" - Как тебя зовут?

- Вопросы:
  - "Тын мãныр?" - Что это? (для предметов/животных)
  - "Тын хōуха?" - Кто это? (для людей)

- Прощание:
  - "Ос ёмас блэн!" - До свидания!
  - "Ос ёмас ўлум!" - Спокойной ночи!

**Пример диалога:**
- Паща блон!
- Паща, паща!
- Ам намум Татья. Нац намын мãныр?
- Ам намум Юван.
''';

    await theoryStore.add(db, {
      'module': 5,
      'level': 1,
      'content': module5Theory,
      'order': 5,
    });

    // 5 типов заданий для модуля 5
    // Тип 1: Приветствия
    await tasksStore.add(db, {
      'module': 5,
      'level': 1,
      'theory_id': 5,
      'question': 'Как сказать "Здравствуй!" на мансийском?',
      'options': ['Панда блэн!', 'Ос ёмас!', 'Пумасица!'],
      'correct_answer': 'Панда блэн!',
      'points': 20,
      'order': 1,
    });

    // Тип 2: Представление
    await tasksStore.add(db, {
      'module': 5,
      'level': 2,
      'theory_id': 5,
      'question': 'Как сказать "Меня зовут Иван"?',
      'options': ['Ам намум Иван', 'Нац намын Иван', 'Таз наме Иван'],
      'correct_answer': 'Ам намум Иван',
      'points': 20,
      'order': 2,
    });

    // Тип 3: Вопросы
    await tasksStore.add(db, {
      'module': 5,
      'level': 3,
      'theory_id': 5,
      'question': 'Как спросить "Кто это?" о человеке?',
      'options': ['Тын мãныр?', 'Тын хōуха?', 'Нац намын мãныр?'],
      'correct_answer': 'Тын хōуха?',
      'points': 20,
      'order': 3,
    });

    // Тип 4: Ответы
    await tasksStore.add(db, {
      'module': 5,
      'level': 4,
      'theory_id': 5,
      'question': 'Как ответить "Это моя собака"?',
      'options': ['Тым ам ёмпум', 'Тым нан ёмпын', 'Тым тав ёмпэ'],
      'correct_answer': 'Тым ам ёмпум',
      'points': 20,
      'order': 4,
    });

    // Тип 5: Диалог
    await tasksStore.add(db, {
      'module': 5,
      'level': 5,
      'theory_id': 5,
      'question': 'Как завершить разговор пожеланием "До свидания!"?',
      'options': ['Панда блэн!', 'Ос ёмас блэн!', 'Пумасица!'],
      'correct_answer': 'Ос ёмас блэн!',
      'points': 20,
      'order': 5,
    });

    // Module 6: Suffixes of adjectives of presence and absence of a feature
    final module6Theory = '''
**Суффиксы прилагательных наличия и отсутствия признака:**
Суффикс =ын образует прилагательные со значением обладания признаком. Например: нб "женщина" + =ын > нбн "женатый". Суффикс =тёл образует прилагательные с отсутствием признака, например: суй "звук" + =тёл > суйтёл "беззвучный".
''';

    await theoryStore.add(db, {
      'module': 6,
      'level': 1,
      'content': module6Theory,
      'order': 6,
    });

    // Module 6 tasks
    await tasksStore.add(db, {
      'module': 6,
      'level': 1,
      'theory_id': 6,
      'question': 'Образуйте прилагательное со значением "крылатый" от слова товыл "крыло".',
      'options': ['товылтёл', 'товлын', 'товылпа', 'товылкве'],
      'correct_answer': 'товлын',
      'points': 20,
      'order': 1,
    });

    await tasksStore.add(db, {
      'module': 6,
      'level': 2,
      'theory_id': 6,
      'question': 'Какое прилагательное означает "безрыбный"?',
      'options': ['хулын', 'хултёл', 'хулпа', 'хулкве'],
      'correct_answer': 'хултёл',
      'points': 20,
      'order': 2,
    });

    await tasksStore.add(db, {
      'module': 6,
      'level': 3,
      'theory_id': 6,
      'question': 'Переведите на русский прилагательное "савтёл".',
      'options': ['бедный', 'богатый', 'безбедный', 'шумный'],
      'correct_answer': 'безбедный',
      'points': 20,
      'order': 3,
    });

    await tasksStore.add(db, {
      'module': 6,
      'level': 4,
      'theory_id': 6,
      'question': 'Образуйте прилагательное от основы "вит" (вода) со значением "водяной".',
      'options': ['виттёл', 'витын', 'витпа', 'виткве'],
      'correct_answer': 'витын',
      'points': 20,
      'order': 4,
    });

    await tasksStore.add(db, {
      'module': 6,
      'level': 5,
      'theory_id': 6,
      'question': 'Какое прилагательное означает "безымянный"?',
      'options': ['намын', 'намтёл', 'намп', 'намкве'],
      'correct_answer': 'намтёл',
      'points': 20,
      'order': 5,
    });

    // Module 7: Diminutive suffixes
    final module7Theory = '''
**Уменьшительные суффиксы:**
Уменьшительные суффиксы =кве и =рищ используются для выражения субъективной оценки. =кве передает ласкательное значение, а =рищ — пренебрежительное. Например: пыл "мальчик" → пылкве "сыночек", амп "собака" → амприщ "собачонка".
''';

    await theoryStore.add(db, {
      'module': 7,
      'level': 1,
      'content': module7Theory,
      'order': 7,
    });

    // Module 7 tasks
    await tasksStore.add(db, {
      'module': 7,
      'level': 1,
      'theory_id': 7,
      'question': 'Образуйте уменьшительно-ласкательную форму от слова "аги" (девочка).',
      'options': ['агирищ', 'агикве', 'агипа', 'агитёл'],
      'correct_answer': 'агикве',
      'points': 20,
      'order': 1,
    });

    await tasksStore.add(db, {
      'module': 7,
      'level': 2,
      'theory_id': 7,
      'question': 'Какое слово означает "лодчонка"?',
      'options': ['халкве', 'халрищ', 'халпа', 'халтёл'],
      'correct_answer': 'халрищ',
      'points': 20,
      'order': 2,
    });

    await tasksStore.add(db, {
      'module': 7,
      'level': 3,
      'theory_id': 7,
      'question': 'Образуйте пренебрежительную форму от слова "уй" (зверь).',
      'options': ['уйкве', 'уйрищ', 'уйпа', 'уйтёл'],
      'correct_answer': 'уйрищ',
      'points': 20,
      'order': 3,
    });

    await tasksStore.add(db, {
      'module': 7,
      'level': 4,
      'theory_id': 7,
      'question': 'Переведите на русский слово "пытрищ".',
      'options': ['мальчик', 'сыночек', 'зверек', 'девочка'],
      'correct_answer': 'мальчик',
      'points': 20,
      'order': 4,
    });

    await tasksStore.add(db, {
      'module': 7,
      'level': 5,
      'theory_id': 7,
      'question': 'Какое слово означает "доченька"?',
      'options': ['агирищ', 'агикве', 'агипа', 'агитёл'],
      'correct_answer': 'агикве',
      'points': 20,
      'order': 5,
    });

    // Module 8: Possessive declension
    final module8Theory = '''
**Притяжательное склонение двойственного числа:**
- 1 лицо = мён  
- 2 лицо = н / ын  
- 3 лицо = тэн / эн  

Например: кол "дом" →  
колмён — наш (двоих) дом  
колын — ваш (двоих) дом  
колэн — их (двоих) дом.
''';

    await theoryStore.add(db, {
      'module': 8,
      'level': 1,
      'content': module8Theory,
      'order': 8,
    });

// Задания модуля 8
    await tasksStore.add(db, {
      'module': 8,
      'level': 36,
      'theory_id': 8,
      'question': 'Как будет "наш (двоих) друг" от слова "рума" (друг)?',
      'options': ['руман', 'руматэн', 'румамён', 'румав'],
      'correct_answer': 'румамён',
      'points': 20,
      'order': 1,
    });
    await tasksStore.add(db, {
      'module': 8,
      'level': 37,
      'theory_id': 8,
      'question': 'Как будет "ваш (двоих) лось" от слова "янгуй" (лось)?',
      'options': ['янгуйн', 'янгуйтэн', 'янгуймён', 'янгуйв'],
      'correct_answer': 'янгуйн',
      'points': 20,
      'order': 2,
    });
    await tasksStore.add(db, {
      'module': 8,
      'level': 38,
      'theory_id': 8,
      'question': 'Как будет "их (двоих) песня" от слова "эрыг" (песня)?',
      'options': ['эрыгн', 'эрыгтэн', 'эрыгмён', 'эрыгв'],
      'correct_answer': 'эрыгтэн',
      'points': 20,
      'order': 3,
    });
    await tasksStore.add(db, {
      'module': 8,
      'level': 39,
      'theory_id': 8,
      'question': 'Как будет "наш (двоих) лес" от слова "вор" (лес)?',
      'options': ['ворн', 'вортэн', 'вормён', 'ворв'],
      'correct_answer': 'вормён',
      'points': 20,
      'order': 4,
    });
    await tasksStore.add(db, {
      'module': 8,
      'level': 40,
      'theory_id': 8,
      'question': 'Как будет "ваш (двоих) стол" от слова "пасан" (стол)?',
      'options': ['пасан', 'пасатэн', 'пасамён', 'пасав'],
      'correct_answer': 'пасан',
      'points': 20,
      'order': 5,
    });

    String module9Theory = '''
**Местный падеж** отвечает на вопросы "где?", "когда?" и образуется:
- после гласных с помощью суффикса **=т**,  
- после согласных — **=ыт**.  

Например:
- кол=т → "в доме"
- класс=ыт → "в классе".
''';

    await theoryStore.add(db, {
      'module': 9,
      'level': 1,
      'content': module9Theory,
      'order': 9,
    });

// Задания модуля 9
    await tasksStore.add(db, {
      'module': 9,
      'level': 41,
      'theory_id': 9,
      'question': 'Как будет "в лесу" от слова "вор" (лес)?',
      'options': ['ворт', 'ворыт', 'вормён', 'ворв'],
      'correct_answer': 'ворт',
      'points': 20,
      'order': 1,
    });
    await tasksStore.add(db, {
      'module': 9,
      'level': 42,
      'theory_id': 9,
      'question': 'Как будет "в котле" от слова "пут" (котел)?',
      'options': ['путт', 'путыт', 'путмён', 'путв'],
      'correct_answer': 'путт',
      'points': 20,
      'order': 2,
    });
    await tasksStore.add(db, {
      'module': 9,
      'level': 43,
      'theory_id': 9,
      'question': 'Как будет "в моей лодке" от слова "хал" (лодка)?',
      'options': ['халт', 'халыт', 'халумт', 'халв'],
      'correct_answer': 'халумт',
      'points': 20,
      'order': 3,
    });
    await tasksStore.add(db, {
      'module': 9,
      'level': 44,
      'theory_id': 9,
      'question': 'Как будет "в нашем доме" от слова "кол" (дом)?',
      'options': ['колт', 'колыт', 'колувт', 'колмён'],
      'correct_answer': 'колувт',
      'points': 20,
      'order': 4,
    });
    await tasksStore.add(db, {
      'module': 9,
      'level': 45,
      'theory_id': 9,
      'question': 'Как будет "в этом месяце" от слова "этнос" (месяц)?',
      'options': ['этност', 'этносыт', 'этносмён', 'этносв'],
      'correct_answer': 'этносыт',
      'points': 20,
      'order': 5,
    });

    final module10Theory = '''
**Предложения местонахождения** имеют структуру:  
**существительное – обстоятельство места**  
Например: Атям ворт — "Мой папа в лесу".

**Предложения наличия** имеют структуру:  
**обстоятельство места – существительное**  
Например: Ворт атям — "В лесу мой папа".
''';

    await theoryStore.add(db, {
      'module': 10,
      'level': 1,
      'content': module10Theory,
      'order': 10,
    });

// Задания модуля 10
    await tasksStore.add(db, {
      'module': 10,
      'level': 46,
      'theory_id': 10,
      'question': 'Как перевести предложение "Мама в доме"?',
      'options': ['Омам колт', 'Колт омам', 'Омам кол', 'Кол омам'],
      'correct_answer': 'Омам колт',
      'points': 20,
      'order': 1,
    });
    await tasksStore.add(db, {
      'module': 10,
      'level': 47,
      'theory_id': 10,
      'question': 'Как перевести предложение "В реке много рыбы"?',
      'options': ['Ят хул сака', 'Хул сака ят', 'Ят сака хул', 'Хул ят сака'],
      'correct_answer': 'Ят хул сака',
      'points': 20,
      'order': 2,
    });
    await tasksStore.add(db, {
      'module': 10,
      'level': 48,
      'theory_id': 10,
      'question': 'Как перевести предложение "Где твой брат?"?',
      'options': ['Хот аппин?', 'Аппин хот?', 'Хот аппинт?', 'Аппинт хот?'],
      'correct_answer': 'Хот аппин?',
      'points': 20,
      'order': 3,
    });
    await tasksStore.add(db, {
      'module': 10,
      'level': 49,
      'theory_id': 10,
      'question': 'Как перевести предложение "В классе девочки"?',
      'options': ['Классут агирищ', 'Агирищ классут', 'Классут аги', 'Аги классут'],
      'correct_answer': 'Классут агирищ',
      'points': 20,
      'order': 4,
    });
    await tasksStore.add(db, {
      'module': 10,
      'level': 50,
      'theory_id': 10,
      'question': 'Как перевести предложение "Моя книга в столе"?',
      'options': ['Нэпакам пасант', 'Пасант нэпакам', 'Нэпакам пасан', 'Пасан нэпакам'],
      'correct_answer': 'Нэпакам пасант',
      'points': 20,
      'order': 5,
    });

    Future<void> _populateRiddles(Database db) async {
      final riddleStore = intMapStoreFactory.store('riddles');

      // Проверяем, есть ли уже загадки
      final count = await riddleStore.count(db);
      if (count > 0) return;

      // Добавляем 20 загадок
      final List<Map<String, dynamic>> riddles = [
        {
          'id': 1,
          'question': 'Рыба у него без костей, вода у него дорогая, с двух сторон железо.',
          'options': ['Ножницы', 'Чайник', 'Лодка', 'Сковорода'],
          'correct_answer': 'Чайник',
        },
        {
          'id': 2,
          'question': 'Живёт старик, одна его щека в небо упирается, другая в землю...',
          'options': ['Гора', 'Дерево', 'Мост', 'Холм'],
          'correct_answer': 'Гора',
        },
        {
          'id': 3,
          'question': 'Одна голова, две спины, пять хвостов.',
          'options': ['Рука', 'Стул', 'Плуг', 'Конь'],
          'correct_answer': 'Рука',
        },
        {
          'id': 4,
          'question': 'Без окон, без дверей, а живут люди в ней.',
          'options': ['Подвал', 'Яйцо', 'Тюрьма', 'Дом'],
          'correct_answer': 'Яйцо',
        },
        {
          'id': 5,
          'question': 'Не конь, а бежит, не лес, а шумит.',
          'options': ['Пароход', 'Река', 'Поезд', 'Ветер'],
          'correct_answer': 'Река',
        },
        {
          'id': 6,
          'question': 'Если ешь — не выешь, если пьёшь — не выпьешь.',
          'options': ['Соль', 'Сахар', 'Вода', 'Завтрак'],
          'correct_answer': 'Соль',
        },
        {
          'id': 7,
          'question': 'Стоит на крыше верх трубой, как будто хочет сесть на мчою.',
          'options': ['Печь', 'Труба', 'Скворечник', 'Флюгер'],
          'correct_answer': 'Печь',
        },
        {
          'id': 8,
          'question': 'Что быстрее мысли?',
          'options': ['Ветер', 'Свет', 'Электричество', 'Никто'],
          'correct_answer': 'Никто',
        },
        {
          'id': 9,
          'question': 'Что было завтра, а будет вчера?',
          'options': ['Сегодня', 'Время', 'Завтра', 'Прошлое'],
          'correct_answer': 'Сегодня',
        },
        {
          'id': 10,
          'question': 'Два братца через дорогу живут, а друг друга не видят.',
          'options': ['Глаза', 'Уши', 'Мост', 'Пешеходный переход'],
          'correct_answer': 'Глаза',
        },
        {
          'id': 11,
          'question': 'Что становится мокрым при сушке?',
          'options': ['Полотенце', 'Вода', 'Воздух', 'Пол'],
          'correct_answer': 'Полотенце',
        },
        {
          'id': 12,
          'question': 'Идёт, качается, упадёт — никому не встать.',
          'options': ['Волна', 'Дерево', 'Тень', 'Снег'],
          'correct_answer': 'Тень',
        },
        {
          'id': 13,
          'question': 'Кто говорит на всех языках?',
          'options': ['Попугай', 'Переводчик', 'Эхо', 'Многознайка'],
          'correct_answer': 'Эхо',
        },
        {
          'id': 14,
          'question': 'Что можно увидеть с закрытыми глазами?',
          'options': ['Сон', 'Тьму', 'Мир', 'Ничего'],
          'correct_answer': 'Сон',
        },
        {
          'id': 15,
          'question': 'На что похожа половина яблока?',
          'options': ['На круг', 'На мяч', 'На половинку', 'На другую половинку'],
          'correct_answer': 'На другую половинку',
        },
        {
          'id': 16,
          'question': 'Что может путешествовать по свету, оставаясь в одном месте?',
          'options': ['Почта', 'Карта', 'Фотография', 'Место'],
          'correct_answer': 'Почта',
        },
        {
          'id': 17,
          'question': 'Что всегда увеличивается и никогда не уменьшается?',
          'options': ['Время', 'Цена', 'Знания', 'Голод'],
          'correct_answer': 'Время',
        },
        {
          'id': 18,
          'question': 'Что принадлежит вам, но используется чаще другими?',
          'options': ['Имя', 'Фамилия', 'Телефон', 'Адрес'],
          'correct_answer': 'Имя',
        },
        {
          'id': 19,
          'question': 'Что можно сломать, даже не прикасаясь к нему?',
          'options': ['Обещание', 'Правило', 'Сердце', 'Молчание'],
          'correct_answer': 'Обещание',
        },
        {
          'id': 20,
          'question': 'Что становится мокрым при сушке?',
          'options': ['Полотенце', 'Вода', 'Воздух', 'Пол'],
          'correct_answer': 'Полотенце',
        }
      ];

      for (var riddle in riddles) {
        await riddleStore.add(db, riddle);
      }
      await _populateRiddles(db);
    }
    Future<List<Map<String, dynamic>>> getRiddles() async {
      final String jsonString = await rootBundle.loadString('assets/riddles.json');
      final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(jsonMap['riddles']);
    }
  }

  Future<List<Map<String, dynamic>>> getModuleLevels(int moduleId) async {
    final db = await _database;
    final store = intMapStoreFactory.store('tasks');

    final finder = Finder(
      filter: Filter.equals('module', moduleId),
      sortOrders: [SortOrder('level')],
    );

    final records = await store.find(db, finder: finder);

    // Group tasks by level and get unique levels
    final levels = <int, Map<String, dynamic>>{};

    for (final record in records) {
      final level = record.value['level'] as int;
      if (!levels.containsKey(level)) {
        levels[level] = {
          'module': moduleId,
          'level': level,
          'has_theory': true, // Assume each level has theory
        };
      }
    }

    // Convert to list and sort
    return levels.values.toList()
      ..sort((a, b) => (a['level'] as int).compareTo(b['level'] as int));
  }

  Future<Map<String, dynamic>?> getTheory(int moduleId, int level) async {
    final db = await _database;
    final store = intMapStoreFactory.store('theory');

    final finder = Finder(
      filter: Filter.and([
        Filter.equals('module', moduleId),
        Filter.equals('level', level),
      ]),
    );

    final record = await store.findFirst(db, finder: finder);
    return record?.value;
  }

  Future<List<Map<String, dynamic>>> getTasks(int moduleId, int level) async {
    final db = await _database;
    final taskStore = intMapStoreFactory.store('tasks');
    final records = await taskStore.find(db, finder: Finder(filter: Filter.and([
      Filter.equals('module', moduleId),
      Filter.equals('level', level),
    ])));

    return records.map((record) => record.value).toList();
  }

  Future<void> saveUserProgress(int moduleId, int level, int score) async {
    final db = await _database;
    final progressStore = intMapStoreFactory.store('user_progress');
    await progressStore.record(moduleId).put(db, {
      'module': moduleId,
      'level': level,
      'score': score,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> getUserProgress(int moduleId) async {
    final db = await _database;
    final progressStore = intMapStoreFactory.store('user_progress');

    return await progressStore.record(moduleId).get(db);
  }

  Future<List<Map<String, dynamic>>> getRiddles() async {
    final db = await _database;
    final store = intMapStoreFactory.store('riddles');
    final records = await store.find(db);
    return records.map((record) => record.value).toList();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset("assets/images/logo.png"),
        ),
        title: LayoutBuilder(
          builder: (context, constraints) {
            // Размер шрифта от 20 до 24 в зависимости от ширины экрана
            final fontSize = constraints.maxWidth > 600 ? 24.0 : 20.0;

            return Text(
              "Переводчик",
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.normal, // Нежирный текст
              ),
            );
          },
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
    {'id': 1, 'title': 'Фонетика мансийского языка'},
    {'id': 2, 'title': 'Грамматика (число и местоимения)'},
    {'id': 3, 'title': 'Лексика (термины родства)'},
    {'id': 4, 'title': 'Предложения с именным сказуемым'},
    {'id': 5, 'title': 'Разговорная тема "Знакомство"'},
    {'id': 6, 'title': 'Суффиксы прилагательных'},
    {'id': 7, 'title': 'Уменьшительные суффиксы'},
    {'id': 8, 'title': 'Притяжательное склонение'},
    {'id': 9, 'title': 'Местный падеж'},
    {'id': 10, 'title': 'Предложения наличия и местонахождения'},
  ];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openMenu() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  MainMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Главное меню')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Выберите модуль:', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: modules.length,
                itemBuilder: (context, index) => _buildModuleItem(context, modules[index]),
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<int>(
              future: AppDatabase().getCompletedRiddlesCount(),
              builder: (context, snapshot) {
                final solved = snapshot.data ?? 0;
                final nextRiddleNumber = solved + 1;
                final neededScore = nextRiddleNumber * 100;

                return ListTile(
                  tileColor: Colors.green[100],
                  title: const Text('Решить загадку'),
                  subtitle: Text('Доступна загадка №$nextRiddleNumber'),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () async {
                    final totalScore = await AppDatabase().getUserTotalScore();
                    if (totalScore >= neededScore) {
                      _openRiddlePage(context, solved);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Нужно ещё $neededScore очков')),
                      );
                    }
                  },
                );
              },
            )
          ],
        ),
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
                title: const Text('Обучение', style: TextStyle(fontSize: 20, color: Color(0xFF0A4B47))),
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

  void _openRiddlePage(BuildContext context, int solvedRiddles) async {
    final data = await loadRiddles();
    final progressData = await AppDatabase().getRiddleProgress();

    final totalScore = progressData['total_score'] as int? ?? 0;
    final nextRequiredScore = (solvedRiddles + 1) * 100;

    if (totalScore >= nextRequiredScore) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RiddlePage(
            riddleIndex: solvedRiddles,
            userScore: totalScore,
            riddles: data['riddles'],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Нужно ещё $nextRequiredScore очков'),
        ),
      );
    }
  }

  Widget _buildModuleItem(BuildContext context, Map<String, dynamic> module) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: AppDatabase().getUserProgress(module['id']),
      builder: (context, snapshot) {
        final progress = snapshot.data;
        final completed = progress != null && (progress['level'] as int) >= 5;
        return ListTile(
          title: Text(module['title']),
          subtitle: completed ? const Text('Пройден') : const Text('В процессе'),
          trailing: const Icon(Icons.arrow_forward),
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
            }
        );
      },
    );
  }

  Widget _buildMenuRow(BuildContext context, Map<String, dynamic> module, int number, Alignment alignment) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: AppDatabase().getUserProgress(module['id']),
      builder: (context, snapshot) {
        final progress = snapshot.data;
        final completed = progress != null && (progress['level'] as int) >= 5;

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
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: completed ? Colors.green : const Color(0xFF0A4B47),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.black,
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$number',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 60,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  module['title'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (progress != null) Text(
                  'Прогресс: ${progress['level']}/5',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
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
                      fontSize: 20,
                      color: Colors.black)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => TranslatePage()));
              },
            ),
            ListTile(
              title: Text('Обучение',
                  style: TextStyle(
                      fontSize: 20,
                      color: const Color(0xFF0A4B47))),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text('История переводов',
                  style: TextStyle(
                      fontSize: 20,
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

class TheoryPage extends StatefulWidget {
  final int moduleId;
  final int level;
  final String moduleTitle;

  const TheoryPage({
    super.key,
    required this.moduleId,
    required this.level,
    required this.moduleTitle,
  });

  @override
  State<TheoryPage> createState() => _TheoryPageState();
}

class _TheoryPageState extends State<TheoryPage> {
  late Future<Map<String, dynamic>?> _theoryFuture;
  late Future<List<Map<String, dynamic>>> _tasksFuture;

  @override
  void initState() {
    super.initState();
    _theoryFuture = AppDatabase().getTheory(widget.moduleId, widget.level);
    _tasksFuture = AppDatabase().getTasks(widget.moduleId, widget.level);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.moduleTitle} - Уровень ${widget.level}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0A4B47),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _theoryFuture,
        builder: (context, theorySnapshot) {
          if (theorySnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: theorySnapshot.hasData
                      ? Text(
                    theorySnapshot.data!['content'] as String,
                    style: const TextStyle(fontSize: 18),
                  )
                      : const Text(
                    'Теория не требуется для этого уровня',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _tasksFuture,
                    builder: (context, tasksSnapshot) {
                      if (tasksSnapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }

                      final hasTasks = tasksSnapshot.hasData && tasksSnapshot.data!.isNotEmpty;

                      return ElevatedButton(
                        onPressed: hasTasks
                            ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TaskPage(
                                moduleId: widget.moduleId,
                                level: widget.level,
                                moduleTitle: widget.moduleTitle,
                                tasks: tasksSnapshot.data!,
                                initialScore: 0,
                              ),
                            ),
                          );
                        }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A4B47),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Перейти к заданиям'),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class TaskPage extends StatefulWidget {
  final int moduleId;
  final int level;
  final String moduleTitle;
  final List<Map<String, dynamic>> tasks;
  final int initialScore;

  const TaskPage({
    super.key,
    required this.moduleId,
    required this.level,
    required this.moduleTitle,
    required this.tasks,
    required this.initialScore,
  });
@override
State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  int _currentTaskIndex = 0;
  int _score = 0;
  bool _showSuccess = false;
  String? _selectedAnswer;
  bool _answerChecked = false;
  bool _isLastLevel = false;
  List<String> _selectedMultipleAnswers = [];
  late Future<List<Map<String, dynamic>>> _tasksFuture;

  @override
  void initState() {
    super.initState();
    _score = widget.initialScore;
    _tasksFuture = widget.tasks != null
        ? Future.value(widget.tasks!)
        : AppDatabase().getTasks(widget.moduleId, widget.level);
    _checkIfLastLevel();
  }

  Future<void> _checkIfLastLevel() async {
    final levels = await AppDatabase().getModuleLevels(widget.moduleId);
    final maxLevel = levels.last['level'] as int;
    setState(() {
      _isLastLevel = widget.level >= maxLevel;
    });
  }

  void _checkAnswer() {
    if (_selectedAnswer == null && _selectedMultipleAnswers.isEmpty) return;

    _tasksFuture.then((tasks) {
      final currentTask = tasks[_currentTaskIndex];
      final isCorrect = currentTask['type'] == 'multiple'
          ? _selectedMultipleAnswers.contains(currentTask['correct_answer'])
          : _selectedAnswer == currentTask['correct_answer'];

      setState(() {
        _answerChecked = true;
        if (isCorrect) {
          _score += currentTask['points'] as int;
          _showSuccess = true;
        } else {
          _showSuccess = false;
        }
      });
    });
  }

  void _checkAndOpenRiddle(int score, BuildContext context) async {
    debugPrint('Проверяем доступность загадки. Очки: $score');

    final riddlesList = await AppDatabase().getRiddles();
    if (riddlesList.isEmpty) {
      debugPrint('Нет загадок в базе данных');
      return;
    }

    final solvedRiddles = await AppDatabase().getCompletedRiddlesCount();
    final neededScore = (solvedRiddles + 1) * 100;

    debugPrint('Необходимо очков: $neededScore | Текущие очки: $score');

    if (score >= neededScore) {
      debugPrint('Открываем загадку №${solvedRiddles + 1}');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RiddlePage(
            riddleIndex: solvedRiddles,
            userScore: score,
            riddles: riddlesList,
          ),
        ),
      );
    } else {
      debugPrint('Недостаточно очков для следующей загадки');
    }
  }
  void _nextTaskOrLevel(BuildContext context) async {
    if (_currentTaskIndex < widget.tasks.length - 1) {
      setState(() {
        _currentTaskIndex++;
        _selectedAnswer = null;
        _answerChecked = false;
        _showSuccess = false;
      });
    } else {
      // Сохраняем прогресс пользователя
      await AppDatabase().saveUserProgress(widget.moduleId, widget.level, _score);
      final totalScore = await AppDatabase().getUserTotalScore();
      // Сохраняем прогресс по загадкам
      final solvedRiddlesCount = await AppDatabase().getCompletedRiddlesCount();
      await AppDatabase().saveRiddleProgress(solvedRiddlesCount, totalScore);

      // Проверяем, есть ли ещё уровни
      final levels = await AppDatabase().getModuleLevels(widget.moduleId);
      final nextLevel = widget.level + 1;
      final hasNextLevel = levels.any((l) => l['level'] == nextLevel);

      if (hasNextLevel) {
        final nextLevelTasks = await AppDatabase().getTasks(widget.moduleId, nextLevel);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TaskPage(
              moduleId: widget.moduleId,
              level: nextLevel,
              moduleTitle: widget.moduleTitle,
              tasks: nextLevelTasks,
              initialScore: _score,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Модуль завершён!')),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ModuleLevelsPage(
              moduleId: widget.moduleId,
              moduleTitle: widget.moduleTitle,
            ),
          ),
        );

        // Проверка доступности загадок
        if (_score >= 100 && _score % 100 == 0) {
          AppDatabase().getRiddles().then((riddlesList) {
            if (riddlesList.isNotEmpty) {
              final int riddleNumber = (_score ~/ 100) - 1;
              if (riddleNumber < riddlesList.length) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RiddlePage(
                      riddleIndex: riddleNumber,
                      userScore: _score,
                      riddles: riddlesList,
                    ),
                  ),
                );
              }
            }
          });
        }
      }
    }
  }

  Widget _buildQuestionWidget(Map<String, dynamic> task) {
    switch (task['type'] ?? 'single') {
      case 'true_false':
        return Column(
          children: [
            Text(task['question'], style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            RadioListTile<String>(
              title: const Text('Правда'),
              value: 'true',
              groupValue: _selectedAnswer,
              onChanged: _answerChecked
                  ? null
                  : (String? value) {
                setState(() {
                  _selectedAnswer = value;
                });
              },
            ),
            RadioListTile<String>(
              title: const Text('Ложь'),
              value: 'false',
              groupValue: _selectedAnswer,
              onChanged: _answerChecked
                  ? null
                  : (String? value) {
                setState(() {
                  _selectedAnswer = value;
                });
              },
            ),
          ],
        );
      case 'multiple':
        return Column(
          children: [
            Text(task['question'], style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            ...(task['options'] as List).map((option) => CheckboxListTile(
                title: Text(option),
                value: _selectedMultipleAnswers.contains(option),
                onChanged: _answerChecked
                    ? null
                    : (checked) {
                  setState(() {
                    if (checked == true) {
                      _selectedMultipleAnswers.add(option);
                    } else {
                      _selectedMultipleAnswers.remove(option);
                    }
                  });
                })),
          ],
        );
      default:
        return Column(
          children: [
            Text(task['question'], style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            ...(task['options'] as List).map((option) => RadioListTile<String>(
              title: Text(option),
              value: option,
              groupValue: _selectedAnswer,
              onChanged: _answerChecked
                  ? null
                  : (String? value) {
                setState(() {
                  _selectedAnswer = value;
                });
              },
            )),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.moduleTitle} - Уровень ${widget.level}'),
        backgroundColor: const Color(0xFF0A4B47),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _tasksFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Ошибка загрузки заданий: ${snapshot.error}'));
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('Задания не найдены'));
            }

            final tasks = snapshot.data!;
            final currentTask = tasks[_currentTaskIndex];

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildQuestionWidget(currentTask),
                  ),
                ),
                if (_answerChecked)
                  Text(
                    _showSuccess ? 'Правильно!' : 'Неправильно!',
                    style: TextStyle(
                      color: _showSuccess ? Colors.green : Colors.red,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  'Счет: $_score',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 20),
                if (!_answerChecked)
                  ElevatedButton(
                    onPressed: () => _checkAnswer(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A4B47),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Проверить', style: TextStyle(fontSize: 18)),
                  )
                else
                  ElevatedButton(
                    onPressed: () => _nextTaskOrLevel(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A4B47),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: Text(
                      _currentTaskIndex < tasks.length - 1
                          ? 'Следующее задание'
                          : _isLastLevel ? 'Завершить модуль' : 'Следующий уровень',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
              ],
            );
          },
        ),
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
                title: const Text('Обучение', style: TextStyle(fontSize: 20, color: Color(0xFF0A4B47))),
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

class ModuleLevelsPage extends StatefulWidget {
  final int moduleId;
  final String moduleTitle;

  const ModuleLevelsPage({
    super.key,
    required this.moduleId,
    required this.moduleTitle,
  });

  @override
  State<ModuleLevelsPage> createState() => _ModuleLevelsPageState();
}

class _ModuleLevelsPageState extends State<ModuleLevelsPage> {
  late Future<List<Map<String, dynamic>>> levelsFuture;
  late Future<Map<String, dynamic>?> userProgressFuture;

  @override
  void initState() {
    super.initState();
    levelsFuture = AppDatabase().getModuleLevels(widget.moduleId);
    userProgressFuture = AppDatabase().getUserProgress(widget.moduleId);
  }

  Future<void> _startLevel(BuildContext context, int level) async {
    final hasTheory = await _hasTheoryForLevel(widget.moduleId, level);

    if (hasTheory) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TheoryPage(
            moduleId: widget.moduleId,
            level: level,
            moduleTitle: widget.moduleTitle,
          ),
        ),
      );
    } else {
      final tasks = await AppDatabase().getTasks(widget.moduleId, level);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TaskPage(
            moduleId: widget.moduleId,
            level: level,
            moduleTitle: widget.moduleTitle,
            tasks: tasks,
            initialScore: 0,
          ),
        ),
      );
    }
  }

  Future<bool> _hasTheoryForLevel(int moduleId, int level) async {
    final theory = await AppDatabase().getTheory(moduleId, level);
    return theory != null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.moduleTitle),
        backgroundColor: const Color(0xFF0A4B47),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: levelsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка загрузки: ${snapshot.error}'));
          }

          final levels = snapshot.data ?? [];

          return FutureBuilder<Map<String, dynamic>?>(
            future: userProgressFuture,
            builder: (context, progressSnapshot) {
              final maxUnlockedLevel = progressSnapshot.data?['level'] ?? 0;

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: levels.length,
                itemBuilder: (context, index) {
                  final level = levels[index];
                  final levelNumber = level['level'] as int;
                  final isUnlocked = levelNumber <= maxUnlockedLevel + 1;

                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(
                        'Уровень $levelNumber',
                        style: const TextStyle(fontSize: 18),
                      ),
                      trailing: const Icon(Icons.arrow_forward),
                      enabled: isUnlocked,
                      onTap: () => _startLevel(context, levelNumber),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

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
        title: LayoutBuilder(
          builder: (context, constraints) {
            final fontSize = constraints.maxWidth > 600 ? 24.0 : 20.0;

            return Text(
              "История переводов",
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.normal,
              ),
            );
          },
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDateTime(context, true),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today, size: 16),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _startDate != null
                                      ? _dateFormat.format(_startDate!)
                                      : 'Начало',
                                  style: TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDateTime(context, false),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today, size: 16),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _endDate != null
                                      ? _dateFormat.format(_endDate!)
                                      : 'Конец',
                                  style: TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildSmallActionButton(
                      onPressed: () => _exportAllData(context),
                      isLoading: _isExporting,
                      text: 'Экспорт',
                      color: const Color(0xFF0A4B47),
                    ),
                    _buildSmallActionButton(
                      onPressed: () => _importAllData(context),
                      isLoading: _isImporting,
                      text: 'Импорт',
                      color: const Color(0xFF0A4B47),
                    ),
                    _buildSmallActionButton(
                      onPressed: () => _removeDuplicates(context),
                      isLoading: _isClearing,
                      text: 'Дубликаты',
                      color: Colors.orange,
                    ),
                    _buildSmallActionButton(
                      onPressed: () => _clearHistory(context),
                      isLoading: _isClearing,
                      text: 'Очистить',
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

Widget _buildSmallActionButton({
  required VoidCallback onPressed,
  required bool isLoading,
  required String text,
  required Color color,
}) {
  return SizedBox(
    height: 36,
    child: ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: isLoading
          ? const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      )
          : Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.white,
        ),
      ),
    ),
  );
}


class RiddlePage extends StatefulWidget {
  final int riddleIndex;
  final int userScore;
  final List<Map<String, dynamic>> riddles;

  const RiddlePage({
    super.key,
    required this.riddleIndex,
    required this.userScore,
    required this.riddles,
  });

  @override
  State<RiddlePage> createState() => _RiddlePageState();
}

class _RiddlePageState extends State<RiddlePage> {
  String? _selectedAnswer;
  bool _answerChecked = false;
  bool _showSuccess = false;

  late final Map<String, dynamic> currentRiddle;

  @override
  void initState() {
    super.initState();
    currentRiddle = widget.riddles[widget.riddleIndex];
  }

  void _checkAnswer() {
    setState(() {
      _answerChecked = true;
      if (_selectedAnswer == currentRiddle['correct_answer']) {
        _showSuccess = true;
        AppDatabase().saveRiddleProgress(widget.riddleIndex + 1, widget.userScore + 100);
      }
    });
  }

  void _nextRiddle(BuildContext context) {
    if (widget.riddleIndex < widget.riddles.length - 1 && _selectedAnswer == currentRiddle['correct_answer']) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RiddlePage(
            riddleIndex: widget.riddleIndex + 1,
            riddles: widget.riddles,
            userScore: widget.userScore + 100,
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Поздравляем!'),
          content: const Text('Вы решили все загадки!'),
          actions: [
            TextButton(onPressed: Navigator.of(context).pop, child: const Text('OK')),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Загадка')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Загадка №${widget.riddleIndex + 1}', style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 10),
            Text(currentRiddle['question']),
            const SizedBox(height: 20),
            ...List<Widget>.from(
              (currentRiddle['options'] as List<String>).map((option) {
                return RadioListTile<String>(
                  title: Text(option),
                  value: option,
                  groupValue: _selectedAnswer,
                  onChanged: _answerChecked
                      ? null
                      : (value) {
                    setState(() {
                      _selectedAnswer = value;
                    });
                  },
                );
              }),
            ),
            if (_answerChecked)
              Text(
                _showSuccess ? 'Правильно!' : 'Неправильно!',
                style: TextStyle(
                  color: _showSuccess ? Colors.green : Colors.red,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 10),
            Text('Очки: ${widget.userScore}'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _answerChecked
                  ? () => _nextRiddle(context)
                  : _checkAnswer,
              child: Text(_answerChecked ? 'Следующая загадка' : 'Проверить'),
            ),
          ],
        ),
      ),
    );
  }
}