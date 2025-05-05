import 'package:flutter/material.dart';
import 'package:qazcros/theme/app_colors.dart' as app_colors;
import 'dart:math' as math;
// import 'dart:async'; // <--- удалён, больше не нужен
import 'package:flutter/foundation.dart'; // Для listEquals
import 'package:logging/logging.dart'; // <-- ДОБАВЛЕН ИМПОРТ LOGGING
import '../services/audio_service.dart'; // <-- ИМПОРТ АУДИО СЕРВИСА
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/shop_modal.dart';
import 'leaderboard_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/statistics_widget.dart'; // Импортируем виджет статистики

// --- Замените на ваши реальные пути ---
import 'level_select_screen.dart';
import 'game_screen.dart';
import '../widgets/home_level_indicator.dart'; // Импорт индикатора
import '../services/progress_service.dart'; // <-- ИМПОРТ СЕРВИСА ПРОГРЕССА
import 'settings_screen.dart'; // <-- ИМПОРТ СЕТТИНГС СКРИНА
// ---

// --- StatefulWidget ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // --- Состояние для прогресса ---
  int _overallCurrentLevel = 1; // Номер первого НЕПРОЙДЕННОГО уровня
  bool _isLoading = true; // Флаг загрузки прогресса
  final ProgressService _progressService = ProgressService();
  final _logger = Logger('HomeScreen'); // <-- СОЗДАН ЭКЗЕМПЛЯР LOGGER
  DateTime? _lastFreeHintTime;
  static const Duration freeHintCooldown = Duration(hours: 6);
  bool _freeHintAvailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProgress();
    AudioService().playMusic();
    _loadFreeHintTime();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AudioService().stopMusic();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      AudioService().stopMusic();
    } else if (state == AppLifecycleState.resumed) {
      AudioService().playMusic();
      _loadProgress();
    }
  }

  // Метод для загрузки прогресса
  Future<void> _loadProgress() async {
    // Устанавливаем isLoading в true перед началом загрузки
    if (!mounted) return;
    setState(() { _isLoading = true; });

    _logger.info("[HomeScreen] Loading progress..."); // <-- ЗАМЕНА PRINT НА _LOGGER.INFO
    try {
      // Загружаем множество пройденных уровней
      final loadedCompleted = await _progressService.loadCompletedLevels();
      // Рассчитываем следующий уровень для игры (первый не пройденный)
      final int nextLevel = loadedCompleted.isEmpty
          ? 1
          : (loadedCompleted.reduce(math.max) + 1);

      // TODO: Установите РЕАЛЬНОЕ максимальное кол-во уровней
      const int maxTotalLevel = 100; // Пример
      // Ограничиваем максимальным уровнем, если все пройдено
      final int currentLevelToShow = math.min(nextLevel, maxTotalLevel);

      if (mounted) { // Проверяем перед финальным setState
        setState(() {
          _overallCurrentLevel = currentLevelToShow;
          _isLoading = false; // Загрузка завершена
        });
        _logger.info("[HomeScreen] Progress loaded. Current level to play: $_overallCurrentLevel"); // <-- ЗАМЕНА PRINT НА _LOGGER.INFO
      }
    } catch(e, s) { // Ловим ошибку и стэк трейс
      _logger.severe("[HomeScreen] Error loading progress: $e"); // <-- ЗАМЕНА PRINT НА _LOGGER.SEVERE
      _logger.severe(s.toString()); // <-- ЗАМЕНА PRINT НА _LOGGER.SEVERE
      if (mounted) {
        setState(() {
          _isLoading = false; // Завершаем загрузку в любом случае
          // Можно показать сообщение об ошибке пользователю
          // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка загрузки прогресса")));
        });
      }
    }
  }

  Future<void> _loadFreeHintTime() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt('lastFreeHintTime');
    if (millis != null) {
      _lastFreeHintTime = DateTime.fromMillisecondsSinceEpoch(millis);
      _updateFreeHintAvailability();
    } else {
      _freeHintAvailable = true;
    }
    setState(() {});
  }

  void _updateFreeHintAvailability() {
    if (_lastFreeHintTime == null) {
      _freeHintAvailable = true;
      return;
    }
    final now = DateTime.now();
    final nextAvailable = _lastFreeHintTime!.add(freeHintCooldown);
    _freeHintAvailable = now.isAfter(nextAvailable);
  }

  void _onShopPressed() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ShopModal(
        onFreeHintTaken: _onFreeHintTaken,
        lastFreeHintTime: _lastFreeHintTime,
        cooldown: freeHintCooldown,
      ),
    );
    _loadFreeHintTime();
  }

  void _onFreeHintTaken() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setInt('lastFreeHintTime', now.millisecondsSinceEpoch);
    setState(() {
      _lastFreeHintTime = now;
      _freeHintAvailable = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const double backgroundOverlayOpacity = 0.2;

    // --- Вычисляем показатели для индикатора ---
    // Номер текущей КАТЕГОРИИ (1, 2, 3...) для отображения в центре
    final int categoryNumberForDisplay = _isLoading ? 1 : ((_overallCurrentLevel - 1) / 10).floor() + 1;
    // Количество пройденных УРОВНЕЙ в текущем 10-уровневом блоке (0-9)
    final int levelsDoneInCurrentBlock = _isLoading ? 0 : (_overallCurrentLevel - 1) % 10;
    // Прогресс для индикатора (0.0 - 1.0)
    final double progressValue = _isLoading ? 0.0 : (levelsDoneInCurrentBlock / 10.0).clamp(0.0, 1.0);
    // --- ОТЛАДОЧНЫЙ PRINT ---
    _logger.info("[HomeScreen Build] isLoading: $_isLoading, OverallLevel: $_overallCurrentLevel, DisplayCategory: $categoryNumberForDisplay, DoneInBlock: $levelsDoneInCurrentBlock, ProgressValue: $progressValue"); // <-- ЗАМЕНА PRINT НА _LOGGER.INFO
    // ---

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Слой 1: Фоновое Изображение
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background_main.png'), // <-- ВАШ ПУТЬ!
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Слой 2: Затемняющий Оверлей
          Container( color: app_colors.kHomeBgGradMid.withAlpha((backgroundOverlayOpacity * 255).toInt()), ),
          // Слой 3: Основной Контент
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
              child: Column(
                children: [
                  // --- Верхняя панель ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(width: 40),
                      Column(
                        children: [
                          const Text(
                            'Crostic',
                            style: TextStyle(
                              color: app_colors.kHomeLogoColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 26,
                              letterSpacing: 1.5,
                              shadows: [Shadow(offset: Offset(1,1), blurRadius: 2, color: app_colors.kHomeLogoShadow)]
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.star, color: app_colors.kAccentColorYellow, size: 20),
                              const SizedBox(width: 4),
                              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                stream: FirebaseAuth.instance.currentUser == null
                                  ? null
                                  : FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).snapshots(),
                                builder: (context, snapshot) {
                                  int score = 0;
                                  if (snapshot.hasData && snapshot.data != null && snapshot.data!.data() != null) {
                                    score = (snapshot.data!.data()!['score'] ?? 0) as int;
                                  }
                                  return Text(
                                    'Очки: $score',
                                    style: const TextStyle(
                                      color: app_colors.kAccentColorYellow,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white),
                        tooltip: 'Настройки',
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SettingsScreen()),
                          );
                          if (result == true) {
                            Future.delayed(const Duration(milliseconds: 500), _loadProgress);
                          }
                        },
                      ),
                    ],
                  ), // --- Конец верхней панели ---

                  const SizedBox(height: 15),

                  // --- Второстепенные кнопки ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 10.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSubtleButton( text: 'Без рекламы', icon: Icons.shield_outlined, onTap: () { _logger.info("No ads button tapped"); /* TODO */ }, ),
                        _buildSubtleButton( text: 'Лидеры', icon: Icons.emoji_events_outlined, onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LeaderboardScreen()),
                          );
                        }, ),
                        _buildSubtleButton( text: 'Статистика', icon: Icons.bar_chart_rounded, onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => Dialog(
                              backgroundColor: Colors.transparent,
                              insetPadding: const EdgeInsets.all(16),
                              child: StatisticsWidget(),
                            ),
                          );
                        }, ),
                      ],
                    ),
                  ), // --- Конец второстепенных кнопок ---

                  // --- Центральная часть ---
                  Expanded(
                    flex: 5, // Даем больше места центру
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // --- Центральный элемент (Индикатор) ---
                        // Показываем индикатор загрузки, пока реальные данные не получены
                        _isLoading
                            ? const CircularProgressIndicator(color: app_colors.kLevelsBtnGradEnd)
                            : Container( // Контейнер для свечения
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [ BoxShadow( color: app_colors.kHomeCircleGlow, blurRadius: 30, spreadRadius: 2, ), ]
                          ),
                          child: HomeLevelIndicator( // Наш виджет
                            currentLevel: categoryNumberForDisplay, // Показываем номер КАТЕГОРИИ
                            progress: progressValue, // Передаем прогресс 0.0 - 1.0
                            size: 250, // Увеличенный размер
                          ),
                        ),
                      ],
                    ),
                  ), // Конец Expanded для центра

                  // --- Основные кнопки действий с фоном ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
                    width: screenWidth * 0.85, // Ширина фона кнопок
                    decoration: BoxDecoration(
                        color: app_colors.kHomeBgGradMid.withAlpha((0.2 * 255).toInt()), // Используем константу
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: app_colors.kHomeCircleBorder.withAlpha((0.2 * 255).toInt())) // Используем константу
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Кнопка "Уровни" (Первая)
                        _buildActionButton(
                          text: 'Уровни', icon: Icons.apps_rounded,
                          gradient: const LinearGradient(colors: [app_colors.kLevelsBtnGradStart, app_colors.kLevelsBtnGradEnd]),
                          glowColor: app_colors.kLevelsBtnGlow,
                          onTap: () async { // Делаем async для await Navigator.push
                            // Переходим и ждем возврата, чтобы обновить прогресс
                            await Navigator.push( context, MaterialPageRoute(builder: (_) => const LevelSelectScreen()), );
                            _loadProgress(); // Перезагружаем прогресс после возврата
                          },
                        ),
                        const SizedBox(height: 15), // Отступ
                        // Кнопка "Играть" (Вторая)
                        _buildActionButton(
                          text: 'Играть', icon: Icons.play_arrow_rounded,
                          gradient: const LinearGradient( colors: [app_colors.kPlayBtnGradStart, app_colors.kPlayBtnGradEnd] ),
                          glowColor: app_colors.kPlayBtnGlow,
                          onTap: () async { // Делаем async
                            if (!_isLoading) { // Переходим только если загрузка завершена
                              _logger.info("Play button tapped - Go to level $_overallCurrentLevel");
                              // Переходим и ждем возврата
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute( builder: (_) => GameScreen(levelNumber: _overallCurrentLevel), ),
                              );
                              if (result == true && mounted) {
                                setState(() {}); // Пересоздаём StreamBuilder и обновляем прогресс
                                _loadProgress();
                              } else {
                                _loadProgress(); // На всякий случай
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 15),
                        _buildActionButton(
                          text: _freeHintAvailable ? 'Заберите подарок' : 'Магазин',
                          icon: Icons.card_giftcard,
                          gradient: const LinearGradient(colors: [app_colors.kPlayBtnGradStart, app_colors.kPlayBtnGradEnd]),
                          glowColor: app_colors.kPlayBtnGlow,
                          onTap: _onShopPressed,
                        ),
                      ], // Конец Column children
                    ), // Конец Container фона
                  ), // --- Конец контейнера основных кнопок ---

                  const Spacer(flex: 1), // Уменьшил нижний отступ

                ], // Конец children основного Column
              ), // Конец Padding
            ), // Конец SafeArea
          ), // Конец контента (Слой 3)
        ], // Конец Stack children
      ), // Конец Stack
    ); // Конец Scaffold
  } // Конец build method

  // Хелпер для ОСНОВНЫХ кнопок
  Widget _buildActionButton(
      {required String text,
        required IconData icon,
        required Gradient gradient,
        required Color glowColor,
        required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: glowColor.withAlpha((0.6 * 255).toInt()),
              blurRadius: 15,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: app_colors.kHomeShadow.withAlpha((0.2 * 255).toInt()),
              offset: const Offset(0, 3),
              blurRadius: 5,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: app_colors.kPlayBtnIcon, size: 26),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(
                  fontSize: 20,
                  color: app_colors.kPlayBtnText,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  shadows: [
                    Shadow(
                        offset: Offset(1, 1),
                        blurRadius: 1,
                        color: app_colors.kHomeShadow)
                  ]),
            ),
          ],
        ),
      ),
    );
  }

  // Хелпер для ВТОРОСТЕПЕННЫХ кнопок
  Widget _buildSubtleButton({required String text, required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 90, maxWidth: 100), // Ограничим ширину для выравнивания
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), // Паддинг
        decoration: BoxDecoration(
          // Используем яркий бирюзовый градиент (как у кнопки "Уровни")
          gradient: const LinearGradient(
            colors: [app_colors.kLevelsBtnGradStart, app_colors.kLevelsBtnGradEnd], // Бирюзовые цвета
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15), // Скругленные углы
          boxShadow: [ // Соответствующее свечение
            BoxShadow(
              color: app_colors.kLevelsBtnGlow.withAlpha((0.6 * 255).toInt()), // Бирюзовое свечение
              blurRadius: 8,
              spreadRadius: 0,
            )
          ],
          // Убрали рамку
          // border: Border.all(color: AppColors.kSubtleBtnBorder.withAlpha((0.5 * 255).toInt())),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: app_colors.kLevelsBtnIcon, size: 24), // Используем белый цвет иконки
            const SizedBox(height: 4),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: app_colors.kLevelsBtnText, // Используем белый цвет текста
                  fontSize: 11,
                  fontWeight: FontWeight.w600 // Чуть жирнее
              ),
              maxLines: 2, // Разрешим перенос на 2 строки, если текст длинный
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

} // Конец _HomeScreenState Class

// --- Класс LevelProgressPainter (НАХОДИТСЯ В ФАЙЛЕ home_level_indicator.dart) ---
// Убедитесь, что этот класс импортирован выше
// class LevelProgressPainter extends CustomPainter { ... }
// ---