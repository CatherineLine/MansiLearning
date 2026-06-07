import 'package:flutter/material.dart';

class MansiKeyboard extends StatefulWidget {
  final Function(String) onTextInput;

  const MansiKeyboard({
    super.key,
    required this.onTextInput,
  });

  @override
  State<MansiKeyboard> createState() => _MansiKeyboardState();
}

class _MansiKeyboardState extends State<MansiKeyboard> {
  static const Color appGreen = Color(0xFF0A4B47);
  static const Color appBeige = Color(0xFFE7E4DF);

  // Состояния Shift: 0 = выключен, 1 = одно нажатие (одна заглавная), 2 = Caps Lock
  int _shiftState = 0;

  // Строчные буквы
  final List<String> _lowercaseLetters = [
    'а̄', 'о̄', 'ē', 'ы̄', 'э̄', 'ӈ', 'ю̄', 'ӣ', 'я̄', 'ё̄', 'ӯ'
  ];

  // Заглавные буквы
  final List<String> _uppercaseLetters = [
    'А̄', 'О̄', 'Ē', 'Ы̄', 'Э̄', 'Ӈ', 'Ю̄', 'Ӣ', 'Я̄', 'Ё̄', 'Ӯ'
  ];

  List<String> get _currentLetters => _shiftState > 0 ? _uppercaseLetters : _lowercaseLetters;

  void _handleShiftPress() {
    setState(() {
      if (_shiftState == 0) {
        _shiftState = 1; // Одно нажатие - одна заглавная
      } else if (_shiftState == 1) {
        _shiftState = 2; // Два нажатия - Caps Lock
      } else {
        _shiftState = 0; // Выключить Caps Lock
      }
    });
  }

  void _onKeyTap(String letter) {
    String outputLetter = letter;

    if (_shiftState == 1) {
      // Режим одной заглавной буквы
      outputLetter = _getUppercaseForLetter(letter);
      // Выключаем Shift после ввода
      Future.delayed(Duration.zero, () {
        if (mounted) {
          setState(() {
            _shiftState = 0;
          });
        }
      });
    } else if (_shiftState == 2) {
      // Caps Lock режим
      outputLetter = _getUppercaseForLetter(letter);
    }

    widget.onTextInput(outputLetter);
  }

  String _getUppercaseForLetter(String lowercase) {
    final index = _lowercaseLetters.indexOf(lowercase);
    if (index != -1 && index < _uppercaseLetters.length) {
      return _uppercaseLetters[index];
    }
    return lowercase;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: appGreen,
      padding: const EdgeInsets.all(5),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Кнопка Shift слева
              _buildShiftButton(),
              // Основные буквы
              ..._currentLetters.map((letter) => _buildKey(letter)).toList(),
            ],
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
          backgroundColor: appBeige,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7),
          ),
          padding: const EdgeInsets.all(3),
        ),
        onPressed: () => _onKeyTap(letter),
        child: Text(
          letter,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: appGreen,
          ),
        ),
      ),
    );
  }

  Widget _buildShiftButton() {
    IconData iconData;

    if (_shiftState == 0) {
      iconData = Icons.arrow_upward;
    } else if (_shiftState == 1) {
      iconData = Icons.arrow_upward;
    } else {
      iconData = Icons.keyboard_capslock;
    }

    return SizedBox(
      width: 30,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: appBeige,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
              ),
              padding: const EdgeInsets.all(3),
            ),
            onPressed: _handleShiftPress,
            child: Icon(
              iconData,
              size: 20,
              color: appGreen,
            ),
          ),
          if (_shiftState == 1)
            Positioned(
              bottom: 6,
              child: Container(
                width: 16,
                height: 2,
                color: appGreen,
              ),
            ),
        ],
      ),
    );
  }
}