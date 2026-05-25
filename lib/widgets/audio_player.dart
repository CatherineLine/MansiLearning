import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class AudioPlayerButton extends StatefulWidget {
  final String audioPath;
  final double size;

  const AudioPlayerButton({
    Key? key,
    required this.audioPath,
    this.size = 40,
  }) : super(key: key);

  @override
  State<AudioPlayerButton> createState() => _AudioPlayerButtonState();
}

class _AudioPlayerButtonState extends State<AudioPlayerButton> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _playAudio() async {
    try {
      await _player.play(DeviceFileSource(widget.audioPath));
      setState(() => _isPlaying = true);

      _player.onPlayerComplete.listen((event) {
        if (mounted) {
          setState(() => _isPlaying = false);
        }
      });
    } catch (e) {
      debugPrint('Ошибка воспроизведения: $e');
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        _isPlaying ? Icons.volume_up : Icons.volume_off,
        color: _isPlaying ? Colors.green : const Color(0xFF0A4B47),
      ),
      iconSize: widget.size,
      onPressed: _isPlaying ? null : _playAudio,
      tooltip: 'Прослушать произношение',
    );
  }
}