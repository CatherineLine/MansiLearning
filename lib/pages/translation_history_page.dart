import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../base_scafford.dart';
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
  bool _showOnlyFavorites = false;

  List<Map<String, dynamic>> _translations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTranslations();
  }

  Future<void> _loadTranslations() async {
    setState(() => _isLoading = true);
    try {
      final translations = await AppDatabase.instance.getTranslationHistory(
        startDate: _startDate,
        endDate: _endDate,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        onlyFavorites: _showOnlyFavorites,
      );
      setState(() {
        _translations = translations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Ошибка загрузки: $e');
    }
  }

  Future<void> _clearHistory(BuildContext context) async {
    if (!mounted) return;
    setState(() => _isClearing = true);
    try {
      final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
          title: const Text('Подтверждение'),
          content: const Text('Очистить всю историю?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Очистить', style: TextStyle(color: Colors.red))),
          ]
      ));
      if (confirm == true) {
        await AppDatabase.instance.clearTranslationHistory();
        await _loadTranslations();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('История очищена')));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  Future<void> _removeDuplicates(BuildContext context) async {
    if (!mounted) return;
    setState(() => _isClearing = true);
    try {
      await AppDatabase.instance.removeDuplicateTranslations();
      await _loadTranslations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Дубликаты удалены')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  Future<void> _exportToDocuments(BuildContext context) async {
    if (!mounted) return;
    setState(() => _isExporting = true);

    try {
      final exportData = await AppDatabase.instance.exportAllData();
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      final now = DateTime.now();
      final fileName = 'mansi_backup_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}.json';

      Directory? saveDir;
      if (Platform.isAndroid) {
        saveDir = Directory('/storage/emulated/0/Download/MansiTranslator');
        if (!await saveDir.exists()) {
          await saveDir.create(recursive: true);
        }
      } else {
        saveDir = await getApplicationDocumentsDirectory();
      }

      final saveFile = File('${saveDir.path}/$fileName');
      await saveFile.writeAsString(jsonString, encoding: utf8);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Файл сохранён: ${saveFile.path}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('Ошибка экспорта: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
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
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (result != null && result.files.isNotEmpty) {
        final content = kIsWeb ? utf8.decode(result.files.first.bytes!) : await File(result.files.first.path!).readAsString();
        await AppDatabase.instance.importAllData(json.decode(content));
        await _loadTranslations();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Импорт завершён')));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
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
        await _loadTranslations();
      }
    }
  }

  Future<void> _toggleFavorite(Map<String, dynamic> item, int index) async {
    final id = item['id'] as int;
    final currentStatus = (item['is_favorite'] == 1);
    final newStatus = !currentStatus;

    setState(() {
      final newList = List<Map<String, dynamic>>.from(_translations);
      newList[index] = Map<String, dynamic>.from(newList[index]);
      newList[index]['is_favorite'] = newStatus ? 1 : 0;
      _translations = newList;
    });

    try {
      await AppDatabase.instance.toggleFavoriteTranslation(id, newStatus);

      if (_showOnlyFavorites && !newStatus) {
        setState(() {
          _translations.removeAt(index);
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentStatus ? 'Удалено из избранного' : 'Добавлено в избранное'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      setState(() {
        final rollbackList = List<Map<String, dynamic>>.from(_translations);
        rollbackList[index] = Map<String, dynamic>.from(rollbackList[index]);
        rollbackList[index]['is_favorite'] = currentStatus ? 1 : 0;
        _translations = rollbackList;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _startTime = null;
      _endTime = null;
      _searchQuery = '';
      _searchController.clear();
      _showOnlyFavorites = false;
    });
    _loadTranslations();
  }

  void _toggleFavoriteFilter() {
    setState(() {
      _showOnlyFavorites = !_showOnlyFavorites;
    });
    _loadTranslations();
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      scaffoldKey: _scaffoldKey,
      appBar: AppBar(
        leading: Padding(padding: const EdgeInsets.all(8.0), child: Image.asset("assets/images/logo.png")),
        title: LayoutBuilder(builder: (ctx, c) => Text("История переводов", style: TextStyle(fontSize: c.maxWidth > 600 ? 24.0 : 20.0))),
        backgroundColor: const Color(0xFF0A4B47),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: const AppDrawer(activeSection: DrawerActiveSection.history),
      body: Column(
        children: [
          Padding(padding: const EdgeInsets.all(16.0), child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Поиск перевода',
                        hintStyle: const TextStyle(color: Colors.grey),
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
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.clear, color: Color(0xFF0A4B47)),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                            });
                            _loadTranslations();
                          },
                        )
                            : null,
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value.toLowerCase());
                        _loadTranslations();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 56,
                    width: 56,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF0A4B47),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      color: _showOnlyFavorites
                          ? const Color(0xFF0A4B47).withOpacity(0.15)
                          : Colors.transparent,
                    ),
                    child: IconButton(
                      icon: Icon(
                        _showOnlyFavorites ? Icons.star : Icons.star_border,
                        color: _showOnlyFavorites ? Colors.amber : const Color(0xFF0A4B47),
                        size: 28,
                      ),
                      onPressed: _toggleFavoriteFilter,
                      tooltip: _showOnlyFavorites
                          ? 'Показать всё'
                          : 'Показать только избранное',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                  if (_startDate != null || _endDate != null || _searchQuery.isNotEmpty || _showOnlyFavorites)
                    const SizedBox(width: 8),
                  if (_startDate != null || _endDate != null || _searchQuery.isNotEmpty || _showOnlyFavorites)
                    TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.clear, size: 18),
                      label: const Text('Сбросить'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF0A4B47),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _translations.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _showOnlyFavorites ? Icons.star_border : Icons.history,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _showOnlyFavorites
                        ? 'Нет избранных переводов\nДобавьте их через звёздочку'
                        : 'История переводов пуста',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _translations.length,
              itemBuilder: (context, index) {
                final item = _translations[index];
                final createdAtStr = item['created_at'] as String?;
                final originalText = item['source_text'] as String? ?? '';
                final translatedText = item['target_text'] as String? ?? '';
                final sLang = item['source_lang'] as String? ?? 'ru';
                final tLang = item['target_lang'] as String? ?? 'mansi';
                final isFavorite = (item['is_favorite'] == 1);

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
                    trailing: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.star_border,
                          size: 32,
                          color: const Color(0xFF0A4B47),
                        ),
                        IconButton(
                          icon: Icon(
                            isFavorite ? Icons.star : Icons.star_border,
                            size: 28,
                            color: isFavorite ? Colors.amber : const Color(0xFFE7E4DF),
                          ),
                          onPressed: () => _toggleFavorite(item, index),
                          tooltip: isFavorite ? 'Удалить из избранного' : 'Добавить в избранное',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}