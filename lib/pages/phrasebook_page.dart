import 'package:flutter/material.dart';
import '../services/app_database.dart';
import '../widgets/app_drawer.dart';

class PhrasebookPage extends StatefulWidget {
  const PhrasebookPage({super.key});

  @override
  State<PhrasebookPage> createState() => _PhrasebookPageState();
}

class _PhrasebookPageState extends State<PhrasebookPage> {
  String _selectedCategory = 'Все';
  final TextEditingController _searchController = TextEditingController();

  // Временные категории (потом загрузим из БД)
  final List<String> _categories = [
    'Все',
    'Приветствия',
    'Основные фразы',
    'Вопросы',
    'Числа',
    'Семья',
    'Природа',
    'Еда',
    'Путешествия',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset("assets/images/logo.png"),
        ),
        title: const Text('Разговорник'),
        backgroundColor: const Color(0xFF0A4B47),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Поиск
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Поиск фраз',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: const Color(0xFFE7E4DF),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),

          // Категории (горизонтальная прокрутка)
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedCategory = category);
                    },
                    backgroundColor: const Color(0xFFE7E4DF),
                    selectedColor: const Color(0xFF0A4B47),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF0A4B47),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Список фраз (заглушка)
          Expanded(
            child: _buildPhraseList(),
          ),
        ],
      ),
      endDrawer: const AppDrawer(activeSection: DrawerActiveSection.phrasebook),
    );
  }

  Widget _buildPhraseList() {
    // Временные данные (потом загрузим из БД)
    final phrases = [
      {'mansi': 'Паща о̄лэгыт.', 'russian': 'Здравствуйте', 'category': 'Приветствия'},
      {'mansi': 'Кёинва', 'russian': 'Спасибо', 'category': 'Основные фразы'},
      {'mansi': 'Хумус толмащлаӈкве э̄ри?', 'russian': 'Как тебя зовут?', 'category': 'Вопросы'},
      {'mansi': 'Ам э̄руптэ̄гум ты номтыт.', 'russian': 'Меня зовут...', 'category': 'Основные фразы'},
    ];

    final filteredPhrases = phrases.where((phrase) {
      final matchesCategory = _selectedCategory == 'Все' || phrase['category'] == _selectedCategory;
      final matchesSearch = _searchController.text.isEmpty ||
          phrase['mansi']!.toLowerCase().contains(_searchController.text.toLowerCase()) ||
          phrase['russian']!.toLowerCase().contains(_searchController.text.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    if (filteredPhrases.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Фразы пока не добавлены', style: TextStyle(color: Colors.grey, fontSize: 16)),
            SizedBox(height: 8),
            Text('Раздел наполняется', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredPhrases.length,
      itemBuilder: (context, index) {
        final phrase = filteredPhrases[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              phrase['mansi']!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0A4B47),
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  phrase['russian']!,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7E4DF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    phrase['category']!,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.volume_up, color: Color(0xFF0A4B47)),
              onPressed: () {
                // TODO: Добавить озвучивание
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Озвучивание в разработке')),
                );
              },
            ),
          ),
        );
      },
    );
  }
}