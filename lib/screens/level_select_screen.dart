import 'package:flutter/material.dart';
import 'dart:async'; // Для Future и Timer (если понадобится)
import 'dart:math' as math; // Для max и floorToDouble
import 'package:logging/logging.dart'; // Добавлен импорт logging

// --- Замените на ваши реальные пути к файлам ---
import 'game_screen.dart';                      // Экран игры
import 'level_complete_screen.dart'; // Импорт экрана завершения
// ВАЖНО: Убедитесь, что эти модели определены (включая CategoryModel с полем imageAssetPath)
import '../models/level_status.dart';          // Модели статуса, уровня, категории
import '../models/level_model.dart';             // Ваша основная модель уровня
import '../services/progress_service.dart';     // Сервис сохранения/загрузки
import '../data/levels_loader.dart';          // Загрузчик уровней из JSON
import 'package:qazcros/theme/app_colors.dart' as app_colors; // Импорт цветов с алиасом для избежания конфликтов

// --- КОНСТАНТЫ ЦВЕТОВ (Скопированные из HomeScreen/Новой палитры) ---
// Фон (для оверлея)
// const Color kHomeBgGradStart = Color(0xFF191821); // Не используется здесь
// const Color kHomeBgGradMid = Color(0xFF2C2438);   // Может пригодиться
// const Color kHomeBgGradEnd = Color(0xFF14111C);
// AppBar / Карточки категорий (если нужны)
// const Color kCardGradientStart = Color(0xFF4E54C8);
// const Color kCardGradientEnd = Color(0xFF8F94FB);
// Статусы уровней
// const Color kPlayBtnGradStart = Color(0xFFFFA35D); // Для inProgress (оранжевый)
// const Color kPlayBtnGradEnd = Color(0xFFF58529);
// const Color kLevelsBtnGradStart = Color(0xFF29a99d); // Для completed (бирюзовый)
// const Color kLevelsBtnGradEnd = Color(0xFF57FFED);
// const Color kLockedColor = Color(0x66616161);       // Для locked
// const Color kLockedIconColor = Color(0xFFBDBDBD);    // Для locked иконки
// Текст и Иконки
// const Color kBrightTextColor = Color(0xFFFFFFFF);    // Для заголовков и активных иконок
// const Color kSubtleTextColor = Color(0xFFCFD8DC);    // Для доп. текста
// const Color kIconColor = Color(0xFFFFFFFF);          // Для AppBar иконки
// const Color kLevelsBtnText = Colors.white;         // Текст/Иконка для Completed/Levels
// const Color kPlayBtnText = Colors.white;           // Текст/Иконка для InProgress/Play
// Свечение (для иконки статуса InProgress)
// const Color kPlayBtnGlow = Color(0x88D59F0D);     // Оранжевое свечение для InProgress
// Плейсхолдер и Загрузка
// const Color kPlaceholderImageColor = Color(0x338F94FB);
// const Color kAccentGradientMid = Color(0xFFFBD786); // Для индикатора загрузки
// --- КОНЕЦ КОНСТАНТ ЦВЕТОВ ---


class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  List<CategoryModel> _categories = []; // Список моделей категорий с уровнями
  bool _isLoading = true; // Флаг состояния загрузки
  int? _currentLevelNumber; // Номер первого НЕпройденного уровня
  Set<int> _completedLevels = {}; // Множество номеров пройденных уровней
  int _maxLevel = 0; // Максимальный номер уровня в игре

  final ProgressService _progressService = ProgressService(); // Сервис для работы с прогрессом
  final ScrollController _scrollController = ScrollController(); // Контроллер для прокрутки
  // Используем ключи для возможности прокрутки к категории
  final Map<String, GlobalKey> _categoryKeys = {};

  final _logger = Logger('LevelSelectScreen'); // Создан экземпляр Logger

  @override
  void initState() {
    super.initState();
    _loadDataAndScroll(); // Запускаем загрузку данных при инициализации
  }

  @override
  void dispose() {
    _scrollController.dispose(); // Освобождаем контроллер прокрутки
    super.dispose();
  }

  // Основной метод загрузки данных уровней, прогресса и планирования прокрутки
  Future<void> _loadDataAndScroll() async {
    if (!mounted) return; // Проверка, активен ли виджет
    setState(() { _isLoading = true; }); // Показываем индикатор загрузки
    _logger.info("[DEBUG] _loadDataAndScroll: Start. isLoading = true."); // Заменен print на _logger.info
    String? errorLoading; // Переменная для хранения текста ошибки

    try {
      _logger.info("[DEBUG] _loadDataAndScroll: Loading progress..."); // Заменен print на _logger.info
      // Загружаем пройденные уровни
      _completedLevels = await _progressService.loadCompletedLevels();
      _logger.info("[DEBUG] _loadDataAndScroll: Progress loaded (${_completedLevels.length} levels)."); // Заменен print на _logger.info

      _logger.info("[DEBUG] _loadDataAndScroll: Loading all level data..."); // Заменен print на _logger.info
      // Загружаем все уровни, сгруппированные по категориям
      final Map<String, List<LevelModel>> groupedLevels =
      await LevelsLoader.loadAllLevelsGroupedByCategory();
      _logger.info("[DEBUG] _loadDataAndScroll: Level data loaded (${groupedLevels.length} categories)."); // Заменен print на _logger.info

      if (groupedLevels.isEmpty) {
        errorLoading = "Не удалось загрузить данные уровней.";
        _logger.info("[DEBUG] _loadDataAndScroll: No categories loaded."); // Заменен print на _logger.info
      } else {
        // --- Вычисление текущего и максимального уровня ---
        _logger.info("[DEBUG] _loadDataAndScroll: Calculating maxLevel and currentLevel..."); // Заменен print на _logger.info
        _maxLevel = 0; // Сбрасываем перед пересчетом
        // Находим максимальный номер уровня среди всех загруженных
        groupedLevels.values.expand((levels) => levels).forEach((level) {
          _maxLevel = math.max(_maxLevel, level.levelNumber ?? 0);
        });

        // Определяем первый не пройденный уровень
        _currentLevelNumber = _completedLevels.isEmpty
            ? 1
            : (_completedLevels.isNotEmpty
            ? (_completedLevels.reduce(math.max) + 1)
            : 1);
        // Ограничиваем текущий уровень максимальным, если все пройдено
        if (_currentLevelNumber != null && _currentLevelNumber! > _maxLevel && _maxLevel > 0) {
          _currentLevelNumber = _maxLevel;
          _logger.info("[DEBUG] _loadDataAndScroll: All levels completed? Setting current to maxLevel."); // Заменен print на _logger.info
        }
        _logger.info("[DEBUG] _loadDataAndScroll: MaxLevel=$_maxLevel, CurrentLevel=$_currentLevelNumber"); // Заменен print на _logger.info


        // --- Формирование моделей категорий ---
        _logger.info("[DEBUG] _loadDataAndScroll: Generating category models..."); // Заменен print на _logger.info
        List<CategoryModel> tempCategories = [];
        _categoryKeys.clear(); // Очищаем старые ключи

        List<String> sortedCategoryNames = groupedLevels.keys.toList();
        // TODO: Раскомментируйте, если нужна сортировка категорий по имени
        // sortedCategoryNames.sort();

        // Используем цикл for с индексом для автоматического назначения картинок
        for (int i = 0; i < sortedCategoryNames.length; i++) {
          final String categoryName = sortedCategoryNames[i];
          _logger.info("[DEBUG] _loadDataAndScroll: Processing category '$categoryName' at index $i"); // Заменен print на _logger.info

          final levelsInCat = groupedLevels[categoryName]!;
          if (levelsInCat.isEmpty) continue; // Пропускаем пустые категории

          final categoryKey = GlobalKey(); // Создаем ключ для этой категории
          _categoryKeys[categoryName] = categoryKey;
          List<LevelInfoModel> levelInfoList = [];

          // Определение статуса для каждого уровня в категории
          for (var levelModel in levelsInCat) {
            int levelNum = levelModel.levelNumber ?? 0;
            if (levelNum == 0) continue; // Пропускаем уровни без номера

            LevelStatus status;
            if (_completedLevels.contains(levelNum)) {
              status = LevelStatus.completed; // Уровень пройден
            } else if (levelNum == _currentLevelNumber) {
              status = LevelStatus.inProgress; // Текущий уровень для игры
            } else {
              // Уровень заблокирован, если он не пройден и не является текущим
              status = LevelStatus.locked;
            }
            levelInfoList.add(LevelInfoModel(levelNumber: levelNum, status: status));
          }

          // Сортируем уровни внутри категории по номеру
          levelInfoList.sort((a, b) => a.levelNumber.compareTo(b.levelNumber));

          // --- Динамическое формирование имени файла картинки ---
          final int imageNumber = i + 1; // Индекс 0 -> Номер 1, Индекс 1 -> Номер 2, ...
          final String imageFileName = "category_$imageNumber.png"; // Формат имени файла
          final String imagePath = "assets/category_images/$imageFileName"; // Полный путь
          _logger.info("[DEBUG] _loadDataAndScroll: Category '$categoryName' dynamically assigned image '$imagePath'"); // Заменен print на _logger.info
          // ---

          // Создаем модель категории с динамическим путем к картинке
          tempCategories.add(CategoryModel(
            name: categoryName,
            levels: levelInfoList,
            imageAssetPath: imagePath, // Используем созданный путь
          ));
        }
        _categories = tempCategories; // Присваиваем готовый список категорий
        _logger.info("[DEBUG] _loadDataAndScroll: Category models generated (${_categories.length})."); // Заменен print на _logger.info
      } // Конец else (если уровни загружены)

    } catch (e, stacktrace) {
      _logger.severe("[DEBUG] _loadDataAndScroll: ERROR loading data: $e"); // Заменен print на _logger.severe
      _logger.severe("[DEBUG] _loadDataAndScroll: Stacktrace: $stacktrace"); // Заменен print на _logger.severe
      errorLoading = "Ошибка загрузки данных: $e";
    } finally {
      _logger.info("[DEBUG] _loadDataAndScroll: Entering FINALLY block. Mounted: $mounted"); // Заменен print на _logger.info
      if (mounted) {
        setState(() { _isLoading = false; }); // Завершаем загрузку
        _logger.info("[DEBUG] _loadDataAndScroll: FINALLY - setState finished. isLoading is now $_isLoading."); // Заменен print на _logger.info
        // Показываем Snackbar с ошибкой, если она была
        if (errorLoading != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(errorLoading),
            backgroundColor: app_colors.kErrorColor,
          ));
        } else if (_categories.isNotEmpty) {
          // Планируем прокрутку только если все загрузилось успешно
          _logger.info("[DEBUG] _loadDataAndScroll: Scheduling scroll callback."); // Заменен print на _logger.info
          // Используем addPostFrameCallback для выполнения после завершения build'а
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _logger.info("[DEBUG] _loadDataAndScroll: Inside scroll callback. Mounted: $mounted"); // Заменен print на _logger.info
            if (mounted) { _scrollToCurrentCategory(); } // Выполняем прокрутку
          });
        }
      } else {
        _logger.info("[DEBUG] _loadDataAndScroll: FINALLY - Widget unmounted. Skipping setState."); // Заменен print на _logger.info
      }
    }
    _logger.info("[DEBUG] _loadDataAndScroll: End of method."); // Заменен print на _logger.info
  } // --- Конец _loadDataAndScroll ---

  // --- Логика прокрутки к текущей категории ---
  void _scrollToCurrentCategory() {
    if (_currentLevelNumber == null || _categories.isEmpty || !_scrollController.hasClients) {
      _logger.info("LevelSelect: Scroll conditions not met."); // Заменен print на _logger.info
      return;
    }
    // Находим категорию, к которой принадлежит текущий НЕПРОЙДЕННЫЙ уровень
    CategoryModel? currentCategory;
    try {
      currentCategory = _categories.firstWhere((cat) => cat.levels.any((lvl) => lvl.levelNumber == _currentLevelNumber));
    } catch (e) {
      _logger.severe("Error finding category for level $_currentLevelNumber: $e"); // Заменен print на _logger.severe
      currentCategory = null;
    }

    if (currentCategory != null) {
      final categoryKey = _categoryKeys[currentCategory.name];
      // Проверяем, что ключ и контекст существуют
      if (categoryKey != null && categoryKey.currentContext != null) {
        _logger.info("LevelSelect: Scrolling to category ${currentCategory.name}"); // Заменен print на _logger.info
        // Плавно прокручиваем к найденному ключу
        Scrollable.ensureVisible(
          categoryKey.currentContext!, // <-- Используем '!' после проверки
          duration: const Duration(milliseconds: 600), // Длительность анимации
          curve: Curves.easeInOut, // Плавность анимации
          alignment: 0.05, // Выравнивание (0.0 - верх, 0.5 - центр, 1.0 - низ)
        );
      } else { _logger.info("LevelSelect: Key/Context not found for category ${currentCategory.name}"); } // Заменен print на _logger.info
    } else { _logger.info("LevelSelect: Category containing level $_currentLevelNumber not found for scrolling."); } // Заменен print на _logger.info
  }

  // --- Метод Build ---
  @override
  Widget build(BuildContext context) {
    // --- Расчет размеров иконок ---
    final screenWidth = MediaQuery.of(context).size.width;
    final double listHorizontalPadding = 15.0;
    final double availableWidth = screenWidth - (listHorizontalPadding * 2);
    const int numberOfIcons = 10; // Иконок в ряду
    const double minIconSpacing = 4.0; const double maxIconSpacing = 8.0;
    const double minIconSize = 26.0; // Минимальный базовый размер иконки
    double iconSpacing = maxIconSpacing;
    double iconContainerSize = (availableWidth - (numberOfIcons - 1) * iconSpacing) / numberOfIcons;
    if (iconContainerSize < minIconSize) { iconSpacing = minIconSpacing; iconContainerSize = (availableWidth - (numberOfIcons - 1) * iconSpacing) / numberOfIcons; }
    iconContainerSize = math.max(minIconSize, iconContainerSize);
    // --- ИЗМЕНЕНО: Уменьшаем размер иконки ---
    final double finalIconSize = (iconContainerSize - 2.0).clamp(minIconSize, 100.0); // Уменьшаем на 2 пикселя и ограничиваем снизу
    // ---
    iconSpacing = (iconSpacing * 10).floorToDouble() / 10; // Округляем отступ
    // --- Конец расчета ---

    // Настройка прозрачности оверлея фона
    const double backgroundOverlayOpacity = 0.3; // Сделал чуть светлее

    return Scaffold(
      // Используем Stack для фона и контента
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Слой 1: Фон (картинка)
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                // !! ЗАМЕНИТЕ НА ВАШ ПУТЬ К ФОНУ !!
                image: AssetImage('assets/images/background_main.png'), // Можно другой фон
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Слой 2: Затемнение
          Container(color: app_colors.kHomeBgGradStart.withAlpha((backgroundOverlayOpacity * 255).toInt())),
          // Слой 3: Основной Контент
          Column(
            children: [
              AppBar( // AppBar остается для заголовка и кнопки назад
                title: Text('Выбор уровня', style: TextStyle(color: app_colors.kBrightTextColor, fontWeight: FontWeight.bold, letterSpacing: 1.1),),
                backgroundColor: Colors.transparent, // Прозрачный AppBar
                elevation: 0, // Убираем тень AppBar
                iconTheme: IconThemeData(color: app_colors.kIconColor), // Цвет кнопки "назад"
                // Оставляем градиент под AppBar для визуального разделения
                flexibleSpace: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [app_colors.kCardGradientStart.withAlpha((0.85 * 255).toInt()), app_colors.kCardGradientEnd.withAlpha((0.85 * 255).toInt())], // Полупрозрачный градиент
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              Expanded( // Основной контент (список категорий или индикатор загрузки)
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(app_colors.kAccentGradientMid)))
                    : _categories.isEmpty
                    ? Center(child: Text("Уровни не найдены.", style: TextStyle(color: app_colors.kSubtleTextColor, fontSize: 16)))
                    : ListView.builder( // Список категорий
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(horizontal: listHorizontalPadding, vertical: 20.0),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final categoryKey = _categoryKeys[category.name] ?? GlobalKey(); // Используем или создаем новый ключ

                    // --- Виджет одной категории ---
                    return Padding(
                      key: categoryKey, // Привязываем ключ
                      padding: const EdgeInsets.only(bottom: 30.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Название категории
                          Padding(
                            padding: const EdgeInsets.only(left: 5.0, bottom: 10.0),
                            child: Text( category.name, style: TextStyle( fontSize: 20, fontWeight: FontWeight.bold, color: app_colors.kBrightTextColor, shadows: [ Shadow(offset: Offset(1, 1), blurRadius: 2, color: app_colors.kHomeBgGradStart) ] ), ),
                          ),
                          // 2. Картинка категории
                          AspectRatio(
                            aspectRatio: 16 / 9, // Соотношение сторон
                            child: Container(
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15.0),
                                  color: app_colors.kPlaceholderImageColor, // Фон на случай ошибки
                                  boxShadow: [ BoxShadow(color: app_colors.kHomeBgGradStart.withAlpha((0.3 * 255).toInt()), blurRadius: 8, offset: Offset(0, 4)) ] // Тень для картинки
                              ),
                              child: ClipRRect( // Обрезаем картинку по радиусу
                                borderRadius: BorderRadius.circular(15.0),
                                child: Image.asset(
                                  category.imageAssetPath, // Путь из модели
                                  fit: BoxFit.cover, // Масштабируем для заполнения
                                  // Обработчик ошибок загрузки картинки
                                  errorBuilder: (context, error, stackTrace) {
                                    _logger.severe("Error loading category image ${category.imageAssetPath}: $error"); // Заменен print на _logger.severe
                                    return Center(child: Icon(Icons.image_not_supported_outlined, color: app_colors.kLockedIconColor, size: 40)); // Другая иконка ошибки
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          // 3. Ряд иконок уровней
                          SizedBox(
                            height: finalIconSize, // Используем УМЕНЬШЕННЫЙ размер
                            child: ListView.separated( // Горизонтальный список иконок
                                scrollDirection: Axis.horizontal,
                                itemCount: category.levels.length,
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                separatorBuilder: (context, index) => SizedBox(width: iconSpacing), // Отступ между иконками
                                itemBuilder: (context, levelIndex) {
                                  if (levelIndex >= category.levels.length) return const SizedBox.shrink();
                                  // Передаем УМЕНЬШЕННЫЙ размер и maxLevel
                                  return _buildLevelIcon(category.levels[levelIndex], finalIconSize, _maxLevel);
                                }
                            ),
                          ), // Конец SizedBox для иконок
                        ],
                      ),
                    ); // --- Конец виджета категории ---
                  },
                ), // Конец ListView.builder
              ), // Конец Expanded
            ],
          ), // Конец Column контента
        ],
      ), // Конец Stack
    ); // Конец Scaffold
  }

  // --- ИЗМЕНЕНО: Вспомогательный виджет для иконки уровня ---
  Widget _buildLevelIcon(LevelInfoModel levelInfo, double containerSize, int maxTotalLevel) {
    IconData iconData;
    BoxDecoration decoration;
    Color iconColor;
    bool isTappable = false; // По умолчанию нельзя тапнуть

    // --- Используем НОВЫЕ цвета и УБИРАЕМ ТЕНИ ---
    switch (levelInfo.status) {
      case LevelStatus.completed: // 
        iconData = Icons.check_circle_outline;
        iconColor = app_colors.kLevelsBtnText; // Белый
        decoration = BoxDecoration(
          gradient: LinearGradient( colors: [app_colors.kLevelsBtnGradStart, app_colors.kLevelsBtnGradEnd], begin: Alignment.topLeft, end: Alignment.bottomRight,), // Бирюзовый градиент
          shape: BoxShape.circle,
          // boxShadow УБРАН
        );
        isTappable = true; // Разрешаем тап для просмотра
        break;
      case LevelStatus.inProgress: // 
        iconData = Icons.play_arrow_rounded;
        iconColor = app_colors.kPlayBtnText; // Белый
        decoration = BoxDecoration(
          gradient: LinearGradient( colors: [app_colors.kPlayBtnGradStart, app_colors.kPlayBtnGradEnd], begin: Alignment.topLeft, end: Alignment.bottomRight,), // Оранжевый градиент
          shape: BoxShape.circle,
          boxShadow: [ // Оставляем легкое свечение для текущего
            BoxShadow( color: app_colors.kPlayBtnGlow.withAlpha((0.7 * 255).toInt()), blurRadius: 8, spreadRadius: 0.5,),
          ],
        );
        isTappable = true;
        break;
      case LevelStatus.locked: // 
      default:
        iconData = Icons.lock_outline_rounded;
        iconColor = app_colors.kLockedIconColor; // Серый
        decoration = BoxDecoration(
          color: app_colors.kLockedColor.withAlpha((0.5 * 255).toInt()), // Сделаем чуть прозрачнее
          shape: BoxShape.circle,
          border: Border.all(color: app_colors.kLockedIconColor.withAlpha((0.4 * 255).toInt())), // Рамка тоже прозрачнее
          // boxShadow УБРАН
        );
        isTappable = false; // Нельзя тапнуть
        break;
    }
    // --- Конец настройки стилей ---

    return GestureDetector(
      onTap: isTappable
          ? () async { // Обработчик тапа
        _logger.info("Tapped level ${levelInfo.levelNumber}, Status: ${levelInfo.status}"); // Заменен print на _logger.info
        // --- ИЗМЕНЕНО: Логика навигации при тапе ---
        if (levelInfo.status == LevelStatus.completed) {
          // Если пройден -> Открыть LevelCompleteScreen
          _logger.info("Navigating to LevelCompleteScreen for level ${levelInfo.levelNumber}"); // Заменен print на _logger.info
          try {
            // Загружаем ПОЛНЫЕ данные уровня перед переходом
            // Предполагаем, что LevelsLoader может загрузить один уровень по номеру
            final levelData = await LevelsLoader.loadLevel(levelInfo.levelNumber);
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LevelCompleteScreen(
                    completedLevel: levelData,
                    maxLevel: maxTotalLevel, // Передаем макс. уровень
                  ),
                ),
              );
              // Не перезагружаем прогресс после просмотра пройденного
            }
          } catch(e) {
            _logger.severe("Error loading level data for complete screen: $e"); // Заменен print на _logger.severe
            if(mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Не удалось загрузить данные уровня ${levelInfo.levelNumber}"))); }
          }
        } else if (levelInfo.status == LevelStatus.inProgress) {
          // Если текущий -> Открыть GameScreen
          _logger.info("Navigating to GameScreen for level ${levelInfo.levelNumber}"); // Заменен print на _logger.info
          // Переходим на экран игры и ЖДЕМ возвращения
          await Navigator.push( context, MaterialPageRoute( builder: (_) => GameScreen(levelNumber: levelInfo.levelNumber), ), );
          // После возвращения ПЕРЕЗАГРУЖАЕМ прогресс и обновляем UI
          _logger.info("Returned from GameScreen for level ${levelInfo.levelNumber}. Reloading progress..."); // Заменен print на _logger.info
          _loadDataAndScroll();
        }
        // --- КОНЕЦ ИЗМЕНЕНИЯ ---
      }
          : null, // onTap = null для заблокированных
      child: Container( // Сам контейнер иконки
        width: containerSize, height: containerSize,
        decoration: decoration, // Применяем стиль
        child: Icon(
            iconData,
            color: iconColor,
            size: containerSize * 0.6 ), // Размер иконки чуть меньше
      ),
    );
  } // Конец _buildLevelIcon

} // Конец _LevelSelectScreenState