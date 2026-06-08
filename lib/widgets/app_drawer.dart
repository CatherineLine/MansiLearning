// widgets/app_drawer.dart
import 'package:flutter/material.dart';
import '../pages/translate_page.dart';
import '../pages/main_menu_page.dart';
import '../pages/translation_history_page.dart';
import '../pages/phrasebook_page.dart';
import '../pages/riddles_menu_page.dart';
import '../pages/document_translation_page.dart';

enum DrawerActiveSection {
  translator,
  learning,
  history,
  phrasebook,
  riddles,
  documents,
}

class AppDrawer extends StatelessWidget {
  final DrawerActiveSection activeSection;

  const AppDrawer({
    super.key,
    required this.activeSection,
  });

  Color _getColor(DrawerActiveSection section) {
    return section == activeSection ? const Color(0xFF0A4B47) : Colors.black;
  }

  Color _getBackgroundColor(DrawerActiveSection section) {
    return section == activeSection
        ? const Color(0xFF0A4B47).withOpacity(0.1)
        : Colors.transparent;
  }

  void _navigateTo(BuildContext context, Widget page, DrawerActiveSection section) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        padding: const EdgeInsets.only(top: 40),
        decoration: const BoxDecoration(color: Color(0xFFE7E4DF)),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Заголовок меню
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Меню',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A4B47),
                ),
              ),
            ),
            const Divider(height: 1, thickness: 0.5, color: Colors.grey),

            // 1. Переводчик
            Container(
              color: _getBackgroundColor(DrawerActiveSection.translator),
              child: ListTile(
                leading: Icon(Icons.translate, color: _getColor(DrawerActiveSection.translator)),
                title: Text(
                  'Переводчик',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: activeSection == DrawerActiveSection.translator
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: _getColor(DrawerActiveSection.translator),
                  ),
                ),
                trailing: activeSection == DrawerActiveSection.translator
                    ? const Icon(Icons.check_circle, color: Color(0xFF0A4B47), size: 20)
                    : null,
                onTap: () => _navigateTo(context, const TranslatePage(), DrawerActiveSection.translator),
              ),
            ),
            const Divider(height: 1, thickness: 0.5, color: Colors.grey),

            // 2. Обучение
            Container(
              color: _getBackgroundColor(DrawerActiveSection.learning),
              child: ListTile(
                leading: Icon(Icons.school, color: _getColor(DrawerActiveSection.learning)),
                title: Text(
                  'Обучение',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: activeSection == DrawerActiveSection.learning
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: _getColor(DrawerActiveSection.learning),
                  ),
                ),
                trailing: activeSection == DrawerActiveSection.learning
                    ? const Icon(Icons.check_circle, color: Color(0xFF0A4B47), size: 20)
                    : null,
                onTap: () => _navigateTo(context, MainMenuPage(), DrawerActiveSection.learning),
              ),
            ),
            const Divider(height: 1, thickness: 0.5, color: Colors.grey),

            // 3. Загадки
            Container(
              color: _getBackgroundColor(DrawerActiveSection.riddles),
              child: ListTile(
                leading: Icon(Icons.psychology, color: _getColor(DrawerActiveSection.riddles)),
                title: Text(
                  'Загадки',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: activeSection == DrawerActiveSection.riddles
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: _getColor(DrawerActiveSection.riddles),
                  ),
                ),
                trailing: activeSection == DrawerActiveSection.riddles
                    ? const Icon(Icons.check_circle, color: Color(0xFF0A4B47), size: 20)
                    : null,
                onTap: () => _navigateTo(context, const RiddlesMenuPage(), DrawerActiveSection.riddles),
              ),
            ),
            const Divider(height: 1, thickness: 0.5, color: Colors.grey),

            // 4. Перевод документов (НОВЫЙ ПУНКТ)
            Container(
              color: _getBackgroundColor(DrawerActiveSection.documents),
              child: ListTile(
                leading: Icon(Icons.description, color: _getColor(DrawerActiveSection.documents)),
                title: Text(
                  'Перевод документов',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: activeSection == DrawerActiveSection.documents
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: _getColor(DrawerActiveSection.documents),
                  ),
                ),
                trailing: activeSection == DrawerActiveSection.documents
                    ? const Icon(Icons.check_circle, color: Color(0xFF0A4B47), size: 20)
                    : null,
                onTap: () => _navigateTo(context, const DocumentTranslationPage(), DrawerActiveSection.documents),
              ),
            ),
            const Divider(height: 1, thickness: 0.5, color: Colors.grey),

            // 5. История переводов
            Container(
              color: _getBackgroundColor(DrawerActiveSection.history),
              child: ListTile(
                leading: Icon(Icons.history, color: _getColor(DrawerActiveSection.history)),
                title: Text(
                  'История переводов',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: activeSection == DrawerActiveSection.history
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: _getColor(DrawerActiveSection.history),
                  ),
                ),
                trailing: activeSection == DrawerActiveSection.history
                    ? const Icon(Icons.check_circle, color: Color(0xFF0A4B47), size: 20)
                    : null,
                onTap: () => _navigateTo(context, const TranslationHistoryPage(), DrawerActiveSection.history),
              ),
            ),
            const Divider(height: 1, thickness: 0.5, color: Colors.grey),

            // 6. Разговорник
            Container(
              color: _getBackgroundColor(DrawerActiveSection.phrasebook),
              child: ListTile(
                leading: Icon(Icons.chat_bubble_outline, color: _getColor(DrawerActiveSection.phrasebook)),
                title: Text(
                  'Разговорник',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: activeSection == DrawerActiveSection.phrasebook
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: _getColor(DrawerActiveSection.phrasebook),
                  ),
                ),
                trailing: activeSection == DrawerActiveSection.phrasebook
                    ? const Icon(Icons.check_circle, color: Color(0xFF0A4B47), size: 20)
                    : null,
                onTap: () => _navigateTo(context, const PhrasebookPage(), DrawerActiveSection.phrasebook),
              ),
            ),
          ],
        ),
      ),
    );
  }
}