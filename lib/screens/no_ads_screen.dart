import 'package:logging/logging.dart';

// Везде далее заменить все обращения к цветам и градиентам на переменные из app_colors.dart (например, kBrightTextColor, kPlayBtnGradStart и т.д.)
// Заменяем стандартные цвета на фирменные из app_colors.dart
// Например:
// Colors.red -> kAnswerBoxIncorrectBorder
// Colors.grey[850] -> kHomeBgGradMid
// Colors.grey[500] -> kSubtleBtnText
// Colors.black -> kHomeBgGradStart
// Colors.white -> kBrightTextColor
// и т.д.

// Исправление: заменяем все обращения к AppColors на прямые переменные из app_colors.dart
// Например: AppColors.kBrightTextColor -> kBrightTextColor
//           AppColors.kHomeBgGradStart -> kHomeBgGradStart
//           AppColors.kNoAdsGradStart -> kNoAdsGradStart
//           AppColors.kNoAdsGradEnd -> kNoAdsGradEnd
//           AppColors.kNoAdsShadow -> kNoAdsShadow
//           AppColors.kNoAdsBorder -> kNoAdsBorder
//           AppColors.kNoAdsText -> kNoAdsText
//           и т.д.

// Удалён неиспользуемый импорт app_colors
// Удалён неиспользуемый _logger