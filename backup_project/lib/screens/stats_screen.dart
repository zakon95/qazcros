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
//           AppColors.kStatsGradStart -> kStatsGradStart
//           AppColors.kStatsGradEnd -> kStatsGradEnd
//           AppColors.kStatsShadow -> kStatsShadow
//           AppColors.kStatsBorder -> kStatsBorder
//           AppColors.kStatsText -> kStatsText
//           и т.д.

import 'package:logging/logging.dart';

// Удалён неиспользуемый импорт app_colors

// Удалён неиспользуемый _logger