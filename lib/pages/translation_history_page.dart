import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
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
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isClearing = false;
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy HH:mm');

  Future<void> _clearHistory(BuildContext context) async {
    if (!mounted) return;
    setState(() => _isClearing = true);

    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Подтверждение'),
          content: const Text('Вы уверены, что хотите очистить всю историю переводов?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Очистить', style: TextStyle(color: Colors.red))),
          ],
        ),
      );

      if (confirm == true) {
        await AppDatabase().clearTranslationHistory();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('История переводов очищена')),
          );
          setState(() {});
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при очистке истории: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  Future<void> _removeDuplicates(BuildContext context) async {
    if (!mounted) return;
    setState(() => _isClearing = true);

    try {
      final removedCount = await AppDatabase().removeDuplicateTranslations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Удалено $removedCount дубликатов')),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при удалении дубликатов: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  Future<void> _exportAllData(BuildContext context) async {
    if (!mounted) return;
    setState(() => _isExporting = true);

    try {
      final exportResult = await AppDatabase().exportAllData();
      final file = exportResult as File;
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Экспорт истории переводов',
        fileName: 'translation_history_${DateTime.now().millisecondsSinceEpoch}.json',
      );

      if (savePath != null) {
        await file.copy(savePath);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Данные успешно экспортированы')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка экспорта: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _importAllData(BuildContext context) async {
    if (!mounted) return;
    setState(() => _isImporting = true);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        String fileContent;
        if (kIsWeb) {
          fileContent = utf8.decode(result.files.first.bytes!);
        } else {
          final file = File(result.files.first.path!);
          fileContent = await file.readAsString();
        }

        final Map<String, dynamic> jsonData = json.decode(fileContent);

        if (jsonData['version'] == 1 && jsonData['data'] != null) {
          final importedCount = await AppDatabase().importAllData(jsonData);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Успешно импортировано $importedCount записей')),
          );
          setState(() {});
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Неверный формат файла')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка импорта: $e')),
      );
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _selectDateTime(BuildContext context, bool isStart) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate ?? DateTime.now() : _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: isStart ? _startTime ?? TimeOfDay.now() : _endTime ?? TimeOfDay.now(),
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
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset("assets/images/logo.png"),
        ),
        title: LayoutBuilder(
          builder: (context, constraints) {
            final fontSize = constraints.maxWidth > 600 ? 24.0 : 20.0;
            return Text(
              "История переводов",
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.normal),
            );
          },
        ),
        backgroundColor: const Color(0xFF0A4B47),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white, size: 30),
            onPressed: () => Scaffold.of(context).openEndDrawer(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDateTime(context, true),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today, size: 16),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _startDate != null ? _dateFormat.format(_startDate!) : 'Начало',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDateTime(context, false),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today, size: 16),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _endDate != null ? _dateFormat.format(_endDate!) : 'Конец',
                                  style: const TextStyle(fontSize: 12),
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
                    labelText: 'Поиск по тексту',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                          _searchController.clear();
                        });
                      },
                    )
                        : null,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: [
                    ActionButton(
                      onPressed: () => _exportAllData(context),
                      isLoading: _isExporting,
                      text: 'Экспорт',
                      color: const Color(0xFF0A4B47),
                      icon: Icons.upload,
                    ),
                    ActionButton(
                      onPressed: () => _importAllData(context),
                      isLoading: _isImporting,
                      text: 'Импорт',
                      color: const Color(0xFF0A4B47),
                      icon: Icons.download,
                    ),
                    ActionButton(
                      onPressed: () => _removeDuplicates(context),
                      isLoading: _isClearing,
                      text: 'Дубликаты',
                      color: Colors.orange,
                      icon: Icons.clean_hands,
                    ),
                    ActionButton(
                      onPressed: () => _clearHistory(context),
                      isLoading: _isClearing,
                      text: 'Очистить',
                      color: Colors.red,
                      icon: Icons.delete,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: AppDatabase().getTranslationHistory(
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
                    final dateTime = DateTime.parse(item['timestamp']);
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(item['original_text'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['translated_text'] ?? ''),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.schedule, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(_dateFormat.format(dateTime), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                const Spacer(),
                                Text(item['direction'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
      endDrawer: _buildDrawer(context),
    );
  }

  Widget _buildSmallActionButton({
    required VoidCallback onPressed,
    required bool isLoading,
    required String text,
    required Color color,
  }) {
    return SizedBox(
      height: 36,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: isLoading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(text, style: const TextStyle(fontSize: 12, color: Colors.white)),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Container(
        padding: const EdgeInsets.only(top: 40),
        decoration: const BoxDecoration(color: Color(0xFFE7E4DF)),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ListTile(
              title: const Text('Переводчик', style: TextStyle(fontSize: 20, color: Colors.black)),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TranslatePage())),
            ),
            ListTile(
              title: const Text('Обучение', style: TextStyle(fontSize: 20, color: Colors.black)),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MainMenuPage())),
            ),
            ListTile(
              title: const Text('История переводов', style: TextStyle(fontSize: 20, color: Color(0xFF0A4B47))),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}