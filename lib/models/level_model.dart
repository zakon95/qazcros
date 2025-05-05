import 'question_model.dart'; // Убедитесь, что путь правильный
import 'package:flutter/foundation.dart'; // Для kDebugMode

// Глобальная функция логирования для модели
void logModelWarning(String message) {
  if (kDebugMode) {
    // ignore: avoid_print
    print('[LevelModel] $message');
  }
}

// Модель для ячейки буквы во фразе (без изменений)
class LetterCellModel {
  final String? letter; // Сделаем nullable на всякий случай
  final int? code;

  LetterCellModel({required this.letter, required this.code});

  factory LetterCellModel.fromJson(Map<String, dynamic> json) {
    return LetterCellModel(
      letter: json['letter'] as String?, // Безопасное приведение
      code: json['code'] as int?,     // Безопасное приведение
    );
  }
}

// Модель уровня (ИЗМЕНЕННАЯ)
class LevelModel {
  int? levelNumber; // <-- Сделано nullable, может быть установлено позже
  final String category;
  final List<LetterCellModel> phraseDisplay;
  final String fullPhrase; // <--- НОВОЕ ПОЛЕ
  final List<QuestionModel> questions;
  final String? explanationText;

  LevelModel({
    this.levelNumber, // <-- Не обязательный в конструкторе
    required this.category,
    required this.phraseDisplay,
    required this.fullPhrase, // <--- ДОБАВЛЕНО В КОНСТРУКТОР
    required this.questions,
    this.explanationText,
  });

  // Фабричный конструктор для создания из JSON (ИЗМЕНЕН)
  factory LevelModel.fromJson(Map<String, dynamic> json, {int? defaultLevelNumber}) {

    List<LetterCellModel> phraseDisplayResult = [];
    StringBuffer phraseBuffer = StringBuffer(); // Для сборки строки

    // Обработка структуры фразы из JSON
    if (json['phrase'] != null && json['phrase'] is List) {
      final List<dynamic> phraseJson = json['phrase'];
      bool firstWord = true; // Флаг для управления пробелами между словами

      for (var wordEntry in phraseJson) {
        // Проверяем, что элемент списка - это карта с нужными ключами
        if (wordEntry is Map<String, dynamic> && wordEntry.containsKey('word') && wordEntry.containsKey('numbers')) {
          String word = wordEntry['word'] as String? ?? ''; // Безопасно получаем слово
          List<dynamic> numbers = wordEntry['numbers'] as List? ?? []; // Безопасно получаем числа

          // Добавляем пробел перед словом (кроме первого)
          if (!firstWord && word.isNotEmpty) {
            phraseDisplayResult.add(LetterCellModel(letter: ' ', code: null));
            phraseBuffer.write(' ');
          }
          // Если слово не пустое, обрабатываем его
          if (word.isNotEmpty){
            firstWord = false; // После первого непустого слова флаг меняется
            for (int i = 0; i < word.length; i++) {
              final letter = word[i];
              // Безопасно получаем код, проверяя тип и индекс
              final int? code = (numbers.length > i && numbers[i] is int) ? numbers[i] as int? : null;

              phraseDisplayResult.add(LetterCellModel(letter: letter, code: code));
              phraseBuffer.write(letter); // Добавляем букву в строку
            }
          }
        } else {
          logModelWarning("Warning: Invalid structure for word entry in phrase JSON: $wordEntry");
        }
      }
    } else {
      logModelWarning("Warning: 'phrase' key not found or is not a List in level JSON.");
    }

    // Парсинг номера уровня: сначала из JSON, потом из параметра (от имени файла)
    int? parsedLevelNumber = json['levelNumber'] as int?;
    int? finalLevelNumber = parsedLevelNumber ?? defaultLevelNumber;

    // Парсинг вопросов
    List<QuestionModel> parsedQuestions = [];
    if (json['questions'] != null && json['questions'] is List) {
      parsedQuestions = (json['questions'] as List<dynamic>)
          .map((item) {
        try {
          // Добавляем проверку типа перед вызовом fromJson
          if (item is Map<String, dynamic>) {
            return QuestionModel.fromJson(item);
          } else {
            logModelWarning("Warning: Invalid question data format found: $item");
            return null; // Возвращаем null, если формат неверный
          }
        } catch (e) {
          logModelWarning("Error parsing question: $item, Error: $e");
          return null; // Возвращаем null при ошибке парсинга
        }
      })
          .whereType<QuestionModel>() // Отфильтровываем null значения
          .toList();
    } else {
      logModelWarning("Warning: 'questions' key not found or is not a List in level JSON.");
    }

    return LevelModel(
      levelNumber: finalLevelNumber,
      category: json['category'] as String? ?? 'Без категории',
      phraseDisplay: phraseDisplayResult,
      fullPhrase: phraseBuffer.toString(),
      questions: parsedQuestions,
      explanationText: json['explanationText'] as String?, // <--- ПАРСИНГ НОВОГО ПОЛЯ (может быть null)
    );
  }
}