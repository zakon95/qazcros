import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/mahjong_model.dart';
import '../services/level_generator.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

// State for the game
class MahjongGameState {
  final MahjongLevel? level;
  final MahjongTile? selectedTile;
  final bool isLoading;
  final String? error;
  final int matchesFound;

  MahjongGameState({
    this.level,
    this.selectedTile,
    this.isLoading = false,
    this.error,
    this.matchesFound = 0,
  });

  MahjongGameState copyWith({
    MahjongLevel? level,
    MahjongTile? selectedTile,
    bool? isLoading,
    String? error,
    int? matchesFound,
    bool clearSelected = false,
  }) {
    return MahjongGameState(
      level: level ?? this.level,
      selectedTile: clearSelected ? null : (selectedTile ?? this.selectedTile),
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      matchesFound: matchesFound ?? this.matchesFound,
    );
  }
}

// Provider
final mahjongGameProvider = StateNotifierProvider<MahjongGameController, MahjongGameState>((ref) {
  return MahjongGameController();
});

class MahjongGameController extends StateNotifier<MahjongGameState> {
  MahjongGameController() : super(MahjongGameState());

  final _generator = LevelGenerator();

  Future<void> loadLevel(String layoutAsset, String dictionaryAsset) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Load assets
      final layoutString = await rootBundle.loadString(layoutAsset);
      final layoutJson = jsonDecode(layoutString) as List;
      final layout = layoutJson.map((e) => TileCoordinates.fromJson(e)).toList();

      final dictString = await rootBundle.loadString(dictionaryAsset);
      final dictJson = jsonDecode(dictString);
      final pairsJson = dictJson['pairs'] as List;
      final dictionary = pairsJson.map((e) => WordPair.fromJson(e)).toList();

      // Generate
      final level = _generator.generateLevel('1', layout, dictionary);

      state = state.copyWith(
        level: level,
        isLoading: false,
        matchesFound: 0,
        clearSelected: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void onTileTap(MahjongTile tile) {
    if (state.level == null) return;

    // Check if tile is still in the game (not matched)
    if (tile.state == TileState.matched) return;

    // Check if tile is free
    if (!_isTileFree(tile)) {
        // Shake effect or sound (handled by UI listener)
        return;
    }

    if (state.selectedTile == null) {
      // Select
      _updateTileState(tile, TileState.selected);
      state = state.copyWith(selectedTile: tile);
    } else {
      if (state.selectedTile!.id == tile.id) {
        // Deselect
        _updateTileState(tile, TileState.normal);
        state = state.copyWith(clearSelected: true);
      } else {
        // Match attempt
        _checkMatch(state.selectedTile!, tile);
      }
    }
  }

  void _checkMatch(MahjongTile tileA, MahjongTile tileB) {
    // We generated matching pairs with 'matchId' for verification.
    // In a real game with multiple same words, we'd check word equality.
    // But here we might have specific pairs (Knife - Butter).

    // Check if they form a pair
    bool isMatch = false;

    // 1. Direct matchId check (if generated as unique pairs)
    if (tileA.matchId == tileB.id) {
      isMatch = true;
    }
    // 2. Word association check (if we had a lookup)
    // For now, LevelGenerator assigns matchId directly.

    if (isMatch) {
      // Success
      _updateTileState(tileA, TileState.matched);
      _updateTileState(tileB, TileState.matched);
      state = state.copyWith(
        matchesFound: state.matchesFound + 1,
        clearSelected: true,
      );

      // Check win condition
      if (state.level!.tiles.every((t) => t.state == TileState.matched)) {
        // Win
        // Can trigger UI event
      }
    } else {
      // Fail
      // Shake effect, deselect
      _updateTileState(state.selectedTile!, TileState.normal);
      // tileB was never selected, so no need to update
      state = state.copyWith(clearSelected: true);
    }
  }

  void _updateTileState(MahjongTile tile, TileState newState) {
    if (state.level == null) return;
    final newTiles = state.level!.tiles.map((t) {
      if (t.id == tile.id) {
        return t.copyWith(state: newState);
      }
      return t;
    }).toList();

    state = state.copyWith(level: MahjongLevel(id: state.level!.id, tiles: newTiles));
  }

  bool _isTileFree(MahjongTile tile) {
    if (state.level == null) return false;

    // Get all active tiles (not matched)
    final activeTiles = state.level!.tiles.where((t) => t.state != TileState.matched).toList();

    // Check top
    final hasTop = activeTiles.any((other) =>
      other.id != tile.id &&
      other.coordinates.z == tile.coordinates.z + 1 &&
      (other.coordinates.x - tile.coordinates.x).abs() < 2 &&
      (other.coordinates.y - tile.coordinates.y).abs() < 2
    );
    if (hasTop) return false;

    // Check Left
    final hasLeft = activeTiles.any((other) =>
      other.id != tile.id &&
      other.coordinates.z == tile.coordinates.z &&
      (other.coordinates.y - tile.coordinates.y).abs() < 2 &&
      other.coordinates.x == tile.coordinates.x - 2
    );

    // Check Right
    final hasRight = activeTiles.any((other) =>
      other.id != tile.id &&
      other.coordinates.z == tile.coordinates.z &&
      (other.coordinates.y - tile.coordinates.y).abs() < 2 &&
      other.coordinates.x == tile.coordinates.x + 2
    );

    return !hasLeft || !hasRight;
  }
}
