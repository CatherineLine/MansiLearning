import 'package:flutter/material.dart';
import '../services/app_database.dart';
import '../widgets/mansi_keyboard.dart'; // Убедитесь, что путь верный

class WordEditPage extends StatefulWidget {
  final int moduleId;
  final Map<String, dynamic>? word;
  const WordEditPage({super.key, required this.moduleId, this.word});

  @override
  State<WordEditPage> createState() => _WordEditPageState();
}

class _WordEditPageState extends State<WordEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _mansiCtrl, _rusCtrl, _transCtrl, _noteCtrl;
  late final bool _isEdit;

  _WordEditPageState() : _isEdit = false; // Хак для инициализации, реальный флаг в initState

  @override
  void initState() {
    super.initState();
    _isEdit = widget.word != null;
    _mansiCtrl = TextEditingController(text: widget.word?['mansi_word'] ?? '');
    _rusCtrl = TextEditingController(text: widget.word?['russian_translation'] ?? '');
    _transCtrl = TextEditingController(text: widget.word?['transcription'] ?? '');
    _noteCtrl = TextEditingController(text: widget.word?['note'] ?? '');
  }

  @override
  void dispose() {
    _mansiCtrl.dispose(); _rusCtrl.dispose(); _transCtrl.dispose(); _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final data = {
      'module_id': widget.moduleId,
      'mansi_word': _mansiCtrl.text.trim(),
      'russian_translation': _rusCtrl.text.trim(),
      'transcription': _transCtrl.text.trim(),
      'note': _noteCtrl.text.trim(),
    };
    if (_isEdit) await AppDatabase.instance.updatePracticeWord(widget.word!['id'], data);
    else await AppDatabase.instance.addPracticeWord(data);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Редактировать слово' : 'Новое слово'), backgroundColor: const Color(0xFF0A4B47), foregroundColor: Colors.white, actions: [IconButton(icon: const Icon(Icons.save), onPressed: _save)]),
      body: Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(16), children: [
        TextFormField(controller: _mansiCtrl, decoration: const InputDecoration(labelText: 'Мансийское слово *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.text_fields)),
            validator: (v) => v == null || v.isEmpty ? 'Обязательное поле' : null),
        const SizedBox(height: 12),
        // ✅ Мансийская клавиатура
        MansiKeyboard(
          onTextInput: (char) {
            final val = _mansiCtrl.text;
            _mansiCtrl.text = val + char;
            _mansiCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _mansiCtrl.text.length));
          },
          onBackspace: () {
            if (_mansiCtrl.text.isNotEmpty) {
              _mansiCtrl.text = _mansiCtrl.text.substring(0, _mansiCtrl.text.length - 1);
              _mansiCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _mansiCtrl.text.length));
            }
          },
        ),
        const SizedBox(height: 16),
        TextFormField(controller: _rusCtrl, decoration: const InputDecoration(labelText: 'Русский перевод', border: OutlineInputBorder(), prefixIcon: Icon(Icons.translate))),
        const SizedBox(height: 12),
        TextFormField(controller: _transCtrl, decoration: const InputDecoration(labelText: 'Транскрипция', border: OutlineInputBorder(), prefixIcon: Icon(Icons.mic)), keyboardType: TextInputType.text),
        const SizedBox(height: 12),
        TextFormField(controller: _noteCtrl, decoration: const InputDecoration(labelText: 'Примечание', border: OutlineInputBorder(), prefixIcon: Icon(Icons.note)), maxLines: 2),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.shade200)),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.amber),
              const SizedBox(width: 12),
              Expanded(child: Text('⚠️ Не все русские слова имеют мансийские аналоги. При некорректном переводе смените слово.', style: TextStyle(fontSize: 13, color: Colors.amber.shade900))),
            ])),
        const SizedBox(height: 24),
        ElevatedButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: Text(_isEdit ? 'Сохранить изменения' : 'Добавить слово'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A4B47), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48))),
      ])),
    );
  }
}