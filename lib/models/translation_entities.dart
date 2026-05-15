class Translation {
  final int? id;
  final int? sessionId;
  final String originalText;
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final bool isFavorite;

  Translation({
    this.id,
    this.sessionId,
    required this.originalText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.isFavorite = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'session_id': sessionId ?? 1,
    'source_text': originalText,
    'target_text': translatedText,
    'source_lang': sourceLanguage,
    'target_lang': targetLanguage,
    'is_favorite': isFavorite ? 1 : 0,
  };

  factory Translation.fromMap(Map<String, dynamic> map) => Translation(
    id: map['id'],
    sessionId: map['session_id'],
    originalText: map['source_text'] ?? '',
    translatedText: map['target_text'] ?? '',
    sourceLanguage: map['source_lang'] ?? 'ru',
    targetLanguage: map['target_lang'] ?? 'mansi',
    isFavorite: map['is_favorite'] == 1,
  );
}

class PhraseCategory {
  final int? id;
  final String name;
  final String iconResource;

  PhraseCategory({this.id, required this.name, required this.iconResource});

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'icon_resource': iconResource,
  };

  factory PhraseCategory.fromMap(Map<String, dynamic> map) => PhraseCategory(
    id: map['id'],
    name: map['name'],
    iconResource: map['icon_resource'],
  );
}

class Phrase {
  final int? id;
  final int categoryId;
  final int? mediaId;
  final String textMansi;
  final String textRussian;
  final String? transcription;

  Phrase({
    this.id,
    required this.categoryId,
    this.mediaId,
    required this.textMansi,
    required this.textRussian,
    this.transcription,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'category_id': categoryId,
    'media_id': mediaId,
    'text_mansi': textMansi,
    'text_russian': textRussian,
    'transcription': transcription,
  };

  factory Phrase.fromMap(Map<String, dynamic> map) => Phrase(
    id: map['id'],
    categoryId: map['category_id'],
    mediaId: map['media_id'],
    textMansi: map['text_mansi'],
    textRussian: map['text_russian'],
    transcription: map['transcription'],
  );
}

class UserPhrasebook {
  final int userId;
  final int phraseId;
  final bool isFavorite;
  final int repetitionCount;
  final DateTime? learnedAt;

  UserPhrasebook({
    required this.userId,
    required this.phraseId,
    this.isFavorite = false,
    this.repetitionCount = 0,
    this.learnedAt,
  });

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'phrase_id': phraseId,
    'is_favorite': isFavorite ? 1 : 0,
    'repetition_count': repetitionCount,
    'learned_at': learnedAt?.toIso8601String(),
  };

  factory UserPhrasebook.fromMap(Map<String, dynamic> map) => UserPhrasebook(
    userId: map['user_id'],
    phraseId: map['phrase_id'],
    isFavorite: map['is_favorite'] == 1,
    repetitionCount: map['repetition_count'] ?? 0,
    learnedAt: map['learned_at'] != null ? DateTime.parse(map['learned_at']) : null,
  );
}

class UserProgress {
  final int? id;
  final int userId;
  final int? taskId;
  final int? phraseId;
  final int? riddleId;
  final String sourceContext;
  final bool isCompleted;
  final int attemptsCount;
  final int score;
  final DateTime lastAttempt;

  UserProgress({
    this.id,
    required this.userId,
    this.taskId,
    this.phraseId,
    this.riddleId,
    required this.sourceContext,
    this.isCompleted = false,
    this.attemptsCount = 0,
    this.score = 0,
    DateTime? lastAttempt,
  }) : lastAttempt = lastAttempt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'task_id': taskId,
    'phrase_id': phraseId,
    'riddle_id': riddleId,
    'source_context': sourceContext,
    'is_completed': isCompleted ? 1 : 0,
    'attempts_count': attemptsCount,
    'score': score,
    'last_attempt': lastAttempt.toIso8601String(),
  };

  factory UserProgress.fromMap(Map<String, dynamic> map) => UserProgress(
    id: map['id'],
    userId: map['user_id'],
    taskId: map['task_id'],
    phraseId: map['phrase_id'],
    riddleId: map['riddle_id'],
    sourceContext: map['source_context'],
    isCompleted: map['is_completed'] == 1,
    attemptsCount: map['attempts_count'] ?? 0,
    score: map['score'] ?? 0,
    lastAttempt: DateTime.parse(map['last_attempt']),
  );
}