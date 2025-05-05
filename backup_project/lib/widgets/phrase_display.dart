import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/level_model.dart';
import '../theme/app_colors.dart';

// Глобальная функция логирования для PhraseDisplay
void logInfo(String message) {
  if (kDebugMode) {
    // ignore: avoid_print
    print('[PhraseDisplay] $message');
  }
}

// --- КОНСТАНТЫ ЦВЕТОВ (Нужны только для стилей по умолчанию, если они не передаются) ---
// const Color kAccentGradientMid = Color(0xFFFBD786); // Больше не нужен здесь
// ---

// Класс для хранения рассчитанных размеров элементов макета
class _LayoutMetrics {
  final double boxSize;
  final double boxHeight;
  final double spacing;
  final double wordSpacing;
  final double letterFontSize;
  final double codeFontSize;

  _LayoutMetrics({
    required this.boxSize,
    required this.boxHeight,
    required this.spacing,
    required this.wordSpacing,
    required this.letterFontSize,
    required this.codeFontSize,
  });

  @override
  String toString() {
    return 'LayoutMetrics(box: ${boxSize.toStringAsFixed(2)}, h: ${boxHeight.toStringAsFixed(2)}, sp: ${spacing.toStringAsFixed(2)}, wsp: ${wordSpacing.toStringAsFixed(2)}, ltrFont: ${letterFontSize.toStringAsFixed(2)}, codeFont: ${codeFontSize.toStringAsFixed(2)})';
  }
}

// --- Виджет PhraseDisplay (ОТКАЧЕННАЯ ВЕРСИЯ - НЕИНТЕРАКТИВНАЯ) ---
class PhraseDisplay extends StatefulWidget {
  // --- Параметры виджета ---
  final List<LetterCellModel> phrase;
  final Set<int> guessedCodes;
  final int? activeCode; // Добавлен параметр activeCode

  // Параметры стилизации (получаемые из GameScreen)
  final Color primaryColor; // Используется для цвета текста по умолчанию в TextField
  final Color backgroundColor;
  final Color correctGuessColor;
  final Color correctGuessBorderColor;
  final Color shadowDarkColor;
  final Color shadowLightColor;
  final Color textColor; // Цвет угаданных букв
  final Color hintTextColor; // Цвет цифры кода
  final Map<int, String> incorrectInputMap; // Карта ошибок (для подсветки)
  final Color incorrectBackgroundColor;
  final Color incorrectBorderColor;
  final void Function(int, String)? onLetterInput; // Добавлен параметр onLetterInput
  final void Function(int)? onActiveCodeChange; // Добавлен параметр onActiveCodeChange
  final VoidCallback? onShowCustomKeyboard; // Добавлен параметр onShowCustomKeyboard
  final bool disableSystemKeyboard; // Новый параметр

  const PhraseDisplay({
    super.key,
    required this.phrase,
    required this.guessedCodes,
    required this.primaryColor,
    required this.backgroundColor,
    required this.correctGuessColor,
    required this.correctGuessBorderColor,
    required this.shadowDarkColor,
    required this.shadowLightColor,
    required this.textColor,
    required this.hintTextColor,
    required this.incorrectInputMap,
    required this.incorrectBackgroundColor,
    required this.incorrectBorderColor,
    this.activeCode, // Добавлен параметр activeCode
    this.onLetterInput, // Добавлен параметр onLetterInput
    this.onActiveCodeChange, // Добавлен параметр onActiveCodeChange
    this.onShowCustomKeyboard, // Добавлен параметр onShowCustomKeyboard
    this.disableSystemKeyboard = false, // по умолчанию false
  });

  @override
  State<PhraseDisplay> createState() => _PhraseDisplayState();
}

class _PhraseDisplayState extends State<PhraseDisplay> with TickerProviderStateMixin {
  // --- Константы размеров (должны быть доступны всегда) ---
  static const double targetBoxSize = 32.0;
  static const double minBoxSize = 16.0;
  static const double targetBoxHeight = 36.0;
  static const double minBoxHeight = 16.0 * (36.0 / 32.0);
  static const double targetSpacing = 2.0;
  static const double minSpacing = 0.5;
  static const double wordSpaceFactor = 0.7;
  static const double minWordSpacing = 5.0;
  static const double targetLetterFontSize = 13.0;
  static const double minLetterFontSize = 9.0;
  static const double targetCodeFontSize = 7.0;
  static const double minCodeFontSize = 6.0;
  // ---

  // Контроллеры нужны для отображения УГАДАННЫХ букв (Text не обновляется сам)
  final Map<int, TextEditingController> _controllers = {};
  // Для анимаций ошибок и успеха:
  final Map<int, AnimationController> _errorControllers = {};
  final Map<int, AnimationController> _successControllers = {};
  final Map<int, int> _errorBlinkCounts = {};
  final int _maxErrorBlinks = 3;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _initAnimationControllers();
  }

  void _initControllers() {
    _controllers.clear();
    for (final cell in widget.phrase) {
      if (cell.code != null) {
        _controllers[cell.code!] = TextEditingController();
      }
    }
    _updateControllerText();
  }

  void _initAnimationControllers() {
    for (final cell in widget.phrase) {
      if (cell.code != null) {
        _errorControllers[cell.code!] = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 120),
          lowerBound: 0.0, upperBound: 1.0,
        );
        _successControllers[cell.code!] = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
          lowerBound: 1.0, upperBound: 1.2,
        );
      }
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    for (final c in _errorControllers.values) { c.dispose(); }
    for (final c in _successControllers.values) { c.dispose(); }
    super.dispose();
  }

  void _disposeControllers() {
    for (final c in _controllers.values) { c.dispose(); }
    _controllers.clear();
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

  void _triggerSuccessAnimation(int code) {
    if (!_successControllers.containsKey(code)) return;
    _successControllers[code]!.forward(from: 1.0);
    _successControllers[code]!.reverse();
  }

  void onLetterInputProxy(int code, String value) {
    final correctLetter = widget.phrase.firstWhere((c) => c.code == code).letter?.toUpperCase();
    if (value.isEmpty) {
      widget.onLetterInput?.call(code, value);
      return;
    }
    if (value == correctLetter) {
      // Анимация успеха для всех ячеек с этой буквой
      for (final cell in widget.phrase.where((c) => c.letter?.toUpperCase() == value)) {
        _triggerSuccessAnimation(cell.code!);
      }
      widget.onLetterInput?.call(code, value);
    } else {
      _triggerErrorAnimation(code);
      // Очищаем неправильную букву после анимации ошибки
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) widget.onLetterInput?.call(code, '');
      });
    }
  }

  // --- Методы жизненного цикла ---
  @override
  void didUpdateWidget(covariant PhraseDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool needsUpdate = false;
    if (!listEquals(widget.phrase, oldWidget.phrase)) {
      _disposeControllers();
      _initControllers(); // Инициализируем новые контроллеры
      needsUpdate = true; // Обновляем текст
    } else if (!setEquals(widget.guessedCodes, oldWidget.guessedCodes) ||
        !mapEquals(widget.incorrectInputMap, oldWidget.incorrectInputMap)) {
      needsUpdate = true; // Обновляем текст или стиль ошибки
    }
    if (needsUpdate) {
      _updateControllerText();
      // setState может быть нужен для перерисовки стиля ошибки,
      // если он не обновился автоматически из-за смены incorrectInputMap
      if(mounted) { setState(() {});}
    }
  }

  bool mapEquals<T, U>(Map<T, U>? a, Map<T, U>? b) { /* ... */ return true; }

  // Обновление текста в контроллерах (только для УГАДАННЫХ)
  void _updateControllerText() {
    for (final cell in widget.phrase) {
      if (cell.code != null) {
        final code = cell.code!;
        final isRevealed = widget.guessedCodes.contains(code);
        final controller = _controllers[code];
        if (controller != null) {
          final targetText = isRevealed ? (cell.letter?.toUpperCase() ?? '?') : '';
          if (controller.text != targetText) {
            // Безопасное обновление после билда
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _controllers.containsKey(code)) {
                _controllers[code]!.text = targetText;
                if (isRevealed) {
                  _controllers[code]!.selection = TextSelection.collapsed(offset: targetText.length);
                }
              }
            });
          }
        }
      }
    }
  }
  // ---

  // --- Функция расчета метрик макета ---
  _LayoutMetrics _calculateLayoutMetrics(List<LetterCellModel> phrase, double availableWidth) {
    logInfo("--- Calculating Metrics ---"); logInfo("Available Width for Calc: ${availableWidth.toStringAsFixed(2)}");
    int longestWordLength = 0; String longestWordStr = ""; int currentWordLength = 0; String currentWordStr = ""; int totalWordsCount = 0; bool containsSpaces = false;
    for (final cell in phrase) { if (cell.letter == ' ') { containsSpaces = true; if (currentWordLength > 0) { totalWordsCount++; if (currentWordLength > longestWordLength) { longestWordLength = currentWordLength; longestWordStr = currentWordStr; } } currentWordLength = 0; currentWordStr = ""; } else { currentWordLength++; currentWordStr += cell.letter ?? ''; } }
    if (currentWordLength > 0) { totalWordsCount++; if (currentWordLength > longestWordLength) { longestWordLength = currentWordLength; longestWordStr = currentWordStr; } }
    if (!containsSpaces && phrase.isNotEmpty) { longestWordLength = phrase.length; longestWordStr = phrase.map((c) => c.letter ?? '').join(); totalWordsCount = 1; }
    if (longestWordLength == 0) longestWordLength = 1; if (totalWordsCount == 0) totalWordsCount = 1;
    logInfo("Longest word: '$longestWordStr' (Length: $longestWordLength)"); logInfo("Total words count: $totalWordsCount");
    const double referenceScreenWidth = 380.0; double scaleFactor = (availableWidth / referenceScreenWidth).clamp(0.6, 1.0);
    double currentBoxSize = (targetBoxSize * scaleFactor).clamp(minBoxSize, targetBoxSize); double currentSpacing = (targetSpacing * scaleFactor).clamp(minSpacing, targetSpacing);
    logInfo("Initial scale: ${scaleFactor.toStringAsFixed(2)} -> Desired sizes: box=${currentBoxSize.toStringAsFixed(2)}, sp=${currentSpacing.toStringAsFixed(2)}");
    double calculateWordWidth(double boxSize, double spacing) { return (longestWordLength * boxSize) + math.max(0, longestWordLength - 1) * spacing; }
    double longestWordCurrentWidth = calculateWordWidth(currentBoxSize, currentSpacing);
    logInfo("Initial longest word width: ${longestWordCurrentWidth.toStringAsFixed(2)} vs availableWidth ${availableWidth.toStringAsFixed(2)}");
    bool needsAggressiveShrinking = totalWordsCount > 4 || longestWordLength > 8;
    int iterations = 0; const int maxIterations = 200;
    while (longestWordCurrentWidth > availableWidth && currentBoxSize > minBoxSize && iterations < maxIterations) { if (iterations == 0) logInfo("Needs shrinking (iterative)... Target width: ${availableWidth.toStringAsFixed(2)}"); currentBoxSize -= 0.25; if (needsAggressiveShrinking) { currentSpacing = minSpacing; } else { currentSpacing = math.max(minSpacing, currentSpacing - 0.1); } if (currentBoxSize < minBoxSize) { currentBoxSize = minBoxSize; } longestWordCurrentWidth = calculateWordWidth(currentBoxSize, currentSpacing); if (iterations % 10 == 0) { logInfo("Iter ${iterations + 1}: box=${currentBoxSize.toStringAsFixed(2)}, sp=${currentSpacing.toStringAsFixed(2)}, wordWidth=${longestWordCurrentWidth.toStringAsFixed(2)}"); } iterations++; if (currentBoxSize <= minBoxSize && longestWordCurrentWidth > availableWidth) { logInfo("Cannot shrink further, reached minBoxSize."); break; } }
    if (iterations >= maxIterations) { logInfo("WARN: Iterative shrinking reached limit!"); }
    if (longestWordCurrentWidth > availableWidth) { currentBoxSize = minBoxSize; currentSpacing = minSpacing; longestWordCurrentWidth = calculateWordWidth(currentBoxSize, currentSpacing); logInfo("WARN: Forced to absolute minimum after loop: box=${currentBoxSize.toStringAsFixed(2)}, sp=${currentSpacing.toStringAsFixed(2)}, final wordWidth=${longestWordCurrentWidth.toStringAsFixed(2)}"); }
    double finalBoxSize = currentBoxSize; double finalSpacing = currentSpacing; double calculatedWordSpacing = finalBoxSize * wordSpaceFactor; double finalWordSpacing = math.max(minWordSpacing, calculatedWordSpacing); double finalBoxHeight = (finalBoxSize * (targetBoxHeight / targetBoxSize)).clamp(minBoxHeight, targetBoxHeight); double sizeRatio = finalBoxSize / targetBoxSize; double finalLetterFontSize = (targetLetterFontSize * sizeRatio).clamp(minLetterFontSize, targetLetterFontSize); double finalCodeFontSize = (targetCodeFontSize * sizeRatio).clamp(minCodeFontSize, targetCodeFontSize);
    final metrics = _LayoutMetrics( boxSize: finalBoxSize, boxHeight: finalBoxHeight, spacing: finalSpacing, wordSpacing: finalWordSpacing, letterFontSize: finalLetterFontSize, codeFontSize: finalCodeFontSize, );
    logInfo("--- Calculated Metrics Result ---"); logInfo("$metrics"); logInfo("-----------------------------");
    return metrics;
  }

  // --- Метод Build ---
  @override
  Widget build(BuildContext context) {
    logInfo("\n--- Build Start ---");
    final double horizontalPadding = 10.0; final screenWidth = MediaQuery.of(context).size.width; final safeAreaInsets = MediaQuery.of(context).padding; final double tolerance = 5.0; final double effectiveWidth = screenWidth - (horizontalPadding * 2) - safeAreaInsets.left - safeAreaInsets.right - tolerance;
    final metrics = _calculateLayoutMetrics(widget.phrase, effectiveWidth);
    logInfo("Build: ScreenWidth=$screenWidth, SafeArea(L:${safeAreaInsets.left}, R:${safeAreaInsets.right})"); logInfo("Build: EffectiveWidth for Layout=${effectiveWidth.toStringAsFixed(2)}"); logInfo("Build: Using Metrics: $metrics");
    final words = <List<LetterCellModel>>[]; List<LetterCellModel> currentWord = []; for (final cell in widget.phrase) { if (cell.letter == ' ') { if (currentWord.isNotEmpty) { words.add(List.from(currentWord)); currentWord.clear(); } } else { currentWord.add(cell); } } if (currentWord.isNotEmpty) { words.add(currentWord); }
    final lines = <Widget>[]; List<Widget> currentLineWidgets = []; double currentLineWidth = 0; int lineIndex = 0;

    for (int wordIndex = 0; wordIndex < words.length; wordIndex++) {
      final word = words[wordIndex];
      final wordText = word.map((c) => c.letter ?? '').join();
      final wordWidth = (word.length * metrics.boxSize) + math.max(0, word.length - 1) * metrics.spacing;
      final requiredWidthForWord = (currentLineWidgets.isNotEmpty ? metrics.wordSpacing : 0) + wordWidth;
      logInfo("Line[$lineIndex] - Processing word: '$wordText' (width: ${wordWidth.toStringAsFixed(2)}), currentLineWidth: ${currentLineWidth.toStringAsFixed(2)}, requiredWidth: ${requiredWidthForWord.toStringAsFixed(2)}");
      if (currentLineWidgets.isNotEmpty && (currentLineWidth + requiredWidthForWord) > effectiveWidth) {
        logInfo("Line[$lineIndex] - Word '$wordText' doesn't fit (${(currentLineWidth + requiredWidthForWord).toStringAsFixed(2)} > ${effectiveWidth.toStringAsFixed(2)}). Breaking line.");
        lines.add(Row(
          key: ValueKey('line_$lineIndex'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.from(currentLineWidgets),
        ));
        lineIndex++;
        currentLineWidgets = [];
        currentLineWidth = 0;
      }
      if (currentLineWidgets.isNotEmpty) {
        currentLineWidgets.add(SizedBox(width: metrics.wordSpacing));
        currentLineWidth += metrics.wordSpacing;
        logInfo("Line[$lineIndex] - Added word spacing: ${metrics.wordSpacing.toStringAsFixed(2)}. New lineWidth: ${currentLineWidth.toStringAsFixed(2)}");
      }
      List<Widget> wordCellWidgets = [];
      for (int i = 0; i < word.length; i++) {
        wordCellWidgets.add(_buildCellWidget(word[i], metrics, ValueKey('cell_${word[i].code}_$wordIndex-$i')));
      }
      currentLineWidgets.addAll(wordCellWidgets);
      currentLineWidth += wordWidth;
      logInfo("Line[$lineIndex] - Added word '$wordText'. Final lineWidth: ${currentLineWidth.toStringAsFixed(2)} (<= ${effectiveWidth.toStringAsFixed(2)})");
      if (currentLineWidth > effectiveWidth) {
        logInfo("WARN: Single word '$wordText' (width ${currentLineWidth.toStringAsFixed(2)}) overflows effectiveWidth (${effectiveWidth.toStringAsFixed(2)})!");
      }
    }
    if (currentLineWidgets.isNotEmpty) {
      logInfo("Line[$lineIndex] - Adding last line. Width: ${currentLineWidth.toStringAsFixed(2)}");
      lines.add(Row(
        key: ValueKey('line_$lineIndex'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: currentLineWidgets,
      ));
    }
    logInfo("--- PhraseDisplay Build End ---");
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: SizedBox(
        height: 180, // Ограничиваем высоту PhraseDisplay
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: lines.map((lineWidget) =>
                Padding(
                  key: lineWidget.key,
                  padding: EdgeInsets.symmetric(vertical: metrics.spacing * 0.5), // уменьшен вертикальный паддинг
                  child: lineWidget,
                )).toList(),
            ),
          ),
        ),
      ),
    );
  }

  // --- Метод _buildCellWidget: ОТРИСОВКА ОДНОЙ ЯЧЕЙКИ (ОТКАТ + СТИЛЬ ОШИБКИ) ---
  Widget _buildCellWidget(LetterCellModel cell, _LayoutMetrics metrics, Key cellKey) {
    final int? code = cell.code;
    final bool isRevealed = code == null || widget.guessedCodes.contains(code);
    final bool hasIncorrectInput = !isRevealed && widget.incorrectInputMap[code] != null;

    return AnimatedBuilder(
      animation: Listenable.merge([
        if (code != null && _errorControllers.containsKey(code)) _errorControllers[code],
        if (code != null && _successControllers.containsKey(code)) _successControllers[code],
      ]),
      builder: (context, child) {
        double scale = 1.0;
        Color? errorColor;
        if (code != null && _errorControllers[code]?.isAnimating == true) {
          errorColor = Color.lerp(widget.incorrectBackgroundColor, Colors.red, _errorControllers[code]!.value);
        }
        if (code != null && _successControllers[code]?.isAnimating == true) {
          scale = _successControllers[code]!.value;
        }
        return Transform.scale(
          scale: scale,
          child: _buildCellContent(cell, metrics, cellKey, errorColor: errorColor),
        );
      },
    );
  }

  Widget _buildCellContent(LetterCellModel cell, _LayoutMetrics metrics, Key cellKey, {Color? errorColor}) {
    final int? code = cell.code;
    final bool isRevealed = code == null || widget.guessedCodes.contains(code);
    final bool hasIncorrectInput = !isRevealed && widget.incorrectInputMap[code] != null;

    // Статичная ячейка
    if (code == null) {
      return Container( key: cellKey, width: metrics.boxSize, height: metrics.boxHeight, decoration: BoxDecoration( color: widget.backgroundColor.withAlpha((0.5 * 255).toInt()), borderRadius: BorderRadius.circular(metrics.boxSize * 0.15), border: Border.all(color: widget.hintTextColor.withAlpha((0.3 * 255).toInt())), ), alignment: Alignment.center, child: Text( cell.letter?.toUpperCase() ?? '', style: TextStyle( fontSize: metrics.letterFontSize, fontWeight: FontWeight.bold, color: widget.textColor.withAlpha((0.8 * 255).toInt()), ), textAlign: TextAlign.center, ), );
    }

    // Угадываемая ячейка
    final controller = _controllers[code];
    // final focusNode = _focusNodes[code]; // <-- УДАЛЕНО: Фокус не управляется здесь
    if (controller == null) { return SizedBox(key: cellKey, width: metrics.boxSize, height: metrics.boxHeight, child: Icon(Icons.error, color: Colors.red)); }

    // Проверяем наличие ошибки для стилизации
    BoxDecoration cellDecoration;
    Color numberColor = widget.hintTextColor;
    Widget cellContent;

    // --- Определяем стиль и КОНТЕНТ ячейки ---
    if (isRevealed) {
      // --- Стиль и контент УГАДАННОЙ ---
      cellDecoration = BoxDecoration(
        gradient: LinearGradient(colors: [kLevelsBtnGradStart, kLevelsBtnGradEnd]),
        borderRadius: BorderRadius.circular(metrics.boxSize * 0.15),
        border: Border.all(color: widget.correctGuessBorderColor, width: 1.5),
      );
      numberColor = Colors.transparent; // Скрываем номер кода
      cellContent = Center(
        child: Text(
          cell.letter!.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: metrics.letterFontSize * 1.35, // ещё больше
            fontWeight: FontWeight.bold,
            color: widget.textColor,
          ),
        ),
      );
    } else if (hasIncorrectInput) { // С ОШИБКОЙ
      cellDecoration = BoxDecoration(
        color: errorColor ?? widget.incorrectBackgroundColor.withAlpha((0.5 * 255).toInt()),
        borderRadius: BorderRadius.circular(metrics.boxSize * 0.15),
        border: Border.all(color: widget.incorrectBorderColor, width: 1.5),
      );
      numberColor = kAnswerBoxIncorrectText; // Белый номер кода
      final String incorrectLetter = widget.incorrectInputMap[cell.code] ?? '';
      cellContent = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            incorrectLetter,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: metrics.letterFontSize,
              fontWeight: FontWeight.w900,
              color: kAnswerBoxIncorrectText, // белый
            ),
          ),
          SizedBox(height: 2),
          Text(
            '${cell.code}',
            style: TextStyle(
              fontSize: metrics.codeFontSize,
              color: kAnswerBoxIncorrectText, // белый номер кода
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    } else if (widget.activeCode != null && cell.code == widget.activeCode) { // ПОДСВЕТКА ВСЕХ АКТИВНЫХ
      cellDecoration = BoxDecoration(
        gradient: LinearGradient(colors: [kAccentColorYellow, kPlayBtnGradEnd]),
        borderRadius: BorderRadius.circular(metrics.boxSize * 0.15),
        border: Border.all(color: kFocusHighlightColor, width: 2.0),
      );
      numberColor = kFocusHighlightColor;
      cellContent = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([
              _errorControllers[cell.code],
              _successControllers[cell.code],
            ]),
            builder: (context, child) {
              double scale = 1.0;
              Color? errorColor;
              if (_errorControllers[cell.code]?.isAnimating == true || (_errorControllers[cell.code]?.value ?? 0) > 0) {
                errorColor = Color.lerp(widget.incorrectBackgroundColor, Colors.red, _errorControllers[cell.code]!.value);
              }
              if (_successControllers[cell.code]?.isAnimating == true || (_successControllers[cell.code]?.value ?? 1) > 1) {
                scale = _successControllers[cell.code]!.value;
              }
              return Transform.scale(
                scale: scale,
                child: TextField(
                  controller: _controllers[cell.code],
                  enabled: true,
                  readOnly: widget.disableSystemKeyboard, // если true — не показываем системную клавиатуру
                  showCursor: true,
                  maxLength: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: metrics.letterFontSize,
                    fontWeight: FontWeight.w900,
                    color: widget.primaryColor,
                  ),
                  decoration: InputDecoration(
                    counterText: '', border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
                    filled: errorColor != null, fillColor: errorColor,
                  ),
                  onChanged: (value) {
                    if (value.length > 1) value = value[0];
                    onLetterInputProxy(cell.code!, value);
                    if (widget.activeCode != cell.code) {
                      widget.onActiveCodeChange?.call(cell.code!);
                    }
                  },
                  onTap: () {
                    if (widget.activeCode != cell.code) {
                      widget.onActiveCodeChange?.call(cell.code!);
                    }
                    // --- Показываем кастомную клавиатуру при тапе на ячейку ---
                    if (widget.onShowCustomKeyboard != null) widget.onShowCustomKeyboard!();
                  },
                ),
              );
            },
          ),
          SizedBox(height: 2),
          Text(
            '${cell.code}',
            style: TextStyle(
              fontSize: metrics.codeFontSize,
              color: kFocusHighlightColor,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    } else { // ОБЫЧНАЯ (без ошибки, без фокуса)
      cellDecoration = BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(metrics.boxSize * 0.15),
        boxShadow: (widget.shadowDarkColor != Colors.transparent || widget.shadowLightColor != Colors.transparent) ? [ /* тени */ ] : null,
        border: (widget.shadowDarkColor == Colors.transparent && widget.shadowLightColor == Colors.transparent)
            ? Border.all(color: widget.hintTextColor.withAlpha((0.4 * 255).toInt()))
            : null,
      );
      numberColor = widget.hintTextColor.withAlpha((0.7 * 255).toInt());
      cellContent = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([
              _errorControllers[cell.code],
              _successControllers[cell.code],
            ]),
            builder: (context, child) {
              double scale = 1.0;
              Color? errorColor;
              if (_errorControllers[cell.code]?.isAnimating == true || (_errorControllers[cell.code]?.value ?? 0) > 0) {
                errorColor = Color.lerp(widget.incorrectBackgroundColor, Colors.red, _errorControllers[cell.code]!.value);
              }
              if (_successControllers[cell.code]?.isAnimating == true || (_successControllers[cell.code]?.value ?? 1) > 1) {
                scale = _successControllers[cell.code]!.value;
              }
              return Transform.scale(
                scale: scale,
                child: TextField(
                  controller: _controllers[cell.code],
                  enabled: true,
                  readOnly: widget.disableSystemKeyboard, // если true — не показываем системную клавиатуру
                  showCursor: true,
                  maxLength: 1, textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: metrics.letterFontSize,
                    fontWeight: FontWeight.w900,
                    color: widget.primaryColor,
                  ),
                  decoration: InputDecoration(
                    counterText: '', border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
                    filled: errorColor != null, fillColor: errorColor,
                  ),
                  onChanged: (value) {
                    if (value.length > 1) value = value[0];
                    onLetterInputProxy(cell.code!, value);
                    if (widget.activeCode != cell.code) {
                      widget.onActiveCodeChange?.call(cell.code!);
                    }
                  },
                  onTap: () {
                    if (widget.activeCode != cell.code) {
                      widget.onActiveCodeChange?.call(cell.code!);
                    }
                    // --- Показываем кастомную клавиатуру при тапе на ячейку ---
                    if (widget.onShowCustomKeyboard != null) widget.onShowCustomKeyboard!();
                  },
                ),
              );
            },
          ),
          SizedBox(height: 2),
          Text(
            '${cell.code}',
            style: TextStyle(
              fontSize: metrics.codeFontSize,
              color: widget.hintTextColor.withAlpha((0.7 * 255).toInt()),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    // --- Сборка виджета ячейки ---
    return SizedBox(
      key: cellKey, width: metrics.boxSize, height: metrics.boxHeight,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150), curve: Curves.easeInOut,
        decoration: cellDecoration, // Применяем стиль (включая стиль ошибки)
        child: cellContent,
      ),
    );
  } // Конец _buildCellContent

} // Конец _PhraseDisplayState