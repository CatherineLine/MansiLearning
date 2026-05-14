class TranslationSession {
  final int? id;
  final int userId;
  final String sessionType;
  final DateTime startedAt;
  final String status;

  TranslationSession({
    this.id,
    required this.userId,
    required this.sessionType,
    DateTime? startedAt,
    this.status = 'active',
  }) : startedAt = startedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'session_type': sessionType,
    'started_at': startedAt.toIso8601String(),
    'status': status,
  };

  factory TranslationSession.fromMap(Map<String, dynamic> map) => TranslationSession(
    id: map['id'],
    userId: map['user_id'],
    sessionType: map['session_type'],
    startedAt: DateTime.parse(map['started_at']),
    status: map['status'],
  );
}

class Translation {
  final int? id;
  final int sessionId;
  final String sourceText;
  final String targetText;
  final String sourceLang;
  final String targetLang;
  final bool isFavorite;

  Translation({
    this.id,
    required this.sessionId,
    required this.sourceText,
    required this.targetText,
    required this.sourceLang,
    required this.targetLang,
    this.isFavorite = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'session_id': sessionId,
    'source_text': sourceText,
    'target_text': targetText,
    'source_lang': sourceLang,
    'target_lang': targetLang,
    'is_favorite': isFavorite ? 1 : 0,
  };

  factory Translation.fromMap(Map<String, dynamic> map) => Translation(
    id: map['id'],
    sessionId: map['session_id'],
    sourceText: map['source_text'],
    targetText: map['target_text'],
    sourceLang: map['source_lang'],
    targetLang: map['target_lang'],
    isFavorite: map['is_favorite'] == 1,
  );
}

class Document {
  final int? id;
  final int sessionId;
  final String originalFilePath;
  final String? translatedFilePath;
  final String fileFormat;
  final String status;
  final DateTime uploadedAt;

  Document({
    this.id,
    required this.sessionId,
    required this.originalFilePath,
    this.translatedFilePath,
    required this.fileFormat,
    this.status = 'pending',
    DateTime? uploadedAt,
  }) : uploadedAt = uploadedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'session_id': sessionId,
    'original_file_path': originalFilePath,
    'translated_file_path': translatedFilePath,
    'file_format': fileFormat,
    'status': status,
    'uploaded_at': uploadedAt.toIso8601String(),
  };

  factory Document.fromMap(Map<String, dynamic> map) => Document(
    id: map['id'],
    sessionId: map['session_id'],
    originalFilePath: map['original_file_path'],
    translatedFilePath: map['translated_file_path'],
    fileFormat: map['file_format'],
    status: map['status'],
    uploadedAt: DateTime.parse(map['uploaded_at']),
  );
}