class QuestionModel {
  final String question;
  final String answer;
  final List<int> letterCodes;

  QuestionModel({
    required this.question,
    required this.answer,
    required this.letterCodes,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      question: json['question'] as String,
      answer: json['answer'] as String,
      letterCodes: List<int>.from(json['numbers'] as List),
    );
  }
}
