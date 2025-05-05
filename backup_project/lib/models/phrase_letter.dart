class PhraseLetter {
  final String letter;
  final int? code;

  PhraseLetter({required this.letter, this.code});

  factory PhraseLetter.fromJson(Map<String, dynamic> json) {
    return PhraseLetter(
      letter: json['letter'] ?? '',
      code: json['code'],
    );
  }
}
