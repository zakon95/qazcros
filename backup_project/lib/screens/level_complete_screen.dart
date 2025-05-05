import 'package:flutter/material.dart';
// import 'package:collection/collection.dart'; // Не используется здесь
import 'package:flutter_markdown/flutter_markdown.dart'; // <-- Импорт для Markdown
import 'package:logging/logging.dart'; // <-- Импорт для логирования
import '../services/progress_service.dart'; // Импортируем сервис прогресса

// --- Замените на ваши реальные пути ---
import '../models/level_model.dart'; // Модель уровня
import 'game_screen.dart'; // Для навигации на следующий уровень
import 'level_select_screen.dart'; // Для навигации к списку уровней
import '../theme/app_colors.dart'; // <-- Импорт для цветов
// ---

class LevelCompleteScreen extends StatefulWidget {
  final LevelModel completedLevel;
  final int maxLevel; // Максимальный номер уровня в игре

  const LevelCompleteScreen({
    super.key,
    required this.completedLevel,
    required this.maxLevel,
  });

  @override
  _LevelCompleteScreenState createState() => _LevelCompleteScreenState();
}

class _LevelCompleteScreenState extends State<LevelCompleteScreen> {
  final _logger = Logger('LevelCompleteScreen');
  final _progressService = ProgressService();
  bool _scoreGranted = false; // Флаг, чтобы начислять очки только один раз

  Future<void> _grantScoreIfNeeded() async {
    if (!_scoreGranted) {
      try {
        await _progressService.incrementScore(100);
        _logger.info("Score incremented successfully");
        _scoreGranted = true;
      } catch (e) {
        _logger.severe("Error incrementing score: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Рассчитываем номер следующего уровня
    final int nextLevelNumber = (widget.completedLevel.levelNumber ?? 0) + 1;
    // Проверяем, был ли пройденный уровень последним
    final bool isLastLevel = (widget.completedLevel.levelNumber ?? 0) >= widget.maxLevel;

    // --- Получаем тексты из модели ---
    final String categoryText = widget.completedLevel.category.toUpperCase();
    final String phraseText = widget.completedLevel.fullPhrase.toUpperCase();
    // Получаем текст объяснения (может быть null)
    final String? explanation = widget.completedLevel.explanationText;
    // ---

    // --- Стили для Markdown (на темном фоне) ---
    final baseTextStyle = Theme.of(context).textTheme.bodyMedium?.copyWith( color: kBrightTextColor, height: 1.5, fontSize: 15) ?? const TextStyle(color: kBrightTextColor, height: 1.5, fontSize: 15);
    final h1Style = Theme.of(context).textTheme.headlineSmall?.copyWith(color: kBrightTextColor, fontWeight: FontWeight.bold) ?? baseTextStyle.copyWith(fontSize: 24, fontWeight: FontWeight.bold);
    final h2Style = Theme.of(context).textTheme.titleLarge?.copyWith(color: kBrightTextColor, fontWeight: FontWeight.bold) ?? baseTextStyle.copyWith(fontSize: 20, fontWeight: FontWeight.bold);
    // ---

    return Scaffold(
      body: Container( // Основной фон
        width: double.infinity, height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient( colors: [kHomeBgGradStart, kHomeBgGradMid, kHomeBgGradEnd], begin: Alignment.topCenter, end: Alignment.bottomCenter, ),
        ),
        child: Column( // Размещаем AppBar и контент
          children: [
            // --- AppBar ---
            AppBar(
              leading: IconButton(
                icon: const Icon(Icons.home_outlined, color: kIconColor, size: 28),
                tooltip: 'На главный экран',
                onPressed: () async {
                  await _grantScoreIfNeeded();
                  Navigator.of(context).popUntil((route) {
                    if (route.isFirst) {
                      // Передаём результат true на главный экран
                      (route.settings as PageRoute).navigator?.context as Element?;
                      // Попробуем вызвать pop с результатом
                      Navigator.of(context).pop(true);
                      return true;
                    }
                    return false;
                  });
                },
              ),
              title: Text( "Уровень ${widget.completedLevel.levelNumber ?? '??'} пройден!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kBrightTextColor), ),
              centerTitle: true, backgroundColor: kHomeBgGradStart, elevation: 0,
              flexibleSpace: Container( decoration: BoxDecoration( gradient: LinearGradient(colors: [kAppBarGradStart.withAlpha((0.8 * 255).toInt()), kAppBarGradEnd.withAlpha((0.8 * 255).toInt())], begin: Alignment.topLeft, end: Alignment.bottomRight,), ),),
              // actions: [ IconButton(icon: const Icon(Icons.share_outlined, color: kIconColor), onPressed: () {/* TODO */}) ],
            ),
            // --- Контент ---
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(15.0, 15.0, 15.0, 20.0), // Общие отступы
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // --- Блок с Категорией и Фразой/Фактом ---
                    Container(
                      width: double.infinity, padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration( color: kContainerBgColor, borderRadius: BorderRadius.circular(15.0), border: Border.all(color: kContainerBorderColor) ),
                      child: Column( crossAxisAlignment: CrossAxisAlignment.center, children: [
                        Text( categoryText, textAlign: TextAlign.center, style: TextStyle( fontSize: 18, fontWeight: FontWeight.bold, color: kAccentColor, letterSpacing: 0.8, ), ), // Акцентный цвет
                        const SizedBox(height: 12),
                        Text( phraseText, textAlign: TextAlign.center, style: TextStyle( fontSize: 19, fontWeight: FontWeight.w600, color: kBrightTextColor, height: 1.4, ), ),
                      ],
                      ),
                    ),
                    const SizedBox(height: 25),

                    // --- Блок Объяснения факта (Markdown) ---
                    if (explanation != null && explanation.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 25.0),
                        child: Container(
                          width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 15.0),
                          decoration: BoxDecoration( color: kContainerDarkerBgColor, borderRadius: BorderRadius.circular(10.0), border: Border.all(color: kContainerBorderColor.withAlpha((0.5 * 255).toInt())) ),
                          child: MarkdownBody(
                            data: explanation, selectable: true,
                            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith( // Стили Markdown для темного фона
                              p: baseTextStyle, h1: h1Style, h2: h2Style, listBullet: baseTextStyle, strong: TextStyle(fontWeight: FontWeight.bold, color: kBrightTextColor), em: TextStyle(fontStyle: FontStyle.italic, color: kBrightTextColor),
                              blockquote: baseTextStyle.copyWith(color: kSubtleTextColor), blockquotePadding: const EdgeInsets.only(left: 20.0),
                              blockquoteDecoration: BoxDecoration( color: Colors.transparent, border: Border( left: BorderSide( color: kAppBarGradEnd.withAlpha((0.8 * 255).toInt()), width: 4.0,), ), ),
                              horizontalRuleDecoration: BoxDecoration( border: Border(top: BorderSide(width: 1.0, color: kSubtleTextColor.withAlpha((0.5 * 255).toInt()))) ),
                            ),
                          ),
                        ),
                      ),
                    // --- Конец блока объяснения ---

                    // --- Блок Вопросы и Ответы ---
                    Text( "Вопросы и ответы", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kSubtleTextColor), ),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0, left: 16.0, right: 16.0),
                      decoration: BoxDecoration( color: kContainerDarkerBgColor, borderRadius: BorderRadius.circular(10.0), ),
                      child: Column(
                        children: widget.completedLevel.questions.map((q) {
                          final questionText = q.question ?? '?'; final answerText = q.answer?.toUpperCase() ?? '?';
                          return Padding( padding: const EdgeInsets.symmetric(vertical: 10.0), child: Row( crossAxisAlignment: CrossAxisAlignment.start, children: [ Expanded( flex: 3, child: Text( questionText, style: TextStyle(fontSize: 15, color: kSubtleTextColor, height: 1.3), ), ), const SizedBox(width: 15), Expanded( flex: 2, child: Text( answerText, textAlign: TextAlign.end, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kBrightTextColor), ), ), ], ), ); }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ), // Конец Expanded контента

            // --- Кнопка Продолжить (Стилизована) ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 20.0),
              child: Container( // Внешний контейнер для градиента и формы
                decoration: BoxDecoration(
                  gradient: LinearGradient( // Бирюзовый градиент
                      colors: [kLevelsBtnGradStart, kLevelsBtnGradEnd],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight),
                  borderRadius: BorderRadius.circular(30.0), // Скругление
                  boxShadow: [ // Свечение
                    BoxShadow( color: kLevelsBtnGlow.withAlpha((0.7 * 255).toInt()), blurRadius: 15, spreadRadius: 1, ),
                    BoxShadow( color: kHomeBgGradStart.withAlpha((0.15 * 255).toInt()), offset: Offset(0, 3), blurRadius: 5, ),
                  ],
                ),
                child: ElevatedButton.icon(
                  icon: Icon(Icons.arrow_forward_ios_rounded, size: 18, color: kLevelsBtnText), // Иконка
                  label: Text( // Текст кнопки
                    isLastLevel ? "К списку уровней" : "Продолжить",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kLevelsBtnText),
                  ),
                  onPressed: () async {
                    await _grantScoreIfNeeded();
                    if (isLastLevel) {
                      _logger.info("Last level completed! Returning to Level Select.");
                      if (Navigator.canPop(context)) {
                        Navigator.popUntil(context, (route) {
                          if (route.isFirst) {
                            Navigator.of(context).pop(true);
                            return true;
                          }
                          return false;
                        });
                      } else {
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LevelSelectScreen()));
                      }
                    } else {
                      _logger.info("Navigating to next level: $nextLevelNumber");
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => GameScreen(levelNumber: nextLevelNumber)),
                      );
                    }
                  },
                  // Стиль самой кнопки (делаем прозрачной)
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent, // Прозрачный фон
                    shadowColor: Colors.transparent, // Убираем тень кнопки
                    elevation: 0, // Убираем возвышение кнопки
                    minimumSize: const Size(double.infinity, 54), // Задаем размер
                    shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(30.0), ), // Форма для ripple эффекта
                    padding: const EdgeInsets.symmetric(vertical: 14.0), // Внутренний отступ
                  ),
                ), // Конец ElevatedButton.icon
              ), // Конец Container
            ), // Конец Padding кнопки
            // --- Конец кнопки ---
          ],
        ), // Конец SafeArea
      ), // Конец Container фона
    );
  }
}