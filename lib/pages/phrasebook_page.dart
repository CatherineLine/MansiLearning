import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../base_scafford.dart';
import '../services/app_database.dart';
import '../services/translation_service.dart';
import '../services/tts_api_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/mansi_keyboard.dart';
import '../widgets/base_page.dart';

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
// Экран добавления фразы
// ============================================================
class AddPhraseScreen extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final Function(String, String, int?) onSave;
  final VoidCallback onCancel;

  const AddPhraseScreen({
    super.key,
    required this.categories,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<AddPhraseScreen> createState() => _AddPhraseScreenState();
}

class _AddPhraseScreenState extends State<AddPhraseScreen> {
  final TextEditingController _russianController = TextEditingController();
  final TextEditingController _mansiController = TextEditingController();
  int? _selectedCategoryId;
  bool _isSaving = false;

  final FocusNode _mansiFocusNode = FocusNode();
  bool _isMansiKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    _mansiFocusNode.addListener(() {
      if (mounted) {
        setState(() {
          _isMansiKeyboardVisible = _mansiFocusNode.hasFocus;
        });
      }
    });
  }

  @override
  void dispose() {
    _russianController.dispose();
    _mansiController.dispose();
    _mansiFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE7E4DF),
      appBar: AppBar(
        title: const Text(
          'Добавить фразу',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0A4B47),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onCancel,
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            TextButton(
              onPressed: _savePhrase,
              child: const Text(
                'Сохранить',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // Фраза на русском
                  const Text(
                    'Фраза на русском',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0A4B47),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _russianController,
                    decoration: InputDecoration(
                      hintText: 'Введите фразу на русском...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF0A4B47)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF0A4B47), width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF0A4B47)),
                      ),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),

                  // Фраза на мансийском
                  const Text(
                    'Фраза на мансийском',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0A4B47),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _mansiController,
                    focusNode: _mansiFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Введите фразу на мансийском...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF0A4B47)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF0A4B47), width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF0A4B47)),
                      ),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),

                  // Категория
                  const Text(
                    'Категория',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0A4B47),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonFormField<int>(
                      value: _selectedCategoryId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      hint: const Text('Выберите категорию'),
                      isExpanded: true,
                      dropdownColor: const Color(0xFFE7E4DF),
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('Без категории'),
                        ),
                        ...widget.categories.map((category) {
                          return DropdownMenuItem<int>(
                            value: category['id'],
                            child: Text(category['name']),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCategoryId = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          // ✅ Мансийская клавиатура (встроена в дерево)
          if (_isMansiKeyboardVisible)
            MansiKeyboard(
              onTextInput: (text) {
                _mansiController.text += text;
              },
            ),
        ],
      ),
    );
  }

  void _savePhrase() {
    final russian = _russianController.text.trim();
    final mansi = _mansiController.text.trim();

    if (russian.isEmpty || mansi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполните оба поля'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    widget.onSave(russian, mansi, _selectedCategoryId);
    // Страница закроется после сохранения через Navigator.pop
  }
}

// ============================================================
// Экран добавления категории
// ============================================================
class AddCategoryScreen extends StatefulWidget {
  final Function(String) onSave;
  final VoidCallback onCancel;

  const AddCategoryScreen({
    super.key,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isMansiKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) {
        setState(() {
          _isMansiKeyboardVisible = _focusNode.hasFocus;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE7E4DF),
      appBar: AppBar(
        title: const Text(
          'Новая категория',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0A4B47),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onCancel,
        ),
        actions: [
          TextButton(
            onPressed: _saveCategory,
            child: const Text(
              'Сохранить',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  const Text(
                    'Название категории',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0A4B47),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: 'Введите название...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF0A4B47)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF0A4B47), width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF0A4B47)),
                      ),
                    ),
                    autofocus: true,
                  ),
                ],
              ),
            ),
          ),
          // ✅ Мансийская клавиатура (встроена в дерево)
          if (_isMansiKeyboardVisible)
            MansiKeyboard(
              onTextInput: (text) {
                _controller.text += text;
              },
            ),
        ],
      ),
    );
  }

  void _saveCategory() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите название категории'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    widget.onSave(name);
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
  final TranslationService _translationService = TranslationService();
  final VoiceCacheService _voiceCache = VoiceCacheService();

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _allPhrases = [];
  List<Map<String, dynamic>> _currentPhrases = [];

  Map<int, Set<int>> _favoritePhrases = {};

  int? _selectedCategoryId;
  bool _showAllPhrases = false;
  bool _isLoading = true;
  bool _isPreloading = false;
  int _userId = 1;

  String _searchQuery = '';
  bool _showOnlyFavorites = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _voiceCache.init();
    TtsAudioPlayer.init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // Основные методы
  // ============================================================
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

  Set<String> _preloadedPhrases = {};

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

  Future<void> _addPhraseWithoutCategory(String russian, String mansi) async {
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

    await _loadAllPhrases();

    if (_showAllPhrases) {
      await _loadAllPhrasesForDisplay();
    } else if (_selectedCategoryId == uncategorizedId) {
      await _loadPhrasesForCategory(uncategorizedId);
    }
  }

  Future<void> _addPhraseToCategory(String russian, String mansi, int categoryId) async {
    await AppDatabase.instance.addPhrase(
      categoryId: categoryId,
      textRussian: russian,
      textMansi: mansi,
    );

    await _loadAllPhrases();

    if (_showAllPhrases) {
      await _loadAllPhrasesForDisplay();
    } else if (_selectedCategoryId == categoryId) {
      await _loadPhrasesForCategory(categoryId);
    }
  }

  void _speakPhrase(String text) {
    if (text.trim().isEmpty) return;

    _voiceCache.getOrSynthesize(text).then((audioBytes) {
      if (audioBytes != null) {
        TtsAudioPlayer.play(audioBytes, text: text);
      }
    });
  }

  void _handleCategoryTap(int categoryId) async {
    if (_selectedCategoryId == categoryId && !_showAllPhrases) {
      setState(() {
        _showAllPhrases = true;
      });
      await _loadAllPhrasesForDisplay();
    } else {
      setState(() {
        _selectedCategoryId = categoryId;
        _showAllPhrases = false;
      });
      await _loadPhrasesForCategory(categoryId);
    }
  }

  // ============================================================
  // ✅ Открытие экрана добавления фразы
  // ============================================================
  void _openAddPhraseScreen() {
    final availableCategories = _categories.where((c) => c['name'] != 'Без категории').toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPhraseScreen(
          categories: availableCategories,
          onSave: (russian, mansi, categoryId) async {
            try {
              if (categoryId != null) {
                await _addPhraseToCategory(russian, mansi, categoryId);
              } else {
                await _addPhraseWithoutCategory(russian, mansi);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Фраза добавлена')),
                );
                Navigator.pop(context);
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
                );
              }
            }
          },
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }

  // ============================================================
  // ✅ Открытие экрана добавления категории
  // ============================================================
  void _openAddCategoryScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCategoryScreen(
          onSave: (name) async {
            try {
              await AppDatabase.instance.addPhraseCategory(name);
              await _loadCategories();
              await _loadAllPhrases();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Категория добавлена')),
                );
                Navigator.pop(context);
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
                );
              }
            }
          },
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredPhrases = _getFilteredPhrases();

    return BasePage(
      title: "Разговорник",
      activeSection: DrawerActiveSection.phrasebook,
      child: Column(
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
                    tooltip: _showOnlyFavorites ? 'Показать всё' : 'Показать только избранное',
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
                    onPressed: _openAddCategoryScreen,
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
                    onPressed: _openAddPhraseScreen,
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredPhrases.isEmpty
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
    );
  }
}