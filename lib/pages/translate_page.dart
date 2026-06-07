import 'dart:async';
import 'dart:convert';
import 'package:Mansi_Translator/services/tts_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../models/translation_entities.dart';
import '../../services/app_database.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/custom_buttons.dart';
import '../../widgets/mansi_keyboard.dart';

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
  bool _isTranslating = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_keyboardListener);
    TtsAudioPlayer.init();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_keyboardListener);
    _focusNode.dispose();
    controller1.dispose();
    controller2.dispose();
    super.dispose();
  }

  void _keyboardListener() {
    if (mounted) setState(() => _isKeyboardVisible = _focusNode.hasFocus);
  }

  Future<void> getTranslate(String text) async {
    if (text.trim().isEmpty) {
      if (mounted) setState(() { controller2.text = ''; _isTranslating = false; });
      return;
    }

    if (mounted) setState(() { _isTranslating = true; controller2.text = ''; });

    final int sourceLanguage = _isSwapped ? 2 : 1;
    final int targetLanguage = _isSwapped ? 1 : 2;
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
        final translatedText = responseData['translatedText'] ?? 'Ошибка: Перевод не найден';

        await _animateTextAppearance(translatedText);

        try {
          await AppDatabase.instance.addTranslation(Translation(
            sessionId: 1,
            originalText: text,
            translatedText: translatedText,
            sourceLanguage: _isSwapped ? 'mansi' : 'ru',
            targetLanguage: _isSwapped ? 'ru' : 'mansi',
            createdAt: DateTime.now(),
          ));
        } catch (dbError) {
          debugPrint('⚠️ Ошибка сохранения истории: $dbError');
        }
      } else {
        if (mounted) {
          setState(() {
            controller2.text = 'Ошибка при запросе данных (код ${response.statusCode})';
            _isTranslating = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() {
        controller2.text = 'Ошибка соединения с сервером';
        _isTranslating = false;
      });
      debugPrint('🌐 Network error: $e');
    }
  }

  Future<void> _animateTextAppearance(String fullText) async {
    if (!mounted) return;
    setState(() { controller2.text = ''; _isTranslating = true; });
    for (int i = 0; i <= fullText.length; i++) {
      await Future.delayed(const Duration(milliseconds: 15));
      if (mounted) setState(() => controller2.text = fullText.substring(0, i));
    }
    if (mounted) setState(() => _isTranslating = false);
  }

  void swapLanguages() {
    setState(() {
      _isSwapped = !_isSwapped;
      String temp = text1; text1 = text2; text2 = temp;
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
        leading: Padding(padding: const EdgeInsets.all(8.0), child: Image.asset("assets/images/logo.png")),
        title: LayoutBuilder(
          builder: (context, constraints) => Text(
            "Переводчик",
            style: TextStyle(fontSize: constraints.maxWidth > 600 ? 24.0 : 20.0, fontWeight: FontWeight.normal),
          ),
        ),
        backgroundColor: const Color(0xFF0A4B47),
        foregroundColor: Colors.white,
        actions: [
          MenuButton(onPressed: _openMenu)
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(padding: const EdgeInsets.all(16), child: Text(text1, style: const TextStyle(fontSize: 20))),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A4B47), shape: const CircleBorder(), padding: const EdgeInsets.all(12)),
                    onPressed: swapLanguages,
                    child: const Icon(Icons.swap_horiz, color: Colors.white, size: 30),
                  ),
                  Container(padding: const EdgeInsets.all(8), child: Text(text2, style: const TextStyle(fontSize: 20, color: Colors.black))),
                ]),
                const SizedBox(height: 10),
                Container(
                  margin: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    _buildInputField(controller1, isInput: true),
                    const SizedBox(height: 20),
                    _buildOutputField(),
                  ]),
                ),
              ],
            ),
          ),
          if (_isMansiLanguage && _isKeyboardVisible)
            MansiKeyboard(
              onTextInput: (text) {
                controller1.text += text;
                _onTextChanged(controller1.text);
              },
            ),
        ],
      ),
      endDrawer: const AppDrawer(activeSection: DrawerActiveSection.translator),
    );
  }

  Widget _buildInputField(TextEditingController controller, {required bool isInput}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black)),
      child: Stack(children: [
        TextField(
          focusNode: isInput ? _focusNode : null,
          controller: controller,
          maxLines: 10,
          onChanged: isInput ? _onTextChanged : null,
          readOnly: !isInput,
          decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(16)),
        ),
        Positioned(
          bottom: 8, right: 8,
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: IconButton(
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
              icon: const Icon(Icons.content_copy, size: 30, color: Color(0xFF0A4B47)),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: controller.text));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Текст скопирован')));
              },
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildOutputField() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black)),
      child: Stack(children: [
        TextField(controller: controller2, maxLines: 10, readOnly: true, decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(16))),
        if (_isTranslating)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              child: LinearProgressIndicator(
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0A4B47)),
                minHeight: 6,
              ),
            ),
          ),
        Positioned(
          bottom: 8, right: 8,
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              TtsSpeechButton(
                text: controller2.text,
                iconColor: const Color(0xFF0A4B47),
                iconSize: 30,
                onPlayStart: () => debugPrint('🔊 Начало воспроизведения'),
                onPlayComplete: () => debugPrint('✅ Воспроизведение завершено'),
                onError: () => debugPrint('❌ Ошибка TTS'),
              ),
              const SizedBox(width: 8),
              IconButton(
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                icon: const Icon(Icons.content_copy, size: 30, color: Color(0xFF0A4B47)),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: controller2.text));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Текст скопирован')));
                },
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}