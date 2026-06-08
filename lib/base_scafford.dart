// base_scaffold.dart
import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';

class BaseScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? endDrawer;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final Key? key;
  final GlobalKey<ScaffoldState>? scaffoldKey;

  const BaseScaffold({
    this.key,
    this.scaffoldKey,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.endDrawer,
    this.bottomNavigationBar,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = screenHeight * 0.02; // 2% от высоты экрана

    return Scaffold(
      key: scaffoldKey ?? key as GlobalKey<ScaffoldState>?,
      backgroundColor: backgroundColor ?? const Color(0xFFE7E4DF),
      appBar: appBar,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: body,
            ),
            SizedBox(height: bottomPadding), // Автоматический отступ снизу
          ],
        ),
      ),
      floatingActionButton: floatingActionButton,
      endDrawer: endDrawer,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}