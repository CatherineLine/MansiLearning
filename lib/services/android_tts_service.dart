import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class AndroidTTSService {
  static final FlutterTts _flutterTts = FlutterTts();
  static bool _isInitialized = false;
  static bool _isSpeaking = false;
  static bool _isInitializing = false;
  static final List<Function> _pendingSpeaks = [];

  static final List<Map<String, String>> availableLanguages = [
    {'code': 'ru-RU', 'name': 'Русский'},
    {'code': 'en-US', 'name': 'English (US)'},
    {'code': 'en-GB', 'name': 'English (UK)'},
  ];

  static String _currentLanguage = 'ru-RU';
  static double _speechRate = 0.5;
  static double _speechPitch = 1.0;

  static Future<void> init() async {
    if (_isInitialized) {
      debugPrint('TTS already initialized');
      return;
    }

    if (_isInitializing) {
      debugPrint('TTS initialization in progress, waiting...');
      return;
    }

    _isInitializing = true;
    debugPrint('Initializing TTS...');

    try {
      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
        debugPrint('TTS: Started speaking');
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        debugPrint('TTS: Completed speaking');
      });

      _flutterTts.setCancelHandler(() {
        _isSpeaking = false;
        debugPrint('TTS: Cancelled');
      });

      _flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
        debugPrint('TTS Error: $msg');
      });

      final languages = await _flutterTts.getLanguages;
      debugPrint('Available languages: $languages');

      final result = await _flutterTts.setLanguage(_currentLanguage);
      debugPrint('Set language $_currentLanguage result: $result');

      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.setPitch(_speechPitch);

      _isInitialized = true;
      _isInitializing = false;
      debugPrint('Android TTS initialized successfully');

      // Обрабатываем накопленные запросы
      for (var speak in _pendingSpeaks) {
        speak();
      }
      _pendingSpeaks.clear();

    } catch (e) {
      debugPrint('Error initializing TTS: $e');
      _isInitializing = false;
    }
  }

  static Future<bool> isAvailable() async {
    try {
      final languages = await _flutterTts.getLanguages;
      return languages != null && languages.isNotEmpty;
    } catch (e) {
      debugPrint('TTS not available: $e');
      return false;
    }
  }

  static Future<void> setLanguage(String languageCode) async {
    _currentLanguage = languageCode;
    if (_isInitialized) {
      final result = await _flutterTts.setLanguage(languageCode);
      debugPrint('Language set to: $languageCode, result: $result');
    }
  }

  static Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.0, 1.0);
    if (_isInitialized) {
      await _flutterTts.setSpeechRate(_speechRate);
      debugPrint('Speech rate set to: $_speechRate');
    }
  }

  static Future<void> setPitch(double pitch) async {
    _speechPitch = pitch.clamp(0.5, 2.0);
    if (_isInitialized) {
      await _flutterTts.setPitch(_speechPitch);
      debugPrint('Pitch set to: $_speechPitch');
    }
  }

  static Future<void> speak(String text) async {
    debugPrint('=== SPEAK CALLED ===');
    debugPrint('Text to speak: "$text"');
    debugPrint('Text length: ${text.length}');

    if (text.trim().isEmpty) {
      debugPrint('Text is empty, cannot speak');
      return;
    }

    // Если ещё не инициализирован, добавляем в очередь
    if (!_isInitialized) {
      debugPrint('TTS not initialized, adding to queue...');
      _pendingSpeaks.add(() => speak(text));
      await init();
      return;
    }

    try {
      await stop();
      final result = await _flutterTts.speak(text);
      debugPrint('Speak result: $result (1 = успех, 0 = ошибка)');
      if (result == 1) {
        _isSpeaking = true;
        debugPrint('✅ Speaking started successfully');
        // Добавьте это:
        debugPrint('🔊 Если звука нет, проверьте:');
        debugPrint('   1. Громкость телефона');
        debugPrint('   2. Настройки TTS в телефоне');
        debugPrint('   3. Установлен ли русский голос');
      } else {
        debugPrint('❌ Failed to start speaking, result code: $result');
      }
    } catch (e) {
      debugPrint('Error speaking: $e');
    }
  }

  static Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _isSpeaking = false;
      debugPrint('Stopped speaking');
    } catch (e) {
      debugPrint('Error stopping: $e');
    }
  }

  static bool get isSpeaking => _isSpeaking;
  static String get currentLanguage => _currentLanguage;
  static double get speechRate => _speechRate;
  static double get speechPitch => _speechPitch;

  static Future<void> dispose() async {
    try {
      await _flutterTts.stop();
      _isInitialized = false;
      _isSpeaking = false;
      _pendingSpeaks.clear();
      debugPrint('TTS disposed');
    } catch (e) {
      debugPrint('Error disposing TTS: $e');
    }
  }
}


/// Виджет настроек Android TTS
class AndroidTTSSettingsSheet extends StatefulWidget {
  final String selectedLanguage;
  final double speechRate;
  final double speechPitch;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<double> onRateChanged;
  final ValueChanged<double> onPitchChanged;

  const AndroidTTSSettingsSheet({
    super.key,
    required this.selectedLanguage,
    required this.speechRate,
    required this.speechPitch,
    required this.onLanguageChanged,
    required this.onRateChanged,
    required this.onPitchChanged,
  });

  @override
  State<AndroidTTSSettingsSheet> createState() => _AndroidTTSSettingsSheetState();
}

class _AndroidTTSSettingsSheetState extends State<AndroidTTSSettingsSheet> {
  late String _tempLanguage;
  late double _tempRate;
  late double _tempPitch;

  @override
  void initState() {
    super.initState();
    _tempLanguage = widget.selectedLanguage;
    _tempRate = widget.speechRate;
    _tempPitch = widget.speechPitch;
  }

  void _applySettings() {
    widget.onLanguageChanged(_tempLanguage);
    widget.onRateChanged(_tempRate);
    widget.onPitchChanged(_tempPitch);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Настройки голоса (Android TTS)',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          const Text('Выберите язык:', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _tempLanguage,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12),
            ),
            items: AndroidTTSService.availableLanguages.map((lang) {
              return DropdownMenuItem(
                value: lang['code'],
                child: Text(lang['name']!),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _tempLanguage = value;
                });
              }
            },
          ),

          const SizedBox(height: 16),
          Text('Скорость речи: ${(_tempRate * 100).toInt()}%',
              style: const TextStyle(fontSize: 16)),
          Slider(
            value: _tempRate,
            min: 0.0,
            max: 1.0,
            divisions: 10,
            label: '${(_tempRate * 100).toInt()}%',
            onChanged: (value) {
              setState(() {
                _tempRate = value;
              });
            },
          ),

          const SizedBox(height: 16),
          Text('Высота тона: ${(_tempPitch).toStringAsFixed(1)}',
              style: const TextStyle(fontSize: 16)),
          Slider(
            value: _tempPitch,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            label: _tempPitch.toStringAsFixed(1),
            onChanged: (value) {
              setState(() {
                _tempPitch = value;
              });
            },
          ),

          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Отмена'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _applySettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A4B47),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
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

/// Кнопка озвучивания с использованием Android TTS
class AndroidTextToSpeechButton extends StatefulWidget {
  final String text;
  final Color? iconColor;
  final double iconSize;
  final VoidCallback? onPlayStart;
  final VoidCallback? onPlayComplete;
  final VoidCallback? onError;

  const AndroidTextToSpeechButton({
    super.key,
    required this.text,
    this.iconColor,
    this.iconSize = 30,
    this.onPlayStart,
    this.onPlayComplete,
    this.onError,
  });

  @override
  State<AndroidTextToSpeechButton> createState() => _AndroidTextToSpeechButtonState();
}

class _AndroidTextToSpeechButtonState extends State<AndroidTextToSpeechButton> {
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _checkSpeakingStatus();
  }

  void _checkSpeakingStatus() {
    if (AndroidTTSService.isSpeaking && !_isSpeaking) {
      setState(() {
        _isSpeaking = true;
      });
      widget.onPlayStart?.call();
    } else if (!AndroidTTSService.isSpeaking && _isSpeaking) {
      setState(() {
        _isSpeaking = false;
      });
      widget.onPlayComplete?.call();
    }

    // Продолжаем проверять каждые 500 мс
    Future.delayed(const Duration(milliseconds: 500), _checkSpeakingStatus);
  }

  Future<void> _speakText() async {
    if (widget.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет текста для озвучивания')),
      );
      widget.onError?.call();
      return;
    }

    try {
      await AndroidTTSService.speak(widget.text);
      setState(() {
        _isSpeaking = true;
      });
      widget.onPlayStart?.call();
    } catch (e) {
      debugPrint('Error speaking: $e');
      widget.onError?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка озвучивания: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _stopSpeaking() async {
    await AndroidTTSService.stop();
    setState(() {
      _isSpeaking = false;
    });
    widget.onPlayComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_isSpeaking) {
      return IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: Icon(Icons.stop, size: widget.iconSize, color: Colors.red),
        onPressed: _stopSpeaking,
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
        onPressed: _speakText,
      );
    }
  }
}