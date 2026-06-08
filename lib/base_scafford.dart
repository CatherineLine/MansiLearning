import 'package:flutter/material.dart';

class BaseScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? endDrawer;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final double bottomPadding; // Процент отступа снизу (0-1)

  const BaseScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.endDrawer,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.bottomPadding = 0.02, // 5% от высоты экрана по умолчанию
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPaddingValue = screenHeight * bottomPadding;

    return Scaffold(
      backgroundColor: backgroundColor ?? const Color(0xFFE7E4DF),
      appBar: appBar,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: body,
            ),
            // Пустое пространство снизу
            SizedBox(height: bottomPaddingValue),
          ],
        ),
      ),
      floatingActionButton: floatingActionButton,
      endDrawer: endDrawer,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}