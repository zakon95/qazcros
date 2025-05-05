// lib/theme/app_colors.dart
import 'package:flutter/material.dart';

// --- КОНСТАНТЫ ЦВЕТОВ ПРИЛОЖЕНИЯ (Темная Тема "Home") ---

// Фон
const Color kAppBackgroundStart = Color(0xFF191821);
const Color kAppBackgroundMid = Color(0xFF2C2438);
const Color kAppBackgroundEnd = Color(0xFF14111C);
const List<Color> kAppBackgroundGradient = [ kAppBackgroundStart, kAppBackgroundMid, kAppBackgroundEnd ];
const List<Color> kGameScreenBackgroundGradient = [
  Color(0xFF232946), // глубокий тёмно-синий
  Color(0xFF372772), // насыщенный фиолетовый
  Color(0xFF2C2438), // тёмный низ
]; // Градиент для GameScreen и AppBar — как на HomeScreen

// AppBar
const Color kAppBarGradStart = Color(0xFF4E54C8);
const Color kAppBarGradEnd = Color(0xFF8F94FB);

// Основные цвета текста и иконок
const Color kBrightTextColor = Color(0xFFFFFFFF);
const Color kSubtleTextColor = Color(0xFFCFD8DC);
const Color kIconColor = Color(0xFFFFFFFF); // Для AppBar и др.
const Color kAccentColorYellow = Color(0xFFFBD786); // Акцентный желтый (для фокуса, загрузки)

// Центральный круг HomeScreen
const Color kHomeCircleOuterRing = Color(0xFF6D548B);
const Color kHomeCircleInnerBg = Color(0xFF2C2438);
const Color kHomeCircleBorder = Color(0xFF8F94FB);
const Color kHomeCircleGlow = Color(0xAA8F94FB);
const Color kHomeLevelNumColor = Colors.white;
const Color kHomeLevelLabelColor = Color(0xFFA0A0B0);
// Индикатор прогресса HomeScreen
const Color kHomeIndicatorBg = Color(0xFF3a394c);
const List<Color> kHomeIndicatorGradient = [ kPlayBtnGradEnd, kAccentColorYellow, kHomeCircleBorder, kHomeCircleOuterRing, kLevelsBtnGradEnd ];

// Кнопка "Играть" (Оранжевая) / Статус InProgress / Аксессуарные кнопки
const Color kPlayBtnText = Colors.white;
const Color kPlayBtnIcon = Colors.white;
const Color kPlayBtnGradStart = Color(0xFFFFA35D);
const Color kPlayBtnGradEnd = Color(0xFFF58529);
const Color kPlayBtnGlow = Color(0x99D59F0D);

// Кнопка "Уровни" / "Продолжить" (Бирюзовая) / Статус Completed
const Color kLevelsBtnText = Colors.white;
const Color kLevelsBtnIcon = Colors.white;
const Color kLevelsBtnGradStart = Color(0xFF29a99d);
const Color kLevelsBtnGradEnd = Color(0xFF57FFED);
const Color kLevelsBtnGlow = Color(0x8856FEA8);

// Второстепенные кнопки HomeScreen
const Color kSubtleBtnText = Color(0xFFE0E0E0);
const Color kSubtleBtnIcon = Color(0xFFE0E0E0);
const Color kSubtleBtnBgStart = Color(0x44302B63);
const Color kSubtleBtnBgEnd = Color(0x4424243E);
const Color kSubtleBtnGlow = Color(0x33CFD8DC);
const Color kSubtleBtnBorder = Color(0x88a09aaf);

// Элементы GameScreen
// Фоны для Q&A Блоков
const List<Color> kQABlockGradientA = [Color(0x33FFA35D), Color(0x22F58529), Color(0x1A2C2438)]; // Оранжевый -> темный
const List<Color> kQABlockGradientB = [Color(0x3329a99d), Color(0x2257FFED), Color(0x1A2C2438)]; // Бирюзовый -> темный
// Ячейки Ответа
const Color kAnswerBoxBg = Color(0x4D000000); // Полупрозрачный ЧЕРНЫЙ
const Color kAnswerBoxBorder = Color(0x889E9E9E); // Сероватая рамка
const Color kAnswerBoxCorrectBgStart = kLevelsBtnGradStart; // Бирюзовый
const Color kAnswerBoxCorrectBgEnd = kLevelsBtnGradEnd;
const Color kAnswerBoxCorrectText = kLevelsBtnText; // Белый
const Color kAnswerBoxFocusBgStart = kPlayBtnGradStart; // Оранжевый
const Color kAnswerBoxFocusBgEnd = kPlayBtnGradEnd;
const Color kFocusHighlightColor = kAccentColorYellow; // Желтая рамка фокуса
const Color kAnswerBoxIncorrectBg = Color(0xB3FF1744); // Красный фон
const Color kAnswerBoxIncorrectBorder = Color(0xFFFF5252); // Яркая красная рамка
const Color kAnswerBoxIncorrectText = Color(0xFFFFFFFF);   // Белый текст
// Подсказки (Цифры под ячейками)
const Color kHintTextColorNormal = Color(0xFFCFD8DC);
const Color kHintTextColorCorrect = Color(0xFFE0E0E0);
const Color kHintTextColorIncorrect = kAnswerBoxIncorrectBorder; // Красный
const Color kHintTextColorFocus = kFocusHighlightColor; // Желтый
// PhraseDisplay
const Color kPhraseTextColor = Color(0xFFFFFFFF);
const Color kPhraseHintTextColor = Color(0xFFCFD8DC);
const Color kPhraseBackgroundColor = Color(0x40000000);
const Color kPhraseCorrectBorderColor = kLevelsBtnGradEnd; // Бирюзовый
const Color kPhraseIncorrectBg = kAnswerBoxIncorrectBg;
const Color kPhraseIncorrectBorder = kAnswerBoxIncorrectBorder;
// Загрузка
const Color kLoadingIndicatorColor = kAccentColorYellow; // Желтый

// === ДОБАВЛЕНЫ ОТСУТСТВУЮЩИЕ КОНСТАНТЫ ДЛЯ level_complete_screen ===
const Color kContainerBgColor = Color(0xFF23213A); // Примерный цвет, отредактируете позже
const Color kContainerBorderColor = Color(0xFF3C3A5A); // Примерный цвет
const Color kAccentColor = Color(0xFF00E6D0); // Бирюзовый акцент, отредактируете позже
const Color kContainerDarkerBgColor = Color(0xFF191821); // Более тёмный фон
// === END ===

// === ДОБАВЛЕНЫ НЕДОСТАЮЩИЕ ЦВЕТА ===
const Color kHomeLogoShadow = Color(0xFF000000);
const Color kHomeShadow = Color(0xFF000000);
const Color kErrorColor = Color(0xFFFF5555);
const Color kCardGradientStart = Color(0xFF363457);
const Color kCardGradientEnd = Color(0xFF4F4668);
const Color kAccentGradientMid = Color(0xFF00B9C2);
const Color kPlaceholderImageColor = Color(0xFFB0B0B0);
const Color kLockedIconColor = Color(0xFF888888);
const Color kLockedColor = Color(0xFFB0B0B0);

// --- ДОПОЛНИТЕЛЬНЫЕ КОНСТАНТЫ ЦВЕТОВ ---

// Фон
const Color kHomeBgGradStart = Color(0xFF191821);
const Color kHomeBgGradMid = Color(0xFF2C2438);
const Color kHomeBgGradEnd = Color(0xFF14111C);

// Центральный круг
const Color kHomeCircleOuterRingDuplicate = Color(0xFF6D548B);
const Color kHomeCircleInnerBgDuplicate = Color(0xFF2C2438);
const Color kHomeCircleBorderDuplicate = Color(0xFF8F94FB);
const Color kHomeCircleGlowDuplicate = Color(0xAA8F94FB);

// Текст в круге
const Color kHomeLevelNumColorDuplicate = Colors.white;
const Color kHomeLevelLabelColorDuplicate = Color(0xFFA0A0B0);

// Индикатор прогресса
const Color kHomeIndicatorBgDuplicate = Color(0xFF3a394c);
const List<Color> kHomeIndicatorGradientDuplicate = [ Color(0xFFF58529), Color(0xFFF7797d), Color(0xFF8F94FB), Color(0xFF4B416C), Color(0xFF41B1AD), ];

// Кнопка "Играть" (Оранжевая)
const Color kPlayBtnTextDuplicate = Colors.white;
const Color kPlayBtnIconDuplicate = Colors.white;
const Color kPlayBtnGradStartDuplicate = Color(0xFFFFA35D);
const Color kPlayBtnGradEndDuplicate = Color(0xFFF58529);
const Color kPlayBtnGlowDuplicate = Color(0x99D59F0D);

// Кнопка "Уровни" (Бирюзовая)
const Color kLevelsBtnTextDuplicate = Colors.white;
const Color kLevelsBtnIconDuplicate = Colors.white;
const Color kLevelsBtnGradStartDuplicate = Color(0xFF29a99d);
const Color kLevelsBtnGradEndDuplicate = Color(0xFF57FFED);
const Color kLevelsBtnGlowDuplicate = Color(0x8856FEA8);

// Верхняя панель
const Color kHomeSettingsColor = Colors.white;
const Color kHomeLogoColor = Colors.white;

// Второстепенные кнопки
const Color kSubtleBtnTextDuplicate = Color(0xFFE0E0E0);
const Color kSubtleBtnIconDuplicate = Color(0xFFE0E0E0);
const Color kSubtleBtnBgStartDuplicate = Color(0x44302B63);
const Color kSubtleBtnBgEndDuplicate = Color(0x4424243E);
const Color kSubtleBtnGlowDuplicate = Color(0x33CFD8DC);
const Color kSubtleBtnBorderDuplicate = Color(0x88a09aaf);

// Цвет фона для контейнера кнопок
const Color kHomeBgGradMidForButtons = Color(0xFF2C2438);

// Цвета для KazakhKeyboard
const Color kLetterKeyBg = Color(0x992C2438); // Полупрозрачный средний фон
const Color kLetterKeyBorder = Color(0xAA8F94FB); // Лавандовая рамка
const Color kLetterKeyGlow = Color(0x448F94FB); // Легкое свечение

// Градиент для AppBar GameScreen (насыщенный, без прозрачности)
const List<Color> kAppBarGameGradient = [
  Color(0xFF29a99d), // Бирюзовый
  Color(0xFF57FFED), // Светло-бирюзовый
  Color(0xFF2C2438), // Тёмный
];

// --- КОНЕЦ КОНСТАНТ ЦВЕТОВ ---