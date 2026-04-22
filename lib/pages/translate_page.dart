import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../services/app_database.dart';
import '../services/android_tts_service.dart';
import '../widgets/custom_buttons.dart';
import '../widgets/mansi_keyboard.dart';
import 'main_menu_page.dart';
import 'translation_history_page.dart';

class TranslatePage extends StatefulWidget {
  const TranslatePage({super.key});

  @override
  State<TranslatePage> createState() => _TranslatePageState();
}

class _TranslatePageState extends State<TranslatePage> {
  final String translateApiEndpoint = "https://ethnoportal.admhmao.ru/api/machine-translates/translate";
  final TextEditingController controller1 = TextEditingController();
  final TextEditingController controller2 = TextEditingController();
  Timer? _debounce;
  bool _isSwapped = false;
  bool _isMansiLanguage = false;
  bool _isKeyboardVisible = false;
  final FocusNode _focusNode = FocusNode();
  String text1 = 'Русский';
  String text2 = 'Мансийский';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _keyboardListener() {
    setState(() {
      _isKeyboardVisible = _focusNode.hasFocus;
    });
  }

  // TTS Settings
  String _selectedLanguage = 'ru-RU';
  double _speechRate = 0.5;
  double _speechPitch = 1.0;
  bool _isTranslating = false;  // Добавьте эту переменную

  @override
  void initState() {
    super.initState();
    AndroidTTSService.init();
    _focusNode.addListener(_keyboardListener);
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
    AndroidTTSService.dispose();
    super.dispose();
  }

  void _showVoiceSettings() {
    if (navigatorKey.currentContext == null) return;

    showModalBottomSheet(
      context: navigatorKey.currentContext!,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AndroidTTSSettingsSheet(
        selectedLanguage: _selectedLanguage,
        speechRate: _speechRate,
        speechPitch: _speechPitch,
        onLanguageChanged: (lang) {
          setState(() => _selectedLanguage = lang);
          AndroidTTSService.setLanguage(lang);
        },
        onRateChanged: (rate) {
          setState(() => _speechRate = rate);
          AndroidTTSService.setSpeechRate(rate);
        },
        onPitchChanged: (pitch) {
          setState(() => _speechPitch = pitch);
          AndroidTTSService.setPitch(pitch);
        },
      ),
    );
  }

  Future<void> getTranslate(String text) async {
    if (text.trim().isEmpty) {
      setState(() {
        controller2.text = '';
        _isTranslating = false;
      });
      return;
    }

    setState(() {
      _isTranslating = true;
      controller2.text = '';  // Очищаем поле перед новым переводом
    });

    final int sourceLanguage = _isSwapped ? 2 : 1;
    final int targetLanguage = _isSwapped ? 1 : 2;
    final String direction = '$sourceLanguage -> $targetLanguage';

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

        // Анимированное появление текста
        final translatedText = responseData['translatedText'] ?? 'Ошибка: Перевод не найден';
        await _animateTextAppearance(translatedText);

        await AppDatabase().addTranslation(
            text,
            controller2.text,
            DateTime.now().toIso8601String(),
            direction
        );
      } else {
        setState(() {
          controller2.text = 'Ошибка при запросе данных';
          _isTranslating = false;
        });
      }
    } catch (e) {
      setState(() {
        controller2.text = 'Ошибка при соединении с сервером';
        _isTranslating = false;
      });
    }
  }

  // Анимация появления текста с эффектом печати
  Future<void> _animateTextAppearance(String fullText) async {
    setState(() {
      controller2.text = '';
      _isTranslating = true;
    });

    // Эффект печати (появляется по буквам)
    for (int i = 0; i <= fullText.length; i++) {
      await Future.delayed(const Duration(milliseconds: 15));
      if (mounted) {
        setState(() {
          controller2.text = fullText.substring(0, i);
        });
      }
    }

    setState(() {
      _isTranslating = false;
    });
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

  void _openMenu() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset("assets/images/logo.png"),
        ),
        title: LayoutBuilder(
          builder: (context, constraints) {
            final fontSize = constraints.maxWidth > 600 ? 24.0 : 20.0;
            return Text(
              "Переводчик",
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.normal),
            );
          },
        ),
        backgroundColor: const Color(0xFF0A4B47),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_voice, color: Colors.white, size: 28),
            onPressed: _showVoiceSettings,
            tooltip: 'Настройки голоса',
          ),
          MenuButton(onPressed: _openMenu)
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
                      _buildInputField(controller1, isInput: true),
                      const SizedBox(height: 20),
                      _buildOutputField(),
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
      endDrawer: _buildDrawer(),
    );
  }

  Widget _buildInputField(TextEditingController controller, {required bool isInput}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black),
      ),
      child: Stack(
        children: [
          TextField(
            focusNode: isInput ? _focusNode : null,
            controller: controller,
            maxLines: 10,
            onChanged: isInput ? _onTextChanged : null,
            readOnly: !isInput,
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
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.content_copy, size: 30, color: Color(0xFF0A4B47)),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: controller.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Текст скопирован')),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputField() {
    return Container(
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
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
          // Полоска загрузки внизу поля
          if (_isTranslating)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0A4B47)),
              ),
            ),
          // Кнопки копирования и TTS (как были)
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
                  AndroidTextToSpeechButton(
                    text: controller2.text,
                    iconColor: const Color(0xFF0A4B47),
                    iconSize: 30,
                  ),
                  const SizedBox(width: 8),
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
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        padding: const EdgeInsets.only(top: 40),
        decoration: const BoxDecoration(color: Color(0xFFE7E4DF)),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ListTile(
              title: const Text('Переводчик', style: TextStyle(fontSize: 20, color: Color(0xFF0A4B47))),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const TranslatePage()));
              },
            ),
            ListTile(
              title: const Text('Обучение', style: TextStyle(fontSize: 20, color: Colors.black)),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => MainMenuPage()));
              },
            ),
            ListTile(
              title: const Text('История переводов', style: TextStyle(fontSize: 20, color: Colors.black)),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => TranslationHistoryPage()));
              },
            ),
          ],
        ),
      ),
    );
  }
}