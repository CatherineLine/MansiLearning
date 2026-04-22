import 'package:flutter/material.dart';

class TranslationHistoryItem {
  final String originalText;
  final String translatedText;
  final DateTime timestamp;
  final String direction;

  TranslationHistoryItem(this.originalText, this.translatedText, this.timestamp, this.direction);
}