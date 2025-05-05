import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:logging/logging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Убедитесь, что импортирована ваша модель LevelModel
import '../models/level_model.dart'; // Теперь ожидает fromJson(..., {int? defaultLevelNumber})

class LevelsLoader {
  static final _logger = Logger('LevelsLoader');

  // Загрузка одного уровня из Firestore
  static Future<LevelModel> loadLevel(int levelNumber) async {
    _logger.info('Loading level $levelNumber from Firestore...');
    try {
      final doc = await FirebaseFirestore.instance.collection('levels').doc(levelNumber.toString()).get();
      if (!doc.exists) {
        throw Exception('Level $levelNumber not found in Firestore');
      }
      final data = doc.data()!;
      return LevelModel.fromJson(data, defaultLevelNumber: levelNumber);
    } catch (e) {
      _logger.severe('Error loading level $levelNumber from Firestore: $e');
      throw Exception('Failed to load level $levelNumber: $e');
    }
  }

  // Загрузка всех уровней, сгруппированных по категориям, из Firestore
  static Future<Map<String, List<LevelModel>>> loadAllLevelsGroupedByCategory() async {
    _logger.info('Loading all levels grouped by category from Firestore...');
    final Map<String, List<LevelModel>> groupedLevels = {};
    try {
      final snapshot = await FirebaseFirestore.instance.collection('levels').get();
      if (snapshot.docs.isEmpty) {
        _logger.warning('No levels found in Firestore!');
        return {};
      }
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final level = LevelModel.fromJson(data, defaultLevelNumber: int.tryParse(doc.id));
          final category = level.category;
          if (groupedLevels.containsKey(category)) {
            groupedLevels[category]!.add(level);
          } else {
            groupedLevels[category] = [level];
          }
        } catch (e) {
          _logger.severe('Error parsing level from Firestore doc ${doc.id}: $e');
        }
      }
      // Сортируем уровни внутри категорий
      groupedLevels.forEach((category, levelsInCategory) {
        levelsInCategory.sort((a, b) => (a.levelNumber ?? 0).compareTo(b.levelNumber ?? 0));
      });
      _logger.info('Finished loading and grouping levels from Firestore. Categories found: ${groupedLevels.keys.length}');
      return groupedLevels;
    } catch (e) {
      _logger.severe('Failed to load levels from Firestore: $e');
      return {};
    }
  }
}