import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../base_scafford.dart';
import '../services/app_database.dart';
import '../services/translation_service.dart';
import '../services/tts_api_service.dart';
import '../widgets/app_drawer.dart';

// ============================================================
// VoiceCacheService - кеширование аудио
// ============================================================
class VoiceCacheService {
  static final VoiceCacheService _instance = VoiceCacheService._internal();
  factory VoiceCacheService() => _instance;
  VoiceCacheService._internal();

  Directory? _cacheDir;
  final TtsApiService _ttsService = TtsApiService();

  Future<void> init() async {
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${appDir.path}/voice_cache');
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
  }

  String _getHash(String text) {
    return md5.convert(utf8.encode(text)).toString();
  }

  Future<File?> getCachedAudio(String text) async {
    if (_cacheDir == null) await init();
    final hash = _getHash(text);
    final file = File('${_cacheDir!.path}/$hash.wav');
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  Future<void> cacheAudio(String text, Uint8List audioBytes) async {
    if (_cacheDir == null) await init();
    final hash = _getHash(text);
    final file = File('${_cacheDir!.path}/$hash.wav');
    await file.writeAsBytes(audioBytes);
    debugPrint('✅ Аудио кешировано: $text');
  }

  Future<Uint8List?> getOrSynthesize(String text) async {
    final cached = await getCachedAudio(text);
    if (cached != null) {
      debugPrint('📦 Аудио из кеша: $text');
      return await cached.readAsBytes();
    }

    debugPrint('🎙️ Синтезируем: $text');
    final audioBytes = await _ttsService.synthesize(text: text);
    if (audioBytes != null) {
      await cacheAudio(text, audioBytes);
    }
    return audioBytes;
  }
}

// ============================================================
// Основная страница разговорника
// ============================================================
class PhrasebookPage extends StatefulWidget {
  const PhrasebookPage({super.key});

  @override
  State<PhrasebookPage> createState() => _PhrasebookPageState();
}

class _PhrasebookPageState extends State<PhrasebookPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TranslationService _translationService = TranslationService();
  final VoiceCacheService _voiceCache = VoiceCacheService();

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _allPhrases = [];
  List<Map<String, dynamic>> _currentPhrases = []; // Текущие отображаемые фразы

  Map<int, Set<int>> _favoritePhrases = {};

  int? _selectedCategoryId;
  bool _showAllPhrases = false;
  bool _isLoading = true;
  bool _isPreloading = false;
  int _userId = 1;

  String _searchQuery = '';
  bool _showOnlyFavorites = false;
  final TextEditingController _searchController = TextEditingController();

  final TextEditingController _newCategoryController = TextEditingController();
  final TextEditingController _newRussianPhraseController = TextEditingController();
  final TextEditingController _newMansiPhraseController = TextEditingController();
  int? _selectedCategoryForPhrase;

  bool _isTranslating = false;
  Set<String> _preloadedPhrases = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _voiceCache.init();
    TtsAudioPlayer.init();
  }

  @override
  void dispose() {
    _newCategoryController.dispose();
    _newRussianPhraseController.dispose();
    _newMansiPhraseController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await _loadCategories();
      await _loadAllPhrases();
      await _loadFavoritePhrases();

      if (_categories.isNotEmpty && _selectedCategoryId == null) {
        final firstNonUncategorized = _categories.firstWhere(
              (c) => c['name'] != 'Без категории',
          orElse: () => _categories.first,
        );
        _selectedCategoryId = firstNonUncategorized['id'];
        await _loadPhrasesForCategory(_selectedCategoryId!);
      }
    } catch (e) {
      debugPrint('Ошибка загрузки: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCategories() async {
    final categories = await AppDatabase.instance.getAllPhraseCategories();
    setState(() {
      _categories = categories;
    });
  }

  Future<void> _loadAllPhrases() async {
    final allPhrases = <Map<String, dynamic>>[];
    for (var category in _categories) {
      final phrases = await AppDatabase.instance.getPhrasesByCategory(category['id']);
      for (var phrase in phrases) {
        final newPhrase = Map<String, dynamic>.from(phrase);
        newPhrase['category_name'] = category['name'];
        newPhrase['category_id'] = category['id'];
        allPhrases.add(newPhrase);
      }
    }
    setState(() {
      _allPhrases = allPhrases;
    });
  }

  Future<void> _loadPhrasesForCategory(int categoryId) async {
    final phrases = await AppDatabase.instance.getPhrasesByCategory(categoryId);

    // Добавляем название категории к каждой фразе
    String categoryName = '';
    for (var c in _categories) {
      if (c['id'] == categoryId) {
        categoryName = c['name'] ?? '';
        break;
      }
    }

    final phrasesWithCategory = <Map<String, dynamic>>[];
    for (var p in phrases) {
      final newPhrase = Map<String, dynamic>.from(p);
      newPhrase['category_name'] = categoryName;
      newPhrase['category_id'] = categoryId;
      phrasesWithCategory.add(newPhrase);
    }

    setState(() {
      _currentPhrases = phrasesWithCategory;
    });

    await _preloadPhrasesForList(phrasesWithCategory);
  }

  Future<void> _loadAllPhrasesForDisplay() async {
    setState(() {
      _currentPhrases = List<Map<String, dynamic>>.from(_allPhrases);
    });
    await _preloadPhrasesForList(_currentPhrases);
  }

  Future<void> _preloadPhrasesForList(List<Map<String, dynamic>> phrases) async {
    final newPhrases = phrases.where((p) =>
    !_preloadedPhrases.contains(p['text_mansi'])
    ).toList();

    if (newPhrases.isEmpty) return;

    setState(() => _isPreloading = true);

    for (var phrase in newPhrases) {
      final text = phrase['text_mansi'] as String?;
      if (text != null && text.isNotEmpty) {
        await _voiceCache.getOrSynthesize(text);
        _preloadedPhrases.add(text);
      }
    }

    setState(() => _isPreloading = false);
  }

  Future<void> _loadFavoritePhrases() async {
    final favorites = await AppDatabase.instance.getFavoritePhrases(_userId);
    setState(() {
      _favoritePhrases.clear();
      for (var fav in favorites) {
        final categoryId = fav['category_id'] as int;
        final phraseId = fav['id'] as int;
        _favoritePhrases.putIfAbsent(categoryId, () => {}).add(phraseId);
      }
    });
  }

  List<Map<String, dynamic>> _getFilteredPhrases() {
    return _currentPhrases.where((phrase) {
      final matchesSearch = _searchQuery.isEmpty ||
          (phrase['text_mansi'] as String? ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (phrase['text_russian'] as String? ?? '').toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesFavorite = !_showOnlyFavorites ||
          (_favoritePhrases[phrase['category_id']]?.contains(phrase['id']) ?? false);

      return matchesSearch && matchesFavorite;
    }).toList();
  }

  Future<void> _toggleFavorite(int phraseId, int categoryId) async {
    final isFavorite = _favoritePhrases[categoryId]?.contains(phraseId) ?? false;
    await AppDatabase.instance.toggleFavoritePhrase(_userId, phraseId, !isFavorite);

    setState(() {
      if (!isFavorite) {
        _favoritePhrases.putIfAbsent(categoryId, () => {}).add(phraseId);
      } else {
        _favoritePhrases[categoryId]?.remove(phraseId);
        if (_favoritePhrases[categoryId]?.isEmpty == true) {
          _favoritePhrases.remove(categoryId);
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(!isFavorite ? 'Добавлено в избранное' : 'Удалено из избранного'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _deleteCategory(int categoryId, String categoryName) async {
    if (categoryName == 'Без категории') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нельзя удалить категорию "Без категории"')),
      );
      return;
    }

    final phrases = await AppDatabase.instance.getPhrasesByCategory(categoryId);
    if (phrases.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Сначала удалите все фразы из категории "${categoryName}"')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удаление категории'),
        content: Text('Вы уверены, что хотите удалить категорию "${categoryName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF0A4B47)),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AppDatabase.instance.deletePhraseCategory(categoryId);
      await _loadCategories();
      await _loadAllPhrases();

      if (_selectedCategoryId == categoryId) {
        if (_categories.isNotEmpty) {
          final firstNonUncategorized = _categories.firstWhere(
                (c) => c['name'] != 'Без категории',
            orElse: () => _categories.first,
          );
          _selectedCategoryId = firstNonUncategorized['id'];
          await _loadPhrasesForCategory(_selectedCategoryId!);
        } else {
          _selectedCategoryId = null;
          setState(() {
            _currentPhrases = [];
          });
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Категория "${categoryName}" удалена')),
      );
    }
  }

  Future<void> _deletePhrase(Map<String, dynamic> phrase, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление фразы'),
        content: const Text('Вы уверены, что хотите удалить эту фразу?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF0A4B47)),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final phraseId = phrase['id'] as int;
      await AppDatabase.instance.deletePhrase(phraseId);
      await _loadAllPhrases();

      if (_showAllPhrases) {
        await _loadAllPhrasesForDisplay();
      } else if (_selectedCategoryId != null) {
        await _loadPhrasesForCategory(_selectedCategoryId!);
      }

      await _loadFavoritePhrases();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Фраза удалена')),
      );
    }
  }

  Future<void> _movePhraseToCategory(Map<String, dynamic> phrase) async {
    final currentCategoryId = phrase['category_id'] as int;

    final availableCategories = _categories.where((c) =>
    c['id'] != currentCategoryId && c['name'] != 'Без категории'
    ).toList();

    if (availableCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет доступных категорий')),
      );
      return;
    }

    final categoryId = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выберите категорию'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableCategories.length,
            itemBuilder: (context, index) {
              final category = availableCategories[index];
              return ListTile(
                title: Text(category['name']),
                onTap: () => Navigator.pop(context, category['id']),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF0A4B47)),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );

    if (categoryId != null) {
      final phraseId = phrase['id'] as int;
      await AppDatabase.instance.movePhraseToCategory(phraseId, categoryId);
      await _loadAllPhrases();

      if (_showAllPhrases) {
        await _loadAllPhrasesForDisplay();
      } else if (_selectedCategoryId != null) {
        await _loadPhrasesForCategory(_selectedCategoryId!);
      }

      await _loadFavoritePhrases();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Фраза перемещена')),
      );
    }
  }

  Future<void> _addPhraseWithoutCategory() async {
    final russian = _newRussianPhraseController.text.trim();
    final mansi = _newMansiPhraseController.text.trim();

    if (russian.isEmpty || mansi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните оба поля')),
      );
      return;
    }

    int? uncategorizedId;
    for (var c in _categories) {
      if (c['name'] == 'Без категории') {
        uncategorizedId = c['id'] as int;
        break;
      }
    }

    if (uncategorizedId == null) {
      uncategorizedId = await AppDatabase.instance.addPhraseCategory('Без категории');
      await _loadCategories();
    }

    await AppDatabase.instance.addPhrase(
      categoryId: uncategorizedId,
      textRussian: russian,
      textMansi: mansi,
    );

    _newRussianPhraseController.clear();
    _newMansiPhraseController.clear();
    await _loadAllPhrases();

    if (_showAllPhrases) {
      await _loadAllPhrasesForDisplay();
    } else if (_selectedCategoryId == uncategorizedId) {
      await _loadPhrasesForCategory(uncategorizedId);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Фраза добавлена')),
      );
    }
  }

  Future<void> _addPhraseToCategory(int categoryId) async {
    final russian = _newRussianPhraseController.text.trim();
    final mansi = _newMansiPhraseController.text.trim();

    if (russian.isEmpty || mansi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните оба поля')),
      );
      return;
    }

    await AppDatabase.instance.addPhrase(
      categoryId: categoryId,
      textRussian: russian,
      textMansi: mansi,
    );

    _newRussianPhraseController.clear();
    _newMansiPhraseController.clear();
    await _loadAllPhrases();

    if (_showAllPhrases) {
      await _loadAllPhrasesForDisplay();
    } else if (_selectedCategoryId == categoryId) {
      await _loadPhrasesForCategory(categoryId);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Фраза добавлена')),
      );
    }
  }

  Future<void> _addCategory() async {
    if (_newCategoryController.text.trim().isEmpty) return;

    final name = _newCategoryController.text.trim();
    await AppDatabase.instance.addPhraseCategory(name);
    _newCategoryController.clear();
    await _loadCategories();
    await _loadAllPhrases();
    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Категория добавлена')),
      );
    }
  }

  Future<void> _translateToRussian() async {
    final mansi = _newMansiPhraseController.text.trim();
    if (mansi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите фразу на мансийском для перевода')),
      );
      return;
    }

    setState(() => _isTranslating = true);
    try {
      final translated = await _translationService.translate(
        text: mansi,
        sourceLang: 'mansi',
        targetLang: 'ru',
      );
      _newRussianPhraseController.text = translated;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка перевода: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isTranslating = false);
    }
  }

  Future<void> _translateToMansi() async {
    final russian = _newRussianPhraseController.text.trim();
    if (russian.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите фразу на русском для перевода')),
      );
      return;
    }

    setState(() => _isTranslating = true);
    try {
      final translated = await _translationService.translate(
        text: russian,
        sourceLang: 'ru',
        targetLang: 'mansi',
      );
      _newMansiPhraseController.text = translated;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка перевода: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isTranslating = false);
    }
  }

  void _speakPhrase(String text) {
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет текста для озвучивания')),
      );
      return;
    }

    _voiceCache.getOrSynthesize(text).then((audioBytes) {
      if (audioBytes != null) {
        TtsAudioPlayer.play(audioBytes, text: text);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось озвучить фразу'), backgroundColor: Colors.red),
        );
      }
    });
  }

  void _showAddPhraseDialog() {
    _newRussianPhraseController.clear();
    _newMansiPhraseController.clear();
    _selectedCategoryForPhrase = null;

    final availableCategories = _categories.where((c) => c['name'] != 'Без категории').toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Добавить фразу'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _newRussianPhraseController,
                    decoration: InputDecoration(
                      labelText: 'Фраза на русском',
                      labelStyle: const TextStyle(color: Color(0xFF0A4B47)),
                      border: const OutlineInputBorder(),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF0A4B47), width: 2),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.translate, color: Color(0xFF0A4B47)),
                        onPressed: _isTranslating ? null : _translateToMansi,
                        tooltip: 'Перевести на мансийский',
                      ),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newMansiPhraseController,
                    decoration: InputDecoration(
                      labelText: 'Фраза на мансийском',
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A4B47)),
                      border: const OutlineInputBorder(),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF0A4B47), width: 2),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.translate, color: Color(0xFF0A4B47)),
                        onPressed: _isTranslating ? null : _translateToRussian,
                        tooltip: 'Перевести на русский',
                      ),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: DropdownButtonFormField<int>(
                      value: _selectedCategoryForPhrase,
                      decoration: InputDecoration(
                        labelText: 'Категория',
                        labelStyle: const TextStyle(color: Color(0xFF0A4B47)),
                        border: const OutlineInputBorder(),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF0A4B47), width: 2),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF0A4B47)),
                        ),
                      ),
                      hint: const Text('Выберите категорию'),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('Без категории'),
                        ),
                        ...availableCategories.map((category) {
                          return DropdownMenuItem<int>(
                            value: category['id'],
                            child: Text(
                              category['name'],
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setStateDialog(() {
                          _selectedCategoryForPhrase = value;
                        });
                      },
                    ),
                  ),
                  if (_isTranslating)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF0A4B47)),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_selectedCategoryForPhrase != null) {
                    await _addPhraseToCategory(_selectedCategoryForPhrase!);
                  } else {
                    await _addPhraseWithoutCategory();
                  }
                  if (mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A4B47),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Добавить'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddCategoryDialog() {
    _newCategoryController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новая категория'),
        content: TextField(
          controller: _newCategoryController,
          decoration: const InputDecoration(
            hintText: 'Название категории',
            border: OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF0A4B47), width: 2),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF0A4B47)),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              _addCategory();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A4B47),
              foregroundColor: Colors.white,
            ),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  void _handleCategoryTap(int categoryId) async {
    if (_selectedCategoryId == categoryId && !_showAllPhrases) {
      // Показываем все фразы
      setState(() {
        _showAllPhrases = true;
      });
      await _loadAllPhrasesForDisplay();
    } else {
      // Показываем фразы выбранной категории
      setState(() {
        _selectedCategoryId = categoryId;
        _showAllPhrases = false;
      });
      await _loadPhrasesForCategory(categoryId);
    }
  }

  String _getCurrentCategoryName() {
    if (_showAllPhrases) return 'Все фразы';
    if (_selectedCategoryId != null) {
      for (var c in _categories) {
        if (c['id'] == _selectedCategoryId) {
          return c['name'] ?? '';
        }
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final filteredPhrases = _getFilteredPhrases();
    final currentCategoryName = _getCurrentCategoryName();

    return BaseScaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset("assets/images/logo.png"),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Разговорник",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.normal),
            ),
            if (currentCategoryName.isNotEmpty)
              Text(
                currentCategoryName,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        backgroundColor: const Color(0xFF0A4B47),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          if (_isPreloading)
            const LinearProgressIndicator(
              backgroundColor: Color(0xFFE7E4DF),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0A4B47)),
            ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Поиск фраз...',
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
                        },
                      )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value.toLowerCase());
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF0A4B47), width: 1.5),
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
                    onPressed: () {
                      setState(() {
                        _showOnlyFavorites = !_showOnlyFavorites;
                      });
                    },
                    tooltip: _showOnlyFavorites
                        ? 'Показать всё'
                        : 'Показать только избранное',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              ],
            ),
          ),

          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategoryId == category['id'] && !_showAllPhrases;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(
                      category['name'],
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF0A4B47),
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      _handleCategoryTap(category['id']);
                    },
                    backgroundColor: const Color(0xFFE7E4DF),
                    selectedColor: const Color(0xFF0A4B47),
                    checkmarkColor: Colors.white,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showAddCategoryDialog,
                    icon: const Icon(Icons.folder_open, size: 18, color: Color(0xFF0A4B47)),
                    label: const Text(
                      'Добавить категорию',
                      style: TextStyle(color: Color(0xFF0A4B47)),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0A4B47),
                      side: const BorderSide(color: Color(0xFF0A4B47)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showAddPhraseDialog,
                    icon: const Icon(Icons.add, size: 18, color: Colors.white),
                    label: const Text(
                      'Добавить фразу',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A4B47),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Colors.grey),

          Expanded(
            child: filteredPhrases.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _showOnlyFavorites ? Icons.star_border : Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _showOnlyFavorites
                        ? 'Нет избранных фраз'
                        : 'Нет фраз. Нажмите "+" чтобы добавить',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: filteredPhrases.length,
              itemBuilder: (context, index) {
                final phrase = filteredPhrases[index];
                final phraseId = phrase['id'] as int;
                final categoryId = phrase['category_id'] as int;
                final isFavorite = _favoritePhrases[categoryId]?.contains(phraseId) ?? false;
                final mansiText = phrase['text_mansi'] ?? '';
                final russianText = phrase['text_russian'] ?? '';
                final categoryName = phrase['category_name'] ?? '';
                final isUncategorized = categoryName == 'Без категории';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    title: Text(
                      mansiText,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A4B47),
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            russianText,
                            style: const TextStyle(fontSize: 16, color: Colors.black87),
                          ),
                          const SizedBox(height: 4),
                          if (categoryName.isNotEmpty && !isUncategorized)
                            Text(
                              categoryName,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          if (isUncategorized && !_showAllPhrases)
                            GestureDetector(
                              onTap: () => _movePhraseToCategory(phrase),
                              child: Text(
                                'Добавить в категорию',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: const Color(0xFF0A4B47),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.volume_up, size: 24),
                          color: const Color(0xFF0A4B47),
                          onPressed: () => _speakPhrase(mansiText),
                          tooltip: 'Озвучить на мансийском',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 24),
                          color: Colors.red,
                          onPressed: () => _deletePhrase(phrase, index),
                          tooltip: 'Удалить фразу',
                        ),
                        Stack(
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
                              onPressed: () => _toggleFavorite(phraseId, categoryId),
                              tooltip: isFavorite ? 'Удалить из избранного' : 'Добавить в избранное',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
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
      endDrawer: const AppDrawer(activeSection: DrawerActiveSection.phrasebook),
    );
  }
}