import 'package:flutter/material.dart';

class MansiKeyboard extends StatelessWidget {
  final Function(String) onTextInput;
  final VoidCallback onBackspace;

  const MansiKeyboard({
    super.key,
    required this.onTextInput,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> mansiLetters = [
      'а̄', 'о̄', 'ē', 'ы̄', 'э̄', 'ӈ', 'ю̄', 'ӣ', 'я̄', 'ё̄', 'ӯ'
    ];

    return Container(
      color: const Color(0xFF0A4B47),
      padding: const EdgeInsets.all(5),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: mansiLetters.map((letter) => _buildKey(letter)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String letter) {
    return SizedBox(
      width: 30,
      height: 40,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7),
          ),
          padding: const EdgeInsets.all(3),
        ),
        onPressed: () => onTextInput(letter),
        child: Text(letter, style: const TextStyle(fontSize: 23)),
      ),
    );
  }
}