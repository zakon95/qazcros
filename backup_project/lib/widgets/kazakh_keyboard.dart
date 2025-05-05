import 'package:flutter/material.dart';
import 'dart:math' as math; 
import '../theme/app_colors.dart';
import 'hint_floating_button.dart';

class KazakhKeyboard extends StatelessWidget {
  final Function(String) onKeyPressed;
  final int hintsCount;

  const KazakhKeyboard({
    super.key,
    required this.onKeyPressed,
    this.hintsCount = 0,
  });

  // === Минималистичные размеры для клавиатуры ===
  static const double _minKeyHeight = 36; // минимальная высота
  static const double _minKeyFontSize = 16; // минимальный размер шрифта
  static const EdgeInsets _minKeyPadding = EdgeInsets.symmetric(vertical: 4, horizontal: 4); // минимальный паддинг
  // 2. Ячейки phrase display
  static const double _minCellSize = 32; // минимальный размер клетки
  static const double _minCellFontSize = 16; // минимальный размер шрифта в клетке
  static const double _minCellSpacing = 4; // минимальный отступ между клетками

  @override
  Widget build(BuildContext context) {
    final List<List<String>> keyboardRows = [
      ['Ә', 'І', 'Ң', 'Ғ', 'Ү', 'Ұ', 'Қ', 'Ө', 'Һ'],
      ['Й', 'Ц', 'У', 'К', 'Е', 'Н', 'Г', 'Ш', 'Щ', 'З', 'Х'],
      ['Ф', 'Ы', 'В', 'А', 'П', 'Р', 'О', 'Л', 'Д', 'Ж', 'Э'],
      ['Я', 'Ч', 'С', 'М', 'И', 'Т', 'Ь', 'Б', 'Ю', 'Ё'],
    ];
    final screenWidth = MediaQuery.of(context).size.width;
    final double horizontalPadding = 5.0 * 2;
    final double availableWidth = screenWidth - horizontalPadding;
    int maxKeysInRow = 0;
    for (var row in keyboardRows) { maxKeysInRow = math.max(maxKeysInRow, row.length); }
    const double keySpacing = 4.0;
    const double minKeyWidth = 28.0;
    final double calculatedKeyWidth = (availableWidth - ((maxKeysInRow - 1) * keySpacing)) / maxKeysInRow;
    final double keyWidth = math.max(minKeyWidth, calculatedKeyWidth).floorToDouble();
    final double bottomSystemPadding = MediaQuery.of(context).padding.bottom;
    const double extraBottomPadding = 10.0;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              kHomeBgGradEnd.withAlpha((0.90 * 255).toInt()),
              kHomeBgGradMid.withAlpha((0.95 * 255).toInt()),
              kHomeBgGradEnd.withAlpha((0.90 * 255).toInt()),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: EdgeInsets.fromLTRB(
            horizontalPadding / 2, 0, horizontalPadding / 2,
            bottomSystemPadding > 0 ? bottomSystemPadding + extraBottomPadding : 15.0
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Первый ряд
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(keyboardRows[0].length * 2 - 1, (index) {
                  if (index.isEven) {
                    final letterIndex = index ~/ 2;
                    return _buildKey(keyboardRows[0][letterIndex], keyWidth);
                  } else {
                    return const SizedBox(width: keySpacing);
                  }
                }),
              ),
            ),
            // Остальные ряды
            for (var rowIndex = 1; rowIndex < keyboardRows.length; rowIndex++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(keyboardRows[rowIndex].length * 2 - 1, (index) {
                    if (index.isEven) {
                      final letterIndex = index ~/ 2;
                      return _buildKey(keyboardRows[rowIndex][letterIndex], keyWidth);
                    } else {
                      return const SizedBox(width: keySpacing);
                    }
                  }),
                ),
              ),
            // Нижний ряд с функциональными кнопками
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildFunctionKey(
                      onTap: () => onKeyPressed('BACKSPACE'),
                      child: const Icon(Icons.backspace_outlined, color: kBrightTextColor, size: 22),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _buildFunctionKey(
                      onTap: () => onKeyPressed('HIDE_KEYBOARD'),
                      child: const Icon(Icons.keyboard_hide_outlined, color: kBrightTextColor, size: 22),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Кнопка подсказки справа
                  HintFloatingButton(
                    onTap: () => onKeyPressed('HINT'),
                    count: hintsCount,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ИЗМЕНЕНО: Виджет для кнопки БУКВЫ ---
  Widget _buildKey(String letter, double width) {
    const double keyHeight = _minKeyHeight; // минимальная высота
    final borderRadius = BorderRadius.circular(8);

    return Container(
      width: width,
      height: keyHeight,
      decoration: BoxDecoration(
        // Убираем градиент, ставим цвет фона и рамку
        color: kLetterKeyBg, // Полупрозрачный темный фон
        border: Border.all(color: kLetterKeyBorder.withAlpha((0.5 * 255).toInt()), width: 1), // Легкая рамка
        borderRadius: borderRadius,
        boxShadow: [ // Легкое свечение
          BoxShadow( color: kLetterKeyGlow.withAlpha((0.5 * 255).toInt()), blurRadius: 5, spreadRadius: 0,),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: () => onKeyPressed(letter),
          borderRadius: borderRadius,
          splashColor: kHomeBgGradMid.withAlpha((0.5 * 255).toInt()), // Эффект нажатия
          highlightColor: kHomeBgGradStart.withAlpha((0.4 * 255).toInt()),
          child: Center(
            child: Text(
              letter,
              style: TextStyle(
                  fontSize: _minKeyFontSize, // минимальный размер шрифта
                  fontWeight: FontWeight.w600, // Пожирнее
                  color: kBrightTextColor, // Белый текст
                  shadows: [ Shadow(offset: Offset(1, 1), blurRadius: 1, color: Colors.black54) ]
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- ИЗМЕНЕНО: Виджет для ФУНКЦИОНАЛЬНОЙ кнопки ---
  Widget _buildFunctionKey({ required VoidCallback onTap, required Widget child }) {
    const double keyHeight = _minKeyHeight; // минимальная высота
    final borderRadius = BorderRadius.circular(8);

    return Container(
      height: keyHeight,
      decoration: BoxDecoration(
        // Используем ОРАНЖЕВЫЙ градиент (как кнопка Играть)
        gradient: const LinearGradient(
          colors: [kPlayBtnGradStart, kPlayBtnGradEnd],
          begin: Alignment.centerLeft, end: Alignment.centerRight,
        ),
        borderRadius: borderRadius,
        boxShadow: [ // Соответствующее свечение
          BoxShadow( color: kPlayBtnGlow.withAlpha((0.7 * 255).toInt()), blurRadius: 8, spreadRadius: 1,),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          splashColor: kPlayBtnGradEnd.withAlpha((0.4 * 255).toInt()), // Темнее оранжевый
          highlightColor: kPlayBtnGradStart.withAlpha((0.3 * 255).toInt()), // Светлее оранжевый
          child: Center(child: child),
        ),
      ),
    );
  }
}

// Удаляем/комментируем KazakhKeyboardWithButtons, чтобы не было дублирования кнопок сверху
// class KazakhKeyboardWithButtons extends StatelessWidget {
//   final Function(String) onKeyPressed;
//   const KazakhKeyboardWithButtons({super.key, required this.onKeyPressed});
//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       alignment: Alignment.bottomCenter,
//       children: [
//         Align(
//           alignment: Alignment.bottomCenter,
//           child: KazakhKeyboard(onKeyPressed: onKeyPressed),
//         ),
//         Positioned(
//           left: 0,
//           right: 0,
//           bottom: 220, // ещё выше над клавиатурой
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Padding(
//                 padding: const EdgeInsets.only(left: 8),
//                 child: KazakhKeyboardStaticHelpers._buildSideButtonStatic(
//                   icon: Icons.shopping_bag_outlined,
//                   onTap: () {},
//                   gradientColors: [kPlayBtnGradStart, kPlayBtnGradEnd],
//                 ),
//               ),
//               Padding(
//                 padding: const EdgeInsets.only(right: 8),
//                 child: KazakhKeyboardStaticHelpers._buildSideButtonStatic(
//                   icon: Icons.lightbulb_outline,
//                   onTap: () {},
//                   gradientColors: [kPlayBtnGradStart, kPlayBtnGradEnd],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
// }

// Статические методы для боковых кнопок и рекламы
extension KazakhKeyboardStaticHelpers on KazakhKeyboard {
  static Widget _buildSideButtonStatic({
    required IconData icon,
    required VoidCallback onTap,
    required List<Color> gradientColors,
  }) {
    return Container(
      width: 40, // уменьшено
      height: 40, // уменьшено
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFA35D), Color(0xFFFFD86F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0xFFFFA35D).withOpacity(0.5),
            blurRadius: 6, // чуть меньше
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: Icon(icon, color: Colors.white, size: 20), // иконка меньше
          ),
        ),
      ),
    );
  }

  static Widget buildAdBlockStatic() {
    return Container(
      height: 54,
      margin: EdgeInsets.zero, // полностью убираем отступ сверху
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), // скругление только сверху
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'Здесь будет реклама',
          style: TextStyle(fontSize: 16, color: Colors.black38),
        ),
      ),
    );
  }
}

class KeyboardBgClipper extends CustomClipper<Path> {
  final double buttonRadius;
  final double padding;
  KeyboardBgClipper({required this.buttonRadius, required this.padding});

  @override
  Path getClip(Size size) {
    final path = Path();
    // Левая верхняя часть
    path.moveTo(0, buttonRadius + padding);
    path.arcToPoint(
      Offset(buttonRadius + padding, 0),
      radius: Radius.circular(buttonRadius + padding),
      clockwise: false,
    );
    // Верхняя линия до правого выреза
    path.lineTo(size.width - buttonRadius - padding, 0);
    // Правая дуга
    path.arcToPoint(
      Offset(size.width, buttonRadius + padding),
      radius: Radius.circular(buttonRadius + padding),
      clockwise: false,
    );
    // Правая сторона вниз
    path.lineTo(size.width, size.height);
    // Левая сторона вниз
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}