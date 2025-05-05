import 'package:flutter/material.dart';
import '../models/question_model.dart';

class AnswerInputRow extends StatefulWidget {
  final QuestionModel answer;
  final Set<int> guessedCodes;
  final void Function(int code, String value) onLetterInput;

  const AnswerInputRow({
    super.key,
    required this.answer,
    required this.guessedCodes,
    required this.onLetterInput,
  });

  @override
  State<AnswerInputRow> createState() => _AnswerInputRowState();
}

class _AnswerInputRowState extends State<AnswerInputRow> with TickerProviderStateMixin {
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, FocusNode> _focusNodes = {};
  final Map<int, AnimationController> _errorControllers = {};
  final Map<int, AnimationController> _successControllers = {};
  final Map<int, int> _errorBlinkCounts = {};
  final int _maxErrorBlinks = 3;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.answer.answer.length; i++) {
      final code = widget.answer.letterCodes[i];
      _controllers[code] = TextEditingController();
      _focusNodes[code] = FocusNode();
      _errorControllers[code] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 120),
        lowerBound: 0.0, upperBound: 1.0,
      );
      _successControllers[code] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 220),
        lowerBound: 1.0, upperBound: 1.2,
      );
    }
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    for (var f in _focusNodes.values) {
      f.dispose();
    }
    for (var c in _errorControllers.values) { c.dispose(); }
    for (var c in _successControllers.values) { c.dispose(); }
    super.dispose();
  }

  void _triggerErrorAnimation(int code) async {
    if (!_errorControllers.containsKey(code)) return;
    _errorBlinkCounts[code] = 0;
    for (int i = 0; i < _maxErrorBlinks; i++) {
      await _errorControllers[code]!.forward();
      await _errorControllers[code]!.reverse();
      _errorBlinkCounts[code] = i + 1;
    }
    if (mounted) {
      setState(() {
        _controllers[code]?.text = '';
      });
    }
  }

  void _triggerSuccessAnimation(int code, String value) {
    if (!_successControllers.containsKey(code)) return;
    _successControllers[code]!.forward(from: 1.0);
    _successControllers[code]!.reverse();
  }

  void _onLetterInputProxy(int code, String value) {
    final correctLetter = widget.answer.answer[widget.answer.letterCodes.indexOf(code)]?.toUpperCase();
    if (value.isEmpty) {
      widget.onLetterInput(code, value);
      return;
    }
    if (value == correctLetter) {
      // Анимация успеха для всех ячеек с этой буквой
      for (int i = 0; i < widget.answer.answer.length; i++) {
        if (widget.answer.answer[i]?.toUpperCase() == value) {
          final c = widget.answer.letterCodes[i];
          _triggerSuccessAnimation(c, value);
        }
      }
      widget.onLetterInput(code, value);
    } else {
      _triggerErrorAnimation(code);
      widget.onLetterInput(code, ''); // очищаем
    }
  }

  @override
  Widget build(BuildContext context) {
    final letterCodes = widget.answer.letterCodes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.answer.question,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: List.generate(widget.answer.answer.length, (i) {
              final code = letterCodes[i];
              final correctLetter = widget.answer.answer[i]?.toUpperCase();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                child: SizedBox(
                  width: 40,
                  height: 54, // увеличил высоту для гарантии отсутствия overflow
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: Listenable.merge([
                          _errorControllers[code],
                          _successControllers[code],
                        ]),
                        builder: (context, child) {
                          double scale = 1.0;
                          Color? errorColor;
                          if (_errorControllers[code]?.isAnimating == true || (_errorControllers[code]?.value ?? 0) > 0) {
                            errorColor = Color.lerp(Colors.white, Colors.red, _errorControllers[code]!.value);
                          }
                          if (_successControllers[code]?.isAnimating == true || (_successControllers[code]?.value ?? 1) > 1) {
                            scale = _successControllers[code]!.value;
                          }
                          return Transform.scale(
                            scale: scale,
                            child: TextField(
                              controller: _controllers[code],
                              focusNode: _focusNodes[code],
                              enabled: true,
                              readOnly: false,
                              showCursor: true,
                              maxLength: 1,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                              decoration: InputDecoration(
                                counterText: '', border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
                                filled: errorColor != null, fillColor: errorColor,
                              ),
                              onChanged: (value) {
                                if (value.length > 1) value = value[0];
                                _onLetterInputProxy(code, value);
                                // автопереход
                                if (value.isNotEmpty) {
                                  final codes = widget.answer.letterCodes;
                                  final currentIndex = codes.indexOf(code);
                                  if (currentIndex != -1 && currentIndex < codes.length - 1) {
                                    final nextCode = codes[currentIndex + 1];
                                    _focusNodes[nextCode]?.requestFocus();
                                  }
                                }
                              },
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$code',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
