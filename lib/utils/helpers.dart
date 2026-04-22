import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void showSuccess(String message) {
  if (navigatorKey.currentContext != null && navigatorKey.currentState?.mounted == true) {
    ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

void showError(String message, {bool isError = true}) {
  if (navigatorKey.currentContext != null && navigatorKey.currentState?.mounted == true) {
    ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.orange,
      ),
    );
  }
}