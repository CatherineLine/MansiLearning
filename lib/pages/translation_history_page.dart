import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/app_database.dart';
import '../widgets/app_drawer.dart';
import '../widgets/custom_buttons.dart';

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

  // Способ 2: Экспорт в видимую папку Downloads (с адаптивным дизайном)
  Future<void> _exportToDocuments(BuildContext context) async {
    if (!mounted) return;
    setState(() => _isExporting = true);

    try {
      final exportData = await AppDatabase.instance.exportAllData();
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      if (jsonString.isEmpty) {
        throw Exception('Нет данных для экспорта');
      }

      final now = DateTime.now();
      final fileName = 'mansi_backup_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.json';

      Directory targetDir;
      try {
        targetDir = Directory('/storage/emulated/0/Download');
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
      } catch (_) {
        targetDir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      }

      final filePath = '${targetDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsString(jsonString);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xFFE7E4DF),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: const Color(0xFF0A4B47)),
                const SizedBox(width: 8),
                const Text('Файл сохранён!', style: TextStyle(color: Color(0xFF0A4B47))),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Путь к файлу:', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SelectableText(
                    filePath,
                    style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        filePath.contains('Download')
                            ? 'Файл находится в папке "Загрузки" вашего телефона.'
                            : 'Файл сохранён в папку Android/data/com.example.translearn/files/',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: filePath));
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(children: [Icon(Icons.check, color: Colors.white, size: 18), SizedBox(width: 8), Text('Путь скопирован')]),
                      backgroundColor: const Color(0xFF0A4B47),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Копировать путь'),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF0A4B47)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A4B47),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Text('Закрыть'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red[700]),
        );
      }
      debugPrint('Export error: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
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
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate ?? DateTime.now() : _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('ru', 'RU'),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF0A4B47),
              onPrimary: Colors.white,
              onSurface: const Color(0xFF0A4B47),
            ),
          ),
          child: Localizations.override(
            context: context,
            locale: const Locale('ru', 'RU'),
            child: child!,
          ),
        );
      },
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: isStart ? _startTime ?? TimeOfDay.now() : _endTime ?? TimeOfDay.now(),
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: const Color(0xFF0A4B47),
                onPrimary: Colors.white,
                onSurface: const Color(0xFF0A4B47),
              ),
            ),
            child: Localizations.override(
              context: context,
              locale: const Locale('ru', 'RU'),
              child: child!,
            ),
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          final combinedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          if (isStart) {
            _startDate = combinedDateTime;
            _startTime = pickedTime;
          } else {
            _endDate = combinedDateTime;
            _endTime = pickedTime;
          }
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
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDateTime(context, true),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7E4DF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF0A4B47), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today, size: 20, color: Color(0xFF0A4B47)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _startDate != null
                                    ? _dateFormat.format(_startDate!)
                                    : 'Начало',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF0A4B47),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDateTime(context, false),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7E4DF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF0A4B47), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.event, size: 20, color: Color(0xFF0A4B47)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _endDate != null
                                    ? _dateFormat.format(_endDate!)
                                    : 'Конец',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF0A4B47),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Поиск перевода',
                  labelStyle: const TextStyle(color: Color(0xFF0A4B47)),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF0A4B47)),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Color(0xFF0A4B47)),
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Color(0xFF0A4B47)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Color(0xFF0A4B47), width: 2),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear, color: Color(0xFF0A4B47)),
                    onPressed: () {
                      setState(() { _searchQuery = ''; _searchController.clear(); });
                    },
                  )
                      : null,
                ),
                onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ActionButton(
                    onPressed: (_isExporting ? null : () => _exportToDocuments(context)) ?? () {},
                    isLoading: false,
                    text: 'Экспорт',
                    color: const Color(0xFF0A4B47),
                    icon: Icons.folder,
                  ),
                  ActionButton(
                    onPressed: (_isImporting ? null : () => _importAllData(context)) ?? () {},
                    isLoading: _isImporting,
                    text: 'Импорт',
                    color: const Color(0xFF0A4B47),
                    icon: Icons.download,
                  ),
                  ActionButton(
                    onPressed: (_isClearing ? null : () => _removeDuplicates(context)) ?? () {},
                    isLoading: _isClearing,
                    text: 'Дубликаты',
                    color: Colors.orange,
                    icon: Icons.clean_hands,
                  ),
                  ActionButton(
                    onPressed: (_isClearing ? null : () => _clearHistory(context)) ?? () {},
                    isLoading: _isClearing,
                    text: 'Очистить',
                    color: Colors.red,
                    icon: Icons.delete,
                  ),
                ],
              ),
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
                    final createdAtStr = item['created_at'] as String?;
                    final originalText = item['source_text'] as String? ?? '';
                    final translatedText = item['target_text'] as String? ?? '';
                    final sLang = item['source_lang'] as String? ?? 'ru';
                    final tLang = item['target_lang'] as String? ?? 'mansi';

                    DateTime? parsedDate;
                    if (createdAtStr != null && createdAtStr.isNotEmpty) {
                      try {
                        parsedDate = DateTime.parse(createdAtStr);
                      } catch (_) {}
                    }
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(originalText, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(translatedText),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.schedule, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  parsedDate != null ? _dateFormat.format(parsedDate) : 'Нет даты',
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
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
      endDrawer: const AppDrawer(activeSection: DrawerActiveSection.history),
    );
  }
}