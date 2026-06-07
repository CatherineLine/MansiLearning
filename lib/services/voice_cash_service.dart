import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'tts_api_service.dart';

class VoiceCacheService {
  static final VoiceCacheService _instance = VoiceCacheService._internal();
  factory VoiceCacheService() => _instance;
  VoiceCacheService._internal();

  Directory? _cacheDir;
  final TtsApiService _ttsService = TtsApiService();

  Future<void> init() async {
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${appDir.path}/voice_cache');
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
  }

  String _getHash(String text) {
    return md5.convert(utf8.encode(text)).toString();
  }

  Future<File?> getCachedAudio(String text) async {
    if (_cacheDir == null) await init();
    final hash = _getHash(text);
    final file = File('${_cacheDir!.path}/$hash.wav');
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  Future<void> cacheAudio(String text, Uint8List audioBytes) async {
    if (_cacheDir == null) await init();
    final hash = _getHash(text);
    final file = File('${_cacheDir!.path}/$hash.wav');
    await file.writeAsBytes(audioBytes);
    debugPrint('✅ Аудио кешировано: $text');
  }

  Future<Uint8List?> getOrSynthesize(String text) async {
    final cached = await getCachedAudio(text);
    if (cached != null) {
      debugPrint('📦 Аудио из кеша: $text');
      return await cached.readAsBytes();
    }

    debugPrint('🎙️ Синтезируем: $text');
    final audioBytes = await _ttsService.synthesize(text: text);
    if (audioBytes != null) {
      await cacheAudio(text, audioBytes);
    }
    return audioBytes;
  }

  Future<void> preloadPhrases(List<Map<String, dynamic>> phrases) async {
    for (var phrase in phrases) {
      final text = phrase['text_mansi'] as String?;
      if (text != null && text.isNotEmpty) {
        await getOrSynthesize(text);
      }
    }
    debugPrint('✅ Предзагрузка фраз завершена');
  }
}