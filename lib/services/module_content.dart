class ModuleContent {
  // Модуль 1: Звуки и произношение
  static const Map<String, dynamic> module1Sounds = {
    'id': 1,
    'title': 'Звуки и произношение',
    'description': 'Фонетика мансийского языка',
    'theory': '''
Гласные звуки

В мансийском языке 12 гласных:
- 6 кратких: а, о, у, и, е, ы
- 6 долгих: ӓ, ӧ, ӱ, ӣ, ё, ӹ

Важно: Долгота обозначается двумя точками сверху (макроном).

Примеры:
- аква [akva] — один
- а̄ква [aːkva] — пять

Согласные звуки

17 согласных:
- Сонорные: м, н, ң, л, р, й
- Шумные: п, т, к, б, д, г, в, с, ш, з, ж, х, ц, ч, щ

Ударение
Всегда падает на ПЕРВЫЙ слог!
''',
    'audioFiles': [
      'assets/audio/phonetics/vowels_short.mp3',
      'assets/audio/phonetics/vowels_long.mp3',
      'assets/audio/phonetics/consonants.mp3',
      'assets/audio/phonetics/stress.mp3',
    ],
    'levels': [
      {
        'id': 1,
        'title': 'Краткие vs Долгие гласные',
        'points': 10,
        'exercises': [
          {
            'type': 'audio_match',
            'question': 'Какое слово вы услышали?',
            'audio': 'assets/audio/exercises/mod1_lvl1_ex1.mp3',
            'options': ['аква', 'а̄ква'],
            'correct': 1,
            'transcription': '[aːkva]',
          },
          // Тут будут 9 упражнений, верьте мне
        ],
      },
      // Тут будут 10 уровней, верьте мне
    ],
  };

  // Модуль 2: Состав слова
  static const Map<String, dynamic> module2WordStructure = {
    'id': 2,
    'title': 'Состав слова',
    'description': 'Морфология и словообразование',
    'theory': '''
Морфология

Мансийский — агглютинативный язык:
- Корень + суффиксы
- Каждый суффикс имеет одно значение

Числа имён существительных
1. Единственное: хӯп (лодка)
2. Двойственное: хӯп-ыг (две лодки)
3. Множественное: хӯп-ыт (лодки)

Падежи:
1. Именительный: хӯп
2. Местный: хӯп-т (в лодке)
3. Лательный: хӯп-н (в лодку)
4. Исходный: хӯп-ныл (из лодки)
5. Творительный: хӯп-ыл (лодкой)
6. Превратительный: хӯп-ыг (стал лодкой)
''',
    'audioFiles': [
      'assets/audio/morphology/cases.mp3',
      'assets/audio/morphology/numbers.mp3',
      'assets/audio/morphology/possessive.mp3',
    ],
    'levels': [
      {
        'id': 1,
        'title': 'Числа существительных',
        'points': 10,
        'exercises': [
          {
            'type': 'choice',
            'question': 'Выберите форму двойственного числа:',
            'word': 'хӯп (лодка)',
            'options': ['хӯп', 'хӯпыг', 'хӯпыт'],
            'correct': 1,
            'transcription': '[xuːpɨg]',
          },
          // Тут будут 9 упражнений, верьте мне
        ],
      },
      // Тут будут 10 уровней, верьте мне
    ],
  };
}