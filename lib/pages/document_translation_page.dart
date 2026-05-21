import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/file_translation_service.dart';

class DocumentTranslationPage extends StatefulWidget {
  const DocumentTranslationPage({super.key});

  @override
  State<DocumentTranslationPage> createState() => _DocumentTranslationPageState();
}

class _DocumentTranslationPageState extends State<DocumentTranslationPage> {
  final FileTranslationService _translationService = FileTranslationService();
  bool _isTranslating = false;

  @override
  void initState() {
    super.initState();
    // ✅ Подписываемся на обновления статуса из сервиса
    _translationService.statusNotifier.addListener(_onStatusUpdate);
  }

  @override
  void dispose() {
    _translationService.statusNotifier.removeListener(_onStatusUpdate);
    super.dispose();
  }

  void _onStatusUpdate() {
    if (mounted) {
      final status = _translationService.statusNotifier.value;
      // ✅ Сбрасываем флаг, если перевод завершён или произошла ошибка
      if (status != null && (status.progress == 100.0 || status.progress == -1.0)) {
        setState(() => _isTranslating = false);
      }
    }
  }

  Future<void> _pickAndTranslateFile() async {
    // ✅ Проверяем, не идёт ли уже перевод
    if (_isTranslating) return;

    try {
      final file = await FileTranslationService.pickFile();
      if (file == null) return; // Пользователь отменил выбор

      setState(() => _isTranslating = true);

      // ✅ Запускаем реальный перевод через сервис
      await _translationService.translateFile(file);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
      setState(() => _isTranslating = false); // ✅ Сбрасываем флаг при ошибке
    }
  }

  void _shareTranslatedFile() {
    final outputFile = _translationService.statusNotifier.value?.outputFile;
    if (outputFile != null) {
      Share.shareXFiles(
        [XFile(outputFile.path)],
        text: 'Переведённый документ',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Получаем статус из ValueNotifier сервиса
    final status = _translationService.statusNotifier.value;
    final currentProgress = status?.progress ?? -1;
    final isActiveTranslation = currentProgress >= 0 && currentProgress < 100;
    final isCompleted = currentProgress == 100;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Перевод документов'),
        backgroundColor: const Color(0xFF0A4B47),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Описание форматов
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📄 Поддерживаемые форматы:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('TXT, MD, JSON, XML, HTML, RTF'),
                  SizedBox(height: 8),
                  Text(
                    'ℹ️ Файлы переводятся построчно. Большие файлы могут обрабатываться дольше.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Перевод ', style: TextStyle(fontSize: 16)),
                Switch(
                  value: _translationService.isTranslatingToMansi,
                  onChanged: (value) {
                    _translationService.setTranslationDirection(toMansi: value);
                    setState(() {}); // Обновить текст переключателя
                  },
                  activeColor: const Color(0xFF0A4B47),
                ),
                Text(
                  _translationService.isTranslatingToMansi ? 'на мансийский' : 'с мансийского',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Кнопка выбора файла
            ElevatedButton.icon(
              onPressed: _isTranslating ? null : _pickAndTranslateFile,
              icon: const Icon(Icons.upload_file),
              label: Text(_isTranslating ? 'Перевод...' : 'Выбрать файл и перевести'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A4B47),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 24),

            // Статус перевода
            if (status != null) ...[
              const Divider(),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isActiveTranslation)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else if (isCompleted)
                            const Icon(Icons.check_circle, color: Colors.green)
                          else if (currentProgress == -1)
                              const Icon(Icons.error, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              status.fileName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(status.status),
                      const SizedBox(height: 8),

                      // Прогресс-бар
                      if (currentProgress >= 0 && currentProgress <= 100) ...[
                        LinearProgressIndicator(
                          value: currentProgress / 100,
                          backgroundColor: Colors.grey[200],
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0A4B47)),
                        ),
                        const SizedBox(height: 8),
                        Text('${currentProgress.toStringAsFixed(0)}%'),
                      ],

                      // Кнопка отмены
                      if (isActiveTranslation) ...[
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () {
                            _translationService.cancelTranslation();
                            setState(() => _isTranslating = false);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            minimumSize: const Size(double.infinity, 40),
                          ),
                          child: const Text('Отменить'),
                        ),
                      ],

                      // Кнопки после завершения
                      if (isCompleted && status.outputFile != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Файл: ${status.outputFile!.path}')),
                                  );
                                },
                                icon: const Icon(Icons.save_alt),
                                label: const Text('Путь к файлу'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0A4B47),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _shareTranslatedFile,
                                icon: const Icon(Icons.share),
                                label: const Text('Поделиться'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const Spacer(),

            // Информация
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Перевод может занять некоторое время в зависимости от размера файла.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}