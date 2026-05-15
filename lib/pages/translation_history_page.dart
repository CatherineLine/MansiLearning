import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../services/app_database.dart';
import '../widgets/custom_buttons.dart';
import 'translate_page.dart';
import 'main_menu_page.dart';

class TranslationHistoryPage extends StatefulWidget {
  const TranslationHistoryPage({super.key});
  @override
  State<TranslationHistoryPage> createState() => _TranslationHistoryPageState();
}

class _TranslationHistoryPageState extends State<TranslationHistoryPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isExporting = false, _isImporting = false, _isClearing = false;
  DateTime? _startDate, _endDate;
  TimeOfDay? _startTime, _endTime;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy HH:mm');

  Future<void> _clearHistory(BuildContext context) async {
    if (!mounted) return;
    setState(() => _isClearing = true);
    try {
      final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Подтверждение'), content: const Text('Очистить всю историю?'), actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Очистить', style: TextStyle(color: Colors.red))),
      ]));
      if (confirm == true) {
        await AppDatabase.instance.clearTranslationHistory();
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('История очищена'))); setState(() {}); }
      }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'))); }
    finally { if (mounted) setState(() => _isClearing = false); }
  }

  Future<void> _removeDuplicates(BuildContext context) async {
    if (!mounted) return;
    setState(() => _isClearing = true);
    try {
      await AppDatabase.instance.removeDuplicateTranslations();
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Дубликаты удалены'))); setState(() {}); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'))); }
    finally { if (mounted) setState(() => _isClearing = false); }
  }

  Future<void> _exportAllData(BuildContext context) async {
    if (!mounted) return;
    setState(() => _isExporting = true);
    try {
      final data = await AppDatabase.instance.exportAllData();
      final savePath = await FilePicker.platform.saveFile(dialogTitle: 'Экспорт', fileName: 'history_${DateTime.now().millisecondsSinceEpoch}.json');
      if (savePath != null) {
        await File(savePath).writeAsString(json.encode(data));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Экспорт завершён')));
      }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'))); }
    finally { if (mounted) setState(() => _isExporting = false); }
  }

  Future<void> _importAllData(BuildContext context) async {
    if (!mounted) return;
    setState(() => _isImporting = true);
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (result != null && result.files.isNotEmpty) {
        final content = kIsWeb ? utf8.decode(result.files.first.bytes!) : await File(result.files.first.path!).readAsString();
        await AppDatabase.instance.importAllData(json.decode(content));
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Импорт завершён'))); setState(() {}); }
      }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'))); }
    finally { if (mounted) setState(() => _isImporting = false); }
  }

  Future<void> _selectDateTime(BuildContext context, bool isStart) async {
    final date = await showDatePicker(context: context, initialDate: isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now()), firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (date != null) {
      final time = await showTimePicker(context: context, initialTime: isStart ? (_startTime ?? TimeOfDay.now()) : (_endTime ?? TimeOfDay.now()));
      if (time != null) {
        setState(() {
          final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
          if (isStart) { _startDate = combined; _startTime = time; } else { _endDate = combined; _endTime = time; }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: Padding(padding: const EdgeInsets.all(8.0), child: Image.asset("assets/images/logo.png")),
        title: LayoutBuilder(builder: (ctx, c) => Text("История переводов", style: TextStyle(fontSize: c.maxWidth > 600 ? 24.0 : 20.0))),
        backgroundColor: const Color(0xFF0A4B47),
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.menu),
        onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
        )],
      ),
      body: Column(
        children: [
          Padding(padding: const EdgeInsets.all(16.0), child: Column(
            children: [
              Row(children: [
                Expanded(child: InkWell(onTap: () => _selectDateTime(context, true), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.calendar_today, size: 16), const SizedBox(width: 4), Flexible(child: Text(_startDate != null ? _dateFormat.format(_startDate!) : 'Начало', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))])))),
                const SizedBox(width: 4),
                Expanded(child: InkWell(onTap: () => _selectDateTime(context, false), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.calendar_today, size: 16), const SizedBox(width: 4), Flexible(child: Text(_endDate != null ? _dateFormat.format(_endDate!) : 'Конец', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))])))),
              ]),
              const SizedBox(height: 16),
              TextField(controller: _searchController, decoration: InputDecoration(labelText: 'Поиск по тексту', prefixIcon: const Icon(Icons.search), border: const OutlineInputBorder(), suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { setState(() { _searchQuery = ''; _searchController.clear(); }); }) : null), onChanged: (v) => setState(() => _searchQuery = v.toLowerCase())),
              const SizedBox(height: 8),
              Wrap(spacing: 4, runSpacing: 4, alignment: WrapAlignment.center, children: [
                ActionButton(onPressed: () => _exportAllData(context), isLoading: _isExporting, text: 'Экспорт', color: const Color(0xFF0A4B47), icon: Icons.upload),
                ActionButton(onPressed: () => _importAllData(context), isLoading: _isImporting, text: 'Импорт', color: const Color(0xFF0A4B47), icon: Icons.download),
                ActionButton(onPressed: () => _removeDuplicates(context), isLoading: _isClearing, text: 'Дубликаты', color: Colors.orange, icon: Icons.clean_hands),
                ActionButton(onPressed: () => _clearHistory(context), isLoading: _isClearing, text: 'Очистить', color: Colors.red, icon: Icons.delete),
              ]),
            ],
          )),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: AppDatabase.instance.getTranslationHistory(
                startDate: _startDate,
                endDate: _endDate,
                searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('История переводов пуста'));
                }
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final item = snapshot.data![index];
                    final original = item['source_text'] as String? ?? '';
                    final translated = item['target_text'] as String? ?? '';
                    final sLang = item['source_lang'] as String? ?? 'ru';
                    final tLang = item['target_lang'] as String? ?? 'mansi';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(original, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(translated),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.schedule, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text('Нет даты', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                const Spacer(),
                                Text('$sLang → $tLang', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
        endDrawer: Drawer(
        child: Container(padding: const EdgeInsets.only(top: 40), decoration: const BoxDecoration(color: Color(0xFFE7E4DF)), child: ListView(padding: EdgeInsets.zero, children: [
          ListTile(title: const Text('Переводчик', style: TextStyle(fontSize: 20)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const TranslatePage()))),
          ListTile(title: const Text('Обучение', style: TextStyle(fontSize: 20, color: Color(0xFF0A4B47))), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => MainMenuPage()))),
          ListTile(title: const Text('История переводов', style: TextStyle(fontSize: 20, color: Color(0xFF0A4B47))), onTap: () {}),
        ])),
      ),
    );
  }
}