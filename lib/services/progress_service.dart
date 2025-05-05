// lib/services/progress_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async'; // Для Future
import 'package:logging/logging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ProgressService {
  // Ключи для локального хранения
  static const _completedLevelsKey = 'completedLevels';
  static const _lastSyncKey = 'lastProgressSync';
  static const _hintsCountKey = 'hintsCount';
  static const _scoreKey = 'score';

  final _logger = Logger('ProgressService');
  
  // Получение текущего пользователя
  User? get _currentUser => FirebaseAuth.instance.currentUser;
  
  // Проверка авторизации
  bool get isAuthenticated => _currentUser != null;

  // Ссылка на коллекцию пользователей
  CollectionReference get _usersCollection => 
      FirebaseFirestore.instance.collection('users');
      
  // Ссылка на документ текущего пользователя
  DocumentReference? get _userDocument => 
      isAuthenticated ? _usersCollection.doc(_currentUser!.uid) : null;

  // Загрузка множества пройденных уровней из локального хранилища
  Future<Set<int>> _loadLocalCompletedLevels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? stringList = prefs.getStringList(_completedLevelsKey);

      if (stringList == null) {
        _logger.info("ProgressService: No completed levels found in local storage.");
        return {};
      }

      final completedSet = stringList
          .map((levelString) => int.tryParse(levelString))
          .whereType<int>()
          .toSet();

      _logger.info("ProgressService: Loaded local completed levels: $completedSet");
      return completedSet;
    } catch (e) {
      _logger.severe("Error loading local completed levels: $e");
      return {};
    }
  }

  // Сохранение множества пройденных уровней в локальное хранилище
  Future<void> _saveLocalCompletedLevels(Set<int> completedLevels) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> stringList = completedLevels.map((level) => level.toString()).toList();
      await prefs.setStringList(_completedLevelsKey, stringList);
      _logger.info("ProgressService: Saved local completed levels: $stringList");
    } catch (e) {
      _logger.severe("Error saving local completed levels: $e");
    }
  }

  // Загрузка множества пройденных уровней из Firestore
  Future<Set<int>> _loadCloudCompletedLevels() async {
    if (!isAuthenticated) {
      _logger.info("ProgressService: Not authenticated, skipping cloud load.");
      return {};
    }

    try {
      final docRef = _userDocument;
      if (docRef == null) return {};

      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) return {};

      final data = docSnapshot.data() as Map<String, dynamic>?;
      if (data == null) return {};

      final completedLevelsList = data['completedLevels'] as List<dynamic>?;
      if (completedLevelsList == null) return {};

      final completedSet = completedLevelsList
          .whereType<num>()
          .map((level) => level.toInt())
          .toSet();

      _logger.info("ProgressService: Loaded cloud completed levels: $completedSet");
      return completedSet;
    } catch (e) {
      _logger.severe("Error loading cloud completed levels: $e");
      return {};
    }
  }

  // Сохранение множества пройденных уровней в Firestore
  Future<bool> _saveCloudCompletedLevels(Set<int> completedLevels) async {
    if (!isAuthenticated) {
      _logger.info("ProgressService: Not authenticated, skipping cloud save.");
      return false;
    }

    try {
      final docRef = _userDocument;
      if (docRef == null) return false;

      final sortedLevels = completedLevels.toList()..sort();
      
      await docRef.set({
        'completedLevels': sortedLevels,
        'lastUpdated': FieldValue.serverTimestamp(),
        'maxCompletedLevel': sortedLevels.isEmpty ? 0 : sortedLevels.last,
        'totalCompletedLevels': sortedLevels.length,
      }, SetOptions(merge: true));

      _logger.info("ProgressService: Saved cloud completed levels: $sortedLevels");
      
      // Обновляем время последней синхронизации
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
      
      return true;
    } catch (e) {
      _logger.severe("Error saving cloud completed levels: $e");
      return false;
    }
  }

  // Синхронизация локального и облачного прогресса
  Future<Set<int>> syncProgress() async {
    try {
      // Загружаем данные из обоих источников
      final localLevels = await _loadLocalCompletedLevels();
      final cloudLevels = await _loadCloudCompletedLevels();
      
      // Объединяем множества (берем максимальный прогресс)
      final mergedLevels = {...localLevels, ...cloudLevels};
      
      // Если данные отличаются от локальных, обновляем локальное хранилище
      if (mergedLevels.length != localLevels.length || 
          !mergedLevels.every((level) => localLevels.contains(level))) {
        await _saveLocalCompletedLevels(mergedLevels);
      }
      
      // Если данные отличаются от облачных и пользователь авторизован, обновляем облако
      if (isAuthenticated && (mergedLevels.length != cloudLevels.length || 
          !mergedLevels.every((level) => cloudLevels.contains(level)))) {
        await _saveCloudCompletedLevels(mergedLevels);
      }
      
      _logger.info("ProgressService: Synced progress. Total levels: ${mergedLevels.length}");
      return mergedLevels;
    } catch (e) {
      _logger.severe("Error syncing progress: $e");
      return await _loadLocalCompletedLevels();
    }
  }

  // Загрузка множества пройденных уровней с синхронизацией
  Future<Set<int>> loadCompletedLevels() async {
    // Если пользователь авторизован, синхронизируем данные
    if (isAuthenticated) {
      return await syncProgress();
    } else {
      // Иначе просто загружаем локальные данные
      return await _loadLocalCompletedLevels();
    }
  }

  // Сохранение множества пройденных уровней с синхронизацией
  Future<void> saveCompletedLevels(Set<int> completedLevels) async {
    await _saveLocalCompletedLevels(completedLevels);
    
    // Если пользователь авторизован, сохраняем в облако
    if (isAuthenticated) {
      await _saveCloudCompletedLevels(completedLevels);
    }
  }

  // Получить очки пользователя (локально или из облака)
  Future<int> getScore() async {
    if (isAuthenticated) {
      try {
        final doc = await _userDocument?.get();
        if (doc != null && doc.exists) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data != null && data['score'] != null) {
            return (data['score'] as num).toInt();
          }
        }
      } catch (_) {}
    }
    // Если не авторизован — из локального хранилища
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_scoreKey) ?? 0;
  }

  // Установить очки пользователя
  Future<void> setScore(int score) async {
    if (isAuthenticated) {
      await _userDocument?.set({'score': score}, SetOptions(merge: true));
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_scoreKey, score);
  }

  // Увеличить очки пользователя на value
  Future<void> incrementScore(int value) async {
    if (!isAuthenticated) {
      _logger.warning("Cannot increment score: user is not authenticated");
      return;
    }

    try {
      final docRef = _userDocument!;
      final doc = await docRef.get();
      
      if (!doc.exists) {
        _logger.info("Creating new user document with initial score");
        await docRef.set({
          'score': value,
          'score_today': value,
          'score_month': value,
          'last_score_update': FieldValue.serverTimestamp(),
        });
      } else {
        final data = doc.data() as Map<String, dynamic>;
        final currentScore = data['score'] as int? ?? 0;
        final currentScoreToday = data['score_today'] as int? ?? 0;
        final currentScoreMonth = data['score_month'] as int? ?? 0;
        
        _logger.info("Incrementing score: current=$currentScore, adding=$value");
        
        await docRef.update({
          'score': currentScore + value,
          'score_today': currentScoreToday + value,
          'score_month': currentScoreMonth + value,
          'last_score_update': FieldValue.serverTimestamp(),
        });
      }
      
      _logger.info("Score incremented successfully");
    } catch (e) {
      _logger.severe("Error incrementing score: $e");
      rethrow;
    }
  }

  // Добавление одного пройденного уровня с синхронизацией
  Future<void> addCompletedLevel(int levelNumber) async {
    try {
      // Загружаем текущие
      final currentCompleted = await loadCompletedLevels();
      // Добавляем новый (Set сам обработает дубликаты)
      bool added = currentCompleted.add(levelNumber);
      if (added) {
        // Сохраняем обновленное множество
        await saveCompletedLevels(currentCompleted);
        _logger.info("ProgressService: Added level $levelNumber to completed list.");
      } else {
        _logger.info("ProgressService: Level $levelNumber was already completed.");
      }
    } catch (e) {
      _logger.severe("Error adding completed level $levelNumber: $e");
    }
  }
  
  // Очистка прогресса (для отладки)
  Future<void> clearProgress() async {
    try {
      await _saveLocalCompletedLevels({});
      if (isAuthenticated) {
        await _saveCloudCompletedLevels({});
      }
      _logger.info("ProgressService: Progress cleared.");
    } catch (e) {
      _logger.severe("Error clearing progress: $e");
    }
  }

  // Получить актуальное количество подсказок (синхронизирует облако и локально)
  Future<int> getHintsCount() async {
    final prefs = await SharedPreferences.getInstance();
    int local = prefs.getInt(_hintsCountKey) ?? 3;
    if (isAuthenticated) {
      final doc = await _userDocument?.get();
      if (doc != null && doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null && data['hintsCount'] != null) {
          int cloud = (data['hintsCount'] as num).toInt();
          if (cloud != local) {
            await prefs.setInt(_hintsCountKey, cloud);
          }
          return cloud;
        }
      }
    }
    return local;
  }

  // Установить количество подсказок (и синхронизировать)
  Future<void> setHintsCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_hintsCountKey, count);
    if (isAuthenticated) {
      await _userDocument?.set({'hintsCount': count}, SetOptions(merge: true));
    }
  }

  // Увеличить количество подсказок
  Future<void> incrementHints([int by = 1]) async {
    int current = await getHintsCount();
    await setHintsCount(current + by);
  }

  // Уменьшить количество подсказок
  Future<void> decrementHints([int by = 1]) async {
    int current = await getHintsCount();
    if (current > 0) {
      await setHintsCount(current - by);
    }
  }
}
