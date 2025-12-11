import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/mahjong_state.dart';
import '../models/mahjong_model.dart';
import 'mahjong_tile_widget.dart';

class MahjongBoard extends ConsumerWidget {
  const MahjongBoard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(mahjongGameProvider);

    if (gameState.level == null) {
      return const Center(child: Text("No Level Loaded"));
    }

    // Determine board size to center it
    // Min/Max X and Y
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (var tile in gameState.level!.tiles) {
      if (tile.coordinates.x < minX) minX = tile.coordinates.x;
      if (tile.coordinates.x > maxX) maxX = tile.coordinates.x;
      if (tile.coordinates.y < minY) minY = tile.coordinates.y;
      if (tile.coordinates.y > maxY) maxY = tile.coordinates.y;
    }

    // Tile visual size
    const double tileWidth = 60;
    const double tileHeight = 80;
    // Step size (from layout units to pixels)
    // In layout: 2 units = 1 tile width?
    // GDD sample: x=0, 2, 4. So step=2 is full width.
    // So 1 unit = tileWidth / 2 = 30px.
    const double unitSize = 30;

    // Board dimensions
    // Width = (maxX - minX + tile_size_in_units) * unitSize
    // tile size in units = 2
    final boardWidth = (maxX - minX + 2) * unitSize;
    final boardHeight = (maxY - minY + 2) * unitSize + 20; // +20 for depth/stacking

    // Sort tiles by Z, then Y, then X for rendering order (Painter's algorithm)
    // Actually Mahjong needs specific order: Bottom Z first.
    // Within same Z: usually Top Y first (back to front)?
    // Wait. In Flutter Stack, last child is on top.
    // To render correctly:
    // Z=0 drawn first. Z=1 drawn on top.
    // Within Z=0: Y=0 (Top) drawn first? Y=1 (Bottom) drawn on top?
    // If tiles overlap vertically (Y), the one "in front" (higher Y) should be on top visually.
    // So sort by Z ascending, then Y ascending?
    // Let's check:
    // Tile A at Y=0. Tile B at Y=1.
    // B is "below" A on screen.
    // If they overlap? B covers A's bottom edge?
    // Yes. So B should be drawn AFTER A.
    // So Y ascending.
    // X ascending (Left to Right).

    final sortedTiles = List<MahjongTile>.from(gameState.level!.tiles);
    sortedTiles.sort((a, b) {
      if (a.coordinates.z != b.coordinates.z) {
        return a.coordinates.z.compareTo(b.coordinates.z);
      }
      if (a.coordinates.y != b.coordinates.y) {
        return a.coordinates.y.compareTo(b.coordinates.y);
      }
      return a.coordinates.x.compareTo(b.coordinates.x);
    });

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SizedBox(
          width: boardWidth + 100, // Padding
          height: boardHeight + 100,
          child: Stack(
            children: sortedTiles.map((tile) {
              // Calculate pixel position
              // X in pixels
              final double left = (tile.coordinates.x - minX) * unitSize + 50;
              // Y in pixels.
              // We need to account for Z shift!
              // Higher Z usually shifts UP (negative Y) and maybe RIGHT (positive X) slightly for 3D effect?
              // Or just straightforward stacking?
              // Standard Mahjong Solitaire usually shifts Z tiles up and right by a few pixels to show depth.
              final double zShiftX = tile.coordinates.z * -4.0;
              final double zShiftY = tile.coordinates.z * -4.0;

              final double top = (tile.coordinates.y - minY) * unitSize + 50 + zShiftY;
              final double finalLeft = left + zShiftX;

              // Calculate if free
              // We replicate the logic here for UI feedback.
              // A tile is blocked if any tile is on top, or both L and R are blocked.
              // Optimization: We could move this to the Controller/State to avoid recalc on every build.
              // But for board size < 144, it's fast enough.

              final activeTiles = gameState.level!.tiles.where((t) => t.state != TileState.matched).toList();

              bool isBlockedByTop = activeTiles.any((other) =>
                other.id != tile.id &&
                other.coordinates.z == tile.coordinates.z + 1 &&
                (other.coordinates.x - tile.coordinates.x).abs() < 2 &&
                (other.coordinates.y - tile.coordinates.y).abs() < 2
              );

              bool isBlockedByLeft = activeTiles.any((other) =>
                other.id != tile.id &&
                other.coordinates.z == tile.coordinates.z &&
                (other.coordinates.y - tile.coordinates.y).abs() < 2 &&
                other.coordinates.x == tile.coordinates.x - 2
              );

              bool isBlockedByRight = activeTiles.any((other) =>
                other.id != tile.id &&
                other.coordinates.z == tile.coordinates.z &&
                (other.coordinates.y - tile.coordinates.y).abs() < 2 &&
                other.coordinates.x == tile.coordinates.x + 2
              );

              final isFree = !isBlockedByTop && (!isBlockedByLeft || !isBlockedByRight);

              return Positioned(
                left: finalLeft,
                top: top,
                child: MahjongTileWidget(
                  tile: tile,
                  isFree: isFree,
                  onTap: () {
                    ref.read(mahjongGameProvider.notifier).onTileTap(tile);
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
