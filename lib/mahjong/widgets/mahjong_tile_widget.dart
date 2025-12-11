import 'package:flutter/material.dart';
import '../models/mahjong_model.dart';

class MahjongTileWidget extends StatelessWidget {
  final MahjongTile tile;
  final VoidCallback onTap;
  final bool isFree;

  const MahjongTileWidget({
    Key? key,
    required this.tile,
    required this.onTap,
    this.isFree = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (tile.state == TileState.matched) {
      return const SizedBox.shrink();
    }

    final isSelected = tile.state == TileState.selected;

    // 2.5D Effect:
    // We can use a Stack with a shadow/depth layer and the top face.
    // Dimensions: Let's assume 1 unit = 30 pixels.
    // Tile size W=2 units = 60px. H=2 units = 60px?
    // Usually Mahjong tiles are tall (3:4 ratio).
    // Let's assume width=60, height=80.

    const double width = 60;
    const double height = 80;
    const double depth = 8;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        height: height + depth, // Includes depth
        child: Stack(
          children: [
            // Side/Depth (Shadow)
            Positioned(
              top: isSelected ? depth : depth, // If pressed, maybe move down?
              // If selected, maybe lift up?
              // Let's make "Selected" lift up.
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            // Top Face
            Positioned(
              top: isSelected ? 0 : depth,
              left: 0,
              right: 0,
              bottom: isSelected ? depth : 0,
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? Colors.amber[100] : (isFree ? Colors.white : Colors.grey[300]),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.amber : (isFree ? Colors.grey[400]! : Colors.grey[500]!),
                    width: 2,
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(color: Colors.amber.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)
                  ] : [],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon or Text
                      // For "Word Game", text.
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Text(
                          tile.word,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isFree ? Colors.black87 : Colors.grey[500],
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
