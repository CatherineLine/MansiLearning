import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class TranslationService {
  static const String translateApiEndpoint = "https://ethnoportal.admhmao.ru/api/machine-translates/translate";

  Future<String> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    if (text.trim().isEmpty) return text;

    final int sourceLanguage = sourceLang == 'ru' ? 1 : 2;
    final int targetLanguage = targetLang == 'ru' ? 1 : 2;

    final Map<String, dynamic> data = {
      "text": text,
      "sourceLanguage": sourceLanguage,
      "targetLanguage": targetLanguage,
    };

    try {
      final response = await http.post(
        Uri.parse(translateApiEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        String responseBody = utf8.decode(response.bodyBytes);
        final Map<String, dynamic> responseData = json.decode(responseBody);
        return responseData['translatedText'] ?? text;
      } else {
        return text;
      }
    } catch (e) {
      debugPrint('Ошибка перевода: $e');
      return text;
    }
  }
}