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
  TranslationStatus? _currentStatus;
  File? _selectedFile;

  @override
  void initState() {
    super.initState();
    _translationService.statusNotifier.addListener(_onStatusUpdate);
  }

  @override
  void dispose() {
    _translationService.statusNotifier.removeListener(_onStatusUpdate);
    super.dispose();
  }

  void _onStatusUpdate() {
    if (mounted) {
      setState(() {
        _currentStatus = _translationService.statusNotifier.value;
        final progress = _currentStatus?.progress;
        _isTranslating = progress != null && progress >= 0 && progress < 100;
      });
    }
  }

  Future<void> _pickAndTranslateFile() async {
    final file = await FileTranslationService.pickFile();
    if (file == null) return;

    setState(() {
      _selectedFile = file;
      _isTranslating = true;
    });

    await _translationService.translateFile(file);
  }

  void _cancelTranslation() {
    _translationService.cancelTranslation();
    setState(() {
      _isTranslating = false;
    });
  }

  void _shareTranslatedFile() {
    if (_currentStatus?.outputFile != null) {
      Share.shareXFiles(
        [XFile(_currentStatus!.outputFile!.path)],
        text: 'Переведённый документ',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double currentProgress = _currentStatus?.progress ?? -1;
    final bool isActiveTranslation = currentProgress >= 0 && currentProgress < 100;
    final bool isCompleted = currentProgress == 100;

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
            // Описание
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📄 Поддерживаемые форматы:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
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

            // Кнопка выбора файла
            ElevatedButton.icon(
              onPressed: _isTranslating ? null : _pickAndTranslateFile,
              icon: const Icon(Icons.upload_file),
              label: const Text('Выбрать файл и перевести'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A4B47),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),

            const SizedBox(height: 24),

            // Статус перевода
            if (_currentStatus != null) ...[
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
                            const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _currentStatus?.fileName ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_currentStatus?.status ?? ''),
                      const SizedBox(height: 8),

                      if (currentProgress >= 0 && currentProgress <= 100) ...[
                        LinearProgressIndicator(
                          value: currentProgress / 100,
                          backgroundColor: Colors.grey[200],
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0A4B47)),
                        ),
                        const SizedBox(height: 8),
                        Text('${currentProgress.toStringAsFixed(0)}%'),
                      ],

                      if (isActiveTranslation) ...[
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: _cancelTranslation,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            minimumSize: const Size(double.infinity, 40),
                          ),
                          child: const Text('Отменить'),
                        ),
                      ],

                      if (isCompleted && _currentStatus?.outputFile != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Файл сохранён в папке приложения'),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.save_alt),
                                label: const Text('Файл сохранён'),
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