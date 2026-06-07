import 'package:flutter/material.dart';
import '../pages/translate_page.dart';
import '../pages/main_menu_page.dart';
import '../pages/translation_history_page.dart';
import '../pages/phrasebook_page.dart';  // Добавьте импорт

enum DrawerActiveSection { translator, learning, history, phrasebook }

class AppDrawer extends StatelessWidget {
  final DrawerActiveSection activeSection;

  const AppDrawer({
    super.key,
    required this.activeSection,
  });

  Color _getColor(DrawerActiveSection section) {
    return section == activeSection ? const Color(0xFF0A4B47) : Colors.black;
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
            ListTile(
              title: Text('Переводчик', style: TextStyle(fontSize: 20, color: _getColor(DrawerActiveSection.translator))),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const TranslatePage()));
              },
            ),
            const Divider(height: 1, thickness: 0.5, color: Colors.grey),
            ListTile(
              title: Text('Обучение', style: TextStyle(fontSize: 20, color: _getColor(DrawerActiveSection.learning))),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => MainMenuPage()));
              },
            ),
            const Divider(height: 1, thickness: 0.5, color: Colors.grey),
            ListTile(
              title: Text('История переводов', style: TextStyle(fontSize: 20, color: _getColor(DrawerActiveSection.history))),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const TranslationHistoryPage()));
              },
            ),
            const Divider(height: 1, thickness: 0.5, color: Colors.grey),
            // ✅ Добавлен пункт "Разговорник"
            ListTile(
              title: Text('Разговорник', style: TextStyle(fontSize: 20, color: _getColor(DrawerActiveSection.phrasebook))),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PhrasebookPage()));
              },
            ),
          ],
        ),
      ),
    );
  }
}