import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Тестирование всех возможных API эндпоинтов
class TestAllApis extends StatefulWidget {
  const TestAllApis({super.key});

  @override
  State<TestAllApis> createState() => _TestAllApisState();
}

class _TestAllApisState extends State<TestAllApis> {
  bool _isTesting = false;
  final List<Map<String, dynamic>> _results = [];

  final String _baseUrl = "https://ethnoportal.admhmao.ru";
  final String _testText = "Привет, это тест";

  // Список возможных эндпоинтов для получения голосов
  final List<Map<String, dynamic>> _voicesEndpoints = [
    {'path': '/tts/voices/', 'method': 'GET', 'description': 'Голоса со слешем'},
    {'path': '/tts/voices', 'method': 'GET', 'description': 'Голоса без слеша'},
    {'path': '/api/tts/voices/', 'method': 'GET', 'description': 'API голоса со слешем'},
    {'path': '/api/tts/voices', 'method': 'GET', 'description': 'API голоса без слеша'},
    {'path': '/voices', 'method': 'GET', 'description': 'Только voices'},
    {'path': '/api/voices', 'method': 'GET', 'description': 'API voices'},
    {'path': '/tts/voices/list', 'method': 'GET', 'description': 'Список голосов'},
    {'path': '/api/tts/voices/list', 'method': 'GET', 'description': 'API список голосов'},
    {'path': '/tts/available-voices', 'method': 'GET', 'description': 'Доступные голоса'},
    {'path': '/api/tts/available-voices', 'method': 'GET', 'description': 'API доступные голоса'},
  ];

  // Список возможных эндпоинтов для синтеза речи
  final List<Map<String, dynamic>> _synthesizeEndpoints = [
    {'path': '/tts', 'method': 'POST', 'description': 'TTS основной'},
    {'path': '/api/tts', 'method': 'POST', 'description': 'API TTS'},
    {'path': '/tts/synthesize', 'method': 'POST', 'description': 'TTS синтез'},
    {'path': '/api/tts/synthesize', 'method': 'POST', 'description': 'API TTS синтез'},
    {'path': '/synthesize', 'method': 'POST', 'description': 'Просто синтез'},
    {'path': '/api/synthesize', 'method': 'POST', 'description': 'API синтез'},
    {'path': '/tts/generate', 'method': 'POST', 'description': 'TTS генерация'},
    {'path': '/api/tts/generate', 'method': 'POST', 'description': 'API TTS генерация'},
    {'path': '/speech/synthesize', 'method': 'POST', 'description': 'Речь синтез'},
    {'path': '/api/speech/synthesize', 'method': 'POST', 'description': 'API речь синтез'},
  ];

  Future<void> _testAllEndpoints() async {
    setState(() {
      _isTesting = true;
      _results.clear();
    });

    // Тестируем эндпоинты для голосов
    _results.add({
      'type': 'header',
      'title': '📢 ТЕСТИРОВАНИЕ ЭНДПОИНТОВ ДЛЯ ГОЛОСОВ',
    });

    for (var endpoint in _voicesEndpoints) {
      final result = await _testVoicesEndpoint(endpoint);
      setState(() {
        _results.add(result);
      });
      await Future.delayed(const Duration(milliseconds: 500)); // небольшая задержка
    }

    // Тестируем эндпоинты для синтеза речи
    _results.add({
      'type': 'header',
      'title': '🎤 ТЕСТИРОВАНИЕ ЭНДПОИНТОВ ДЛЯ СИНТЕЗА РЕЧИ',
    });

    for (var endpoint in _synthesizeEndpoints) {
      final result = await _testSynthesizeEndpoint(endpoint);
      setState(() {
        _results.add(result);
      });
      await Future.delayed(const Duration(milliseconds: 500));
    }

    setState(() {
      _isTesting = false;
    });
  }

  Future<Map<String, dynamic>> _testVoicesEndpoint(Map<String, dynamic> endpoint) async {
    final String url = '$_baseUrl${endpoint['path']}';
    final String method = endpoint['method'];
    final String description = endpoint['description'];

    final startTime = DateTime.now();

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json', 'Accept': '*/*'},
      ).timeout(const Duration(seconds: 10));

      final duration = DateTime.now().difference(startTime);

      String result = '';
      List<String> voiceNames = [];

      if (response.statusCode == 200) {
        final contentType = response.headers['content-type'] ?? '';

        if (contentType.contains('application/json')) {
          try {
            final dynamic data = json.decode(response.body);
            if (data is List) {
              for (var item in data) {
                if (item is Map) {
                  final name = item['name']?.toString() ?? '';
                  if (name.isNotEmpty) voiceNames.add(name);
                }
              }
              result = '✅ JSON список, найдено голосов: ${voiceNames.length}';
              if (voiceNames.isNotEmpty) {
                result += '\n   Имена: ${voiceNames.join(', ')}';
              }
            } else if (data is Map && data.containsKey('voices')) {
              final voices = data['voices'];
              if (voices is List) {
                result = '✅ JSON объект с voices, найдено: ${voices.length}';
              } else {
                result = '✅ JSON получен, но не список';
              }
            } else {
              result = '✅ JSON получен: ${response.body.length > 100 ? response.body.substring(0, 100) : response.body}';
            }
          } catch (e) {
            result = '✅ Статус 200, но не JSON: ${response.body.length > 100 ? response.body.substring(0, 100) : response.body}';
          }
        } else if (contentType.contains('text/html')) {
          result = '⚠️ HTML страница (не JSON)';
        } else {
          result = '⚠️ Статус 200, тип: $contentType, размер: ${response.bodyBytes.length} байт';
        }
      } else {
        result = '❌ Ошибка ${response.statusCode}';
      }

      return {
        'type': 'voices',
        'method': method,
        'path': endpoint['path'],
        'description': description,
        'statusCode': response.statusCode,
        'duration': duration.inMilliseconds,
        'result': result,
        'voiceNames': voiceNames,
      };

    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      return {
        'type': 'voices',
        'method': method,
        'path': endpoint['path'],
        'description': description,
        'statusCode': null,
        'duration': duration.inMilliseconds,
        'result': '❌ Ошибка: $e',
        'voiceNames': [],
      };
    }
  }

  Future<Map<String, dynamic>> _testSynthesizeEndpoint(Map<String, dynamic> endpoint) async {
    final String url = '$_baseUrl${endpoint['path']}';
    final String method = endpoint['method'];
    final String description = endpoint['description'];

    final Map<String, dynamic> requestBody = {
      "text": _testText,
      "voice_name": "irina",
      "settings": {
        "speed": 1.0,
        "nfe_step": 32,
        "cfg_strength": 2.0,
        "sway_sampling_coef": -1.0,
        "cross_fade_duration": 0.05,
      }
    };

    final startTime = DateTime.now();

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'audio/wav, audio/mpeg, */*',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 15));

      final duration = DateTime.now().difference(startTime);

      String result = '';
      bool isAudio = false;

      if (response.statusCode == 200) {
        final contentType = response.headers['content-type'] ?? '';

        // Проверяем, является ли ответ аудио (WAV начинается с RIFF)
        final isWav = response.bodyBytes.length > 12 &&
            response.bodyBytes[0] == 0x52 && // 'R'
            response.bodyBytes[1] == 0x49 && // 'I'
            response.bodyBytes[2] == 0x46 && // 'F'
            response.bodyBytes[3] == 0x46;   // 'F'

        if (contentType.contains('audio') || isWav) {
          isAudio = true;
          result = '✅ АУДИО ПОЛУЧЕНО! Размер: ${response.bodyBytes.length} байт';
        } else if (contentType.contains('application/json')) {
          try {
            final data = json.decode(response.body);
            result = '⚠️ JSON ответ: ${data.toString().length > 200 ? data.toString().substring(0, 200) : data.toString()}';

            // Если в ответе есть ID файла
            if (data['id'] != null) {
              result += '\n   ID файла: ${data['id']}';
            }
            if (data['isAudio'] == true) {
              result += '\n   Это аудиофайл, но нужен отдельный запрос для скачивания';
            }
          } catch (e) {
            result = '⚠️ Статус 200, тип: $contentType, размер: ${response.bodyBytes.length} байт';
          }
        } else {
          result = '⚠️ Статус 200, тип: $contentType, размер: ${response.bodyBytes.length} байт';
          if (response.bodyBytes.length < 500) {
            result += '\n   Содержимое: ${response.body}';
          }
        }
      } else {
        result = '❌ Ошибка ${response.statusCode}';
      }

      return {
        'type': 'synthesize',
        'method': method,
        'path': endpoint['path'],
        'description': description,
        'statusCode': response.statusCode,
        'duration': duration.inMilliseconds,
        'result': result,
        'isAudio': isAudio,
      };

    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      return {
        'type': 'synthesize',
        'method': method,
        'path': endpoint['path'],
        'description': description,
        'statusCode': null,
        'duration': duration.inMilliseconds,
        'result': '❌ Ошибка: $e',
        'isAudio': false,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тест всех API'),
        backgroundColor: const Color(0xFF0A4B47),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: _isTesting ? null : _testAllEndpoints,
            tooltip: 'Запустить тест',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.blue[50],
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.blue[800]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Тестируется ${_voicesEndpoints.length + _synthesizeEndpoints.length} эндпоинтов',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                if (_isTesting)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _results.isEmpty
                ? const Center(child: Text('Нажмите ▶ для запуска теста'))
                : ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final item = _results[index];

                if (item['type'] == 'header') {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.grey[300],
                    child: Text(
                      item['title'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  );
                }

                final isSuccess = item['statusCode'] == 200;
                final isAudio = item['isAudio'] == true;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: isSuccess
                      ? (isAudio ? Colors.green[50] : Colors.blue[50])
                      : Colors.grey[50],
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSuccess ? Colors.green : Colors.red,
                      child: Text(
                        item['statusCode']?.toString() ?? '?',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    title: Text(
                      '${item['method']} ${item['path']}',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${item['description']} - ${item['duration']} мс'),
                        Text(
                          item['result'],
                          style: TextStyle(
                            fontSize: 12,
                            color: isSuccess ? Colors.green[800] : Colors.red[800],
                          ),
                        ),
                        if (item['voiceNames'] != null && item['voiceNames'].isNotEmpty)
                          Text(
                            '🎤 Голоса: ${item['voiceNames'].join(', ')}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                    trailing: isSuccess
                        ? Icon(isAudio ? Icons.audiotrack : Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.error, color: Colors.red),
                  ),
                );
              },
            ),
          ),
          // Результат в консоль
          ElevatedButton.icon(
            onPressed: () {
              _printResultsToConsole();
            },
            icon: const Icon(Icons.print),
            label: const Text('Вывести результат в консоль'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[800],
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _printResultsToConsole() {
    debugPrint('\n' + '=' * 80);
    debugPrint('📊 РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ API');
    debugPrint('=' * 80);

    for (var item in _results) {
      if (item['type'] == 'header') {
        debugPrint('\n${item['title']}');
        debugPrint('-' * 40);
      } else {
        final statusIcon = item['statusCode'] == 200 ? '✅' : '❌';
        debugPrint('$statusIcon ${item['method']} ${item['path']}');
        debugPrint('   Статус: ${item['statusCode']} (${item['duration']} мс)');
        debugPrint('   Результат: ${item['result']}');
        if (item['voiceNames'] != null && item['voiceNames'].isNotEmpty) {
          debugPrint('   Голоса: ${item['voiceNames'].join(', ')}');
        }
        debugPrint('');
      }
    }
    debugPrint('=' * 80);
  }
}