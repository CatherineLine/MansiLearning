class MediaAsset {
  final int? id;
  final String filePath;
  final String mimeType;
  final int? durationSec;
  final String? checksum;

  MediaAsset({
    this.id,
    required this.filePath,
    required this.mimeType,
    this.durationSec,
    this.checksum,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'file_path': filePath,
      'mime_type': mimeType,
      'duration_sec': durationSec,
      'checksum': checksum,
    };
  }

  factory MediaAsset.fromMap(Map<String, dynamic> map) {
    return MediaAsset(
      id: map['id'],
      filePath: map['file_path'],
      mimeType: map['mime_type'],
      durationSec: map['duration_sec'],
      checksum: map['checksum'],
    );
  }
}