import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TtsApiService {
  static const String baseUrl = "https://ethnoportal.admhmao.ru";
  static const String ttsEndpoint = "/api/tts/synthesize";
  static String? _sessionCookie;

  static Future<void> setSessionCookie(String cookie) async {
    _sessionCookie = cookie;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_cookie', cookie);
    debugPrint('✅ Cookie сохранён');
  }

  static Future<void> loadSessionCookie() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionCookie = prefs.getString('session_cookie');
    if (_sessionCookie != null) {
      debugPrint('📦 Загружен сохранённый cookie');
    }
  }

  static Future<void> clearSessionCookie() async {
    _sessionCookie = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_cookie');
    debugPrint('🗑️ Cookie очищен');
  }

  Future<List<TtsVoiceModel>> getVoices() async {
    return [
      TtsVoiceModel(name: 'galina', description: 'Женский голос, Кондина Галина'),
      TtsVoiceModel(name: 'irina', description: 'Женский голос, Ирина'),
    ];
  }

  Future<Uint8List?> synthesize({
    required String text,
    String voiceName = 'irina',
    double speed = 1.0,
    int nfeStep = 32,
    double cfgStrength = 2.0,
    double swaySamplingCoef = -1.0,
    double crossFadeDuration = 0.05,
  }) async {
    if (text.trim().isEmpty) {
      debugPrint('❌ Текст не может быть пустым');
      return null;
    }
    try {
      final synthesizeUrl = Uri.parse('$baseUrl$ttsEndpoint');
      final Map<String, dynamic> requestBody = {
        "text": text,
        "voice_name": voiceName,
        "settings": {
          "speed": speed.clamp(0.5, 2.0),
          "nfeStep": nfeStep.clamp(1, 100),
          "cfgStrength": cfgStrength.clamp(0.0, 10.0),
          "swaySamplingCoef": swaySamplingCoef,
          "crossFadeDuration": crossFadeDuration.clamp(0.0, 1.0),
        }
      };

      debugPrint('📡 TTS ЗАПРОС: $text');
      final synthesizeResponse = await http.post(
        synthesizeUrl,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (_sessionCookie != null && _sessionCookie!.isNotEmpty) 'Cookie': _sessionCookie!,
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 60));

      if (synthesizeResponse.statusCode != 200) {
        debugPrint('❌ Ошибка синтеза (${synthesizeResponse.statusCode}): ${synthesizeResponse.body}');
        return null;
      }

      final Map<String, dynamic> metadata = json.decode(synthesizeResponse.body);
      final String? fileId = metadata['id']?.toString();
      if (fileId == null || fileId.isEmpty) {
        debugPrint('❌ В ответе нет поля "id". Ответ: $metadata');
        return null;
      }

      debugPrint('✅ Получен ID файла: $fileId');

      final fileUrl = Uri.parse('$baseUrl/api/files/$fileId');
      final fileResponse = await http.get(
        fileUrl,
        headers: {
          'Accept': 'audio/wav, */*',
          if (_sessionCookie != null && _sessionCookie!.isNotEmpty) 'Cookie': _sessionCookie!,
        },
      ).timeout(const Duration(seconds: 30));

      if (fileResponse.statusCode == 200) {
        debugPrint('✅ АУДИО ПОЛУЧЕНО: ${fileResponse.bodyBytes.length} байт');
        return fileResponse.bodyBytes;
      } else {
        debugPrint('❌ Ошибка скачивания: ${fileResponse.statusCode}');
        return null;
      }
    } catch (e, stack) {
      debugPrint('❌ Исключение: $e');
      debugPrint('Stack: $stack');
      return null;
    }
  }
}

class TtsVoiceModel {
  final String name;
  final String description;
  TtsVoiceModel({required this.name, required this.description});
}

/// ✅ Исправленный менеджер аудиоплеера
class TtsAudioPlayer {
  static final AudioPlayer _player = AudioPlayer();
  static bool _isPlaying = false;
  static String? _currentText;
  static StreamSubscription? _stateSubscription;
  static File? _currentTempFile;

  static Future<void> init() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration.speech());

      // ✅ Подписываемся ОДИН раз
      await _stateSubscription?.cancel();
      _stateSubscription = _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _isPlaying = false;
          _currentText = null;
          debugPrint('🎵 Воспроизведение завершено');
        }
      });

      debugPrint('🎵 Аудиосессия инициализирована');
    } catch (e) {
      debugPrint('Ошибка инициализации: $e');
    }
  }

  static Future<void> play(Uint8List audioBytes, {String? text}) async {
    try {
      await stop(); // ✅ Очищаем предыдущее воспроизведение

      _currentText = text;

      // ✅ Удаляем старый файл
      if (_currentTempFile != null) {
        try { await _currentTempFile!.delete(); } catch(e) {}
      }

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.wav');
      await tempFile.writeAsBytes(audioBytes);
      _currentTempFile = tempFile;

      await _player.setAudioSource(AudioSource.file(tempFile.path));
      await _player.play();
      _isPlaying = true;
      debugPrint('🎵 Воспроизведение началось');
    } catch (e) {
      debugPrint('Ошибка воспроизведения: $e');
      _isPlaying = false;
      _currentText = null;
      if (_currentTempFile != null) {
        try { await _currentTempFile!.delete(); } catch(e) {}
        _currentTempFile = null;
      }
    }
  }

  static Future<void> stop() async {
    try {
      await _player.stop();
      _isPlaying = false;
      _currentText = null;
    } catch (e) {
      debugPrint('Ошибка остановки: $e');
    }
  }

  static bool get isPlaying => _isPlaying;
  static String? get currentText => _currentText;

  static void dispose() {
    _stateSubscription?.cancel();
    _player.dispose();
    _isPlaying = false;
    _currentText = null;
    if (_currentTempFile != null) {
      try { _currentTempFile!.deleteSync(); } catch(e) {}
      _currentTempFile = null;
    }
  }
}

/// ✅ Исправленная кнопка озвучивания
class TtsSpeechButton extends StatefulWidget {
  final String text;
  final Color? iconColor;
  final double iconSize;
  final VoidCallback? onPlayStart;
  final VoidCallback? onPlayComplete;
  final VoidCallback? onError;

  const TtsSpeechButton({
    super.key,
    required this.text,
    this.iconColor,
    this.iconSize = 30,
    this.onPlayStart,
    this.onPlayComplete,
    this.onError,
  });

  @override
  State<TtsSpeechButton> createState() => _TtsSpeechButtonState();
}

class _TtsSpeechButtonState extends State<TtsSpeechButton> {
  final TtsApiService _ttsService = TtsApiService();
  bool _isSynthesizing = false;
  bool _isPlaying = false;
  Timer? _pollingTimer; // ✅ Таймер для безопасной отмены

  @override
  void initState() {
    super.initState();
    _checkPlaybackStatus();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel(); // ✅ Отменяем таймер при удалении виджета
    super.dispose();
  }

  void _checkPlaybackStatus() {
    if (!mounted) return;

    if (TtsAudioPlayer.isPlaying && TtsAudioPlayer.currentText == widget.text) {
      if (!_isPlaying) {
        setState(() => _isPlaying = true);
      }
    } else if (_isPlaying) {
      setState(() => _isPlaying = false);
      widget.onPlayComplete?.call();
    }

    // ✅ Сохраняем ссылку на таймер
    _pollingTimer = Timer(const Duration(milliseconds: 500), _checkPlaybackStatus);
  }

  Future<void> _speak() async {
    if (widget.text.trim().isEmpty) {
      _showMessage('Нет текста для озвучивания', isError: true);
      return;
    }

    setState(() => _isSynthesizing = true);
    widget.onPlayStart?.call();

    try {
      final audioBytes = await _ttsService.synthesize(text: widget.text);
      if (!mounted) return;

      if (audioBytes != null) {
        await TtsAudioPlayer.play(audioBytes, text: widget.text);
        if (mounted) {
          setState(() => _isPlaying = true);
          _showMessage('Воспроизведение началось', isError: false);
        }
      } else if (mounted) {
        _showMessage('Не удалось синтезировать речь', isError: true);
        widget.onError?.call();
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Ошибка: $e', isError: true);
      }
      widget.onError?.call();
    } finally {
      if (mounted) {
        setState(() => _isSynthesizing = false);
      }
    }
  }

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _stop() async {
    await TtsAudioPlayer.stop();
    if (mounted) {
      setState(() => _isPlaying = false);
    }
    widget.onPlayComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_isSynthesizing) {
      return SizedBox(
        width: widget.iconSize,
        height: widget.iconSize,
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (_isPlaying) {
      return IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: Icon(Icons.stop, size: widget.iconSize, color: Colors.red),
        onPressed: _stop,
        tooltip: 'Остановить',
      );
    } else {
      return IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: Icon(
          Icons.volume_up,
          size: widget.iconSize,
          color: widget.iconColor ?? const Color(0xFF0A4B47),
        ),
        onPressed: _speak,
        tooltip: 'Озвучить текст',
      );
    }
  }
}

class TtsVoiceSettingsSheet extends StatefulWidget {
  final String selectedVoice;
  final double speechSpeed;
  final ValueChanged<String> onVoiceChanged;
  final ValueChanged<double> onSpeedChanged;

  const TtsVoiceSettingsSheet({
    super.key,
    required this.selectedVoice,
    required this.speechSpeed,
    required this.onVoiceChanged,
    required this.onSpeedChanged,
  });

  @override
  State<TtsVoiceSettingsSheet> createState() => _TtsVoiceSettingsSheetState();
}

class _TtsVoiceSettingsSheetState extends State<TtsVoiceSettingsSheet> {
  final TtsApiService _ttsService = TtsApiService();
  List<TtsVoiceModel> _voices = [];
  bool _isLoading = true;
  String? _error;
  late String _tempSelectedVoice;
  late double _tempSpeechSpeed;

  @override
  void initState() {
    super.initState();
    _tempSelectedVoice = widget.selectedVoice;
    _tempSpeechSpeed = widget.speechSpeed;
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final voices = await _ttsService.getVoices();
      setState(() {
        _voices = voices;
        _isLoading = false;
        if (_voices.isNotEmpty && !_voices.any((v) => v.name == _tempSelectedVoice)) {
          _tempSelectedVoice = _voices.first.name;
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Не удалось загрузить голоса: $e';
        _isLoading = false;
      });
    }
  }

  void _applySettings() {
    widget.onVoiceChanged(_tempSelectedVoice);
    widget.onSpeedChanged(_tempSpeechSpeed);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Настройки сохранены'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Настройки голоса', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          const Text('Выберите голос:', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Column(
              children: [
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
                ElevatedButton(onPressed: _loadVoices, child: const Text('Повторить')),
              ],
            )
          else if (_voices.isEmpty)
              const Center(child: Text('Нет доступных голосов'))
            else
              DropdownButtonFormField<String>(
                value: _tempSelectedVoice,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
                items: _voices.map((voice) {
                  return DropdownMenuItem(
                    value: voice.name,
                    child: Text('${voice.description} (${voice.name})'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _tempSelectedVoice = value);
                },
              ),
          const SizedBox(height: 16),
          Text('Скорость речи: ${_tempSpeechSpeed.toStringAsFixed(1)}', style: const TextStyle(fontSize: 16)),
          Slider(
            value: _tempSpeechSpeed,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            label: _tempSpeechSpeed.toStringAsFixed(1),
            onChanged: (value) => setState(() => _tempSpeechSpeed = value),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, foregroundColor: Colors.white),
                  child: const Text('Отмена'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _applySettings,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A4B47), foregroundColor: Colors.white),
                  child: const Text('Применить'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}