// widgets/base_page.dart
import 'package:flutter/material.dart';
import 'app_drawer.dart';

class BasePage extends StatelessWidget {
  final Widget child;
  final DrawerActiveSection activeSection;
  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? appBar;
  final FloatingActionButton? floatingActionButton;
  final Color? backgroundColor;

  const BasePage({
    super.key,
    required this.child,
    required this.activeSection,
    required this.title,
    this.actions,
    this.appBar,
    this.floatingActionButton,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = screenHeight * 0.05; // 5% отступ снизу

    return Scaffold(
      backgroundColor: backgroundColor ?? const Color(0xFFE7E4DF),
      appBar: appBar ?? AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset("assets/images/logo.png"),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.normal,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF0A4B47),
        foregroundColor: Colors.white,
        actions: actions ?? [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white, size: 30),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: AppDrawer(activeSection: activeSection),
      floatingActionButton: floatingActionButton,
      body: Column(
        children: [
          Expanded(child: child),
          SizedBox(height: bottomPadding), // Автоматический отступ снизу
        ],
      ),
    );
  }
}