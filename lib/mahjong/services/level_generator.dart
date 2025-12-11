import 'dart:math';
import '../models/mahjong_model.dart';

class LevelGenerator {
  /// Generates a level by filling the layout with pairs from the dictionary using reverse filling.
  MahjongLevel generateLevel(
    String levelId,
    List<TileCoordinates> layout,
    List<WordPair> dictionary,
  ) {
    if (layout.length % 2 != 0) {
      throw Exception('Layout must have an even number of tiles');
    }

    // We work with a mutable list of 'filled' positions.
    // Initially empty, we fill it up.
    // Wait, the GDD says "Reverse Filling":
    // "Beresh pustoy shablon. Nahodish 2 dostupnye pozitsii. Kladiesh tuda paru slov."
    // Accessible positions in an EMPTY template?
    // Actually, "Accessible" usually means removable in Mahjong.
    // If we are building it up, we are placing tiles such that if we were to play, they would be removable last?
    // No, if we place them, they become "present".
    //
    // Let's think about the "Reverse Filling" algorithm for Solvability.
    // To ensure a Mahjong layout is solvable, we can simulate the *removal* process in reverse.
    // That means we *place* tiles in positions that would be "free" if they were the *only* tiles on the board?
    //
    // Let's re-read:
    // "Beresh pustoy shablon." (Take empty template - i.e. structure of slots)
    // "Nahodish 2 dostupnye (svobodnye) pozitsii." (Find 2 available positions)
    // "Kladiesh tuda paru slov." (Put a pair of words there)
    //
    // If the board is empty, ALL positions are technically "available" to be placed?
    // NO. In Mahjong, you can only remove tiles that are "free" (top is free, L or R is free).
    // If we are ADDING tiles, we should add them to positions that satisfy the condition...
    // Actually, usually you generate a solvable board by taking a set of tiles and placing them in pairs such that they can be removed.
    // The "Reverse" approach usually means:
    // 1. Start with an empty board.
    // 2. Pick a pair of tiles.
    // 3. Place them in two spots that are "valid" to be removed?
    // No, if we place them, we are building the pile.
    // The last pair we place will be the *first* pair the player removes (or one of the first).
    // So the positions we pick must be "removable" relative to the tiles *already placed*.
    //
    // Wait. If I place a tile at Z=0, and then later place a tile at Z=1 on top of it.
    // The Z=1 is removable. The Z=0 is NOT.
    // So, when we build:
    // We should place tiles in positions that DO NOT block existing tiles?
    // Or do we place tiles such that they cover existing ones?
    //
    // Let's trace:
    // Step 1: Place pair A at (0,0,0) and (2,0,0). Board has 2 tiles. Both are removable.
    // Step 2: Place pair B at (0,0,1) [covering A1] and (4,0,0).
    // Now (0,0,1) is removable. (4,0,0) is removable. (0,0,0) is blocked.
    //
    // So the rule for "Reverse Filling" (Adding tiles):
    // Pick 2 positions from the set of ALL EMPTY SLOTS such that:
    // IF we place tiles there, they will be removable given the CURRENT state of the board?
    // NO.
    // If we place a tile on top of an existing one, the NEW tile is removable, but the OLD one becomes blocked.
    // This is valid.
    //
    // However, the GDD says "Find 2 available (free) positions".
    // "Free" usually means "unblocked".
    // If the board is empty, everything is free? No.
    //
    // Let's look at standard solvable generation.
    // Method 1 (Forward): Start full. Randomly shuffle pairs. Check solvability. If fail, retry.
    // Method 2 (Reverse): Start empty.
    // Pick 2 positions that *can* be covered?
    // No, think about removal.
    // Removal: Take 2 free tiles. Remove them.
    // Reverse Removal (Addition): Take 2 positions. Place tiles.
    // These new tiles must be "free" immediately after placement?
    // Yes. Because in the game (forward time), these would be the LAST tiles removed.
    // Wait.
    // If I build from bottom up (Z=0 first), then Z=1.
    // When playing, I remove Z=1 first.
    // So if I place Z=0 first, then Z=1.
    // At step 1 (placing Z=0), it is free.
    // At step 2 (placing Z=1 on top), Z=1 is free. Z=0 becomes blocked.
    //
    // So the algorithm is:
    // 1. Identify all positions defined in the layout.
    // 2. Keep track of which positions are currently filled. Initially none.
    // 3. Keep track of which positions are "available to be filled".
    //    A position can be filled if:
    //    - It is supported by tiles below it (if physics mattered, but here we just have coordinates).
    //    - Actually, we can fill ANY position as long as we respect the order.
    //
    // Let's re-read the GDD carefully: "Reverse Filling".
    // "Beresh pustoy shablon" (Start with empty template).
    // "Nahodish 2 dostupnye (svobodnye) pozitsii" (Find 2 free positions).
    // "Kladiesh tuda paru slov" (Put pair there).
    //
    // "Free" here must mean "If I place a tile here, it won't be floating in air" OR "It corresponds to the Mahjong rule"?
    //
    // Actually, usually "Reverse Filling" for Mahjong means:
    // We simulate the game in reverse.
    // In the game, we REMOVE tiles that are free.
    // In reverse, we ADD tiles that *become* free?
    // No, we ADD tiles.
    // The tiles we add must be capable of being removed *at that moment*?
    // If the board currently has tiles, and we add 2 more.
    // These 2 new ones must be removable?
    // If so, then we are building the state that exists *before* a move.
    //
    // Let's assume the state "Filled Tiles" represents the board at some point in the game.
    // Initially Empty (End of game).
    // We want to reach Full (Start of game).
    // Step: Add 2 tiles such that they are "Removable" in the new state.
    // If we add them, they must be free.
    // So, we need to find 2 empty slots in the layout such that if we fill them, they satisfy the "Free" condition (No tile on top, L or R free).
    // AND checking against *already filled* tiles?
    //
    // Example:
    // Layout: A(0,0,0), B(0,0,1).
    // Empty board.
    // Slots available: A, B.
    // Can we fill B? B is at Z=1. A is at Z=0.
    // If we fill B, is it free? Yes (nothing on top).
    // But is it valid to have B without A? In 2.5D Mahjong, usually yes, tiles can fly.
    // But visually, B floats.
    // Usually we want to fill from bottom up?
    //
    // But if we fill from bottom up (A then B):
    // 1. Fill A. Board has {A}. A is free.
    // 2. Fill B. Board has {A, B}. B is on A.
    //    B is free. A is NOT free.
    //    This matches the game flow! (Player sees A blocked by B, removes B, A becomes free).
    //
    // So the algorithm is:
    // 1. Start with Empty Board.
    // 2. Identify "Candidates for Placement".
    //    A slot is a candidate if:
    //    - It is empty.
    //    - Placing a tile there does not violate physics? (Usually we require tiles below to be present? Or maybe not).
    //    - The GDD doesn't specify gravity.
    //    - But crucially: The tile we place MUST BE REMOVABLE immediately.
    //      Why? Because if we are going backwards from "End of Game" (Empty) to "Start",
    //      then the step "Add 2 tiles" corresponds to "Player removes 2 tiles".
    //      The player can only remove free tiles.
    //      So the tiles we Add (which are the ones the player Removes) must be free in the resulting configuration.
    //
    //      Wait. If I have {A} and I add B on top. Result {A, B}.
    //      In the game, player sees {A, B}. Removes B. State becomes {A}.
    //      So B must be free in {A, B}.
    //      A does NOT need to be free in {A, B}.
    //
    // So the condition for adding a tile T at position P:
    // P must be such that in the NEW state (Old + T), T is free.
    // T is free if:
    // - No tile is at Z+1 covering T. (Since we are adding T, we just need to ensure no EXISTING tile is covering P? No, existing tiles are "below" or "blocking"?
    //   If there is an existing tile at Z+1, we CANNOT place T at Z. Because then T would be covered.
    //   So P must not be covered by any ALREADY FILLED tile.
    // - L or R is free. We need to check neighbors in the ALREADY FILLED set.
    //
    // Let's refine "Reverse Filling".
    // Start: Empty.
    // Loop until Full:
    //   Pick 2 Empty Slots (P1, P2) such that:
    //     1. If we place tiles at P1 and P2, they will be "Free" according to Mahjong rules, considering all currently filled tiles.
    //     Mahjong Rule for "Free":
    //       - No tile on top (z+1 covers part of it).
    //       - Left OR Right is empty.
    //
    //     So for P1 to be valid to ADD:
    //       - Is there any EXISTING tile covering P1?
    //         (If yes, we can't place P1 yet? Wait. If there is a tile C on top of P1.
    //          Then in the game, C must be removed before P1.
    //          So we must add P1 *before* we add C?
    //          No, we are going Reverse (Empty -> Full).
    //          Game: Full -> Empty.
    //          Sequence of removal: C, then P1.
    //          Reverse Sequence of addition: P1, then C.
    //
    //          So when we Add P1, C is NOT there yet.
    //          So P1 is not covered.
    //          Then we Add C. C covers P1.
    //          So P1 becomes blocked.
    //
    //          So when adding P1:
    //          - We need to ensure that P1 can be placed.
    //          - Actually, we can place anything anywhere as long as "physics" allows (if we care about gravity).
    //          - BUT, to ensure "Solvability", we usually mean that we construct the pairs such that they are available.
    //
    //          Let's stick to the simple logic:
    //          We fill the board.
    //          But we need to assign Pairs to positions.
    //
    //          If we just randomly fill positions with pairs, we might put Key A at bottom and Key B at bottom, both covered by other tiles. Unsolvable.
    //
    //          So we must assign pairs to positions that will be available *at the same time* during the game?
    //
    //          Correct Approach (Reverse):
    //          1. Start with Layout structure (empty slots).
    //          2. Maintain a list of "Available to Remove" slots? No, "Available to Place".
    //
    //          Let's try the "Forward Solvable Generation" logic instead, it's easier to think about?
    //          No, the GDD says "Reverse Filling".
    //
    //          Let's try GDD's "Reverse":
    //          "Takes empty template."
    //          "Finds 2 available (free) positions." (Free meaning what?)
    //          "Puts a pair there."
    //
    //          If "Free" means "Removable if existing", then on an Empty board, ALL positions are free?
    //          If I pick (0,0,0) and (0,0,1).
    //          I place Pair 1 at Bottom and Top.
    //          In Game: Top is free. Bottom is NOT free.
    //          So I can remove Top. But I cannot remove Bottom until Top is gone.
    //          But they are a Pair!
    //          So I need to remove them TOGETHER.
    //          I can't.
    //          So this configuration is UNSOLVABLE.
    //
    //          Conclusion: When placing a Pair (P1, P2), BOTH P1 and P2 must be "Removable" relative to the TILES ALREADY PLACED?
    //          Wait.
    //          If I place P1, P2.
    //          Then later I place P3, P4.
    //          In Game: Remove P3, P4. Then Remove P1, P2.
    //
    //          So when I place P1, P2 (at step 1), they will be the LAST to be removed.
    //          So they must be removable *relative to ONLY EACH OTHER*? (and the empty space).
    //          No, relative to "Nothing on top".
    //
    //          When I place P3, P4 (at step 2).
    //          They will be removed *before* P1, P2.
    //          They might cover P1, P2.
    //          So P3 might be on top of P1.
    //
    //          So the Algorithm:
    //          1. `filled_slots = []`. `available_slots = layout`.
    //          2. While `filled_slots.length < layout.length`:
    //             a. Pick P1, P2 from `available_slots`.
    //             b. Condition: If we place P1 and P2, can we eventually remove them?
    //                Actually, if we build bottom-up (Start with last-to-remove):
    //                We place P1, P2.
    //                Then we place P3, P4 on top.
    //
    //                When placing P1, P2:
    //                Does it matter where they are?
    //                Yes. They shouldn't be covering each other in a way that blocks both?
    //                If P2 is on top of P1.
    //                Then P2 is free. P1 is blocked.
    //                We remove P2. P1 becomes free.
    //                But we need to remove PAIR (P1, P2).
    //                We cannot remove P1 yet.
    //                So we cannot remove the pair.
    //
    //                So: When placing a Pair (A, B) at Step K (earlier in generation = later in game).
    //                A and B must NOT block each other.
    //                And they must not be blocked by any previously placed tiles (which are "below" them in removal order)?
    //                Wait. Previously placed tiles are REMOVED LATER.
    //                So if A is on top of "Old Tile O".
    //                Then A is free (assuming nothing on top of A). O is blocked.
    //                We remove A. Then eventually O.
    //                This works.
    //
    //                So the condition is:
    //                When adding a Pair (A, B):
    //                1. A and B must NOT be blocked by "Future Tiles" (which we haven't placed yet). Obviously.
    //                2. A and B must NOT block EACH OTHER?
    //                   - A cannot be on B.
    //                   - B cannot be on A.
    //                   - A cannot block B's side.
    //                   - B cannot block A's side.
    //                3. What about "Old Tiles" (Placed in previous steps)?
    //                   - If A is placed on top of O (Old).
    //                     Then A blocks O.
    //                     In game: A is removed first. Then O.
    //                     This is fine.
    //                   - If O is placed on top of A?
    //                     Impossible, because O was placed first (so it's "under" in the stack of logic? No).
    //
    //                     Let's clarify "Step".
    //                     Step 1: Place Pair 1 (Last to be removed).
    //                     Step 2: Place Pair 2 (2nd Last).
    //                     ...
    //
    //                     When placing Pair 2 (A, B):
    //                     We can place them anywhere?
    //                     As long as they don't block each other.
    //                     AND they don't block Pair 1?
    //                     No, they CAN block Pair 1. That's the point.
    //                     They COVER Pair 1.
    //
    //                     But can Pair 1 block Pair 2?
    //                     If we place Pair 2 *under* Pair 1?
    //                     Then Pair 1 (which is removed LAST) is blocking Pair 2 (which is removed FIRST).
    //                     This is IMPOSSIBLE. You can't remove Pair 2 if Pair 1 is on top.
    //
    //                     So, we can only place tiles in positions that are NOT BLOCKED by existing tiles?
    //
    //                     Let's check:
    //                     Existing tiles = "Last to Remove".
    //                     New tiles = "First to Remove".
    //                     New tiles must be ON TOP of Existing tiles (or beside).
    //                     New tiles CANNOT be UNDER Existing tiles.
    //
    //                     So, a slot S is valid to fill if:
    //                     - It is not already filled.
    //                     - It is NOT covered by any FILLED tile.
    //                     - It's sides are ... ?
    //
    //                     Actually, let's reverse the logic again.
    //                     Let's simulate REMOVAL (Forward).
    //                     Start with FULL board.
    //                     Find removable pairs. Remove them.
    //
    //                     To GENERATE:
    //                     Start with EMPTY board.
    //                     We need to build a structure.
    //
    //                     Let's use the GDD's hint:
    //                     "Beresh pustoy shablon."
    //                     "Nahodish 2 dostupnye (svobodnye) pozitsii."
    //                     "Kladiesh tuda paru slov."
    //
    //                     Maybe it implies:
    //                     We determine the *order of removal* in reverse.
    //                     1. Identify positions that are "Blocked" by nothing (i.e. if a tile was there, it would be free).
    //                        On an empty board, ALL positions are "Free" in terms of "No tile on top".
    //                        But we have to pick positions that *will be* free when the player sees them.
    //
    //                        Actually, the "Reverse Filling" algorithm for Mahjong usually works like this:
    //                        1. List all slot coordinates.
    //                        2. Determine "dependencies": Slot A covers Slot B.
    //                        3. We need to assign an order of removal.
    //                           - If A covers B, A must be removed before B.
    //                        4. We need to pair tiles up.
    //                           - Pick 2 slots (S1, S2) that can be removed *at the same time*.
    //                           - This means neither blocks the other?
    //                           - And all slots covering them are already processed (removed)?
    //
    //                           So, let's process in "Removal Order".
    //                           Iterate until all slots assigned:
    //                             Find set of "Available Candidates".
    //                             Candidate C is available if:
    //                               - All tiles covering C are already assigned (and thus removed).
    //                               - All tiles blocking C (L/R) are already assigned?
    //
    //                             Pick 2 candidates. Assign a pair. Mark them as "Present" (for the player) / "Processed" (for the generator).
    //
    //                             Wait. If C is covered by D.
    //                             D must be removed first.
    //                             So we must assign D first.
    //
    //                             So Candidates are those who are NOT covered by any *Unassigned* slot?
    //                             No.
    //                             If D covers C.
    //                             D is "Top". C is "Bottom".
    //                             Player sees D.
    //                             So D is available. C is blocked.
    //                             So we assign D first.
    //
    //                             So:
    //                             Candidate set = { All slots S such that NO Unassigned Slot blocks S }.
    //                             (i.e. S is "exposed" or "free" given the remaining structure).
    //
    //                             "Blocking":
    //                             - T1 blocks T2 if T1 is on T2.
    //                             - T1 blocks T2 if T1 is L/R of T2.
    //
    //                             If we use "Removal Order" (Start of game -> End):
    //                             1. Candidates = All slots that are currently Removable.
    //                                (i.e. Topmost, and sides free).
    //                             2. Pick 2. Assign Pair. Remove from board simulation.
    //                             3. Repeat.
    //
    //                             BUT we don't know what's on the board yet! We only have coordinates.
    //                             So we assume the board is FULL of "unassigned tiles".
    //
    //                             Algorithm:
    //                             1. Create a graph of dependencies based on coordinates.
    //                                For each slot S:
    //                                  Find who blocks S?
    //                                  - TopBlockers: slots directly above S.
    //                                  - SideBlockers: slots L/R of S.
    //                             2. `remaining_slots` = all slots.
    //                             3. Loop:
    //                                Find `free_slots`: S where (TopBlockers intersected with `remaining_slots`) is Empty
    //                                                AND (SideBlockers check).
    //
    //                                Pick 2 from `free_slots`.
    //                                Assign a word pair.
    //                                Remove from `remaining_slots`.
    //
    //                             This ensures solvability!
    //
    //                             One detail: Side blocking.
    //                             In Mahjong, a tile is free if Left is free OR Right is free.
    //                             So S is free if:
    //                               (TopBlockers in Remaining) is Empty
    //                               AND
    //                               ( (LeftBlockers in Remaining) is Empty OR (RightBlockers in Remaining) is Empty )

    // Let's implement this.

    final slots = List<TileCoordinates>.from(layout);
    final assignments = <TileCoordinates, WordPair>{};
    final pairsToAssign = List<WordPair>.from(dictionary); // We might need to cycle/repeat if dictionary is small

    // Calculate dependencies
    // We need helper to check overlaps

    final remaining = Set<TileCoordinates>.from(slots);
    final assignedTiles = <MahjongTile>[];

    final r = Random();

    while (remaining.isNotEmpty) {
      if (remaining.length < 2) {
        // Should not happen if even
        break;
      }

      // Find candidates
      final candidates = <TileCoordinates>[];
      for (final slot in remaining) {
        if (_isFree(slot, remaining)) {
          candidates.add(slot);
        }
      }

      if (candidates.length < 2) {
        // Deadlock? This can happen in Mahjong generation.
        // If we only have 1 free tile, we are stuck.
        // We might need backtracking or simply shuffle and retry.
        // For this simple implementation, let's throw or retry.
        throw Exception('Deadlock in generation');
      }

      // Pick 2 random
      candidates.shuffle(r);
      final a = candidates[0];
      final b = candidates[1];

      // Pick a pair
      // Ensure we don't run out of pairs if layout is larger than dictionary
      if (pairsToAssign.isEmpty) {
        // Refill if needed, or throw. For now, let's just refill from original dictionary
        // but that brings back the duplicate issue.
        // Ideally dictionary should be large enough.
        // Let's assume it is large enough or we cycle but we MUST remove to avoid duplicates in a small set.
        // If we must reuse, we should probably update match logic.
        // But for this task, let's assume unique pairs are desired.
        pairsToAssign.addAll(dictionary);
      }

      final pairIndex = r.nextInt(pairsToAssign.length);
      final pair = pairsToAssign[pairIndex];
      pairsToAssign.removeAt(pairIndex);

      assignedTiles.add(MahjongTile(
        id: '${a.x}_${a.y}_${a.z}',
        word: pair.a,
        category: pair.category,
        coordinates: a,
        matchId: '${b.x}_${b.y}_${b.z}',
      ));

      assignedTiles.add(MahjongTile(
        id: '${b.x}_${b.y}_${b.z}',
        word: pair.b,
        category: pair.category,
        coordinates: b,
        matchId: '${a.x}_${a.y}_${a.z}',
      ));

      remaining.remove(a);
      remaining.remove(b);
    }

    return MahjongLevel(id: levelId, tiles: assignedTiles);
  }

  bool _isFree(TileCoordinates slot, Set<TileCoordinates> remaining) {
    // Check Top
    // A tile at (x, y, z) is blocked by any tile at (x +/- 1, y +/- 1, z + 1)?
    // Standard Mahjong dimensions: Tile is 2 units wide, 2 units high?
    // GDD: "Coordinates (x,y,z)".
    // Let's assume standard integer grid or similar.
    // Usually:
    // Tile size: W=2, H=2.
    // Overlap: If distance < 2?
    // Let's assume the JSON coordinates are grid units where 1 unit = half a tile?
    // Or 1 unit = 1 tile?
    //
    // "Turtle" layout usually has half-overlaps.
    // Let's assume a tile occupies (x, y) to (x+2, y+2).
    // So blocking on top:
    //   Any tile in `remaining` with z = slot.z + 1
    //   AND x in (slot.x - 2, slot.x + 2)
    //   AND y in (slot.y - 2, slot.y + 2)

    // Check Left/Right
    //   Blocked on Left if exists tile with z = slot.z
    //   AND y in (slot.y - 2, slot.y + 2) (same row approx)
    //   AND x = slot.x - 2 (immediately left)

    // Let's define the metrics.
    // GDD sample: x=0, 2, 4. So width=2 seems to be the step.
    // y=0, 1, 2. Overlap in y is possible.
    // z=0, 1.
    //
    // Assumption: Tile Size = 2x2 units.

    final hasTop = remaining.any((other) =>
      other != slot &&
      other.z == slot.z + 1 &&
      (other.x - slot.x).abs() < 2 &&
      (other.y - slot.y).abs() < 2
    );

    if (hasTop) return false;

    final hasLeft = remaining.any((other) =>
      other != slot &&
      other.z == slot.z &&
      (other.y - slot.y).abs() < 2 &&
      other.x == slot.x - 2
    ); // Actually left could be overlapping slightly?
       // Usually standard Mahjong: Left is exactly at x-2?
       // Or range? "Immediately left".
       // Let's strictly check: x range (slot.x - 2, slot.x).
       // If tile size is 2. Center at x. Extent x to x+2.
       // Left neighbor: Center at x-2. Extent x-2 to x.
       // So they touch.
       // Blocked if "Blocking tile is present".

       // Let's relax: distance < 2 means overlap.
       // Left: x < slot.x. Right: x > slot.x.
       // Usually we check specifically neighbors.

    final hasRight = remaining.any((other) =>
      other != slot &&
      other.z == slot.z &&
      (other.y - slot.y).abs() < 2 &&
      other.x == slot.x + 2
    );

    return !hasLeft || !hasRight;
  }
}
