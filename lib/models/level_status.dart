// lib/models/level_status.dart
enum LevelStatus {
  locked,
  inProgress, // Текущий доступный для игры
  completed,
}

class LevelInfoModel {
  final int levelNumber;
  final LevelStatus status;

  LevelInfoModel({required this.levelNumber, required this.status});
}

class CategoryModel {
  final String name;
  final List<LevelInfoModel> levels;
  final String imageAssetPath;

  CategoryModel({
    required this.name,
    required this.levels,
    required this.imageAssetPath,
  });
}