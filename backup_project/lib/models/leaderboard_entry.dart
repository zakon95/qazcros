class LeaderboardEntry {
  final String userId;
  final String displayName;
  final int score;
  final int scoreMonth;
  final int scoreToday;
  final String city;
  final String avatar;
  final int rank;
  final DateTime lastUpdated;

  LeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.score,
    required this.scoreMonth,
    required this.scoreToday,
    required this.city,
    required this.avatar,
    required this.rank,
    required this.lastUpdated,
  });

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map) {
    return LeaderboardEntry(
      userId: map['userId'] as String,
      displayName: map['displayName'] as String? ?? 'Аноним',
      score: map['score'] as int? ?? 0,
      scoreMonth: map['score_month'] as int? ?? 0,
      scoreToday: map['score_today'] as int? ?? 0,
      city: map['city'] as String? ?? '',
      avatar: map['avatar'] as String? ?? '',
      rank: map['rank'] as int? ?? 0,
      lastUpdated: (map['lastUpdated'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'displayName': displayName,
      'score': score,
      'score_month': scoreMonth,
      'score_today': scoreToday,
      'city': city,
      'avatar': avatar,
      'rank': rank,
      'lastUpdated': lastUpdated,
    };
  }
} 