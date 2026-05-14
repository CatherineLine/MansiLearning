class Module {
  final int? id;
  final String title;
  final String? description;
  final int orderIndex;

  Module({this.id, required this.title, this.description, required this.orderIndex});

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'order_index': orderIndex,
  };

  factory Module.fromMap(Map<String, dynamic> map) => Module(
    id: map['id'],
    title: map['title'],
    description: map['description'],
    orderIndex: map['order_index'],
  );
}

class Level {
  final int? id;
  final int moduleId;
  final String title;
  final String difficulty;

  Level({this.id, required this.moduleId, required this.title, required this.difficulty});

  Map<String, dynamic> toMap() => {
    'id': id,
    'module_id': moduleId,
    'title': title,
    'difficulty': difficulty,
  };

  factory Level.fromMap(Map<String, dynamic> map) => Level(
    id: map['id'],
    moduleId: map['module_id'],
    title: map['title'],
    difficulty: map['difficulty'],
  );
}

class Theory {
  final int? id;
  final int levelId;
  final int? mediaId;
  final String contentHtml;

  Theory({this.id, required this.levelId, this.mediaId, required this.contentHtml});

  Map<String, dynamic> toMap() => {
    'id': id,
    'level_id': levelId,
    'media_id': mediaId,
    'content_html': contentHtml,
  };

  factory Theory.fromMap(Map<String, dynamic> map) => Theory(
    id: map['id'],
    levelId: map['level_id'],
    mediaId: map['media_id'],
    contentHtml: map['content_html'],
  );
}

class Task {
  final int? id;
  final int levelId;
  final int? mediaId;
  final String questionText;
  final String type;
  final String correctAnswer;
  final String optionsJson;

  Task({
    this.id,
    required this.levelId,
    this.mediaId,
    required this.questionText,
    required this.type,
    required this.correctAnswer,
    required this.optionsJson,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'level_id': levelId,
    'media_id': mediaId,
    'question_text': questionText,
    'type': type,
    'correct_answer': correctAnswer,
    'options_json': optionsJson,
  };

  factory Task.fromMap(Map<String, dynamic> map) => Task(
    id: map['id'],
    levelId: map['level_id'],
    mediaId: map['media_id'],
    questionText: map['question_text'],
    type: map['type'],
    correctAnswer: map['correct_answer'],
    optionsJson: map['options_json'],
  );
}