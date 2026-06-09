import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../base_scafford.dart';
import '../services/file_translation_service.dart';
import '../widgets/app_drawer.dart';

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
      if (status != null && (status.progress == 100.0 || status.progress == -1.0)) {
        setState(() => _isTranslating = false);
      }
    }
  }

  Future<void> _pickAndTranslateFile() async {
    if (_isTranslating) return;

    try {
      final file = await FileTranslationService.pickFile();
      if (file == null) return;

      setState(() => _isTranslating = true);
      await _translationService.translateFile(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isTranslating = false);
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
    final status = _translationService.statusNotifier.value;
    final currentProgress = status?.progress ?? -1;
    final isActiveTranslation = currentProgress >= 0 && currentProgress < 100;
    final isCompleted = currentProgress == 100;

    return BaseScaffold(
      appBar: AppBar(
        title: const Text(
          'Перевод документов',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0A4B47),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openEndDrawer(),
          ),
        ],
      ),
      endDrawer: const AppDrawer(activeSection: DrawerActiveSection.documents),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Карточка с информацией о форматах
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF0A4B47), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.description, color: Color(0xFF0A4B47), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Поддерживаемые форматы:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF0A4B47),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFormatChip('TXT'),
                        _buildFormatChip('MD'),
                        _buildFormatChip('JSON'),
                        _buildFormatChip('XML'),
                        _buildFormatChip('HTML'),
                        _buildFormatChip('RTF'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey, size: 16),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Файлы переводятся построчно. Большие файлы могут обрабатываться дольше.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Переключатель направления перевода
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF0A4B47), width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Перевод ',
                      style: TextStyle(fontSize: 16, color: Color(0xFF0A4B47)),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        color: const Color(0xFFE7E4DF),
                      ),
                      child: Switch(
                        value: _translationService.isTranslatingToMansi,
                        onChanged: (value) {
                          _translationService.setTranslationDirection(toMansi: value);
                          setState(() {});
                        },
                        activeColor: const Color(0xFF0A4B47),
                        activeTrackColor: const Color(0xFF0A4B47).withOpacity(0.3),
                        inactiveThumbColor: const Color(0xFF0A4B47),
                        inactiveTrackColor: const Color(0xFF0A4B47).withOpacity(0.2),
                      ),
                    ),
                    Text(
                      _translationService.isTranslatingToMansi ? 'на мансийский' : 'с мансийского',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0A4B47),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Кнопка выбора файла
              ElevatedButton.icon(
                onPressed: _isTranslating ? null : _pickAndTranslateFile,
                icon: Icon(
                  _isTranslating ? Icons.hourglass_empty : Icons.upload_file,
                  color: Colors.white,
                ),
                label: Text(
                  _isTranslating ? 'Перевод в процессе...' : 'Выбрать файл и перевести',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A4B47),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: const Color(0xFF0A4B47).withOpacity(0.5),
                ),
              ),

              // Статус перевода
              if (status != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF0A4B47), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Заголовок с иконкой статуса
                      Row(
                        children: [
                          if (isActiveTranslation)
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0A4B47)),
                              ),
                            )
                          else if (isCompleted)
                            const Icon(Icons.check_circle, color: Colors.green, size: 24)
                          else if (currentProgress == -1)
                              const Icon(Icons.error, color: Colors.red, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              status.fileName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF0A4B47),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Статус текстом
                      Text(
                        status.status,
                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                      ),

                      // Прогресс-бар
                      if (currentProgress >= 0 && currentProgress <= 100) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: currentProgress / 100,
                            backgroundColor: const Color(0xFFE7E4DF),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0A4B47)),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${currentProgress.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0A4B47),
                          ),
                        ),
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
                            side: const BorderSide(color: Colors.red),
                            minimumSize: const Size(double.infinity, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Отменить перевод'),
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
                                    SnackBar(
                                      content: Text('Файл сохранён: ${status.outputFile!.path}'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.folder_open, size: 18),
                                label: const Text('Путь к файлу'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0A4B47),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _shareTranslatedFile,
                                icon: const Icon(Icons.share, size: 18),
                                label: const Text('Поделиться'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0A4B47),
                                  side: const BorderSide(color: Color(0xFF0A4B47)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Информационная карточка
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7E4DF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.security, size: 20, color: Color(0xFF0A4B47)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ваши файлы обрабатываются безопасно и не сохраняются на сервере после перевода.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF0A4B47)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormatChip(String format) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE7E4DF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        format,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Color(0xFF0A4B47),
        ),
      ),
    );
  }
}