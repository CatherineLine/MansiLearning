// lib/widgets/app_drawer.dart
import 'package:flutter/material.dart';
import '../models/learning_entities.dart';
import '../pages/module_levels_page.dart';
import '../pages/translate_page.dart';
import '../pages/translation_history_page.dart';
import '../services/app_database.dart';

enum AppDrawerSection { translator, learning, history }

class AppDrawer extends StatelessWidget {
  final AppDrawerSection activeSection;
  final VoidCallback? onLearningExpanded;

  const AppDrawer({
    super.key,
    required this.activeSection,
    this.onLearningExpanded,
  });

  Color _getColorForSection(AppDrawerSection section) {
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
            // Переводчик
            ListTile(
              title: Text('Переводчик', style: TextStyle(fontSize: 20, color: _getColorForSection(AppDrawerSection.translator))),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const TranslatePage()));
              },
            ),
            const Divider(height: 1, thickness: 0.5, color: Colors.grey),

            // Обучение (с раскрытием модулей)
            ExpansionTile(
              title: Text('Обучение', style: TextStyle(fontSize: 20, color: _getColorForSection(AppDrawerSection.learning))),
              iconColor: _getColorForSection(AppDrawerSection.learning),
              textColor: _getColorForSection(AppDrawerSection.learning),
              onExpansionChanged: (expanded) {
                if (expanded && onLearningExpanded != null) onLearningExpanded!();
              },
              children: [
                FutureBuilder<List<Module>>(
                  future: AppDatabase.instance.getModules(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const ListTile(title: Center(child: CircularProgressIndicator()));
                    }
                    if (snapshot.hasError) {
                      return ListTile(title: Text('Ошибка: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                    }
                    final modules = snapshot.data ?? [];
                    return Column(
                      children: modules.map((module) => ListTile(
                        title: Text(module.title, style: const TextStyle(fontSize: 16)),
                        leading: const Icon(Icons.book, size: 18),
                        onTap: () {
                          if (module.id == null) return; // ✅ Защита от null
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => ModuleLevelsPage(
                              moduleId: module.id!, // ✅ Force unwrap после проверки
                              moduleTitle: module.title,
                            ),
                          ));
                        },
                      )).toList(),
                    );
                  },
                ),
              ],
            ),
            const Divider(height: 1, thickness: 0.5, color: Colors.grey),

            // История переводов
            ListTile(
              title: Text('История переводов', style: TextStyle(fontSize: 20, color: _getColorForSection(AppDrawerSection.history))),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const TranslationHistoryPage()));
              },
            ),
          ],
        ),
      ),
    );
  }
}