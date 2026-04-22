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

  // ПРАВИЛЬНЫЙ endpoint из документации!
  static const String ttsEndpoint = "/tts";  // ← ВАЖНО! Не /api/tts/synthesize

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

  Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'audio/wav, audio/mpeg, */*',
    };
    if (_sessionCookie != null && _sessionCookie!.isNotEmpty) {
      headers['Cookie'] = _sessionCookie!;
    }
    return headers;
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
      final url = Uri.parse('$baseUrl$ttsEndpoint');

      final Map<String, dynamic> requestBody = {
        "text": text,
        "voice_name": voiceName,
        "settings": {
          "speed": speed.clamp(0.5, 2.0),
          "nfe_step": nfeStep.clamp(1, 100),
          "cfg_strength": cfgStrength.clamp(0.0, 10.0),
          "sway_sampling_coef": swaySamplingCoef,
          "cross_fade_duration": crossFadeDuration.clamp(0.0, 1.0),
        }
      };

      debugPrint('📡 TTS ЗАПРОС (POST $ttsEndpoint)');
      debugPrint('   URL: $url');
      debugPrint('   Текст: $text');
      debugPrint('   Голос: $voiceName');
      debugPrint('   Cookie: ${_sessionCookie != null ? "✅ есть" : "❌ нет"}');

      final response = await http.post(
        url,
        headers: _getHeaders(),
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 30));

      debugPrint('   Статус: ${response.statusCode}');
      debugPrint('   Content-Type: ${response.headers['content-type']}');

      if (response.statusCode == 200) {
        final contentType = response.headers['content-type'] ?? '';

        // Проверяем, что это аудио (WAV начинается с RIFF)
        final isWav = response.bodyBytes.length > 12 &&
            response.bodyBytes[0] == 0x52 && // 'R'
            response.bodyBytes[1] == 0x49 && // 'I'
            response.bodyBytes[2] == 0x46 && // 'F'
            response.bodyBytes[3] == 0x46;   // 'F'

        if (contentType.contains('audio') || isWav) {
          debugPrint('   ✅ АУДИО ПОЛУЧЕНО! Размер: ${response.bodyBytes.length} байт');
          return response.bodyBytes;
        } else {
          debugPrint('   ⚠️ Получен не аудиофайл, тип: $contentType');
          debugPrint('   Первые 200 байт: ${response.bodyBytes.length > 200 ? response.bodyBytes.sublist(0, 200) : response.bodyBytes}');
          return null;
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('   ❌ Ошибка авторизации! Cookie недействителен.');
        return null;
      } else {
        debugPrint('   ❌ Ошибка ${response.statusCode}: ${response.body}');
        return null;
      }

    } catch (e) {
      debugPrint('   ❌ Исключение: $e');
      return null;
    }
  }
}

/// Модель голоса
class TtsVoiceModel {
  final String name;
  final String description;

  TtsVoiceModel({
    required this.name,
    required this.description,
  });
}

/// Менеджер аудиоплеера
class TtsAudioPlayer {
  static final AudioPlayer _player = AudioPlayer();
  static bool _isPlaying = false;
  static String? _currentText;

  static Future<void> init() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration.speech());
      debugPrint('🎵 Аудиосессия инициализирована');
    } catch (e) {
      debugPrint('Ошибка инициализации аудиосессии: $e');
    }
  }

  static Future<void> play(Uint8List audioBytes, {String? text}) async {
    try {
      await stop();
      _currentText = text;

      final tempDir = await getTemporaryDirectory();
      final tempFile = await File('${tempDir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.wav')
          .writeAsBytes(audioBytes);

      final source = AudioSource.file(tempFile.path);
      await _player.setAudioSource(source);
      await _player.play();
      _isPlaying = true;
      debugPrint('🎵 Воспроизведение началось');

      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _isPlaying = false;
          _currentText = null;
          tempFile.delete();
          debugPrint('🎵 Воспроизведение завершено');
        }
      });
    } catch (e) {
      debugPrint('Ошибка воспроизведения: $e');
      _isPlaying = false;
      _currentText = null;
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
    _player.dispose();
  }
}

/// Кнопка озвучивания текста
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

  @override
  void initState() {
    super.initState();
    _checkPlaybackStatus();
  }

  void _checkPlaybackStatus() {
    if (TtsAudioPlayer.isPlaying && TtsAudioPlayer.currentText == widget.text) {
      if (!_isPlaying) {
        setState(() => _isPlaying = true);
      }
    } else if (_isPlaying) {
      setState(() => _isPlaying = false);
      widget.onPlayComplete?.call();
    }
    Future.delayed(const Duration(milliseconds: 500), _checkPlaybackStatus);
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

      if (audioBytes != null && mounted) {
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

/// Виджет настроек голоса
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