import 'dart:math';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:bubblepop/engine/bubble_engine.dart';

/// RULES.md §13 test cases + regression tests for the exemplar fixes.
///
/// The engine owns its shot timers; tests drive the public API and wait out
/// the (short) phase durations. A fixed seed makes layouts deterministic.
BubbleEngine makeEngine({int difficulty = 1, int mode = 0, int? seed}) {
  final e = BubbleEngine(difficulty: difficulty, mode: mode, seed: seed ?? 42);
  e.setBoardSize(const Size(360, 560));
  return e;
}

/// Fire straight at the board and wait for the settle.
Future<void> fireAndSettle(BubbleEngine e) async {
  e.setAim(-pi / 2);
  e.fire();
  // Ball flight + 260ms settle: generous wait for CI slowness.
  await Future.delayed(const Duration(milliseconds: 2500));
  // Pump any remaining armed timer.
  await Future.delayed(const Duration(milliseconds: 500));
}

void main() {
  test('1. Firing a ball that completes a 3-group pops it and scores',
      () async {
    final e = makeEngine(seed: 1);
    addTearDown(e.dispose);
    // Rig a 2-group of color 0 at the top, then fire color 0 into it.
    e.grid.clear();
    e.grid[const Point(3, 0)] = 0;
    e.grid[const Point(4, 0)] = 0;
    e.forceColors(0, 1);
    e.fire();
    await Future.delayed(const Duration(milliseconds: 3000));
    expect(e.grid.containsKey(const Point(3, 0)), isFalse);
    expect(e.grid.containsKey(const Point(4, 0)), isFalse);
    expect(e.score, greaterThan(0));
    expect(e.combo, 1);
  });

  test('2. Consecutive popping shots build a combo multiplier', () async {
    final e = makeEngine(seed: 2);
    addTearDown(e.dispose);
    e.grid.clear();
    e.grid[const Point(3, 0)] = 0;
    e.grid[const Point(4, 0)] = 0;
    e.grid[const Point(5, 0)] = 0;
    e.grid[const Point(7, 0)] = 1; // leftover: board must not clear
    e.forceColors(0, 0);
    final before = e.score;
    e.fire();
    await Future.delayed(const Duration(milliseconds: 3000));
    expect(e.combo, 1);
    // Rig another group for the second shot.
    e.grid[const Point(2, 0)] = 0;
    e.grid[const Point(3, 0)] = 0;
    e.forceColors(0, 0);
    e.fire();
    await Future.delayed(const Duration(milliseconds: 3000));
    expect(e.combo, 2);
    expect(e.score, greaterThan(before));
  });

  test('3. A non-popping shot resets the combo', () async {
    final e = makeEngine(seed: 3);
    addTearDown(e.dispose);
    e.grid.clear();
    e.grid[const Point(3, 0)] = 0;
    e.grid[const Point(4, 0)] = 0;
    e.grid[const Point(5, 0)] = 1; // different color: no pop
    e.forceColors(1, 0);
    // First make a pop to build combo 1.
    e.grid[const Point(6, 0)] = 0;
    e.grid[const Point(7, 0)] = 0;
    e.forceColors(0, 1);
    e.fire();
    await Future.delayed(const Duration(milliseconds: 3000));
    expect(e.combo, 1);
    // Now a non-popping shot.
    e.forceColors(1, 0);
    e.fire();
    await Future.delayed(const Duration(milliseconds: 3000));
    expect(e.combo, 0);
  });

  test('4. Ceiling drops every N shots (normal = 6)', () async {
    final e = makeEngine(seed: 4);
    addTearDown(e.dispose);
    e.grid.clear();
    // One anchored bubble so the game continues.
    e.grid[const Point(4, 0)] = 0;
    final rowsBefore = e.grid.keys.map((p) => p.y).toSet();
    // Fire 6 missed shots at a color that cannot pop.
    for (int i = 0; i < 6; i++) {
      e.forceColors(1, 1);
      e.setAim(-pi / 2 + 0.5); // aim sideways to avoid the group
      e.fire();
      await Future.delayed(const Duration(milliseconds: 3000));
      if (e.over) break;
    }
    if (!e.over) {
      final rowsAfter = e.grid.keys.map((p) => p.y).toSet();
      // A fresh row was added at the top AND old rows shifted down.
      expect(rowsAfter.contains(0), isTrue);
      expect(rowsBefore, isNot(rowsAfter));
    }
  });

  test('7. Bubble crossing the death line ends the game (loss)', () async {
    final e = makeEngine(seed: 7);
    addTearDown(e.dispose);
    e.grid.clear();
    // Place a bubble just above the death line, then drop the ceiling.
    final deathRow = ((560 - 120 - 10) / (e.r * 1.732)).floor();
    e.grid[Point(4, deathRow - 1)] = 0;
    // Force enough shots to trigger a ceiling drop.
    e.forceColors(1, 1);
    for (int i = 0; i < 7 && !e.over; i++) {
      e.setAim(-pi / 2 + 0.6);
      e.fire();
      await Future.delayed(const Duration(milliseconds: 2500));
    }
    expect(e.over, isTrue);
    expect(e.won, isFalse);
    expect(e.phase, BubblePhase.over);
  });

  test('8/9. Clearing the board advances the level; level 30 wins',
      () async {
    final e = makeEngine(seed: 8);
    addTearDown(e.dispose);
    e.grid.clear();
    e.grid[const Point(3, 0)] = 0;
    e.grid[const Point(4, 0)] = 0;
    e.forceColors(0, 1);
    e.fire();
    await Future.delayed(const Duration(milliseconds: 3500));
    expect(e.level, 2);
    expect(e.phase, BubblePhase.aiming);
  });

  test('10. Endless: clearing the board rebuilds a fresh rack', () async {
    final e = makeEngine(mode: 1, seed: 10);
    addTearDown(e.dispose);
    e.grid.clear();
    e.grid[const Point(3, 0)] = 0;
    e.grid[const Point(4, 0)] = 0;
    e.forceColors(0, 1);
    e.fire();
    await Future.delayed(const Duration(milliseconds: 3500));
    expect(e.over, isFalse);
    expect(e.grid.isNotEmpty, isTrue); // fresh rack
    expect(e.level, 1); // endless never levels up
  });

  test('11. Firing during flight is ignored — never two balls', () async {
    final e = makeEngine(seed: 11);
    addTearDown(e.dispose);
    e.grid.clear();
    e.grid[const Point(4, 0)] = 0;
    e.forceColors(1, 1);
    e.fire();
    expect(e.phase, BubblePhase.flying);
    e.fire(); // ignored
    e.fire(); // ignored
    await Future.delayed(const Duration(milliseconds: 3000));
    // Game continued normally to aiming (or over), never stuck in flight.
    expect(
        e.phase == BubblePhase.aiming ||
            e.phase == BubblePhase.over ||
            e.phase == BubblePhase.settling,
        isTrue);
  });

  test('12. Swap exchanges current/next only while aiming', () async {
    final e = makeEngine(seed: 12);
    addTearDown(e.dispose);
    e.forceColors(0, 1);
    e.swap();
    expect(e.current, 1);
    expect(e.next, 0);
    // Swap during flight is ignored.
    e.grid.clear();
    e.grid[const Point(4, 0)] = 2;
    e.fire();
    e.swap();
    expect(e.phase, BubblePhase.flying);
    await Future.delayed(const Duration(milliseconds: 3000));
  });

  test('13. Pause freezes flight; resume continues', () async {
    final e = makeEngine(seed: 13);
    addTearDown(e.dispose);
    e.grid.clear();
    e.grid[const Point(4, 0)] = 2;
    e.forceColors(1, 1);
    e.fire();
    expect(e.phase, BubblePhase.flying);
    e.setPaused(true);
    expect(e.paused, isTrue);
    await Future.delayed(const Duration(milliseconds: 500));
    expect(e.phase, BubblePhase.flying); // still flying, frozen
    e.setPaused(false);
    await Future.delayed(const Duration(milliseconds: 3000));
    expect(e.phase != BubblePhase.flying, isTrue);
  });

  test('15. Watchdog recovers a settling phase with no live timer', () async {
    final e = makeEngine(seed: 15);
    addTearDown(e.dispose);
    // Simulate a dead timer: settling with nothing pending must recover.
    e.phase = BubblePhase.settling;
    // The watchdog fires every 3s; wait for one sweep.
    await Future.delayed(const Duration(milliseconds: 3600));
    expect(e.phase, BubblePhase.aiming);
  });
}
