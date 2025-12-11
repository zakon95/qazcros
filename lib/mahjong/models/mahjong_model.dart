import 'package:equatable/equatable.dart';

class WordPair extends Equatable {
  final String a;
  final String b;
  final String category;

  const WordPair({
    required this.a,
    required this.b,
    required this.category,
  });

  factory WordPair.fromJson(Map<String, dynamic> json) {
    return WordPair(
      a: json['a'] as String,
      b: json['b'] as String,
      category: json['category'] ?? '',
    );
  }

  @override
  List<Object?> get props => [a, b, category];
}

class TileCoordinates extends Equatable {
  final double x;
  final double y;
  final int z;

  const TileCoordinates({
    required this.x,
    required this.y,
    required this.z,
  });

  factory TileCoordinates.fromJson(Map<String, dynamic> json) {
    return TileCoordinates(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      z: (json['z'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'z': z,
      };

  @override
  List<Object?> get props => [x, y, z];
}

enum TileState {
  normal,
  selected,
  matched,
}

class MahjongTile extends Equatable {
  final String id;
  final String word;
  final String category;
  final TileCoordinates coordinates;
  final TileState state;
  final String? matchId; // ID of the matching tile (for debugging/verification)

  const MahjongTile({
    required this.id,
    required this.word,
    this.category = '',
    required this.coordinates,
    this.state = TileState.normal,
    this.matchId,
  });

  MahjongTile copyWith({
    TileState? state,
  }) {
    return MahjongTile(
      id: id,
      word: word,
      category: category,
      coordinates: coordinates,
      state: state ?? this.state,
      matchId: matchId,
    );
  }

  @override
  List<Object?> get props => [id, word, coordinates, state, matchId];
}

class MahjongLevel {
  final String id;
  final List<MahjongTile> tiles;

  const MahjongLevel({
    required this.id,
    required this.tiles,
  });
}
