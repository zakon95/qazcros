import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/mahjong_state.dart';
import '../widgets/mahjong_board.dart';
import '../../theme/app_colors.dart';

class MahjongGameScreen extends ConsumerStatefulWidget {
  const MahjongGameScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MahjongGameScreen> createState() => _MahjongGameScreenState();
}

class _MahjongGameScreenState extends ConsumerState<MahjongGameScreen> {
  @override
  void initState() {
    super.initState();
    // Load level on start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mahjongGameProvider.notifier).loadLevel(
        'assets/mahjong_layouts/turtle.json',
        'assets/mahjong_dictionaries/kitchen.json',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(mahjongGameProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF2C2438), // Match app theme
      appBar: AppBar(
        title: const Text("Mahjong Associations"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(mahjongGameProvider.notifier).loadLevel(
                'assets/mahjong_layouts/turtle.json',
                'assets/mahjong_dictionaries/kitchen.json',
              );
            },
          )
        ],
      ),
      body: Container(
         decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: kGameScreenBackgroundGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: gameState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : gameState.error != null
                ? Center(child: Text("Error: ${gameState.error}", style: const TextStyle(color: Colors.red)))
                : Column(
                    children: [
                      // HUD
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Matches: ${gameState.matchesFound}", style: const TextStyle(color: Colors.white, fontSize: 20)),
                            if (gameState.selectedTile != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  gameState.selectedTile!.category.isNotEmpty
                                      ? "Find pair in: ${gameState.selectedTile!.category}"
                                      : "Find pair for: ${gameState.selectedTile!.word}",
                                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                ),
                              )
                          ],
                        ),
                      ),
                      // Board
                      const Expanded(
                        child: Center(
                          child: MahjongBoard(),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
