import 'package:flutter/material.dart';
import 'dart:math' as math; // Для CustomPaint
import 'package:flutter/foundation.dart'; // Для listEquals

// --- КОНСТАНТЫ ЦВЕТОВ (Необходимые для этого виджета) ---
// !! Убедитесь, что эти константы соответствуют вашей теме !!
// Центральный круг
const Color kHomeCircleOuterRing = Color(0xFF6D548B); // Для градиента фона текста
const Color kHomeCircleInnerBg = Color(0xFF2C2438);   // Для градиента фона текста
// Текст в круге
const Color kHomeLevelNumColor = Colors.white;
const Color kHomeLevelLabelColor = Color(0xFFA0A0B0); // Для "LEVEL" и пунктира
// Индикатор прогресса
const Color kHomeIndicatorBg = Color(0xFF3a394c); // Цвет фона для индикатора прогресса
// Яркий градиент индикатора (Оранжевый -> Розовый -> Фиолетовый -> Синий -> Бирюзовый)
const List<Color> kHomeIndicatorGradient = [
  Color(0xFFF58529), Color(0xFFF7797d), Color(0xFF8F94FB), Color(0xFF4B416C), Color(0xFF41B1AD),
];
// Кнопка "Играть" (нужен цвет для градиента внутри круга)
const Color kPlayBtnGradStart = Color(0xFFFFA35D);
// Кнопка "Уровни" (нужны цвета для маркера)
const Color kLevelsBtnGradStart = Color(0xFF29a99d);
const Color kLevelsBtnGradEnd = Color(0xFF57FFED);
// --- КОНЕЦ КОНСТАНТ ЦВЕТОВ ---


// --- Виджет Индикатора Уровня ---
class HomeLevelIndicator extends StatelessWidget {
  final int currentLevel;
  final double progress; // 0.0 to 1.0
  final double size;     // Общий размер виджета (диаметр)

  const HomeLevelIndicator({
    super.key,
    required this.currentLevel,
    required this.progress,
    this.size = 250.0, // Увеличенный размер по умолчанию
  });

  @override
  Widget build(BuildContext context) {
    // Рассчитываем размеры элементов пропорционально общему размеру
    final double strokeWidth = size * 0.08;    // Толщина кольца индикатора (~20 для 250)
    final double innerCircleSize = size - (strokeWidth * 2) - (size * 0.12); // Размер внутреннего круга (~160 для 250)
    final double numberFontSize = size * 0.28;    // ~70 для 250
    final double labelFontSize = size * 0.064;    // ~16 для 250

    return SizedBox( // Ограничиваем размер всего виджета
      width: size,
      height: size,
      child: CustomPaint( // Рисуем индикатор и пунктир
        painter: LevelProgressPainter(
          progress: progress,
          gradientColors: kHomeIndicatorGradient, // Яркий градиент
          backgroundColor: kHomeIndicatorBg,
          strokeWidth: strokeWidth,
          segments: 10, // Количество сегментов (для расчета разрывов, если вернем)
        ),
        child: Center( // Центрируем внутренний круг
          child: Container( // Внутренний круг для текста
            width: innerCircleSize,
            height: innerCircleSize,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              // Градиентная заливка внутри круга
              gradient: RadialGradient(
                colors: [
                  kPlayBtnGradStart,         // Центр - оранжевый
                  kHomeCircleOuterRing,      // Середина - фиолетовый
                  kHomeCircleInnerBg,        // Край - темно-фиолетовый
                ],
                stops: [0.0, 0.55, 1.0], // Распределение цветов
                center: Alignment.center, radius: 0.8,
              ),
            ),
            child: Center( // Центрируем текст внутри круга
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text( // Номер уровня
                    '$currentLevel',
                    style: TextStyle(
                        fontSize: numberFontSize, // Динамический размер
                        fontWeight: FontWeight.bold,
                        color: kHomeLevelNumColor,
                        shadows: const [ // Объемные тени
                          Shadow(offset: Offset(0, 2), blurRadius: 4, color: Colors.black87),
                          Shadow(offset: Offset(0, 0), blurRadius: 15, color: Colors.black)
                        ]
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text( // Надпись "LEVEL"
                    'LEVEL',
                    style: TextStyle(
                      fontSize: labelFontSize, // Динамический размер
                      fontWeight: FontWeight.w500,
                      color: kHomeLevelLabelColor,
                      letterSpacing: 3,
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    ); // Конец CustomPaint
  }
} // Конец HomeLevelIndicator


// --- Класс для рисования индикатора прогресса (ФИНАЛЬНАЯ ВЕРСИЯ) ---
class LevelProgressPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final int segments; // Больше не используется для рисования, но нужен для shouldRepaint
  final List<Color> gradientColors;
  final Color backgroundColor;
  final double strokeWidth;

  LevelProgressPainter({
    required this.progress,
    this.segments = 10, // Оставляем для совместимости
    required this.gradientColors,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Радиус для фона и прогресса (одинаковый)
    final radius = math.min(size.width / 2, size.height / 2) - strokeWidth / 2;
    if (radius <= 0) return; // Не рисуем, если места нет

    // --- ИЗМЕНЕНО: Начальный угол - низ (6 часов) ---
    const startAngle = math.pi / 2;
    // ---

    // 1. Рисуем фон индикатора
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, backgroundPaint);

    // 2. Рисуем пунктирную линию снаружи
    final double outerRadius = radius + strokeWidth / 2 + 5; // Отступ пунктира
    final dashPaint = Paint()
      ..color = kHomeLevelLabelColor.withAlpha((0.3 * 255).toInt()) // Цвет пунктира
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    const double dashWidth = 1.0; const double dashSpace = 5.0; // Короткие штрихи, большие пробелы
    final double circumference = 2 * math.pi * outerRadius;
    if (circumference > 0) {
      final double totalDashSpace = dashWidth + dashSpace;
      final int dashCount = math.max(1,(circumference / totalDashSpace).floor());
      final double angleStep = (math.pi * 2) / dashCount;
      final double dashAngle = angleStep * (dashWidth / totalDashSpace);
      for (int i = 0; i < dashCount; i++) {
        final double currentAngle = startAngle + i * angleStep;
        canvas.drawArc( Rect.fromCircle(center: center, radius: outerRadius), currentAngle, dashAngle, false, dashPaint );
      }
    }

    // 3. Рисуем СПЛОШНУЮ дугу прогресса
    if (progress > 0.001) {
      final progressPaint = Paint()
        ..strokeWidth = strokeWidth
      // --- УБРАН MaskFilter ---
        ..shader = SweepGradient( // Яркий градиент
          center: Alignment.center, colors: gradientColors,
          startAngle: startAngle, endAngle: startAngle + (math.pi * 2),
          stops: const [0.0, 0.25, 0.5, 0.75, 1.0], // Точки градиента
          transform: const GradientRotation(startAngle), // Поворот для старта снизу
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
      // --- ИЗМЕНЕНО: Скругленные концы ---
        ..strokeCap = StrokeCap.round; // Делает концы дуги круглыми

      final double sweepAngle = math.pi * 2 * progress.clamp(0.0, 1.0); // Угол заполнения

      // --- Рисуем ОДНУ сплошную дугу ---
      canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,       // Начальный угол (низ)
          sweepAngle,       // Длина дуги (зависит от progress)
          false,            // Не соединять с центром
          progressPaint     // Краска с градиентом и скруглением
      );
      // --- КОНЕЦ РИСОВАНИЯ ДУГИ ---

      // 4. Рисуем маркер на конце прогресса
      final double progressEndAngle = startAngle + sweepAngle;
      // Координаты центра маркера
      final markerCenter = Offset(
        center.dx + radius * math.cos(progressEndAngle),
        center.dy + radius * math.sin(progressEndAngle),
      );
      final markerRadius = strokeWidth * 0.65; // Радиус маркера
      // Краска для маркера (бирюзовый градиент)
      final markerPaint = Paint()
        ..shader = const RadialGradient( colors: [kLevelsBtnGradEnd, kLevelsBtnGradStart], center: Alignment(0.3, -0.3), radius: 0.8, ).createShader(Rect.fromCircle(center: markerCenter, radius: markerRadius))
        ..style = PaintingStyle.fill;
      // Краска для обводки маркера
      final markerBorderPaint = Paint() ..color = Colors.white.withAlpha((0.9 * 255).toInt()) ..strokeWidth = 1.5 ..style = PaintingStyle.stroke;

      // Рисуем маркер и обводку
      canvas.drawCircle(markerCenter, markerRadius, markerPaint);
      canvas.drawCircle(markerCenter, markerRadius + 0.5, markerBorderPaint);
      // --- КОНЕЦ БЛОКА МАРКЕРА ---
    }
  }

  @override
  bool shouldRepaint(covariant LevelProgressPainter oldDelegate) {
    // Перерисовывать, если изменились параметры
    return oldDelegate.progress != progress ||
        oldDelegate.segments != segments || // Оставляем segments на случай, если вы решите их вернуть
        !listEquals(oldDelegate.gradientColors, gradientColors) ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
} // Конец LevelProgressPainter